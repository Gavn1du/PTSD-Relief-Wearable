"""Raise the imported UPS above the Pi and extend the arm enclosure.

Stored BRep stages; edit PARAMETERS and run Rebuild-UPS-Case.FCMacro.
The original arm case, lid history, Pi and accessory placements are retained.
Dimensions are millimeters. The UPS source model is approximate.
"""
import json
from pathlib import Path
import FreeCAD as App
import Part
import MeshPart

ROOT = Path(__file__).resolve().parent.parent
V = App.Vector
PARAMETERS = dict(spacer_length=40.0, roof_raise=34.0, split_height=19.0,
                  spacer_outer_diameter=5.0, spacer_bore=2.7, lid_seat_clearance=.25)
PI_NAME = 'RP_004882_DD___Pi_5_Mechanical_Reference_3D_model_Iss1'
HOLES = [(-41.0,-20.5),(-41.0,28.5),(17.0,-20.5),(17.0,28.5)]


def bounds(s):
    b=s.BoundBox
    return [b.XMin,b.YMin,b.ZMin,b.XMax,b.YMax,b.ZMax]


def valid(s, name):
    if s.isNull() or not s.isValid() or len(s.Solids)!=1:
        raise RuntimeError(name+' must be one valid solid: valid=%s, solids=%s'%(s.isValid(),len(s.Solids)))


def world_feature(body, feature):
    s=feature.Shape.copy()
    s.Placement=body.Placement.multiply(s.Placement)
    return s


def stretch(s, plane, delta, perimeter_only=False):
    lower=s.common(Part.makeBox(300,plane+100,300,V(-150,-100,-150)))
    upper=s.common(Part.makeBox(300,150-plane,300,V(-150,plane,-150)))
    upper.translate(V(0,delta,0))
    section=Part.makeFace(s.slice(V(0,1,0),plane),'Part::FaceMakerBullseye')
    if perimeter_only:
        # The other section face is the accessory bay suspended from the roof.
        # Carry it on two end ribs instead of extending the whole solid block.
        faces=[f for f in section.Faces if f.BoundBox.ZLength>70]
        if len(faces)!=1: raise RuntimeError('Expected one perimeter wall section')
        extension=faces[0].extrude(V(0,delta,0))
        for f in section.Faces:
            if f.BoundBox.ZLength<70:
                slab=f.extrude(V(0,delta,0))
                for x in [-47,39]:
                    rib=slab.common(Part.makeBox(6,delta+2,30,V(x,plane-1,-50)))
                    extension=extension.fuse(rib)
    else:
        extension=section.extrude(V(0,delta,0))
    result=lower.fuse(extension,1e-5).fuse(upper,1e-5).removeSplitter()
    valid(result,'Extended enclosure')
    return result


def port_cutters(origin_y):
    # Generous rounded access windows, based on the imported part bounds.
    from arm_mount import rounded_rect
    # These XY profiles pass through the +Z wall. Y is enclosure height.
    y=origin_y
    # One service window avoids fragile webs between the closely spaced ports.
    specs=[('Charging / USB / power switch',(-38.0,y+.1,11.1,y+13.6))]
    result=[rounded_rect(x0,y0,x1,y1,2.0,30,15) for _,(x0,y0,x1,y1) in specs]
    # BOOT access through the -X end wall, clear of the side lid.
    boot=rounded_rect(15.0,y+.1,24.2,y+7.1,1.2,47,10)
    boot.rotate(V(),V(0,1,0),-90) # local X -> world Z, local Z -> -world X
    result.append(boot)
    return result


def upsert(body, name, label, shape):
    obj=body.Document.getObject(name) or body.newObject('PartDesign::Feature',name)
    obj.Label=label
    local=shape.copy(); local.Placement=body.Placement.inverse().multiply(local.Placement)
    obj.Shape=local
    return obj


