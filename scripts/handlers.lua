-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local main = require("scripts.main")
local equipment = require("scripts.equipment")
local gui = require("scripts.gui")
local constants = require("scripts.constants")


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
    if event.gui_type == defines.gui_type.controller or event.gui_type == defines.gui_type.item then
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


--- Reregisters conditional handlers.
--
-- Primarily meant as means to reregister the processing handler (on_nth_tick) on both server and client side, since the
-- handler is registered and deregistered as needed (both server and client must have it in same state when player joins
-- the game).
--
function handlers.on_load()

    if table_size(global.equipment_requests) > 0 then
        script.on_nth_tick(constants.DELIVERY_UPDATE_FREQUENCY, handlers.on_nth_tick)
    end

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


--- Processes events every n-ticks.
--
-- @param data NthTickEventData Event data as passed-in by the game engine.
--
function handlers.on_nth_tick(data)
    equipment.process_equipment_deliveries()
end


return handlers
