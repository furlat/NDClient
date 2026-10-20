extends RefCounted
## Actual renderer operands for declared Factory setters. Each occurrence keeps
## its clocks/material leases; source optical samples share by source pose.
const Effects=preload("res://presentation/effect_package.gd")
const Surface=preload("res://presentation/entity_surface.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Weapons=preload("res://presentation/native_weapon_inputs.gd")
const ConditionPose=preload("res://presentation/condition_pose.gd")
const Appearances=preload("res://presentation/condition_appearance.gd")
const SpatialInputs=preload("res://presentation/spatial_inputs.gd")
const CreationInputs=preload("res://presentation/creation_inputs.gd")
const PropagationInputs=preload("res://presentation/propagation_inputs.gd")
const Characters=preload("res://presentation/characters.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const ActorResources=preload("res://presentation/actor_resources.gd")
const Tracks=preload("res://presentation/tracks.gd")
var appearances:RefCounted=Appearances.new()
var surfaces:RefCounted=Surface.new()

static func recipient(component:Dictionary)->String:
    if str(component.get("native_cue",{}).get("attachment","")).begins_with("caster"):
        return str(component.get("actor_uuid",""))
    var target:Variant=component.get("target_uuid")
    return "" if target==null else str(target)

func prepare(world:Node,components:Array,priority:bool=true,received_groups:Array=[])->void:
    var interests:Dictionary={}
    for component in components:
        if Effects.choice(component.get("native_clip",{})).kind=="recorded":continue
        for request in geometry_interests(component,world):
            if not request.actor.is_empty():interests[[request.actor,request.slots]]=request
    for request in interests.values():surfaces.prepare(world,[request.actor],request.slots,priority)
    if not received_groups.is_empty():surfaces.prepare_received_tracks(world,received_groups,interests.values())

static func geometry_request(component:Dictionary,channel:String)->Dictionary:
    var cue:Dictionary=component.get("native_cue",{})
    var authored:Dictionary=cue.get(channel,cue.get("entity_geometry",{}) if channel!="source_geometry" else {})
    var actor:String=str(component.get("actor_uuid","")) if channel=="source_geometry" else recipient(component)
    var selector:String=str(authored.get("actor",""))
    var reason:String=""
    if not selector.is_empty():
        actor=actor_uuid(component,selector)
        if actor.is_empty():reason="authored_actor_binding_not_bound:"+selector
    return {"actor":actor,"slots":Array(authored.get("slots",Surface.BODY_SLOTS)),"reason":reason}

static func actor_uuid(component:Dictionary,selector:String)->String:
    if selector=="caster":return str(component.get("actor_uuid",""))
    if selector in ["target","recipient"]:
        var target:Variant=component.get("target_uuid");return "" if target==null else str(target)
    return str(component.get("native_actor_uuids",{}).get(selector,""))

static func geometry_interests(component:Dictionary,world:Node=null)->Array:
    var requested:Array=component.get("native_clip",{}).get("inputs",[])
    var result:Array=[]
    if "weapon_binding" in requested and world!=null:
        var weapon:Dictionary=Weapons.resolve(world,component)
        result.append({"actor":weapon.actor,"slots":weapon.slots,"reason":weapon.reason})
    else:
        for channel in ["entity_geometry","recipient_geometry"]:
            if channel in requested:result.append(geometry_request(component,channel))
    for channel in ["source_geometry"]:
        if channel in requested:result.append(geometry_request(component,channel))
    if "targets" in requested or "live_endpoints" in requested:
        for endpoint in component.get("native_cue",{}).get("live_endpoints",[]):
            if endpoint.has("surface_slots"):
                result.append({"actor":actor_uuid(component,str(endpoint.get("actor",""))),"slots":Array(endpoint.surface_slots),"reason":""})
    return result

func geometry_sample(world:Node,component:Dictionary,channel:String,weapon:Dictionary={})->Dictionary:
    if "weapon_binding" in component.get("native_clip",{}).get("inputs",[]) and channel!="source_geometry":
        if weapon.is_empty():weapon=Weapons.resolve(world,component)
        if not weapon.ready:return {"actor":weapon.actor,"actor_uuid":weapon.actor,"ready":false,"reason":weapon.reason,"points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
        return Weapons.surface(surfaces.sample(world,weapon.actor,weapon.slots),weapon)
    var request:Dictionary=geometry_request(component,channel)
    if not request.reason.is_empty():return {"actor":"","actor_uuid":"","ready":false,"reason":request.reason,"points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
    var result:Dictionary=surfaces.sample(world,request.actor,request.slots)
    result.geometry_slots=request.slots
    return result

static func actor_layers(world:Node,actor:String)->Dictionary:
    var visual:Dictionary=world.visual_actors.get(actor,{})
    var layers:Array=[];var revision:Array=[]
    for entry in visual.get("entries",[]):
        if entry.role=="shadow":continue
        var effect:Dictionary=entry.actor_layer.get("effect",{})
        if not effect.is_empty() and effect.get("kind")!="condition_appearance":continue
        if not entry.node.is_visible_in_tree():continue
        layers.append({"slot":entry.actor_layer.slot,"node":entry.node,"material":entry.material})
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_binding_revision",0)])
    return {"actor_uuid":actor,"layers":layers,"revision":revision}

## Actual published layers in their painter order. GPU textures stay on the
## GPU; revisions describe the current pose/material, never a guessed history.
static func actor_context(world:Node,actor:String,receiver_depth:Texture2D)->Dictionary:
    var visual:Dictionary=world.visual_actors.get(actor,{})
    if not Sockets.displayed(visual):return {"ready":false,"reason":"actor_not_displayed"}
    if not world.camera is Camera3D or receiver_depth==null:return {"ready":false,"reason":"actor_context_receiver_not_prepared"}
    var pose:Dictionary=visual.get("sampled_pose",{})
    if pose.is_empty():return {"ready":false,"reason":"actor_pose_not_sampled"}
    var layers:Array=[];var revision:Array=[]
    for entry in visual.entries:
        if entry.role=="shadow" or not entry.node.is_visible_in_tree():continue
        var effect:Dictionary=entry.actor_layer.get("effect",{})
        if not effect.is_empty() and effect.get("kind")!="condition_appearance":continue
        layers.append({"slot":entry.actor_layer.slot,"node":entry.node,"material":entry.material,
            "received_material":entry.material,"pivot":entry.pivot,"ground_pixels":entry.get("geometry_ground_pixels",19.0)})
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0),entry.get("source_binding_revision",0)])
    if layers.is_empty():return {"ready":false,"reason":"actor_layers_not_displayed"}
    return {"ready":true,"packet":{"actor_uuid":actor,"camera":world.camera,"receiver_depth":receiver_depth,
        "depth_encoding":"rgb24_reversed_z","capture_size":Vector2i(world.get_viewport().get_visible_rect().size),
        "origin":Sockets.Placement.contact(visual.row),"layers":layers,"pose_key":pose.key,
        "material_revision":revision}}

static func current_pose_history(handle:Dictionary)->bool:
    var settings:Dictionary=handle.occurrence.parameters.get("actor_history",{})
    return settings.get("mirror",false) and not settings.get("capture_departure",false) and not settings.get("specifications",[]).any(func(row):return float(row.get("delay",0.0))>0.0)

static func departure_history(handle:Dictionary)->bool:
    if not handle.has("occurrence"):return false # Recorded handles have no live constructor/context.
    var settings:Dictionary=handle.occurrence.parameters.get("actor_history",{})
    return settings.get("capture_departure",false) and not settings.get("mirror",false)

static func departure_capture(component:Dictionary)->Dictionary:
    var capture:Dictionary=component.get("logical_pose",{})
    if capture.get("condition_uuid")!=component.get("condition_uuid") or capture.get("actor_uuid")!=recipient(component):return {}
    return capture if capture.has("departure") else {}

static func _departure_layer(layer:Dictionary,capture:Dictionary,rig:Dictionary,quarter:int,cycle:Array)->Dictionary:
    var clip:String=capture.clip;var frame:int=int(capture.frame);var direction:String=capture.world_facing
    var id:String=str(layer.get("effect",{}).get("component_id",""))
    for effect in capture.departure.layer_samples:
        if effect.id!=id:continue
        clip=effect.get("clip",clip)
        var track:Dictionary=effect.source_track
        var pose:Dictionary=Tracks.samples([track],float(track.start_ms)+float(effect.age_ms)).get(capture.actor_uuid,{})
        frame=clampi(int(float(pose.get("source_seconds",0))*float(rig.clips[clip].fps)),0,int(rig.clips[clip].frames)-1)
        var from:Variant=track.get("from_position");var to:Variant=track.get("target_position",track.get("to_position"))
        if from!=null and to!=null and from!=to:direction=Sockets.Placement.facing(Vector2(to[0]-from[0],to[1]-from[1]),cycle)
    return {"clip":clip,"frame":frame,"facing":cycle[posmod(cycle.find(direction)+quarter*2,8)]}

static func _departure_metadata(capture:Dictionary,cache:Dictionary,config:Dictionary,resources:Dictionary,output:Dictionary)->void:
    var departure:Dictionary=capture.departure;var row:Dictionary=departure.row
    var rig:Dictionary=Characters.rigs(cache)[capture.rig]
    var prepared:Dictionary=Characters.prepare_layers(row,rig,cache)
    if not prepared.ok:output.merge({"complete":true,"reason":prepared.error.message});return
    var layers:Dictionary={};var paths:Dictionary={}
    for layer in prepared.value:
        if layer.slot=="shadow" or layer.slot in capture.hidden_slots:continue
        var selected:Dictionary=_departure_layer(layer,capture,rig,config.quarter,config.cycle)
        if not layer.paths.has(selected.clip):output.merge({"complete":true,"reason":"departure_layer_clip_not_authored:"+str(layer.slot)});return
        var path:String=layer.paths[selected.clip]
        var binding:Dictionary=Construction.prepare_binding(rig,layer,path,cache,config.depth,config.normals,config.profile,
            128.0/float(departure.tile_width)*float(row.scale),float(row.get("scale_x",1.0)))
        layers[layers.size()]={"layer":layer,"binding":binding,"frame":selected.frame}
        paths[path]=true
        for companion in binding.geometry.textures.values():paths[companion]=true
        var noise:Variant=layer.get("effect",{}).get("palette",{}).get("noiseSheet")
        if noise!=null and resources.has(noise):paths[resources[noise]]=true
    var material:Dictionary=departure.material
    for key in [material.get("ramp",{}).get("texture"),material.get("flash",{}).get("material",{}).get("palette",{}).get("noiseSheet")]:
        if resources.has(key):paths[resources[key]]=true
    var input:Dictionary={"row":row,"rig":rig,"layers":layers,"material":material,"quarter":config.quarter,
        "facing":config.cycle[posmod(config.cycle.find(capture.world_facing)+int(config.quarter)*2,8)],
        "scale":128.0/float(departure.tile_width)*float(row.scale),"light_parameters":{"authored_base_light":0.0}}
    output.merge({"complete":true,"reason":"","inputs":{capture.actor_uuid:input},"paths":paths})

## Finite capture preparation belongs to its existing occurrence. Workers only
## see immutable pre-cut data, admitted metadata and explicit texture snapshots.
func prepare_departure(world:Node,handle:Dictionary,component:Dictionary)->Dictionary:
    var capture:Dictionary=departure_capture(component)
    if capture.is_empty():return {"ready":false,"pending":false,"reason":"condition_original_departure_not_observed"}
    if not str(capture.departure.reason).is_empty():return {"ready":false,"pending":false,"reason":capture.departure.reason}
    var key:Array=[capture,world.source_depth,world.source_normals,world.character_light_profile]
    if handle.get("departure_key",[])!=key:
        release_departure(handle)
        handle.departure_key=key;handle.departure_capture=capture
        var config:Dictionary={"quarter":world.quarter,"cycle":world.rig_config.FACING_CYCLE,"depth":world.source_depth,"normals":world.source_normals,"profile":world.character_light_profile}
        var output:Dictionary={}
        handle.departure_metadata=output
        handle.departure_task=WorkerThreadPool.add_task(_departure_metadata.bind(capture,Construction.source_cache(world.catalog_cache),config,world.resources.duplicate(),output),false,"Prepare original departure sources")
    if int(handle.get("departure_task",-1))>=0:
        if not WorkerThreadPool.is_task_completed(handle.departure_task):return {"ready":false,"pending":true,"reason":"departure_source_metadata_preparing"}
        WorkerThreadPool.wait_for_task_completion(handle.departure_task);handle.departure_task=-1
    var metadata:Dictionary=handle.departure_metadata
    if not str(metadata.get("reason","")).is_empty():return {"ready":false,"pending":false,"reason":metadata.reason}
    handle.departure_paths=metadata.paths
    if not metadata.paths.keys().all(func(path):return world.textures.has(path)):
        return {"ready":false,"pending":true,"reason":"departure_source_textures_preparing"}
    if not handle.has("departure_output"):
        var textures:Dictionary={}
        for path in metadata.paths:textures[path]=world.textures[path]
        var output:Dictionary={};handle.departure_output=output
        handle.departure_resource_task=WorkerThreadPool.add_task(ActorResources.build_private.bind(metadata.inputs,textures,world.resources.duplicate(),Construction.source_parameter_names(),output),false,"Prepare private departure layers")
    if int(handle.get("departure_resource_task",-1))>=0:
        if not WorkerThreadPool.is_task_completed(handle.departure_resource_task):return {"ready":false,"pending":true,"reason":"departure_layers_preparing"}
        WorkerThreadPool.wait_for_task_completion(handle.departure_resource_task);handle.departure_resource_task=-1
    if not handle.has("departure_entries"):
        var parent:=Node3D.new();parent.name="OriginalDepartureLayers";parent.hide();handle.occurrence.add_child(parent)
        handle.departure_parent=parent;var entries:Array=[]
        for packet in handle.departure_output.rows[capture.actor_uuid].values():
            var entry:Dictionary=packet.entry;entry.node.layers=0;parent.add_child(entry.node);entries.append(entry)
        handle.departure_entries=entries
    return {"ready":true,"pending":false,"reason":""}

func departure_context(world:Node,handle:Dictionary,component:Dictionary,receiver_depth:Texture2D)->Dictionary:
    var capture:Dictionary=departure_capture(component)
    if capture.is_empty():return {"ready":false,"reason":"condition_original_departure_not_observed"}
    if not handle.has("departure_entries"):return {"ready":false,"reason":"departure_layers_not_prepared"}
    if not world.camera is Camera3D or receiver_depth==null:return {"ready":false,"reason":"actor_context_receiver_not_prepared"}
    var row:Dictionary=capture.departure.row;var rig:Dictionary=Characters.rigs(world.catalog_cache)[capture.rig]
    var layers:Array=[];var revision:Array=[]
    for entry in handle.departure_entries:
        var selected:Dictionary=_departure_layer(entry.actor_layer,capture,rig,world.quarter,world.rig_config.FACING_CYCLE)
        var binding:Dictionary=entry.prepared_source_binding
        Construction.bind_source_values(entry,rig,binding.path,selected.frame,selected.facing,binding.sheet,binding.sheet_size,
            world.textures,world.resources,entry.bound_condition_parameters)
        entry.node.global_transform=Construction.layer_transform(world.camera.basis,row,rig,capture.departure.motion,entry.role,
            capture.clip,world.rig_config.FACING_CYCLE[posmod(world.rig_config.FACING_CYCLE.find(capture.world_facing)+world.quarter*2,8)],int(capture.frame),float(capture.departure.tile_width),float(capture.departure.material.body_scale.factor))
        layers.append({"slot":entry.actor_layer.slot,"node":entry.node,"material":entry.material,"received_material":entry.material,
            "pivot":entry.pivot,"ground_pixels":entry.get("geometry_ground_pixels",19.0)})
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0),entry.get("source_binding_revision",0)])
    if layers.is_empty():return {"ready":false,"reason":"departure_layers_not_prepared"}
    var logical:Array=[capture.actor_uuid,capture.condition_uuid,capture.admitted_at_ms]
    var origin:Vector3=Sockets.Placement.contact(row)
    return {"ready":true,"packet":{"actor_uuid":capture.actor_uuid,"camera":world.camera,"receiver_depth":receiver_depth,
        "depth_encoding":"rgb24_reversed_z","capture_size":Vector2i(world.get_viewport().get_visible_rect().size),
        "origin":origin,"layers":[],"departure_layers":layers,"departure_revision":logical,
        "departure_origin":origin,"departure_capture_revision":[logical,world.quarter,world.camera.global_basis,revision],
        "pose_key":[capture.clip,capture.frame,capture.world_facing,world.quarter],"material_revision":revision}}

