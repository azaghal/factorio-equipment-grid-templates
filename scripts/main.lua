-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local gui = require("scripts.gui")
local utils = require("scripts.utils")
local equipment = require("scripts.equipment")
local template = require("scripts.template")


local main = {}


--- Initialises global mod data.
--
function main.initialise_data()
    global.player_data = global.player_data or {}

    for index, player in pairs(game.players) do
        main.initialise_player_data(player)
    end
end


--- Initialiases global mod data for a specific player.
--
-- @param player LuaPlayer Player for which to initialise the data.
--
function main.initialise_player_data(player)
    global.player_data[player.index] = global.player_data[player.index] or {}

    gui.initialise(player)
end


--- Updates global mod data.
--
-- @param old_version string Old version of mod.
-- @param new_version string New version of mod.
--
function main.update_data(old_version, new_version)

    -- Ensure the GUI definition is up-to-date for all players.
    if new_version ~= old_version then
        for index, player in pairs(game.players) do
            gui.destroy_player_data(player)
            gui.initialise(player)
        end
    end

end


--- Destroys all mod data for a specific player.
--
-- @param player LuaPlayer Player for which to destroy the data.
--
function main.destroy_player_data(player)
    gui.destroy_player_data(player)

    global.player_data[player.index] = nil
end


--- Updates visibility of buttons for a given player based on held cursor stack.
--
-- @param player LuaPlayer Player for which to update button visibility.
--
function main.update_button_visibility(player)

    -- Assume the GUI should be kept hidden.
    local gui_mode = "hidden"

    -- Retrieve list of blueprint entities.
    local blueprint_entities = player.get_blueprint_entities() or {}

    -- Fetch entity and equipment grid corresponding to currently opened GUI.
    local entity = utils.get_opened_gui_entity(player)
    local equipment_grid = utils.get_opened_gui_equipment_grid(player)

    -- Check if player is holding a blank blueprint.
    if utils.is_player_holding_blank_editable_blueprint(player) and equipment_grid then
        gui_mode = "export"

    -- Check if player is holding a valid template while window of entity with an equipment grid is open.
    elseif entity and equipment_grid and template.is_valid_template(equipment_grid, blueprint_entities) then
        gui_mode = "import"

    end

    gui.set_mode(player, gui_mode)

end


--- Exports equipment grid template for requesting player's opened entity into a held (empty) blueprint.
--
-- @param player LuaPlayer Player that has requested the export.
--
function main.export(player)

    local equipment_grid = utils.get_opened_gui_equipment_grid(player)

    equipment.export_into_blueprint(equipment_grid, player.cursor_stack, false)

    -- Player should be holding a valid blueprint template at this point. Make sure correct buttons are visible.
    main.update_button_visibility(player)

end


--- Exports equipment grid template for requesting player's opened entity into a held (empty) blueprint.
--
-- Produces blueprint with border markers for denoting what area is occupied by each piece of equipment.
--
-- @param player LuaPlayer Player that has requested the export.
--
function main.export_border(player)

    local equipment_grid = utils.get_opened_gui_equipment_grid(player)

    equipment.export_into_blueprint(equipment_grid, player.cursor_stack, true)

    -- Player should be holding a valid blueprint template at this point. Make sure correct buttons are visible.
    main.update_button_visibility(player)

end


--- Imports equipment grid template from a held blueprint.
--
-- @param player LuaPlayer Player that has requested the import.
--
function main.import(player)

    local entity = utils.get_opened_gui_entity(player)
    local equipment_grid = utils.get_opened_gui_equipment_grid(player)
    local provider_inventory =
        player.can_reach_entity(entity) and player.character.get_inventory(defines.inventory.character_main) or
        nil

    local blueprint_entities = player.get_blueprint_entities()
    local configuration = template.constant_combinators_to_equipment_grid_configuration(blueprint_entities, equipment_grid.width)

    equipment.import(equipment_grid, provider_inventory, entity, configuration)

end


--- Registers GUI handlers for the module.
--
function main.register_gui_handlers()
    gui.register_handler("egt_export_button", main.export)
    gui.register_handler("egt_export_border_button", main.export_border)
    gui.register_handler("egt_import_button", main.import)
end


return main
