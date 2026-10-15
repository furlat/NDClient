extends RefCounted
## Exact selected donor preparation. Runtime owns a new scene and private
## mutable resources; original adapter sample() still owns its source clock.
const Packet=preload("res://presentation/native_source_variant.gd")
const Resources=preload("res://assets/native_effects/sandbox/projectiles/factory/core/resource_graph.gd")
const Programs=preload("res://assets/native_effects/sandbox/projectiles/factory/core/native_source_resources.gd")
const MaterialRules=preload("res://assets/native_effects/sandbox/projectiles/factory/materials/donor_material_rules.gd")
const DIRECTORY="res://.derived/native-source-variants"
const PREFIX="res://assets/native_effects/sandbox/projectiles/factory/components/"
const SELECTED_BINBUN="res://assets/native_effects/sandbox/projectiles/library/selected/project_authored_source_binbun_spell_recovery_ee747028/assets/"
const BINBUN="res://assets/native_effects/sandbox/projectiles/library/binbun/"
# Their preparation may author/recolour an image; that has already completed
# before packing. Runtime updates only private uniforms, nodes and emitters.
const CONSTANT_NOISE_ADAPTERS=["clocked_source","selected_projectile","fireball_layers","ice_projectile","approved_ice_burst","control_status","support","bane","blessing","healing"]
# These donor controllers assign private shader uniforms/particles/lights. They
# never edit the sampled NoiseTexture2D, FastNoiseLite or Gradient contents.
const CONSTANT_NOISE_CONTROLLERS=[
    SELECTED_BINBUN+"BinbunVFX/shared/script/vfx_controller.gd",
    SELECTED_BINBUN+"BinbunVFX/shared/script/vfx_light.gd",
    SELECTED_BINBUN+"BinbunVFX_Vol2/ElementalMagicFX/script/VFXElementalProjectileBB.gd",
    SELECTED_BINBUN+"BinbunVFX_Vol2/shared/script/VFXOmniLightBB.gd",
    BINBUN+"pack_binbun_magicprojectilesvfx/assets/BinbunVFX/shared/script/vfx_controller.gd",
    BINBUN+"pack_binbun_magicprojectilesvfx/assets/BinbunVFX/shared/script/vfx_light.gd",
    BINBUN+"pack_binbun_godotmagicorbsvfx/assets/BinbunVFX/shared/script/vfx_controller.gd",
    BINBUN+"pack_binbun_godotmagicorbsvfx/assets/BinbunVFX/shared/script/vfx_light.gd",
    BINBUN+"pack_binbun_statusfxfull/assets/BinbunVFX_Vol2/StatusFX/script/VFXStatusBB.gd",
]
# These adapters finish their resource edits before packing. Their runtime
# samplers only advance private players/emitters and write material uniforms.
const CONSTANT_DATA_ADAPTERS=["clocked_source","chill_hand","protection","fireball_layers"]
const CONSTANT_DATA_CONTROLLERS=[
    "res://assets/native_effects/sandbox/projectiles/library/lelu/pack_lelu_godot_patreons_community_pack_3_d/VFX/scripts/plane_cutter.gd",
    "res://assets/native_effects/sandbox/projectiles/library/lelu/pack_lelu_godot_vertical_beam_effects_premium/VFX/Misc/laser_activator.gd"]
const BASE_ADAPTERS=["clocked_source","selected_projectile","ice_projectile","chill_hand","fireball_layers","approved_ice_burst","approved_aoe_whole","bane","control_status","protection","protection_contact","blessing","healing","support","cantrip_donor","sacred_beam","compact_flame","silk_area"]
# These are source-declared references, not arbitrary script serialization.
const EXTRA_NODES={"cantrip_donor":["source"],"sacred_beam":["source"],"compact_flame":["root","asset"]}
const EXTRA_NODE_ARRAYS={"protection":["particle_banks"],"protection_contact":["particle_banks"],"silk_area":["parts","animations"]}
const EXTRA_MATERIALS={"compact_flame":["mats"],"silk_area":["mats","deploy_mats","net_mats"]}
static var verified:Dictionary={}
static var metadata_profile:Dictionary={}
static var _generation:int=0
static var _metadata_state:Dictionary={"manifest":{},"read":false,"stamps":{}}
static var _metadata_job:Dictionary={}
static var _queued:Dictionary={}
static var _inflight:Dictionary={}

