-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local gui = {}


--- Initialise GUI elements for a given player.
--
-- @param player LuaPlayer Player for which to initialise the GUI.
--
function gui.initialise(player)
    if global.player_data[player.index].windows then
        return
    end

    -- Although it would be possible to maintain a single window, and simply update the anchors, this would result in
    -- entity window getting nudged upwards every time the buttons window gets reanchored to them, which would be
    -- somewhat annoying visually. Maintain "duplicate" button windows instead for smoother GUI experience.
    global.player_data[player.index].windows = {}

    local window_anchors = {
        armor = defines.relative_gui_type.armor_gui,
        car = defines.relative_gui_type.car_gui,
        character = defines.relative_gui_type.controller_gui,
        -- Cargo wagons, artillery wagons.
        container = defines.relative_gui_type.container_gui,
        -- Fluid wagons.
        equipment_grid = defines.relative_gui_type.equipment_grid_gui,
        spidertron = defines.relative_gui_type.spider_vehicle_gui,
        -- Locomotives.
        train = defines.relative_gui_type.train_gui,
    }

    for window_name, gui_type in pairs(window_anchors) do

        local window = player.gui.relative.add{
            type = "frame",
            name = "egt_window_" .. window_name,
            anchor = {
                gui = gui_type,
                position = defines.relative_gui_position.bottom
            },
            style = "quick_bar_window_frame",
            visible = false,
        }

        local panel = window.add{
            type = "frame",
            name = "egt_panel",
            style = "shortcut_bar_inner_panel",
        }

        local export_button = panel.add{
            type = "sprite-button",
            name = "egt_export_button",
            style = "shortcut_bar_button_blue",
            visible = false,
            sprite = "egt-export-template-button",
            tooltip = {"gui.egt-export"},
            tags = { mode = "export" }
        }

        local export_border_button = panel.add{
            type = "sprite-button",
            name = "egt_export_border_button",
            style = "shortcut_bar_button_blue",
            visible = false,
            sprite = "egt-export-border-template-button",
            tooltip = {"gui.egt-export-border"},
            tags = { mode = "export" }
        }

        local import_button = panel.add{
            type = "sprite-button",
            name = "egt_import_button",
            style = "shortcut_bar_button_blue",
            visible = false,
            sprite = "egt-import-template-button",
            tooltip = {"gui.egt-import"},
            tags = { mode = "import" }
        }

        global.player_data[player.index].windows[window_name] = window
    end

    -- @WORKAROUND: Window does not get rendered at bottom of train window for some reason. Interesting enough, if the
    --              top_margin is set to -10, the window will render, but button cannot be clicked.
    --
    --              Similar problem seems to happen with spidetron/vehicle GUIs if they have a tall equipment grid, and
    --              at specific GUI sizes. Decrementing GUI size seems to unhide the window.
    --
    --              Both issues are most likely related to the window being too tall. Probably should test against
    --              latest version and then report the bug to Wube.
    global.player_data[player.index].windows.train.anchor = {
        gui = global.player_data[player.index].windows.train.anchor.gui,
        position = defines.relative_gui_position.left
    }
end


--- Destroys all GUI elements for passed-in player.
--
-- @param player LuaPlayer Player for which to destroy the GUI.
--
function gui.destroy_player_data(player)
    if not global.player_data[player.index].windows then
        return
    end

    for _, window in pairs(global.player_data[player.index].windows) do
        window.destroy()
    end

    global.player_data[player.index].windows = nil
end


--- Sets mode of operation for GUI, showing or hiding the relevant elements.
--
-- @param player LuaPlayer Player for which to set the GUI mode.
-- @param mode string Mode to set. One of: "hidden".
--
function gui.set_mode(player, mode)
    for _, window in pairs(global.player_data[player.index].windows) do

        if mode == "hidden" then

            window.visible = false

        else

            -- Show all buttons with matching mode.
            for _, button in pairs(window.egt_panel.children) do
                if button.tags.mode == mode then
                    button.visible = true
                else
                    button.visible = false
                end
            end

            window.visible = true

        end
    end
end


-- Maps GUI events to list of handlers to invoke.
gui.handlers = {}

--- Registers handler with click event on a specific GUI element.
--
-- Multiple handlers can be registered with GUI element. Handlers are invoked in the order they have been registered.
--
-- @param name string Name of GUI element for which to register click handler.
-- @param func callable Callable to invoke when GUI element is clicked on.
--
function gui.register_handler(name, func)
    gui.handlers[name] = gui.handlers[name] or {}
    table.insert(gui.handlers[name], func)
end


--- Invokes registered handlers for passed-in GUI element.
--
-- @param player LuaPlayer Player that clicked on the GUI element.
-- @param element LuaGuiElement GUI element that was clicked on.
--
function gui.on_click(player, element)
    if string.find(element.name, "^egt_") then
        for _, func in pairs(gui.handlers[element.name] or {}) do
            func(player)
        end
    end
end


return gui
