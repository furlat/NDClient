extends SceneTree
## Material ownership/admission, with the actual lit source shaders. Sprites
## light themselves: the source material is the displayed material, so there
## are no receiving copies to admit. Real Gallery framebuffer parity is
## qualified by actor_preparation_native_checks.
const Construction=preload("res://presentation/actor_construction.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Sources=preload("res://presentation/sprite_sources.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const PATH="/media/smallscale/modular/material-preparation-fixture.png"
const ALT_PATH="/media/smallscale/modular/material-preparation-damage.png"
const MISSING_PATH="/media/smallscale/modular/material-preparation-unsupported.png"
var checks:int=0
var failures:Array=[]
class Host extends Node3D:
    var camera:Camera3D
    var textures:Dictionary={}
    var source_images:Dictionary={}
    var resources:Dictionary={}
    var catalog_cache:Dictionary={}
    var source_depth:bool=true
    var source_normals:bool=true
    var character_light_profile:String="original"
    var component_renderer:Dictionary={}
    var profile:Dictionary={}
    func texture(path:String)->Texture2D:return textures.get(path)
var host:Host
var entry:Dictionary
var rig:Dictionary={"cell_width":64,"cell_height":64,"facing_rows":{"SW":0,"NE":1}}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ACTOR_MATERIAL_FAIL ",label)
func bind(frame:int=0,facing:String="SW",alpha:float=1.0,path:String=PATH)->void:
    var state:Dictionary=Construction.Conditions.material("actor",[])
    state.alpha=alpha
    Construction.bind_source(host,entry,rig,path,frame,facing,Construction.Conditions.parameters(state,host.textures,host.resources))
func geometry_fixture()->void:
    var body=Construction.CharacterGeometry.BodySources
    var index=body.Index.new();var layer=body.Layer.new()
    var records:Dictionary={}
    for path in [PATH,ALT_PATH]:
        var name:String="Idle" if path==PATH else "TakeDamage"
        var files:Dictionary={};var profiles:Dictionary={}
        for field in ["depth","normal","support","normal_valid"]:
            files[field]=name+"-"+field
            host.textures["/fixture/"+files[field]]=ImageTexture.create_from_image(host.source_images[PATH])
        for profile in ["original","gentle","reference"]:profiles[profile]="/fixture/"+files.normal
        var source={"_source_root":"/fixture","status":"complete","files":files,"cell_size":[64,64],
            "depth_range":[-8,16],"optical_camera":{"origin":[32,48],"elevation_degrees":45},
            "optical_ground_pixels":19.0 if path==PATH else null}
        records[name]={"body":{"geometry":source,"normal_paths":profiles}}
        index.source_owners[path]=["fixture-layer",name]
    layer.clips=records
    var loaded:Dictionary={"fixture-layer":layer}
    for name in records:
        var clip=body.Clip.new();clip.descriptors=records[name]
        var clip_path:String="fixture-layer::"+name
        layer.clip_sources[name]=clip_path;loaded[clip_path]=clip
    for path in [PATH,ALT_PATH,MISSING_PATH]:layer.headers[path]={"width":192,"height":128}
    index.source_owners[MISSING_PATH]=["fixture-layer","Missing"]
    host.catalog_cache[body.KEY]={"index":index,"loaded":loaded}

func future_binding_checks()->void:
    for target in [ALT_PATH,MISSING_PATH]:
        for flags in [[true,true,"original",1.0],[false,true,"gentle",-1.0],[true,false,"reference",1.0],[true,true,"missing-profile",1.0]]:
            host.source_depth=flags[0];host.source_normals=flags[1];host.character_light_profile=flags[2];reset()
            entry.placement.scale_x=flags[3]
            var old_parameters:Dictionary=entry.source_parameters.duplicate()
            var old_bounds:AABB=entry.node.custom_aabb
            var future:Dictionary=Construction.prepare_binding(rig,entry.actor_layer,target,host.catalog_cache,
                host.source_depth,host.source_normals,host.character_light_profile,entry.scale,entry.placement.scale_x)
            var ready:Dictionary=Construction.realize_binding(host,future)
            check(not ready.is_empty(),"Future clip borrows resident texture operands "+str([target,flags]))
            check(entry.source_parameters==old_parameters and entry.node.custom_aabb==old_bounds,"Preparing future clip never changes displayed uniforms/bounds")
            # Existing synchronous binder is an independent exact operand oracle.
            bind(1,"NE",.4,target)
            var expected:Dictionary=entry.source_parameters.duplicate()
            var bounds:AABB=entry.node.custom_aabb
            var status:String=entry.geometry_status
            reset();entry.placement.scale_x=flags[3]
            var binding_revision:int=entry.source_binding_revision
            entry.prepared_source_binding=ready
            bind(1,"NE",.4,target)
            check(entry.source_parameters==expected,"Future packet applies exact original final source/UV/condition values "+str([target,flags]))
            check(entry.node.custom_aabb==bounds and entry.geometry_status==status,"Future packet preserves original optical bounds/status")
            check(entry.source_binding_revision==binding_revision,"Future clip packet does not replace private material ownership")
            check(entry.node.material_override==entry.material,"Future clip packet keeps the source material displayed "+str([target,flags]))
    host.source_depth=true;host.source_normals=true;host.character_light_profile="original"

func future_support_checks()->void:
    var Renderer=preload("res://presentation/native_spell_renderer.gd")
    var renderer=Renderer.new();renderer._support=Renderer.Support.new();renderer._required_ids={"real-spell":true}
    var paths:Dictionary=Construction.CharacterGeometry.BodySources.descriptor(ALT_PATH,"body",host.catalog_cache)
    paths.optical_paths={"solid":"/fixture/future-solid"}
    var absent:Dictionary=renderer.prepare_actor_binding(ALT_PATH,"body",host)
    check(not absent.ready and renderer._support.solid_masks.is_empty(),"Future native solid binding waits for its actual resident mask")
    host.textures["/fixture/future-solid"]=host.textures[ALT_PATH]
    var prepared_mask:Dictionary=renderer.prepare_actor_binding(ALT_PATH,"body",host)
    check(prepared_mask.ready and renderer._support.solid_masks.is_empty(),"Preparing future optical mask does not publish future actor pose or binding")
    renderer.publish_actor_binding(prepared_mask)
    check(renderer._support.solid_masks.get(ALT_PATH)==host.textures[ALT_PATH] and renderer._support.actors.is_empty(),"Cue publishes exact mask into existing support owner without proxy allocation")
    renderer._support=Renderer.Support.new();renderer.publish_actor_binding(prepared_mask)
    check(renderer._support.solid_masks.is_empty(),"Old source packet cannot mutate replacement optical owner")
    renderer._support=null

func future_support_transition_checks()->void:
    var Renderer=preload("res://presentation/native_spell_renderer.gd")
    var Media=preload("res://presentation/media_warmup.gd")
    var renderer=Renderer.new();renderer._support=Renderer.Support.new()
    host.component_renderer={"native_spells":renderer,"blood":preload("res://presentation/blood_renderer.gd").new()}
    var solid:String="/fixture/future-solid";host.textures.erase(solid)
    reset()
    var candidate=Preparation.new();host.add_child(candidate);candidate.host=host;candidate.phase="sampling"
    candidate.result={"blood_rows":{}}
    candidate.required_source_record=Media.source_record({solid:true},{},{},{solid:true})
    var value:Dictionary=Construction.prepare_binding(rig,entry.actor_layer,ALT_PATH,host.catalog_cache,true,true,"original",entry.scale,1.0)
    candidate.actor_bindings=[{"entry":entry,"value":value,"actor":"actor","owner":{}}]
    candidate.step(100000)
    check(candidate.prepared and not renderer.actor_bindings_needed(),"Ordinary cold clip completes while native support is not needed")
    check(not candidate.actor_bindings[0].optical.has("mask"),"Inactive optical support does not demand or pretend to prepare a future mask")
    var media:Dictionary=Media.create();Media.adopt_required(media,1)
    Media.demand_records(media,[])
    renderer.groups={"prior-native-tail":{}}
    if renderer.actor_bindings_needed():Media.demand_records(media,[candidate.required_source_record])
    check(media.wanted.has(solid) and not media.cpu_required.has(solid),"A prior native tail promotes the exact future cold mask as GPU-only required source")
    candidate.step(100000)
    check(not candidate.prepared and candidate.phase=="sampling" and is_same(candidate.actor_bindings[0].value,value),"Late optical activation reopens only retained binding work before admission")
    check(renderer._support.solid_masks.is_empty(),"Waiting on a cold future mask never changes current support bindings")
    host.textures[solid]=host.textures[ALT_PATH]
    Media.published(media,{"path":solid,"cpu_bytes":0,"gpu_bytes":64})
    candidate.step(100000)
    check(candidate.prepared and Media.ready(media,{solid:true}),"Exact future-mask publication completes the held candidate")
    candidate.publish_actor_bindings()
    check(renderer._support.solid_masks.get(ALT_PATH)==host.textures[solid],"Cue adopts the now-resident future mask into the existing tail support")
    var previous:RefCounted=renderer._support;renderer._support=Renderer.Support.new()
    candidate.step(100000);candidate.publish_actor_bindings()
    check(candidate.prepared and renderer._support.solid_masks.get(ALT_PATH)==host.textures[solid] and renderer._support!=previous,"Replacement support owner refreshes actual mask operands without source metadata derivation")
    Media.demand_records(media,[])
    check(not media.wanted.has(solid),"Withdrawing the candidate releases its exact mask contribution")
    candidate.release_handles();candidate.free();Media.close(media)
    renderer.groups.clear();renderer._support=null;host.component_renderer={}
func reset()->void:
    if not entry.is_empty():entry.node.free()
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(1,1);host.add_child(node);node.hide()
    var source=ShaderMaterial.new();source.shader=Construction.MODULAR_SHADER
    node.material_override=source
    entry={"node":node,"material":source,"cell":Vector2(64,64),"scale":1.0,"role":"body",
        "placement":{"id":"actor","kind":"actor","scale_x":1.0},
        "actor_layer":{"slot":"body","paths":{"Idle":PATH}}}
    bind()
    check(entry.node.material_override==entry.material and not entry.node.visible,
        "Resident actor source binds its own lit material without receiving copies or exposure")
# The ledger after a change-and-return equals a fresh binding of the same sample.
func fresh_parameters()->Dictionary:
    var saved:Dictionary=entry;entry={}
    var node:MeshInstance3D=saved.node
    reset();var value:Dictionary=entry.source_parameters.duplicate()
    entry.node.free();entry=saved
    check(is_instance_valid(node),"Fresh reference binding leaves the probed source alive")
    return value
func compare_fresh(label:String)->void:
    var actual:Dictionary=entry.source_parameters.duplicate()
    var expected:Dictionary=fresh_parameters()
    var different:Array=[]
    # Palette operands are inert while effect_palette_enabled is false; a
    # removed palette keeps its last operands behind that disabled gate.
    var inert:Callable=func(name:StringName)->bool:
        return str(name).begins_with("effect_") and name!=&"effect_palette_enabled" and not actual.get(&"effect_palette_enabled",false)
    for name in expected:
        if inert.call(name):continue
        if not actual.has(name) or actual[name]!=expected[name]:different.append(name)
    for name in actual:
        if not expected.has(name) and not inert.call(name):different.append(name)
    check(different.is_empty(),label+": source ledger returns to the fresh binding "+str(different))
    if not different.is_empty():
        for name in different:print("LEDGER_DIFFERENCE ",label," ",name," actual=",actual.get(name,"<absent>")," fresh=",expected.get(name,"<absent>"))
    check(entry.node.material_override==entry.material,label+": the source material stays displayed")

func water_clock_ownership()->void:
    var first=Sources.new();var second=Sources.new();root.add_child(first);root.add_child(second)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();first.add_child(node)
    var material=ShaderMaterial.new();material.shader=Sources.WATER_SHADER;node.material_override=material
    var water:Dictionary={"node":node,"material":material}
    var retained:WeakRef=weakref(material)
    first._register_water_clock(water)
    node.reparent(second,false)
    check(first.water_materials.is_empty(),"Moving a water source releases its previous clock owner")
    second._register_water_clock(water)
    check(second.water_materials.size()==1,"The new water source owner can register its displayed clock")
    water={};material=null;node.queue_free()
    await process_frame;await process_frame
    check(second.water_materials.is_empty() and retained.get_ref()==null,"Retiring water releases clock references and its native material")
    first.queue_free();second.queue_free();await process_frame

func run()->void:
    host=Host.new();root.add_child(host)
    host.camera=Camera3D.new();host.add_child(host.camera)
    var image=Image.create(192,128,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    host.textures[PATH]=ImageTexture.create_from_image(image);host.source_images[PATH]=image
    host.textures[ALT_PATH]=ImageTexture.create_from_image(image)
    host.textures[MISSING_PATH]=host.textures[PATH]
    geometry_fixture()
    future_binding_checks()
    future_support_checks()
    future_support_transition_checks()
    reset();SourceMaterial.acknowledge(entry);bind(1,"NE",.4)
    check(entry.material.get_shader_parameter("condition_alpha")==.4,"First sample delivers current opacity to the displayed source material")
    check(entry.source_changes.has(&"condition_alpha") and entry.source_changes.has(&"frame_uv"),"First sample after acknowledgement records only changed operands")
    reset();bind(1);bind(2);bind(0)
    compare_fresh("Several ordinary frames")
    reset();bind(1,"SW",.4);bind(2,"SW",1.0);bind(0)
    compare_fresh("Opacity change and return")
    reset();host.source_depth=false;bind(1);host.source_depth=true;bind(2);bind(0)
    compare_fresh("Optical change and return")
    reset();entry.actor_layer.effect={"palette":{"colors":[0xffffff,0x4488aa]}};bind(1)
    entry.actor_layer.effect={};bind(2);bind(0)
    check(SourceMaterial.value(entry,"effect_palette_enabled")==false,"Removing the palette disables its shader gate")
    compare_fresh("Palette change and return")
    reset();host.textures[PATH]=ImageTexture.create_from_image(image);bind()
    check(entry.material.get_shader_parameter("sheet")==host.textures[PATH],"Replacement resident texture binds the current sheet")
    reset();SourceMaterial.acknowledge(entry)
    var binding_revision:int=entry.source_binding_revision
    bind(1,"NE",1.0,ALT_PATH)
    check(entry.source_binding_revision==binding_revision,"Another clip keeps its source material identity")
    check(not entry.source_changes.has(&"has_component_geometry"),"Supported clip change never clears and restores geometry")
    check(not entry.has("geometry_ground_pixels"),"A clip without optical ground releases the previous optional value")
    check(entry.geometry_paths.size()==4 and not entry.geometry_paths.has("/fixture/Idle-depth"),"Clip binding replaces old optical path ownership")
    reset();bind(0,"SW",1.0,MISSING_PATH)
    check(not SourceMaterial.value(entry,"has_component_geometry") and entry.geometry_paths.is_empty() and not entry.has("geometry_ground_pixels"),"Unsupported source clears geometry and optional metadata")
    for name in Construction.CharacterGeometry.PARAMETERS.values():check(SourceMaterial.value(entry,name)==null,"Unsupported source clears "+name)
    reset();host.character_light_profile="missing-profile";bind()
    check(entry.geometry_status=="incomplete_normal_profile" and not SourceMaterial.value(entry,"has_component_geometry"),"Incomplete normal profile clears the previous supported geometry")
    for name in Construction.CharacterGeometry.PARAMETERS.values():check(SourceMaterial.value(entry,name)==null,"Incomplete profile clears "+name)
    host.character_light_profile="original";bind()
    check(SourceMaterial.value(entry,"has_component_geometry"),"Recovery from incomplete profile restores supported geometry")
    compare_fresh("Recovery from incomplete profile")
    reset()
    var private_source=weakref(entry.material)
    var private_mesh=weakref(entry.node.mesh)
    var candidate=Preparation.new();host.add_child(candidate);entry.node.reparent(candidate,false)
    candidate.entries=[entry]
    var actor:Dictionary={"entries":[entry],"new_entries":[entry]}
    candidate.native_actors={"actor":actor};candidate.result={"actors":{"actor":actor}}
    entry={};actor={}
    var held:Array=candidate.release_handles()
    check(held.size()==2 and held.all(func(value):return is_same(value,held[0])),"Cancelled private layer transfers its exact node handle to retirement")
    check(candidate.entries.is_empty(),"Cancelled owner keeps no live source directory")
    check(private_source.get_ref()!=null and held[0].node.material_override==private_source.get_ref(),"Private material remains owned until its node retires")
    held.clear();candidate.free()
    await process_frame;await process_frame
    check(private_source.get_ref()==null and private_mesh.get_ref()==null,"Cancelled owner releases private source material and mesh without a Dictionary cycle")
    reset()
    await water_clock_ownership()
    entry.node.free();entry={}
    host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Actual lit shader source binding, future clip packets, native support binding and material-only ownership/release; no framebuffer/performance claim."}
    FileAccess.open("res://.runtime/actor-material-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_MATERIAL_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
