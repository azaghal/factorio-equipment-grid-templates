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


return equipment
