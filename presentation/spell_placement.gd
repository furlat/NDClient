extends RefCounted
## Authored painted placement and measured optical socket registration.
const Placement=preload("res://placement.gd")
const Surfaces=preload("res://presentation/surface_sockets.gd")
const Weapons=preload("res://presentation/native_weapon_inputs.gd")

static func facing(world:Node,row:Dictionary)->String:
    var cycle:Array=world.rig_config.FACING_CYCLE
    return cycle[posmod(cycle.find(row.get("facing","SW"))+world.quarter*2,8)]

## Source live_pose.gaze consumes WORLD points and adds its declared offset in
## world space. The received anchor already includes the actual root placement.
## Its second point conveys orientation only: distance is normalized by source.
## row.facing is world-facing, before the sprite's camera-quarter row rotation.
static func display_facing_aim(row:Dictionary,cycle:Array,source_point:Vector3,live_pose:Dictionary,policy:String)->Dictionary:
    if policy!="display_facing" or live_pose.get("mode")!="gaze":return {"rows":[],"reason":"authored_endpoint_aim_not_bound"}
    var index:int=cycle.find(str(row.get("facing","")))
    var east:int=cycle.find("E")
    if index<0 or east<0:return {"rows":[],"reason":"display_facing_not_available"}
    var angle:float=float(posmod(index-east,8))*TAU/8.0-PI/4.0
    var direction:=Vector3(cos(angle),0.0,sin(angle))
    var offset:Array=live_pose.get("offset",[0.0,0.0,0.0])
    var origin:Vector3=source_point+Vector3(offset[0],offset[1],offset[2])
    return {"rows":[{"actor_uuid":str(row.id),"point":source_point},
        {"actor_uuid":str(row.id),"point":origin+direction,"optical_aim":"display_facing"}],
        "reason":"","direction":direction,"source_origin":origin}

static func projectile_point(world: Node,component: Dictionary,fraction: float) -> Vector3:
    var recipe: Dictionary=component.recipe
    var a=Vector3(component.from_position[0],component.from_elevation_feet/5.0*Placement.HEIGHT_UNIT,component.from_position[1])
    var b=Vector3(component.to_position[0],component.to_elevation_feet/5.0*Placement.HEIGHT_UNIT,component.to_position[1])
    var visual: Dictionary=world.visual_actors.get(component.actor_uuid,{})
    if not visual.is_empty():
        var row: Dictionary=visual.row.duplicate()
        var rig: Dictionary=world.rigs[row.rig]
        var delta=Vector2(component.to_position[0]-component.from_position[0],component.to_position[1]-component.from_position[1])
        if not delta.is_zero_approx():row.facing=world._facing(delta)
        var facing=facing(world,row)
        var socket: Variant=recipe.get("sourceSockets",recipe.get("sourceSocketsByRig",{}).get(row.rig,{})).get("release",{}).get(facing)
        var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
        if socket!=null:a+=Surfaces.painted_point(world,row,Vector2(socket.x,socket.y))-Placement.contact(row)
        else:a+=world.camera.basis.x*float(recipe.get("originX",0))*unit-world.camera.basis.y*float(recipe.get("originY",recipe.get("sourceAnchor",{}).get("liftY",0)))*unit
    var target: Dictionary=world.visual_actors.get(component.target_uuid,{})
    if not target.is_empty():
        var target_row=target.row.duplicate();target_row.position=component.to_position;target_row.base_height_steps=component.to_elevation_feet/5.0
        if component.kind=="geometry_projectile":
            b-=world.camera.basis.y*float(recipe.targetY)*128.0/float(world.rig_config.TILE_W)*target_row.scale/Placement.PIXELS_PER_UNIT
        else:b=socket(world,target_row,"body_center")
    var forward=(b-a).normalized()
    var unit=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
    a+=forward*float(recipe.get("sourceForwardPx",0))*unit;b-=forward*float(recipe.get("targetForwardPx",0))*unit
    var trajectory: Dictionary=recipe.get("trajectory",{})
    if trajectory.get("type")!="bezier":return a.lerp(b,fraction)
    var distance=a.distance_to(b)
    var delta=b-a
    var x=delta.dot(world.camera.basis.x);var y=delta.dot(world.camera.basis.y)
    var perpendicular=(world.camera.basis.x*-y+world.camera.basis.y*x).normalized()
    var spread=1.0
    if trajectory.get("sameTargetSpread",false) and component.get("same_target_count",1)>1:
        spread=2.0*float(component.same_target_index)/float(component.same_target_count-1)-1.0
    var control=(a+b)*.5+perpendicular*distance*trajectory.get("curvature",0.0)*spread
    return a*(1-fraction)*(1-fraction)+control*2*fraction*(1-fraction)+b*fraction*fraction

