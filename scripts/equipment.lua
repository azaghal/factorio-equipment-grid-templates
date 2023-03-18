-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local template = require("scripts.template")
local factorio_util = require("util")


local equipment = {}


--- Update frequency in ticks for repositioning delivery boxes and installing delivered equipment.
equipment.DELIVERY_UPDATE_FREQUENCY = 20


--- Exports equipment grid template into passed-in blueprint.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid to export the template for.
-- @param blueprint LuaItemStack Empty blueprint to export the template into.
-- @param bool include_equipment_border Include equipment borders in exported blueprint.
--
function equipment.export_into_blueprint(equipment_grid, blueprint, include_equipment_borders)

    local combinators

    if include_equipment_borders then
        combinators = template.equipment_grid_configuration_to_constant_combinators_with_borders(equipment_grid)
    else
        combinators = template.equipment_grid_configuration_to_constant_combinators(equipment_grid)
    end

    -- Set the blueprint content and change default icons.
    blueprint.set_blueprint_entities(combinators)
    blueprint.blueprint_icons = {
        { index = 1, signal = {type = "virtual", name = "signal-E"}},
        { index = 2, signal = {type = "virtual", name = "signal-G"}},
        { index = 3, signal = {type = "virtual", name = "signal-T"}},
    }

end


--- Adds equipment delivery request for an entity.
--
-- Equipment requests are registred via global.equipment_requests data structure, which maps unit number of target
-- entity to equipment request information. The equipment request has the following keys available:
--
--     - entity (LuaEntity), entity where the equipment should be installed.
--     - equipment ({ string = { EquipmentPosition }), list of requested equipment, mapping equipment names to
--       list of positions in grid.
--     - delivery_box (LuaEntity), delivery box for storing the requested equipment prior to installation.
--     - delivery_inventory (LuaInventory), delivery box where the equipment is temporarily stored.
--     - delivery_request_proxy (LuaEntity), item request proxy entity used to deliver the equipment into delviery
--       box/inventory.
--
-- @param entity Entity with equipment grid where equipment should be installed.
-- @param requested_equipment { string = { EquipmentPosition } } List of equipment to install. Maps equipment names into
--     list of equipment grid positions.
--
function equipment.add_equipment_delivery_request(entity, requested_equipment)

    -- Set-up list of equipment to deliver.
    local equipment_modules = {}
    for name, positions in pairs(requested_equipment) do
        equipment_modules[name] = table_size(positions)
    end

    -- Nothing to be done, bail-out.
    if table_size(equipment_modules) == 0 then
        return
    end

    -- Create delivery box for requesting the equipment.
    local delivery_box = entity.surface.create_entity{
        name = "egt-delivery-box",
        position = entity.position,
        force = entity.force,
    }

    local delivery_inventory = delivery_box.get_inventory(defines.inventory.item_main)

    -- Create item request proxy for delivering equipment.
    local equipment_request_proxy = entity.surface.create_entity{
        name = "item-request-proxy",
        target = delivery_box,
        modules = equipment_modules,
        position = delivery_box.position,
        force = delivery_box.force,
    }

    -- Prepare request information.
    local equipment_request = {
        entity = entity,
        equipment = factorio_util.table.deepcopy(requested_equipment),
        delivery_box = delivery_box,
        delivery_inventory = delivery_inventory,
        delivery_request_proxy = factorio_util.table.deepcopy(equipment_request_proxy)
    }

    -- Regiser data for processing.
    global.equipment_requests[entity.unit_number] = equipment_request

    -- Start processing deliveries when the first request gets added.
    if table_size(global.equipment_requests) == 1 then
        script.on_nth_tick(equipment.DELIVERY_UPDATE_FREQUENCY, equipment.process_equipment_deliveries)
    end

end


--- Spills item stack around the first valid passed-in entity, or at fallback position.
--
-- @param item_stack SimpleItemStack|LuaItemStack Item stack to spill.
-- @param surface Surface to spill the items on.
-- @param position MapPosition Position to spill the items around.
-- @param force LuaForce Force to use when ordering deconstruction.
--
function equipment.spill_and_deconstruct(item_stack, surface, position, force)

    local spilled_item_entities = surface.spill_item_stack(position, item_stack, false, nil, false)

    for _, item_entity in pairs(spilled_item_entities) do
        item_entity.order_deconstruction(force)
    end

    item_stack.count = 0

end


--- Clears equipment delivery request for entity identified by passed-in unit number.
--
-- Unit number is used in order to avoid having to deal with invalid entities (where unit number can no longer be
-- obtained).
--
-- Equipment iems that have already been delivered into the delivery box are spilled on the ground.
--
-- @param unit_number uint Unit number of entity for which to clear the request.
--
function equipment.clear_equipment_delivery_request(unit_number)

    local equipment_request = global.equipment_requests[unit_number]

    -- Bail-out, no equipment delivery requests registered for this entity.
    if not equipment_request then
        return
    end

    -- Spill all equipment that might have been delivered but not inserted into the requesting entity.
    for i = 1, #equipment_request.delivery_inventory do

        local slot_stack = equipment_request.delivery_inventory[i]

        if slot_stack.valid_for_read then

            equipment.spill_and_deconstruct(
                slot_stack,
                equipment_request.delivery_box.surface,
                equipment_request.entity.valid and equipment_request.entity.position or equipment_request.delivery_box.position,
                equipment_request.delivery_box.force
            )

        end

    end

    -- Destroy the delivery container. This will get rid of the item request proxy as well.
    equipment_request.delivery_box.destroy()

    -- Deregister equipment request.
    global.equipment_requests[unit_number] = nil

end


--- Installs equipment from delivery box into requesting entity.
--
-- @param equipment_request {
--         entity = LuaEntity,
--         equipment = { string = { EquipmentPosition },
--         delivery_box = LuaEntity,
--         delivery_inventory = LuaInventory,
--         delivery_request_proxy = LuaEntity
--     }
--
function equipment.install_delivered_equipment(equipment_request)

    -- Sort the inventory so we have non-empty slots at the very beginning only.
    equipment_request.delivery_inventory.sort_and_merge()

    for slot_index = 1, #equipment_request.delivery_inventory do

        local slot_stack = equipment_request.delivery_inventory[slot_index]

        -- Break out of the loop since inventory is sorted, and we have hit the first empty slot.
        if not slot_stack.valid_for_read then
            break
        end

        -- All the required equipment by this name has already been installed, spill the excess onto the ground.
        if table_size(equipment_request.equipment[slot_stack.name] or {}) == 0  then

            equipment.spill_and_deconstruct(
                slot_stack,
                equipment_request.entity.surface,
                equipment_request.entity.position,
                equipment_request.entity.force
            )

        -- Proceed with installing the equipment. Try to insert every single item from the stack until we run out of
        -- registered positions.
        else

            for _ = 1, slot_stack.count do

                -- Grab the first position.
                position = table.remove(equipment_request.equipment[slot_stack.name], 1)

                -- We ran out of positions, remaining items are no longer needed.
                if not position then

                    equipment.spill_and_deconstruct(
                        slot_stack,
                        equipment_request.entity.surface,
                        equipment_request.entity.position,
                        equipment_request.entity.force
                    )

                    break

                end

                -- Try to place equipment.
                if equipment_request.entity.grid.put{name = slot_stack.name, position = position} then
                    slot_stack.count = slot_stack.count - 1
                end

            end

        end

    end

end


--- Processes all equipment deliveries, updating delivery box positions and installing delivered equipment.
--
-- Function is primarily meant to be called periodically every N ticks.
--
function equipment.process_equipment_deliveries()

    for unit_number, equipment_request in pairs(global.equipment_requests) do

        -- If requesting entity is no longer valid, clear the request.
        if not equipment_request.entity.valid then
            equipment.clear_equipment_delivery_request(unit_number)

        -- Update delivery box position and install delivered equipment if delivery box and delivery target are on the same surface.
        elseif equipment_request.delivery_box.surface == equipment_request.entity.surface then
            equipment_request.delivery_box.teleport(equipment_request.entity.position)
            equipment.install_delivered_equipment(equipment_request)

        -- If delivery box and delivery target are not on the same surface, we need to recreate the box and item request proxy.
        else

            local old_delivery_box = equipment_request.delivery_box
            local old_delivery_request_proxy = equipment_request.delivery_request_proxy

            equipment_request.delivery_box = old_delivery_box.clone{
                position = equipment_request.entity.position,
                surface = equipment_request.entity.surface
            }
            equipment_request.delivery_inventory = equipment_request.delivery_box.get_inventory(defines.inventory.item_main)
            equipment_request.delivery_request_proxy = equipment_request.delivery_box.surface.create_entity{
                name = "item-request-proxy",
                target = equipment_request.delivery_box,
                modules = old_delivery_request_proxy.item_requests,
                position = equipment_request.delivery_box.position,
                force = equipment_request.delivery_box.force,
            }

            old_delivery_box.destroy()

            equipment.install_delivered_equipment(equipment_request)
        end

        -- Requested equipment has been installed (if possible) or delivered.
        if  table_size(equipment_request.equipment) == 0 or
            not equipment_request.delivery_request_proxy.valid then

            equipment.clear_equipment_delivery_request(unit_number)

        end

    end

    -- Stop processing equipment deliveries, there are none left.
    if table_size(global.equipment_requests) == 0 then
        script.on_nth_tick(20, nil)
    end

end


--- Import equipment grid configuration.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid for which to import the configuration.
-- @param provider_inventory LuaInventory Inventory to use as source of equipment for immediate insertion.
-- @param provider_entity LuaEntity Entity to use as source of equipment for delivery via construction bots.
-- @param configuration { { name = string, position = EquipmentPosition } } List of equipment to import into equipment grid.
--
function equipment.import(equipment_grid, provider_inventory, provider_entity, configuration)

    -- Track configuration equipment (by index) that is already in correct place.
    local already_fulfilled = {}

    -- Track excess equipment (by name) that should be remove from equipment grid.
    local excess_equipment = {}

    -- Track missing equipment (by name). Maps name to list of positions in the equipment grid.
    local missing_equipment = {}

    -- Find configuration equipment that is already correctly placed in the grid, and remove all other equipment.
    for _, current_equipment in pairs(equipment_grid.equipment) do

        local keep = false
        for requested_equipment_index, requested_equipment in pairs(configuration) do

            if  current_equipment.position.x == requested_equipment.position.x and
                current_equipment.position.y == requested_equipment.position.y and
                current_equipment.name == requested_equipment.name then

                already_fulfilled[requested_equipment_index] = true

                keep = true
                break

            end

        end

        if not keep then
            local removed_equipment = equipment_grid.take{equipment = current_equipment}
            excess_equipment[removed_equipment.name] = excess_equipment[removed_equipment.name] or {}
            table.insert(excess_equipment[removed_equipment.name], removed_equipment)
        end

    end

    -- Try to satisfy configuration using equipment removed from the grid or from provider inventory.
    for requested_equipment_index, requested_equipment in pairs(configuration) do

        if not already_fulfilled[requested_equipment_index] then

            local equipment_ =
                table.remove(excess_equipment[requested_equipment.name] or {}) or
                provider_inventory.find_item_stack(requested_equipment.name)

            if equipment_ then

                equipment_grid.put({name = requested_equipment.name, position = requested_equipment.position})
                equipment_.count = equipment_.count - 1

            else

                missing_equipment[requested_equipment.name] = missing_equipment[requested_equipment.name] or {}
                table.insert(missing_equipment[requested_equipment.name], requested_equipment.position)

            end

        end

    end

    -- Store remaining excess equipment in provider inventory or spill it on the ground if no room is available.
    for _, equipment_list in pairs(excess_equipment) do
        for _, equipment_ in pairs(equipment_list) do
            if provider_inventory.insert(equipment_) == 0 then
                equipment.spill_and_deconstruct(
                    equipment_,
                    provider_entity.surface,
                    provider_entity.position,
                    provider_entity.force
                )
            end
        end
    end

    -- Request missing equipment delivery.
    equipment.clear_equipment_delivery_request(provider_entity.unit_number)
    equipment.add_equipment_delivery_request(provider_entity, missing_equipment)

end


return equipment