static func release_departure(handle:Dictionary)->void:
    for field in ["departure_task","departure_resource_task"]:
        if int(handle.get(field,-1))>=0:WorkerThreadPool.wait_for_task_completion(handle[field])
    if handle.has("departure_parent") and is_instance_valid(handle.departure_parent):handle.departure_parent.free()
    elif handle.has("departure_output"):
        for packets in handle.departure_output.get("rows",{}).values():
            for packet in packets.values():
                if is_instance_valid(packet.entry.node):packet.entry.node.free()
    for field in ["departure_key","departure_capture","departure_metadata","departure_task","departure_paths","departure_output","departure_resource_task","departure_parent","departure_entries"]:handle.erase(field)

static func endpoints(component:Dictionary,points:Dictionary,surface:Dictionary)->Array:
    # Legacy targets forwards to set_live_endpoints (source, recipient).
    # Prepared conditions discover one surface in the same array. Never put a
    # second actor's body on the source endpoint of a recipient occurrence.
    var target:Dictionary={"actor_uuid":recipient(component),"role":"recipient","point":points.to}
    if not surface.is_empty():target.surface=surface
    return [{"actor_uuid":str(component.get("actor_uuid","")),"role":"source","point":points.hand},target]

func endpoint_packet(world:Node,handle:Dictionary,component:Dictionary,points:Dictionary,surface:Dictionary)->Dictionary:
    var cue:Dictionary=component.get("native_cue",{})
    if cue.has("review_trajectory"):return {"rows":[],"reason":"review_trajectory_not_bound"}
    if not cue.has("live_endpoints"):
        if component.has("lifecycle_phases"):
            var live:Dictionary=handle.occurrence.parameters.get("live_pose",{})
            if live.get("mode")=="gaze":return {"rows":[],"reason":"authored_endpoint_aim_not_bound"}
            var point:Vector3=points.hand if str(cue.get("attachment","")).begins_with("caster_hand") else points.to
            var row:Dictionary={"actor_uuid":recipient(component),"point":point}
            if not surface.is_empty():row.surface=surface
            return {"rows":[row],"reason":""}
        # The legacy package adapter explicitly forwards targets to its
        # two source/recipient endpoints. It has no authored tuple to interpret.
        return {"rows":endpoints(component,points,surface),"reason":""}
    var result:Array=[]
    for authored in cue.live_endpoints:
        if authored.has("point") or authored.has("review_trajectory"):return {"rows":[],"reason":"review_endpoint_position_not_bound"}
        if authored.has("cue_point"):
            if authored.cue_point!="source":return {"rows":[],"reason":"authored_cue_point_not_bound:"+str(authored.cue_point)}
            result.append({"point":points.from,"cue_point":"source"});continue
        var selector:String=str(authored.get("actor",""));var actor:String=actor_uuid(component,selector)
        if actor.is_empty():return {"rows":[],"reason":"authored_actor_binding_not_bound:"+selector}
        var visual:Dictionary=world.visual_actors.get(actor,{})
        if not Sockets.displayed(visual):return {"rows":[],"reason":"native_spell_endpoint_actor_not_displayed"}
        var socket:String=str(authored.get("socket",""));var resolved:Dictionary={"ready":true}
        var pose_socket:String=str(authored.get("pose_socket",socket))
        if socket=="ground":resolved.point=Sockets.Placement.contact(visual.row)
        elif selector=="caster" and cue.has("source_socket") and socket==cue.source_socket:resolved.point=points.from
        elif selector=="caster" and socket in ["cast_hand","hand"]:resolved.point=points.hand
        else:resolved=Sockets.pose_point(world,visual.row,pose_socket,authored.get("pose_socket_by_clip",{}))
        if not resolved.ready:return {"rows":[],"reason":resolved.reason}
        var endpoint:Dictionary={"actor":actor if cue.get("endpoint_actor_uuids",false) else selector,"actor_uuid":actor,"socket":socket,"point":resolved.point}
        if authored.get("view_basis",false):endpoint.view_basis=world.camera.global_basis
        if authored.has("surface_slots"):
            var slots:Array=Array(authored.surface_slots)
            var supplied:Dictionary=surface if surface.get("actor")==actor and surface.get("geometry_slots",[])==slots else receiver_surface(surfaces.sample(world,actor,slots),handle.root.global_transform)
            if not supplied.ready:return {"rows":[],"reason":supplied.reason}
            endpoint.surface=supplied
        elif not surface.is_empty() and surface.get("actor")==actor:endpoint.surface=surface
        result.append(endpoint)
    return {"rows":result,"reason":""}

