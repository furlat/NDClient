extends SceneTree
## Material ownership/admission, with actual source/receiving shaders. Real
## Gallery framebuffer parity is qualified by actor_preparation_native_checks.
const Construction=preload("res://presentation/actor_construction.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Sources=preload("res://presentation/sprite_sources.gd")
const Atlas=preload("res://presentation/native_light_atlas.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
const PATH="/media/smallscale/modular/material-preparation-fixture.png"
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
    func texture(path:String)->Texture2D:return textures.get(path)
var host:Host
var atlas:RefCounted
var entry:Dictionary
var prepared:Dictionary
var rig:Dictionary={"cell_width":64,"cell_height":64,"facing_rows":{"SW":0,"NE":1}}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ACTOR_MATERIAL_FAIL ",label)
func bind(frame:int=0,facing:String="SW",alpha:float=1.0)->void:
    var state:Dictionary=Construction.Conditions.material("actor",[])
    state.alpha=alpha
    Construction.bind_source(host,entry,rig,PATH,frame,facing,Construction.Conditions.parameters(state,host.textures,host.resources))
func reset()->void:
    atlas.prepared_source_bindings.clear();prepared={}
    if not entry.is_empty():entry.node.free()
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(1,1);host.add_child(node);node.hide()
    var source=ShaderMaterial.new();source.shader=Construction.MODULAR_SHADER
    node.material_override=source
    entry={"node":node,"material":source,"cell":Vector2(64,64),"scale":1.0,"role":"body",
        "placement":{"id":"actor","kind":"actor","scale_x":1.0},
        "actor_layer":{"slot":"body","paths":{"Idle":PATH}}}
    bind()
    prepared=atlas.prepare_source_binding(entry,{},host,true)
    check(not prepared.is_empty(),"Resident actor source prepares receiving materials")
    check(prepared.specs.is_empty() and prepared.receivers.is_empty() and atlas.receivers.is_empty() and atlas.entry_specs.is_empty(),"Preparation publishes no dynamic geometry/address or atlas membership")
    check(not entry.has("received_material") and entry.node.material_override==entry.material and not entry.node.visible,"Private receiving copies never replace or expose the source mesh")
    atlas.adopt_source_binding(prepared)
func admitted()->bool:
    return Atlas.Delta._source(atlas,entry,host).has("prepared_output")
func compare_destinations(label:String)->void:
    var group:Dictionary=prepared.groups.values()[0]
    var source:Dictionary=Atlas.Delta._source(atlas,entry,host)
    check(source.has("prepared_output"),label+": source is admitted before copied outputs are used")
    entry.received_material=source.prepared_output.received_material
    entry.received_source_key=source.prepared_output.received_source_key
    atlas.last_reconcile_phases={}
    atlas._copy_parameters(group);atlas._copy_output_source(entry)
    var reference:Dictionary=entry.duplicate()
    reference.erase("received_source_key")
    reference.received_material=ShaderMaterial.new();reference.received_material.shader=Atlas.CappedModular
    var fresh:Dictionary=atlas._new_group(entry,prepared.source.crop,1.0,[],prepared.info,0)
    atlas._copy_parameters(fresh);atlas._copy_output_source(reference)
    for pair in [[group.material,fresh.material],[entry.received_material,reference.received_material]]:
        for uniform in entry.material.shader.get_shader_uniform_list():
            var name:String=uniform.name
            if name in ["use_instance_visibility"]:continue
            var accepted:Array=pair[0].shader.get_shader_uniform_list().map(func(row):return str(row.name))
            if name in accepted:check(pair[0].get_shader_parameter(name)==pair[1].get_shader_parameter(name),label+": exact full-copy source uniform "+name)
func reset_flame()->void:
    reset();atlas.prepared_source_bindings.clear();prepared={}
    var frames=Texture2DArray.new()
    var image=Image.create(64,64,false,Image.FORMAT_RGBA8);image.fill(Color.ORANGE)
    var images:Array[Image]=[image,image]
    check(frames.create_from_images(images)==OK,"Fixture source frames initialize")
    var source=ShaderMaterial.new();source.shader=Atlas.FlameSource
    entry.material=source;entry.node.material_override=source
    SourceMaterial.initialize(entry)
    SourceMaterial.set_parameter(entry,"frames",frames,true);SourceMaterial.set_parameter(entry,"alpha_pedestal",1.0/255.0,true)
    entry.placement.kind="wall"
    prepared=atlas.prepare_source_binding(entry,{},host,true)
    atlas.adopt_source_binding(prepared)
    check(prepared.receivers.is_empty() and prepared.specs.is_empty(),"Fixture copies contain no future geometry/address")
func flame_checks()->void:
    reset_flame();check(admitted(),"Unchanged original fixture material admits")
    SourceMaterial.set_parameter(entry,"frame_index",1)
    check(admitted(),"First real fixture frame admits the privately constructed copies")
    var group:Dictionary=prepared.groups.values()[0]
    check(group.version==prepared.version,"Fixture admission retains original copied version until ordinary material synchronization")
    atlas._copy_parameters(group)
    for name in ["frames","frame_index","alpha_pedestal"]:
        check(group.material.get_shader_parameter(name)==SourceMaterial.value(entry,name),"Ordinary copy binds current fixture "+name)
    reset_flame();SourceMaterial.set_parameter(entry,"frame_index",1);SourceMaterial.acknowledge(entry)
    SourceMaterial.set_parameter(entry,"frame_index",0);SourceMaterial.set_parameter(entry,"frame_index",1)
    check(admitted(),"Missed continuous fixture samples retain structural admission")
    group=prepared.groups.values()[0];atlas._copy_parameters(group)
    check(group.material.get_shader_parameter("frame_index")==1,"Missed consumer receives latest frame through a complete producer copy")
    reset_flame();SourceMaterial.set_parameter(entry,"alpha_pedestal",.1,true)
    check(not admitted(),"Changed fixture alpha correction rejects private copies")
    reset_flame();SourceMaterial.set_parameter(entry,"frames",null,true)
    check(not admitted(),"Replacement fixture texture array rejects private copies")

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
    host.catalog_cache[Construction.CharacterGeometry.TABLE]={"records":{}}
    var image=Image.create(192,128,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    host.textures[PATH]=ImageTexture.create_from_image(image);host.source_images[PATH]=image
    atlas=Atlas.new();atlas.attach(host);atlas.set_light_cap(1.0)
    reset();check(admitted(),"Identical source version admits exact material owners");compare_destinations("Unchanged source")
    reset();SourceMaterial.acknowledge(entry);bind(1,"NE",.4)
    entry.received_material=prepared.output.received_material
    entry.received_source_key=prepared.output.received_source_key
    atlas.last_reconcile_phases={}
    atlas._copy_parameters(prepared.groups.values()[0]);atlas._copy_output_source(entry)
    check(atlas.last_reconcile_phases.get("material_full_copies",0)==0,"First sample after private targets finish preparation copies only changed operands")
    check(entry.received_material.get_shader_parameter("condition_alpha")==.4,"Prepared output receives current first-sample opacity")
    compare_destinations("First private delivery")
    reset();bind(1,"NE")
    check(admitted(),"Ordinary frame/facing updates retain the prepared geometry")
    compare_destinations("Adjacent frame")
    reset();bind(1,"NE",.4);check(admitted(),"Current condition values retain structural admission");compare_destinations("Current condition")
    reset();bind(1);bind(2);bind(0,"NE")
    check(admitted(),"Continuous ordinary frames retain private receiving copies")
    compare_destinations("Several ordinary frames")
    reset();bind(1,"SW",.4);bind(2,"SW",1.0);bind(0)
    check(admitted(),"Opacity change-and-return retains prepared geometry");compare_destinations("Opacity change and return")
    reset();host.source_depth=false;bind(1);host.source_depth=true;bind(2);bind(0)
    check(not admitted(),"Optical change-and-return invalidates structural admission")
    reset();entry.actor_layer.effect={"palette":{"colors":[0xffffff,0x4488aa]}};bind(1)
    entry.actor_layer.effect={};bind(2);bind(0)
    check(not admitted(),"Palette family change-and-return invalidates structural admission")
    reset();bind(1);SourceMaterial.acknowledge(entry);bind(2)
    check(admitted(),"A destination that missed an acknowledged sample remains structurally valid");compare_destinations("Missed delivery")
    reset();host.source_depth=false;bind(1);check(not admitted(),"Changed optical flags reject old material proof");host.source_depth=true
    reset();entry.placement.scale_x=-1.0;bind(1);check(not admitted(),"Changed optical scale rejects old geometry proof")
    reset();entry.node.mesh.size=Vector2(2,1);check(not admitted(),"Changed quad dimensions reject old material proof")
    reset();host.camera.rotate_y(.5);check(not admitted(),"Changed view basis rejects old receiving copies");host.camera.basis=Basis.IDENTITY
    reset();prepared.output.received_material.shader=Atlas.Output;check(not admitted(),"Changed output shader rejects old destination identity")
    reset();prepared.groups.values()[0].material.shader=Atlas.ShadowReceiver;check(not admitted(),"Changed receiving shader rejects old destination identity")
    reset();entry.material=entry.material.duplicate();SourceMaterial.initialize(entry);check(not admitted(),"Replacement source material cannot inherit old copied owners")
    reset();host.textures[PATH]=ImageTexture.create_from_image(image);bind();check(not admitted(),"Replacement resident texture rejects old source snapshot")
    reset();atlas.set_light_cap(.8);check(not admitted(),"Changed light mode rejects prepared copy");atlas.set_light_cap(1.0)
    reset();prepared.screen_size+=Vector2.ONE;check(not admitted(),"Changed receiving viewport size rejects prepared copy")
    reset()
    var private_output=weakref(prepared.output.received_material)
    var private_group=weakref(prepared.groups.values()[0].material)
    atlas.prepared_source_bindings.clear()
    var candidate=Preparation.new();host.add_child(candidate);entry.node.reparent(candidate,false)
    candidate.entries=[entry]
    var actor:Dictionary={"entries":[entry]}
    candidate.native_actors={"actor":actor};candidate.result={"actors":{"actor":actor}}
    candidate.atlas_shells={entry.node.get_instance_id():prepared}
    prepared={};entry={};actor={}
    var held:Array=candidate.release_handles()
    var retirement:Dictionary=candidate.atlas_retirement
    check(not retirement.payloads.is_empty(),"Cancelled private material stores transfer to existing bounded retirement")
    candidate.free();held.clear()
    check(private_output.get_ref()!=null,"Private materials remain owned until their retirement slice")
    var retired:bool=false
    for step in 200:
        if Atlas.Delta.retire_candidate_step(retirement).done:retired=true;break
    check(retired,"Bounded material retirement drains without another owner")
    await process_frame;await process_frame
    check(private_output.get_ref()==null and private_group.get_ref()==null,"Cancelled owner releases private output/group materials without a Dictionary cycle")
    reset();bind(1,"SW",.4);compare_destinations("Independent recipients")
    var peer:Dictionary=entry.duplicate()
    peer.received_material=ShaderMaterial.new();peer.received_material.shader=Atlas.CappedModular
    peer.erase("received_source_key");atlas._copy_output_source(peer)
    SourceMaterial.acknowledge(entry);bind(2,"NE",.8)
    atlas._copy_parameters(prepared.groups.values()[0]);atlas._copy_output_source(entry)
    check(peer.received_material.get_shader_parameter("condition_alpha")==.4,"A peer material retains its independently sampled opacity")
    check(entry.received_material.get_shader_parameter("condition_alpha")==.8,"The current output receives the new opacity")
    var newcomer:Dictionary=entry.duplicate();newcomer.erase("received_source_key")
    newcomer.received_material=ShaderMaterial.new();newcomer.received_material.shader=Atlas.CappedModular
    SourceMaterial.acknowledge(entry);atlas._copy_output_source(newcomer)
    check(newcomer.received_material.get_shader_parameter("condition_alpha")==.8,"New destination copies current values after changes were acknowledged")
    peer={};newcomer={}
    flame_checks()
    await water_clock_ownership()
    atlas.prepared_source_bindings.clear();prepared={};entry.node.free();entry={}
    atlas.close();host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Actual shader uniform parity and material-only source admission; no framebuffer/performance claim."}
    FileAccess.open("res://.runtime/actor-material-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_MATERIAL_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
