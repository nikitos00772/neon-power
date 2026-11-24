# Neon Power

Neon versions of every power pole, connected by glowing neon cables.

Looks best without night vision.

## Features

- **Neon small, medium and big electric poles and neon substation**, with the same stats as their vanilla versions. All four are unlocked by the **Neon power** technology (after Electric energy distribution 2 and Advanced circuits).
- **Neon cables** between neon poles: a bright core inside a coloured tube, with a soft outer shine and light at night. A cable lights up only while both of its poles have power and draws 1 kW, shared by the two poles. Unlit cables are a grey tube.
- Cables hang exactly like vanilla wires and are drawn over them, so wire previews still show when you build poles.
- A wire from a neon pole to a vanilla pole stays a plain copper wire.
- **Circuit colour:** send `signal-red`, `signal-green` and `signal-blue` (0–255) to a neon pole on a red or green wire, like a lamp in RGB mode.
  - The pole's light takes that colour.
  - A cable takes it when both of its poles carry the same colour signal.
- **Upgrade planner:** vanilla poles upgrade to their neon versions.

## Settings

Map settings, applied immediately: neon colour, core width, tube width, outer shine width and smoothness, cable light and pole light at night.

## Commands

- `/neon-power-rebuild`: redraw all neon cables.

## Recipes

Each neon pole is made from its vanilla pole + 1 advanced circuit and 2 plastic bars.

## Feedback

Found a bug, a mod conflict or something that looks off?
Open an issue on [GitHub](https://github.com/nikitos00772/neon-power/issues) or post on the mod portal's discussion page.

## License

The code is MIT; see [LICENSE](https://github.com/nikitos00772/neon-power/blob/master/LICENSE). The thumbnail is derived from Factorio's own art and stays © Wube Software (listed in LICENSE).