static func receiver_surface(surface:Dictionary,transform:Transform3D)->Dictionary:
    # The source pose is translation-independent. The receiving kernel turns
    # its world points into this occurrence's local frame; only that relative
    # frame belongs in the upload key. Co-moving actor/occurrence stays hot.
    var inverse:Transform3D=transform.affine_inverse()
    var result:Dictionary=surface.duplicate(false)
    result.gpu_geometry_key=[surface.get("actor",surface.get("actor_uuid","")),surface.get("ready",false),surface.get("reason",""),
        surface.get("gpu_geometry_key",[]),inverse.basis,inverse*surface.get("origin",Vector3.ZERO)]
    return result

static func geometry_input(handle:Dictionary,name:String,surface:Dictionary)->void:
    if not handle.has("geometry_input_keys"):handle.geometry_input_keys={}
    if handle.geometry_input_keys.get(name,[])==surface.gpu_geometry_key:return
    Effects.set_input(handle,name,surface)
    handle.geometry_input_keys[name]=surface.gpu_geometry_key

static func cells(positions:Array,elevation:float)->Array:
    var result:Array=[]
    for position in positions:
        result.append({"centre":Vector3(position[0],elevation/5.0*Sockets.Placement.HEIGHT_UNIT,position[1]),"half_size":Vector2(.5,.5)})
    return result

