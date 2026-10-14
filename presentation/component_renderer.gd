extends RefCounted
const NativePreview=preload("res://presentation/native_effect_preview.gd")
const Placement=preload("res://placement.gd")
const RegisteredMedia=preload("res://presentation/registered_media.gd")
const MediaShader=preload("res://presentation/registered_media.gdshader")
const AudioPresenter=preload("res://presentation/audio_presenter.gd")
const NativeSources=preload("res://presentation/native_effects.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Components=preload("res://presentation/components.gd")
const ConditionOutline=preload("res://presentation/condition_outline.gd")
const BoltShader=preload("res://presentation/geometry_projectile.gdshader")
const BloodRenderer=preload("res://presentation/blood_renderer.gd")
var blood=BloodRenderer.new()
var outlines=ConditionOutline.new()
var audio=AudioPresenter.new()
var handles: Dictionary={}
var numbers: Dictionary={}
var media_handles: Dictionary={}
var epoch=-1
var ready=true
var prepared_groups: Dictionary={}
var pending_evidence: Array=[]

func ensure_epoch(world: Node) -> void:
    if epoch!=world.timeline.initialization_revision:
        close(world);epoch=world.timeline.initialization_revision

func prepare(groups: Array,cache: Dictionary,world: Node=null) -> Dictionary:
    var sources: Array=[]
    for group in groups:
        if group.is_empty() or is_same(prepared_groups.get(group.get("id")),group):continue
        audio.prepare(group.get("components",[]))
        for component in group.get("components",[]):
            if component.kind=="native_effect" and component.status=="available" and component.source_id not in sources:sources.append(component.source_id)
    var result=NativeSources.prepare(sources,cache)
    if result.ready:
        for group in groups:
            if not group.is_empty():prepared_groups[group.id]=group
        while prepared_groups.size()>32:prepared_groups.erase(prepared_groups.keys()[0])
    if world!=null:result.ready=blood.prepare(world,groups) and result.ready
    return result

func sample(world: Node, samples: Array,frame_seconds: float=1.0/60.0) -> void:
    ensure_epoch(world)
    ready=true
    blood.sample(world,samples)
    ready=blood.ready
    var live_media={}
    var sounds: Array=[]
    var alive={}
    var live_numbers={}
    for actor_id in world.visual_actors:
        if not outlines.sample(world,actor_id,Conditions.material(actor_id,samples)):ready=false
    for actor_id in outlines.owners.keys():
        if not world.visual_actors.has(actor_id):outlines.erase(world,actor_id)
    for component in samples:
        if component.kind=="residue_deposit":
            _witness(world,component,blood.visible_deposit(component));continue
        if component.get("status")=="missing": continue
        if component.kind=="audio":
            sounds.append(_audio_attachment(world,component));continue
        var actor: Dictionary=world.visual_actors.get(component.get("actor_uuid"),{})
        var fixed_ground=component.get("attachment")=="ground" and component.get("position")!=null
        var fixed_impact=component.get("attachment")=="impact" and component.get("impact",{}).get("status")=="available"
        if actor.is_empty() and not fixed_ground and not fixed_impact: continue
        var row: Dictionary=actor.get("row",{})
        if fixed_impact and actor.is_empty():row={"id":component.id,"position":component.impact.position,"base_height_steps":component.impact.elevation_feet/5.0,"kind":"effect","facing":"SW"}
        if fixed_ground:
            row={"id":component.id,"position":component.position,"base_height_steps":component.get("elevation_feet",0)/5.0,"kind":"effect","facing":"SW"}
            var tile: Dictionary=world.timeline.presentation_state().tiles.get("%d,%d" % component.position,{})
            if tile.is_empty(): continue
        var origin=Placement.contact(row)
        if component.kind=="native_effect":
            alive[component.id]=true
            if not handles.has(component.id):
                var presenter=NativePreview.new(); world.add_child(presenter)
                var issue=presenter.configure(component.source_id,world.catalog_cache,Components.effect_seed(component),component.get("palette",[]))
                if not issue.is_empty():
                    world.presentation_errors.append(issue); presenter.queue_free(); continue
                issue=presenter.bind_receiving(world.source_lighting)
                if not issue.is_empty():world.presentation_errors.append(issue);presenter.close();presenter.queue_free();continue
                var placement=row.duplicate(); placement.id=component.id
                var draws=presenter.draw_entries(component.id,placement,-10,100)
                world.actor_entries.append_array(draws)
                handles[component.id]={"node":presenter,"draws":draws,"placement":placement,"component":component}
                world.draw_order_dirty=true
            var handle: Dictionary=handles[component.id]
            handle.placement.position=row.position
            handle.placement.base_height_steps=row.base_height_steps
            var attach: String=component.get("attachment","body")
            if attach=="projectile":
                var fraction=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
                var a=component.from_position;var b=component.to_position
                var point=[lerpf(a[0],b[0],fraction),lerpf(a[1],b[1],fraction)]
                var height=lerpf(component.from_elevation_feet,component.to_elevation_feet,fraction)/5.0
                handle.placement.position=point;handle.placement.base_height_steps=height
                origin=_projectile_point(world,component,fraction)
            elif attach=="target_body":
                var target: Dictionary=world.visual_actors.get(component.get("target_uuid"),{})
                if not target.is_empty():
                    handle.placement.position=target.row.position;handle.placement.base_height_steps=target.row.base_height_steps
                    origin=_socket(world,target.row,"body_center")
            elif attach=="ground" and component.get("position")!=null:
                handle.placement.position=component.position
                origin=Placement.contact(handle.placement)
            elif attach=="impact":origin=component.impact.world_anchor
            elif attach=="body":origin+=Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT
            elif attach in ["body_center","head","face","hand"]:origin=_socket(world,row,attach)
            var opacity: float=component.get("alpha",1)
            var fade=minf(1,component.age_ms/component.fade_in_ms) if component.get("fade_in_ms",0)>0 else 1.0
            if component.get("fade_out_ms",0)>0:fade=minf(fade,(component.duration_ms-component.age_ms)/component.fade_out_ms)
            if component.get("fade_curve")=="smoothstep":fade=smoothstep(0,1,fade)
            handle.node.set_opacity(opacity*clampf(fade,0,1))
            var age: float=NativeSources.source_age_ms(component,component.age_ms)
            var source_scale: float=component.get("scale",1)
            if component.has("condition_uuid"):source_scale*=row.scale*128.0/float(world.rig_config.TILE_W)
            if handle.node.record.get("actor_partition",false):
                var partition_error=handle.node.bind_actor_partition(Placement.contact(row),world.camera.global_basis,origin,source_scale)
                if not partition_error.is_empty():
                    ready=false
                    if partition_error not in world.presentation_errors:world.presentation_errors.append(partition_error)
                    continue
            var context=_receiving_context(world,handle.node.record,component,origin,source_scale)
            if component.has("weapon_pose"):
                var weapon=NativeSources.weapon_context(component,row,world.rigs[row.rig],world.rig_config.FACING_CYCLE,world.quarter)
                if not weapon.error.is_empty():
                    ready=false
                    if weapon.error not in world.presentation_errors:world.presentation_errors.append(weapon.error)
                    continue
                context.merge(weapon.context)
            context.native_frame_seconds=frame_seconds
            context.native_continuous=not world.timeline.paused and not world.timeline.waiting_for_media and not world.timeline.waiting_for_world
            var history: Array=[]
            if attach=="projectile":
                if handle.get("history_quarter",-1)!=world.quarter:
                    handle.anchor=_projectile_point(world,component,0)
                    handle.history=[]
                    var duration: float=component.duration_ms/1000.0
                    for index in ceili(duration*60)+1:
                        var at=minf(index/60.0,duration)
                        var point=_projectile_point(world,component,at/maxf(.001,duration))
                        handle.history.append({"age_seconds":at,"transform":Transform3D(Basis.IDENTITY,(point-handle.anchor)/source_scale)})
                    handle.history_quarter=world.quarter
                history=handle.history
                context.native_transform=Transform3D(Basis.IDENTITY,(origin-handle.anchor)/source_scale)
                origin=handle.anchor
            var result=handle.node.sample(age/1000.0,world.camera.global_basis,origin,source_scale,history,context)
            ready=ready and result.ready
            _witness(world,component,handle.node.sampled_age>=0 and handle.draws.any(func(draw):return _entry_visible(world,draw)))
            if not result.get("error","").is_empty() and result.error not in world.presentation_errors: world.presentation_errors.append(result.error)
        elif component.kind=="registered_media":
            if not row.has("rig"): continue
            var canonical: Dictionary=world.timeline.presentation_state().actors.get(component.actor_uuid,{})
            if canonical.get("life_state","alive") not in component.layer.get("lifeStates",["alive","dying","stable","dead"]): continue
            var facing=_facing(world,row)
            if component.metadata.has("world_basis"):
                var basis_row=row.duplicate();basis_row.facing=component.metadata.world_basis;facing=_facing(world,basis_row)
            var phases:Array=component.get("media_samples",[{"part_id":"sustain","media":component.media,"source_age_ms":component.get("source_age_ms",component.age_ms),"alpha":component.alpha}])
            var origin_point=origin
            if component.attachment=="body":origin_point+=Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT
            elif component.attachment in ["head","face","hand"]:
                if not _has_socket(world,row,component.attachment):continue
                origin_point=_socket(world,row,component.attachment)
            var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
            if component.attachment in ["head","face","hand"]: origin_point+=world.camera.basis.y*float(component.metadata.get("actor_top_clearance_px",0))*unit
            origin_point+=(world.camera.basis.x*float(component.layer.get("offsetX",0))*row.get("scale_x",1.0)-world.camera.basis.y*float(component.layer.get("offsetY",0)))*unit
            var scale=float(component.metadata.get("scale",.5))
            var drawn=false
            for phase in phases:
                if phase.media.status!="available":
                    ready=false
                    var issue="Missing condition phase registration: "+str(phase.media.get("asset_id",""))
                    if issue not in world.presentation_errors:world.presentation_errors.append(issue)
                    continue
                var parts=RegisteredMedia.sample(phase.media,phase.source_age_ms,facing)
                var definition:Dictionary=phase.media.definition
                for i in parts.size():
                    var part: Dictionary=parts[i]
                    var id: String=component.id+":"+str(phase.part_id)+":"+str(i);live_media[id]=true
                    if not world.textures.has(part.file): ready=false;continue
                    if not media_handles.has(id):
                        var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                        var material=ShaderMaterial.new();material.shader=MediaShader;node.material_override=material;world.add_child(node)
                        var entry={"id":id,"node":node,"material":material,"placement":row,"role":"native_effect","layer":-10 if component.layer.get("drawOrder")=="behind_body" else 101}
                        media_handles[id]=entry;world.actor_entries.append(entry);world.draw_order_dirty=true
                    var entry: Dictionary=media_handles[id]
                    entry.placement=row
                    var rect: Array=part.rect
                    var texture: Texture2D=world.textures[part.file]
                    entry.material.set_shader_parameter("sheet",texture)
                    entry.material.set_shader_parameter("frame_uv",Vector4(rect[0]/texture.get_width(),rect[1]/texture.get_height(),rect[2]/texture.get_width(),rect[3]/texture.get_height()))
                    entry.material.set_shader_parameter("opacity",phase.alpha)
                    entry.node.mesh.size=Vector2(rect[2],rect[3])*unit*scale
                    var center=Vector2(part.offset[0]+rect[2]*.5-definition.anchor.x*definition.frame.width,part.offset[1]+rect[3]*.5-definition.anchor.y*definition.frame.height)
                    entry.node.basis=world.camera.basis
                    entry.node.position=origin_point+(world.camera.basis.x*center.x-world.camera.basis.y*center.y)*unit*scale
                    entry.screen_rect=Rect2(world.camera.unproject_position(entry.node.position),Vector2(rect[2],rect[3]))
                    if _entry_visible(world,entry):drawn=true
            _witness(world,component,drawn)
        elif component.kind=="geometry_projectile":
            live_media[component.id]=true
            if not media_handles.has(component.id):
                var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var material=ShaderMaterial.new();material.shader=BoltShader;node.material_override=material;world.add_child(node)
                var entry={"id":component.id,"node":node,"material":material,"placement":row.duplicate(),"role":"native_effect","layer":100}
                media_handles[component.id]=entry;world.actor_entries.append(entry);world.draw_order_dirty=true
            var entry: Dictionary=media_handles[component.id]
            var a=_projectile_point(world,component,0);var b=_projectile_point(world,component,1)
            var fraction=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
            var point=a.lerp(b,fraction);var forward=(b-a).normalized()
            var x=forward.dot(world.camera.basis.x);var y=forward.dot(world.camera.basis.y)
            var tangent=(world.camera.basis.x*x+world.camera.basis.y*y).normalized()
            if tangent.is_zero_approx():tangent=world.camera.basis.x
            var unit=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
            var length_px=minf(component.style.maximumLengthPx,Vector2((b-a).dot(world.camera.basis.x),(b-a).dot(world.camera.basis.y)).length()/unit*component.style.distanceLengthRatio)
            var extent=Vector2(length_px+component.style.headRadiusPx*2+2,maxf(component.style.headRadiusPx*2,component.style.strokeWidthPx)+2)
            entry.node.mesh.size=extent*unit
            entry.node.basis=Basis(tangent,world.camera.basis.z.cross(tangent),world.camera.basis.z)
            entry.node.position=point-tangent*(extent.x*.5-component.style.headRadiusPx-1)*unit
            entry.placement.position=[lerpf(component.from_position[0],component.to_position[0],fraction),lerpf(component.from_position[1],component.to_position[1],fraction)]
            entry.placement.base_height_steps=lerpf(component.from_elevation_feet,component.to_elevation_feet,fraction)/5.0
            entry.material.set_shader_parameter("extent",extent);entry.material.set_shader_parameter("length_px",length_px)
            for field in [["stroke_width","strokeWidthPx"],["stroke_alpha","strokeAlpha"],["head_radius","headRadiusPx"],["head_alpha","headAlpha"]]:entry.material.set_shader_parameter(field[0],component.style[field[1]])
            entry.material.set_shader_parameter("stroke_colour",Color.hex(int(component.colors.secondary)*256+255));entry.material.set_shader_parameter("head_colour",Color.hex(int(component.colors.primary)*256+255))
            _witness(world,component,_entry_visible(world,entry))
        elif component.kind in ["damage_number","feedback_text"]:
            live_numbers[component.id]=true
            if not numbers.has(component.id):
                var label=Label3D.new();label.text=component.text;label.font_size=component.style.fontSizePx
                label.pixel_size=128.0/float(world.rig_config.TILE_W)/Placement.PIXELS_PER_UNIT
                var font=SystemFont.new();font.font_names=PackedStringArray([component.style.fontFamily]);font.font_weight=700;label.font=font
                label.outline_size=component.style.strokeWidthPx;label.outline_modulate=Color.hex(int(component.style.strokeColor)*256+255)
                label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.modulate=Color.hex(int(component.color)*256+255)
                # Feedback is a foreground overlay; depth-disabled sprites still
                # participate in the transparent pass and can otherwise cover it.
                label.render_priority=127;label.outline_render_priority=126
                world.add_child(label);numbers[component.id]=label
            var progress=clampf(component.age_ms/maxf(.001,component.duration_ms),0,1)
            var rig: Dictionary=world.rigs[row.rig]
            var lift=(component.style.anchorLiftPx-rig.origin_y_from_ground)*row.scale+component.style.risePx*progress+component.style.fontSizePx*.5
            numbers[component.id].position=origin+world.camera.basis.y*lift*numbers[component.id].pixel_size
            numbers[component.id].modulate.a=clampf((1-progress)/maxf(.001,1.0-component.style.fadeStartFraction),0,1)
            _witness(world,component,not world.camera.is_position_behind(numbers[component.id].global_position) and world.get_viewport().get_visible_rect().has_point(world.camera.unproject_position(numbers[component.id].global_position)))
        elif component.kind=="material_flash": _witness(world,component,_actor_visible(world,component.actor_uuid))
    for id in handles.keys():
        if not alive.has(id): _release(world,id)
    for id in numbers.keys():
        if not live_numbers.has(id): numbers[id].queue_free(); numbers.erase(id)
    for id in media_handles.keys():
        if not live_media.has(id):
            world.actor_entries.erase(media_handles[id]);media_handles[id].node.queue_free();media_handles.erase(id);world.draw_order_dirty=true
    audio.prepare(sounds)
    audio.sample(world,sounds,world.timeline.display_ms,world.playback_speed,world.timeline.paused or world.timeline.waiting_for_media or world.timeline.waiting_for_world,epoch)
    for voice in audio.voices.values():
        if voice.started and not voice.paused:_witness(world,voice.row,true)
    for id in world.visual_actors:
        if _actor_visible(world,id):_condition_witnesses(world,id,samples)

static func _audio_attachment(world: Node, component: Dictionary) -> Dictionary:
    var sound=component.duplicate()
    var attachment:String=component.get("attachment","body")
    if attachment=="ui":return sound
    if attachment=="screen" and component.has("screen_position"):return sound
    if component.has("world_position"):return sound
    if attachment=="impact" and component.get("impact",{}).get("status")=="available":
        sound.world_position=component.impact.world_anchor;return sound
    if attachment in ["ground","world"] and component.get("position")!=null:
        sound.world_position=Placement.contact({"position":component.position,"base_height_steps":component.get("elevation_feet",0)/5.0});return sound
    var actor_id:String=component.get("target_uuid",component.get("actor_uuid","")) if attachment=="target_body" else component.get("actor_uuid","")
    var actor:Dictionary=world.visual_actors.get(actor_id,{})
    if actor.is_empty():
        sound.attachment_error="attachment_unavailable";return sound
    var row:Dictionary=actor.row
    if attachment=="ground":sound.world_position=Placement.contact(row)
    elif attachment in ["body","body_center","target_body"]:sound.world_position=_socket(world,row,"body_center")
    elif attachment in ["head","face","hand","weapon"]:
        var socket="hand" if attachment=="weapon" else attachment
        if row.has("rig") and _has_socket(world,row,socket):sound.world_position=_socket(world,row,socket)
        else:sound.attachment_error="attachment_socket_unavailable"
    elif attachment=="screen":sound.screen_position=world.camera.unproject_position(_socket(world,row,"body_center"))
    else:sound.attachment_error="attachment_unsupported"
    return sound

static func _facing(world: Node,row: Dictionary) -> String:
    var cycle: Array=world.rig_config.FACING_CYCLE
    return cycle[posmod(cycle.find(row.get("facing","SW"))+world.quarter*2,8)]

static func _receiving_context(world: Node,record: Dictionary,component: Dictionary,origin: Vector3,scale: float) -> Dictionary:
    var projected: Vector2=world.camera.unproject_position(origin)
    var pixel_scale=projected.distance_to(world.camera.unproject_position(origin+world.camera.basis.x))*scale/float(record.pixels_per_unit)
    var context={"screen_origin":projected-Vector2(record.pivot[0],record.pivot[1])*pixel_scale,"pixel_scale":pixel_scale,
        "light_cap":1.0 if world.light_cap_enabled else 0.0,"supports":[],"source_basis":Basis.IDENTITY}
    if component.get("direction_from")!=null and component.get("direction_to")!=null:
        var a=component.direction_from;var b=component.direction_to
        var direction=Vector3(b[0]-a[0],0,b[1]-a[1])
        if not direction.is_zero_approx():context.source_basis=Basis.looking_at(direction.normalized(),Vector3.UP)
    if "depth_receiver" in record.get("requirements",[]):
        var tiles: Dictionary=world.timeline.presentation_state().tiles
        for x in range(floori(origin.x)-1,floori(origin.x)+2):
            for y in range(floori(origin.z)-1,floori(origin.z)+2):
                var tile: Dictionary=tiles.get("%d,%d" % [x,y],{})
                if not tile.has("elevation_steps"):continue
                var contact=Vector3(x,float(tile.elevation_steps)*Placement.HEIGHT_UNIT,y)
                context.supports.append(Transform3D(Basis.from_scale(Vector3.ONE/maxf(.001,scale)),(contact-origin)/maxf(.001,scale)))
    return context

static func _projectile_point(world: Node,component: Dictionary,fraction: float) -> Vector3:
    var recipe: Dictionary=component.recipe
    var a=Vector3(component.from_position[0],component.from_elevation_feet/5.0*Placement.HEIGHT_UNIT,component.from_position[1])
    var b=Vector3(component.to_position[0],component.to_elevation_feet/5.0*Placement.HEIGHT_UNIT,component.to_position[1])
    var visual: Dictionary=world.visual_actors.get(component.actor_uuid,{})
    if not visual.is_empty():
        var row: Dictionary=visual.row.duplicate()
        var rig: Dictionary=world.rigs[row.rig]
        var delta=Vector2(component.to_position[0]-component.from_position[0],component.to_position[1]-component.from_position[1])
        if not delta.is_zero_approx():row.facing=world._facing(delta)
        var facing=_facing(world,row)
        var socket: Variant=recipe.get("sourceSockets",recipe.get("sourceSocketsByRig",{}).get(row.rig,{})).get("release",{}).get(facing)
        var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
        if socket!=null:a+=world.camera.basis.x*(socket.x-rig.cell_width*.5)*unit*row.get("scale_x",1.0)+world.camera.basis.y*(rig.cell_height-rig.origin_y_from_ground-socket.y)*unit
        else:a+=world.camera.basis.x*float(recipe.get("originX",0))*unit-world.camera.basis.y*float(recipe.get("originY",recipe.get("sourceAnchor",{}).get("liftY",0)))*unit
    var target: Dictionary=world.visual_actors.get(component.target_uuid,{})
    if not target.is_empty():
        var target_row=target.row.duplicate();target_row.position=component.to_position;target_row.base_height_steps=component.to_elevation_feet/5.0
        if component.kind=="geometry_projectile":
            b-=world.camera.basis.y*float(recipe.targetY)*128.0/float(world.rig_config.TILE_W)*target_row.scale/Placement.PIXELS_PER_UNIT
        else:b=_socket(world,target_row,"body_center")
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

static func _socket(world: Node,row: Dictionary,socket: String) -> Vector3:
    var base=Placement.contact(row)
    if not row.has("rig"): return base
    var rig: Dictionary=world.rigs[row.rig]
    var playback: Node=world.playbacks.get(row.id)
    var clip: String=playback.clip if playback!=null else "Idle"
    var frame=mini(int((playback.sample_seconds if playback!=null else 0.0)*rig.clips[clip].fps),int(rig.clips[clip].frames)-1)
    var points: Array=rig.get("pose_sockets",{}).get(socket,{}).get(clip,{}).get(_facing(world,row),[])
    var point: Variant=points[mini(frame,points.size()-1)] if not points.is_empty() else null
    if point==null: point=rig.get("body_anchor") if socket=="body_center" else null
    if point==null: return base
    var unit=128.0/float(world.rig_config.TILE_W)*row.scale/Placement.PIXELS_PER_UNIT
    return base+world.camera.basis.x*(point.x-rig.cell_width*.5)*unit*row.get("scale_x",1.0)+world.camera.basis.y*(rig.cell_height-rig.origin_y_from_ground-point.y)*unit+Vector3.UP*row.get("visual_height",0.0)*Placement.HEIGHT_UNIT

static func _has_socket(world: Node,row: Dictionary,socket: String) -> bool:
    var rig: Dictionary=world.rigs[row.rig]
    var playback: Node=world.playbacks.get(row.id)
    var clip: String=playback.clip if playback!=null else "Idle"
    var points: Array=rig.get("pose_sockets",{}).get(socket,{}).get(clip,{}).get(_facing(world,row),[])
    if points.is_empty():return false
    var frame=mini(int((playback.sample_seconds if playback!=null else 0.0)*rig.clips[clip].fps),int(rig.clips[clip].frames)-1)
    return points[mini(frame,points.size()-1)]!=null

func _witness(world: Node,component: Dictionary,visible: bool) -> void:
    if not visible:return
    for id in [component.id]+component.get("trace_keys",[]):
        pending_evidence.append({"trace_track_id":id,"display_ms":world.timeline.display_ms,"visible":true})

static func _entry_visible(world: Node,entry: Dictionary) -> bool:
    if not entry.node.is_visible_in_tree():return false
    var mesh: QuadMesh=entry.node.mesh
    var transform: Transform3D=entry.node.global_transform
    var a=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(-mesh.size.x*.5,mesh.size.y*.5,0)))
    var b=world.camera.unproject_position(transform*(mesh.center_offset+Vector3(mesh.size.x*.5,-mesh.size.y*.5,0)))
    return Rect2(a,b-a).abs().intersects(world.get_viewport().get_visible_rect())