static func socket(world: Node,row: Dictionary,socket: String) -> Vector3:
    var base=Placement.contact(row)
    if not row.has("rig"): return base
    var rig: Dictionary=world.rigs[row.rig]
    var playback: Node=world.playbacks.get(row.id)
    var clip: String=playback.clip if playback!=null else "Idle"
    var frame=mini(int((playback.sample_seconds if playback!=null else 0.0)*rig.clips[clip].fps),int(rig.clips[clip].frames)-1)
    var points: Array=rig.get("pose_sockets",{}).get(socket,{}).get(clip,{}).get(facing(world,row),[])
    var point: Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else null
    if point==null: point=rig.get("body_anchor") if socket=="body_center" else null
    if point==null: return base
    return Surfaces.painted_point(world,row,Vector2(point.x,point.y))

static func has_socket(world: Node,row: Dictionary,socket: String) -> bool:
    var rig: Dictionary=world.rigs[row.rig]
    var playback: Node=world.playbacks.get(row.id)
    var clip: String=playback.clip if playback!=null else "Idle"
    var points: Array=rig.get("pose_sockets",{}).get(socket,{}).get(clip,{}).get(facing(world,row),[])
    if points.is_empty():return false
    var frame=mini(int((playback.sample_seconds if playback!=null else 0.0)*rig.clips[clip].fps),int(rig.clips[clip].frames)-1)
    return points[mini(frame,points.size()-1)]!=null