static func supported(spec:Dictionary)->bool:
    var script:String=spec.get("script","")
    if script in [PREFIX+"native_scene_effect.gd",PREFIX+"projectile_formation.gd"]:return true
    return script.begins_with(PREFIX+"recipient/") and script.get_file().get_basename() in BASE_ADAPTERS

static func component_spec(spec:Dictionary,clip:Dictionary)->Dictionary:
    var overrides:Array=[];var writes:Array=[]
    var prefix:String=str(spec.id)+"/"
    for value in clip.get("property_overrides",[]):
        if not str(value.node).begins_with(prefix) and str(value.node)!=str(spec.id):continue
        var local:Dictionary=value.duplicate(true)
        local.node=str(value.node).trim_prefix(prefix) if str(value.node)!=str(spec.id) else "."
        if str(value.property).begins_with("material_override:"):overrides.append(local)
        if ":" in str(value.property):writes.append({"node":local.node,"property":value.property})
    if overrides.is_empty() and writes.is_empty():return spec
    var result:Dictionary=spec.duplicate(false)
    if not overrides.is_empty():result.prepared_material_overrides=overrides
    if not writes.is_empty():result.prepared_resource_writes=writes
    return result

static func canonical(value:Variant)->Variant:
    if value is Dictionary:
        var plain:Dictionary={};var result:Dictionary={}
        for key in value:plain[str(key)]=value[key]
        var keys:Array=plain.keys();keys.sort()
        for key in keys:result[key]=canonical(plain[key])
        return result
    if value is Array:return value.map(canonical)
    if value is StringName:return str(value)
    return value

static func specification(spec:Dictionary)->Dictionary:
    var value:Dictionary=spec.duplicate(true)
    value.erase("id") # The name is supplied by the occurrence; it does not author resources.
    return canonical({"version":2,"component":value})

static func key(spec:Dictionary)->String:
    return var_to_bytes(specification(spec)).hex_encode().sha256_text()

static func path_for(spec:Dictionary)->String:return DIRECTORY.path_join(key(spec)+".res")

static func reset()->void:
    # An old metadata-only job can finish without blocking a new UI revision.
    # Its private state/results are discarded when polled after completion.
    _generation+=1;verified.clear();metadata_profile.clear();_queued.clear();_inflight.clear()
    _metadata_state={"manifest":{},"read":false,"stamps":{}}

static func _poll_metadata()->void:
    if _metadata_job.is_empty():return
    if not WorkerThreadPool.is_task_completed(_metadata_job.task):return
    WorkerThreadPool.wait_for_task_completion(_metadata_job.task)
    if _metadata_job.generation==_generation:
        verified.merge(_metadata_job.results)
        for identity in _metadata_job.requests:_inflight.erase(identity)
        metadata_profile=_metadata_job.profile
    _metadata_job={}

static func _start_metadata()->void:
    if not _metadata_job.is_empty() or _queued.is_empty():return
    _metadata_job={"generation":_generation,"state":_metadata_state,"requests":_queued,"results":{},"profile":{},"task":-1}
    for identity in _queued:_inflight[identity]=true
    _queued={}
    _metadata_job.task=WorkerThreadPool.add_task(_verify_metadata.bind(_metadata_job),false,"Prepared native source metadata")

