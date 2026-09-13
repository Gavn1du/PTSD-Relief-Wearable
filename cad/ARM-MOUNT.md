# Curved upper-arm case

`../PTSD-App-Helper.FCStd` is the revised source. The Case body ends in four
named arm-mount features. The earlier sketches and features, electronics,
mounts, port openings, and lid geometry remain in the document.

## Dimensions and strap routing

- Arm-facing cylindrical radius: **80 mm**, across the case's shorter dimension.
- Long case direction runs along the arm, shoulder to elbow; straps cross it.
- Added material at underside center: **2 mm**. The curve drops **10.85 mm**
  from the center to the original case edges.
- Four rounded **28 × 4 mm** through-slots accept two nominal **25 mm / 1 inch**
  Velcro straps. The extra slot length accommodates rounded ends and threading.
- Two opposed slot pairs, **48 mm** apart along the case.
- Curved anchor ears: **4.5 mm radial thickness**, extending **14 mm** beyond
  each side, with **0.8 mm** edge rounds. Minimum nominal slot-end ligament is
  **5.5 mm** before edge rounding.
- Overall case with ears, excluding lid: approximately **98.55 mm** along the
  arm, **108.47 mm** across the ears, and about **53.3 mm** maximum depth. The larger
  depth is at the curved ear tips; center case depth is **33 mm**.

Use one strap through each opposed pair: fix or loop one end through a slot,
wrap around the back of the upper arm, pass through the opposite slot and
fold the Velcro back onto itself. Repeat for the second pair. The straps stay
outside the electronics compartment. Strap length depends on the wearer and
must allow the Velcro's required fastening overlap. A thin removable pad can
be fitted to the curved face; leave the slots clear.

The radius is a starting geometry because no arm measurements were supplied.
Check a physical fit sample, threading, anchor strength and comfort before
printing/using a loaded assembly. This is not a load-tested design.

## Files and editing

- `../PTSD-App-Helper-Case-Arm.stl`: closed case mesh, in millimeters.
- `../PTSD-App-Helper-Case-Arm.step`: case solid for CAD interchange.
- `PTSD-App-Helper-before-arm.FCStd`: exact source backup before this revision.
- `arm-mount-validation.json`: actual geometry and interference results.
- `arm_mount.py`: dimension parameters and reproducible FreeCAD builder.
- `Rebuild-Arm-Mount.FCMacro`: run in FreeCAD to regenerate and save the model.

To change radius or strap dimensions, edit `PARAMETERS` in `arm_mount.py`, open
the revised source, then execute the macro. The four new stages are native
stored BRep features, not live constraint-driven sketches; their displayed
parameter properties are read-only records. Reopening the file needs no
Python module or plugin. The builder regenerates only its four named stages
from the original `Pad007` tip, leaving the earlier design history intact.

Existing STL, 3MF and G-code files describe the previous design. Slice the new
`Case-Arm.stl` separately. Review print orientation and support placement so
supports do not leave rough contact surfaces or obstruct the strap slots.

## Validation

The saved case is one valid solid and its exported mesh is closed. No original
case material was removed. All new material is outside the old exterior
floor. Added geometry intersects none of the modeled Pi, accessory boards,
Qwiic shield or lid. Original modeled intersections of approximately **2.956
mm³** with the Pi reference and **35.180 mm³** with the lid remain unchanged;
therefore these checks confirm preservation of the existing fit, not a new
certification of assembly tolerances. Cable routing, unmodeled attachments,
strap thickness, manufacturing tolerances and physical fit require a sample.
