"""Compact PiSugar 3 Plus arm case. Native BRep stages, dimensions in mm.
Run Rebuild-PiSugar-Case.FCMacro after changing PARAMETERS.
"""
import json
from pathlib import Path
import FreeCAD as App
import Part
import MeshPart
from arm_mount import rounded_rect
from ups_stack import world_feature, upsert, valid, bounds
ROOT=Path(__file__).resolve().parent.parent
V=App.Vector
PI='RP_004882_DD___Pi_5_Mechanical_Reference_3D_model_Iss1'
MOVED=[PI,'PCB_Component','PCB_Component001','Body002','Qwiic_Shield_for_RaspberryPi_1']
PARAMETERS=dict(center_floor_thickness=2.5,battery_clearance=2.0,
                top_clearance=1.5,roof_thickness=2.0,lid_seat_clearance=.25)


def xzbox(x0,z0,x1,z1,r,ymin,h):
    s=rounded_rect(x0,z0,x1,z1,r,0,h)
    s.rotate(V(),V(1,0,0),90);s.translate(V(0,ymin+h,0))
    return s


def stretch(shape,plane,delta):
    low=shape.common(Part.makeBox(300,plane+100,300,V(-150,-100,-150)))
    high=shape.common(Part.makeBox(300,150-plane,300,V(-150,plane,-150)))
    high.translate(V(0,delta,0))
    section=Part.makeFace(shape.slice(V(0,1,0),plane),'Part::FaceMakerBullseye')
    return low.fuse(section.extrude(V(0,delta,0)),1e-5).fuse(high,1e-5).removeSplitter()


def intersection(a,b):
    if not a.BoundBox.intersect(b.BoundBox):return 0.0
    return a.common(b).Volume


