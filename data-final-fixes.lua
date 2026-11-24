local function xy(c) return c.x or c[1] or 0, c.y or c[2] or 0 end

-- Copper wire and shadow points of every picture variant, per pole.
local anchors = {}
for name, pole in pairs(data.raw["electric-pole"]) do
  local list = {}
  for i, cp in ipairs(pole.connection_points or {}) do
    local c = cp.wire and cp.wire.copper
    if not c then break end
    local a = {}
    a.x, a.y = xy(c)
    local s = cp.shadow and cp.shadow.copper
    if s then a.sx, a.sy = xy(s) end
    list[i] = a
  end
  if #list > 0 then anchors[name] = list end
end
data:extend({ { type = "mod-data", name = "neon-power-anchors", data = anchors } })
