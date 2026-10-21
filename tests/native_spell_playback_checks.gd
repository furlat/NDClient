extends SceneTree
## Actual admitted operations -> shared Compiler/Timeline/Play -> Forward+ pixels.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Play=preload("res://play.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const CAPTURES="res://.captures/native-spell-playback"
const REPORT="res://.runtime/native-spell-playback-checks.json"
var checks=0
var failures:Array=[]
var evidence:Array=[]
var captures:Array=[]
var plan_only:bool=false

func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    create_timer(480).timeout.connect(func():check(false,"Native spell playback exceeded its finite budget");finish())
    run.call_deferred()

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("NATIVE_PLAYBACK_FAIL ",label)

func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func read_case(spec:Dictionary)->Dictionary:
    var journal=Journal.new()
    var opened=journal.open(spec.path,true,false)
    check(opened.ok,spec.id+": real journal admits")
    if not opened.ok:return {}
    var before=journal.replay(spec.sequence-1)
    check(before.ok,spec.id+": preceding canonical state reduces")
    if not before.ok:return {}
    var initial:Dictionary=journal.state
    var raw:PackedByteArray=FileAccess.get_file_as_bytes(spec.path.path_join("%016d.json"%spec.sequence))
    var decoded:Dictionary=journal.decode_record(spec.sequence,raw)
    check(decoded.ok,spec.id+": actual native16 operation admits")
    if not decoded.ok:return {}
    var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
    check(folded.ok,spec.id+": actual event-time canonical cuts reduce")
    if not folded.ok:return {}
    var packet:Dictionary=folded.normalized
    var cache:Dictionary={}
    var compiled=Compiler.compile_recorded(initial,packet,cache,journal.state,folded.transitions)
    check(compiled.ok,spec.id+": production compiler accepts")
    if not compiled.ok:print(compiled);return {}
    var result={"spec":spec,"initial":initial,"final":journal.state,"groups":compiled.value.groups,"cache":cache,"rows":[],"end_ms":0.0,"semantic_end_ms":0.0,"events":{}}
    var completion_by_lineage:Dictionary={}
    for native in packet.lineages:
        var lineage:Dictionary=Occurrences.group(native)
        for event in lineage.events:
            result.events[event.id]=event
            if event.phase=="completion":completion_by_lineage[event.lineage_id]=event
    var at=0.0
    for group in result.groups:
        for component in group.components:
            if component.get("native_spell",false) or component.get("kind")=="material_flash" and component.has("native_hit"):
                result.rows.append({"component":component,"start_ms":at+component.start_ms,"end_ms":at+component.start_ms+component.duration_ms,"group_end_ms":at+group.duration_ms})
                result.end_ms=maxf(result.end_ms,at+component.start_ms+component.duration_ms)
        at+=group.duration_ms
    result.semantic_end_ms=at;result.end_ms=maxf(at,result.end_ms)+100.0
    var flights=result.rows.filter(func(row):return row.component.get("native_cue",{}).get("role")=="flight")
    var hits=result.rows.filter(func(row):return row.component.kind=="material_flash")
    check(flights.size()==spec.deliveries and hits.size()==spec.hits,spec.id+": actual delivery/damage counts match the recording")
    for hit in hits:
        var event:Dictionary=result.events[hit.component.source_event_uuid]
        check(event.fact.kind=="damage" and event.fact.stage=="applied" and event.fact.applied_damage>0 and not event.canceled,spec.id+": native flash belongs to actual applied positive damage")
        # Parent-event IDs may name an undisclosed intermediate phase. The
        # admitted parent-lineage chain identifies its actual completion owner.
        var ancestor_lineage:Variant=event.parent_lineage
        var ancestor:Variant=null
        while ancestor_lineage!=null and completion_by_lineage.has(ancestor_lineage):
            var owner:Dictionary=completion_by_lineage[ancestor_lineage]
            var fact:Variant=owner.fact
            ancestor=owner.id
            if fact!=null and fact.kind=="spell":break
            ancestor_lineage=owner.parent_lineage
        var own=flights.filter(func(row):return row.component.source_event_uuid==ancestor)
        check(own.size()==1,spec.id+": damage identifies its exact spell application delivery")
        if own.size()==1:
            var contact=own[0].start_ms+own[0].component.native_cue.contact*1000.0
            check(hit.component.actor_uuid==own[0].component.target_uuid and hit.start_ms>=contact-.001,spec.id+": recipient damage follows its own missile contact")
    return result

