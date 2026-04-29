# QField Geomless Plugin

A [QField](https://qfield.org) plugin for quickly adding features to any editable layer — with or without geometry. Works with point, line, and polygon layers.

![Plugin toolbar button](images/toolbar_button.png)
*The plugin adds a single button to the QField toolbar.*

---

## Features

- Add a **geometryless (attribute-only) feature** to any editable layer with one tap
- Add a **point feature at your GPS location** or the **map screen centre**
- Add a **line feature** extending from the GPS/screen location at a configurable bearing and length
- Add a **polygon feature** as a regular circle approximation around the GPS/screen location
- Configurable **target layer** (defaults to the active layer)
- Configurable **radius/length**, **polygon vertices**, and **line bearing**
- Browse or edit existing records via long press
- All settings persist between sessions

---

## Installation

1. Copy the `qfield-geomless` folder into your QField plugins directory:
   - Android: `<QField data folder>/QField/plugins/`
   - The plugin folder should contain `main.qml` and `geom-less.svg`
2. Open QField, go to **Settings → Plugins** and enable **Geomless**
3. The button appears in the plugins toolbar

---

## Usage

### Short press — add a feature

Behaviour depends on the **Short-press action** setting:

| Action | Point layer | Line layer | Polygon layer |
|---|---|---|---|
| Geometryless | Empty geometry | Empty geometry | Empty geometry |
| GPS location | Point at GPS fix | Line from GPS fix | Circle around GPS fix |
| Screen centre | Point at map centre | Line from map centre | Circle around map centre |

The attribute form opens immediately after the feature is created so you can fill in values.

#### GPS inactive

If **GPS location** is selected but GPS has no valid fix, a confirmation dialog appears:

Choose **Yes** to add a geometryless feature instead, or **No** to cancel.

---

### Long press — browse records or open settings

Configurable in settings:

- **Open settings on long press** (default) — opens the settings dialog
- **Open records** — opens the first record in the target layer, or the full feature list if there are multiple. Keep holding (~2 seconds total) to reach settings regardless.

---

## Settings

Open settings by long-pressing the toolbar button (or keep holding ~2 seconds if long press is set to browse records).

### Target layer

Select the layer features will be added to. Defaults to the **active layer** if none is selected. The layer list shows all editable layers in the current project.

### Short-press action

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

### Long-press action

Toggle whether long press opens settings or browses existing records in the target layer.

---

## Notes

- Metre-to-CRS conversion handles geographic (degrees), metres, feet, nautical miles, kilometres, and yards automatically
- The settings dialog can always be reached by holding the button for ~2 seconds, even if long press is set to browse records

---

## Licence

GPL v2 or later
