"""Build the bicep case in FreeCAD. Run via the supplied FCMacro.

All coordinates are in the original Case body's local frame (mm).
The legacy Pad007 and every electronics/lid placement remain untouched.
The added features are explicit BRep stages; change PARAMETERS and rerun
this builder to regenerate them (the displayed dimensions are read-only).
"""
import json
import math
from pathlib import Path
import FreeCAD as App
import Part
import MeshPart

PARAMETERS = dict(arm_radius=80.0, center_addition=2.0, strap_width=25.0,
                  slot_length=28.0, slot_gap=4.0, ear_radial_thickness=4.5,
                  ear_extension=14.0, ear_root_overlap=6.0,
                  ear_length=39.0, strap_center_spacing=48.0,
                  edge_round=0.8)
FEATURE_NAMES = ['ArmSaddle', 'ArmStrapAnchors', 'ArmStrapSlots', 'ArmComfortEdges']
ROOT = Path(__file__).resolve().parent.parent


def rounded_rect(x0, y0, x1, y1, radius, z, height):
    """Rounded XY footprint extruded along Z; exact tangent arcs."""
    r=radius; V=App.Vector
    points=[(x0+r,y0),(x1-r,y0),(x1,y0+r),(x1,y1-r),
            (x1-r,y1),(x0+r,y1),(x0,y1-r),(x0,y0+r)]
    p=[V(x,y,z) for x,y in points]
    d=r/math.sqrt(2)
    mids=[V(x1-r+d,y0+r-d,z),V(x1-r+d,y1-r+d,z),
          V(x0+r-d,y1-r+d,z),V(x0+r-d,y0+r-d,z)]
    edges=[]
    for j in range(4):
        i=2*j
        if (p[i]-p[i+1]).Length > 1e-9:
            edges.append(Part.makeLine(p[i],p[i+1]))
        edges.append(Part.Arc(p[i+1],mids[j],p[(i+2)%8]).toShape())
    return Part.Face(Part.Wire(edges)).extrude(V(0,0,height))


def check_shape(s, name):
    if s.isNull() or len(s.Solids)!=1 or not s.isValid():
        raise RuntimeError('%s must be one valid solid (null=%s, solids=%s, valid=%s)' % (name,s.isNull(),len(s.Solids),s.isValid()))


