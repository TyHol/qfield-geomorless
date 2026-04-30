# QField Geomless Plugin

A [QField](https://qfield.org) plugin for quickly adding features to any editable layer — with or without geometry. Works with point, line, and polygon layers.

*The plugin adds a single button to the QField canvas.*

---

## Features

- **Browse or edit existing records** with a short press
- **Add a feature** (geometryless, GPS location, or screen centre) with a long press
- Add a **point feature at your GPS location** or the **map screen centre**
- Add a **line feature** extending from the GPS/screen location at a configurable bearing and length
- Add a **polygon feature** as a regular circle approximation around the GPS/screen location
- Two **layer modes** — Fixed (always use a set layer) or Dynamic (pick the layer each time)
- Configurable **radius/length**, **polygon vertices**, and **line bearing**
- All settings persist between sessions

---

## Installation

1. Copy the `qfield-geomless` folder into your QField plugins directory:
   - Android: `<QField data folder>/QField/plugins/`
   - The plugin folder should contain `main.qml` and `geom-less.svg`
2. Open QField, go to **Settings → Plugins** and enable **Geomless**
3. The button appears in the plugins toolbar.

Scan to download zip:
<img width="381" height="376" alt="image" src="https://github.com/user-attachments/assets/235f6969-6231-4f69-9849-7fbb6b094b6f" />

---

## Button actions

| Press | Action |
|---|---|
| Short press | Browse records in the target layer |
| Long press | Create a new feature |
| Very long press (~2 s) | Open settings |

---

## Usage

### Short press — browse records

Opens the feature list for the target layer. If the layer has a single record the attribute form opens directly; if it has multiple records the full feature list is shown.

---

### Long press — add a feature

Behaviour depends on the **Short-press action** setting:

| Action | Point layer | Line layer | Polygon layer |
|---|---|---|---|
| Geometryless | Empty geometry | Empty geometry | Empty geometry |
| GPS location | Point at GPS fix | Line from GPS fix | Circle around GPS fix |
| Screen centre | Point at map centre | Line from map centre | Circle around map centre |

The attribute form opens immediately after the feature is created so you can fill in values.

#### GPS inactive

If **GPS location** is selected but GPS has no valid fix, a dialog offers three options:

- **Create at screen centre** — places the feature at the current map view centre
- **Create geometryless feature** — adds the feature with no geometry
- **Cancel** — abandons the action

---

## Settings

Open settings by holding the toolbar button for ~2 seconds.

### Layer mode

| Mode | Behaviour |
|---|---|
| **Fixed** (default) | Always uses the layer selected in the Target layer dropdown |
| **Dynamic** | A layer picker appears on every create or browse action; the most recently used layer is pre-selected |

### Target layer (Fixed mode only)

Select the layer features will be added to. Defaults to the **active layer** if none is selected. The layer list shows all editable layers in the current project.

### Short-press action

Controls the geometry placed when creating a new feature:

| Option | Description |
|---|---|
| Geometryless | Creates a feature with no geometry — works on all layer types |
| GPS location | Places the feature at your current GPS position |
| Screen centre | Places the feature at the centre of the map view |

### Shape settings

Used when creating line or polygon features with the GPS or screen-centre actions:

| Setting | Default | Description |
|---|---|---|
| Radius / length (m) | 10 | Polygon radius or line length in metres |
| Polygon vertices (≥3) | 16 | Number of vertices in the circle approximation |
| Line bearing (°) | 0 | Direction the line extends from the start point. 0 = north, 90 = east, clockwise. Uses grid north (= true north for geographic CRS). |

The bearing also rotates the polygon so the first vertex points in the set direction — useful for triangles or other non-circular shapes.

> **Note on bearing:** The plugin uses **grid north** (aligned to the map CRS). For geographic CRS (e.g. WGS84/EPSG:4326) this equals true north. For projected CRS it may differ slightly from true north due to meridian convergence — typically 1–3° for most areas, negligible for field use. Magnetic north is not supported directly; apply your local declination manually if needed.

---

## Notes

- Metre-to-CRS conversion handles geographic (degrees), metres, feet, nautical miles, kilometres, and yards automatically
- Settings always reachable by holding the button for ~2 seconds

---

## Licence

GPL v2 or later
