# Neon Power

Neon versions of every power pole, connected by glowing neon cables.

## Features

- **Neon small, medium and big electric poles and neon substation**, with the same stats as their vanilla versions. All four are unlocked by the **Neon power** technology (after Electric energy distribution 2 and Advanced circuits).
- **Glowing cables** with a bright core, a soft glow and light at night. They light up only while the pole has power and draw 1 kW per cable.
- **Circuit colour:** send `signal-red`, `signal-green` and `signal-blue` (0–255) to a neon pole on a red or green wire, like a lamp in RGB mode.
  - The pole's light takes that colour.
  - A cable takes it when both of its poles carry the same colour signal.
- **Upgrade planner:** vanilla poles upgrade to their neon versions.
- Neon cables run only between neon poles; a wire from a neon pole to a vanilla pole stays a plain copper wire.

## Commands

- `/neon-power-rebuild`: redraw all neon cables.

## Recipes

Each neon pole is made from its vanilla pole + 1 advanced circuit and 2 plastic bars.

## License

The code is MIT; see [LICENSE](LICENSE). Some graphics are derived from Factorio's own assets and stay © Wube Software (listed in LICENSE).
