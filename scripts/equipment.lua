-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local template = require("scripts.template")
local utils = require("scripts.utils")
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


--- Creates delivery box and item request proxy for passed-in item requests.
--
-- @param entity LuaEntity Entity for which to create the delivery box.
-- @param item_requests { string = uint } Items to request for delivery.
--
-- @return (LuaEntity, LuaInventory, LuaEntity) Delivery box entity, delivery box inventory, and delivery item request proxy.
--
function equipment.create_delivery_box(entity, item_requests)

    -- Container that will hold the received equipment.
    local delivery_box = entity.surface.create_entity{
        name = "egt-delivery-box",
        position = entity.position,
        force = entity.force,
    }

    -- Inventory corresponding to delivery box.
    local delivery_inventory = delivery_box.get_inventory(defines.inventory.item_main)

    -- Item request proxy that construction bots will respond to.
    local delivery_request_proxy = entity.surface.create_entity{
        name = "item-request-proxy",
        target = delivery_box,
        modules = item_requests,
        position = delivery_box.position,
        force = delivery_box.force,
    }

    return delivery_box, delivery_inventory, delivery_request_proxy
end


--- Adds equipment delivery request for an entity.
--
-- Equipment requests are registred via global.equipment_requests data structure, which maps unit number of target
-- entity to equipment request information. The equipment request has the following keys available:
--
--     - entity (LuaEntity), entity where the equipment should be installed.
--     - equipment_grid_id (uint), unique ID of equipment grid. Used for checking if entity's grid might have changed.
--     - configuration ({ string = { EquipmentPosition }), configuration to apply against equipment grid, mapping
--       equipment names to list of positions in grid.
--     - delivery_box (LuaEntity), delivery box for storing the requested equipment prior to installation.
--     - delivery_inventory (LuaInventory), delivery box where the equipment is temporarily stored.
--     - delivery_request_proxy (LuaEntity), item request proxy entity used to deliver the equipment into delviery
--       box/inventory.
--
-- @param entity Entity with equipment grid where equipment should be installed.
-- @param equipment_grid_id uint Unique ID of associaed equipment grid.
-- @param configuration { string = { EquipmentPosition } } Configuration to apply against the equipment grid. Maps
--     equipment names into list of equipment grid positions.
--
function equipment.add_equipment_delivery_request(entity, equipment_grid_id, configuration)

    -- Set-up list of equipment to deliver.
    local equipment_modules = {}
    for name, positions in pairs(configuration) do
        equipment_modules[name] = table_size(positions)
    end

    -- Nothing to be done, bail-out.
    if table_size(equipment_modules) == 0 then
        return
    end

    local delivery_box, delivery_inventory, delivery_request_proxy =
        equipment.create_delivery_box(entity, equipment_modules)

    -- Prepare request information.
    local equipment_request = {
        entity = entity,
        equipment_grid_id = equipment_grid_id,
        configuration = factorio_util.table.deepcopy(configuration),
        delivery_box = delivery_box,
        delivery_inventory = delivery_inventory,
        delivery_request_proxy = delivery_request_proxy
    }

    -- Regiser data for processing.
    global.equipment_requests[entity.unit_number] = equipment_request

    -- Start processing deliveries when the first request gets added.
    if table_size(global.equipment_requests) == 1 then
        script.on_nth_tick(equipment.DELIVERY_UPDATE_FREQUENCY, equipment.process_equipment_deliveries)
    end

end


--- Spills item stack around the passed-in position.
--
-- @param item_stack SimpleItemStack|LuaItemStack Item stack to spill.
-- @param surface LuaSurface Surface to spill the items on.
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


--- Discards items by placing them into passed-in inventory or spilling them to the ground.
--
-- @param item_stacks { SimpleItemStack|LuaItemStack } List of item stacks to spill.
-- @param inventory LuaInventory|nil Inventory to insert the items into (if possible).
-- @param surface LuaSurface Surface to spill the items on if inventory insertion fails.
-- @param position MapPosition Position to spill the items around if inventory insertion fails.
-- @param force LuaForce Force to use when ordering deconstruction of spilled items.
--
function equipment.discard_item_stacks(item_stacks, inventory, surface, position, force)

    for _, item_stack in pairs(item_stacks) do

        -- Insert as many items as possible into inventory.
        if item_stack.count > 0 and inventory then
            item_stack.count = item_stack.count - inventory.insert(item_stack)
        end

        -- Spill the remaining items from the stack.
        if item_stack.count > 0 then
            equipment.spill_and_deconstruct(item_stack, surface, position, force)
        end

    end

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
--         configuration = { string = { EquipmentPosition },
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

        -- Insert no more equipment than available/requested.
        for _ = 1, math.min(slot_stack.count, table_size(equipment_request.configuration[slot_stack.name] or {})) do

            position = table.remove(equipment_request.configuration[slot_stack.name], 1)

            -- Try to place equipment.
            if equipment_request.entity.grid.put{name = slot_stack.name, position = position} then
                slot_stack.count = slot_stack.count - 1
            end

        end

        -- Spill the excess equipment on the ground.
        if slot_stack.valid_for_read then
            equipment.spill_and_deconstruct(
                slot_stack,
                equipment_request.entity.surface,
                equipment_request.entity.position,
                equipment_request.entity.force
            )
        end

    end

end


--- Processes all equipment deliveries, updating delivery box positions and installing delivered equipment.
--
-- Function is primarily meant to be called periodically every N ticks.
--
function equipment.process_equipment_deliveries()

    for unit_number, equipment_request in pairs(global.equipment_requests) do

        -- If requesting entity or equipment grid are no longer valid, clear the request.
        if  not equipment_request.entity.valid or
            not equipment_request.entity.grid or not equipment_request.entity.grid.valid or
            equipment_request.entity.grid.unique_id ~= equipment_request.equipment_grid_id then

            equipment.clear_equipment_delivery_request(unit_number)

        -- Update delivery box position and install delivered equipment if delivery box and delivery target are on the same surface.
        elseif equipment_request.delivery_box.surface == equipment_request.entity.surface then
            equipment_request.delivery_box.teleport(equipment_request.entity.position)
            equipment.install_delivered_equipment(equipment_request)

        -- If delivery box and delivery target are not on the same surface, we need to recreate the box and item request proxy.
        else

            -- Item requests will be reused for new box.
            local item_requests = equipment_request.delivery_request_proxy.item_requests

            -- Install equipment from existing delivery box and destroy it.
            equipment.install_delivered_equipment(equipment_request)
            equipment_request.delivery_box.destroy()

            -- Create new delivery box.
            local new_delivery_box, new_delivery_inventory, new_delivery_request_proxy =
                equipment.create_delivery_box(equipment_request.entity, item_requests)

            equipment_request.delivery_box = new_delivery_box
            equipment_request.delivery_inventory = new_delivery_inventory
            equipment_request.delivery_request_proxy = new_delivery_request_proxy

        end

        -- Requested equipment has been installed (if possible) or delivered.
        if  table_size(equipment_request.configuration) == 0 or
            not equipment_request.delivery_request_proxy.valid then

            equipment.clear_equipment_delivery_request(unit_number)

        end

    end

    -- Stop processing equipment deliveries, there are none left.
    if table_size(global.equipment_requests) == 0 then
        script.on_nth_tick(20, nil)
    end

end


--- Removes excess equipment from the grid.
--
-- Excess equipment is equipment that is:
--
--     - Not included in the equipment grid configuration.
--     - Placed in wrong position.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid to remove the excess equipment from.
-- @param configuration { string = { EquipmentPosition } }
--     Configuration to compare the equipment grid against.
--
-- @return { SimpleItemStack } List of removed equipment.
--
function equipment.remove_excess_equipment(equipment_grid, configuration)

    local excess_equipment = {}

    for _, grid_equipment in pairs(equipment_grid.equipment) do

        local keep = false

        for _, position in pairs(configuration[grid_equipment.name] or {}) do

            if  grid_equipment.position.x == position.x and grid_equipment.position.y == position.y then
                keep = true
                break
            end

        end

        if not keep then
            local removed_equipment = equipment_grid.take{equipment = grid_equipment}
            table.insert(excess_equipment, removed_equipment)
        end

    end

    return excess_equipment

end


--- Populates equipment grid according to passed-in configuration using equipment from passed-in source.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid to insert the equipment into.
-- @param configuration { string = { EquipmentPosition } }
--     Equipment configuration to apply against the grid.
-- @param source LuaInventory | { LuaItemStack|SimpleItemStack } Inventory or list of items to use as source.
--
-- @return ( string = { EquipmentPosition }, { string = { EquipmentPosition } )
--     Two equipment grid configurations - one with missing equipment, and one with equipment that could not be
--     installed (insufficient space or not allowed in the grid).
--
function equipment.populate_equipment_grid_from_source(equipment_grid, configuration, source)

    local missing = {}
    local failed = {}

    for name, positions in pairs(configuration) do

        for _, position in pairs(positions) do

            local existing_equipment = equipment_grid.get(position)
            local source_equipment = utils.find_item_stack(name, source)

            -- Non-matching equipment is already occupying the position.
            if existing_equipment and existing_equipment.name ~= name then
                failed[name] = failed[name] or {}
                table.insert(failed[name], position)

            -- Position is empty, and equipment from inventory was inserted.
            elseif not existing_equipment and source_equipment and
                equipment_grid.put({name = name, position = position}) then
                source_equipment.count = source_equipment.count - 1

            -- Position is empty, but insertion has failed.
            elseif not existing_equipment and source_equipment then
                failed[name] = failed[name] or {}
                table.insert(failed[name], position)

            -- Position is empty, but we are missing equipment in the inventory.
            elseif not existing_equipment and not source_equipment then
                missing[name] = missing[name] or {}
                table.insert(missing[name], position)

            end

        end

    end

    return missing, failed

end


--- Installs equipment according to grid configuration.
--
-- The equipment is installed from the following sources (in order of preference):
--
--     - Equipment grid itself (misplaced/excess equipment).
--     - Provider inventory (usually player's own inventory).
--     - Construction bots deliveries to entity, if equipment grid is associated with an entity.
--
-- @param entity LuaEntity|nil Entity that owns the equipment grid. Pass-in nil if equipment grid is not associated with
--     an entity.
-- @param equipment_grid LuaEquipmentGrid Equipment grid for which to import the configuration.
-- @param configuration { string = { EquipmentPosition } } Equipment configuration to apply against the grid.
-- @param provider_inventories LuaInventory Inventories to use as source of equipment for immediate insertion.
-- @param discard_inventory LuaInventory Inventory to discard into the excess equipment removed from the grid.
--
-- @return { string = { EquipmentPosition } } Equipment grid configuration with equipment that could not be installed
--     (insufficient space or not allowed in the grid).
--
function equipment.import(entity, equipment_grid, configuration, provider_inventories, discard_inventory)

    local excess_equipment
    local missing_configuration
    local failed_configuration
    local failed_configurations = {}

    excess_equipment = equipment.remove_excess_equipment(equipment_grid, configuration)

    missing_configuration, failed_configuration =
        equipment.populate_equipment_grid_from_source(equipment_grid, configuration, excess_equipment)
    table.insert(failed_configurations, failed_configuration)

    for _, inventory in pairs(provider_inventories)do
        missing_configuration, failed_configuration =
            equipment.populate_equipment_grid_from_source(equipment_grid, missing_configuration, inventory)
        table.insert(failed_configurations, failed_configuration)
    end

    equipment.discard_item_stacks(excess_equipment, discard_inventory, entity.surface, entity.position, entity.force)

    -- Request missing equipment delivery.
    equipment.clear_equipment_delivery_request(entity.unit_number)
    equipment.add_equipment_delivery_request(entity, equipment_grid.unique_id, missing_configuration)

    -- Merge all failed configurations for return result.
    local merged_failed_configurations = {}
    for _, failed_configuration in pairs(failed_configurations) do
        for name, positions in pairs(failed_configuration) do
            merged_failed_configurations[name] = merged_failed_configurations[name] or {}
            for _, position in pairs(positions) do
                table.insert(merged_failed_configurations[name], position)
            end
        end
    end

    return merged_failed_configurations
end


return equipment
