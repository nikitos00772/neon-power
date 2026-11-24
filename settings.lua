data:extend({
  {
    type = "color-setting",
    name = "neon-power-color",
    setting_type = "runtime-global",
    default_value = { r = 0.1, g = 0.75, b = 1.0, a = 1.0 },
    order = "a"
  },
  {
    type = "double-setting",
    name = "neon-power-core-width",
    setting_type = "runtime-global",
    default_value = 0.5,
    minimum_value = 0.3,
    maximum_value = 2.0,
    order = "b"
  },
  {
    type = "double-setting",
    name = "neon-power-tube-width",
    setting_type = "runtime-global",
    default_value = 1.3,
    minimum_value = 1.3,
    maximum_value = 4.0,
    order = "bb"
  },
  {
    type = "double-setting",
    name = "neon-power-glow-width",
    setting_type = "runtime-global",
    default_value = 7.0,
    minimum_value = 0.0,
    maximum_value = 30.0,
    order = "c"
  },
  {
    type = "int-setting",
    name = "neon-power-glow-layers",
    setting_type = "runtime-global",
    default_value = 3,
    minimum_value = 1,
    maximum_value = 8,
    order = "cb"
  },
  {
    type = "double-setting",
    name = "neon-power-cable-glow",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0.0,
    maximum_value = 2.0,
    order = "e"
  },
  {
    type = "double-setting",
    name = "neon-power-pole-glow",
    setting_type = "runtime-global",
    default_value = 1.0,
    minimum_value = 0.0,
    maximum_value = 2.0,
    order = "f"
  },
})
