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
    default_value = 1,
    minimum_value = 0.5,
    maximum_value = 8.0,
    order = "b"
  },
  {
    type = "double-setting",
    name = "neon-power-glow-width",
    setting_type = "runtime-global",
    default_value = 5.0,
    minimum_value = 0.0,
    maximum_value = 30.0,
    order = "c"
  },
  {
    type = "double-setting",
    name = "neon-power-glow-strength",
    setting_type = "runtime-global",
    default_value = 0.2,
    minimum_value = 0.0,
    maximum_value = 1.0,
    order = "d"
  },
  {
    type = "double-setting",
    name = "neon-power-light-strength",
    setting_type = "runtime-global",
    default_value = 1.5,
    minimum_value = 0.0,
    maximum_value = 2.0,
    order = "e"
  },
})
