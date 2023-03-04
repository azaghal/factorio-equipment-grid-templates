-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local template = require("scripts.template")


local equipment = {}


--- Exports equipment grid template into passed-in blueprint.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid to export the template for.
-- @param blueprint LuaItemStack Empty blueprint to export the template into.
--
function equipment.export_into_blueprint(equipment_grid, blueprint)

    local combinators = template.equipment_grid_configuration_to_constant_combinators(equipment_grid)

    -- Set the blueprint content and change default icons.
    blueprint.set_blueprint_entities(combinators)
    blueprint.blueprint_icons = {
        { index = 1, signal = {type = "virtual", name = "signal-E"}},
        { index = 2, signal = {type = "virtual", name = "signal-G"}},
        { index = 3, signal = {type = "virtual", name = "signal-T"}},
    }

end


return equipment
