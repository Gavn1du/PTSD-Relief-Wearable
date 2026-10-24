# Compact PiSugar arm enclosure

The current main project uses the imported **PiSugar 3 Plus / 5000 mAh** below
the Raspberry Pi. The Waveshare assembly and 40 mm spacer references are
retained in a hidden, superseded hardware group. Their large shell stages stay
in the design history; the active Case and Lid tips are the new PiSugar stages.

## Size and fit

| Dimension | Current design |
|---|---:|
| Center depth, curved contact face to outer roof | **40.85 mm** |
| Previous Waveshare center depth | 67 mm |
| Reduction | **26.15 mm / 39%** |
| Shell at the center beneath the battery | 2.5 mm |
| Battery-to-floor clearance | 2 mm |
| Roof thickness | 2 mm |
| Highest modeled Pi component to roof | 1.5 mm |
| Lid seating clearance | 0.25 mm |

The center depth is not the maximum overall bounding depth: the retained curved
strap ears extend toward the arm, giving a maximum case envelope of about
**61.04 mm** in that direction. Case-only bounds including ears and cable pocket
are approximately **103.4 × 108.47 × 61.04 mm** (along arm × across ears × depth).
The fitted end lid extends another 2.95 mm along the arm.

This is a compact geometry for the modeled components and stated clearance / wall
allowances, not a claim that no smaller physical case is possible. Further height
reduction would consume these allowances or require changing the curved base.
The flat battery cavity is recessed into the old floor. The curved contact
surface, 80 mm radius and four 28 × 4 mm Velcro slots remain intact.

The Pi and existing accessory boards move upward together by 12.4 mm, preserving
their relative layout. The PiSugar mounting nuts meet the Pi PCB underside at
four aligned holes on the 58 × 49 mm pattern. No 40 mm spacers are needed.
The manufacturer describes this underside mounting and pogo-pin connection:
[PiSugar installation documentation](https://docs.pisugar.com/docs/product-wiki/battery/pisugar3/pisugar-3-series#mounting-steps).

The imported battery lead is a swept clearance envelope that extends beyond the
PCB outline. A small rounded pocket at the cable end accommodates it instead of
forcing it into the wall. Its outer end extends 4.85 mm beyond the old case end.
The charging USB-C, alternative micro-USB and buttons share a broad rounded
**54 × 13.4 mm** service opening with the Pi USB-C / HDMI area, avoiding fragile
webs between vertically adjacent ports. Existing USB/Ethernet end access and the
lid clips follow the relocated Pi.

## Model limits

The PCB comes from PiSugar's vendor STEP model. The pouch cell, magnet and wire
were added to the imported reference from photos, approximately ±1–2 mm. Verify
those dimensions and the physical battery clearance before a final print.
Per the user's confirmation, fit is limited to the existing modeled components.
The separate fan/heatsink in the photo is excluded; the roof follows the modeled
Pi components.

The vendor model has six uncompressed spring pins. Their tips overlap the Pi's
GPIO solder-tail reference by 0.8 mm at the intended contact points. This is
reported separately from enclosure clashes and is not a spring travel rating.
Check contact compression, supplied mounting screws, battery retention, cable
access and lid clip fit on the physical assembly. No screw-head, thermal or
wear/load testing is claimed.

## Current files

- `../PTSD-App-Helper.FCStd`: saved native assembly.
- `../PTSD-App-Helper-Case-PiSugar.stl` / `.step`: current case.
- `../PTSD-App-Helper-Lid-PiSugar.stl` / `.step`: matching lid.
- `PTSD-App-Helper-before-pisugar-fit.FCStd`: backup of the user's live assembly,
  including the unsaved PiSugar import, before the fitting changes.
- `pisugar-case-preview.png`: transparent case assembly preview.
- `pisugar-case-validation.json`: numerical fit and solid/mesh checks.
- `pisugar_case.py`, `Rebuild-PiSugar-Case.FCMacro`: reproducible builder.

Use the **Case-PiSugar / Lid-PiSugar** pair for slicing. Earlier Case-Arm,
Case-UPS, Lid-UPS, other meshes and G-code describe previous configurations.

## Editing and validation

Edit `PARAMETERS` in `pisugar_case.py` and run `Rebuild-PiSugar-Case.FCMacro` from
the open main project. The native BRep stages are stored in the document, so no
plugin is required to reopen it. Dimension properties are build records, not
live sketch constraints. The builder stores original electronics placements so
rerunning does not cumulatively shift them. Do not run the old UPS macro on this
configuration; it restores the obsolete layout. If changing arm geometry with
the old arm builder, rerun this PiSugar builder afterward.

Both case and lid are valid single solids with closed exported meshes. The Pi,
PiSugar board, battery, magnet, full wire envelope and all existing accessory
boards have zero volumetric intersections with either enclosure part. The
case/lid overlap is zero. No original arm-contact material is removed. Six
intended uncompressed pogo-pin contacts are listed separately in the report.
