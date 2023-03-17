-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local main = require("scripts.main")
local equipment = require("scripts.equipment")
local gui = require("scripts.gui")


local handlers = {}


--- Updates button visibility when players changes a held item.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function handlers.on_player_cursor_stack_changed(event)
    local player = game.players[event.player_index]
    main.update_button_visibility(player)
end


--- Updates button visibility when players open a GUI.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function handlers.on_gui_opened(event)
    local player = game.players[event.player_index]

    -- This is the only type of mod-supported inventory GUI that can be opened while a blueprint is being held (at least
    -- in vanilla game).
    if event.gui_type == defines.gui_type.controller then
        main.update_button_visibility(player)
    end
end


--- Initialises mod data for newly joined players.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function handlers.on_player_joined_game(event)
    local player = game.players[event.player_index]

    main.initialise_player_data(player)
end


--- Cleans-up data for removed players.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function handlers.on_pre_player_removed(event)
    local player = game.players[event.player_index]

    main.destroy_player_data(player)
end


--- Initialises mod data when mod is first added to a savegame.
--
function handlers.on_init()
    main.initialise_data()
end


--- Registers GUI handlers for all relevant modules.
--
function handlers.register_gui_handlers()
    main.register_gui_handlers()
end


--- Processes clicks on GUI elements.
--
-- @param event EventData Event data as passed-in by the game engine.
--
function handlers.on_gui_click(event)
    local player = game.players[event.player_index]
    local element = event.element

    gui.on_click(player, element)
end


--- Processes mod configuration changes (upgrades).
--
-- @param data ConfigurationChangedData Event data as passed-in by the game engine.
--
function handlers.on_configuration_changed(data)
    local mod_changes = data.mod_changes["equipment-grid-templates"]

    if mod_changes then
        main.update_data(mod_changes.old_version,
                         mod_changes.new_version)
    end
end


return handlers