static func endpoints(world:Node,component:Dictionary,fixed:Dictionary={},preparing:bool=true,weapon_registration:Dictionary={})->Dictionary:
    var cue:Dictionary=component.native_cue
    var persistent:bool=component.get("persistent_owner",false)
    var source:Dictionary=world.visual_actors.get(component.get("actor_uuid"),{})
    var target:Dictionary=world.visual_actors.get(component.get("target_uuid"),{})
    var role:String=cue.role
    var attachment:String=cue.get("attachment","")
    if component.get("native_weapon_impact",false) and component.has("impact"):
        var receipt:Dictionary=component.impact
        if receipt.status!="available":return {"ready":false,"unavailable":true,"reason":receipt.get("reason","weapon_impact_contact_not_resolved")}
        var from:Vector3=Vector3(component.from_position[0],float(component.from_elevation_feet)/5.0*Placement.HEIGHT_UNIT,component.from_position[1])
        var ground:Vector3=Vector3(receipt.position[0],float(receipt.elevation_feet)/5.0*Placement.HEIGHT_UNIT,receipt.position[1])
        return {"ready":true,"from":from,"hand":from,"to":receipt.world_anchor,"ground":ground,"caster_ground":from,"fixed":{},"surfaces":[]}
    # Only explicitly authored departure owners may register without a live
    # recipient. Their immutable original support replaces no canonical row.
    if persistent and component.get("recipe",{}).get("persistent",{}).get("actorHistory",{}).get("captureDeparture",false):
        var capture:Dictionary=component.get("logical_pose",{})
        if capture.get("actor_uuid")!=component.get("target_uuid") or capture.get("condition_uuid")!=component.get("condition_uuid") or not capture.has("departure"):
            return {"ready":false,"unavailable":true,"reason":"condition_original_departure_not_observed"}
        if not str(capture.departure.get("reason","")).is_empty():return {"ready":false,"unavailable":true,"reason":capture.departure.reason}
        if attachment!="recipient_ground" or cue.get("anchor")!="ground":return {"ready":false,"unavailable":true,"reason":"departure_registration_not_authored"}
        var ground:Vector3=Placement.contact(capture.departure.row)
        return {"ready":true,"from":ground,"hand":ground,"to":ground,"ground":ground,"caster_ground":ground,"surfaces":[],"fixed":{}}
    # These registrations need actual head/equipment ownership. Never fall
    # through to an unrelated ground/body point or a missing transform key.
    if attachment=="item":
        if component.get("native_item",false):
            var attached:Dictionary=component.duplicate(false);attached.native_cue=cue.duplicate(false);attached.native_cue.attachment="recipient_weapon"
            return endpoints(world,attached,fixed,preparing,weapon_registration)
        return {"ready":false,"unavailable":true,"reason":"native_item_registration_not_bound"}
    if attachment=="recipient_weapon":
        if not weapon_registration.is_empty():
            if not weapon_registration.ready:return weapon_registration
            var resolved:Dictionary=weapon_registration.weapon
            var ground:Vector3=Placement.contact(world.visual_actors[resolved.actor].row)
            var known:Dictionary=weapon_registration.hand
            var optical:Vector3=known.point if known.get("ready",false) else weapon_registration.optical_anchor
            var result:Dictionary={"ready":true,"from":optical,"to":optical,"ground":ground,"caster_ground":ground,
                "surfaces":[known] if known.get("ready",false) else [],"fixed":{},"item_uuid":resolved.item_uuid,
                "holder_uuid":resolved.actor,"equipment_slot":resolved.equipment_slot,"weapon_registration":weapon_registration}
            if known.get("ready",false):result.hand=known.point
            else:result.optical_anchor=optical
            return result
        var weapon:Dictionary=Weapons.resolve(world,component)
        if not weapon.ready:return {"ready":false,"unavailable":true,"reason":weapon.reason}
        if weapon.render_slot!="weapon":return {"ready":false,"unavailable":true,"reason":"weapon_offhand_socket_not_authored"}
        var received:Dictionary=pose_point(world,world.visual_actors[weapon.actor].row,"hand")
        if not received.ready:
            # A pose without authored grip registration is a recoverable
            # presentation gap. Actual asynchronous source admission remains
            # pending; neither case authorizes a substitute socket or point.
            if not received.get("pending",false):received.unavailable=true
            return received
        var ground:Vector3=Placement.contact(world.visual_actors[weapon.actor].row)
        return {"ready":true,"from":received.point,"hand":received.point,"to":received.point,"ground":ground,"caster_ground":ground,
            "surfaces":[received],"fixed":{},"item_uuid":weapon.item_uuid,"holder_uuid":weapon.actor,"equipment_slot":weapon.equipment_slot}
    if attachment=="recipient_head" and (target.is_empty() or not has_socket(world,target.row,"head")):
        return {"ready":false,"unavailable":true,"reason":"native_head_registration_not_bound"}
    var source_socket:String=str(cue.get("source_socket",""))
    var needs_hand:bool=source_socket.is_empty() and (role in ["cast","flight","spray"] or attachment in ["caster_hand","caster_release"])
    var hand_endpoint:Dictionary={}
    for endpoint in cue.get("live_endpoints",[]):
        if endpoint.get("actor")=="caster" and endpoint.get("socket") in ["hand","cast_hand"]:
            needs_hand=true;hand_endpoint=endpoint;break
    var needs_body:bool=not component.get("ground_target",false) and (role in ["flight","impact","strike"] or attachment in ["recipient_body","recipient_head"])
    if (needs_hand or not source_socket.is_empty()) and not displayed(source):return {"ready":false,"unavailable":true,"reason":"native_spell_actor_not_displayed"}
    if (needs_body or persistent and not component.get("spatial_owner",false)) and not displayed(target):return {"ready":false,"unavailable":true,"reason":"native_spell_recipient_not_displayed"}
    var from_position:Array=component.get("from_position",[0,0])
    var to_position:Array=component.get("to_position",from_position)
    var row:Dictionary=source.get("row",{}).duplicate()
    row.position=from_position;row.base_height_steps=float(component.get("from_elevation_feet",0))/5.0
    var target_row:Dictionary=target.get("row",{}).duplicate()
    if not persistent:
        target_row.position=to_position;target_row.base_height_steps=float(component.get("to_elevation_feet",0))/5.0
    elif target_row.is_empty():
        target_row.position=to_position;target_row.base_height_steps=float(component.get("to_elevation_feet",0))/5.0
    var direction=Vector2(to_position[0]-from_position[0],to_position[1]-from_position[1])
    var geometry:Dictionary=component.get("area_geometry",{})
    if geometry.get("direction")!=null:direction=Vector2(geometry.direction[0],geometry.direction[1])
    if source_socket.is_empty() and not direction.is_zero_approx():row.facing=world._facing(direction)
    var released:Dictionary={"ready":true,"point":Placement.contact(row)}
    var hand:Dictionary=released
    if not source_socket.is_empty():
        released=fixed.get("release",{})
        if released.is_empty():released=pose_point(world,row,source_socket)
        if not released.ready:return released
        hand=released
    elif needs_hand:
        var cast:Dictionary=component.get("cast_recipe",{})
        if cast.get("enabled",true):
            var view:String=facing(world,row)
            released=fixed.get("release",{})
            if released.is_empty():released=cast_point(world,component,"release",int(cast.get("releaseFrame",0)),view)
            if not released.ready:return released
            hand=released
            var playback:Node=world.playbacks.get(component.actor_uuid)
            if preparing and playback!=null and playback.clip==cast.get("actionClip",""):
                var rig:Dictionary=world.rigs[row.rig]
                var frame=clampi(int(playback.sample_seconds*float(rig.clips[playback.clip].fps)),0,int(rig.clips[playback.clip].frames)-1)
                hand=cast_point(world,component,"preparation",frame,view)
                if not hand.ready:return hand
        else:
            # Weapon-backed spells use the real attack pose, not a fabricated
            # second casting action (e.g. True Strike).
            released=pose_point(world,source.row,"hand",hand_endpoint.get("pose_socket_by_clip",{}));hand=released
            if not released.ready:return released
    var received:Dictionary={"ready":true,"point":Placement.contact(target_row)}
    if needs_body:
        if not persistent:
            target_row.facing=world._facing(-direction) if not direction.is_zero_approx() else "SW"
            received=fixed.get("target",{})
            if received.is_empty():received=body_anchor(world,target_row)
        else:
            # A condition registers at its declared socket (a marker at the
            # head); rigs without that socket use their body centre.
            var anchor:String="head" if attachment=="recipient_head" else str(cue.get("anchor","body_center"))
            if not world.rigs[target_row.rig].get("pose_sockets",{}).has(anchor):anchor="body_center"
            received=pose_point(world,target_row,anchor)
        if not received.ready:return received
    if not needs_body and not direction.is_zero_approx() and received.point.is_equal_approx(released.point):
        # Facing-only effects (cones) anchor at the real origin but orient along
        # the disclosed area direction, independently of their world position.
        received=received.duplicate();received.point+=Vector3(direction.x,0,direction.y)
    return {"ready":true,"from":released.point,"hand":hand.point,"to":received.point,
        "ground":Placement.contact(target_row),"caster_ground":Placement.contact(row),
        "surfaces":[released,hand,received],"fixed":{"release":released,"target":received}}

