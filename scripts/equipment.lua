-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local template = require("scripts.template")


local equipment = {}


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
-- Equipment requests is registred via global.equipment_requests data structure, which maps registration numbers
-- (obtained via script.register_on_entity_destroyed) to equipment request information. The equipment request
-- has the following keys available:
--
--     - entity (LuaEntity), entity to which the request (and equipment grid) are tied to.
--     - inventories ({ LuaInventory }), list of inventories associated with the entity. This is where requested items
--       will usually end-up in.
--     - name (string), name of requested equipment.
--     - position (EquipmentPosition), desired position of equipment in the grid.
--     - request_proxy (LuaEntity), item request proxy entity used to deliver the equipment.
--
-- @param entity Entity with equipment grid to insert the delivered equipment into.
-- @param equipment_name string Name of equipment to deliver.
-- @param equipment_position EquipmentPosition Position in grid to install the equipment into.
--
function equipment.add_equipment_delivery_request(entity, equipment_name, equipment_position)

    -- Set-up list of inventories available to entity.
    local entity_inventories = {}
    for inventory_name, enum in pairs(defines.inventory) do
        entity_inventories[enum] = entity_inventories[enum] or entity.get_inventory(enum)
    end

    -- Create entity for equipment delivery using construction bots.
    local equipment_request_proxy = entity.surface.create_entity{
        name = "item-request-proxy",
        target = entity,
        modules = { [equipment_name] = 1 },
        position = entity.position,
        force = entity.force,
    }

    -- Prepare request information.
    local equipment_request = {
        entity = entity,
        inventories = entity_inventories,
        name = equipment_name,
        position = equipment_position,
        request_proxy = equipment_request_proxy
    }

    -- Keep track of created item request proxy, and register the data for handler processing.
    local registration_number = script.register_on_entity_destroyed(equipment_request_proxy)
    global.equipment_requests[registration_number] = equipment_request

end


--- Clears all equipment delivery requests for a given entity.
--
-- @param entity LuaEntity Entity for which to clear the requests.
--
function equipment.clear_equipment_delivery_requests(entity)

    for registration_number, equipment_request in pairs(global.equipment_requests) do
        if entity.unit_number == equipment_request.entity.unit_number then

            -- Clear registration number so the on_entity_destroyed handler would not process it.
            global.equipment_requests[registration_number] = nil

            if equipment_request.valid then
                equipment_request.equipment_request_proxy.destroy()
            end

        end
    end

end


--- Processes received equipment from an equipment request.
--
-- @param equipment_request {
--     entity = LuaEntity,
--     inventories = { LuaInventory },
--     name = string,
--     position = EquipmentPosition,
--     request_proxy = LuaEntity,
-- } Equipment request for received equipment.
--
function equipment.process_received_equipment(equipment_request)

    local equipment_
    local index

    for _, inventory in pairs(equipment_request.inventories) do
        equipment_, index = inventory.find_item_stack(equipment_request.name)
        if equipment_ then
            break
        end
    end

    if equipment_ then
        equipment_request.entity.grid.put({name = equipment_request.name, position = equipment_request.position})
        equipment_.count  = equipment_.count - 1
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
            if provider_inventory.insert(equipment) == 0 then
                provider_entity.surface.spill_item_stack(provider_entity.position, equipment, false, nil, false)
            end
        end
    end

    -- Clear existing proxy requests.
    local item_request_proxies = provider_entity.surface.find_entities_filtered{
        position = provider_entity.position,
        name = "item-requests-proxy"
    }

    for _, item_request_proxy in pairs(item_request_proxies) do
        item_request_proxy.destroy()
    end

    -- Request missing equipment delivery via construction bots. Clear any previous requests.
    equipment.clear_equipment_delivery_requests(provider_entity)
    for name, position_list in pairs(missing_equipment) do
        for _, position in pairs(position_list) do
            equipment.add_equipment_delivery_request(provider_entity, name, position)
        end
    end

end


return equipment
