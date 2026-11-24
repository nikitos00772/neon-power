local util = require("util")

data:extend({
  {
    type = "sprite",
    name = "neon-power-cable-light",
    filename = "__neon-power__/graphics/cable-light.png",
    priority = "extra-high",
    flags = { "light" },
    width = 128,
    height = 128,
  },
  {
    type = "electric-energy-interface",
    name = "neon-power-interface",
    icon = "__base__/graphics/icons/medium-electric-pole.png",
    icon_size = 64,
    hidden = true,
    flags = { "not-on-map", "placeable-off-grid", "not-blueprintable",
              "not-deconstructable", "hide-alt-info", "no-copy-paste",
              "not-selectable-in-game", "not-upgradable" },
    selectable_in_game = false,
    collision_box = { { -0.1, -0.1 }, { 0.1, 0.1 } },
    collision_mask = { layers = {} },
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "10kJ",
      input_flow_limit = "10MW",
      render_no_power_icon = false,
      render_no_network_icon = false,
    },
    energy_usage = "1kW",
    picture = util.empty_sprite(),
    max_health = 1,
    allow_copy_paste = false,
  },
})