def build(doc, output_dir=ROOT, parameters=None):
    p=dict(PARAMETERS); p.update(parameters or {})
    out=Path(output_dir); out.mkdir(parents=True,exist_ok=True)
    b=doc.getObject('Body001'); legacy=doc.getObject('Pad007')
    if not b or not legacy or b.Label != 'Case':
        raise RuntimeError('Expected the original PTSD-App-Helper Case body and Pad007')
    # Feature.Shape is in body-local coordinates, including feature placement.
    base=legacy.Shape.copy(); bb=base.BoundBox
    original_world=base.copy(); original_world.Placement=b.Placement.multiply(base.Placement)
    ymin,ymax=bb.YMin,bb.YMax; yc=(ymin+ymax)/2
    xmin=bb.XMin+0.8; xmax=bb.XMax-1.5; xc=(xmin+xmax)/2
    half=(ymax-ymin)/2; R=p['arm_radius']; cz=-R-p['center_addition']
    if R <= half+p['ear_extension']+5:
        raise ValueError('Arm radius is too small for this case width')
    if p['slot_length'] < p['strap_width']+2 or p['ear_length'] < p['slot_length']+8:
        raise ValueError('Keep strap clearance and at least 4 mm end ligaments')
    V=App.Vector
    cylinder=Part.makeCylinder(R,xmax-xmin+4,V(xmin-2,yc,cz),V(1,0,0))
    outer=Part.makeCylinder(R+p['ear_radial_thickness'],xmax-xmin+4,V(xmin-2,yc,cz),V(1,0,0))
    bottom=cz+math.sqrt(R*R-(half+p['ear_extension'])**2)-2
    saddle_blank=rounded_rect(xmin,ymin,xmax,ymax,3,bottom,0.4-bottom)
    saddle=saddle_blank.cut(cylinder).removeSplitter()
    s1=base.fuse(saddle,1e-5).removeSplitter(); check_shape(s1,'Saddle')
    ears=[]; cutters=[]; slot_specs=[]
    centers=[xc-p['strap_center_spacing']/2,xc+p['strap_center_spacing']/2]
    if centers[0]-p['ear_length']/2 < xmin or centers[1]+p['ear_length']/2 > xmax:
        raise ValueError('Strap anchors extend beyond the saddle ends')
    for x in centers:
        for sign in [-1,1]:
            near=yc+sign*(half-p['ear_root_overlap'])
            far=yc+sign*(half+p['ear_extension'])
            y0,y1=sorted([near,far])
            blank=rounded_rect(x-p['ear_length']/2,y0,x+p['ear_length']/2,y1,4,bottom,1-bottom)
            ears.append(blank.common(outer))
            sy=yc+sign*(half+6.5)
            cut=rounded_rect(x-p['slot_length']/2,sy-p['slot_gap']/2,
                             x+p['slot_length']/2,sy+p['slot_gap']/2,
                             p['slot_gap']/2,-60,65)
            cutters.append(cut)
            slot_specs.append(dict(x=x,y=sy,length=p['slot_length'],gap=p['slot_gap']))
    mount=saddle_blank
    for ear in ears:
        mount=mount.fuse(ear,1e-6).removeSplitter()
    s2=base.fuse(mount.cut(cylinder),1e-5).removeSplitter()
    check_shape(s2,'Strap anchors')
    s3=s2.cut(Part.makeCompound(cutters)).removeSplitter(); check_shape(s3,'Strap slots')
    # All selected edges are beneath the old outer floor. No original interior
    # edge, port, lid seat or attachment mount is rounded or cut.
    edge_list=[e for e in s3.Edges if e.BoundBox.ZMax < -0.05]
    s4=s3.makeFillet(p['edge_round'],edge_list).removeSplitter()
    check_shape(s4,'Comfort rounds')
    added=s4.cut(base); removed=base.cut(s4)
    if removed.Volume > 1e-5:
        raise RuntimeError('The arm revision removed original case material')
    # Explicitly ensure no new material above the original exterior floor.
    cavity_zone=Part.makeBox(200,200,80,V(bb.XMin-30,ymin-30,0.001))
    if added.common(cavity_zone).Volume > 1e-5:
        raise RuntimeError('The arm revision intrudes into the existing case envelope')
    world=s4.copy(); world.Placement=b.Placement.multiply(s4.Placement)
    additions_world=added.copy(); additions_world.Placement=b.Placement.multiply(added.Placement)
    checks={}
    for n in ['PCB_Component','PCB_Component001',
              'RP_004882_DD___Pi_5_Mechanical_Reference_3D_model_Iss1',
              'Body002','Body005','Qwiic_Shield_for_RaspberryPi_1']:
        o=doc.getObject(n); ref=Part.getShape(o)
        new_interference=additions_world.common(ref).Volume
        if new_interference > 1e-5:
            raise RuntimeError('New interference with '+o.Label)
        checks[n]={'label':o.Label,'baseline_intersection_mm3':original_world.common(ref).Volume,
                   'revised_intersection_mm3':world.common(ref).Volume,
                   'new_material_intersection_mm3':new_interference}
    # Preserve the pre-existing history; replace only this builder's stages.
    doc.openTransaction('Curved bicep saddle and Velcro slots')
    try:
        b.Tip=legacy
        for name in reversed(FEATURE_NAMES):
            if doc.getObject(name): doc.removeObject(name)
        stages=[('ArmSaddle','Arm saddle | R%g mm' % R,s1),
                ('ArmStrapAnchors','Four curved strap anchors',s2),
                ('ArmStrapSlots','Four %g x %g mm Velcro slots' % (p['slot_length'],p['slot_gap']),s3),
                ('ArmComfortEdges','Arm mount | rounded edges',s4)]
        for name,label,s in stages:
            obj=b.newObject('PartDesign::Feature',name); obj.Label=label; obj.Shape=s
        b.Tip=obj
        for key,value in p.items():
            name=''.join(w.title() for w in key.split('_'))
            obj.addProperty('App::PropertyLength',name,'Arm mount dimensions','Generated by cad/arm_mount.py; change parameters and rerun the macro.')
            setattr(obj,name,value); obj.setEditorMode(name,1)
        obj.addProperty('App::PropertyString','Rebuild','Arm mount dimensions')
        obj.Rebuild='Edit PARAMETERS in cad/arm_mount.py, then run Rebuild-Arm-Mount.FCMacro';obj.setEditorMode('Rebuild',1)
        doc.recompute()
        check_shape(b.Shape,'Recomputed case')
        doc.commitTransaction()
    except Exception:
        doc.abortTransaction(); raise
    # Portable native BRep and print mesh; no plugin is needed to reopen FCStd.
    mesh=MeshPart.meshFromShape(Shape=world,LinearDeflection=0.08,AngularDeflection=0.12,Relative=False)
    if not mesh.isSolid(): raise RuntimeError('Export mesh is not closed')
    mesh.write(str(out/'PTSD-App-Helper-Case-Arm.stl'))
    world.exportStep(str(out/'PTSD-App-Helper-Case-Arm.step'))
    bounds=world.BoundBox
    report=dict(parameters_mm=p,case_valid=world.isValid(),case_solids=len(world.Solids),
                mesh_closed=mesh.isSolid(),mesh_facets=mesh.CountFacets,
                original_case_volume_mm3=base.Volume,revised_case_volume_mm3=s4.Volume,
                original_material_removed_mm3=removed.Volume,
                new_intrusion_above_original_floor_mm3=added.common(cavity_zone).Volume,
                transverse_sag_at_case_edge_mm=R-math.sqrt(R*R-half*half),
                revised_bounds_xyz_mm=[bounds.XLength,bounds.YLength,bounds.ZLength],
                slot_centers_body_local_mm=slot_specs,component_checks=checks,
                note='Existing Pi/lid reference intersections are inherited. Added arm geometry introduces none. Physical fit and strap pull testing remain necessary.')
    (out/'cad' ).mkdir(exist_ok=True)
    (out/'cad'/'arm-mount-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    if App.GuiUp:
        import FreeCADGui as Gui
        for o in doc.RootObjects:
            if hasattr(o,'ViewObject'): o.ViewObject.Visibility=False
        b.ViewObject.Visibility=True
        for o in b.Group:
            if hasattr(o,'ViewObject'): o.ViewObject.Visibility=False
        obj.ViewObject.Visibility=True
        obj.ViewObject.ShapeColor=(0.72,0.80,0.85)
        obj.ViewObject.LineColor=(0.14,0.20,0.24)
        obj.ViewObject.DisplayMode='Flat Lines'
        b.ViewObject.ShapeColor=(0.72,0.80,0.85)
        Gui.activeDocument().activeView().viewIsometric()
        Gui.activeDocument().activeView().fitAll()
    doc.recompute()
    return report


if __name__=='__main__':
    doc=App.ActiveDocument or App.openDocument(str(ROOT/'PTSD-App-Helper.FCStd'))
    print(json.dumps(build(doc),indent=2))
    doc.saveAs(str(ROOT/'PTSD-App-Helper.FCStd'))
