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


return utils