static func _actor_visible(world: Node,id: String) -> bool:
    var actor: Dictionary=world.visual_actors.get(id,{})
    if actor.is_empty() or not actor.valid:return false
    for entry in actor.entries:
        if entry.role!="shadow" and not entry.get("texture_path","").is_empty() and _entry_visible(world,entry):return true
    return false

func _condition_witnesses(world: Node,actor_id: String,samples: Array) -> void:
    var selected=Conditions.select_recipes(actor_id,samples)
    for sample in samples:
        if sample.kind!="condition" or sample.actor_uuid!=actor_id:continue
        if not selected.any(func(value):return value.recipe.get("definitionRef")==sample.recipe.get("definitionRef")):continue
        var persistent: Dictionary=sample.recipe.get("persistent",{})
        var poses:Array=persistent.get("activityPoses",[])
        if not poses.is_empty():
            var actor:Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
            var activity:String=world.displayed_samples.get(actor_id,{}).get("activity","idle")
            var rig:String=world.visual_actors[actor_id].row.rig
            var pose=Conditions.ConditionPose.select(actor,rig,activity,world.catalog_cache)
            if pose.get("condition_uuid")==sample.condition_uuid and world.playbacks[actor_id].clip==pose.get("clip"):
                for i in poses.size():
                    if poses[i].rigId==rig and poses[i].activity==activity:
                        _witness(world,{"id":"condition:"+sample.condition_uuid+":activityPoses:"+str(i)},true)
        for mechanism in ["bodyColor","alphaMultiplier","bodyRamp","bodyOutline","bodyPose","frozenPose"]:
            if persistent.get(mechanism)==null:continue
            if mechanism=="bodyRamp" and (persistent.bodyRamp.get("mapping")!="flowing_film" or not world.textures.has(world.resources.get(persistent.bodyRamp.get("texture")))):continue
            if mechanism=="bodyOutline" and (not outlines.owners.has(actor_id) or not outlines.owners[actor_id].drawn):continue
            if mechanism in ["bodyPose","frozenPose"]:
                if not world.displayed_samples.get(actor_id,{}).is_empty():continue
                var actor: Dictionary=world.timeline.presentation_state().actors.get(actor_id,{})
                var pose=Conditions.pose(actor,world.visual_actors[actor_id].row.rig,world.catalog_cache)
                if pose.get("condition_uuid")!=sample.condition_uuid or world.playbacks[actor_id].clip!=pose.get("clip"):continue
            _witness(world,{"id":"condition:"+sample.condition_uuid+":"+mechanism},true)

func _release(world: Node, id: String) -> void:
    var handle: Dictionary=handles[id]
    for draw in handle.draws: world.actor_entries.erase(draw)
    handle.node.close();handle.node.queue_free();handles.erase(id)
    world.draw_order_dirty=true

func close(world: Node) -> void:
    blood.close(world)
    outlines.close(world)
    for id in handles.keys(): _release(world,id)
    for label in numbers.values(): label.queue_free()
    numbers.clear()
    for entry in media_handles.values():world.actor_entries.erase(entry);entry.node.queue_free()
    media_handles.clear();audio.close()
    prepared_groups.clear();pending_evidence=[]
