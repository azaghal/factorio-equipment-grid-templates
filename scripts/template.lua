-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local template = {}


--- Checks if passed-in list of blueprint entities constitutes a valid equipment grid template that can be imported.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid to check the template against.
-- @param blueprint_entities {BlueprintEntity} List of blueprint entities to check.
--
-- @return bool true if passed-in entities constitute valid equipment grid template, false otherwise.
--
function template.is_valid_template(equipment_grid, blueprint_entities)

    -- At least one entity must be present in the blueprint.
    if table_size(blueprint_entities) == 0 then
        return false
    end

    -- Equipment grid must have the same number of slots as passed-in template.
    if equipment_grid.height * equipment_grid.width ~= table_size(blueprint_entities) then
        return false
    end

    -- Sort the passed-in combinators by coordinates. This is the same order the combinators are read during import.
    local sort_by_coordinate = function(elem1, elem2)
        if elem1.position.y < elem2.position.y then
            return true
        elseif elem1.position.y == elem2.position.y and elem1.position.x < elem2.position.x then
            return true
        end

        return false
    end
    table.sort(blueprint_entities, sort_by_coordinate)

    -- Set-up a matrix for keeping track on whether we can fit all the equipment into the grid.
    local space_occupied = {}
    for x = 1, equipment_grid.width do

        local column = {}
        table.insert(space_occupied, column)

        for y = 1, equipment_grid.height do
            table.insert(column, false)
        end
    end

    -- Process combinators one by one, try to bail-out early if possible.
    for entity_index, entity in pairs(blueprint_entities) do

        -- Only constant combinators are allowed in the blueprint.
        if entity.name ~= "constant-combinator" then
            return false
        end

        -- Extract list of filters on constant combinator.
        local filters = entity.control_behavior and entity.control_behavior.filters and entity.control_behavior.filters or {}

        -- Maximum of four filters can be set.
        if table_size(filters) > 4 then
            return false
        end

        -- Check if the filters have been set correctly.
        for _, filter in pairs(filters) do

            -- Check if filters at specific positions are of correct type.
            if filter.index > 5 then
                return false
            elseif filter.index == 1 and (filter.count ~= 1 or filter.signal.type ~= "item" or not game.equipment_prototypes[filter.signal.name]) then
                return false
            elseif filter.index ~= 1 and (filter.signal.type ~= "virtual") then
                return false
            end

            -- Check if equipment fits in the grid.
            if filter.index == 1 then

                local equipment = game.equipment_prototypes[filter.signal.name]

                -- Expected boundries for the equipment.
                local top = math.floor((entity_index - 1) / equipment_grid.width) + 1
                local bottom = top + equipment.shape.height - 1
                local left = (entity_index - 1) % equipment_grid.width + 1
                local right = left + equipment.shape.width - 1

                -- Check if equipment is within the grid boundaries.
                if bottom > equipment_grid.height or right > equipment_grid.width then
                    return false
                end

                -- Check if equipment is overlapping other equipment.
                for y = top, bottom do
                    for x = left, right do
                        if space_occupied[x][y] then
                            return false
                        else
                            space_occupied[x][y] = true
                        end

                    end
                end

            end

        end

    end

    return true
end


--- Converts equipment grid configuration into list of (blueprint entity) constant combinators.
--
-- Constant combinators are laid-out in a grid matching the size of equipment grid. Signals matching equipment items are
-- set at equipment positions (which corresponds to upper-left corner of equipment itself).
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid for which to generate the list of blueprint entities.
--
-- @return {BlueprintEntity} List of blueprint entities (constant combinators) representing the configuration.
--
function template.equipment_grid_configuration_to_constant_combinators(equipment_grid)

    -- Set-up a list of empty combinators (row by row) that will represent the configuration.
    local combinators = {}

    for y = 1, equipment_grid.height do
        for x = 1, equipment_grid.width do
            table.insert(
                combinators,
                {
                    entity_number = (y - 1) * equipment_grid.width + x,
                    name = "constant-combinator",
                    position = {x = x, y = y},
                    control_behavior = {filters = {}}
                }
            )
        end
    end

    -- Process every piece of equipment.
    for equipment_index, equipment_ in pairs(equipment_grid.equipment) do

        -- Fetch combinator that corresponds to position on the equipment grid.
        local combinator_index = equipment_.position.y * equipment_grid.width + equipment_.position.x + 1
        local combinator = combinators[combinator_index]

        table.insert(
            combinator.control_behavior.filters,
            { index = 1, count = 1, signal = { name = equipment_.name, type = "item" } }
        )

    end

    return combinators
