local function xy(c) return c.x or c[1] or 0, c.y or c[2] or 0 end

-- Copper wire point of each neon pole: cables start where the copper wire does.
local anchors = {}
for name in pairs(data.raw["mod-data"]["neon-power-poles"].data) do
  local pole = data.raw["electric-pole"][name]
  local cp = pole and pole.connection_points and pole.connection_points[1]
  local c = cp and cp.wire and cp.wire.copper
  if c then
    local x, y = xy(c)
    anchors[name] = { x = x, y = y }
  end
end
data:extend({ { type = "mod-data", name = "neon-power-anchors", data = anchors } })