def build(doc,output_dir=ROOT,parameters=None):
    p=dict(PARAMETERS);p.update(parameters or {})
    out=Path(output_dir);(out/'cad').mkdir(parents=True,exist_ok=True)
    base=world_feature(doc.Body001,doc.ArmComfortEdges)
    original_lid=world_feature(doc.Body005,doc.Pocket005)
    existing=doc.getObject('PiSugarCasePorts')
    if existing and 'OriginalPlacements' in existing.PropertiesList:
        placements=json.loads(existing.OriginalPlacements)
    else:
        placements={n:[list(doc.getObject(n).Placement.Base),list(doc.getObject(n).Placement.Rotation.Q)] for n in MOVED}
    # Original center saddle surface is Y=-7. Pi PCB underside is Y=0.1.
    # PiSugar mounting nut height is 2.6; modeled battery reaches Z=-12.4.
    floor=-7+p['center_floor_thickness']
    lift=floor+p['battery_clearance']+14.9
    origin=lift-2.5
    roof_inside=17.95+lift+p['top_clearance']
    roof_top=roof_inside+p['roof_thickness']
    if min(p.values())<=0:raise ValueError('All clearances and wall thicknesses must be positive')
    if p['center_floor_thickness']<2 or p['roof_thickness']<2:raise ValueError('Keep at least 2 mm shell thickness')
    doc.openTransaction('Compact PiSugar arm enclosure')
    try:
        for n,(pos,quat) in placements.items():
            obj=doc.getObject(n);obj.Placement=App.Placement(V(*pos)+V(0,lift,0),App.Rotation(*quat))
        sugar=doc.PiSugar_3_Plus
        sugar.Placement=App.Placement(V(40.5,origin,-24),App.Rotation(V(-1,0,0),V(0,0,1),V(0,1,0),'ZXY'))
        case=stretch(base,-1.1,lift)
        case=case.common(Part.makeBox(300,roof_inside+100,300,V(-150,-100,-150)))
        roof=[f for f in base.Faces if f.BoundBox.YLength<1e-5 and abs(f.BoundBox.YMin-26)<1e-5][0].copy()
        roof.translate(V(0,roof_inside-26,0))
        case=case.fuse(roof.extrude(V(0,p['roof_thickness'],0)),1e-5)
        # Recess only the electronics floor, keeping the curved arm contact skin.
        case=case.cut(xzbox(-46.7,-25.8,42,33.8,1,floor,20))
        # The imported lead is a generous swept keep-out. Retain its full envelope.
        # Pocket lies outside the original inner wall; it does not crowd either PCB.
        outer=xzbox(-56.6,-30.1,-47.3,-1.8,2,floor-2.5,24)
        inner=xzbox(-54.1,-28.1,-42,-3.8,1,floor,16.5)
        case=case.fuse(outer,1e-5).cut(inner).removeSplitter()
        compact=case.copy();valid(compact,'Compact shell')
        # One side opening serves Pi USB-C/HDMI plus PiSugar charge ports/buttons.
        # A shared opening avoids fragile webs between these stacked connectors.
        service=rounded_rect(-40,origin-5.2,14,origin+8.2,1.5,30,15)
        case=case.cut(service).removeSplitter();valid(case,'Ported case')
        lid=stretch(original_lid,-1.1,lift)
        lid=lid.common(Part.makeBox(300,roof_top-.07+100,300,V(-150,-100,-150))).removeSplitter()
        extended_lid=lid.copy()
        rim=Part.makeFace(case.slice(V(1,0,0),46.76),'Part::FaceMakerBullseye')
        rim.translate(V(-.02,0,0))
        lid=lid.cut(rim.extrude(V(.06+p['lid_seat_clearance'],0,0))).removeSplitter()
        valid(lid,'PiSugar lid')
        checks={}
        for n in MOVED:
            sh=Part.getShape(doc.getObject(n))
            checks[n]={'case_mm3':intersection(sh,case),'lid_mm3':intersection(sh,lid)}
            if max(checks[n].values())>1e-5:raise RuntimeError('Enclosure collision with '+n+': '+str(checks[n]))
        for obj in sugar.Group:
            sh=Part.getShape(obj);sh.Placement=sugar.Placement.multiply(sh.Placement)
            checks[obj.Name]={'label':obj.Label,'case_mm3':intersection(sh,case),'lid_mm3':intersection(sh,lid)}
            if max(checks[obj.Name][k] for k in ['case_mm3','lid_mm3'])>1e-5:raise RuntimeError('Enclosure collision with '+obj.Label+': '+str(checks[obj.Name]))
        sugar_shape=Part.getShape(sugar);pi_shape=Part.getShape(doc.getObject(PI))
        contact=sugar_shape.common(pi_shape)
        # Vendor spring pins are modeled uncompressed. Permit only six pin-tip
        # contacts at the GPIO solder tails, not arbitrary PCB/part overlap.
        contacts=[]
        for s in contact.Solids:
            b=s.BoundBox
            if b.XLength>1.001 or b.ZLength>1.001 or b.YLength>.801 or b.ZMin<-23 or b.ZMax>-18 or b.YMin<lift-.301 or b.YMax>lift+.501:
                raise RuntimeError('PiSugar/Pi collision outside the spring-pin contact envelope')
            contacts.append({'volume_mm3':s.Volume,'bounds_xyz_mm':bounds(s)})
        checks['modeled_uncompressed_pogo_contacts']=contacts
        checks['case_vs_lid_mm3']=intersection(case,lid)
        if checks['case_vs_lid_mm3']>1e-5:raise RuntimeError('Lid overlap')
        arm_zone=Part.makeBox(300,95.0,300,V(-150,-100,-150))
        original_arm=base.common(arm_zone)
        checks['original_arm_surface_material_removed_mm3']=original_arm.cut(case).Volume
        if checks['original_arm_surface_material_removed_mm3']>1e-5:raise RuntimeError('Arm contact surface changed')
        # Hole centers align with the Pi, at a 58 x 49 mm pattern.
        holes=[sugar.Placement.multVec(V(x,z,2.6)) for x,z in [(23.5,3.5),(81.5,3.5),(23.5,52.5),(81.5,52.5)]]
        for h in holes:
            if min((h-V(x,.1+lift,z)).Length for x,z in [(-41,-20.5),(-41,28.5),(17,-20.5),(17,28.5)])>1e-6:raise RuntimeError('Mounting pattern misalignment')
        upsert(doc.Body001,'PiSugarCompactShell','PiSugar | recessed floor and compact roof',compact)
        cf=upsert(doc.Body001,'PiSugarCasePorts','PiSugar | compact case and service opening',case)
        upsert(doc.Body005,'PiSugarLidProfile','PiSugar | shortened lid',extended_lid)
        lf=upsert(doc.Body005,'PiSugarLidSeat','PiSugar | lid with seating clearance',lid)
        doc.Body001.Tip=cf;doc.Body005.Tip=lf
        if 'OriginalPlacements' not in cf.PropertiesList:cf.addProperty('App::PropertyString','OriginalPlacements','Rebuild')
        cf.OriginalPlacements=json.dumps(placements);cf.setEditorMode('OriginalPlacements',2)
        for name,value in dict(p,center_depth=roof_top+7,pi_lift=lift).items():
            prop=''.join(x.title() for x in name.split('_'))
            if prop not in cf.PropertiesList:cf.addProperty('App::PropertyLength',prop,'PiSugar fit')
            setattr(cf,prop,value);cf.setEditorMode(prop,1)
        if 'AssemblyNote' not in sugar.PropertiesList:sugar.addProperty('App::PropertyString','AssemblyNote','Assembly')
        sugar.AssemblyNote='Under Pi, aligned on mounting nuts; vendor pogo pins shown uncompressed. Battery and lead approximated. Rebuild with cad/Rebuild-PiSugar-Case.FCMacro.'
        obsolete=doc.getObject('SupersededWaveshare') or doc.addObject('App::DocumentObjectGroup','SupersededWaveshare')
        obsolete.Label='Superseded Waveshare hardware (hidden)'
        for n in ['Waveshare_UPS_HAT__B_','UPSStackSpacers']:
            obj=doc.getObject(n)
            if obj and obj not in obsolete.Group:obsolete.addObject(obj)
        doc.recompute();valid(doc.Body001.Shape,'Recomputed case');valid(doc.Body005.Shape,'Recomputed lid')
        doc.commitTransaction()
    except Exception:
        doc.abortTransaction();raise
    exports={}
    for suffix,sh in [('Case-PiSugar',case),('Lid-PiSugar',lid)]:
        m=MeshPart.meshFromShape(Shape=sh,LinearDeflection=.08,AngularDeflection=.12,Relative=False)
        if not m.isSolid():raise RuntimeError('Mesh not closed: '+suffix)
        stem=out/('PTSD-App-Helper-'+suffix)
        m.write(str(stem)+'.stl');sh.exportStep(str(stem)+'.step')
        exports[suffix]={'valid':sh.isValid(),'solids':len(sh.Solids),'mesh_closed':m.isSolid(),'facets':m.CountFacets,'bounds_xyz_mm':bounds(sh)}
    report={'parameters_mm':p,'pi_lift_mm':lift,'floor_height_mm':floor,'roof_inner_height_mm':roof_inside,'roof_top_height_mm':roof_top,
            'center_case_depth_mm':roof_top+7,'previous_waveshare_center_depth_mm':67,'depth_reduction_mm':67-(roof_top+7),
            'battery_floor_clearance_mm':p['battery_clearance'],'pi_roof_clearance_mm':p['top_clearance'],
            'mounting_holes_xyz_mm':[list(h) for h in holes],'checks':checks,'exports':exports,
            'note':'Compact fit for modeled hardware; vendor board with approximate battery/lead. Pogo pin contact overlap is intentional uncompressed reference geometry. Additional cooler not modeled.'}
    (out/'cad'/'pisugar-case-validation.json').write_text(json.dumps(report,indent=2)+'\n')
    if App.GuiUp:
        import FreeCADGui as Gui
        for body in [doc.Body001,doc.Body005]:
            for o in body.Group:
                if hasattr(o,'ViewObject'):o.ViewObject.Visibility=False
            body.ViewObject.Visibility=True;body.Tip.ViewObject.Visibility=True
            body.Tip.ViewObject.ShapeColor=(.72,.80,.85);body.Tip.ViewObject.DisplayMode='Flat Lines'
            body.Tip.ViewObject.LineColor=(.14,.20,.24)
        for n in MOVED+['PiSugar_3_Plus']:doc.getObject(n).ViewObject.Visibility=True
        for n in ['Waveshare_UPS_HAT__B_','UPSStackSpacers','SupersededWaveshare','Body','Body004']:
            o=doc.getObject(n)
            if o:o.ViewObject.Visibility=False
        Gui.activeDocument().activeView().setCameraOrientation(App.Rotation(V(),V(0,1,0),V(1,1,1),'ZYX').Q)
        Gui.activeDocument().activeView().fitAll()
    return report

if __name__=='__main__':
    doc=App.ActiveDocument or App.openDocument(str(ROOT/'PTSD-App-Helper.FCStd'))
    print(json.dumps(build(doc),indent=2));doc.saveAs(str(ROOT/'PTSD-App-Helper.FCStd'))
