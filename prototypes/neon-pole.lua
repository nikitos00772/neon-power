local CONFIG = require("config")
local TINT = { 0.55, 0.85, 1.0, 1.0 }
local ICON_TINT = { 0.45, 0.85, 1.0, 1.0 }

local POLES = {
  { base = "small-electric-pole",  name = "neon-small-electric-pole", order = "a" },
  { base = "medium-electric-pole", name = "neon-power-pole",          order = "b" },
  { base = "big-electric-pole",    name = "neon-big-electric-pole",   order = "c" },
  { base = "substation",           name = "neon-substation",          order = "d" },
}

local prototypes, effects, names = {}, {}, {}

for _, def in pairs(POLES) do
  local base_pole = data.raw["electric-pole"][def.base]
  local base_item = data.raw["item"][def.base]
  if base_pole and base_item then
    local NAME = def.name
    local icons = { { icon = base_pole.icon, icon_size = base_pole.icon_size or 64, tint = ICON_TINT } }

    local pole = table.deepcopy(base_pole)
    pole.name = NAME
    pole.localised_name = nil
    pole.icons, pole.icon = icons, nil
    pole.minable = { mining_time = (base_pole.minable and base_pole.minable.mining_time) or 0.1, result = NAME }
    pole.next_upgrade = nil
    pole.fast_replaceable_group = base_pole.fast_replaceable_group
    pole.draw_copper_wires = CONFIG.vanilla_wire
    pole.light = nil
    for k, v in pairs(def.extra or {}) do pole[k] = v end

    -- single sprite variant so the cable anchor always matches
    for _, layer in pairs(pole.pictures.layers or { pole.pictures }) do
      if not layer.draw_as_shadow then layer.tint = TINT end
      layer.direction_count = 1
    end
    pole.connection_points = { pole.connection_points[1] }

    local item = table.deepcopy(base_item)
    item.name = NAME
    item.localised_name = nil
    item.icons, item.icon = icons, nil
    item.place_result = NAME
    item.order = "a[energy]-n[neon]-" .. def.order .. "[" .. NAME .. "]"

    prototypes[#prototypes + 1] = pole
    prototypes[#prototypes + 1] = item
    prototypes[#prototypes + 1] = {
      type = "recipe",
      name = NAME,
      enabled = false,
      energy_required = 1,
      ingredients = {
        { type = "item", name = def.base, amount = 1 },
        { type = "item", name = "advanced-circuit", amount = 1 },
        { type = "item", name = "plastic-bar", amount = 2 },
      },
      results = { { type = "item", name = NAME, amount = 1 } },
    }
    effects[#effects + 1] = { type = "unlock-recipe", recipe = NAME }
    if not base_pole.next_upgrade then base_pole.next_upgrade = NAME end
    names[NAME] = true
  end
end

local prereqs = {}
for _, t in pairs({ "electric-energy-distribution-2", "advanced-circuit" }) do
  if data.raw.technology[t] then prereqs[#prereqs + 1] = t end
end

prototypes[#prototypes + 1] = {
  type = "technology",
  name = "neon-power",
  icons = { {
    icon = "__base__/graphics/technology/electric-energy-distribution-2.png",
    icon_size = 256,
    tint = ICON_TINT,
  } },
  effects = effects,
  prerequisites = prereqs,
  unit = {
    count = 150,
    ingredients = {
      { "automation-science-pack", 1 },
      { "logistic-science-pack", 1 },
      { "chemical-science-pack", 1 },
    },
    time = 30,
  },
}
prototypes[#prototypes + 1] = { type = "mod-data", name = "neon-power-poles", data = names }

data:extend(prototypes)