func restored(data:Dictionary,at:float)->RefCounted:
    var timeline=Timeline.new()
    timeline.accept({"kind":"initialization","state":data.initial.duplicate(true),"sequence":data.spec.sequence-1})
    timeline.accept({"kind":"operation","groups":data.groups})
    if at>0:timeline.advance(at)
    timeline.paused=true
    return timeline

func settle(world:Node,label:String)->bool:
    var deadline=Time.get_ticks_msec()+90000
    var diagnosed=false
    var ready=false
    while world.presentation_errors.is_empty() and world.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
        if world.playback_prepared():
            check(world.component_renderer.native_spells.required_images.keys().all(func(path):return world.media_plan.required.has(path)),label+": ready includes every current native optical image in mandatory media")
            check(world.playback_prepared(),label+": readiness does not retract on an unchanged immediate query")
            # Capture only after the prepared native scene has drawn, then
            # recheck the host's readiness at that visible boundary.
            await frame()
            if world.playback_prepared():ready=true;break
        if not diagnosed and Time.get_ticks_msec()>deadline-80000:
            print("NATIVE_PREP_WAIT ",label," ",JSON.stringify(preparation_diagnostic(world)));diagnosed=true
        await frame()
    check(ready,label+": production world/media/native readiness completes")
    if not ready:print("NATIVE_PREP_DIAGNOSTIC ",JSON.stringify(preparation_diagnostic(world)))
    if ready:await frame()
    return ready

func preparation_diagnostic(world:Node)->Dictionary:
    var group:Dictionary=world.timeline.current if not world.timeline.current.is_empty() else world.timeline.queue[0] if not world.timeline.queue.is_empty() else {}
    return {"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics,
        "world_revision":world.world_revision,"timeline_revision":world.timeline.world_revision,"pending_world":world.pending_world!=null,
        "world_epoch":world.world_prepare_epoch,"timeline_epoch":world.timeline.initialization_revision,"waiting_world":world.timeline.waiting_for_world,
        "media_metadata_ready":world.media_metadata_ready,"media_initial_ready":world.media_initial_ready,"media_group":group.get("id"),
        "renderer_ready":world.component_renderer.ready,"native_ready":world.component_renderer.native_spells.ready,"hit_ready":world.component_renderer.native_hits.ready,
        "blood_ready":world.component_renderer.blood.ready,"native_prepare":world.component_renderer.readiness}

func advance(world:Node,target:float)->bool:
    var plan=world.timeline.replay_plan(target)
    var deadline=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline:
        if world.timeline.replay_prepare(plan) and world.can_publish_replay_advance(plan):
            check(world.publish_replay_advance(plan),"Prepared exact replay boundary publishes")
            await frame()
            return true
        if not world.presentation_errors.is_empty() or not world.media_issue.is_empty():break
        await frame()
    check(false,"Replay boundary prepares at %.3fms"%target)
    print("NATIVE_ADVANCE_DIAGNOSTIC ",JSON.stringify({"target":target,"errors":world.presentation_errors,"media":world.media_issue,"native":world.component_renderer.native_spells.diagnostics}))
    return false

func pixels(image:Image)->int:
    var count=0
    for y in image.get_height():
        for x in image.get_width():
            var value=image.get_pixel(x,y)
            if maxf(value.r,maxf(value.g,value.b))>1./255.:count+=1
    return count

func capture(view:SubViewport,label:String)->void:
    captures.append({"label":label,"image":view.get_texture().get_image()})

func pause_stage(world:Node,label:String,previous:Dictionary={})->Dictionary:
    var images:Dictionary={}
    var renderer=world.component_renderer.native_spells
    for key in renderer.groups:images["pass-"+str(images.size())]=renderer.groups[key].viewport.get_texture().get_image()
    if renderer._support!=null and renderer._support.enabled:images.support=renderer._support.viewport.get_texture().get_image()
    var changes:Dictionary={}
    for key in images:
        captures.append({"label":label+"-"+key,"image":images[key]})
        if previous.has(key):changes[key]=previous[key].get_data()!=images[key].get_data()
    var clocks:Array=[]
    for handle in renderer.handles.values():
        if handle.root.visible:clocks.append({"id":handle.component.id,"age":handle.age,"sample_time":handle.sample_time,"speeds":handle.emitters.map(func(emitter):return emitter.speed_scale)})
    print("NATIVE_PAUSE_STAGE ",label," ",JSON.stringify({"changed":changes,"clocks":clocks}))
    return images

