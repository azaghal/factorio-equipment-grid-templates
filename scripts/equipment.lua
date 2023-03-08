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

    -- Track missing equipment (by name) count.
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

    -- Try to satisfy configuration using equipment removed from the grid or from provider iventory.
    for requested_equipment_index, requested_equipment in pairs(configuration) do

        if not already_fulfilled[requested_equipment_index] then

            local equipment =
                table.remove(excess_equipment[requested_equipment.name] or {}) or
                provider_inventory.find_item_stack(requested_equipment.name)

            if equipment then

                equipment_grid.put({name = requested_equipment.name, position = requested_equipment.position})
                equipment.count = equipment.count - 1

            else

                missing_equipment[requested_equipment.name] = missing_equipment[requested_equipment.name] or 0
                missing_equipment[requested_equipment.name] = missing_equipment[requested_equipment.name] + 1

            end

        end

    end

    -- Store remaining excess equipment in provider inventory or spill it on the ground if no room is available.
    for _, equipment_list in pairs(excess_equipment) do
        for _, equipment in pairs(equipment_list) do
            if provider_inventory.insert(equipment) == 0 then
                provider_entity.surface.spill_item_stack(provider_entity.position, equipment, false, nil, false)
            end
        end
    end

    -- Request missing equipment delivery via construction bots. Reuse existing item request proxy.
    if table_size(missing_equipment) > 0 then

        local equipment_request_proxy = provider_entity.surface.find_entity('item-request-proxy', provider_entity.position)

        if equipment_request_proxy then
            equipment_request_proxy.item_requests = missing_equipment
        else
            equipment_request_proxy = provider_entity.surface.create_entity{
                name = "item-request-proxy",
                target = provider_entity,
                modules = missing_equipment,
                position = provider_entity.position,
                force = provider_entity.force,
            }
        end

    end

end


return equipment
