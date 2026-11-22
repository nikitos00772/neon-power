local NEON = "neon-power-pole"
local POWER = "neon-power-interface"
local CABLE_KW = 1
local VANILLA_WIRE = require("config").vanilla_wire

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

-- Vanilla wire geometry: the copper-wire.png arc along the chord, bulging
-- by |cos| (wire, downward) or |sin| (shadow, to the left) of its angle.
local WIRE_SPRITE = "neon-power-wire"
local SHADOW_SPRITE = "neon-power-wire-shadow"
local STRIP_TILES = 0.25
local WIRE_DEPTH = 46.9 / 64
local END_OFF = 2.33 / 64
local SHORT_LEN = 2.93
local PROFILE = {
  0.0, 0.1569, 0.2944, 0.4136, 0.517, 0.6082, 0.6859, 0.7545, 0.8121, 0.8624,
  0.9031, 0.936, 0.9617, 0.9805, 0.9948, 1.0, 1.0, 1.0, 0.9948, 0.9805, 0.9617,
  0.936, 0.9031, 0.8624, 0.8121, 0.7545, 0.6859, 0.6082, 0.517, 0.4136, 0.2944,
  0.1569, 0.0,
}
local SHADE = { x = 0.5, y = 1 }

-- Saved cables are redrawn when this changes; bump DRAW_REV for drawing changes.
local DRAW_REV = 6
local DRAW_SIG = table.concat({ DRAW_REV, tostring(VANILLA_WIRE), WIRE_DEPTH, END_OFF, SHORT_LEN, SEG_LEN, MIN_SEGS, MAX_SEGS,
  LIGHT_SPACING, STRIP_LEN, POLE_LIGHT_SCALE, STRIP_TILES, SHADE.x, SHADE.y }, "|")

local anchors

local function cfg()
  local g = settings.global
  return {
    color   = g["neon-power-color"].value,
    core_w  = g["neon-power-core-width"].value,
    glow_w  = g["neon-power-glow-width"].value,
    glow_a  = g["neon-power-glow-strength"].value,
    light   = g["neon-power-light-strength"].value,
    kw      = CABLE_KW,
  }
end

local function anchor_of(pole)
  if not anchors then
    local md = prototypes.mod_data["neon-power-anchors"]
    anchors = md and md.data or {}
  end
  local o = anchors[pole.name] or DEFAULT_ANCHOR
  local p = pole.position
  local sx, sy = o.sx or (o.x + 2), o.sy or 0
  return { x = p.x + o.x, y = p.y + o.y }, { x = p.x + sx, y = p.y + sy }
end

local function profile(t)
  local f = t * 32
  local i = math.max(0, math.min(31, math.floor(f)))
  local u = f - i
  return PROFILE[i + 1] * (1 - u) + PROFILE[i + 2] * u
end

local function arc(pa, pb, shadow)
  local dx, dy = pb.x - pa.x, pb.y - pa.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1e-6 then len = 1e-6 end
  local nx, ny = -dy / len, dx / len
  local scale
  if shadow then
    if nx > 0 then nx, ny = -nx, -ny end
    scale = math.abs(dy) / len
  else
    if ny < 0 then nx, ny = -nx, -ny end
    scale = math.abs(dx) / len
  end
  scale = scale * math.min(1, len / SHORT_LEN)
  return { x = pa.x, y = pa.y, dx = dx, dy = dy, len = len, nx = nx, ny = ny, scale = scale }
end

local function arc_point(a, t)
  local d = a.scale * (WIRE_DEPTH * profile(t) - END_OFF)
  return { x = a.x + a.dx * t + a.nx * d, y = a.y + a.dy * t + a.ny * d }
end

local function arc_points(a, n)
  local pts = {}
  for k = 0, n do pts[k + 1] = arc_point(a, k / n) end
  return pts
end

local function draw_strip(pts, surface, sprite, visible, list)
  for k = 1, #pts - 1 do
    local f, t = pts[k], pts[k + 1]
    local sx, sy = t.x - f.x, t.y - f.y
    if -sy * SHADE.x + sx * SHADE.y < 0 then sx, sy = -sx, -sy end
    list[#list + 1] = rendering.draw_sprite{
      surface = surface, sprite = sprite, render_layer = "wires-above",
      target = { x = (f.x + t.x) / 2, y = (f.y + t.y) / 2 },
      orientation = (math.atan2(sy, sx) / (2 * math.pi)) % 1,
      x_scale = math.sqrt(sx * sx + sy * sy) / STRIP_TILES * 1.1, y_scale = 1,
      visible = visible,
    }
  end
end