func body_pixels(world:Node,view:SubViewport,actor:String,label:String,source_hidden:bool=false)->Dictionary:
    # Hold the real displayed pose and source age while changing only the
    # production Full/Colour option. The impact remains present in both frames.
    world.native_spell_hit_material=true;world._process(0.0)
    if source_hidden:
        for layer in world.component_renderer.native_spells.groups.values():layer.output.hide()
    await frame();await frame()
    var full=view.get_texture().get_image();full.convert(Image.FORMAT_RGBA8)
    captures.append({"label":label+"-full","image":full})
    var probes:Dictionary={}
    var probe="--pause-stages" in OS.get_cmdline_user_args()
    if probe:
        probes=pause_stage(world,label+"-0-initial")
        await frame();await frame()
        probes=pause_stage(world,label+"-1-no-sample",probes)
        world._process(0.0);await frame();await frame()
        probes=pause_stage(world,label+"-2-same-sample",probes)
    var pass_images:Dictionary={}
    for key in world.component_renderer.native_spells.groups:
        pass_images[key]=world.component_renderer.native_spells.groups[key].viewport.get_texture().get_image()
    var hit_images:Dictionary={}
    for key in world.component_renderer.native_hits.records:
        var record:Dictionary=world.component_renderer.native_hits.records[key]
        if record.has("surface"):hit_images[key]=record.surface.viewport.get_texture().get_image()
    world.native_spell_hit_material=false;world._process(0.0)
    if source_hidden:
        for layer in world.component_renderer.native_spells.groups.values():layer.output.hide()
    await frame();await frame()
    var colour=view.get_texture().get_image();colour.convert(Image.FORMAT_RGBA8)
    captures.append({"label":label+"-colour","image":colour})
    if probe:probes=pause_stage(world,label+"-3-colour",probes)
    var entries:Array=world.visual_actors[actor].entries.filter(func(entry):return entry.role!="shadow" and entry.node.visible)
    check(not entries.is_empty(),label+": real recipient has assembled receiving layers")
    # White through the original source alpha, compared with those same layers
    # at zero output alpha, measures recipient coverage without a rectangle.
    # Keep scene instances registered: hiding them can reorder overlapping
    # native transparent draws even though their source clock has not changed.
    var white_image=Image.create(1,1,false,Image.FORMAT_RGBA8);white_image.fill(Color.WHITE)
    var white=ImageTexture.create_from_image(white_image)
    var fields=["native_body_enabled","native_body_strength","native_body_surface","native_body_ramp_count","wall_opacity"]
    var saved:Array=[]
    for entry in entries:
        var values:Dictionary={}
        for field in fields:values[field]=entry.material.get_shader_parameter(field)
        saved.append(values)
        entry.material.set_shader_parameter("native_body_enabled",true)
        entry.material.set_shader_parameter("native_body_strength",1.0)
        entry.material.set_shader_parameter("native_body_surface",white)
        entry.material.set_shader_parameter("native_body_ramp_count",0)
    await frame();await frame()
    var coverage=view.get_texture().get_image();coverage.convert(Image.FORMAT_RGBA8)
    if probe:probes=pause_stage(world,label+"-4-white",probes)
    for entry in entries:entry.material.set_shader_parameter("wall_opacity",0.0)
    await frame();await frame()
    var absent=view.get_texture().get_image();absent.convert(Image.FORMAT_RGBA8)
    if probe:probes=pause_stage(world,label+"-5-transparent",probes)
    for index in entries.size():
        for field in fields:entries[index].material.set_shader_parameter(field,saved[index][field])
    if probe:
        await frame();await frame()
        probes=pause_stage(world,label+"-6-opaque",probes)
    captures.append({"label":label+"-target-coverage","image":coverage})
    captures.append({"label":label+"-target-absent","image":absent})
    var a=full.get_data();var b=colour.get_data();var c=coverage.get_data();var d=absent.get_data()
    var changed=0;var outside=0;var coverage_pixels=0
    var bounds=Rect2i()
    var mask=Image.create(full.get_width(),full.get_height(),false,Image.FORMAT_RGBA8);mask.fill(Color.TRANSPARENT)
    for offset in range(0,a.size(),4):
        var covered=c[offset]!=d[offset] or c[offset+1]!=d[offset+1] or c[offset+2]!=d[offset+2]
        var point=Vector2i((offset/4)%full.get_width(),(offset/4)/full.get_width())
        if covered:
            coverage_pixels+=1
            bounds=Rect2i(point,Vector2i.ONE) if coverage_pixels==1 else bounds.merge(Rect2i(point,Vector2i.ONE))
            mask.set_pixelv(point,Color.WHITE)
        if a[offset]!=b[offset] or a[offset+1]!=b[offset+1] or a[offset+2]!=b[offset+2]:
            changed+=1
            if not covered:outside+=1
    captures.append({"label":label+"-target-mask","image":mask})
    check(coverage_pixels>0,label+": actual recipient alpha has visible coverage")
    check(outside==0,label+": Full/Colour changes remain inside actual assembled recipient alpha (%d outside)"%outside)
    world.native_spell_hit_material=true;world._process(0.0)
    if source_hidden:
        for layer in world.component_renderer.native_spells.groups.values():layer.output.hide()
    await frame();await frame()
    var restored_full=view.get_texture().get_image();restored_full.convert(Image.FORMAT_RGBA8)
    if probe:pause_stage(world,label+"-7-restored",probes)
    captures.append({"label":label+"-restored-full","image":restored_full})
    var source_changes:Dictionary={"appearance_passes":[],"hit_materials":[]}
    for key in pass_images:
        var current:Image=world.component_renderer.native_spells.groups[key].viewport.get_texture().get_image()
        source_changes.appearance_passes.append(pass_images[key].get_data()!=current.get_data())
        captures.append({"label":label+"-pass-before-%d"%source_changes.appearance_passes.size(),"image":pass_images[key]})
        captures.append({"label":label+"-pass-after-%d"%source_changes.appearance_passes.size(),"image":current})
    for key in hit_images:
        var current:Image=world.component_renderer.native_hits.records[key].surface.viewport.get_texture().get_image()
        source_changes.hit_materials.append(hit_images[key].get_data()!=current.get_data())
    check(not source_changes.appearance_passes.has(true),label+": Full/Colour coverage controls preserve exact native impact pixels")
    check(not source_changes.hit_materials.has(true),label+": paused hit source materials remain exact")
    check(full.get_data()==restored_full.get_data(),label+": paused Full material restores the exact scene")
    print("NATIVE_BODY_CONTROL ",label," ",JSON.stringify(source_changes))
    return {"changed":changed,"outside":outside,"coverage_pixels":coverage_pixels,"coverage_bounds":str(bounds),"source_hidden":source_hidden,"source_changes":source_changes}

