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
const ActorBirthInputs=preload("res://presentation/actor_birth_inputs.gd")
const PropagationInputs=preload("res://presentation/propagation_inputs.gd")
const Characters=preload("res://presentation/characters.gd")
const Construction=preload("res://presentation/actor_construction.gd")
const ActorResources=preload("res://presentation/actor_resources.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const NativeHits=preload("res://presentation/native_spell_hits.gd")
const HistoryOwner=preload("res://assets/vfx/extensions/production-review-20261020/sources/6e2fd9339711629213f5/condition_actor_history.gd")
const HistoryClock=preload("res://assets/vfx/sources/c0017ad639184b208deb/occurrence_clock.gd")
var appearances:RefCounted=Appearances.new()
var surfaces:RefCounted=Surface.new()

## Retained constructors lexically preload their previous helper. Rebind only
## this delivered owner before its first packet, retaining its real clock slot.
static func rebind_history(handle:Dictionary)->void:
    if "actor_context" not in handle.clip.get("inputs",[]) or not is_instance_valid(handle.get("occurrence")):return
    var occurrence=handle.occurrence
    var settings:Dictionary=occurrence.parameters.get("actor_history",{})
    if settings.is_empty():return
    if occurrence.actor_history!=null:occurrence.actor_history.close()
    occurrence.actor_history=HistoryOwner.new()
    settings=settings.duplicate(false);settings.layer_mask=int(occurrence.parameters.get("layer_mask",2))
    occurrence.actor_history.configure(occurrence,settings,occurrence.slot)

static func capture_status(handle:Dictionary)->Dictionary:
    if "actor_context" not in handle.clip.get("inputs",[]) or not is_instance_valid(handle.get("occurrence")):return {"ready":true}
    var helper:RefCounted=handle.occurrence.actor_history
    if helper==null:return {"ready":false,"reason":"history_capture_owner_unavailable"}
    var status:Dictionary=helper.capture_status()
    var ready:bool=str(status.error).is_empty()
    for capture in status.captures:
        ready=ready and capture.ready and capture.requested_identity==capture.drawn_identity
    status.ready=ready
    status.pending=not ready and str(status.error).is_empty()
    status.reason=str(status.error) if not str(status.error).is_empty() else "history_capture_draw_pending" if not ready else ""
    return status

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
    var region:Dictionary=authored.get("region",{})
    if region.get("status")=="missing":reason="authentic_"+str(region.get("id","optical"))+"_region_not_authored"
    return {"actor":actor,"slots":Array(authored.get("slots",Surface.BODY_SLOTS)),"reason":reason,"region":region}

static func actor_uuid(component:Dictionary,selector:String)->String:
    if selector=="caster":return str(component.get("actor_uuid",""))
    if selector in ["target","recipient"]:
        var target:Variant=component.get("target_uuid");return "" if target==null else str(target)
    return str(component.get("native_actor_uuids",{}).get(selector,""))

## Only the actual prepared Measured receiver (including its Flame Blade
## subclass) admits exact item geometry without a grip. Legacy ownership and
## authored caster-hand endpoints retain their separate physical obligations.
static func measured_weapon_source(handle:Dictionary)->bool:
    var selected:Dictionary=Effects.choice(handle.clip)
    if selected.approaches.is_empty() or not selected.approaches[0].get("condition_prepared",false):return false
    if handle.clip.has("construction_inputs"):return false
    return handle.occurrence.parameters.get("adaptive_surface",{}).get("kind") in ["measured","flame_blade"]

func weapon_registration(world:Node,handle:Dictionary,component:Dictionary)->Dictionary:
    if "item_snapshot" in handle.clip.get("inputs",[]):
        var item:Dictionary=Weapons.resolve(world,component)
        if not item.ready:return {"ready":false,"unavailable":true,"reason":item.reason}
        var surface:Dictionary=Weapons.surface(surfaces.sample(world,item.actor,item.slots),item)
        if not surface.ready:return {"ready":false,"pending":true,"reason":surface.reason}
        # Exact selected item pixels/support own this root; a body hand is not
        # a substitute for the rendered item's measured optical point.
        return {"ready":true,"reason":"","weapon":item,"surface":surface,"optical_anchor":surface.optical_anchor,
            "hand":{"ready":false,"reason":"actual_item_optical_anchor"}}
    if "weapon_binding" not in handle.clip.get("inputs",[]):return {}
    var weapon:Dictionary=Weapons.resolve(world,component)
    var hand:Dictionary={"ready":false,"reason":weapon.reason}
    if weapon.ready:
        hand=Sockets.pose_point(world,world.visual_actors[weapon.actor].row,"hand") if weapon.render_slot=="weapon" \
            else {"ready":false,"reason":"weapon_offhand_socket_not_authored"}
    var measured:bool=measured_weapon_source(handle)
    var cue:Dictionary=component.get("native_cue",{})
    var grip_required:bool=cue.get("live_endpoints",[]).any(func(endpoint):return endpoint.get("socket") in ["hand","cast_hand"])
    var absent:bool=hand.get("reason") in ["native_spell_hand_socket_missing","weapon_offhand_socket_not_authored"]
    var surface_owned:bool=measured or Weapons.equipped_source(handle) and weapon.render_slot=="weapon"
    var surface_anchor:bool=surface_owned and absent and cue.get("attachment") in ["recipient_weapon","item"] and not grip_required
    var packet:Dictionary=Weapons.packet(weapon,hand,not surface_anchor)
    var result:Dictionary={"ready":packet.ready,"reason":packet.reason,"weapon":weapon,"hand":hand,"packet":packet,"surface":{},"measured":measured}
    if handle.clip.get("inputs",[]).any(func(channel):return channel in ["entity_geometry","recipient_geometry"]):
        result.surface=geometry_sample(world,component,"entity_geometry",weapon)
    if not packet.ready:
        result.pending=hand.get("pending",false);result.unavailable=not result.pending;return result
    if hand.get("ready",false):return result
    # No manufactured binding.hand: this is the optical support frame already
    # assembled/cached with the exact selected weapon points, not its hilt.
    if not result.surface.get("ready",false):
        result.ready=false;result.reason=result.surface.get("reason","weapon_surface_not_prepared")
        result.pending=true;return result
    result.optical_anchor=result.surface.optical_anchor
    return result

static func geometry_interests(component:Dictionary,world:Node=null)->Array:
    var requested:Array=component.get("native_clip",{}).get("inputs",[])
    var policies:Dictionary=component.get("native_cue",{}).get("input_policies",{})
    requested=requested.filter(func(channel):return policies.get(channel,{}).get("mode")!="not_applicable")
    var result:Array=[]
    if ("weapon_binding" in requested or "item_snapshot" in requested) and world!=null:
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
    if component.has("weapon_result_item_uuid") and channel=="recipient_geometry":
        var source:String=str(component.actor_uuid)
        var visual:Dictionary=world.visual_actors.get(source,{})
        var exact:bool=visual.get("entries",[]).any(func(entry):return entry.role!="shadow" and entry.node.is_visible_in_tree() \
            and entry.actor_layer.get("item_uuid")==component.weapon_result_item_uuid and entry.actor_layer.get("slot") in ["weapon","offhand"])
        if not exact:return {"actor":source,"ready":false,"reason":"attributed_attack_item_not_currently_displayed","points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
    if "weapon_binding" in component.get("native_clip",{}).get("inputs",[]) and channel!="source_geometry":
        if weapon.is_empty():weapon=Weapons.resolve(world,component)
        if not weapon.ready:return {"actor":weapon.actor,"actor_uuid":weapon.actor,"ready":false,"reason":weapon.reason,"points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
        return Weapons.surface(surfaces.sample(world,weapon.actor,weapon.slots),weapon)
    var request:Dictionary=geometry_request(component,channel)
    if not request.reason.is_empty():return {"actor":"","actor_uuid":"","ready":false,"reason":request.reason,"points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
    var region:Dictionary={}
    if not request.region.is_empty():
        var visual:Dictionary=world.visual_actors.get(request.actor,{})
        if not Sockets.displayed(visual):return {"actor":request.actor,"ready":false,"reason":"actor_not_displayed","points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
        var anchor:Dictionary
        if request.region.get("at")=="impact":
            var impact:Dictionary=component.get("impact",{})
            if impact.get("status")!="available":return {"actor":request.actor,"ready":false,"reason":"actual_impact_region_not_resolved","points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
            anchor={"point":impact.world_anchor}
        else:
            anchor=Sockets.pose_point(world,visual.row,request.region.socket)
            if not anchor.ready:return {"actor":request.actor,"ready":false,"reason":anchor.reason,"points":[],"origin":Vector3.ZERO,"gpu_geometry_key":[]}
        var body_scale:float=visual.get("sampled_pose",{}).get("body_scale",{}).get("factor",1.0)
        region={"socket":str(request.region.get("socket",request.region.get("at",""))),"point":anchor.point,"radius":float(request.region.radius_cells)*float(visual.row.scale)*body_scale}
    var result:Dictionary=surfaces.sample(world,request.actor,request.slots,region)
    result.geometry_slots=request.slots
    if not request.region.is_empty() and request.region.has("id"):result.region_id=str(request.region.id)
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
    var dependencies:Array=[]
    var flash:Dictionary=Construction.Conditions.material(actor,world.displayed_components).get("flash",{})
    if not flash.get("native_hit",{}).is_empty() and world.native_spell_hit_material:
        var native:Dictionary=world.component_renderer.native_hits.history_material(flash)
        if not native.ready:return native
        dependencies.append(native.dependency)
    return {"ready":true,"packet":{"actor_uuid":actor,"camera":world.camera,"receiver_depth":receiver_depth,
        "depth_encoding":"rgb24_reversed_z","capture_size":Vector2i(world.get_viewport().get_visible_rect().size),
        "origin":Sockets.Placement.contact(visual.row),"layers":layers,"pose_key":pose.key,
        "material_revision":revision,"material_dependencies":dependencies,
        "capture_identity":{"actor_uuid":actor,"display_ms":world.timeline.display_ms,
            "native_results":dependencies.map(func(value):return value.identity)}}}

static func current_pose_history(handle:Dictionary)->bool:
    var settings:Dictionary=handle.occurrence.parameters.get("actor_history",{})
    return settings.get("mirror",false) and not settings.get("capture_departure",false) and not settings.get("specifications",[]).any(func(row):return float(row.get("delay",0.0))>0.0)

static func departure_history(handle:Dictionary)->bool:
    if not handle.has("occurrence"):return false # Recorded handles have no live constructor/context.
    var settings:Dictionary=handle.occurrence.parameters.get("actor_history",{})
    return settings.get("capture_departure",false) and not settings.get("mirror",false)

## History modes come from the selected delivered constructor, never spell IDs.
static func rolling_history(handle:Dictionary)->bool:
    if not handle.has("occurrence") or not is_instance_valid(handle.occurrence):return false
    var settings:Dictionary=handle.occurrence.parameters.get("actor_history",{})
    return not settings.get("mirror",false) and not settings.get("capture_departure",false) and settings.get("specifications",[]).any(func(row):return float(row.get("delay",0.0))>0.0)

static func capture_view_key(world:Node)->Array:
    var camera:Camera3D=world.camera
    # Match the delivered capture's optical inputs. Pan, zoom and resize need
    # new private pixels without changing the original logical departure.
    return [Vector2i(world.get_viewport().get_visible_rect().size),camera.global_transform,
        camera.projection,camera.keep_aspect,camera.size,camera.near,camera.far,
        camera.fov,camera.frustum_offset,camera.h_offset,camera.v_offset]

static func history_key(world:Node,handle:Dictionary,component:Dictionary)->Array:
    return [world.timeline.initialization_revision,component.get("condition_uuid"),world.quarter,capture_view_key(world),
        world.source_depth,world.source_normals,world.character_light_profile]

static func _history_source_key(capture:Dictionary,world:Node)->Array:
    var value:Dictionary=capture.departure
    # Frames, position, facing and treatment age bind at seeding, not construction.
    # Shared source topology/private layer ownership survives a view recapture.
    var result:Array=[capture.rig,capture.clip,value.row.equipment_layers,capture.hidden_slots,
        value.row.scale,value.row.get("scale_x",1.0),value.layer_samples.map(func(row):return row.get("clip","")),
        value.material.get("ramp",{}).get("texture"),value.material.get("flash",{}).get("material",{}).get("palette",{}).get("noiseSheet")]
    var rig:Dictionary=capture.source_registration if capture.has("source_registration") else world.rigs.get(capture.rig,{})
    if capture.has("source_registration"):result.append(float(capture.source_registration.source_scale))
    if rig.get("native_banks",false):
        result.append(capture.world_facing)
        result.append(value.layer_samples.map(func(row):return [row.get("clip",""),row.get("source_track",{}).get("from_position"),row.get("source_track",{}).get("target_position",row.get("source_track",{}).get("to_position"))]))
    return result

func prepare_history(world:Node,handle:Dictionary,component:Dictionary,admit:bool=true)->Dictionary:
    var owner:String=str(component.get("condition_uuid",""))
    if not world.timeline.condition_owners.has(owner):return {"ready":true,"pending":false}
    var key:Array=history_key(world,handle,component)
    if handle.get("history_seeded_key",[])==key or handle.get("history_sources_ready_key",[])==key:return {"ready":true,"pending":false}
    if not admit:return {"ready":false,"pending":true}
    var at:float=world.timeline.display_ms
    if handle.get("history_prepare_key",[])!=key:
        var maximum:float=0.0
        for specification in handle.occurrence.parameters.actor_history.specifications:maximum=maxf(maximum,float(specification.get("delay",0.0)))
        var delays:Array=[0.0,maximum]
        for step in range(1,ceili(maximum*60.0)):delays.append(float(step)/60.0)
        for specification in handle.occurrence.parameters.actor_history.specifications:
            var delay:float=float(specification.get("delay",0.0))
            if delay not in delays:delays.append(delay)
        var observed:Dictionary=world.timeline.history_captures(recipient(component),owner,at,delays)
        if not observed.ready:return {"ready":false,"pending":false,"reason":observed.reason}
        handle.history_prepare_key=key;handle.history_captures=observed.captures
        handle.history_prefix_cursor=0
        handle.history_allocation_step=0;handle.erase("history_allocated")
        handle.history_capture_range={"from_ms":observed.get("available_from_ms",at),"to_ms":at,"complete_window":observed.get("complete_window",false)}
        handle.history_active_sources={}
    var sources:Dictionary=handle.get("history_sources",{})
    handle.history_sources=sources
    var representatives:Dictionary={}
    for capture in handle.history_captures:
        var source_key:Array=_history_source_key(capture,world)
        if representatives.has(source_key):continue
        representatives[source_key]=true
        handle.history_active_sources[source_key]=true
        if not sources.has(source_key):sources[source_key]={"occurrence":handle.occurrence,"clip":handle.clip,"root":handle.root}
        var row:Dictionary=sources[source_key]
        row.history_draw_captures=handle.history_captures.filter(func(value):return _history_source_key(value,world)==source_key)
        var bound:Dictionary=component.duplicate(false);bound.logical_pose=row.get("departure_capture",capture)
        var prepared:Dictionary=prepare_departure(world,row,bound)
        if not prepared.ready:return prepared
    handle.history_sources_ready_key=key
    return {"ready":true,"pending":false}

## Realize only complete original capture requests under this existing owner's
## remaining allowance. The capture array/target are fixed by prepare_history;
## no current actor sample may interleave until every requested draw is admitted.
func prepare_history_prefix(world:Node,handle:Dictionary,component:Dictionary,receiver_depth:Texture2D,allowance_usec:int,urgent:bool=true)->Dictionary:
    var key:Array=history_key(world,handle,component)
    # Only the real sampling boundary chooses whether predecessors are needed.
    # Unknown interest must not prevent that first sample or realize a newborn.
    if handle.get("history_seeded_key",[])==key or handle.get("history_prefix_demand_key",[])!=key:
        return {"ready":true,"pending":false}
    if handle.get("history_sources_ready_key",[])!=key or not handle.get("history_allocated",false):
        return {"ready":false,"pending":true,"reason":"actor_history_prefix_sources_preparing"}
    var captures:Array=handle.get("history_captures",[])
    if captures.is_empty():return {"ready":false,"pending":false,"reason":"actor_history_prefix_not_observed"}
    var started:int=Time.get_ticks_usec()
    var helper:RefCounted=handle.occurrence.actor_history
    if handle.get("history_requested_key",[])!=key:
        var cursor:int=int(handle.get("history_prefix_cursor",0))
        while cursor<captures.size():
            if Time.get_ticks_usec()-started>=allowance_usec:
                return {"ready":false,"pending":true,"reason":"actor_history_prefix_preparing"}
            # Actual required mutation uses the existing urgent handoff; an
            # optional prefix never displaces an admitted source worker.
            if (not urgent and not Effects.Admission.can_mutate()) or not Effects.Admission.begin_mutation():
                return {"ready":false,"pending":true,"reason":"actor_history_prefix_admission_pending"}
            var capture:Dictionary=captures[cursor]
            var source:Dictionary=handle.history_sources[_history_source_key(capture,world)]
            var packet:Dictionary=_private_layer_context(world,source,capture,receiver_depth)
            if not packet.ready:return packet
            if not handle.occurrence.call(handle.clip.input_setters.actor_context,packet.packet):
                return {"ready":false,"pending":false,"reason":"actor_history_prefix_not_accepted"}
            # Only the private source helper sees original predecessor ages.
            # Each request freezes its original clock/material dependencies now.
            var seconds:float=maxf(0.0,float(capture.sample_ms)-float(capture.admitted_at_ms))/1000.0
            helper.sample(seconds)
            if helper.history.is_empty():helper.sample(seconds)
            cursor+=1;handle.history_prefix_cursor=cursor
            var submitted:Dictionary=capture_status(handle)
            if not str(submitted.get("error","")).is_empty():return submitted
        handle.history_requested_key=key
    # Resume only the exact outstanding immutable requests after a real source
    # suspension. Already completed or already armed captures are untouched.
    for poses in helper.history.values():
        for pose in poses:
            if not pose.has("capture") or not pose.capture.get("suspended",false):continue
            if Time.get_ticks_usec()-started>=allowance_usec:
                return {"ready":false,"pending":true,"reason":"actor_history_prefix_draw_preparing"}
            if (not urgent and not Effects.Admission.can_mutate()) or not Effects.Admission.begin_mutation():
                return {"ready":false,"pending":true,"reason":"actor_history_prefix_admission_pending"}
            HistoryOwner.Capture.resume(pose.capture)
    var status:Dictionary=capture_status(handle)
    if not status.ready:return status
    for source_key in handle.get("history_sources",{}).keys():
        if handle.history_active_sources.has(source_key):continue
        if Time.get_ticks_usec()-started>=allowance_usec:
            return {"ready":false,"pending":true,"reason":"actor_history_prefix_retiring"}
        var source:Dictionary=handle.history_sources[source_key]
        for field in ["departure_task","departure_resource_task"]:
            var task:int=int(source.get(field,-1))
            if task>=0 and not WorkerThreadPool.is_task_completed(task):
                return {"ready":false,"pending":true,"reason":"actor_history_prefix_retiring"}
        if (not urgent and not Effects.Admission.can_mutate()) or not Effects.Admission.begin_mutation():
            return {"ready":false,"pending":true,"reason":"actor_history_prefix_admission_pending"}
        release_departure(source);handle.history_sources.erase(source_key)
    handle.history_seeded_key=key
    return {"ready":true,"pending":false}

func seed_history(world:Node,handle:Dictionary,component:Dictionary,_receiver_depth:Texture2D)->Dictionary:
    var key:Array=history_key(world,handle,component)
    if handle.get("history_seeded_key",[])==key:return {"ready":true}
    # Keep the original decision at the actual inputs.sync sampling boundary,
    # including a pending owner sampled backwards into its live-birth window.
    if float(component.get("age_ms",INF))<=1000.0/60.0:
        handle.history_seeded_key=key;return {"ready":true}
    # Existing preparation owns only demand the real source sample has reached.
    # No current helper packet/sample replaces this unfinished immutable prefix.
    if handle.get("history_prefix_demand_key",[])!=key:handle.erase("history_prefix_status")
    handle.history_prefix_demand_key=key
    var status:Dictionary=handle.get("history_prefix_status",{})
    if not status.is_empty() and not status.get("ready",false) and not status.get("pending",false):return status
    return {"ready":false,"pending":true,"reason":"actor_history_prefix_not_prepared"}

static func invalidate_history(handle:Dictionary)->bool:
    if not rolling_history(handle) or not handle.has("history_seeded_key"):return false
    # Preserve the original withdrawal rule. An unseeded prefix is suspended
    # by Effects.hide and later re-arms the same immutable requests.
    handle.occurrence.actor_history.close()
    for field in ["history_seeded_key","history_requested_key","history_prepare_key","history_sources_ready_key","history_prefix_cursor","history_prefix_demand_key","history_prefix_status","history_captures","history_allocated","history_allocation_key","history_allocation_step"]:handle.erase(field)
    return true

static func history_paths(handle:Dictionary)->Dictionary:
    var paths:Dictionary={}
    for source in handle.get("history_sources",{}).values():paths.merge(source.get("departure_paths",{}))
    return paths

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
    if capture.has("source_registration") and not is_same(Characters.rigs(cache).get(capture.rig),capture.source_registration):
        output.merge({"complete":true,"reason":"departure_source_registration_not_admitted"});return
    var rig:Dictionary=capture.source_registration if capture.has("source_registration") else Characters.rigs(cache)[capture.rig]
    var prepared:Dictionary=Characters.prepare_layers(row,rig,cache)
    if not prepared.ok:output.merge({"complete":true,"reason":prepared.error.message});return
    var layers:Dictionary={};var paths:Dictionary={}
    for layer in prepared.value:
        if layer.slot=="shadow" or layer.slot in capture.hidden_slots:continue
        var selected:Dictionary=_departure_layer(layer,capture,rig,config.quarter,config.cycle)
        var path:String=Characters.source_path(layer,selected.clip,selected.facing)
        if path.is_empty():output.merge({"complete":true,"reason":"departure_layer_clip_not_authored:"+str(layer.slot)});return
        var binding:Dictionary=Construction.prepare_binding(rig,layer,path,cache,config.depth,config.normals,config.profile,
            128.0/float(departure.tile_width)*float(row.scale),float(row.get("scale_x",1.0)))
        var index:int=layers.size()
        layers[index]={"layer":layer,"binding":binding,"frame":selected.frame}
        if rig.get("native_banks",false):layers[index].facing=selected.facing
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
func prepare_departure(world:Node,handle:Dictionary,component:Dictionary,admit:bool=true)->Dictionary:
    var capture:Dictionary=departure_capture(component)
    if capture.is_empty():return {"ready":false,"pending":false,"reason":"condition_original_departure_not_observed"}
    if not str(capture.departure.reason).is_empty():return {"ready":false,"pending":false,"reason":capture.departure.reason}
    var key:Array=[capture,world.source_depth,world.source_normals,world.character_light_profile]
    var registration:Dictionary=capture.source_registration if capture.has("source_registration") else world.rigs.get(capture.rig,{})
    if registration.get("native_banks",false):key.append(world.quarter)
    if handle.get("departure_key",[])==key and handle.has("departure_entries"):
        handle.departure_draw_status=_prepare_draw_sources(world,handle,handle.get("history_draw_captures",[capture]),admit)
        return handle.departure_draw_status
    if not admit:return {"ready":false,"pending":true}
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
    handle.departure_draw_status=_prepare_draw_sources(world,handle,handle.get("history_draw_captures",[capture]),admit)
    return handle.departure_draw_status

## Reuse the existing native owners on private original-prefix layers. These
## are selected source occurrences, never a hand-written treatment/opacity or
## a second renderer. Only admitted historical samples can enter this set.
static func _prepare_draw_sources(world:Node,handle:Dictionary,captures:Array,admit:bool)->Dictionary:
    var samples:Dictionary={};var hits:Dictionary={};var clips:Array=[]
    for capture in captures:
        for sample in capture.departure.get("draw_samples",[]):
            samples[sample.id]=sample
        var flash:Dictionary=capture.departure.material.get("flash",{})
        if not flash.get("native_hit",{}).is_empty():hits[NativeHits._key(flash)]=flash
    var records:Dictionary=handle.get("departure_draw_sources",{})
    handle.departure_draw_sources=records
    for sample in samples.values():
        var clip:Dictionary=Effects.occurrence_clip(sample)
        if clip.get("inputs",[]).any(func(channel):return channel not in ["actor_layers","treatment_state","pose_provider","appearance_provider","owner_state"]):
            Effects.retain_source_preparation(handle.get("departure_source_resources",{}),[])
            return {"ready":false,"pending":false,"reason":"history_native_owner_requires_unsupported_input:"+str(sample.id)}
        if Effects.choice(clip).kind in ["","recorded"]:
            Effects.retain_source_preparation(handle.get("departure_source_resources",{}),[])
            return {"ready":false,"pending":false,"reason":"history_native_owner_requires_live_source:"+str(sample.id)}
        if not records.has(sample.id):clips.append(clip)
    Effects.retain_source_preparation(handle.get("departure_source_resources",{}),clips)
    if not clips.is_empty():
        if not admit:return {"ready":false,"pending":true,"reason":"history_draw_sources_preparing"}
        if not handle.has("departure_source_resources"):handle.departure_source_resources={}
        var loading:Dictionary=Effects.prepare(clips,handle.departure_source_resources)
        if not loading.errors.is_empty():return {"ready":false,"pending":false,"reason":"; ".join(loading.errors)}
        if not loading.ready:return {"ready":false,"pending":true,"reason":"history_draw_sources_preparing"}
        for sample in samples.values():
            if records.has(sample.id):continue
            var record:Dictionary=Effects.make(handle.occurrence,Effects.occurrence_clip(sample),0,0)
            if not str(record.error).is_empty():
                var reason:String=record.error;Effects.close(record)
                return {"ready":false,"pending":false,"reason":reason}
            record.root.hide();records[sample.id]=record
    if not hits.is_empty() and world.native_spell_hit_material:
        if not handle.has("departure_native_hits"):handle.departure_native_hits=NativeHits.new()
        var native:Dictionary=handle.departure_native_hits.prepare(handle.occurrence,hits.values(),world.catalog_cache,[],{},false)
        if not native.ready:
            var missing:Array=native.issues.filter(func(issue):return issue.status=="missing")
            return {"ready":false,"pending":missing.is_empty(),"reason":"history_native_hit_sources_preparing" if missing.is_empty() else str(missing)}
    return {"ready":true,"pending":false,"reason":""}

static func _bind_draw_sources(handle:Dictionary,capture:Dictionary,layers:Array)->Dictionary:
    # A topology can serve several historical conditions. Unbind owners absent
    # at this exact original age before applying the next prefix's operands.
    var selected:Dictionary={}
    if not handle.get("departure_draw_status",{}).get("ready",false):return handle.get("departure_draw_status",{"ready":false,"reason":"history_native_owner_sources_not_prepared"})
    for sample in capture.departure.get("draw_samples",[]):selected[sample.id]=sample
    for id in handle.get("departure_draw_sources",{}):
        var record:Dictionary=handle.departure_draw_sources[id]
        if not selected.has(id):
            if "actor_layers" in record.clip.inputs:Effects.set_input(record,"actor_layers",{"actor_uuid":capture.actor_uuid,"layers":[]})
            if "appearance_provider" in record.clip.inputs:Effects.set_input(record,"appearance_provider",{"provider":null,"actor_uuid":capture.actor_uuid})
    for sample in selected.values():
        var record:Dictionary=handle.departure_draw_sources[sample.id]
        var inputs:Array=record.clip.inputs
        if "pose_provider" in inputs:
            var logical:Dictionary=sample.get("logical_pose",{})
            if logical.is_empty():return {"ready":false,"reason":"history_native_pose_not_observed"}
            var binding:ConditionPose.Binding=ConditionPose.Binding.new()
            binding.actor_uuid=capture.actor_uuid;binding.condition_uuid=sample.condition_uuid;binding.capture=logical
            record.history_pose_binding=binding
            if not record.occurrence.call(record.clip.input_setters.pose_provider,{"provider":binding,"actor_uuid":capture.actor_uuid,"owner_uuid":sample.condition_uuid,"admitted":true}):
                return {"ready":false,"reason":"history_native_pose_not_accepted"}
        if "actor_layers" in inputs:
            if not record.occurrence.call(record.clip.input_setters.actor_layers,{"actor_uuid":capture.actor_uuid,"layers":layers}):
                return {"ready":false,"reason":"history_native_layers_not_accepted"}
        if "treatment_state" in inputs:
            var state:Variant=sample.get("condition",{}).get("state")
            Effects.set_input(record,"treatment_state",state if state is Dictionary else {})
        if "appearance_provider" in inputs:
            if not handle.has("departure_appearances"):handle.departure_appearances=Appearances.new()
            var binding:Appearances.Binding=Appearances.Binding.new()
            binding.appearances=handle.departure_appearances;binding.actor_uuid=capture.actor_uuid
            binding.condition_uuid=sample.condition_uuid;binding.private_entries=handle.departure_entries
            record.history_appearance_binding=binding
            if not record.occurrence.call(record.clip.input_setters.appearance_provider,{"provider":binding,"actor_uuid":capture.actor_uuid}):
                return {"ready":false,"reason":"history_appearance_outfit_not_admitted"}
        var age:float=float(sample.age_ms)/1000.0
        if sample.has("history_owner_state"):
            Effects.set_input(record,"owner_state",sample.history_owner_state)
            Effects.sample(record,float(sample.history_owner_state.owner_age_seconds))
        else:Effects.sample(record,Playback.source_time(sample.native_cue,age))
        record.root.hide()
    for entry in handle.departure_entries:
        var effect:Dictionary=entry.actor_layer.get("effect",{})
        if effect.get("kind")!="condition_appearance":continue
        if not selected.values().any(func(sample):return sample.get("condition_uuid") in effect.get("condition_uuids",[]) and "appearance_provider" in sample.native_clip.inputs):
            return {"ready":false,"reason":"history_appearance_opacity_source_not_disclosed"}
    if handle.has("departure_appearances"):handle.departure_appearances.sync_private_entries(capture.actor_uuid,handle.departure_entries)
    return {"ready":true}

func _private_layer_context(world:Node,handle:Dictionary,capture:Dictionary,receiver_depth:Texture2D)->Dictionary:
    if not handle.has("departure_entries"):return {"ready":false,"reason":"departure_layers_not_prepared"}
    if not world.camera is Camera3D or receiver_depth==null:return {"ready":false,"reason":"actor_context_receiver_not_prepared"}
    var row:Dictionary=capture.departure.row
    var rig:Dictionary=capture.source_registration if capture.has("source_registration") else Characters.rigs(world.catalog_cache)[capture.rig]
    var layers:Array=[];var revision:Array=[]
    var value:Dictionary=capture.departure.material.duplicate(false)
    var dependencies:Array=[]
    var flash:Dictionary=value.get("flash",{})
    if not flash.get("native_hit",{}).is_empty() and world.native_spell_hit_material:
        if not handle.has("departure_native_hits"):return {"ready":false,"reason":"history_native_hit_source_not_prepared"}
        var native:Dictionary=handle.departure_native_hits.history_material(flash)
        if not native.ready:return native
        flash=flash.duplicate(false);flash.native_surface=native.surface
        flash.native_ramp=native.ramp;flash.native_finishing=native.finishing
        value.flash=flash;dependencies.append(native.dependency)
    var parameters:Dictionary=Construction.Conditions.parameters(value,world.textures,world.resources)
    parameters.merge(Construction.aperture_parameters(capture.departure.motion,world.camera.basis,float(capture.departure.tile_width)),true)
    if not capture.departure.motion.get("body_visible",true):parameters.condition_alpha=0.0
    parameters.make_read_only()
    for entry in handle.departure_entries:
        var selected:Dictionary=_departure_layer(entry.actor_layer,capture,rig,world.quarter,world.rig_config.FACING_CYCLE)
        var binding:Dictionary=entry.prepared_source_binding
        if rig.get("native_banks",false):
            if Characters.source_path(entry.actor_layer,selected.clip,selected.facing)!=binding.path:return {"ready":false,"reason":"departure_native_view_not_prepared"}
            if not Construction.apply_source_shape(entry,rig,binding.path,binding.get("source_layout",{})):return {"ready":false,"reason":"departure_native_shape_not_prepared"}
        Construction.bind_source_values(entry,rig,binding.path,selected.frame,selected.facing,binding.sheet,binding.sheet_size,
            world.textures,world.resources,parameters)
        entry.node.global_transform=Construction.layer_transform(world.camera.basis,row,rig,capture.departure.motion,entry.role,
            capture.clip,world.rig_config.FACING_CYCLE[posmod(world.rig_config.FACING_CYCLE.find(capture.world_facing)+world.quarter*2,8)],int(capture.frame),float(capture.departure.tile_width),float(capture.departure.material.body_scale.factor))
        layers.append({"slot":entry.actor_layer.slot,"node":entry.node,"material":entry.material,"received_material":entry.material,
            "pivot":entry.pivot,"ground_pixels":entry.get("geometry_ground_pixels",19.0)})
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0),entry.get("source_binding_revision",0)])
    if layers.is_empty():return {"ready":false,"reason":"departure_layers_not_prepared"}
    var shaders:Array=handle.departure_entries.map(func(entry):return entry.material.shader)
    var bound:Dictionary=_bind_draw_sources(handle,capture,layers)
    if not bound.ready:return bound
    revision=[]
    for index in handle.departure_entries.size():
        var entry:Dictionary=handle.departure_entries[index]
        if entry.material.shader!=shaders[index]:SourceMaterial.structural_change(entry)
        revision.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.get("source_version",0),entry.get("source_binding_revision",0),entry.material.shader])
    var origin:Vector3=Sockets.Placement.contact(row)
    return {"ready":true,"packet":{"actor_uuid":capture.actor_uuid,"camera":world.camera,"receiver_depth":receiver_depth,
        "depth_encoding":"rgb24_reversed_z","capture_size":Vector2i(world.get_viewport().get_visible_rect().size),
        "origin":origin,"layers":layers,"pose_key":[capture.clip,capture.frame,capture.world_facing,world.quarter,capture.get("sample_ms",capture.admitted_at_ms)],
        "material_revision":revision,"material_dependencies":dependencies,"history_clock_image":HistoryClock.image.duplicate(),
        "condition_uuid":capture.condition_uuid,"capture_identity":{"actor_uuid":capture.actor_uuid,"condition_uuid":capture.condition_uuid,
            "sample_ms":capture.get("sample_ms",capture.admitted_at_ms),"admitted_at_ms":capture.admitted_at_ms,
            "native_results":dependencies.map(func(dependency):return dependency.identity)}}}

static func allocation_key(world:Node,handle:Dictionary,component:Dictionary)->Array:
    var entries:Array=handle.get("departure_entries",[]) if departure_history(handle) else world.visual_actors.get(recipient(component),{}).get("entries",[])
    var topology:Array=[]
    for entry in entries:
        if entry.role=="shadow":continue
        var effect:Dictionary=entry.actor_layer.get("effect",{})
        if not effect.is_empty() and effect.get("kind")!="condition_appearance":continue
        topology.append([entry.node.get_instance_id(),entry.material.get_instance_id(),entry.material.shader])
    return [history_key(world,handle,component),world.get_viewport().get_visible_rect().size,topology]

func allocation_context(world:Node,handle:Dictionary,component:Dictionary,receiver_depth:Texture2D)->Dictionary:
    if departure_history(handle):return departure_context(world,handle,component,receiver_depth)
    if rolling_history(handle):
        var step:int=int(handle.get("history_allocation_step",0))
        var sources:Array=handle.get("history_active_sources",{}).keys()
        if step<sources.size():
            var source:Dictionary=handle.history_sources[sources[step]]
            return _private_layer_context(world,source,source.departure_capture,receiver_depth)
    return actor_context(world,recipient(component),receiver_depth)

static func advance_allocation(handle:Dictionary)->bool:
    if not rolling_history(handle):return true
    var step:int=int(handle.get("history_allocation_step",0))
    if step>=handle.get("history_active_sources",{}).size():return true
    handle.history_allocation_step=step+1
    return false

func departure_context(world:Node,handle:Dictionary,component:Dictionary,receiver_depth:Texture2D)->Dictionary:
    var capture:Dictionary=departure_capture(component)
    if capture.is_empty():return {"ready":false,"reason":"condition_original_departure_not_observed"}
    var context:Dictionary=_private_layer_context(world,handle,capture,receiver_depth)
    if not context.ready:return context
    var logical:Array=[capture.actor_uuid,capture.condition_uuid,capture.admitted_at_ms]
    var packet:Dictionary=context.packet
    packet.departure_layers=packet.layers;packet.layers=[]
    packet.departure_revision=logical;packet.departure_origin=packet.origin
    packet.departure_capture_revision=[logical,world.quarter,capture_view_key(world),packet.material_revision]
    return context

static func seed_departure(handle:Dictionary,context:Dictionary)->Dictionary:
    var key:Variant=context.packet.departure_capture_revision
    if handle.get("departure_seeded_key")==key:return capture_status(handle)
    # This is the actual pre-cut body observed at this condition's admission.
    # Its original owner age is zero even when playback seeks past departure.
    # Only the public history helper receives it; the occurrence stays at its
    # normal current clock and never replays particles/phase envelopes.
    var helper:RefCounted=handle.occurrence.actor_history
    helper.sample(0.0)
    if helper.history.is_empty():helper.sample(0.0)
    handle.departure_seeded_key=key
    return capture_status(handle)

static func release_departure(handle:Dictionary)->void:
    for source in handle.get("history_sources",{}).values():release_departure(source)
    for field in ["history_sources","history_active_sources","history_captures","history_prepare_key","history_seeded_key","history_requested_key","history_sources_ready_key","history_prefix_cursor","history_prefix_demand_key","history_prefix_status","history_allocation_key","history_allocation_step","history_capture_range"]:handle.erase(field)
    for field in ["departure_task","departure_resource_task"]:
        if int(handle.get(field,-1))>=0:WorkerThreadPool.wait_for_task_completion(handle[field])
    if handle.has("departure_source_resources"):Effects.Admission.cancel_source_cache(handle.departure_source_resources)
    for record in handle.get("departure_draw_sources",{}).values():Effects.close(record)
    if handle.has("departure_appearances"):handle.departure_appearances.clear()
    if handle.has("departure_native_hits"):handle.departure_native_hits.close()
    if handle.has("departure_parent") and is_instance_valid(handle.departure_parent):handle.departure_parent.free()
    elif handle.has("departure_output"):
        for packets in handle.departure_output.get("rows",{}).values():
            for packet in packets.values():
                if is_instance_valid(packet.entry.node):packet.entry.node.free()
    for field in ["departure_key","departure_capture","departure_metadata","departure_task","departure_paths","departure_output","departure_resource_task","departure_parent","departure_entries","departure_seeded_key","departure_draw_sources","departure_draw_status","departure_appearances","departure_native_hits","departure_source_resources"]:handle.erase(field)

static func endpoints(component:Dictionary,points:Dictionary,surface:Dictionary)->Array:
    # Legacy targets forwards to set_live_endpoints (source, recipient).
    # Prepared conditions discover one surface in the same array. Never put a
    # second actor's body on the source endpoint of a recipient occurrence.
    var target:Dictionary={"actor_uuid":recipient(component),"role":"recipient","point":points.to}
    if not surface.is_empty():target.surface=surface
    var source:Vector3=points.optical_anchor if points.has("optical_anchor") else points.hand
    return [{"actor_uuid":str(component.get("actor_uuid","")),"role":"source","point":source},target]

func endpoint_packet(world:Node,handle:Dictionary,component:Dictionary,points:Dictionary,surface:Dictionary)->Dictionary:
    var cue:Dictionary=component.get("native_cue",{})
    if cue.has("review_trajectory"):return {"rows":[],"reason":"review_trajectory_not_bound"}
    if not cue.has("live_endpoints"):
        if component.has("lifecycle_phases"):
            var live:Dictionary=handle.occurrence.parameters.get("live_pose",{})
            if live.get("mode")=="gaze":
                var visual:Dictionary=world.visual_actors.get(recipient(component),{})
                if not Sockets.displayed(visual):return {"rows":[],"reason":"actor_not_displayed"}
                return Sockets.display_facing_aim(visual.row,world.rig_config.FACING_CYCLE,points.to,live,str(cue.get("aim_policy","")))
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
        if authored.has("aim_from_endpoint"):
            var anchor:int=int(authored.aim_from_endpoint)
            var pair:Array=authored.get("direction_endpoints",[])
            if pair.size()!=2 or anchor<0 or anchor>=result.size():return {"rows":[],"reason":"authored_optical_aim_endpoints_not_bound"}
            var first:int=int(pair[0]);var second:int=int(pair[1])
            if first<0 or second<0 or first>=result.size() or second>=result.size():return {"rows":[],"reason":"authored_optical_aim_endpoints_not_bound"}
            var direction:Vector3=result[second].point-result[first].point
            if direction.is_zero_approx():return {"rows":[],"reason":"authored_optical_aim_direction_empty"}
            result.append({"point":result[anchor].point+direction,"optical_aim":"authored_endpoint_direction"});continue
        if authored.has("area_point"):
            var area:Dictionary=PropagationInputs.area_endpoint(component,authored,points)
            if not area.ready:return {"rows":[],"reason":area.reason}
            result.append({"point":area.point,"area_point":authored.area_point});continue
        if authored.has("cue_point"):
            if authored.cue_point=="aim":
                var aim:Variant=component.get("aim_position")
                if aim==null:return {"rows":[],"reason":"authored_aim_position_not_disclosed"}
                result.append({"point":Vector3(aim[0],points.caster_ground.y,aim[1]),"cue_point":"aim"});continue
            if authored.cue_point not in ["source","target"]:return {"rows":[],"reason":"authored_cue_point_not_bound:"+str(authored.cue_point)}
            result.append({"point":points.from if authored.cue_point=="source" else points.to,"cue_point":authored.cue_point});continue
        var selector:String=str(authored.get("actor",""));var actor:String=actor_uuid(component,selector)
        if actor.is_empty():return {"rows":[],"reason":"authored_actor_binding_not_bound:"+selector}
        var socket:String=str(authored.get("socket",""))
        var visual:Dictionary=world.visual_actors.get(actor,{})
        if socket=="ground" and component.get("native_body_owner",false) and not Sockets.displayed(visual):
            var actual:Dictionary=Sockets.effect_owned_ground(world,component,actor)
            if actual.ready:
                result.append({"actor":actor if authored.get("endpoint_actor_uuids",cue.get("endpoint_actor_uuids",false)) else selector,"actor_uuid":actor,"socket":socket,"point":actual.point})
                continue
        if not Sockets.displayed(visual):return {"rows":[],"reason":"native_spell_endpoint_actor_not_displayed"}
        var resolved:Dictionary={"ready":true}
        var pose_socket:String=str(authored.get("pose_socket",socket))
        if socket=="ground":resolved.point=Sockets.Placement.contact(visual.row)
        elif selector=="caster" and cue.has("source_socket") and socket==cue.source_socket:resolved.point=points.from
        elif selector=="caster" and socket in ["cast_hand","hand"]:resolved.point=points.hand
        else:resolved=Sockets.pose_point(world,visual.row,pose_socket,authored.get("pose_socket_by_clip",{}))
        if not resolved.ready:return {"rows":[],"reason":resolved.reason}
        if authored.has("optical_miss"):
            resolved=Sockets.miss_point(world,visual.row,resolved.point,authored.optical_miss)
            if not resolved.ready:return {"rows":[],"reason":resolved.reason}
        var endpoint:Dictionary={"actor":actor if authored.get("endpoint_actor_uuids",cue.get("endpoint_actor_uuids",false)) else selector,"actor_uuid":actor,"socket":socket,"point":resolved.point}
        if authored.get("view_basis",false):endpoint.view_basis=world.camera.global_basis
        if authored.has("surface_slots"):
            var slots:Array=Array(authored.surface_slots)
            var supplied:Dictionary=surface if surface.get("actor")==actor and surface.get("geometry_slots",[])==slots else receiver_surface(surfaces.sample(world,actor,slots),handle.root.global_transform)
            if not supplied.ready:return {"rows":[],"reason":supplied.reason,"pending":supplied.get("pending",false)}
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

## Actual self-owned condition packet. Its public state remains immutable;
## no member-benefit UUID, private duration or spatial identity is inferred.
static func owner_packet(component:Dictionary,displayed:bool)->Dictionary:
    var condition:Dictionary=component.get("condition",{})
    var state:Variant=condition.get("state")
    var actor:String=str(component.get("actor_uuid",""))
    var owner:String=str(component.get("condition_uuid",""))
    if actor.is_empty() or owner.is_empty() or condition.get("condition_uuid")!=owner or not state is Dictionary \
        or state.get("condition_uuid")!=owner or state.get("behavior_id")!=condition.get("behavior_id"):
        return {"ready":false,"reason":"actual_owner_condition_not_disclosed"}
    var packet:Dictionary={"condition_state":state,"source_entity_uuid":actor,"target_entity_uuid":actor,
        "present":component.get("removal_age_ms")==null,"observed":displayed}
    if component.get("removal_age_ms")!=null:packet.removal_at_seconds=float(component.duration_ms)/1000.0
    return {"ready":true,"binding":{"owner_uuid":owner,"condition_id":condition.behavior_id,
        "source_entity_uuid":actor,"recipient_entity_uuid":actor},"value":packet}

## Actual current held-item facts and measured selected item support. The
## membership's UUID owns age; this holder/optical packet may change at it.
static func item_packet(world:Node,component:Dictionary,registration:Dictionary)->Dictionary:
    if not component.get("dynamic_item_effect",false) or not registration.get("ready",false):
        return {"ready":false,"reason":registration.get("reason","actual_item_membership_not_bound")}
    var item:String=str(component.get("item_owner_uuid",""));var effect:String=str(component.get("item_effect_uuid",""))
    var member:Dictionary=component.get("item_effect_member",{})
    var actual:Array=world.timeline.state.get("items",{}).get(item,{}).get("effects",[]).filter(func(row):return row.get("effect_uuid")==effect and row.get("behavior_id")==member.get("behavior_id"))
    if item.is_empty() or effect.is_empty() or member.get("effect_uuid")!=effect or actual.size()!=1:
        return {"ready":false,"reason":"actual_item_effect_membership_not_disclosed"}
    var weapon:Dictionary=registration.weapon;var surface:Dictionary=registration.surface
    if weapon.item_uuid!=item or not surface.get("ready",false):return {"ready":false,"reason":"actual_item_optical_support_not_bound"}
    var facts:Dictionary={"item_uuid":item,"effect_uuid":effect,"observed":true,"admitted":true,
        "condition_present":true,"item_visible":Sockets.displayed(world.visual_actors.get(weapon.actor,{}))}
    return {"ready":true,"value":{"item_uuid":item,"effect_uuid":effect,"behavior_id":member.behavior_id,
        "actor_id":weapon.actor,"facts":facts,"socket_found":true,"point":surface.optical_anchor,
        "normal_support_points":surface.points.size(),"actual_item_optical_depth":true,
        "reason":"exact_current_item_measured_surface","geometry_key":surface.gpu_geometry_key}}

## A public readiness publication belongs to the exact currently disclosed
## condition member on its real actor, independently of any private grant.
## Optical admission is separate, including ready=false without a mouth.
static func readiness_packet(world:Node,component:Dictionary,surface:Dictionary)->Dictionary:
    var identity:String=str(component.get("condition_uuid",""))
    var source:String=str(component.get("actor_uuid",""))
    var binding:Dictionary={"condition_uuid":identity,"source_actor_uuid":source,
        "stream_generation":world.timeline.initialization_revision}
    var actor:Dictionary=world.timeline.state.get("actors",{}).get(source,{})
    var members:Array=actor.get("conditions",[]).filter(func(member):return str(member.get("condition_uuid",""))==identity)
    if members.size()!=1:return {"ready":false,"reason":"readiness_condition_owner_not_observed","binding":binding}
    var state:Variant=members[0].get("state")
    if not state is Dictionary or not state.get("ready") is bool or not state.get("breath_type") is String:
        return {"ready":false,"reason":"public_condition_readiness_not_disclosed","binding":binding}
    var age:float=maxf(0.0,float(component.get("age_ms",0.0)))/1000.0
    var clock:Dictionary=Persistent.lifecycle_state(component,age)
    var value:Dictionary={"observed":true,"ready":state.ready,"breath_type":state.breath_type,
        "condition_uuid":identity,"source_actor_uuid":source,
        "suppressed":not state.get("suppression_provider_uuids",[]).is_empty(),
        "observation_revision":int(component.get("native_observation_revision",0)),
        "owner_age_seconds":clock.owner_age_seconds,"phase_age_seconds":clock.phase_age_seconds}
    if surface.get("ready",false) and surface.get("region_id")=="mouth":
        value.mouth_surface_revision=surface.get("region_revision",surface.gpu_geometry_key)
    return {"ready":true,"reason":"","binding":binding,"value":value}

func sync(world:Node,handle:Dictionary,component:Dictionary,points:Dictionary,receiver_depth:Texture2D=null,prepare_only:bool=false,source_sample_seconds:float=INF)->Dictionary:
    var requested:Array=handle.clip.get("inputs",[])
    var supplied:Array=["root_path","binding_owners"]
    if component.has("lifecycle_phases"):supplied.append("owner_state")
    var unavailable:Dictionary={}
    var pending:Dictionary={}
    var not_applicable:Dictionary={}
    # Offline-qualified client choices remain distinct from Factory-required
    # operands actually supplied. No synthetic empty density field is sent.
    for name in component.get("native_cue",{}).get("input_policies",{}):
        var policy:Dictionary=component.native_cue.input_policies[name]
        if policy.mode=="not_applicable":not_applicable[name]=policy.reason
    var geometry_requested:Array=requested.filter(func(channel):return not not_applicable.has(channel))
    var actor:String=recipient(component)
    var surface:Dictionary={}
    var cell_endpoints:Array=[]
    var weapon:Dictionary={}
    var weapon_gaps:Array=[]
    var weapon_surface:Dictionary={}
    var source_contact_seconds:float=-1.0
    if component.has("native_counterspell"):
        var actual:Dictionary=interrupted_packets(world,component)
        for channel in ["reaction_observation","interrupted_presentation","interrupted_path"]:
            if channel not in requested:continue
            if not actual.ready:unavailable[channel]=actual.reason;continue
            var value:Dictionary=actual[channel]
            if value!=handle.get(channel+"_input",{}):
                Effects.set_input(handle,channel,value);handle[channel+"_input"]=value
            supplied.append(channel)
    if "actor_context" in requested:
        if not current_pose_history(handle) and not departure_history(handle) and not rolling_history(handle):unavailable.actor_context="authentic_actor_history_not_bound"
        else:
            var history:Dictionary=seed_history(world,handle,component,receiver_depth) if rolling_history(handle) and not prepare_only else {"ready":true}
            var context:Dictionary=departure_context(world,handle,component,receiver_depth) if departure_history(handle) else actor_context(world,actor,receiver_depth)
            if not history.ready:
                context={"ready":false,"reason":history.reason}
                if history.get("pending",false):pending.actor_context=history.reason
            if context.ready:
                # The camera/depth texture are live references; source sampling
                # consumes exact current transforms even if source pixels match.
                context.packet.condition_uuid=component.get("condition_uuid","")
                context.packet.capture_identity=context.packet.get("capture_identity",{}).merged({"condition_uuid":component.get("condition_uuid","")},true)
                var accepted:bool=handle.occurrence.call(handle.clip.input_setters.actor_context,context.packet)
                if accepted:
                    handle.actor_context_bound=true;supplied.append("actor_context")
                    if departure_history(handle) and not prepare_only:
                        var held:Dictionary=seed_departure(handle,context)
                        if not held.ready:
                            if held.get("pending",false):pending.actor_context=held.reason
                            else:unavailable.actor_context=held.reason
                else:unavailable.actor_context="actor_context_not_accepted"
            elif not pending.has("actor_context"):unavailable.actor_context=context.reason
    if "history_state" in requested and departure_history(handle):
        not_applicable.history_state="non_mirror_departure_does_not_consume_duplicate_count"
    elif "history_state" in requested and rolling_history(handle):
        not_applicable.history_state="non_mirror_history_does_not_consume_duplicate_count"
    elif "history_state" in requested:
        var state:Variant=component.get("condition",{}).get("state",component.get("native_preparation_inputs",{}).get("history_state"))
        if state is Dictionary and state.get("duplicate_count")!=null:
            var packet:Dictionary={"duplicate_count":state.duplicate_count}
            if packet!=handle.get("history_state_input",{}):
                Effects.set_input(handle,"history_state",packet);handle.history_state_input=packet
            supplied.append("history_state")
        else:unavailable.history_state="duplicate_count_not_disclosed"
    if "owner_binding" in requested or "actual_owner_state" in requested:
        var owner:Dictionary=owner_packet(component,Sockets.displayed(world.visual_actors.get(actor,{})))
        for channel in ["owner_binding","actual_owner_state"]:
            if channel not in requested:continue
            if not owner.ready:unavailable[channel]=owner.reason;continue
            var value:Dictionary=owner.binding if channel=="owner_binding" else owner.value
            if value!=handle.get(channel+"_input",{}):
                Effects.set_input(handle,channel,value);handle[channel+"_input"]=value
            supplied.append(channel)
    if "item_snapshot" in requested:
        var item:Dictionary=item_packet(world,component,points.get("weapon_registration",{}))
        if item.ready:
            if item.value!=handle.get("item_snapshot_input",{}):
                Effects.set_input(handle,"item_snapshot",item.value);handle.item_snapshot_input=item.value
            supplied.append("item_snapshot")
        else:unavailable.item_snapshot=item.reason
    if "created_item_binding" in requested:
        unavailable.created_item_binding="wielded_native_bodies_not_supported"
    if "surface_records" in requested:
        # This setter is preconstruction-only in the sealed source. The exact
        # records were admitted through native_constructor_inputs before make.
        if component.has("spatial_surface_records") and component.get("spatial_owner",false):supplied.append("surface_records")
        else:unavailable.surface_records="surface_immutable_coverage_not_bound"
    if "suppressed" in requested and component.get("native_cue",{}).get("authored_suppressed")!=null:
        var authored:bool=component.native_cue.authored_suppressed
        if not handle.has("authored_suppressed_input") or handle.authored_suppressed_input!=authored:
            Effects.set_input(handle,"suppressed",authored);handle.authored_suppressed_input=authored
        supplied.append("suppressed")
    if "owner_state" in requested and component.get("spatial_owner",false) \
            and component.get("native_cue",{}).get("constructor_input",{}).get("cell_input") in ["owner_state","wall_segment","zone_geometry","owned_field","wall_geometry","partitioned_surface"]:
        var actual:Dictionary=SpatialInputs.owner_state(component,world.timeline.state,source_sample_seconds)
        if actual.ready:
            if actual.value!=handle.get("spatial_owner_state_input",{}):
                Effects.set_input(handle,"owner_state",actual.value);handle.spatial_owner_state_input=actual.value
            supplied.append("owner_state")
        else:unavailable.owner_state=actual.reason
    if "zone_geometry" in requested:
        var zone:Dictionary=SpatialInputs.zone_geometry(component,world.timeline.state)
        if zone.ready:
            if zone.value!=handle.get("zone_geometry_input",{}):
                Effects.set_input(handle,"zone_geometry",zone.value);handle.zone_geometry_input=zone.value
                handle.erase("endpoint_input_key") # Logical anchor changes invalidate source optical placement.
            supplied.append("zone_geometry")
        else:unavailable.zone_geometry=zone.reason
    if "surface_partition" in requested:
        var partition:Dictionary=component.get("spatial_surface_partition",{})
        if partition.is_empty():unavailable.surface_partition="actual_full_owner_draw_partition_not_bound"
        else:
            if partition!=handle.get("surface_partition_input",{}):
                Effects.set_input(handle,"surface_partition",partition);handle.surface_partition_input=partition
            supplied.append("surface_partition")
    if "surface_presence" in requested:
        var packet:Dictionary=SpatialInputs.presence(component,world.timeline.state)
        if packet.ready:
            if not handle.has("surface_presence_input") or handle.surface_presence_input!=packet.value:
                Effects.set_input(handle,"surface_presence",packet.value);handle.surface_presence_input=packet.value
            supplied.append("surface_presence")
        else:unavailable.surface_presence=packet.reason
    if "visual_state" in requested and component.get("native_wall",false):
        var displayed:Dictionary={}
        for id in world.visual_actors:
            if Sockets.displayed(world.visual_actors[id]):displayed[id]=world.visual_actors[id]
        var wall:Dictionary=SpatialInputs.wall_state(component,world.timeline.state,displayed)
        if wall.ready:
            if wall.packet!=handle.get("wall_visual_state_input",{}):
                Effects.set_input(handle,"visual_state",wall.packet);handle.wall_visual_state_input=wall.packet
            supplied.append("visual_state")
        else:unavailable.visual_state=wall.reason
    if "payload_state" in requested or "payload_anchor" in requested:
        var payload:Dictionary=points.get("payload",{})
        if payload.is_empty():payload=CreationInputs.payload_location(component,world.timeline.state)
        for channel in ["payload_state","payload_anchor"]:
            if channel not in requested:continue
            if not payload.ready:unavailable[channel]=payload.reason;continue
            var value:Dictionary=payload.state if channel=="payload_state" else payload.anchor
            if value!=handle.get(channel+"_input",{}):
                Effects.set_input(handle,channel,value);handle[channel+"_input"]=value
            supplied.append(channel)
    if component.get("native_quarry",false):
        var pair:Dictionary=CreationInputs.quarry_state(component.get("creation_binding",{}),world.timeline.state)
        for channel in ["owner_input","quarry_input"]:
            if channel not in requested:continue
            if not pair.ready:unavailable[channel]=pair.reason;continue
            var value:Dictionary=pair.owner if channel=="owner_input" else pair.quarry
            if value!=handle.get(channel+"_input",{}):
                Effects.set_input(handle,channel,value);handle[channel+"_input"]=value
            supplied.append(channel)
    if "surface_state" in requested:
        var packet:Dictionary=SpatialInputs.surface_state(component,world.timeline.state)
        if packet.ready:
            if packet.packet!=handle.get("surface_state_input",{}):
                Effects.set_input(handle,"surface_state",packet.packet);handle.surface_state_input=packet.packet
            supplied.append("surface_state")
        else:unavailable.surface_state=packet.reason
    if component.has("native_actor_birth") and "owner_state" in requested:
        var birth:Dictionary=ActorBirthInputs.packet(component,world.timeline.state,Sockets.displayed(world.visual_actors.get(actor,{})))
        if birth.ready:
            if handle.get("actor_birth_input",{})!=birth.value:
                Effects.set_input(handle,"owner_state",birth.value);handle.actor_birth_input=birth.value
            supplied.append("owner_state")
        else:unavailable.owner_state=birth.reason
    if component.has("native_actor_terminal") and "terminal_departure" in requested:
        var terminal:Dictionary=ActorBirthInputs.terminal_packet(component)
        if handle.get("terminal_departure_input",{})!=terminal:
            Effects.set_input(handle,"terminal_departure",terminal);handle.terminal_departure_input=terminal
        supplied.append("terminal_departure")
    if component.get("native_item",false) and not component.has("lifecycle_phases") and "owner_state" in requested:
        var equipped:bool=Weapons.equipped_source(handle)
        var age:float=maxf(0.0,float(component.age_ms) if equipped else float(world.timeline.display_ms)-float(component.start_ms))/1000.0
        var owner_state:Dictionary={"phase":"sustain","phase_age_seconds":age,"owner_age_seconds":age}
        if equipped:owner_state.source_age_seconds=float(handle.get("weapon_source_age",0.0))
        Effects.set_input(handle,"owner_state",owner_state)
        supplied.append("owner_state")
    if "owner_visibility" in requested:
        var visibility:float=float(component.get("alpha",1.0)) if Sockets.displayed(world.visual_actors.get(actor,{})) else 0.0
        if visibility!=float(handle.get("owner_visibility_input",-1.0)):
            Effects.set_input(handle,"owner_visibility",visibility);handle.owner_visibility_input=visibility
        supplied.append("owner_visibility")
    if "weapon_binding" in requested:
        var registration:Dictionary=points.get("weapon_registration",{})
        if registration.is_empty():registration=weapon_registration(world,handle,component)
        weapon=registration.weapon
        var packet:Dictionary=registration.packet
        # The finite cast names a real, causally observed actor condition.
        # Contribution is that committed application; decoration admission is
        # the current exact equipped optical surface, never a Factory default.
        if component.has("native_condition_application") and packet.ready:
            packet=packet.duplicate(false);packet.binding=packet.binding.duplicate(false)
            packet.binding.contribution_active=true
            packet.binding.decoration_admitted=bool(registration.surface.get("ready",false))
            packet.public_gaps=[]
        if "created_item_identity" in requested:
            var creation:Dictionary=CreationInputs.lifetime_packet(component,world.timeline.state,weapon)
            if creation.ready:
                packet.binding.merge(creation.weapon,true)
                if handle.get("created_item_identity_input",{})!=creation.identity:
                    Effects.set_input(handle,"created_item_identity",creation.identity)
                    handle.created_item_identity_input=creation.identity
                supplied.append("created_item_identity")
            else:
                if handle.has("created_item_identity_input"):
                    Effects.set_input(handle,"created_item_identity",{})
                    handle.erase("created_item_identity_input")
                unavailable.created_item_identity=creation.reason
        weapon_gaps=packet.public_gaps
        if requested.any(func(name):return name in ["entity_geometry","recipient_geometry"]):
            weapon_surface=receiver_surface(registration.surface,handle.root.global_transform)
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
        # Prepared conditions and the delivered equipped-sheet source have
        # different construction/clock contracts but neither consumes legacy
        # contribution flags. Keep legacy ownership consumers strict.
        var required_gaps:Array=[] if prepared or Weapons.equipped_source(handle) else weapon_gaps
        weapon_gaps=required_gaps
        if not packet.ready:unavailable.weapon_binding=packet.reason
        elif not required_gaps.is_empty():unavailable.weapon_binding="weapon_legacy_admission_not_bound:"+", ".join(required_gaps)
        else:supplied.append("weapon_binding")
    if geometry_requested.any(func(name):return name in ["entity_geometry","recipient_geometry"]):
        var channel:String="entity_geometry" if "entity_geometry" in geometry_requested else "recipient_geometry"
        surface=weapon_surface if "weapon_binding" in requested else receiver_surface(geometry_sample(world,component,channel),handle.root.global_transform)
        if component.has("native_event_state") and surface.get("region_id")=="damage_contact":surface.region_revision=surface.gpu_geometry_key
        for name in ["entity_geometry","recipient_geometry"]:
            if name in geometry_requested:
                geometry_input(handle,name,surface);supplied.append(name)
                if not surface.ready:
                    if surface.get("pending",false):pending[name]=surface.reason
                    else:unavailable[name]=surface.reason
    if "source_geometry" in geometry_requested:
        var source:Dictionary=receiver_surface(geometry_sample(world,component,"source_geometry"),handle.root.global_transform)
        geometry_input(handle,"source_geometry",source);supplied.append("source_geometry")
        if not source.ready:
            if source.get("pending",false):pending.source_geometry=source.reason
            else:unavailable.source_geometry=source.reason
    if "targets" in geometry_requested or "live_endpoints" in geometry_requested:
        # Both delivered adapters forward live_endpoints through targets. One
        # changed endpoint packet supplies both declared aliases, avoiding a
        # second source traversal and repeated body delivery on every sample.
        var packet:Dictionary=endpoint_packet(world,handle,component,points,surface)
        cell_endpoints=packet.rows
        var endpoint_key:Array=[packet.reason,packet.rows.map(func(row):return [row.get("actor_uuid",""),row.get("actor",""),row.get("socket",""),row.get("cue_point",""),row.point,row.get("view_basis"),row.get("surface",{}).get("gpu_geometry_key",[])])]
        if endpoint_key!=handle.get("endpoint_input_key",[]):
            Effects.set_input(handle,"live_endpoints" if "live_endpoints" in geometry_requested else "targets",packet.rows)
            handle.endpoint_input_key=endpoint_key
        for channel in ["targets","live_endpoints"]:
            if channel not in geometry_requested:continue
            if packet.reason.is_empty():supplied.append(channel)
            elif packet.get("pending",false):pending[channel]=packet.reason
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
    if "retirement_time" in requested:
        var descriptor:Dictionary=component.get("native_cue",{}).get("constructor_input",{})
        if not component.get("spatial_owner",false) or str(component.get("spatial_effect_uuid","")).is_empty() \
            or descriptor.get("cell_input")!="owned_cells" or not component.has("duration_ms"):
            unavailable.retirement_time="actual_spatial_owner_lifetime_not_bound"
        else:
            # Infinity denotes the absence of an observed future retirement,
            # not a duration inferred from rounds or the source's review end.
            var retirement:float=float(component.duration_ms)/1000.0
            if handle.get("retirement_time_input")!=retirement:
                Effects.set_input(handle,"retirement_time",retirement);handle.retirement_time_input=retirement
            supplied.append("retirement_time")
    if "delivery_timing" in requested:
        var timing:Vector2=Vector2(float(component.native_cue.launch),float(component.native_cue.contact)-float(component.native_cue.launch))
        # Attached sources move their own projectile. Their authored source
        # clock can differ from the compiler's gameplay contact clock (which
        # has no external flight for these cues). Preserve the declared source
        # launch/contact rather than collapsing that source's travel to zero.
        if component.native_cue.has("source_launch_local") and component.native_cue.has("source_contact_local"):
            timing=Vector2(float(component.native_cue.source_launch_local),float(component.native_cue.source_contact_local)-float(component.native_cue.source_launch_local))
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
            var descriptor:Dictionary=component.native_cue.get("owner_projection",{})
            var reason:String=""
            if not descriptor.is_empty():
                var raw:Variant=component.condition.get("state")
                var state:Dictionary=raw if raw is Dictionary else {}
                var parent_id:Variant=state.get(str(descriptor.parent_field))
                var parent:Dictionary=world.timeline.condition_owners.get(str(parent_id),{}) if parent_id!=null else {}
                if parent.is_empty():reason="condition_parent_owner_not_observed"
                elif parent.actor_uuid!=actor or parent.condition.behavior_id!=descriptor.parent_behavior_id:
                    reason="condition_parent_owner_identity_mismatch"
                elif float(parent.start_ms)>float(component.start_ms) or float(parent.end_ms)<float(component.start_ms):
                    reason="condition_parent_owner_interval_mismatch"
                else:
                    var parent_state:Variant=parent.condition.get("state")
                    projection.owner_uuid=str(parent.condition.condition_uuid)
                    projection.behavior_id=str(parent.condition.behavior_id)
                    projection.suppressed=parent_state is Dictionary and not parent_state.get("suppression_provider_uuids",[]).is_empty()
                    var end:float=minf(float(component.duration_ms),float(parent.end_ms)-float(component.start_ms))
                    projection.removed_seconds=-1.0 if is_inf(end) else end/1000.0
                    projection[str(descriptor.child_input)]={"owner_uuid":str(component.condition.condition_uuid),
                        "behavior_id":str(component.condition.behavior_id),"parent_owner_uuid":str(parent_id),"admitted":true,
                        "suppressed":not state.get("suppression_provider_uuids",[]).is_empty()}
            if reason.is_empty():
                if projection!=handle.get("owner_projection_input",{}):
                    Effects.set_input(handle,"owner_projection",projection);handle.owner_projection_input=projection
                supplied.append("owner_projection")
            else:unavailable.owner_projection=reason
    if "accepted_release" in requested:
        var release:Dictionary=CreationInputs.release_packet(component,points)
        if release.ready:
            if release.packet!=handle.get("accepted_release_input",{}):
                Effects.set_input(handle,"accepted_release",release.packet);handle.accepted_release_input=release.packet
            supplied.append("accepted_release")
        else:unavailable.accepted_release=release.reason
    if component.get("native_readiness_gate",{}).get("schema")=="vfxfactory.public_condition_readiness.v1":
        var readiness:Dictionary=readiness_packet(world,component,surface)
        if "event_binding" in requested:
            if readiness.binding!=handle.get("readiness_binding_input",{}):
                Effects.set_input(handle,"event_binding",readiness.binding);handle.readiness_binding_input=readiness.binding
            supplied.append("event_binding")
        if "event_state" in requested:
            # The public false publication clears source readiness even when
            # the optical mouth disappeared; it never needs a fake surface.
            var value:Dictionary=readiness.value if readiness.ready else {"observed":false,"ready":false}
            if value!=handle.get("readiness_state_input",{}):
                Effects.set_input(handle,"event_state",value);handle.readiness_state_input=value
            if readiness.ready:supplied.append("event_state")
            else:unavailable.event_state=readiness.reason
    if component.has("native_event_state"):
        # This is the finite result occurrence's ordinary source clock, not
        # the retained condition's age or a reconstructed gameplay cadence.
        var age:float=maxf(0.0,float(component.get("age_ms",0.0)))/1000.0
        var binding:Dictionary=component.native_event_binding.duplicate(false)
        binding.stream_generation=world.timeline.state.get("generation","")
        var event:Dictionary=component.native_event_state.duplicate(false)
        event.phase_age_seconds=age;event.owner_age_seconds=age
        if surface.get("region_id")=="damage_contact":event.contact_surface_revision=surface.region_revision
        for channel in ["event_binding","event_state","owner_state"]:
            if channel not in requested:continue
            var packet:Dictionary=binding if channel=="event_binding" else event if channel=="event_state" else {"phase":"sustain","phase_age_seconds":age,"owner_age_seconds":age}
            if channel=="event_state" and not surface.get("ready",false):
                if surface.get("pending",false):pending[channel]=surface.reason
                else:unavailable[channel]=surface.get("reason","actual_event_contact_surface_unavailable")
                continue
            if packet!=handle.get(channel+"_input",{}):
                Effects.set_input(handle,channel,packet);handle[channel+"_input"]=packet
            supplied.append(channel)
    var arguments:Dictionary=component.get("native_cue",{}).get("input_arguments",{})
    var projected_values:Dictionary=component.get("native_input_values",{})
    var argument_packets:Dictionary=handle.get("native_argument_packets",{})
    for channel in arguments:
        if channel not in requested:continue
        var values:Array=[]
        for field in arguments[channel]:
            if not projected_values.has(field):
                unavailable[channel]="source_argument_not_projected:"+str(field);break
            values.append(projected_values[field])
        if unavailable.has(channel):continue
        if values.is_empty():unavailable[channel]="source_arguments_empty";continue
        if not argument_packets.has(channel) or argument_packets[channel]!=values:
            Effects.set_input(handle,channel,values[0],values.slice(1));argument_packets[channel]=values.duplicate(true)
        supplied.append(channel)
    handle.native_argument_packets=argument_packets
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
        if name in supplied or unavailable.has(name) or pending.has(name) or not_applicable.has(name):continue
        if state.get(name)!=null:Effects.set_input(handle,name,state[name]);supplied.append(name)
        else:unavailable[name]="provider_not_bound"
    var result:Dictionary={"supplied":supplied.filter(func(name):return name in requested),"unavailable":unavailable,
        "pending":pending,"not_applicable":not_applicable,"weapon_public_gaps":weapon_gaps}
    if source_contact_seconds>=0.0:result.source_contact_seconds=source_contact_seconds
    return result

## One immutable source socket at its original private body/frame clock. This
## uses the same layer pivot/model as the displayed actor, never live idle.
static func interrupted_packets(world:Node,component:Dictionary)->Dictionary:
    var capture:Dictionary=component.get("native_counterspell",{})
    if capture.get("capture_cut")!="canonical_pre_reaction_commit":return {"ready":false,"reason":"interrupted_preparation_cut_not_bound"}
    if not capture.get("present",false):return {"ready":false,"reason":"interrupted_preparation_not_observed"}
    var row:Dictionary=capture.row.duplicate(false)
    var rig:Dictionary=capture.source_registration if capture.has("source_registration") else world.rigs.get(row.rig,{})
    if rig.is_empty():return {"ready":false,"reason":"interrupted_preparation_rig_not_prepared"}
    row.facing=str(capture.world_facing)
    var view:String=Sockets.facing(world,row)
    var choices:Array=rig.get("pose_sockets",{}).get(str(capture.socket),{}).get(str(capture.clip),{}).get(view,[])
    var frame:int=int(capture.frame)
    if frame<0 or frame>=choices.size() or choices[frame]==null:return {"ready":false,"reason":"interrupted_preparation_socket_not_authored"}
    var pixel:Variant=choices[frame]
    var shape:Dictionary=Construction.layer_shape(rig,128.0/float(world.rig_config.TILE_W)*float(row.scale))
    var units:float=float(shape.scale)/Sockets.Placement.PIXELS_PER_UNIT
    if rig.get("source_scale",1.0)!=1.0:units*=float(rig.source_scale)
    var local:Vector3=Vector3(float(pixel.x)-shape.pivot.x,shape.pivot.y-float(pixel.y),0.0)*units
    var transform:Transform3D=Construction.layer_transform(world.camera.global_basis,row,rig,capture.sample,"body",str(capture.clip),view,frame,float(world.rig_config.TILE_W),float(capture.body_scale))
    var point:Vector3=transform*local
    var observation:Dictionary=component.native_reaction_observation.duplicate(false)
    observation.merge({"phase":"completion","admitted":true,"present":true,"canceled":bool(component.native_constructor_evidence.triggered_canceled),
        "contact_seconds":0.0,"contact_world":point})
    var presentation:Dictionary={"presentation_uuid":str(capture.presentation_uuid),"source_owner_uuid":str(capture.source_owner_uuid),
        "triggered_event_uuid":str(capture.triggered_event_uuid),"triggered_lineage_uuid":str(capture.triggered_lineage_uuid),
        "source_seconds":float(capture.source_seconds),"present":true}
    return {"ready":true,"reason":"","reaction_observation":observation,"interrupted_presentation":presentation,
        "interrupted_path":{"presentation_uuid":str(capture.presentation_uuid),"samples":[{"source_seconds":float(capture.source_seconds),
            "world_transform":Transform3D(transform.basis,point)}]}}

func clear()->void:
    surfaces.clear()
    appearances.clear()
