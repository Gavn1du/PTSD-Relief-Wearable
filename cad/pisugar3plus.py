"""STEP model of the PiSugar 3 Plus (5000 mAh) for Raspberry Pi 3B/4B/5.

Run headless:  /Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd cad/pisugar3plus.py

The board is PiSugar's official model (vendor/pisugar3plus.STEP, GPL-3.0).
The 5000 mAh pouch cell, its magnet disc and the battery lead are added
here from product photos (about +/-1-2 mm), so verify them before designing
tight features.

Frame (mm) matches ups_hat_b.py, so both models drop into a case at the same
origin with the mounting holes coinciding at (23.5|81.5, 3.5|52.5):
  * XY: Pi footprint seen from above, Pi rotated 180 deg (GPIO header along Y~3.5).
  * Z=0 is the PCB face toward the battery. The 1.0 mm PCB spans Z 0..1.
  * +Z faces the Pi. The Pi's underside rests on the board's nuts at Z=2.6.
  * Components, the battery and the lead hang below Z=0.
"""
import math
import os
from pathlib import Path
import FreeCAD as App
import Part

OUT = Path(__file__).resolve().parent
VENDOR = OUT / 'vendor' / 'pisugar3plus.STEP'
NAME = 'PiSugar-3-Plus'
V = App.Vector

# The vendor file is Y-up with the board centred on the origin. Rotate +90 deg
# about X and shift so its holes land on the Pi/HAT hole pattern.
VENDOR_PLACEMENT = App.Placement(V(52.5, 28.0, 0.0), App.Rotation(V(1, 0, 0), 90))

P = dict(
    # Pouch cell: inner end clears the 1R0 inductor (ends at x=72.3), outer
    # end overhangs the board's x=20 edge, staying inside the Pi outline.
    batt_x=(4.8, 71.8), batt_y=(0.5, 55.5), batt_z=(-12.4, -3.4), batt_r=2.0,
    # Steel/magnet disc on the cell, mating the board magnet at (35, 28).
    disc_xy=(35.0, 28.0), disc_d=14.0,
    # Lead keep-out from the PH2.0 socket, out past the x=85 edge, back to the cell
    lead_r=1.6,
    lead_pts=[(82.0, 13.1, -3.1), (86.0, 13.1, -3.4), (87.8, 9.0, -4.5),
              (87.0, 3.0, -6.5), (83.0, 1.6, -7.6), (75.0, 1.6, -7.9),
              (71.8, 1.6, -7.9)],
)

COLORS = dict(pcb=(0.10, 0.10, 0.11), cell=(0.16, 0.16, 0.17),
              metal=(0.78, 0.78, 0.80), lead=(0.80, 0.10, 0.10))


def rounded_box(x0, x1, y0, y1, z0, z1, r):
    b = Part.makeBox(x1 - x0, y1 - y0, z1 - z0, V(x0, y0, z0))
    vertical = [e for e in b.Edges
                if abs(e.Vertexes[0].Point.z - e.Vertexes[1].Point.z) > 1e-6]
    return b.makeFillet(r, vertical)


def board():
    s = Part.read(str(VENDOR))
    s.Placement = VENDOR_PLACEMENT
    return s


def battery():
    (x0, x1), (y0, y1), (z0, z1) = P['batt_x'], P['batt_y'], P['batt_z']
    return rounded_box(x0, x1, y0, y1, z0, z1, P['batt_r'])


def battery_disc():
    x, y = P['disc_xy']
    z1 = -2.0  # face of the board magnet in the vendor model
    z0 = P['batt_z'][1]
    return Part.makeCylinder(P['disc_d'] / 2, z1 - z0, V(x, y, z0))


def battery_lead():
    pts = [V(*p) for p in P['lead_pts']]
    spine = Part.BSplineCurve()
    spine.interpolate(pts)
    path = Part.Wire(spine.toShape())
    t = spine.tangent(spine.FirstParameter)[0]
    ring = Part.Wire(Part.makeCircle(P['lead_r'], pts[0], t))
    return path.makePipeShell([ring], True, True)


def build():
    doc = App.newDocument(NAME.replace('-', '_'))
    assy = doc.addObject('App::Part', 'PiSugar3Plus')
    assy.Label = 'PiSugar 3 Plus'
    parts = []

    def add(label, shape, color):
        o = doc.addObject('Part::Feature', label.replace(' ', '_').replace('-', '_'))
        o.Label = label
        o.Shape = shape
        assy.addObject(o)
        parts.append((o, color))

    add('PiSugar 3 Plus board (vendor)', board(), COLORS['pcb'])
    add('Battery 5000mAh pouch', battery(), COLORS['cell'])
    add('Battery magnet disc', battery_disc(), COLORS['metal'])
    add('Battery lead keep-out', battery_lead(), COLORS['lead'])

    for o, c in parts:
        if not o.Shape.isValid() or not o.Shape.Solids:
            raise RuntimeError('%s is not a valid solid' % o.Label)
        if App.GuiUp:
            o.ViewObject.ShapeColor = c
    doc.recompute()

    doc.saveAs(str(OUT / (NAME + '.FCStd')))
    import Import
    Import.export([assy], str(OUT / (NAME + '.step')))

    preview = os.environ.get('PISUGAR_PREVIEW_DIR')
    if preview:  # per-part STL + colour list for a Blender preview render
        import MeshPart
        Path(preview).mkdir(parents=True, exist_ok=True)
        with open(Path(preview) / 'colors.txt', 'w') as f:
            for o, c in parts:
                MeshPart.meshFromShape(Shape=o.Shape, LinearDeflection=0.05,
                                       AngularDeflection=0.3).write(str(Path(preview) / (o.Name + '.stl')))
                f.write('%s %.3f %.3f %.3f\n' % ((o.Name,) + c))

    # Sanity checks: holes on the shared pattern, battery clear of the board parts
    b = parts[0][0].Shape
    for x, y in [(23.5, 3.5), (81.5, 3.5), (23.5, 52.5), (81.5, 52.5)]:
        if b.isInside(V(x, y, 0.5), 0.01, True):
            raise RuntimeError('No mounting hole at (%.1f, %.1f)' % (x, y))
    for o, _ in parts[1:]:
        clash = b.common(o.Shape).Volume
        print('RESULT %s overlap with board: %.3f mm^3' % (o.Label, clash))
    bb = Part.makeCompound([o.Shape for o, _ in parts]).BoundBox
    print('RESULT bbox X %.1f..%.1f  Y %.1f..%.1f  Z %.1f..%.1f' %
          (bb.XMin, bb.XMax, bb.YMin, bb.YMax, bb.ZMin, bb.ZMax))
    return doc


build()