end


--- Converts equipment grid configuration into list of (blueprint entity) constant combinators.
--
-- Constant combinators are laid-out in a grid matching the size of equipment grid. Signals matching equipment items are
-- set at equipment positions (which corresponds to upper-left corner of equipment itself).
--
-- During conversion, the combinators that would get occupied by the equipment are marked-off using colour virtual
-- signals, resulting in a kind of rectangle with equipment item in upper-left. This is done only for visual hints to
-- the player.
--
-- @param equipment_grid LuaEquipmentGrid Equipment grid for which to generate the list of blueprint entities.
--
-- @return {BlueprintEntity} List of blueprint entities (constant combinators) representing the configuration.
--
function template.equipment_grid_configuration_to_constant_combinators_with_borders(equipment_grid)

    -- Set-up a list of empty combinators (row by row) that will represent the configuration.
    local combinators = {}

    for y = 1, equipment_grid.height do
        for x = 1, equipment_grid.width do

            table.insert(
                combinators,
                {
                    entity_number = (y - 1) * equipment_grid.width + x,
                    name = "constant-combinator",
                    position = {x = x, y = y},
                    control_behavior = {filters = {}}
                }
            )
        end
    end

    -- List of virtual signals to use when alternating border color.
    local border_signal_names = {
        "signal-red",
        "signal-green",
        "signal-blue",
        "signal-yellow",
        "signal-pink",
        "signal-cyan",
        "signal-white",
    }
    local border_variation_count = table_size(border_signal_names)

    -- Process every piece of equipment.
    for equipment_index, equipment_ in pairs(equipment_grid.equipment) do

        -- Signals to use for setting-up the combinator filters.
        local equipment_signal = {
            name = equipment_.name ,
            type = "item"
        }
        local border_signal = {
            name = border_signal_names[(equipment_index - 1) % border_variation_count + 1],
            type = "virtual"
        }
        local filler_signal =
            equipment_.shape.height == 1 or equipment_.shape.width == 1 and border_signal or
            { name = "signal-black", type = "virtual" }

        -- Combinator filter for representing equipment insertion position. Always in top-left.
        local top_left_border_filters = {
            { index = 1, count = 1, signal = equipment_signal }
        }

        -- Filters used for marking the area occupied by equipment on the grid.
        local top_border_filters = {
            { index = 2, count = 0, signal = border_signal },
            { index = 3, count = 0, signal = border_signal },
            { index = 4, count = 0, signal = filler_signal },
            { index = 5, count = 0, signal = filler_signal },
        }

        local top_right_border_filters = {
            { index = 2, count = 0, signal = border_signal },
            { index = 3, count = 0, signal = border_signal },
            { index = 4, count = 0, signal = filler_signal },
            { index = 5, count = 0, signal = border_signal },
        }

        local right_border_filters = {
            { index = 2, count = 0, signal = filler_signal },
            { index = 3, count = 0, signal = border_signal },
            { index = 4, count = 0, signal = filler_signal },
            { index = 5, count = 0, signal = border_signal },
        }

        local bottom_right_border_filters = {
            { index = 2, count = 0, signal = filler_signal },
            { index = 3, count = 0, signal = border_signal },
            { index = 4, count = 0, signal = border_signal },
            { index = 5, count = 0, signal = border_signal },
        }

        local bottom_border_filters = {
            { index = 2, count = 0, signal = filler_signal },
            { index = 3, count = 0, signal = filler_signal },
            { index = 4, count = 0, signal = border_signal },
            { index = 5, count = 0, signal = border_signal },
        }

        local bottom_left_border_filters = {
            { index = 2, count = 0, signal = border_signal },
            { index = 3, count = 0, signal = filler_signal },
            { index = 4, count = 0, signal = border_signal },
            { index = 5, count = 0, signal = border_signal },
        }

        local left_border_filters = {
            { index = 2, count = 0, signal = border_signal },
            { index = 3, count = 0, signal = filler_signal },
            { index = 4, count = 0, signal = border_signal },
            { index = 5, count = 0, signal = filler_signal },
        }

        local center_filters = {
            { index = 2, count = 0, signal = filler_signal },
            { index = 3, count = 0, signal = filler_signal },
            { index = 4, count = 0, signal = filler_signal },
            { index = 5, count = 0, signal = filler_signal },
        }

        -- Figure out border positions.
        local left = equipment_.position.x + 1
        local right = equipment_.position.x + equipment_.shape.width
        local top = equipment_.position.y + 1
        local bottom = equipment_.position.y + equipment_.shape.height

        -- Set-up filters on combinators.
        for y = top, bottom do
            for x = left, right do
                local combinator_index = (y - 1) * equipment_grid.width + x
                local combinator = combinators[combinator_index]

                -- "Draw" a filled-in rectangle over combinators that denote slots occupied by equipment. Top-left
                -- should consist just out of equipment item itself.
                if y == top and x == left then
                    combinator.control_behavior.filters = top_left_border_filters
                elseif y == top and x == right then
                    combinator.control_behavior.filters = top_right_border_filters
                elseif y == bottom and x == right then
                    combinator.control_behavior.filters = bottom_right_border_filters
                elseif y == bottom and x == left then
                    combinator.control_behavior.filters = bottom_left_border_filters
                elseif y == top then
                    combinator.control_behavior.filters = top_border_filters
                elseif y == bottom then
                    combinator.control_behavior.filters = bottom_border_filters
                elseif x == left then
                    combinator.control_behavior.filters = left_border_filters
                elseif x == right then
                    combinator.control_behavior.filters = right_border_filters
                else
                    combinator.control_behavior.filters = center_filters
                end

            end
        end
    end

    return combinators
