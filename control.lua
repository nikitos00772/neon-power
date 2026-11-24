local POWER = "neon-power-interface"
local CABLE_KW = 1

local NEON_SET = prototypes.mod_data["neon-power-poles"].data
local NEON_LIST = {}
for n in pairs(NEON_SET) do NEON_LIST[#NEON_LIST + 1] = n end
local function is_neon(name) return NEON_SET[name] == true end

local STEP_TICKS = 20
local RESCAN_PER_STEP = 30
local SEG_LEN = 0.3
local MIN_SEGS = 16
local MAX_SEGS = 64
local LIGHT_SPACING = 0.5
local STRIP_LEN = 2
local STRIP_PX = 128
local POLE_LIGHT_SCALE = 0.8
local DEFAULT_ANCHOR = { x = 0, y = -2.5 }

local WIRE_DEPTH = 46.9 / 64 -- depth of the arc in the png
local END_OFF = 2.33 / 64    -- arc ends above the png's vertical centre
local SPRITE_H = 46          -- png height, px at 32 px per tile
local HALF_H = SPRITE_H / 64 -- half of it, in tiles
local SHORT_LEN = 3
local PROFILE = {
  0.0, 0.1569, 0.2944, 0.4136, 0.517, 0.6082, 0.6859, 0.7545, 0.8121, 0.8624,
  0.9031, 0.936, 0.9617, 0.9805, 0.9948, 1.0, 1.0, 1.0, 0.9948, 0.9805, 0.9617,
  0.936, 0.9031, 0.8624, 0.8121, 0.7545, 0.6859, 0.6082, 0.517, 0.4136, 0.2944,
  0.1569, 0.0,
}
-- Saved cables are redrawn when this changes; bump DRAW_REV for drawing changes.
local DRAW_REV = 20
local DRAW_SIG = table.concat({ DRAW_REV, WIRE_DEPTH, END_OFF, SPRITE_H, SHORT_LEN, SEG_LEN, MIN_SEGS, MAX_SEGS,
  LIGHT_SPACING, STRIP_LEN, POLE_LIGHT_SCALE }, "|")

local anchors

local function cfg()
  local g = settings.global
  return {
    color   = g["neon-power-color"].value,
    core_w  = g["neon-power-core-width"].value,
    glow_w  = g["neon-power-glow-width"].value,
    glow_layers = g["neon-power-glow-layers"].value,
    tube_w  = g["neon-power-tube-width"].value,
    light   = g["neon-power-cable-glow"].value,
    pole_light = g["neon-power-pole-glow"].value,
  }
end

-- Round connection points toward zero to 1/256 tile, so cables meet the vanilla wire ends exactly.
local function fixed(v)
  local s = v * 256
  return (s >= 0 and math.floor(s) or math.ceil(s)) / 256
end

-- Where the copper wire leaves the pole.
local function anchor_of(pole)
  if not anchors then
    local md = prototypes.mod_data["neon-power-anchors"]
    anchors = md and md.data or {}
  end
  local o = anchors[pole.name] or DEFAULT_ANCHOR
  local p = pole.position
  return { x = p.x + fixed(o.x), y = p.y + fixed(o.y) }
end

local function profile(t)
  local f = t * 32
  local i = math.max(0, math.min(31, math.floor(f)))
  local u = f - i
  return PROFILE[i + 1] * (1 - u) + PROFILE[i + 2] * u
end

local function arc(pa, pb)
  local dx, dy = pb.x - pa.x, pb.y - pa.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1e-6 then len = 1e-6 end
  local nx, ny = -dy / len, dx / len
  if ny < 0 then nx, ny = -nx, -ny end
  local k = math.abs(dx) / len
  local s = k * SPRITE_H * math.min(1, len / SHORT_LEN)
  local q = math.max(1, s) / SPRITE_H -- cropped fraction of the png height
  return {
    x = pa.x, y = pa.y, dx = dx, dy = dy, len = len, nx = nx, ny = ny,
    q = q, w = math.sqrt(q),
    shrink = math.max(0, len - 1 / 32) / len, -- drawn 1 px shorter than the chord
  }
end

local function arc_point(a, t)
  local u = 0.5 + (t - 0.5) * a.w -- column in the png, 0..1
  local d = WIRE_DEPTH * profile(u) - END_OFF - HALF_H * (1 - a.q)
  local s = 0.5 + (t - 0.5) * a.shrink
  return { x = a.x + a.dx * s + a.nx * d, y = a.y + a.dy * s + a.ny * d }
end

local function band(pts, width)
  local verts, n, half = {}, #pts, width / 2
  for k = 1, n do
    local p0, p1 = pts[math.max(1, k - 1)], pts[math.min(n, k + 1)]
    local tx, ty = p1.x - p0.x, p1.y - p0.y
    local l = math.sqrt(tx * tx + ty * ty)
    if l < 1e-9 then l = 1 end
    local nx, ny = -ty / l * half, tx / l * half
    local p = pts[k]
    verts[#verts + 1] = { x = p.x + nx, y = p.y + ny }
    verts[#verts + 1] = { x = p.x - nx, y = p.y - ny }
  end
  return verts
end

local function arc_points(a, n)
  local pts = {}
  for k = 0, n do pts[k + 1] = arc_point(a, k / n) end
  return pts
end

local function wire_key(a, b)
  if a < b then return a .. ":" .. b end
  return b .. ":" .. a
end

local function core_color(k)
  return { r = k.r + (1 - k.r) * 0.55, g = k.g + (1 - k.g) * 0.55, b = k.b + (1 - k.b) * 0.55, a = 1 }
end

-- Layers, bottom to top: outer shine (lit only), tube, core (lit only).
-- The unlit tube is grey whatever the cable colour and covers the copper wire.
local UNLIT_GREY = { r = 0.67, g = 0.67, b = 0.67, a = 1 }

local function tube_color(k, lit)
  if not lit then return UNLIT_GREY end
  return { r = k.r, g = k.g, b = k.b, a = 1 }
end

-- The outer shine is c.glow_layers stacked lines, each narrower than the last,
-- so it is strongest at the centre (GLOW_ALPHA) and fades out to the edge.
local GLOW_ALPHA = 0.8

local function glow_color(c, k)
  local a = GLOW_ALPHA / c.glow_layers
  return { r = k.r * a, g = k.g * a, b = k.b * a, a = a } -- premultiplied
end

local function same_color(p, q)
  if p == nil or q == nil then return p == q end
  return p.r == q.r and p.g == q.g and p.b == q.b
end

local SIG_R = { type = "virtual", name = "signal-red" }
local SIG_G = { type = "virtual", name = "signal-green" }
local SIG_B = { type = "virtual", name = "signal-blue" }
local CIRCUITS = { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }

local function signal_color(pole)
  local r, g, b = 0, 0, 0
  for _, id in pairs(CIRCUITS) do
    local net = pole.get_circuit_network(id)
    if net then
      r = r + net.get_signal(SIG_R)
      g = g + net.get_signal(SIG_G)
      b = b + net.get_signal(SIG_B)
    end
  end
  if r == 0 and g == 0 and b == 0 then return nil end
  local function ch(v) return math.max(0, math.min(255, v)) / 255 end
  return { r = ch(r), g = ch(g), b = ch(b), a = 1 }
end

local function pole_color(un, c)
  local rec = storage.neon[un]
  return (rec and rec.color) or c.color
end

-- Signal colour only if both poles carry the same one.
local function wire_color(w, c)
  local ra, rb = storage.neon[w.a], storage.neon[w.b]
  local ka, kb = ra and ra.color, rb and rb.color
  if ka and kb and same_color(ka, kb) then return ka end
  return c.color
end

local function by_pole(un)
  local t = storage.by_pole[un]
  if not t then t = {}; storage.by_pole[un] = t end
  return t
end

local function create_interface(pole)
  local eei = pole.surface.create_entity{
    name = POWER, position = pole.position, force = pole.force,
    create_build_effect_smoke = false,
  }
  if eei then
    eei.destructible = false
    eei.power_usage = 0
  end
  return eei
end

local function add_neon(pole)
  local un = pole.unit_number
  local rec = storage.neon[un]
  if rec then return rec end
  rec = { pole = pole, eei = create_interface(pole) }
  storage.neon[un] = rec
  return rec
end

local function powered(un)
  local rec = storage.neon[un]
  return rec and rec.eei and rec.eei.valid and rec.eei.energy > 0
end

local function update_pole_light(un, c, redraw)
  local rec = storage.neon[un]
  if not (rec and rec.pole.valid) then return end
  local on = powered(un) or false
  if redraw and rec.light and rec.light.valid then rec.light.destroy() end
  if c.pole_light <= 0 then
    if rec.light and rec.light.valid then rec.light.destroy() end
    rec.light = nil
    return
  end
  local col = pole_color(un, c)
  if not (rec.light and rec.light.valid) then
    rec.light = rendering.draw_light{
      surface = rec.pole.surface, target = rec.pole,
      sprite = "utility/light_medium", scale = POLE_LIGHT_SCALE,
      intensity = c.pole_light, color = col, visible = on,
    }
    rec.light_col = col
  else
    if rec.light.visible ~= on then rec.light.visible = on end
    if not same_color(rec.light_col, col) then
      rec.light.color = col
      rec.light_col = col
    end
  end
end

local function destroy_objects(w)
  for _, list in pairs({ w.core, w.tube, w.glow, w.lights }) do
    for _, o in pairs(list) do if o.valid then o.destroy() end end
  end
  w.core, w.tube, w.glow, w.lights = {}, {}, {}, {}
end

local function draw_wire(w, c)
  destroy_objects(w)
  if not (w.ea.valid and w.eb.valid) then return end

  local a = arc(anchor_of(w.ea), anchor_of(w.eb))
  local len = a.len
  local function point(t) return arc_point(a, t) end

  local surface = w.ea.surface
  local lit = w.lit

  local n = math.max(MIN_SEGS, math.min(MAX_SEGS, math.ceil(len / SEG_LEN)))
  local pts = arc_points(a, n)

  local col = wire_color(w, c)
  w.col = col
  if c.glow_w > 0 then
    local gc = glow_color(c, col)
    for layer = c.glow_layers, 1, -1 do
      local width = c.glow_w * layer / c.glow_layers / 32 -- px to tiles
      w.glow[#w.glow + 1] = rendering.draw_polygon{
        surface = surface, vertices = band(pts, width),
        color = gc, visible = lit,
      }
    end
  end
  -- Round caps on both ends, so cables meeting at a pole join smoothly.
  local ends = { pts[1], pts[n + 1] }
  local tc = tube_color(col, lit)
  for k = 1, n do
    w.tube[#w.tube + 1] = rendering.draw_line{
      surface = surface, from = pts[k], to = pts[k + 1],
      color = tc, width = c.tube_w,
    }
  end
  for _, p in pairs(ends) do
    w.tube[#w.tube + 1] = rendering.draw_circle{
      surface = surface, target = p, radius = c.tube_w / 64, filled = true,
      color = tc,
    }
  end
  local cc = core_color(col)
  for k = 1, n do
    w.core[#w.core + 1] = rendering.draw_line{
      surface = surface, from = pts[k], to = pts[k + 1],
      color = cc, width = c.core_w, visible = lit,
    }
  end
  for _, p in pairs(ends) do
    w.core[#w.core + 1] = rendering.draw_circle{
      surface = surface, target = p, radius = c.core_w / 64, filled = true,
      color = cc, visible = lit,
    }
  end
  if c.light > 0 then
    -- overlapping strips, intensity divided by the overlap
    local nl = math.max(1, math.ceil(len / LIGHT_SPACING))
    local scale = STRIP_LEN * 32 / STRIP_PX
    local intensity = c.light * 2 * (len / nl) / STRIP_LEN
    for k = 0, nl do
      local t = k / nl
      local p = point(t)
      local p0, p1 = point(math.max(0, t - 0.01)), point(math.min(1, t + 0.01))
      local tx, ty = p1.x - p0.x, p1.y - p0.y
      w.lights[k + 1] = rendering.draw_light{
        surface = surface, target = p,
        sprite = "neon-power-cable-light", scale = scale,
        orientation = (math.atan2(ty, tx) / (2 * math.pi)) % 1,
        intensity = intensity, color = col, visible = lit,
      }
    end
  end
end

local function recolor_wire(w, c)
  local col = wire_color(w, c)
  if same_color(w.col, col) then return end
  w.col = col
  local cc, tc, gc = core_color(col), tube_color(col, w.lit), glow_color(c, col)
  for _, o in pairs(w.core) do if o.valid then o.color = cc end end
  for _, o in pairs(w.tube) do if o.valid then o.color = tc end end
  for _, o in pairs(w.glow) do if o.valid then o.color = gc end end
  for _, o in pairs(w.lights) do if o.valid then o.color = col end end
end

local function set_lit(w, c, lit)
  w.lit = lit
  local tc = tube_color(w.col or c.color, lit)
  for _, o in pairs(w.tube) do if o.valid then o.color = tc end end
  for _, o in pairs(w.core) do if o.valid then o.visible = lit end end
  for _, o in pairs(w.glow) do if o.valid then o.visible = lit end end
  for _, o in pairs(w.lights) do if o.valid then o.visible = lit end end
end

local function wire_lit(w)
  return powered(w.a) and powered(w.b) or false
end

local function destroy_wire(key)
  local w = storage.wires[key]
  if not w then return end
  destroy_objects(w)
  storage.wires[key] = nil
  for _, un in pairs({ w.a, w.b }) do
    local t = storage.by_pole[un]
    if t then
      t[key] = nil
      if next(t) == nil then storage.by_pole[un] = nil end
    end
  end
end

local function update_power(un, c)
  local rec = storage.neon[un]
  if not (rec and rec.eei and rec.eei.valid) then return end
  local kw = 0
  for key in pairs(storage.by_pole[un] or {}) do
    local w = storage.wires[key]
    if w then kw = kw + CABLE_KW / 2 end -- each end pays half
  end
  local per_tick = kw * 1000 / 60
  rec.eei.power_usage = per_tick
  rec.eei.electric_buffer_size = math.max(per_tick * 60, 1)
end

-- Neon poles wired to this one; wires to vanilla poles stay plain copper.
local function neon_partners(pole)
  local out = {}
  local conn = pole.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not conn then return out end
  for _, wc in pairs(conn.connections) do
    local o = wc.target and wc.target.owner
    if wc.origin == defines.wire_origin.player and o and o.valid
       and is_neon(o.name) and o.unit_number then
      out[o.unit_number] = o
    end
  end
  return out
end

local function refresh_neon(un, c)
  local rec = storage.neon[un]
  if not rec then return end
  local pole = rec.pole
  if not pole.valid then return end
  if not (rec.eei and rec.eei.valid) then rec.eei = create_interface(pole) end

  local partners = neon_partners(pole)
  local changed = {}
  for pun, other in pairs(partners) do
    local key = wire_key(un, pun)
    if not storage.wires[key] then
      local w = {
        a = un, b = pun, ea = pole, eb = other,
        core = {}, tube = {}, glow = {}, lights = {},
      }
      add_neon(other)
      w.lit = wire_lit(w)
      storage.wires[key] = w
      by_pole(un)[key] = true
      by_pole(pun)[key] = true
      draw_wire(w, c)
      changed[pun] = true
    end
  end
  for key in pairs(storage.by_pole[un] or {}) do
    local w = storage.wires[key]
    local other = w and (w.a == un and w.b or w.a)
    if not w or not partners[other] then
      destroy_wire(key)
      if other then changed[other] = true end
    end
  end
  update_power(un, c)
  for pun in pairs(changed) do update_power(pun, c) end
end

local function remove_pole(un, c)
  local partners = {}
  for key in pairs(storage.by_pole[un] or {}) do
    local w = storage.wires[key]
    if w then partners[w.a == un and w.b or w.a] = true end
    destroy_wire(key)
  end
  storage.by_pole[un] = nil
  local rec = storage.neon[un]
  if rec then
    if rec.eei and rec.eei.valid then rec.eei.destroy() end
    if rec.light and rec.light.valid then rec.light.destroy() end
    storage.neon[un] = nil
  end
  for pun in pairs(partners) do update_power(pun, c) end
end

local function rebuild_all()
  anchors = nil
  rendering.clear("neon-power")
  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered{ name = POWER }) do e.destroy() end
  end
  storage.neon, storage.wires, storage.by_pole, storage.cursor = {}, {}, {}, nil
  for _, surface in pairs(game.surfaces) do
    for _, pole in pairs(surface.find_entities_filtered{ name = NEON_LIST }) do add_neon(pole) end
  end
  local c = cfg()
  for un in pairs(storage.neon) do
    refresh_neon(un, c)
    update_pole_light(un, c)
  end
  storage.draw_sig = DRAW_SIG
end

local function redraw_all()
  local c = cfg()
  for _, w in pairs(storage.wires) do
    if w.ea.valid and w.eb.valid then draw_wire(w, c) end
  end
  for un in pairs(storage.neon) do
    update_power(un, c)
    update_pole_light(un, c, true)
  end
end

script.on_init(rebuild_all)
script.on_configuration_changed(rebuild_all)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(e)
  if e.setting:sub(1, 11) == "neon-power-" then redraw_all() end
end)

-- Only neon poles matter: wires to vanilla poles are left to the game.
local pole_filter = {}
for _, n in pairs(NEON_LIST) do pole_filter[#pole_filter + 1] = { filter = "name", name = n } end

local function on_built(e)
  local pole = e.entity
  if not (pole and pole.valid and pole.unit_number) then return end
  if not is_neon(pole.name) then return end
  add_neon(pole)
  refresh_neon(pole.unit_number, cfg())
end

local function on_removed(e)
  local pole = e.entity
  if pole and pole.valid and pole.unit_number then remove_pole(pole.unit_number, cfg()) end
end

for _, ev in pairs({
  defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built, defines.events.script_raised_revive,
  defines.events.on_space_platform_built_entity,
}) do
  if ev then script.on_event(ev, on_built, pole_filter) end
end

for _, ev in pairs({
  defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity,
  defines.events.on_entity_died, defines.events.script_raised_destroy,
  defines.events.on_space_platform_mined_entity,
}) do
  if ev then script.on_event(ev, on_removed, pole_filter) end
end

script.on_event(defines.events.on_surface_cleared, rebuild_all)
script.on_event(defines.events.on_surface_deleted, rebuild_all)

-- No event exists for manual rewiring, so poles are rescanned round-robin.
script.on_nth_tick(STEP_TICKS, function()
  if storage.draw_sig ~= DRAW_SIG then rebuild_all() end
  local c = cfg()
  local neon = storage.neon
  local k = storage.cursor
  if k ~= nil and neon[k] == nil then k = nil end
  local batch = {}
  for _ = 1, RESCAN_PER_STEP do
    k = next(neon, k)
    if k == nil then break end
    batch[#batch + 1] = k
  end
  storage.cursor = k
  for _, un in pairs(batch) do
    local rec = neon[un]
    if rec and not rec.pole.valid then remove_pole(un, c) else refresh_neon(un, c) end
  end
  for un, rec in pairs(neon) do
    if rec.pole.valid then rec.color = signal_color(rec.pole) end
    update_pole_light(un, c)
  end

  for key, w in pairs(storage.wires) do
    if not (w.ea.valid and w.eb.valid) then
      destroy_wire(key)
    else
      local lit = wire_lit(w)
      if lit ~= w.lit then set_lit(w, c, lit) end
      recolor_wire(w, c)
    end
  end
end)

commands.add_command("neon-power-rebuild", "Rebuild all neon cables.", function()
  rebuild_all()
end)
