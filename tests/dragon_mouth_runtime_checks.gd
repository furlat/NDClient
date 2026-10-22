extends SceneTree
## Installed Dragon source images -> real optical worker -> NativeInputs mouth
## packets. No native effect construction, GPU draw, gameplay or art approval.
const Inputs=preload("res://presentation/native_inputs.gd")
const Surface=preload("res://presentation/entity_surface.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const Catalog=preload("res://source_catalog.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Timeline=preload("res://presentation/timeline.gd")
const CONDITION="res://authoring/abilities/conditions/condition.summon.draconic_breath_cadence.tres"
const RIG="summon.draconic_spirit.violet-astral"
const BANK="Ground_Idle/090"

class World extends Node3D:
    var visual_actors:Dictionary={}
    var source_images:Dictionary={}
    var catalog_cache:Dictionary={}
    var character_light_profile:String="original"
    var camera:Node3D
    var rigs:Dictionary={}
    var rig_config:Dictionary={}
    var timeline:RefCounted=Timeline.new()

var checks:int=0
var failures:Array=[]
var table:Dictionary={}
var observations:Dictionary={}

func _initialize()->void:run.call_deferred()

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("DRAGON_MOUTH_RUNTIME_FAIL ",label)

func read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):check(false,"Installed input exists: "+path);return {}
    var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not value is Dictionary:check(false,"Installed input is an object: "+path);return {}
    return value

func component(id:String,actor:String,geometry:Dictionary)->Dictionary:
    return {"id":id,"actor_uuid":actor,"target_uuid":actor,"condition_uuid":"condition-"+id,
        "age_ms":1500.0,"duration_ms":INF,"initial":false,
        "lifecycle_phases":{"application":{"seconds":1.2}},
        "native_cue":{"entity_geometry":geometry.duplicate(true)}}

func actor(world:World,id:String,position:Vector3)->void:
    var body:Node3D=Node3D.new();world.add_child(body)
    body.global_transform=Transform3D(world.camera.global_basis,position)
    world.visual_actors[id]={"valid":true,"row":{"id":id,"rig":RIG,"scale":1.0,
        "position":[position.x,position.z],"base_height_steps":position.y/Surface.Placement.HEIGHT_UNIT,"visual_height":0.0},
        "entries":[{"node":body,"actor_layer":{"slot":"body","effect":{}},"role":"body"}]}

func bind(world:World,id:String,bank_key:String,frame:int)->bool:
    var layout:Dictionary=table.banks[bank_key].layouts.selected768
    var path:String=layout.source_path
    var descriptor:Dictionary=Surface.Geometry.BodySources.prepare_descriptor(path,"body",world.catalog_cache)
    check(not descriptor.is_empty(),"Actual built source registration: "+bank_key)
    if descriptor.is_empty():return false
    for image_path in Surface.required_paths(path,"body",world.catalog_cache,world.character_light_profile):
        if world.source_images.has(image_path):continue
        var image:Image=Image.load_from_file(image_path)
        check(image!=null and not image.is_empty(),"Installed optical source image: "+image_path)
        if image==null or image.is_empty():return false
        world.source_images[image_path]=image
    var scale:float=128.0/float(world.rig_config.TILE_W)
    var geometry:Dictionary=Surface.Geometry.prepare_binding(path,"body",world.catalog_cache,true,true,world.character_light_profile,scale,1.0)
    check(geometry.parameters.get("has_component_geometry",false) and geometry.ground!=null,"Actual optical binding has geometry and ground: "+bank_key)
    if not geometry.parameters.get("has_component_geometry",false) or geometry.ground==null:return false
    var source_layout:Dictionary=descriptor.get("source_layout",{})
    var shape:Dictionary=Construction.layer_shape(world.rigs[RIG],scale,source_layout)
    var uv:Array=layout.frame_uvs[frame]
    var entry:Dictionary=world.visual_actors[id].entries[0]
    entry.merge({"texture_path":path,"pivot":shape.pivot,"geometry_ground_pixels":geometry.ground,
        "source_layout":source_layout,"source_frame_loop":true,"bound_frame_key":[null,frame,bank_key.get_file(),null],
        "source_parameters":geometry.parameters.duplicate()},true)
    entry.source_parameters.frame_uv=Vector4(float(uv[0]),float(uv[1]),float(uv[2]),float(uv[3]))
    return true

func settled(bridge:RefCounted,world:World,row:Dictionary)->Dictionary:
    var value:Dictionary=bridge.geometry_sample(world,row,"entity_geometry")
    var deadline:int=Time.get_ticks_msec()+15000
    while Time.get_ticks_msec()<deadline and (value.get("pending",false) or not bridge.surfaces.jobs.is_empty() or not bridge.surfaces.pending.is_empty()):
        await process_frame
        value=bridge.geometry_sample(world,row,"entity_geometry")
    check(bridge.surfaces.jobs.is_empty() and bridge.surfaces.pending.is_empty(),"Finite optical work completes: "+str(row.id))
    return value