local function wire_key(a, b)
  if a < b then return a .. ":" .. b end
  return b .. ":" .. a
end

local function core_color(k)
  return { r = k.r + (1 - k.r) * 0.55, g = k.g + (1 - k.g) * 0.55, b = k.b + (1 - k.b) * 0.55, a = 1 }
end

local function unlit_color(k)
  return { r = 0.12 + k.r * 0.3, g = 0.12 + k.g * 0.3, b = 0.12 + k.b * 0.3, a = 1 }
end

local function core_look(k, lit)
  if lit then return core_color(k), true end
  return unlit_color(k), VANILLA_WIRE
end

local function glow_color(c, k)
  local a = c.glow_a
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

local function end_color(un, ent, cache)
  local rec = storage.neon[un]
  if rec then return rec.color end
  if not ent.valid then return nil end
  if cache then
    local v = cache[un]
    if v == nil then v = signal_color(ent) or false; cache[un] = v end
    return v or nil
  end
  return signal_color(ent)
end

-- Signal colour only if both poles carry the same one.
local function wire_color(w, c, cache)
  local ka = end_color(w.a, w.ea, cache)
  local kb = end_color(w.b, w.eb, cache)
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
  if c.light <= 0 then
    if rec.light and rec.light.valid then rec.light.destroy() end
    rec.light = nil
    return
  end
  local col = pole_color(un, c)
  if not (rec.light and rec.light.valid) then
    rec.light = rendering.draw_light{
      surface = rec.pole.surface, target = rec.pole,
      sprite = "utility/light_medium", scale = POLE_LIGHT_SCALE,
      intensity = c.light, color = col, visible = on,
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
  for _, list in pairs({ w.core, w.glow, w.lights, w.tex, w.shadow }) do
    for _, o in pairs(list) do if o.valid then o.destroy() end end
  end
  w.core, w.glow, w.lights, w.tex, w.shadow = {}, {}, {}, {}, {}
end

local function draw_wire(w, c)
  destroy_objects(w)
  if not (w.ea.valid and w.eb.valid) then return end

  local pa, sa = anchor_of(w.ea)
  local pb, sb = anchor_of(w.eb)
  local a = arc(pa, pb)
  local len = a.len
  local function point(t) return arc_point(a, t) end

  local surface = w.ea.surface
  local lit = w.lit

  local n = math.max(MIN_SEGS, math.min(MAX_SEGS, math.ceil(len / SEG_LEN)))
  local pts = arc_points(a, n)

  if not VANILLA_WIRE then
    draw_strip(pts, surface, WIRE_SPRITE, not lit, w.tex)
    draw_strip(arc_points(arc(sa, sb, true), n), surface, SHADOW_SPRITE, true, w.shadow)
  end

  local col = wire_color(w, c)
  w.col = col
  if c.glow_w > 0 and c.glow_a > 0 then
    local gc = glow_color(c, col)
    for k = 1, n do
      w.glow[k] = rendering.draw_line{
        surface = surface, from = pts[k], to = pts[k + 1],
        color = gc, width = c.glow_w, visible = lit,
      }
    end
  end
  local cc, core_vis = core_look(col, lit)
  for k = 1, n do
    local f, t = pts[k], pts[k + 1]
    w.core[k] = rendering.draw_line{
      surface = surface, from = f, to = t,
      color = cc, width = c.core_w, visible = core_vis,
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

local function recolor_wire(w, c, cache)
  local col = wire_color(w, c, cache)
  if same_color(w.col, col) then return end
  w.col = col
  local cc, gc = core_look(col, w.lit), glow_color(c, col)
  for _, o in pairs(w.core) do if o.valid then o.color = cc end end
  for _, o in pairs(w.glow) do if o.valid then o.color = gc end end
  for _, o in pairs(w.lights) do if o.valid then o.color = col end end
end

local function set_lit(w, c, lit)
  w.lit = lit
  local cc, core_vis = core_look(w.col or c.color, lit)
  for _, o in pairs(w.core) do
    if o.valid then o.visible = core_vis; o.color = cc end
  end
  for _, o in pairs(w.tex or {}) do if o.valid then o.visible = not lit end end
  for _, o in pairs(w.glow) do if o.valid then o.visible = lit end end
  for _, o in pairs(w.lights) do if o.valid then o.visible = lit end end
end

local function wire_lit(w)
  if w.na and not powered(w.a) then return false end
  if w.nb and not powered(w.b) then return false end
  return true
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
    if w then kw = kw + ((w.na and w.nb) and c.kw / 2 or c.kw) end
  end
  local per_tick = kw * 1000 / 60
  rec.eei.power_usage = per_tick
  rec.eei.electric_buffer_size = math.max(per_tick * 60, 1)
end

local function partners_of(pole)
  local out = {}
  local conn = pole.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not conn then return out end
  for _, wc in pairs(conn.connections) do
    local o = wc.target and wc.target.owner
    if wc.origin == defines.wire_origin.player and o and o.valid
       and o.type == "electric-pole" and o.unit_number then
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

  local partners = partners_of(pole)
  local changed = {}
  for pun, other in pairs(partners) do
    local key = wire_key(un, pun)
    if not storage.wires[key] then
      local w = {
        a = un, b = pun, ea = pole, eb = other,
        na = true, nb = is_neon(other.name),
        core = {}, glow = {}, lights = {}, tex = {}, shadow = {},
      }
      if w.nb then add_neon(other) end
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

local pole_filter = { { filter = "type", type = "electric-pole" } }

local function on_built(e)
  local pole = e.entity
  if not (pole and pole.valid and pole.unit_number) then return end
  local c = cfg()
  if is_neon(pole.name) then
    add_neon(pole)
    refresh_neon(pole.unit_number, c)
  end
  for pun, other in pairs(partners_of(pole)) do
    if is_neon(other.name) then
      add_neon(other)
      refresh_neon(pun, c)
    end
  end
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
  local ref = storage.ref_surface
  if ref and game.tick > ref.tick then
    if game.surfaces[ref.name] then game.delete_surface(ref.name) end
    storage.ref_surface = nil
  end
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

  local cache = {}
  for key, w in pairs(storage.wires) do
    if not (w.ea.valid and w.eb.valid) then
      destroy_wire(key)
    else
      local lit = wire_lit(w)
      if lit ~= w.lit then set_lit(w, c, lit) end
      recolor_wire(w, c, cache)
    end
  end
end)

commands.add_command("neon-power-rebuild", "Rebuild all neon cables.", function()
  rebuild_all()
end)

local REF_PAIRS = {
  { 0, 0, 2, 0 }, { 0, 4, 4, 4 }, { 0, 8, 6, 8 }, { 0, 12, 9, 12 },
  { 12, 0, 12, 4 }, { 12, 7, 12, 15 },
  { 15, 0, 21, 6 }, { 15, 9, 23, 13 }, { 16, 16, 22, 13 },
  { 0, 16, 1, 16 }, { 3, 16, 6, 16 }, { 8, 15, 10, 16 }, { 23, 0, 24, 1 }, { 23, 4, 24, 7 },
}
local REF_BLOCK = 30

commands.add_command("neon-power-wire-reference",
  "Build vanilla + neon reference wires on a new surface and screenshot them to script-output/neon-power/.",
  function(cmd)
    local s = game.create_surface("neon-wire-reference-" .. game.tick)
    s.generate_with_lab_tiles = true
    s.always_day = true
    s.request_to_generate_chunks({ REF_BLOCK, 8 }, 3)
    s.force_generate_chunk_requests()
    local c = cfg()
    for block, name in pairs({ "medium-electric-pole", NEON }) do
      local bx = (block - 1) * REF_BLOCK
      local made = {}
      local function pole(x, y)
        local key = x .. "," .. y
        if not made[key] then
          made[key] = s.create_entity{ name = name, position = { bx + x + 0.5, y + 0.5 }, force = "player" }
        end
        return made[key]
      end
      for _, p in pairs(REF_PAIRS) do pole(p[1], p[2]); pole(p[3], p[4]) end
      for _, e in pairs(made) do
        e.get_wire_connector(defines.wire_connector_id.pole_copper, true).disconnect_all()
      end
      for _, p in pairs(REF_PAIRS) do
        pole(p[1], p[2]).get_wire_connector(defines.wire_connector_id.pole_copper, true)
          .connect_to(pole(p[3], p[4]).get_wire_connector(defines.wire_connector_id.pole_copper, true), false)
      end
      if name == NEON then
        for _, e in pairs(made) do add_neon(e) end
        for _, e in pairs(made) do refresh_neon(e.unit_number, c) end
      end
      game.take_screenshot{
        surface = s, position = { bx + 12.5, 7.5 }, resolution = { 1664, 1536 }, zoom = 2,
        path = "neon-power/" .. (block == 1 and "vanilla" or "neon") .. ".png",
        show_entity_info = false, show_gui = false, daytime = 0, anti_alias = false, force_render = true,
      }
    end
    local player = cmd.player_index and game.get_player(cmd.player_index)
    storage.ref_surface = { name = s.name, tick = game.tick }
    if player then player.print("Neon Power: reference screenshots saved to script-output/neon-power/") end
  end)