static func _verify_metadata(job:Dictionary)->void:
    # Only passive paths/stat data live here: no ResourceLoader, Shader, mesh,
    # Node or native renderer calls can overlap the source compiler admission.
    var started:int=Time.get_ticks_usec();var stat_count:int=0
    var state:Dictionary=job.state
    if not state.read:
        state.read=true
        if FileAccess.file_exists(DIRECTORY.path_join("index.json")):
            var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join("index.json")))
            if data is Dictionary:state.manifest=data
    for identity in job.requests:
        var request:Dictionary=job.requests[identity]
        var result:Dictionary={"supported":true,"pending":false,"path":request.path,"error":""}
        if not state.manifest.has(identity) or not FileAccess.file_exists(request.path):
            result.error="Prepared native source missing; run tools/bake_native_source_variants.gd: "+request.label
        else:
            for dependency in state.manifest[identity].dependencies:
                if not state.stamps.has(dependency):state.stamps[dependency]=stamp(dependency);stat_count+=1
                if state.stamps[dependency]!=state.manifest[identity].dependencies[dependency]:
                    result.error="Prepared native source stale: "+dependency
                    break
        job.results[identity]=result
    job.profile={"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"new_dependency_stats":stat_count,"cached_dependency_stats":state.stamps.size(),"variants":job.requests.size()}

static func admission(spec:Dictionary)->Dictionary:
    if not supported(spec):return {"supported":false,"pending":false,"path":"","error":""}
    _poll_metadata()
    var identity:String=key(spec)
    if verified.has(identity):return verified[identity]
    if not _queued.has(identity) and not _inflight.has(identity):
        _queued[identity]={"path":path_for(spec),"label":spec.script+" / "+str(spec.get("id",""))}
    _start_metadata()
    return {"supported":true,"pending":true,"path":path_for(spec),"error":""}

static func instantiate(spec:Dictionary,admitted_packet:Resource=null)->Dictionary:
    var admitted:Dictionary=admission(spec)
    if admitted.pending:return {"component":null,"clocks":[],"error":"Prepared native source metadata admission is pending"}
    if not admitted.error.is_empty():return {"component":null,"clocks":[],"error":admitted.error}
    if admitted_packet==null and not ResourceLoader.has_cached(admitted.path):return {"component":null,"clocks":[],"error":"Prepared native source was not admitted before construction: "+admitted.path}
    var packet:Resource=admitted_packet if admitted_packet!=null else load(admitted.path)
    # CACHE_MODE_IGNORE_DEEP deliberately owns a fresh script Resource too.
    if packet==null or packet.get_script().resource_path!=Packet.resource_path or packet.format_version!=2 or packet.specification!=specification(spec):
        return {"component":null,"clocks":[],"error":"Invalid prepared native source: "+admitted.path}
    var component:Node3D=packet.scene.instantiate()
    # Restore before _ready, with addresses resolved inside this new instance.
    for state in packet.adapters:
        var node:Node=component.get_node(state.path)
        node.parameters=state.parameters.duplicate(true)
        match state.kind:
            "base":
                node.settings=state.settings.duplicate(true);node.side=state.side
                node.subject=component.get_node(state.subject);node.prepared=true
                node.materials.assign(_resolve_materials(component,state.materials))
                node.seeds=state.seeds.duplicate(true)
                for field in state.get("nodes",{}):node.set(field,component.get_node(state.nodes[field]))
                for field in state.get("node_arrays",{}):
                    var values:Array=[]
                    for address in state.node_arrays[field]:values.append(component.get_node(address))
                    # Preserve a source's typed Array declaration.
                    var target:Array=node.get(field);target.assign(values)
                for field in state.get("material_arrays",{}):
                    var target:Array=node.get(field);target.assign(_resolve_materials(component,state.material_arrays[field]))
                if state.has("active"):node.active=state.active
            "scene":
                node.donor=component.get_node(state.donor);node.material_rules_prepared=true
            "formation":node.donor=component.get_node(state.donor)
    return {"component":component,"clocks":_resolve_materials(component,packet.clocks),"materials":_resolve_materials(component,packet.materials),"material_overrides":packet.material_overrides,"after_ready":packet.after_ready,"error":""}

static func _resolve_materials(root:Node,addresses:Array)->Array:
    var result:Array=[]
    for address in addresses:
        var value:Variant=root.get_node(address.node)
        for step in address.steps:
            if step.has("surface"):value=value.surface_get_material(int(step.surface))
            elif step.has("index"):value=value[step.index]
            else:value=value.get(step.property)
        result.append(value)
    return result

static func stamp(path:String)->Dictionary:
    var file=FileAccess.open(path,FileAccess.READ)
    return {"modified":float(FileAccess.get_modified_time(path)),"bytes":float(file.get_length()) if file!=null else -1.0}

static func dependencies(spec:Dictionary)->Dictionary:
    var result:Dictionary={}
    _dependency_values(spec,result)
    for path in ["res://presentation/native_source_variant.gd","res://presentation/native_source_variants.gd","res://tools/bake_native_source_variants.gd"]:_dependency(path,result)
    return canonical(result)

static func _dependency_values(value:Variant,result:Dictionary)->void:
    if value is Dictionary:
        for item in value.values():_dependency_values(item,result)
    elif value is Array:
        for item in value:_dependency_values(item,result)
    elif value is String and value.begins_with("res://"):_dependency(value,result)

static func _dependency(path:String,result:Dictionary)->void:
    if result.has(path) or not FileAccess.file_exists(path):return
    result[path]=stamp(path)
    if FileAccess.file_exists(path+".import"):result[path+".import"]=stamp(path+".import")
    if path.get_extension() in ["tscn","tres","res","scn","gd"]:
        for dependency in ResourceLoader.get_dependencies(path):_dependency(str(dependency).split("::")[-1],result)
    if path.get_extension() in ["gd","gdshader","gdshaderinc"]:
        var expression=RegEx.new();expression.compile('(?:res://[^"\\s]+|#include\\s+"[^"\\n]+")')
        for found in expression.search_all(FileAccess.get_file_as_string(path)):
            var child:String=found.get_string()
            if child.begins_with("#include"):
                child=child.get_slice('"',1)
                if not child.begins_with("res://"):child=path.get_base_dir().path_join(child)
            if child.get_extension() in ["gd","gdshader","gdshaderinc","tscn","scn","tres","res","png","jpg","webp","exr","svg"]:_dependency(child,result)

## Offline-only entry. The caller supplies the original detached constructor
## result after original material/animation assignments, then gives it its first
## tree entry before this resource preparation, matching Factory.make's order.
static func bake(component:Node3D,spec:Dictionary)->Dictionary:
    var packet=Packet.new();packet.specification=specification(spec)
    var states:Array[Dictionary]=[]
    var error:String=_prepare_adapter(component,component,states)
    if not error.is_empty():return {"packet":null,"error":error}
    # The admitted Base.sample(0) only starts its selected AnimationPlayers;
    # it never advances their tracks or reads these native material features.
    # Prepare the exact authored fields before packing to avoid regenerating a
    # temporary StandardMaterial program on every live source construction.
    # ShaderMaterial controls and all node/geometry setters retain their
    # original runtime order. Runtime still restores any field changed at0.
    for value in spec.get("prepared_material_overrides",[]):
        var target:Node=component.get_node(value.node)
        if not target.get("material_override") is BaseMaterial3D:continue
        target.set_indexed(NodePath(value.property),value.value)
        packet.material_overrides.append(value)
    # Source-owned Node metadata must resolve inside the new occurrence.
    for state in states:
        if state.kind=="base" and state.settings.get("spell","")=="thunderwave":
            var subject:Node=component.get_node(state.subject)
            for field in ["crest","echo"]:
                if subject.has_meta(field):
                    packet.after_ready.append({"kind":"node_meta","node":state.subject,"field":field,"target":str(component.get_path_to(subject.get_meta(field)))})
                    subject.remove_meta(field)
        if state.kind=="base" and state.settings.get("kind","")=="sanctuary":
            var mark:Node3D=component.get_node(state.subject).get_node("SanctuaryMark")
            packet.after_ready.append({"kind":"native_scale","node":str(component.get_path_to(mark)),"scale":mark.scale})
    # Final global TIME translation happens once too; addresses rebind clocks
    # to the private materials of each instantiation.
    var clocks:Array=[];var seen:Dictionary={}
    for node in _nodes(component):
        for property in node.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                var value:Variant=node.get(property.name)
                if value is Resource:_clock(value,seen,clocks)
    # Offline duplication ensures marking local-to-scene never mutates donor
    # assets. Immutable shaders/textures are shared; mutable aliases stay exact.
    Resources.isolate_node(component,{"share_shader_programs":true})
    # Native Trail export setters can overwrite the already-adapted draw
    # parameters while PackedScene instantiates. Save those exact private
    # resource references as scene metadata, then restore after tree entry.
    for node in _nodes(component):
        if node.get_script()!=null and node.get_script().resource_path.ends_with("/GPUTrail3D.gd"):
            var uniforms:Dictionary={}
            for field in ["tex","color_ramp","curve"]:
                uniforms[field]=node.draw_pass_1.material.get_shader_parameter(field)
            node.set_meta("native_prepared_draw_parameters",uniforms)
            packet.after_ready.append({"kind":"trail_properties","node":str(component.get_path_to(node)),"length":int(node.length),"seconds":float(node.length_seconds)})
            # _ready also initializes the native billboard frame. Its private
            # transform drives RenderingServer directly and is not serialized
            # by PackedScene. Preserve that exact initialization in component
            # coordinates rather than replaying setters on prepared resources.
            packet.after_ready.append({"kind":"trail_runtime","node":str(component.get_path_to(node)),"billboard_transform":component.global_transform.affine_inverse()*node.get("_billboard_transform"),"old_position":component.to_local(node.get("_old_pos")),"uv_offset":node.get("_uv_offset")})
    var addresses:Dictionary={};seen.clear()
    for node in _nodes(component):
        for property in node.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                var value:Variant=node.get(property.name)
                _resource_addresses(value,{"node":str(component.get_path_to(node)),"steps":[{"property":str(property.name)}]},addresses,seen)
    _share_constant_noise(component,spec,seen)
    _share_constant_data(component,spec,seen)
    # The offline isolation above replaces references. Resolve original adapter
    # material paths before cloning instead, then use the same paths in packet.
    for state in states:
        if state.kind=="scene":
            var node:Node3D=component.get_node(state.path)
            var offset:Array=state.parameters.get("local_offset",[0,0,0])
            node.position-=node.basis*Vector3(offset[0],offset[1],offset[2])
    packet.adapters=states
    for material in addresses:
        packet.program_materials.append(material)
        packet.materials.append(addresses[material])
    packet.clocks.clear()
    for address in _clock_addresses(component):packet.clocks.append(address)
    component.scene_file_path=""
    for child in _nodes(component).slice(1):
        if child.get_script()!=null and child.get_script().resource_path.ends_with("/plane_cutter.gd") and child.target_mesh!=null:
            packet.after_ready.append({"node":str(component.get_path_to(child)),"property":"target_mesh","target":str(component.get_path_to(child.target_mesh)),"cutplane":child.target_mesh.get_active_material(0).get_shader_parameter("cutplane")})
            child.target_mesh=null
        if child.get_script()!=null and child.get_script().resource_path.ends_with("/GPUTrail3D.gd"):
            child.set_meta("native_prepared_properties",true)
            # Exported property setters run again during PackedScene loading.
            # Restore the exact prepared bitfield after native tree entry;
            # the original source sampler still owns all subsequent updates.
            packet.after_ready.append({"kind":"trail_flags","node":str(component.get_path_to(child)),"flags":int(child.get("_flags"))})
        child.scene_file_path=""
        child.owner=component
    packet.scene=PackedScene.new()
    var status:Error=packet.scene.pack(component)
    if status!=OK:return {"packet":null,"error":"Packing native source: "+str(status)}
    packet.dependencies=dependencies(spec)
    return {"packet":packet,"error":""}

static func _prepare_adapter(root:Node3D,node:Node3D,states:Array[Dictionary])->String:
    var script:String=node.get_script().resource_path
    var state:Dictionary={"path":str(root.get_path_to(node)),"parameters":node.parameters.duplicate(true)}
    if script==PREFIX+"projectile_formation.gd":
        state.kind="formation";state.donor=str(root.get_path_to(node.donor));states.append(state)
        return _prepare_adapter(root,node.donor,states)
    if script==PREFIX+"native_scene_effect.gd":
        MaterialRules.apply(node.donor,node.parameters.get("material_rules",[]))
        state.kind="scene";state.donor=str(root.get_path_to(node.donor));states.append(state)
        return ""
    var adapter:String=script.get_file().get_basename()
    if adapter not in BASE_ADAPTERS:return "Unqualified prepared source adapter: "+script
    node.prepare_subject()
    state.merge({"kind":"base","settings":node.settings.duplicate(true),"side":node.side,"subject":str(root.get_path_to(node.subject)),"seeds":node.seeds.duplicate(true),"nodes":{},"node_arrays":{},"material_arrays":{}})
    var addresses:Dictionary={};var seen:Dictionary={}
    for child in _nodes(root):
        for property in child.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                _resource_addresses(child.get(property.name),{"node":str(root.get_path_to(child)),"steps":[{"property":str(property.name)}]},addresses,seen,false)
    state.materials=_addresses(node.materials,addresses)
    if state.materials.size()!=node.materials.size():return "Unreachable native material in "+script
    for field in EXTRA_NODES.get(adapter,[]):state.nodes[field]=str(root.get_path_to(node.get(field)))
    for field in EXTRA_NODE_ARRAYS.get(adapter,[]):
        var paths:Array=[]
        for value in node.get(field):paths.append(str(root.get_path_to(value)))
        state.node_arrays[field]=paths
    for field in EXTRA_MATERIALS.get(adapter,[]):
        state.material_arrays[field]=_addresses(node.get(field),addresses)
        if state.material_arrays[field].size()!=node.get(field).size():return "Unreachable native material array "+field+" in "+script
    if adapter=="silk_area":state.active=node.active
    states.append(state)
    return ""

static func _addresses(materials:Array,addresses:Dictionary)->Array:
    var result:Array=[]
    for material in materials:
        if addresses.has(material):result.append(addresses[material])
    return result

static func _constant_noise_adapter(path:String)->bool:
    return path==PREFIX+"projectile_formation.gd" or (path.begins_with(PREFIX+"recipient/") and path.get_file().get_basename() in CONSTANT_NOISE_ADAPTERS)

static func _share_constant_noise(component:Node3D,spec:Dictionary,resources:Dictionary)->void:
    # These prepared resources contain the original edits/material rules. Their
    # audited runtime never changes procedural image contents. A fresh texture does
    # its first image generation synchronously on the next main-thread update.
    # Share only proven constant procedural images, not all procedural resources.
    if not _constant_noise_adapter(spec.script):return
    for node in _nodes(component):
        if node!=component and node.get_script()!=null:
            var path:String=node.get_script().resource_path
            if not _constant_noise_adapter(path) and path not in CONSTANT_NOISE_CONTROLLERS:return
    var writes:Dictionary=_resource_write_targets(component,spec)
    if not writes.safe:return
    var animated:Dictionary=writes.resources
    for resource in resources:
        if not resource is NoiseTexture2D or not resource.noise is FastNoiseLite:continue
        if animated.has(resource) or animated.has(resource.noise) or animated.has(resource.color_ramp):continue
        resource.resource_local_to_scene=false

static func _share_constant_data(component:Node3D,spec:Dictionary,resources:Dictionary)->void:
    var script:String=spec.script
    if not script.begins_with(PREFIX+"recipient/") or script.get_file().get_basename() not in CONSTANT_DATA_ADAPTERS:return
    for node in _nodes(component):
        if node!=component and node.get_script()!=null:
            var path:String=node.get_script().resource_path
            if path not in CONSTANT_DATA_CONTROLLERS:return
    var writes:Dictionary=_resource_write_targets(component,spec)
    if not writes.safe:return
    var animated:Dictionary=writes.resources
    for resource in resources:
        if animated.has(resource):continue
        var constant:bool=resource is Animation or resource is Curve or resource is Gradient
        if resource is CurveTexture:constant=not animated.has(resource.curve)
        elif resource is CurveXYZTexture:constant=not animated.has(resource.curve_x) and not animated.has(resource.curve_y) and not animated.has(resource.curve_z)
        elif resource is GradientTexture1D or resource is GradientTexture2D:constant=not animated.has(resource.gradient)
        elif resource is ArrayMesh:
            # Surface materials are private mutable owners. Only geometry with
            # no embedded materials can be shared without moving those owners.
            constant=true
            for surface in resource.get_surface_count():
                if resource.surface_get_material(surface)!=null:constant=false;break
        if constant:resource.resource_local_to_scene=false

# Sharing a parent resource also shares its children. Only proven property
# writes are accepted; arbitrary method calls or unresolved indexed paths leave
# the complete source private. This applies to procedural textures too.
static func _resource_write_targets(component:Node3D,spec:Dictionary)->Dictionary:
    var result:Dictionary={"safe":false,"resources":{}}
    for node in _nodes(component):
        if not node is AnimationPlayer:continue
        var animation_root:Node=node.get_node_or_null(node.root_node)
        if animation_root==null:return result
        for name in node.get_animation_list():
            var animation:Animation=node.get_animation(name)
            for track in animation.get_track_count():
                if not animation.track_is_enabled(track):continue
                if animation.track_get_type(track)==Animation.TYPE_METHOD:return result
                # A shared Animation must never assign a shared mutable key
                # resource into two otherwise private scene instances.
                for key_index in animation.track_get_key_count(track):
                    if _contains_resource(animation.track_get_key_value(track,key_index)):return result
                var path:NodePath=animation.track_get_path(track)
                var target:Node=animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
                var fields:Array=[]
                for index in path.get_subname_count():fields.append(path.get_subname(index))
                if not _record_resource_path(target,fields,result.resources):return result
    for write in spec.get("prepared_resource_writes",[]):
        if not _record_resource_path(component.get_node_or_null(write.node),Array(str(write.property).split(":")),result.resources):return result
    result.safe=true
    return result

static func _record_resource_path(target:Variant,fields:Array,writes:Dictionary)->bool:
    if target==null:return false
    for index in fields.size():
        if not target is Object:return false
        target=target.get(fields[index])
        if target is Resource:writes[target]=true
        # Scalar leaf properties are valid; intermediate values must be
        # traversable objects. Container paths are deliberately not inferred.
        if index+1<fields.size() and not target is Object:return false
    return true

static func _contains_resource(value:Variant)->bool:
    if value is Resource:return true
    if value is Array or value is Dictionary:
        for item in (value if value is Array else value.values()):
            if _contains_resource(item):return true
    return false

static func _resource_addresses(value:Variant,address:Dictionary,result:Dictionary,seen:Dictionary,mark:bool=true)->void:
    if value is Resource:
        if seen.has(value):return
        seen[value]=true
        if value is Shader or value is CompressedTexture2D or value is ImageTexture or value is Script:return
        if mark:
            value.resource_local_to_scene=true
            if value is ShaderMaterial and value.shader!=null and value.shader.resource_path.is_empty():
                # Identical final programs are external shared native resources,
                # not one embedded Shader identity per baked phase.
                var program_path:String=DIRECTORY.path_join("programs/"+value.shader.code.sha256_text()+".gdshader")
                DirAccess.make_dir_recursive_absolute(program_path.get_base_dir())
                if not FileAccess.file_exists(program_path):FileAccess.open(program_path,FileAccess.WRITE).store_string(value.shader.code)
                for uniform in value.shader.get_shader_uniform_list():
                    if value.get_shader_parameter(uniform.name)==null:
                        var texture:Texture2D=value.shader.get_default_texture_parameter(uniform.name)
                        if texture!=null:value.set_shader_parameter(uniform.name,texture)
                value.shader=load(program_path)
        if value is Material:result[value]=address
        if value is Mesh:
            for i in value.get_surface_count():
                var next:Dictionary=address.duplicate(true);next.steps.append({"surface":i})
                _resource_addresses(value.surface_get_material(i),next,result,seen,mark)
        for property in value.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                var child:Variant=value.get(property.name)
                if child is Resource or child is Array or child is Dictionary:
                    var next:Dictionary=address.duplicate(true);next.steps.append({"property":str(property.name)})
                    _resource_addresses(child,next,result,seen,mark)
    elif value is Array or value is Dictionary:
        for i in (range(value.size()) if value is Array else value.keys()):
            var next:Dictionary=address.duplicate(true);next.steps.append({"index":i})
            _resource_addresses(value[i],next,result,seen,mark)

static func _clock(resource:Resource,seen:Dictionary,clocks:Array)->void:
    if seen.has(resource):return
    seen[resource]=true
    if resource is Shader or resource is Texture2D:return
    if resource is ShaderMaterial and Programs.apply_clock(resource,"sandbox_source_seconds",false):clocks.append(resource)
    if resource is Mesh:
        for i in resource.get_surface_count():
            var material:Material=resource.surface_get_material(i)
            if material!=null:_clock(material,seen,clocks)
    for property in resource.get_property_list():
        if int(property.usage)&PROPERTY_USAGE_STORAGE:
            var child:Variant=resource.get(property.name)
            if child is Resource:_clock(child,seen,clocks)

static func _clock_addresses(root:Node3D)->Array:
    var addresses:Dictionary={};var seen:Dictionary={};var result:Array=[]
    for node in _nodes(root):
        for property in node.get_property_list():
            if int(property.usage)&PROPERTY_USAGE_STORAGE:
                _resource_addresses(node.get(property.name),{"node":str(root.get_path_to(node)),"steps":[{"property":str(property.name)}]},addresses,seen,false)
    for material in addresses:
        if material is ShaderMaterial and material.shader.code.contains("uniform float sandbox_source_seconds"):
            result.append(addresses[material])
    return result

static func after_attach(component:Node3D,bindings:Array)->void:
    for binding in bindings:
        var node:Node=component.get_node(binding.node)
        if binding.get("kind","")=="trail_flags":
            node.set("_flags",int(binding.flags))
            node.draw_pass_1.material.set_shader_parameter("flags",int(binding.flags))
        elif binding.get("kind","")=="trail_properties":
            node.set_meta("native_prepared_restoring",true)
            node.length=int(binding.length);node.length_seconds=float(binding.seconds)
            node.remove_meta("native_prepared_restoring")
            for field in node.get_meta("native_prepared_draw_parameters"):
                node.draw_pass_1.material.set_shader_parameter(field,node.get_meta("native_prepared_draw_parameters")[field])
        elif binding.get("kind","")=="trail_runtime":
            node.set("_billboard_transform",component.global_transform*binding.billboard_transform)
            node.set("_old_pos",component.to_global(binding.old_position))
            node.set("_uv_offset",binding.uv_offset)
        elif binding.get("kind","")=="node_meta":node.set_meta(binding.field,component.get_node(binding.target))
        elif binding.get("kind","")=="native_scale":node.scale=binding.scale
        else:
            node.set(binding.property,component.get_node(binding.target))
            # The setter updates the plane before the first source sample.
            # Preserve the original post-adapter material value until the
            # next native transform notification, as on original construction.
            node.target_mesh.get_active_material(0).set_shader_parameter("cutplane",binding.cutplane)

static func _nodes(root:Node)->Array:
    var result:Array=[root]
    # Engine-owned internal children (e.g. Skeleton's compatibility simulator)
    # must be recreated by their owner, never persisted as authored children.
    for child in root.get_children():result.append_array(_nodes(child))
    return result