func expected_pixels(world:World,bank_key:String,frame:int)->Array:
    var bank:Dictionary=table.banks[bank_key]
    var registration:Dictionary=bank.layouts.selected768
    var offset:Array=registration.pixel_to_canonical_offset
    var images:Dictionary=Surface.admitted_images(world,registration.source_path,"body").images
    var rect:Array=registration.frame_uvs[frame]
    var sheet_offset:=Vector2i(roundi(float(rect[0])*images.colour.get_width()),roundi(float(rect[1])*images.colour.get_height()))
    var expected:Array=[]
    for pixel in bank.frames[frame].pixels:
        var local:=Vector2i(int(pixel[0])-int(offset[0]),int(pixel[1])-int(offset[1]))
        var at:Vector2i=local+sheet_offset
        if images.colour.get_pixelv(at).a>=.99 and images.depth.get_pixelv(at).a>=.5 and images.normal.get_pixelv(at).a>=.5 \
                and images.support.get_pixelv(at).r>=.5 and images.normal_valid.get_pixelv(at).r>=.5:expected.append(local)
    expected.sort_custom(func(a,b):return a.y<b.y or a.y==b.y and a.x<b.x)
    return expected

func pixels(value:Dictionary)->Array:
    return value.get("points",[]).map(func(point):return point.pixel)

func refused(value:Dictionary,label:String)->void:
    check(not value.get("ready",false) and value.get("points",[]).is_empty(),label+": no stale or fallback body points ("+str(value.get("reason",""))+")")

