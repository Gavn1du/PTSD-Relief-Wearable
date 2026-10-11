"""Approximate STEP model of the Waveshare 20567 UPS HAT (B) for Raspberry Pi.

Run headless:  /Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd cad/ups_hat_b.py

Frame (mm): top view, component side up. Origin = bottom-left PCB corner,
X along the 85 mm edge, Y along the 56 mm edge, Z=0 at the PCB underside.
The 8.4V jack / USB-A / ON-OFF switch sit on the +Y edge, BOOT on the +X edge,
the 2x18650 holder hangs below Z=0.

Board outline and hole pattern come from the Waveshare drawing (exact).
Component positions/sizes were measured from product photos (±~1 mm);
heights are typical datasheet values for those parts. Verify before
designing tight-fitting features.
"""
import math
import os
from pathlib import Path
import FreeCAD as App
import Part

OUT = Path(__file__).resolve().parent
NAME = 'Waveshare-UPS-HAT-B'
V = App.Vector

P = dict(
    pcb_l=85.0, pcb_w=56.0, pcb_t=1.6, corner_r=3.0, hole_d=3.0,
    holes=[(23.5, 3.5), (81.5, 3.5), (23.5, 52.5), (81.5, 52.5)],
    # 2x18650 holder on the underside
    holder_x=(0.8, 82.9), holder_y=(6.8, 48.3), holder_h=20.0, holder_wall=1.2,
    cell_d=18.4, cell_l=65.0, cell_x0=9.3, cell_y=(18.0, 37.1),
    # Brass standoffs supplied with the kit (Pi sits on top, rotated 180°)
    standoff_h=10.0, standoff_af=5.0,
    # Pogo pins: under Pi GPIO pins 2/4/6 (5V, 5V, GND) with the Pi rotated 180°
    pogo_xy=[(76.63, 2.23), (74.09, 2.23), (71.55, 2.23)], pogo_h=8.0,
)
T = P['pcb_t']

COLORS = dict(pcb=(0.05, 0.25, 0.65), black=(0.08, 0.08, 0.08),
              metal=(0.78, 0.78, 0.80), brass=(0.80, 0.65, 0.25),
              gold=(0.90, 0.72, 0.20), cell=(0.95, 0.72, 0.80),
              grey=(0.45, 0.45, 0.47), white=(0.92, 0.92, 0.92))


def box(x0, y0, z0, dx, dy, dz):
    return Part.makeBox(dx, dy, dz, V(x0, y0, z0))


def cbox(cx, cy, z0, dx, dy, dz):
    """Box centred in XY, starting at z0."""
    return box(cx - dx / 2, cy - dy / 2, z0, dx, dy, dz)


def rounded_rect(x0, y0, x1, y1, r, z, h):
    pts = [(x0 + r, y0), (x1 - r, y0), (x1, y0 + r), (x1, y1 - r),
           (x1 - r, y1), (x0 + r, y1), (x0, y1 - r), (x0, y0 + r)]
    p = [V(x, y, z) for x, y in pts]
    d = r / math.sqrt(2)
    mids = [V(x1 - r + d, y0 + r - d, z), V(x1 - r + d, y1 - r + d, z),
            V(x0 + r - d, y1 - r + d, z), V(x0 + r - d, y0 + r - d, z)]
    edges = []
    for j in range(4):
        i = 2 * j
        edges.append(Part.makeLine(p[i], p[i + 1]))
        edges.append(Part.Arc(p[i + 1], mids[j], p[(i + 2) % 8]).toShape())
    return Part.Face(Part.Wire(edges)).extrude(V(0, 0, h))


def hexagon(cx, cy, z0, af, h):
    r = af / math.sqrt(3)
    pts = [V(cx + r * math.cos(math.radians(60 * k)),
             cy + r * math.sin(math.radians(60 * k)), z0) for k in range(7)]
    return Part.Face(Part.makePolygon(pts)).extrude(V(0, 0, h))