static func cast_point(world:Node,component:Dictionary,key:String,frame:int,view:String)->Dictionary:
    var visual:Dictionary=world.visual_actors.get(component.actor_uuid,{})
    if visual.is_empty():return {"ready":false,"unavailable":true,"reason":"native_spell_actor_not_displayed"}
    var row:Dictionary=visual.row
    var rig:Dictionary=world.rigs[row.rig]
    var cast:Dictionary=component.cast_recipe
    var clip:String=cast.get("actionClip","")
    if not rig.clips.has(clip):return {"ready":false,"reason":"native_spell_cast_clip_missing"}
    var sockets:Dictionary=component.recipe.get("sourceSockets",component.recipe.get("sourceSocketsByRig",{}).get(row.rig,{}))
    var sources:Array=sockets.get("sources",[])
    # A BodyUse selects the cast clip/release frame; its canonical cast hand
    # is the rig's authored hand channel at that pose. Older spell recipes may
    # instead register measured/multiple sockets and retain that exact choice.
    # An explicit but incomplete registration must not silently select a hand.
    if not component.recipe.has("sourceSockets") and not component.recipe.has("sourceSocketsByRig"):
        sources=["hand"]
    var pixels:Array=[]
    if sources.is_empty():
        var choices:Variant=sockets.get(key,{}).get(view)
        var point:Variant=null
        if choices is Array:
            if frame>=0 and frame<choices.size():point=choices[frame]
        elif key=="release":point=choices
        if point==null:return {"ready":false,"reason":"native_spell_"+key+"_socket_missing"}
        pixels.append(point)
    else:
        for name in sources:
            var choices:Array=rig.get("pose_sockets",{}).get(name,{}).get(clip,{}).get(view,[])
            if frame<0 or frame>=choices.size() or choices[frame]==null:return {"ready":false,"reason":"native_spell_"+key+"_socket_missing"}
            pixels.append(choices[frame])
    var position:=Vector3.ZERO
    var qualifications:Array=[]
    for point in pixels:
        var placed=component.duplicate(false)
        if component.get("aim_position")!=null:placed.to_position=component.aim_position
        placed.recipe=component.recipe.duplicate(false)
        placed.recipe.sourceSockets={"release":{view:point}}
        var painted=projectile_point(world,placed,0.0)
        var surface=Surfaces.resolve(world,component.actor_uuid,clip,frame,view,Vector2(point.x,point.y),painted,["weapon","offhand"] if cast.get("equipment",{}).get("kind")=="hidden" else [])
        if str(surface.reason).ends_with("not_prepared"):
            return {"ready":false,"pending":true,"reason":"native_spell_"+surface.reason}
        position+=surface.point;qualifications.append(surface)
    position/=pixels.size()
    if not sources.is_empty():
        var forward=Vector3(component.to_position[0]-component.from_position[0],0,component.to_position[1]-component.from_position[1]).normalized()
        var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
        position+=forward*float(sockets.get("forwardPixels",0.0))*unit
    return {"ready":true,"point":position,"surfaces":qualifications,"clip":clip,"frame":frame,"facing":view}

