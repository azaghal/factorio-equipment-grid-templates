-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


--- Container used for delivering equipment to entities using item request proxy.
--
-- Required in order to ensure the equipment can be reliably delivered. The delivery box is moved around to follow the
-- target entity. Delivered equipment is installed into equipment grid as quickly as possible.
--
-- The delivery box is not visible, nor selectable, nor interactable by players.
--
local delivery_box = {
    name = "egt-delivery-box",
    type = "container",
    inventory_size = 100,
    picture = {
        filename = "__equipment-grid-templates__/graphics/icons/delivery-box.png",
        width = 1,
        height = 1,
    },
    allow_copy_paste = false,
    selectable_in_game = false,
    collision_mask = {},
    flags = {
        "hidden",
        "no-automated-item-insertion",
        "no-automated-item-removal",
        "no-copy-paste",
        "not-blueprintable",
        "not-deconstructable",
        "not-flammable",
        "not-in-kill-statistics",
        "not-in-made-in",
        "not-on-map",
        "not-selectable-in-game",
        "not-upgradable",
        "placeable-off-grid",
        "player-creation"
    },
}


data:extend{delivery_box}