def pcb():
    s = rounded_rect(0, 0, P['pcb_l'], P['pcb_w'], P['corner_r'], 0, T)
    for x, y in P['holes']:
        s = s.cut(Part.makeCylinder(P['hole_d'] / 2, T + 2, V(x, y, -1)))
    return s


def battery_holder():
    (x0, x1), (y0, y1) = P['holder_x'], P['holder_y']
    h, w = P['holder_h'], P['holder_wall']
    floor = 1.5  # plastic between PCB and cells
    s = box(x0, y0, -h, x1 - x0, y1 - y0, h)
    ym = (y0 + y1) / 2
    for a, b in ((y0 + w, ym - 0.5), (ym + 0.5, y1 - w)):
        s = s.cut(box(x0 + 2.5, a, -h - 1, x1 - x0 - 5.0, b - a, h + 1 - floor))
    # Finger cut-outs in the long walls (visible in product photos)
    for yy in (y0 - 1, y1 - w - 1):
        s = s.cut(box(x0 + 22, yy, -h - 1, x1 - x0 - 44, w + 2, 9.0))
    return s


def cells():
    out = []
    zc = -1.5 - P['cell_d'] / 2
    for y in P['cell_y']:
        c = Part.makeCylinder(P['cell_d'] / 2, P['cell_l'],
                              V(P['cell_x0'], y, zc), V(1, 0, 0))
        out.append(c)
    return Part.makeCompound(out)


def holder_contacts():
    out = []
    zc = -1.5 - P['cell_d'] / 2
    (x0, x1) = P['holder_x']
    for y in P['cell_y']:
        for x in (x0 + 2.6, x1 - 3.6):
            out.append(cbox(x + 0.5, y, zc - 5, 1.0, 9.0, 10.0))
    return Part.makeCompound(out)


def dc_jack():
    # 8.4 V charging input, barrel opening facing +Y, overhangs edge ~1.5 mm
    cx, h = 36.2, 10.5
    s = cbox(cx, 51.5, T, 9.0, 12.0, h)
    s = s.cut(Part.makeCylinder(3.2, 10.0, V(cx, 58.0, T + 6.0), V(0, -1, 0)))
    pin = Part.makeCylinder(1.0, 9.0, V(cx, 57.5, T + 6.0), V(0, -1, 0))
    return s, pin


def usb_a():
    # 5 V OUT USB-A receptacle, opening facing +Y, front ~flush/overhang 1 mm
    cx, w, h, l = 52.1, 13.2, 7.0, 14.0
    shell = cbox(cx, 57.0 - l / 2, T, w, l, h)
    shell = shell.cut(cbox(cx, 57.0 - 5.0, T + 0.6, 12.2, 10.2, 5.8))
    tongue = cbox(cx, 57.0 - 4.5, T + 3.4, 11.0, 8.0, 1.8)
    return shell, tongue


def slide_switch():
    # ON/OFF switch, actuator sliding along X and sticking out past +Y edge
    body = box(62.7, 49.6, T, 13.4, 6.4, 4.5)
    lever = cbox(70.4, 57.8, T + 1.2, 3.0, 4.4, 2.2)
    return body, lever


def boot_button():
    # Side-actuated tact switch on the +X edge
    body = box(81.5, 40.5, T, 3.5, 7.2, 3.5)
    knob = cbox(85.4, 43.6, T + 1.0, 0.8, 2.4, 1.5)
    return body, knob


def inductor():
    return cbox(60.2, 36.0, T, 10.5, 10.5, 4.0)


def ics():
    out = []
    for x in (14.8, 25.8):
        for y in (38.0, 28.2, 18.3):
            out.append(cbox(x, y, T, 5.0, 4.0, 1.75))
    out.append(cbox(38.2, 27.1, T, 4.0, 5.0, 1.75))
    out.append(cbox(56.8, 25.2, T, 3.0, 3.0, 0.9))
    return Part.makeCompound(out)


def resistors():
    out = [cbox(37.9, 35.0, T, 6.4, 3.2, 0.7), cbox(38.0, 40.6, T, 5.0, 2.5, 0.7),
           cbox(71.6, 19.5, T, 3.2, 6.4, 0.7), cbox(71.6, 11.9, T, 3.2, 6.4, 0.7)]
    return Part.makeCompound(out)