func run()->void:
    var condition:Resource=load(CONDITION)
    var geometry:Dictionary=condition.lifecycle_geometry
    if geometry.get("region",{}).get("kind")!="authored_pixels":
        check(false,"Installed condition selects authored mouth pixels");finish();return
    table=read(geometry.region.table)
    var receivers:Dictionary=read(geometry.region.receiver_inputs)
    if table.is_empty() or receivers.is_empty():finish();return
    var world:World=World.new();root.add_child(world)
    # Use the ordinary passive admission boundary before any geometry query.
    Conditions.prepare_geometry_metadata({"condition_uuid":"condition-cadence-a","behavior_id":condition.id,
        "state":{"ready":true,"breath_type":"Fire"}},world.catalog_cache)
    check(world.catalog_cache.has(geometry.region.table) and world.catalog_cache.has(geometry.region.receiver_inputs),"Actual condition admits both optical documents before sampling")
    world.rigs=Surface.Geometry.BodySources.index(world.catalog_cache).rigs
    world.rig_config=Catalog.read_file("catalog/rig.json",world.catalog_cache)
    world.camera=Node3D.new();world.add_child(world.camera)
    world.camera.transform=Surface.Placement.camera_transform(Vector3.ZERO,0)
    actor(world,"dragon-a",Vector3.ZERO);actor(world,"dragon-b",Vector3(6,1,-3))
    if not bind(world,"dragon-a",BANK,0) or not bind(world,"dragon-b",BANK,0):world.free();finish();return
    var bridge:RefCounted=Inputs.new()
    var a:Dictionary=component("cadence-a","dragon-a",geometry)
    var b:Dictionary=component("cadence-b","dragon-b",geometry)
    var first:Dictionary=bridge.geometry_sample(world,a,"entity_geometry")
    check(not first.ready and first.pending,"Cold real source waits for optical measurement without publishing body points")
    var initial:Dictionary=await settled(bridge,world,a)
    check(initial.ready and pixels(initial)==expected_pixels(world,BANK,0) and initial.points.size()>=2,"Exact admitted authored lip pixels preserve raster order")
    if not initial.ready:bridge.clear();world.free();finish();return
    check(initial.geometry_slots==["body"] and initial.region_id=="mouth","Actual body points retain the mouth region and body slot")
    # One independent ordinary full-body reference outside candidate sampling.
    # It borrows the same immutable measured rows; the candidate builds none.
    var reference:RefCounted=Surface.new();reference.sources=bridge.surfaces.sources.duplicate()
    var whole:Dictionary=reference.sample(world,"dragon-a",["body"])
    var wanted:Array=pixels(initial)
    var expected:Array=whole.points.filter(func(point):return point.pixel in wanted)
    check(whole.ready and whole.points.size()>initial.points.size() and initial.points==expected,"Sparse packets equal ordinary source position, inverse-transpose normal, UV and pixel values")
    reference.clear()
    var built:int=bridge.surfaces.source_builds
    for attempt in 4:
        var held:Dictionary=bridge.geometry_sample(world,a,"entity_geometry")
        check(held.points==initial.points and held.region_revision==initial.region_revision,"Held mouth retains exact points and revision")
    check(bridge.surfaces.source_builds==built and bridge.surfaces.packet_builds==0,"Held mouth neither remeasures source nor builds a whole-body packet")
    var held_usec:Array=[]
    for attempt in 100:
        var started:int=Time.get_ticks_usec()
        bridge.geometry_sample(world,a,"entity_geometry")
        held_usec.append(Time.get_ticks_usec()-started)
    held_usec.sort()
    var before:PackedByteArray=var_to_bytes(initial)
    var translation:=Vector3(.31,.12,-.14)
    var shown:Dictionary=world.visual_actors["dragon-a"]
    shown.entries[0].node.position+=translation
    shown.row.position=[translation.x,translation.z];shown.row.base_height_steps=translation.y/Surface.Placement.HEIGHT_UNIT
    var moved:Dictionary=bridge.geometry_sample(world,a,"entity_geometry")
    check(moved.ready and moved.region_revision!=initial.region_revision,"Whole actor translation changes mouth revision even when relative body placement is unchanged")
    check(moved.points.size()==initial.points.size() and moved.points.all(func(point):return (point.position-initial.points[pixels(initial).find(point.pixel)].position).is_equal_approx(translation)),"Only actual actor translation moves the retained lip points")
    check(bridge.surfaces.source_builds==built and bridge.surfaces.packet_builds==0 and var_to_bytes(initial)==before,"Movement transforms sparse rows without rebuilding full body or mutating a previous packet")
    var other:Dictionary=bridge.geometry_sample(world,b,"entity_geometry")
    check(other.ready and not is_same(other.points,moved.points) and (other.points[0].position-initial.points[0].position).is_equal_approx(Vector3(6,1,-3)),"Second actor receives private transformed mouth points from the shared physical source")
    check(bridge.mouth_surfaces.size()==2 and bridge.surfaces.source_builds==built,"Two occurrence owners retain separate selections and share source measurement")
    var frame_before:Array=moved.region_revision.duplicate(true)
    bind(world,"dragon-a",BANK,1)
    var next:Dictionary=await settled(bridge,world,a)
    check(next.ready and next.region_revision!=frame_before and pixels(next)==expected_pixels(world,BANK,1),"Animated source frame changes reselect actual lip pixels without a resource-preparation callback")
    var entry:Dictionary=shown.entries[0]
    entry.node.hide();refused(bridge.geometry_sample(world,a,"entity_geometry"),"Hidden body");entry.node.show()
    for change in [{"layout":"new512"},{"status":"missing"}]:
        var rejected:Dictionary=a.duplicate(true);rejected.native_cue.entity_geometry.region.merge(change,true)
        refused(bridge.geometry_sample(world,rejected,"entity_geometry"),"Unavailable authored route "+str(change))
    shown.row.rig="other-rig";refused(bridge.geometry_sample(world,a,"entity_geometry"),"Wrong actual rig");shown.row.rig=RIG
    var saved_path:String=entry.texture_path
    entry.texture_path="res://unregistered-dragon.png"
    refused(bridge.geometry_sample(world,a,"entity_geometry"),"Wrong actual source path");entry.texture_path=saved_path
    var saved_uv:Vector4=entry.source_parameters.frame_uv
    var first_uv:Array=table.banks[BANK].layouts.selected768.frame_uvs[0]
    entry.source_parameters.frame_uv=Vector4(first_uv[0],first_uv[1],first_uv[2],first_uv[3])
    refused(bridge.geometry_sample(world,a,"entity_geometry"),"UV disagrees with displayed frame");entry.source_parameters.frame_uv=saved_uv
    bind(world,"dragon-a","Ground_Idle/000",0)
    var occluded:Dictionary=await settled(bridge,world,a)
    refused(occluded,"Actual rear-facing authored occlusion")
    check(not occluded.get("pending",false),"Unexposed lip is unavailable rather than permanently preparing")
    world.timeline.state={"actors":{"dragon-a":{"conditions":[{"condition_uuid":a.condition_uuid,"state":{"ready":false,"breath_type":"Fire"}}]}}}
    var readiness:Dictionary=Inputs.readiness_packet(world,a,occluded)
    check(readiness.ready and not readiness.value.ready and not readiness.value.has("mouth_surface_revision"),"Public ready=false survives absent mouth without inventing a surface revision")
    bridge.retire({b.id:true})
    check(bridge.mouth_surfaces.size()==1 and bridge.geometry_sample(world,b,"entity_geometry").ready,"Retiring one occurrence preserves the other actor's current mouth")
    observations={"selected_pixels":wanted.size(),"reference_body_points":whole.points.size(),"source_builds":bridge.surfaces.source_builds,"whole_body_packet_builds":bridge.surfaces.packet_builds,
        "held_samples":held_usec.size(),"held_median_usec":held_usec[50],"held_p95_usec":held_usec[95],"held_max_usec":held_usec[-1]}
    check(bridge.surfaces.packet_builds==0,"Every candidate route bypasses full-body composition")
    bridge.clear()
    check(bridge.mouth_surfaces.is_empty() and bridge.surfaces.sources.is_empty() and bridge.surfaces.jobs.is_empty(),"World teardown clears selections and owned optical work")
    world.free();finish()

func finish()->void:
    print("DRAGON_MOUTH_RUNTIME ",JSON.stringify({"checks":checks,"failures":failures,"observations":observations,
        "scope":"Installed selected768 optical images and NativeInputs sparse mouth packets, real worker lifecycle and public ready=false projection. No GPU rendering, finite breath, performance target or art approval."}))
    quit(0 if failures.is_empty() else 1)