end


--- Converts list of (blueprint entity) constant combinators into equipment grid configuration.
--
-- Function assumes that the passed-in list of constant combinators has been validated already (see
-- template.is_valid_template).
--
-- @param combinators {BlueprintEntity} List of constant combinators representing inventory configuration.
-- @param grid_width uint Width of equipment grid.
--
-- @return { string = { EquipmentPosition } } Mapping between equipment names and list of equipment grid positions.
--
function template.constant_combinators_to_equipment_grid_configuration(combinators, grid_width)

    local configuration = {}

    -- Sort the passed-in combinators by coordinates. This should help get a somewhat sane ordering even if player has
    -- been messing with the constant combinator layout. Slots are read from top to bottom and from left to right.
    table.sort(
        combinators,
        function(a, b)
            return a.position.y < b.position.y or a.position.y == b.position.y and a.position.x < b.position.x
        end
    )

    for combinator_index, combinator in pairs(combinators) do

        if combinator.control_behavior and combinator.control_behavior.filters then

            local combinator_filters = combinator.control_behavior.filters

            for _, filter in pairs(combinator.control_behavior.filters) do

                -- Grid positions are 0-based.
                local position = {
                    x = (combinator_index - 1) % grid_width,
                    y = math.floor((combinator_index - 1) / grid_width)
                }

                if filter.index == 1  then
                    configuration[filter.signal.name] = configuration[filter.signal.name] or {}
                    table.insert(configuration[filter.signal.name], position)
                end

            end

        end

    end

    return configuration

end


return template
