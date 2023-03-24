-- Copyright (c) 2023 Branko Majic
-- Provided under MIT license. See LICENSE for details.


local util = require("__core__/lualib/util")


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


--- Custom item request proxy for better visibility.
--
-- Uses custom images in order to make it easier to spot equipment grid requests, and to make it possible to cancel only
-- those via deconstruction planner.
--
local equipment_request_proxy = util.copy(data.raw["item-request-proxy"]["item-request-proxy"])
equipment_request_proxy.name = "egt-equipment-request-proxy"
equipment_request_proxy.icon = "__equipment-grid-templates__/graphics/icons/egt-equipment-request-proxy.png"
equipment_request_proxy.icon_mipmaps = 3
equipment_request_proxy.icon_size = 64
equipment_request_proxy.picture = {
    filename = "__equipment-grid-templates__/graphics/entity/egt-equipment-request-proxy.png",
    flags = {
        "icon"
    },
    height = 64,
    priority = "extra-high",
    scale = 0.5,
    shift = {
        0,
        0
    },
    width = 64
}


data:extend{delivery_box, equipment_request_proxy}