func configure_camera(world:Node,data:Dictionary)->void:
    var flight=data.rows.filter(func(row):return row.component.get("native_cue",{}).get("role")=="flight")[0].component
    var a=Vector3(flight.from_position[0],flight.from_elevation_feet/5.0*Play.Placement.HEIGHT_UNIT,flight.from_position[1])
    var b=Vector3(flight.to_position[0],flight.to_elevation_feet/5.0*Play.Placement.HEIGHT_UNIT,flight.to_position[1])
    world.camera_focus=(a+b)*.5+Vector3.UP*.5;world.initial_focus=true
    world.camera.size=maxf(6.0,a.distance_to(b)*1.45+2.0)
    world.position_camera()
    world.wall_mode="hidden";world.update_wall_visibility()

func assert_frame(world:Node,data:Dictionary,observed:Dictionary)->void:
    var native=world.component_renderer.native_spells
    for component in world.displayed_components:
        if component.get("native_spell",false):
            if not native.handles.has(component.id):
                check(false,data.spec.id+": active real native phase has a prepared instance "+component.id);continue
            var handle:Dictionary=native.handles[component.id]
            var diagnostic:Dictionary=native.diagnostics.get(component.id,{})
            if diagnostic.get("status") in ["prepared","rendered"]:
                check(absf(float(diagnostic.age_ms)-float(diagnostic.requested_age_ms))<.001,data.spec.id+": live native age keeps up with requested display age")
                check(absf(handle.sample_time*1000.0-component.age_ms)<.001,data.spec.id+": displayed phase and source occurrence clocks agree")
            else:check(false,data.spec.id+": active native phase has no pending/missing attachment "+str(diagnostic))
            observed.phases[component.id]=true
            if handle.rendered_once:observed.drawn[component.id]=true
            if component.native_cue.role=="flight":
                var elapsed=component.age_ms/1000.0
                if elapsed>=component.native_cue.launch and elapsed<=component.native_cue.contact:
                    observed.flight_frames+=1
                if elapsed>=component.native_cue.contact:
                    var points=Sockets.endpoints(world,component)
                    if points.ready:
                        var core:Node3D=handle.root.get_node(component.native_cue.origin_path) if component.native_cue.has("origin_path") else handle.root
                        check(core.global_position.distance_to(points.to)<.001,data.spec.id+": delivered native core stays at this recipient's measured contact")
                        observed.contacts[component.id]=true
            if world.timeline.retained_components.any(func(item):return item.component.id==component.id):observed.tail_frames+=1
        elif component.kind=="material_flash" and component.has("native_hit"):
            observed.hits[component.id]=true
            check(component.age_ms>=0 and component.age_ms<150.0,data.spec.id+": only the authored150ms actual-damage flash is displayed")
            var count=0
            for entry in world.visual_actors.get(component.actor_uuid,{}).get("entries",[]):
                if entry.role=="shadow" or not entry.node.visible:continue
                var material:ShaderMaterial=entry.node.material_override
                if material.get_shader_parameter("native_body_enabled"):
                    count+=1
                    check(material.get_shader_parameter("native_body_surface")!=null and float(material.get_shader_parameter("native_body_strength"))>0,data.spec.id+": actual lit actor output carries the current native material")
            check(count>0,data.spec.id+": actual damaged recipient has native-material body layers")

