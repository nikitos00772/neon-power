local function xy(c) return c.x or c[1] or 0, c.y or c[2] or 0 end

local anchors = {}
for name, pole in pairs(data.raw["electric-pole"]) do
  local cp = pole.connection_points and pole.connection_points[1]
  local c = cp and cp.wire and cp.wire.copper
  if c then
    local a = {}
    a.x, a.y = xy(c)
    local s = cp.shadow and cp.shadow.copper
    if s then a.sx, a.sy = xy(s) end
    anchors[name] = a
  end
end
data:extend({ { type = "mod-data", name = "neon-power-anchors", data = anchors } })
