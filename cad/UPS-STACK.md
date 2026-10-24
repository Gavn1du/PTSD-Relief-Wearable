# Pi + UPS arm enclosure

**Superseded:** the current project uses the [compact PiSugar layout](PISUGAR-CASE.md).
This document and the `Case-UPS / Lid-UPS` exports describe the previous
Waveshare version. Use `Case-PiSugar / Lid-PiSugar` for the current assembly.

The current `../PTSD-App-Helper.FCStd` places the Waveshare 20567 UPS HAT (B)
**above the Pi's components**, as requested. Its battery holder faces the Pi.
The Raspberry Pi, existing accessory boards and curved arm mount retain their
original placements.

## Assembly and dimensions

- The UPS's four holes align with the Pi's **58 × 49 mm** hole pattern.
- Four separate **40 mm long, 5 mm OD, 2.7 mm bore** spacer references sit between
  the Pi PCB's component-side face and the UPS PCB's underside. These are
  required mounting hardware references, not parts of the printed case. Select
  suitable M2.5 fixings and verify their engagement against the actual boards.
- The UPS PCB underside is at global Y = **41.5 mm**. Its lowest modeled battery
  holder surface is at Y = **21.5 mm**, leaving **3.55 mm** above the Pi's highest
  modeled component envelope. The imported kit standoffs are retained above
  the UPS, within the enclosure.
- Case roof and end lid are raised **34 mm**. The case's center depth is now
  **67 mm**; the curved strap ears extend farther toward the arm. The footprint,
  80 mm arm radius, and four 28 × 4 mm slots for two 25 mm straps are unchanged.
- A rounded **49.1 × 13.5 mm** service window provides access to the charging
  jack, USB output and power switch. A separate **9.2 × 7 mm** window provides
  tool access to BOOT. Openings are deliberately generous because the UPS model
  was approximated from a manufacturer drawing and product photos.
- The original accessory bay remains in place, supported from the raised roof
  by two 6 mm end ribs. Its whole cross-section is not filled with plastic.
- The lid seating rim has **0.25 mm** axial clearance at the case end. Original
  clip positions are preserved; physical clip fit still needs a sample.

This is a custom mechanical stack. The UPS's pogo pins **do not contact the Pi**
in this arrangement; a separate electrical interconnect is required and is not
modeled. Cable connectors, bend radii, extra cooling hardware and fastener heads
beyond the supplied reference geometry have not been fit-checked. The imported
UPS model itself is approximate; confirm dimensions on the physical hardware
before a final print. This is a taller prototype enclosure, not a wear-tested
finished product.

## Current deliverables

- `../PTSD-App-Helper.FCStd`: editable native project, retaining the old feature
  histories and adding named UPS case and lid stages.
- `../PTSD-App-Helper-Case-UPS.stl` and `.step`: current printable case.
- `../PTSD-App-Helper-Lid-UPS.stl` and `.step`: matching expanded end lid.
- `PTSD-App-Helper-before-ups-stack.FCStd`: saved live assembly before this change.
- `ups-stack-validation.json`: measured checks for this revision.
- `ups_stack.py` and `Rebuild-UPS-Case.FCMacro`: reproducible builder.

The `Case-Arm` exports and older lid meshes / G-code predate this UPS revision.
Use the new **Case-UPS / Lid-UPS** pair and slice them together for this design.

## Rebuilding

Edit `PARAMETERS` in `ups_stack.py`, open the main project, and run
`Rebuild-UPS-Case.FCMacro`. The stages are stored native BReps, not live sketch
constraints; displayed dimensions record the build settings. Changing a
property in the FreeCAD panel alone does not regenerate them. The script
rebuilds from the preserved `ArmComfortEdges` and `Pocket005` features, so reruns
do not cumulatively increase height. No plugin is needed to reopen the model.

The older arm macro only rebuilds the arm geometry. If using it to change the
arm dimensions, run the UPS macro afterward to regenerate the expanded shell
and lid before exporting or printing.

## Validation scope

The case and lid are each one valid solid with closed exported meshes. The UPS
and added spacer hardware intersect neither case, lid nor Pi. Existing
accessory boards gain no interference. The lower case, arm curve, strap slots
and Pi-level openings are geometrically unchanged. The original small
**2.956 mm³** Pi/case reference intersection remains; the old lid/case overlap
is corrected to **zero**. These are CAD checks, not a physical fit or strength
test. Refer to the JSON for the exact measured values and bounding boxes.