func continuous(world:Node,view:SubViewport,data:Dictionary,fps:int,rate:float)->void:
    Engine.max_fps=fps
    world.playback_speed=rate;world.timeline.paused=false
    var observed={"phases":{},"drawn":{},"hits":{},"contacts":{},"flight_frames":0,"tail_frames":0}
    var frame_count=0;var previous=Time.get_ticks_usec();var native_steps:Array=[]
    var first_flight=data.rows.filter(func(row):return row.component.get("native_cue",{}).get("role")=="flight")[0]
    var midpoint=first_flight.start_ms+(first_flight.component.native_cue.launch+first_flight.component.native_cue.contact)*500.0
    var captured=false;var source_pixels=0
    var deadline=Time.get_ticks_msec()+90000
    while world.timeline.display_ms<data.end_ms-.001 and Time.get_ticks_msec()<deadline:
        var target=minf(data.end_ms,world.timeline.display_ms+1000.0/fps*rate)
        if not await advance(world,target):break
        var now=Time.get_ticks_usec();native_steps.append((now-previous)/1000.0);previous=now
        frame_count+=1;assert_frame(world,data,observed)
        if not captured and world.timeline.display_ms>=midpoint:
            capture(view,"%s-%dfps-%.0fx-flight"%[data.spec.id,fps,rate]);captured=true
            for group in world.component_renderer.native_spells.groups.values():source_pixels+=pixels(group.viewport.get_texture().get_image())
    world.timeline.paused=true
    check(world.timeline.display_ms>=data.end_ms-.001,data.spec.id+": native playback reaches the complete authored tail")
    check(observed.flight_frames>0 and source_pixels>0,data.spec.id+": actual Forward+ delivery has nonblank source pixels")
    check(observed.hits.size()==data.spec.hits,data.spec.id+": continuous display shows exactly the real damaging occurrences")
    check(observed.contacts.size()==data.spec.deliveries,data.spec.id+": every native projectile reaches its own recipient")
    var expected_native=data.rows.filter(func(row):return row.component.get("native_spell",false))
    var persistent:Array=world.timeline.component_samples(world.catalog_cache).filter(func(component):return component.get("native_spell",false) and component.get("persistent_owner",false))
    var expected_drawn:Dictionary={}
    for row in expected_native:expected_drawn[row.component.id]=true
    for component in persistent:
        expected_drawn[component.id]=true
        check(data.final.actors.get(component.actor_uuid,{}).get("conditions",[]).any(func(condition):return condition.condition_uuid==component.condition_uuid),data.spec.id+": terminal persistent visual belongs to a condition still present in the independent canonical result")
    check(observed.drawn==expected_drawn,data.spec.id+": every transient phase and still-authoritative persistent condition completes an actual draw")
    var expected_tails=expected_native.filter(func(row):return row.end_ms>row.group_end_ms+.001)
    if not expected_tails.is_empty():check(observed.tail_frames>0,data.spec.id+": actual retained native tails survive their group's completed state commits")
    check(world.timeline.state==data.final,data.spec.id+": fully displayed state equals the canonical reducer result")
    var renderer=world.component_renderer.native_spells
    var remaining_ids:Array=persistent.map(func(component):return component.id)
    check(renderer.handles.size()==remaining_ids.size() and renderer.handles.keys().all(func(id):return id in remaining_ids),data.spec.id+": completed sources retire while authoritative condition owners remain")
    check(renderer.spare_layers.size()<=renderer.LAST_BIT-renderer.FIRST_BIT+1,data.spec.id+": retained native passes stay within their existing capacity")
    check(renderer.spare_layers.all(func(layer):return not layer.output.visible and layer.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED),data.spec.id+": reusable inactive passes neither render nor composite old pixels")
    if persistent.is_empty():
        check(renderer.groups.is_empty(),data.spec.id+": no active pass remains without an authoritative effect")
        check(renderer._support==null or (not renderer._support.enabled and not renderer._support.owner.visible and renderer._support.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED),data.spec.id+": inactive receiver support stops rendering")
        if renderer._support!=null:
            check(renderer._support.solid_masks.is_empty() and renderer._support.actors.values().all(func(node):return node.material_override.get_shader_parameter("sheet")==null and node.material_override.get_shader_parameter("component_solid")==null),data.spec.id+": sleeping receiver support releases media texture references")
    check(world.source_lighting.effect_sources.is_empty(),data.spec.id+": completed native sources leave no effect light")
    for visual in world.visual_actors.values():
        for entry in visual.entries:
            if entry.role!="shadow":check(not entry.node.material_override.get_shader_parameter("native_body_enabled"),data.spec.id+": terminal actor output restores ordinary material")
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),data.spec.id+": native continuous playback is free of presentation/media errors")
    evidence.append({"case":data.spec.id,"fps_cap":fps,"rate":rate,"frames":frame_count,"source_pixels":source_pixels,"observed":observed,"native_draw_intervals_ms":native_steps,"end_ms":world.timeline.display_ms,
        "native_phases":expected_native.map(func(row):return {"id":row.component.id,"role":row.component.native_cue.role,"start_ms":row.start_ms,"end_ms":row.end_ms,"group_end_ms":row.group_end_ms})})