def pogo_pins():
    housing = cbox(72.8, 2.23, T, 5.4, 2.6, 2.5)  # black carrier seen in photo
    pins = []
    for x, y in P['pogo_xy']:
        pins.append(Part.makeCylinder(0.75, P['pogo_h'] - 1.0, V(x, y, T)))
        pins.append(Part.makeCylinder(0.5, 1.0, V(x, y, T + P['pogo_h'] - 1.0)))
    return housing, Part.makeCompound(pins)


def standoffs():
    out = []
    for x, y in P['holes']:
        s = hexagon(x, y, T, P['standoff_af'], P['standoff_h'])
        s = s.cut(Part.makeCylinder(1.25, P['standoff_h'] + 2, V(x, y, T - 1)))
        out.append(s)
    return Part.makeCompound(out)


def build():
    doc = App.newDocument(NAME.replace('-', '_'))
    assy = doc.addObject('App::Part', 'UPS_HAT_B')
    assy.Label = 'Waveshare UPS HAT (B)'
    parts = []

    def add(label, shape, color):
        o = doc.addObject('Part::Feature', label.replace(' ', '_').replace('-', '_'))
        o.Label = label
        o.Shape = shape
        assy.addObject(o)
        parts.append((o, color))
        return o

    jack, jack_pin = dc_jack()
    usb_shell, usb_tongue = usb_a()
    sw_body, sw_lever = slide_switch()
    bt_body, bt_knob = boot_button()
    pogo_housing, pogo = pogo_pins()

    add('PCB', pcb(), COLORS['pcb'])
    add('Battery holder 2x18650', battery_holder(), COLORS['black'])
    add('Battery contacts', holder_contacts(), COLORS['metal'])
    add('18650 cells (not included)', cells(), COLORS['cell'])
    add('DC jack 8.4V', jack, COLORS['black'])
    add('DC jack pin', jack_pin, COLORS['metal'])
    add('USB-A 5V OUT', usb_shell, COLORS['metal'])
    add('USB-A tongue', usb_tongue, COLORS['black'])
    add('Power switch', sw_body, COLORS['grey'])
    add('Power switch lever', sw_lever, COLORS['black'])
    add('BOOT button', bt_body, COLORS['white'])
    add('BOOT button actuator', bt_knob, COLORS['black'])
    add('Inductor', inductor(), COLORS['grey'])
    add('ICs', ics(), COLORS['black'])
    add('Resistors', resistors(), COLORS['black'])
    add('Pogo pin carrier', pogo_housing, COLORS['black'])
    add('Pogo pins', pogo, COLORS['gold'])
    add('Standoffs M2.5 (kit)', standoffs(), COLORS['brass'])

    for o, c in parts:
        if not o.Shape.isValid():
            raise RuntimeError('%s is not a valid shape' % o.Label)
        if App.GuiUp:
            o.ViewObject.ShapeColor = c
    doc.recompute()

    doc.saveAs(str(OUT / (NAME + '.FCStd')))
    import Import
    Import.export([assy], str(OUT / (NAME + '.step')))
    preview = os.environ.get('UPS_HAT_PREVIEW_DIR')
    if preview:  # per-part STL + colour list for a Blender preview render
        import MeshPart
        Path(preview).mkdir(parents=True, exist_ok=True)
        with open(Path(preview) / 'colors.txt', 'w') as f:
            for o, c in parts:
                MeshPart.meshFromShape(Shape=o.Shape, LinearDeflection=0.05,
                                       AngularDeflection=0.3).write(str(Path(preview) / (o.Name + '.stl')))
                f.write('%s %.3f %.3f %.3f\n' % ((o.Name,) + c))
    bb = Part.makeCompound([o.Shape for o, _ in parts]).BoundBox
    print('Overall bbox: X %.1f..%.1f  Y %.1f..%.1f  Z %.1f..%.1f' %
          (bb.XMin, bb.XMax, bb.YMin, bb.YMax, bb.ZMin, bb.ZMax))
    return doc


build()