def build(doc, output_dir=ROOT, parameters=None):
    p=dict(PARAMETERS);p.update(parameters or {})
    out=Path(output_dir);(out/'cad').mkdir(parents=True,exist_ok=True)
    case_body=doc.Body001; lid_body=doc.Body005
    original=world_feature(case_body,doc.ArmComfortEdges)
    original_lid=world_feature(lid_body,doc.Pocket005)
    original_pi=doc.getObject(PI_NAME).Placement.copy()
    ups=doc.Waveshare_UPS_HAT__B_
    origin_y=1.5+p['spacer_length']
    doc.openTransaction('Fit UPS above Raspberry Pi and expand enclosure')
    try:
        ups.Placement=App.Placement(V(40.5,origin_y,-24),
            App.Rotation(V(-1,0,0),V(0,0,1),V(0,1,0),'ZXY'))
        case=stretch(original,p['split_height'],p['roof_raise'],True)
        lid=stretch(original_lid,p['split_height'],p['roof_raise'])
        raised=case.copy()
        cutters=port_cutters(origin_y)
        for cutter in cutters: case=case.cut(cutter)
        case=case.removeSplitter();valid(case,'UPS case');valid(lid,'UPS lid')
        extended_lid=lid.copy()
        # Relieve the seating rim without moving the original snap clips.
        # Original end plate begins at X=46.75, case ends at X=46.8.
        rim=Part.makeFace(case.slice(V(1,0,0),46.76),'Part::FaceMakerBullseye')
        rim.translate(V(-.02,0,0))
        lid=lid.cut(rim.extrude(V(.06+p['lid_seat_clearance'],0,0))).removeSplitter()
        valid(lid,'Lid seating relief')
        # Hardware is separate from the printable case, on the shared hole axes.
        spacers=[]
        for x,z in HOLES:
            s=Part.makeCylinder(p['spacer_outer_diameter']/2,p['spacer_length'],V(x,1.5,z),V(0,1,0))
            s=s.cut(Part.makeCylinder(p['spacer_bore']/2,p['spacer_length']+2,V(x,.5,z),V(0,1,0)))
            valid(s,'Mounting spacer');spacers.append(s)
        spacer_shape=Part.makeCompound(spacers)
        # Test solid-by-solid; compounds contain many touching internal parts.
        ups_shape=Part.getShape(ups)
        checks={}
        for name,ref in [('case',case),('lid',lid),('pi',Part.getShape(doc.getObject(PI_NAME)))]:
            volume=sum(s.common(ref).Volume for s in ups_shape.Solids if s.BoundBox.intersect(ref.BoundBox))
            checks['ups_vs_'+name+'_mm3']=volume
            if volume>1e-5: raise RuntimeError('UPS collision with '+name+': '+str(volume))
        for name,ref in [('case',case),('lid',lid),('pi',Part.getShape(doc.getObject(PI_NAME))),('ups',ups_shape)]:
            volume=sum(s.common(ref).Volume for s in spacers if s.BoundBox.intersect(ref.BoundBox))
            checks['spacers_vs_'+name+'_mm3']=volume
            if volume>1e-5: raise RuntimeError('Spacer collision with '+name+': '+str(volume))
        checks['case_vs_lid_baseline_mm3']=original.common(original_lid).Volume
        checks['case_vs_lid_revised_mm3']=case.common(lid).Volume
        if checks['case_vs_lid_revised_mm3']>1e-5: raise RuntimeError('Lid seating interference')
        checks['case_vs_pi_baseline_mm3']=original.common(Part.getShape(doc.getObject(PI_NAME))).Volume
        checks['case_vs_pi_revised_mm3']=case.common(Part.getShape(doc.getObject(PI_NAME))).Volume
        # Entire arm-facing region and original Pi-level openings must match.
        lower_zone=Part.makeBox(300,p['split_height']+100-.001,300,V(-150,-100,-150))
        old_lower=original.common(lower_zone); new_lower=case.common(lower_zone)
        checks['lower_case_removed_mm3']=old_lower.cut(new_lower).Volume
        checks['lower_case_added_mm3']=new_lower.cut(old_lower).Volume
        if max(checks['lower_case_removed_mm3'],checks['lower_case_added_mm3'])>1e-5:
            raise RuntimeError('Original arm mount or Pi-level enclosure changed')
        for name in ['PCB_Component','PCB_Component001','Body002','Qwiic_Shield_for_RaspberryPi_1']:
            ref=Part.getShape(doc.getObject(name))
            before=original.common(ref).Volume;after=case.common(ref).Volume
            checks[name]={'baseline_mm3':before,'revised_mm3':after}
            if after>before+1e-5: raise RuntimeError('New accessory collision: '+name)
        f1=upsert(case_body,'UPSCaseExtension','UPS enclosure | roof raised %g mm'%p['roof_raise'],raised)
        f2=upsert(case_body,'UPSCasePorts','UPS enclosure | charging, USB and controls',case)
        upsert(lid_body,'UPSLidExtension','Lid | expanded for Pi + UPS',extended_lid)
        lf=upsert(lid_body,'UPSLidSeat','Lid | 0.25 mm seating relief',lid)
        case_body.Tip=f2;lid_body.Tip=lf
        hardware=doc.getObject('UPSStackSpacers') or doc.addObject('Part::Feature','UPSStackSpacers')
        hardware.Label='4 x %g mm mounting spacers | hardware reference'%p['spacer_length']
        hardware.Shape=spacer_shape
        for key,value in p.items():
            prop=''.join(w.title() for w in key.split('_'))
            if prop not in f2.PropertiesList: f2.addProperty('App::PropertyLength',prop,'UPS enclosure')
            setattr(f2,prop,value);f2.setEditorMode(prop,1)
        if 'AssemblyNote' not in ups.PropertiesList: ups.addProperty('App::PropertyString','AssemblyNote','Assembly')
        ups.AssemblyNote='Above Pi, batteries downward, 40 mm mounting spacers. Pogo pins do not contact Pi; separate electrical interconnect required. Approximate reference model.'
        if 'Rebuild' not in f2.PropertiesList: f2.addProperty('App::PropertyString','Rebuild','UPS enclosure')
        f2.Rebuild='Edit cad/ups_stack.py PARAMETERS; run cad/Rebuild-UPS-Case.FCMacro'
        doc.recompute();valid(case_body.Shape,'Recomputed case');valid(lid_body.Shape,'Recomputed lid')
        if doc.getObject(PI_NAME).Placement!=original_pi: raise RuntimeError('Pi placement changed')
        doc.commitTransaction()
    except Exception:
        doc.abortTransaction();raise
    exports={}
    for suffix,shape in [('Case-UPS',case),('Lid-UPS',lid)]:
        mesh=MeshPart.meshFromShape(Shape=shape,LinearDeflection=.08,AngularDeflection=.12,Relative=False)
        if not mesh.isSolid(): raise RuntimeError('Export mesh not closed: '+suffix)
        stem=out/('PTSD-App-Helper-'+suffix)
        mesh.write(str(stem)+'.stl');shape.exportStep(str(stem)+'.step')
        exports[suffix]={'valid_solid':shape.isValid(),'solids':len(shape.Solids),'closed_mesh':mesh.isSolid(),'facets':mesh.CountFacets,'bounds_xyz_mm':bounds(shape)}
    report={'parameters_mm':p,'ups_origin_xyz_mm':[40.5,origin_y,-24],
            'ups_bounds_xyz_mm':bounds(ups_shape),'mounting_hole_centers_xz_mm':HOLES,
            'pi_to_holder_vertical_envelope_clearance_mm':ups_shape.BoundBox.YMin-Part.getShape(doc.getObject(PI_NAME)).BoundBox.YMax,
            'checks':checks,'exports':exports,
            'note':'UPS above Pi as requested. Imported component geometry approximate; physical fit and separate wiring require verification. Existing case/Pi and lid seam intersections reported explicitly.'}
    (out/'cad'/'ups-stack-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    if App.GuiUp:
        import FreeCADGui as Gui
        for b in [case_body,lid_body]:
            for obj in b.Group:
                if hasattr(obj,'ViewObject'):obj.ViewObject.Visibility=False
            b.Tip.ViewObject.Visibility=True;b.ViewObject.Visibility=True
            b.Tip.ViewObject.ShapeColor=(.72,.80,.85)
            b.Tip.ViewObject.LineColor=(.14,.20,.24)
            b.Tip.ViewObject.DisplayMode='Flat Lines'
        hardware.ViewObject.ShapeColor=(.80,.65,.25)
        hardware.ViewObject.Visibility=True;ups.ViewObject.Visibility=True
        Gui.activeDocument().activeView().viewIsometric();Gui.activeDocument().activeView().fitAll()
    return report

if __name__=='__main__':
    import sys
    sys.path.insert(0,str(ROOT/'cad'))
    doc=App.ActiveDocument or App.openDocument(str(ROOT/'PTSD-App-Helper.FCStd'))
    print(json.dumps(build(doc),indent=2))
    doc.saveAs(str(ROOT/'PTSD-App-Helper.FCStd'))