func paused_controls(world:Node,view:SubViewport,data:Dictionary)->void:
    var hits=data.rows.filter(func(row):return row.component.kind=="material_flash")
    if hits.is_empty():return
    var hit:Dictionary=hits[0]
    var at:float=hit.start_ms+25.0
    check(world.try_reset_hidden_playback(restored(data,at)),data.spec.id+": hidden native host accepts exact contact seek")
    if not await settle(world,data.spec.id+" contact seek"):return
    configure_camera(world,data);await frame()
    world.set_process(false)
    var actual=await body_pixels(world,view,hit.component.actor_uuid,data.spec.id+"-contact")
    var unoccluded:Dictionary={}
    if actual.changed==0:
        # A source impact can occlude its receiver. Qualify that body separately
        # without claiming it is visible through the original impact geometry.
        unoccluded=await body_pixels(world,view,hit.component.actor_uuid,data.spec.id+"-contact-unoccluded",true)
        for layer in world.component_renderer.native_spells.groups.values():layer.output.show()
    check(actual.changed>0 or unoccluded.get("changed",0)>0,data.spec.id+": full native material changes actual recipient pixels versus colour-only mode")
    var recipient_screen=world.camera.unproject_position(Sockets.socket(world,world.visual_actors[hit.component.actor_uuid].row,"body_center"))
    world.set_process(true)
    world.native_spell_hit_material=true;await frame();await frame()
    check(world.try_reset_hidden_playback(restored(data,0)),data.spec.id+": reverse seek installs the actual pre-operation state")
    if not await settle(world,data.spec.id+" reverse seek"):return
    check(world.timeline.state==data.initial,data.spec.id+": reverse seek restores canonical initial state")
    check(world.component_renderer.native_spells.groups.is_empty(),data.spec.id+": reverse seek has no active old appearance pass")
    check(world.try_reset_hidden_playback(restored(data,at)),data.spec.id+": second exact seek reconstructs the occurrence")
    if not await settle(world,data.spec.id+" repeated contact"):return
    check(world.displayed_components.any(func(row):return row.id==hit.component.id and row.has("native_surface")),data.spec.id+": repeated exact seek restores the same real native hit occurrence")
    evidence.append({"case":data.spec.id,"contact_seek_ms":at,"recipient_uuid":hit.component.actor_uuid,"recipient_body_screen":str(recipient_screen),"actual_scene_body_pixels":actual,"source_hidden_control":unoccluded})

