extends SceneTree
## Explicit authoring reload: changed same-path packets and external materials
## become new instances, while a displayed old instance remains untouched.
## Isolated resource fixtures never replace the production variant manifest.
const Factory=preload("res://presentation/native_factory_source.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
const Packet=preload("res://presentation/native_source_variant.gd")
var checks:int=0
var failures:Array=[]
var directory:String
var spec:Dictionary
var clip:Dictionary
var packet_path:String
var material_path:String
var dependency:String
var created:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)

func write_material(color:Color,revision:int)->void:
    FileAccess.open(material_path,FileAccess.WRITE).store_string(
        '[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nresource_local_to_scene = true\nalbedo_color = Color(%s, %s, %s, 1)\n' % [color.r,color.g,color.b]
        +"# "+"rebaked ".repeat(revision)+"\n")
    FileAccess.open(dependency,FileAccess.WRITE).store_string("Native authoring fixture revision "+str(revision)+"\n".repeat(revision))

func write_packet(size:float)->Dictionary:
    var material:Material=ResourceLoader.load(material_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    var owner=Node3D.new();owner.name="Fixture"
    var mesh=MeshInstance3D.new();mesh.name="Core";mesh.mesh=BoxMesh.new()
    mesh.mesh.size=Vector3.ONE*size;mesh.mesh.resource_local_to_scene=true
    mesh.material_override=material;owner.add_child(mesh);mesh.owner=owner
    var packed=PackedScene.new();check(packed.pack(owner)==OK,"Fixture source packs")
    var packet=Packet.new();packet.specification=Variants.specification(spec);packet.scene=packed
    packet.dependencies={dependency:Variants.stamp(dependency),material_path:Variants.stamp(material_path)}
    packet.program_materials.assign([material])
    var manifest:Dictionary={Variants.key(spec):{"dependencies":packet.dependencies.duplicate(true)}}
    check(ResourceSaver.save(packet,packet_path)==OK,"Same-path packet saves")
    owner.free()
    return manifest

func inspect_metadata(manifest:Dictionary)->Dictionary:
    var identity:String=Variants.key(spec)
    var job={"state":{"manifest":manifest,"read":true,"stamps":{}},
        "requests":{identity:{"path":packet_path,"label":"isolated reload fixture"}},"results":{},"profile":{}}
    Variants._verify_metadata(job)
    # Feed the actual verifier result into the same admission cache. Only the
    # manifest location is isolated; packet loading/validation is production.
    Variants.verified[identity]=job.results[identity]
    return job.results[identity]

func prepared(cache:Dictionary)->bool:
    var deadline:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        var result:Dictionary=Factory.prepare([clip],cache)
        if not result.errors.is_empty():failures.append_array(result.errors);return false
        if result.ready:return true
        await process_frame
    check(false,"Fresh native packet finishes serialized admission: "+str({"loading":Admission.loading_path,"settling":Admission.settling,"material_worker":not Admission._material_job.is_empty()}))
    return false

func instance(packet:Resource)->Node3D:
    var result:Dictionary=Variants.instantiate(spec,packet)
    check(result.error.is_empty(),"Admitted packet instantiates without cache fallback")
    if not result.error.is_empty():return null
    created.append(result.component)
    root.add_child(result.component)
    return result.component

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(160,120)
    Engine.max_fps=120
    directory="res://.runtime/native-source-reload-"+str(OS.get_process_id())
    DirAccess.make_dir_recursive_absolute(directory)
    material_path=directory.path_join("material.tres");dependency=directory.path_join("authoring.txt")
    spec={"id":"ReloadFixture","script":Variants.PREFIX+"native_scene_effect.gd","input":{"scene":directory.path_join("fixture.tscn")}}
    clip={"id":"reload-fixture","components":[spec]};packet_path=Variants.path_for(spec)
    check(not FileAccess.file_exists(packet_path),"Fixture owns a new packet path, never production artwork")
    if not failures.is_empty():quit(1);return
    write_material(Color.RED,1)
    var manifest:Dictionary=write_packet(1.0)
    check(inspect_metadata(manifest).error.is_empty(),"Initial actual dependency metadata admits")
    var cache:Dictionary={}
    if not await prepared(cache):await finish();return
    var first:Resource=Factory.admitted_packet(spec)
    var old:Node3D=instance(first)
    if old==null:await finish();return
    var old_core:MeshInstance3D=old.get_node("Core")
    check(old_core.mesh.size==Vector3.ONE and old_core.material_override.albedo_color==Color.RED,"Initial instance has exact old geometry/material")
    var load_count:int=Admission.loads_started
    check(await prepared(cache) and is_same(Factory.admitted_packet(spec),first),"Ordinary preparation retains the admitted source revision")
    check(Admission.loads_started==load_count,"Ordinary preparation does not reload native packets")
    write_material(Color.BLUE,2)
    Factory.invalidate_authoring()
    check(not inspect_metadata(manifest).error.is_empty(),"Changed dependency with old bake is rejected after explicit reload")
    var rejected:Dictionary=Factory.prepare([clip],cache)
    check(not rejected.ready and not rejected.errors.is_empty() and Factory.admitted_packet(spec)==null,"Stale authoring cannot publish the old cached packet as ready")
    check(old_core.material_override.albedo_color==Color.RED and old_core.mesh.size==Vector3.ONE,"Rejected replacement leaves the displayed instance unchanged")
    manifest=write_packet(2.0)
    check(is_same(ResourceLoader.load(packet_path),first),"Fixture reproduces the stale ResourceLoader same-path cache")
    Factory.invalidate_authoring()
    check(inspect_metadata(manifest).error.is_empty(),"New bake matches exact changed source metadata")
    if not await prepared(cache):await finish();return
    var second:Resource=Factory.admitted_packet(spec)
    check(not is_same(first,second),"Explicit reload owns a fresh packet Resource")
    var revised:Node3D=instance(second)
    if revised==null:await finish();return
    var new_core:MeshInstance3D=revised.get_node("Core")
    check(new_core.mesh.size==Vector3.ONE*2 and new_core.material_override.albedo_color==Color.BLUE,"New instance receives changed packet geometry and external material")
    check(old_core.mesh.size==Vector3.ONE and old_core.material_override.albedo_color==Color.RED,"Fresh deep loading never mutates the live old instance")
    check(not is_same(new_core.material_override,old_core.material_override),"Old/new mutable material ownership stays independent")
    var peer:Node3D=instance(second)
    if peer!=null:
        new_core.material_override.albedo_color=Color.GREEN
        check(peer.get_node("Core").material_override.albedo_color==Color.BLUE,"New revision instances retain private materials")
        check(old_core.material_override.albedo_color==Color.RED,"New instance edits cannot reach retained old material")
    var pending_path:String=directory.path_join("pending.tres")
    FileAccess.open(pending_path,FileAccess.WRITE).store_string('[gd_resource type="BoxMesh" format=3]\n[resource]\nsize = Vector3(3, 3, 3)\n')
    await process_frame
    var pending_cache:Dictionary={"native_source_revision":Factory.source_revision}
    Admission.prepare([pending_path],pending_cache,true)
    check(Admission.loading_path==pending_path,"A real old-revision threaded load is in flight")
    Factory.invalidate_authoring();Factory.prepare([],pending_cache)
    var deadline:int=Time.get_ticks_msec()+10000
    while not Admission.can_mutate() and Time.get_ticks_msec()<deadline:await process_frame
    check(Admission.can_mutate() and not pending_cache.has(pending_path),"An old in-flight load cannot publish into the revised owner cache")
    await finish()

func finish()->void:
    for node in created:node.free()
    created=[]
    # These paths belong to this process's isolated fixture only.
    DirAccess.remove_absolute(packet_path)
    for name in ["material.tres","authoring.txt","pending.tres"]:DirAccess.remove_absolute(directory.path_join(name))
    DirAccess.remove_absolute(directory)
    await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Same-path packet and external-material reload, stale metadata rejection, old-instance ownership, private new instances and in-flight old-owner isolation. Does not claim native framebuffer or interactive Studio timing."}
    FileAccess.open("res://.runtime/native-source-reload-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SOURCE_RELOAD ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
