extends RefCounted
## Actual renderer operands for declared Factory setters. Each occurrence keeps
## its clocks/material leases; source optical samples share by source pose.
const Effects=preload("res://presentation/effect_package.gd")
const Surface=preload("res://presentation/entity_surface.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Weapons=preload("res://presentation/native_weapon_inputs.gd")
var surfaces:RefCounted=Surface.new()

static func recipient(component:Dictionary)->String:
    if str(component.get("native_cue",{}).get("attachment","")).begins_with("caster"):
        return str(component.get("actor_uuid",""))
    var target:Variant=component.get("target_uuid")
    return "" if target==null else str(target)

func prepare(world:Node,components:Array,priority:bool=true)->void:
    var interests:Dictionary={}
    for component in components:
        if Effects.choice(component.get("native_clip",{})).kind=="recorded":continue
        for request in geometry_interests(component,world):
            if not request.actor.is_empty():interests[[request.actor,request.slots]]=request
    for request in interests.values():surfaces.prepare(world,[request.actor],request.slots,priority)

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
        if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
        if not entry.node.is_visible_in_tree():continue
        layers.append({"slot":entry.actor_layer.slot,"node":entry.node,"material":entry.material})
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_binding_revision",0)])
    return {"actor_uuid":actor,"layers":layers,"revision":revision}

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
        if socket=="ground":resolved.point=Sockets.Placement.contact(visual.row)
        elif selector=="caster" and socket in ["cast_hand","hand"]:resolved.point=points.hand
        else:resolved=Sockets.pose_point(world,visual.row,socket)
        if not resolved.ready:return {"rows":[],"reason":resolved.reason}
        var endpoint:Dictionary={"actor":selector,"actor_uuid":actor,"socket":socket,"point":resolved.point}
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
            handle.occurrence.call(handle.clip.input_setters.admitted_cells,local)
    return handle.cell_input_reason

func sync(world:Node,handle:Dictionary,component:Dictionary,points:Dictionary)->Dictionary:
    var requested:Array=handle.clip.get("inputs",[])
    var supplied:Array=["root_path","binding_owners"]
    if component.has("lifecycle_phases"):supplied.append("owner_state")
    var unavailable:Dictionary={}
    var actor:String=recipient(component)
    var surface:Dictionary={}
    var cell_endpoints:Array=[]
    var weapon:Dictionary={}
    var weapon_gaps:Array=[]
    var weapon_surface:Dictionary={}
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
    if "pose_provider" in requested and not handle.occurrence.parameters.get("actor_operation",{}).get("capture_pose",false):
        supplied.append("pose_provider") # This operation does not request a capture.
    for name in component.get("native_inputs",{}):
        if name=="weapon_binding":continue # Exact item provider owns the complete packet.
        if name in requested:
            Effects.set_input(handle,name,component.native_inputs[name]);supplied.append(name)
    # Selector values are copied only from actual disclosed ConditionState.
    # Other channels need a provider; their names alone do not supply evidence.
    var state:Dictionary=component.get("condition",{}).get("state",{}) if component.get("condition",{}).get("state") is Dictionary else {}
    for name in requested:
        if name in supplied or unavailable.has(name):continue
        if state.has(name):Effects.set_input(handle,name,state[name]);supplied.append(name)
        else:unavailable[name]="provider_not_bound"
    return {"supplied":supplied.filter(func(name):return name in requested),"unavailable":unavailable,"weapon_public_gaps":weapon_gaps}

func clear()->void:
    surfaces.clear()