func run_case(spec:Dictionary)->void:
    var data=read_case(spec)
    if data.is_empty():return
    if plan_only:
        evidence.append({"case":spec.id,"recording":spec.path,"sequence":spec.sequence,"deliveries":spec.deliveries,"hits":spec.hits,"phase_plan":data.rows.map(func(row):return {"id":row.component.id,"source_event_uuid":row.component.source_event_uuid,"role":row.component.get("native_cue",{}).get("role","material_flash"),"start_ms":row.start_ms,"end_ms":row.end_ms})});return
    var immutable=data.groups.duplicate(true)
    var view=SubViewport.new();view.size=Vector2i(960,640);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.audio_listener_enable_3d=false;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(data.cache);world.media_warmup.budget_bytes=0
    view.add_child(world);world.install_playback(restored(data,0))
    var cadences:Array=[] if "--controls-only" in OS.get_cmdline_user_args() else [{"fps":30,"rate":1.0},{"fps":60,"rate":2.0}]
    for cadence in cadences:
        if not await settle(world,spec.id+" initial"):break
        configure_camera(world,data);await frame()
        await continuous(world,view,data,cadence.fps,cadence.rate)
        if not failures.is_empty() and not world.presentation_errors.is_empty():break
        check(world.try_reset_hidden_playback(restored(data,0)),spec.id+": loop resets an actual Timeline with independent occurrence state")
    if cadences.is_empty():await settle(world,spec.id+" initial control")
    if world.presentation_errors.is_empty():await paused_controls(world,view,data)
    check(data.groups==immutable,spec.id+": preparation, playback and seek leave compiled source snapshots unchanged")
    check(world.presentation_errors.is_empty(),spec.id+": no native source or receiver errors")
    view.queue_free();await frame();await frame()

func run()->void:
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var selected=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--case="):selected=argument.trim_prefix("--case=")
        if argument=="--plan-only":plan_only=true
    for spec in [{"id":"fire-bolt","path":Fixtures.journal("fire-bolt"),"sequence":8,"deliveries":1,"hits":1},
        {"id":"magic-missile","path":Fixtures.journal("magic-missile"),"sequence":2,"deliveries":3,"hits":3},
        {"id":"shield-blocked","path":Fixtures.journal("shield"),"sequence":6,"deliveries":3,"hits":0}]:
        if selected.is_empty() or selected==spec.id:await run_case(spec)
    check(selected.is_empty() or selected in ["fire-bolt","magic-missile","shield-blocked"],"Requested playback subset names an actual original case")
    finish()

func finish()->void:
    for capture in captures:capture.image.save_png(CAPTURES+"/"+capture.label+".png")
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"evidence":evidence,
        "scope":"Real SDK operations through production Compiler/Timeline/Play with external shared-clock publication, native30fps1x and60fps2x draws, source/receiver pixels, actual application contact ownership, tails, seeks, loops and retirement. Frame intervals include test observations and are not performance measurements."}
    if plan_only:report.scope="Actual current original three-case native16 operation admission, independent canonical cuts, exact damage/application ancestry and phase-clock plans only; no native rendering, playback controls or pixel qualification."
    var destination:String=REPORT.replace(".json","-plan.json") if plan_only else REPORT
    FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_PLAYBACK ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures,"report":destination}))
    quit(0 if failures.is_empty() else 1)