static func cell_membership(handle:Dictionary,component:Dictionary,endpoints:Array=[])->String:
    # Prepared condition masks consume world cell rectangles and return bool.
    # Legacy native adapters forward local pairs to a void setter. Null is an
    # inapplicable optional native operand, never an invented target cell.
    if not handle.has("cell_input_prepared"):
        var selected:Dictionary=Effects.choice(handle.clip)
        handle.cell_input_prepared=not selected.approaches.is_empty() and selected.approaches[0].get("condition_prepared",false)
    var prepared:bool=handle.cell_input_prepared
    var disclosed:Variant=component.get("resolved_area_positions")
    var elevation:float=float(component.get("to_elevation_feet",0.0))
    var frame:Transform3D=Transform3D.IDENTITY
    if not prepared and disclosed!=null:
        # Delivered native surface planes place their local topology at the
        # first authored endpoint; endpoint-free native owners use their root.
        frame=Transform3D(Basis.IDENTITY,endpoints[0].point) if not endpoints.is_empty() else handle.root.global_transform
    var key:Array=[disclosed,elevation,frame,component.get("spatial_owner",false)]
    if key==handle.get("cell_input_key",[]):return handle.get("cell_input_reason","")
    handle.cell_input_key=key;handle.cell_input_reason=""
    var positions:Array=[] if disclosed==null else disclosed
    if prepared:
        var accepted:bool=handle.occurrence.call(handle.clip.input_setters.admitted_cells,cells(positions,elevation))
        if disclosed==null:handle.cell_input_reason="admitted_cells_not_disclosed"
        elif not positions.is_empty() and not accepted:handle.cell_input_reason="admitted_cells_not_accepted"
    elif disclosed==null:
        if component.get("spatial_owner",false):handle.cell_input_reason="admitted_cells_not_disclosed"
    elif positions.is_empty():
        # Native source setters assert nonempty topology. Hiding this exact
        # owner clears its output without forwarding an invalid empty packet.
        handle.cell_input_reason="native_admitted_cells_empty"
    else:
        var axes:Array=[Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
        var grid:bool=frame.basis.y.is_equal_approx(Vector3.UP) and axes.any(func(axis):return frame.basis.x.is_equal_approx(axis)) \
            and axes.any(func(axis):return frame.basis.z.is_equal_approx(axis)) and is_zero_approx(frame.basis.x.dot(frame.basis.z))
        if not grid:handle.cell_input_reason="native_admitted_cells_frame_not_grid_aligned"
        else:
            var inverse:Transform3D=frame.affine_inverse()
            var local:Array=[]
            for position in positions:
                var point:Vector3=inverse*Vector3(position[0],elevation/5.0*Sockets.Placement.HEIGHT_UNIT,position[1])
                local.append([point.x,point.z])
            # The declared native adapter returns void; null is not rejection.
            Effects.set_input(handle,"admitted_cells",local)
    return handle.cell_input_reason

func sync(world:Node,handle:Dictionary,component:Dictionary,points:Dictionary,receiver_depth:Texture2D=null)->Dictionary:
    var requested:Array=handle.clip.get("inputs",[])
    var supplied:Array=["root_path","binding_owners"]
    if component.has("lifecycle_phases"):supplied.append("owner_state")
    var unavailable:Dictionary={}
    var not_applicable:Dictionary={}
    # Offline-qualified client choices remain distinct from Factory-required
    # operands actually supplied. No synthetic empty density field is sent.
    for name in component.get("native_cue",{}).get("input_policies",{}):
        var policy:Dictionary=component.native_cue.input_policies[name]
        if policy.mode=="not_applicable":not_applicable[name]=policy.reason
    var actor:String=recipient(component)
    var surface:Dictionary={}
    var cell_endpoints:Array=[]
    var weapon:Dictionary={}
    var weapon_gaps:Array=[]
    var weapon_surface:Dictionary={}
    var source_contact_seconds:float=-1.0
    if "actor_context" in requested:
        if not current_pose_history(handle) and not departure_history(handle):unavailable.actor_context="authentic_actor_history_not_bound"
        else:
            var context:Dictionary=departure_context(world,handle,component,receiver_depth) if departure_history(handle) else actor_context(world,actor,receiver_depth)
            if context.ready:
                # The camera/depth texture are live references; source sampling
                # consumes exact current transforms even if source pixels match.
                var accepted:bool=handle.occurrence.call(handle.clip.input_setters.actor_context,context.packet)
                if accepted:handle.actor_context_bound=true;supplied.append("actor_context")
                else:unavailable.actor_context="actor_context_not_accepted"
            else:unavailable.actor_context=context.reason
    if "history_state" in requested and departure_history(handle):
        not_applicable.history_state="non_mirror_departure_does_not_consume_duplicate_count"
    elif "history_state" in requested:
        var state:Variant=component.get("condition",{}).get("state",component.get("native_preparation_inputs",{}).get("history_state"))
        if state is Dictionary and state.get("duplicate_count")!=null:
            var packet:Dictionary={"duplicate_count":state.duplicate_count}
            if packet!=handle.get("history_state_input",{}):
                Effects.set_input(handle,"history_state",packet);handle.history_state_input=packet
            supplied.append("history_state")
        else:unavailable.history_state="duplicate_count_not_disclosed"
    if "created_item_binding" in requested:
        unavailable.created_item_binding="wielded_native_bodies_not_supported"
    if "surface_presence" in requested:
        var packet:Dictionary=SpatialInputs.presence(component,world.timeline.state)
        if packet.ready:
            if not handle.has("surface_presence_input") or handle.surface_presence_input!=packet.value:
                Effects.set_input(handle,"surface_presence",packet.value);handle.surface_presence_input=packet.value
            supplied.append("surface_presence")
        else:unavailable.surface_presence=packet.reason
    if component.get("native_item",false) and "owner_state" in requested:
        var age:float=maxf(0.0,float(world.timeline.display_ms)-float(component.start_ms))/1000.0
        Effects.set_input(handle,"owner_state",{"phase":"sustain","phase_age_seconds":age,"owner_age_seconds":age})
        supplied.append("owner_state")
    if "owner_visibility" in requested:
        var visibility:float=float(component.get("alpha",1.0)) if Sockets.displayed(world.visual_actors.get(actor,{})) else 0.0
        if visibility!=float(handle.get("owner_visibility_input",-1.0)):
            Effects.set_input(handle,"owner_visibility",visibility);handle.owner_visibility_input=visibility
        supplied.append("owner_visibility")
    if "weapon_binding" in requested:
        weapon=Weapons.resolve(world,component)
        var hand:Dictionary={"ready":false,"reason":weapon.reason}
        if weapon.ready:
            # Main/offhand pixels are distinct optical channels. An absent
            # offhand socket cannot borrow the main hand's authored position.
            hand=Sockets.pose_point(world,world.visual_actors[weapon.actor].row,"hand") if weapon.render_slot=="weapon" else {"ready":false,"reason":"weapon_offhand_socket_not_authored"}
        var packet:Dictionary=Weapons.packet(weapon,hand)
        weapon_gaps=packet.public_gaps
        if requested.any(func(name):return name in ["entity_geometry","recipient_geometry"]):
            weapon_surface=receiver_surface(geometry_sample(world,component,"entity_geometry",weapon),handle.root.global_transform)
        var selected:Dictionary=Effects.choice(handle.clip)
        var prepared:bool=not selected.approaches.is_empty() and selected.approaches[0].get("condition_prepared",false)
        var key:Dictionary=packet.binding.duplicate(false)
        if prepared and key.has("hand"):key.hand=handle.root.global_transform.affine_inverse()*key.hand
        var hand_key:Variant=key.get("hand");key.erase("hand")
        var previous_hand:Variant=handle.get("weapon_hand_key")
        # World translation and its inverse introduce float32 cancellation.
        # Compare only this relative operand approximately; never quantize the
        # actual hand supplied on a changed source pose/receiving frame.
        var same_hand:bool=hand_key.is_equal_approx(previous_hand) if prepared and hand_key!=null and previous_hand!=null else hand_key==previous_hand
        var delivery_key:Array=[key,weapon_surface.get("gpu_geometry_key",[])]
        if not same_hand or delivery_key!=handle.get("weapon_input_key",null):
            Effects.set_input(handle,"weapon_binding",packet.binding)
            handle.weapon_input_key=delivery_key
            handle.weapon_hand_key=hand_key
        var required_gaps:Array=[] if prepared else weapon_gaps
        if not packet.ready:unavailable.weapon_binding=packet.reason
        elif not required_gaps.is_empty():unavailable.weapon_binding="weapon_legacy_admission_not_bound:"+", ".join(required_gaps)
        else:supplied.append("weapon_binding")
    if requested.any(func(name):return name in ["entity_geometry","recipient_geometry"]):
        var channel:String="entity_geometry" if "entity_geometry" in requested else "recipient_geometry"
        surface=weapon_surface if "weapon_binding" in requested else receiver_surface(geometry_sample(world,component,channel),handle.root.global_transform)
        for name in ["entity_geometry","recipient_geometry"]:
            if name in requested:
                geometry_input(handle,name,surface);supplied.append(name)
                if not surface.ready:unavailable[name]=surface.reason
    if "source_geometry" in requested:
        var source:Dictionary=receiver_surface(geometry_sample(world,component,"source_geometry"),handle.root.global_transform)
        geometry_input(handle,"source_geometry",source);supplied.append("source_geometry")
        if not source.ready:unavailable.source_geometry=source.reason
    if "targets" in requested or "live_endpoints" in requested:
        # Both delivered adapters forward live_endpoints through targets. One
        # changed endpoint packet supplies both declared aliases, avoiding a
        # second source traversal and repeated body delivery on every sample.
        var packet:Dictionary=endpoint_packet(world,handle,component,points,surface)
        cell_endpoints=packet.rows
        var endpoint_key:Array=[packet.reason,packet.rows.map(func(row):return [row.get("actor_uuid",""),row.get("actor",""),row.get("socket",""),row.get("cue_point",""),row.point,row.get("view_basis"),row.get("surface",{}).get("gpu_geometry_key",[])])]
        if endpoint_key!=handle.get("endpoint_input_key",[]):
            Effects.set_input(handle,"live_endpoints" if "live_endpoints" in requested else "targets",packet.rows)
            handle.endpoint_input_key=endpoint_key
        for channel in ["targets","live_endpoints"]:
            if channel not in requested:continue
            if packet.reason.is_empty():supplied.append(channel)
            else:unavailable[channel]=packet.reason
        if component.has("native_propagation") and packet.reason.is_empty():
            source_contact_seconds=PropagationInputs.optical_contact(component,packet.rows,handle.root.global_transform)
    if "removed_cells" in requested:
        if not component.get("spatial_owner",false) or not component.has("spatial_observed_removals"):
            unavailable.removed_cells="spatial_retirement_observations_not_bound"
        else:
            # Empty means no observed permanent retirement. In particular,
            # changing subjective visibility never becomes a burn operation.
            var observations:Array=component.spatial_observed_removals
            if not handle.has("removed_cells_input") or handle.removed_cells_input!=observations:
                if observations.is_empty():
                    Effects.set_input(handle,"removed_cells",[],[maxf(0.0,float(component.age_ms))/1000.0])
                else:
                    for observation in observations:
                        Effects.set_input(handle,"removed_cells",observation.cells,[float(observation.source_seconds)])
                handle.removed_cells_input=observations
            supplied.append("removed_cells")
    if "admitted_cells" in requested:
        var reason:String=cell_membership(handle,component,cell_endpoints)
        if reason.is_empty():supplied.append("admitted_cells")
        else:unavailable.admitted_cells=reason
    if "delivery_timing" in requested:
        var timing:Vector2=Vector2(float(component.native_cue.launch),float(component.native_cue.contact)-float(component.native_cue.launch))
        if timing!=handle.get("delivery_input",Vector2(INF,INF)):
            handle.occurrence.call(handle.clip.input_setters.delivery_timing,timing.x,timing.y)
            handle.delivery_input=timing
        supplied.append("delivery_timing")
    if "pose_provider" in requested:
        if not handle.occurrence.parameters.get("actor_operation",{}).get("capture_pose",false):supplied.append("pose_provider")
        else:
            var identity:String=str(component.get("condition_uuid",component.get("condition",{}).get("condition_uuid","")))
            var owner:Dictionary=world.timeline.condition_owners.get(identity,{})
            var capture:Dictionary=owner.get("logical_pose",{})
            if capture.is_empty():unavailable.pose_provider="condition_original_pose_not_observed"
            elif capture.actor_uuid!=actor:unavailable.pose_provider="condition_capture_actor_mismatch"
            else:
                if not handle.has("pose_provider_binding"):
                    var binding:RefCounted=ConditionPose.Binding.new()
                    binding.actor_uuid=actor;binding.condition_uuid=identity;binding.capture=capture
                    handle.pose_provider_binding=binding
                var packet:Dictionary={"provider":handle.pose_provider_binding,"actor_uuid":actor,"owner_uuid":identity,"admitted":true}
                if handle.occurrence.call(handle.clip.input_setters.pose_provider,packet):
                    if not handle.get("pose_provider_admitted",false):handle.erase("actor_layer_input")
                    handle.pose_provider_admitted=true;supplied.append("pose_provider")
                else:unavailable.pose_provider="condition_pose_not_accepted"
    if "actor_layers" in requested:
        var packet:Dictionary=actor_layers(world,actor)
        var previous:Dictionary=handle.get("actor_layer_input",{})
        if packet.revision!=previous.get("revision",[]):
            var shaders:Array=packet.layers.map(func(layer):return layer.material.shader)
            Effects.set_input(handle,"actor_layers",packet)
            for index in packet.layers.size():
                if packet.layers[index].material.shader==shaders[index]:continue
                var entry:Dictionary=world.visual_actors[actor].entries.filter(func(value):return value.node==packet.layers[index].node)[0]
                SourceMaterial.structural_change(entry)
            handle.actor_layer_input=packet
        supplied.append("actor_layers")
        if packet.layers.is_empty():unavailable.actor_layers="actor_not_displayed"
    if "treatment_state" in requested:
        # No staged failures or strength are inferred from a condition's name.
        # An empty ordinary state means the resource's authored strength.
        var raw:Variant=component.get("condition",{}).get("state")
        var treatment:Dictionary=raw if raw is Dictionary else {}
        Effects.set_input(handle,"treatment_state",treatment);supplied.append("treatment_state")
    if "appearance_provider" in requested:
        var reason:String=appearances.bind(world,handle,component)
        if reason.is_empty():supplied.append("appearance_provider")
        else:unavailable.appearance_provider=reason
    if "owner_projection" in requested and component.get("persistent_owner",false) and component.has("condition"):
        if component.get("initial",false):unavailable.owner_projection="condition_application_not_observed"
        else:
            var projection={"actor_id":actor,"actor_uuid":actor,"owner_uuid":component.condition.condition_uuid,
                "behavior_id":component.condition.behavior_id,"admitted":true,"suppressed":false,"begin_seconds":0.0,
                "removed_seconds":-1.0 if is_inf(float(component.duration_ms)) else float(component.duration_ms)/1000.0}
            if projection!=handle.get("owner_projection_input",{}):
                Effects.set_input(handle,"owner_projection",projection);handle.owner_projection_input=projection
            supplied.append("owner_projection")
    var values:Dictionary=component.get("native_inputs",{})
    if "event_input" in requested and component.has("native_creation"):
        var created:Dictionary=CreationInputs.event_packet(component,world.timeline.state,cell_endpoints)
        if created.ready:
            values=values.duplicate(false);values.event_input=created.event
        else:unavailable.event_input=created.reason
    var packets:Dictionary=handle.get("native_input_packets",{})
    for name in values:
        if name=="weapon_binding":continue # Exact item provider owns the complete packet.
        if unavailable.has(name) or not_applicable.has(name):continue
        if name in requested:
            if not packets.has(name) or packets[name]!=values[name]:
                Effects.set_input(handle,name,values[name])
                packets[name]={name:values[name]}.duplicate(true)[name]
            supplied.append(name)
    handle.native_input_packets=packets
    # Selector values are copied only from actual disclosed ConditionState.
    # Other channels need a provider; their names alone do not supply evidence.
    var state:Dictionary=component.get("condition",{}).get("state",{}) if component.get("condition",{}).get("state") is Dictionary else {}
    for name in requested:
        if name in supplied or unavailable.has(name) or not_applicable.has(name):continue
        if state.get(name)!=null:Effects.set_input(handle,name,state[name]);supplied.append(name)
        else:unavailable[name]="provider_not_bound"
    var result:Dictionary={"supplied":supplied.filter(func(name):return name in requested),"unavailable":unavailable,
        "not_applicable":not_applicable,"weapon_public_gaps":weapon_gaps}
    if source_contact_seconds>=0.0:result.source_contact_seconds=source_contact_seconds
    return result

func clear()->void:
    surfaces.clear()
    appearances.clear()
