-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local utils = {}


--- Retrieves equipment grid corresponding to currently opened GUI.
--
-- @param LuaPlayer Player to check the opened GUI for.
--
-- @return LuaEquipmentGrid|nil Equipment grid for which the current GUI is opened for.
--
function utils.get_opened_gui_equipment_grid(player)

    local equipment_grid =
        player.opened_gui_type == defines.gui_type.controller and player.character and player.character.grid or
        player.opened_gui_type == defines.gui_type.entity and player.opened.grid or
        player.opened_gui_type == defines.gui_type.item and player.opened and player.opened.object_name == "LuaEquipmentGrid" and player.opened or
        nil

    return equipment_grid
end


--- Retrieves entity corresponding to currently opened GUI.
--
-- @param LuaPlayer Player to check the opened GUI for.
--
-- @return LuaEntity|nil Entity for which the current GUI is opened for, or nil in case of unsupported entity.
--
function utils.get_opened_gui_entity(player)

    local entity = nil

    if player.opened_gui_type == defines.gui_type.controller then
        entity = player.character
    elseif player.opened_gui_type == defines.gui_type.entity and player.opened.grid then
        entity = player.opened
    end

    return entity
end


--- Checks if the player is holding a blank editable blueprint.
--
-- @param player LuaPlayer Player for which to perform the check.
--
-- @return bool true if player is holding a blank blueprint, false otherwise.

function utils.is_player_holding_blank_editable_blueprint(player)

    local blueprint_entities = player.get_blueprint_entities() or {}

    return table_size(blueprint_entities) == 0 and player.is_cursor_blueprint() and player.cursor_stack.valid_for_read
end


--- Finds a non-empty item stack by item name from the passed-in source.
--
-- @param name string Name of an item to find.
-- @param source LuaInventory | { LuaItemStack|SimpleItemStack } Inventrory or list of item stacks to search through.
--
-- @return LuaItemStack|SimpleItemStack|nil Matching non-empty item stack.
--
function utils.find_item_stack(name, source)

    if source.object_name == "LuaInventory" then

        return source.find_item_stack(name)

    elseif type(source) == "table" then

        for _, item in pairs(source) do
            if item.count > 0 and item.name == name then
                return item
            end
        end

    end

    return nil

end


--- Returns list of all inventories owned by an entity.
--
-- @param entity LuaEntity Entity to get the inventories for.
--
-- @return { LuaInventory }
--
function utils.get_entity_inventories(entity)

    local inventories = {}

    local seen = {}
    for _, inventory_type_id in pairs(defines.inventory) do

        if not seen[inventory_type_id] then

            local inventory = entity.get_inventory(inventory_type_id)
            if inventory then
                table.insert(inventories, inventory)
            end
            seen[inventory_type_id] = true

        end

    end

    return inventories

end


--- Reports details of failed equipment import to player.
--
-- @param player LuaPlayer Player to report the details to.
-- @param configuration { string = { EquipmentPosition } } Configuration describing failed equipment installation. Maps
--     equipment names into list of equipment grid positions.
function utils.report_failed_equipment_installation(player, configuration)

    player.print({"error.egt-failed-install-header"})

    for name, positions in pairs(configuration) do

        local positions_strings = {}

        for _, position in pairs(positions) do
            table.insert(positions_strings, string.format("(%d, %d)", position.x + 1, position.y + 1))
        end

        player.print({"error.egt-failed-install-item", name, {"equipment-name." .. name}, table.concat(positions_strings, ", ")})

    end

end


-- Reports details of missing equipment import to player.
--
-- @param player LuaPlayer Player to report the details to
-- @param configuration { string = { EquipmentPosition } } Configuration describing failed equipment installation. Maps
--     equipment names into list of equipment grid positions.
function utils.report_missing_equipment(player, configuration)

    player.print({"error.egt-missing-header"})

    for name, positions in pairs(configuration) do
        player.print({"error.egt-missing-item", table_size(positions), name, {"equipment-name." .. name}})
    end

end


return utils