static func pose_point(world:Node,row:Dictionary,name:String,by_clip:Dictionary={})->Dictionary:
    var rig:Dictionary=world.rigs[row.rig]
    var playback:Node=world.playbacks.get(row.id)
    var clip:String=playback.clip if playback!=null else "Idle"
    var frame=mini(int((playback.sample_seconds if playback!=null else 0.0)*float(rig.clips[clip].fps)),int(rig.clips[clip].frames)-1)
    var view=facing(world,row)
    var selected:String=str(by_clip.get(clip,name))
    var choices:Array=rig.get("pose_sockets",{}).get(selected,{}).get(clip,{}).get(view,[])
    var point:Variant=choices[mini(frame,choices.size()-1)] if not choices.is_empty() else rig.get("body_anchor") if selected=="body_center" else null
    if point==null:return {"ready":false,"reason":"native_spell_"+selected+"_socket_missing"}
    var surface=Surfaces.resolve(world,row.id,clip,frame,view,Vector2(point.x,point.y),socket(world,row,selected))
    if str(surface.reason).ends_with("not_prepared"):
        return {"ready":false,"pending":true,"reason":"native_spell_"+surface.reason}
    var result={"ready":true,"point":surface.point,"surface":surface,"clip":clip,"frame":frame,"facing":view}
    if selected!=name:result.pose_socket=selected
    return result

static func displayed(visual:Dictionary)->bool:
    if visual.is_empty() or not visual.get("valid",false):return false
    for entry in visual.get("entries",[]):
        if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
        if is_instance_valid(entry.node) and entry.node.is_visible_in_tree():return true
    return false

static func body_anchor(world:Node,row:Dictionary)->Dictionary:
    # The compiler admits this fixed recipient position. Without a separately
    # authored contact pose, the stable rig anchor uses Idle/frame0 optical
    # registration; sampling a recovered live pose would make seeking drift.
    var rig:Dictionary=world.rigs[row.rig]
    var point:Variant=rig.get("body_anchor")
    if point==null or not rig.clips.has("Idle"):
        return {"ready":false,"reason":"native_spell_body_anchor_missing"}
    var view:String=facing(world,row)
    var painted:Vector3=Surfaces.painted_point(world,row,Vector2(point.x,point.y))
    var surface=Surfaces.resolve(world,row.id,"Idle",0,view,Vector2(point.x,point.y),painted)
    if str(surface.reason).ends_with("not_prepared"):
        return {"ready":false,"pending":true,"reason":"native_spell_"+surface.reason}
    return {"ready":true,"point":surface.point,"surface":surface,"clip":"Idle","frame":0,"facing":view,
        "source":"catalog/rigs.json:/"+str(row.rig)+"/body_anchor","reference_pose":"Idle/frame0"}
