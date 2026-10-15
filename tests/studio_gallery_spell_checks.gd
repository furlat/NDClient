extends SceneTree
## Original large-map SDK journals -> ordinary Studio/reducer and native replay.
## --native adds the actual Studio window; headless qualification never draws.
const Recording=preload("res://studio/recording.gd")
const Library=preload("res://studio/case_library.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Studio=preload("res://studio/studio.gd")
const Placement=preload("res://placement.gd")
const CASE="res://generated/studio_gallery_spell_case.json"
const REPORT="res://.runtime/studio-gallery-spell-checks"
const CAPTURES="res://.captures/studio-gallery-spells"
const SPELLS=["magic_missile","ray_of_frost","scorching_ray","acid_splash","fireball","chill_touch"]
const ROLES={"magic_missile":{"cast":2,"flight":6,"impact":6},"ray_of_frost":{"cast":1,"flight":2,"impact":1},
    "scorching_ray":{"cast":1,"flight":3,"impact":1},"acid_splash":{"cast":1,"flight":1,"impact":1},
    "fireball":{"cast":1,"flight":1,"area":1},"chill_touch":{"strike":1},"shield":{"attached":3}}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var native_evidence:Dictionary={}
var canonical:Dictionary={}
var indices:Dictionary={}
var fixture:Dictionary={}
var studio:Control
var native:bool=false

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("GALLERY_SPELL_FAIL ",label)
func data(path:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))

func raw_events(path:String)->Dictionary:
    var result:Dictionary={}
    for file in DirAccess.get_files_at(path):
        if not file.ends_with(".json") or file.length()!=21:continue
        var packet:Dictionary=data(path.path_join(file))
        for lineage in packet.get("lineages",[]):
            var nodes:Array=[lineage.root];nodes.append_array(lineage.events)
            for event in nodes:result[event.uuid]=event
    return result

func qualify_fixture()->void:
    fixture=data(CASE)
    check(fixture.failures.is_empty(),"The captured Gallery commands and source qualification succeeded")
    var capture:Dictionary=data(fixture.descriptor)
    check(capture.ok and capture.commands.size()==60,"All60 original SDK commands completed")
    check(capture.commands.all(func(command):return command.receipt.kind=="committed"),"Every recorded command has an authoritative committed receipt")
    var config:Dictionary=data(fixture.descriptor.get_base_dir().path_join("server.json"))
    var member:Dictionary=config.recipe.roster_slots[0].roster.members[0]
    check(config.recipe.battlefield_id=="battlefield.lantern_gallery" and member.source.premade_id=="hero.sorcerer_l5_standard_torch","The fixture uses the existing Gallery and ordinary level5 sorcerer premade")
    check(member.scenario_setup_effects.size()==1 and member.scenario_setup_effects[0].behavior_ref.content_id=="reaction.spell.shield","Shield is the explicit scenario reaction grant, not an invented client outcome")
    var listed:Array=Library.read().filter(func(item):return item.id==fixture.id)
    check(listed.size()==1 and listed[0].perspectives==fixture.perspectives,"Library exposes exactly this complete run and both original faction streams")
    var scenarios:Array=data("res://authoring/studio/scenarios.json").scenarios
    var studies:Array=scenarios.filter(func(item):return item.id=="gallery.sorcerer_expedition")
    check(studies.size()==1 and studies[0].code=="GAL01" and studies[0].recordings[0].case_id==fixture.id,"GAL01 links the real Gallery recording to its capability study")

func qualify_stream(side:Dictionary)->void:
    var label:String="Gallery / "+side.id
    var started:int=Time.get_ticks_msec()
    var index:Dictionary=Recording.read(side.journal)
    check(index.ok,label+": original journal builds the shared Studio index")
    if not index.ok:return
    indices[side.id]=index
    var journal=Journal.new();var opened:Dictionary=journal.open(side.journal,true,true)
    check(opened.ok,label+": independent canonical SDK reduction succeeds")
    if not opened.ok:return
    canonical[side.id]=journal.state.duplicate(true)
    var events:Dictionary=raw_events(side.journal)
    var facts:Dictionary={};var positive:Dictionary={};var blocked:Dictionary={};var shield:Dictionary={}
    for id in events:
        var event:Dictionary=events[id]
        if event.fact==null:continue
        var fact:Dictionary=event.fact
        facts[fact.kind]=int(facts.get(fact.kind,0))+1
        if fact.kind=="damage" and fact.get("stage")=="applied" and fact.get("applied_damage",0)>0 and not event.canceled:positive[id]=fact
        if fact.get("intercepted_by_condition_uuid")!=null:blocked[id]=fact
        if fact.kind=="condition" and fact.condition.behavior_id=="condition.spell.shield":shield[fact.event_type]=event
    check(positive.size()==8 and blocked.size()==3,label+": recorded eight applied damage facts and three actual Shield interceptions")
    check(facts.get("step",0)==35 and facts.get("movement",0)==8 and facts.get("object_destroyed",0)==4,label+": long excursion and four actual environment destructions remain in the event stream")
    check(shield.has("condition_application") and shield.has("condition_removal"),label+": actual Shield application and removal are disclosed")
    var owner:String=shield.condition_application.fact.condition.condition_uuid
    check(shield.condition_application.fact.target_entity_uuid==fixture.caster_uuid and shield.condition_removal.fact.target_entity_uuid==fixture.caster_uuid and shield.condition_removal.fact.condition.condition_uuid==owner,label+": the same Shield instance belongs to the sorcerer throughout")
    var state:Dictionary=index.initialization.state.duplicate(true)
    var owners:Dictionary={};Conditions.observe(owners,state.actors,0.0,true)
    var phase_counts:Dictionary={};var flashes:Dictionary={};var reactions:Dictionary={};var commits:Dictionary={};var native_ids:Dictionary={};var persistent_ids:Dictionary={};var damage_times:Dictionary={}
    var previous_group:float=-1.0
    for wrapped in index.groups:
        var group:Dictionary=wrapped.group
        check(wrapped.start_ms>=previous_group,label+": shared groups preserve chronological order")
        previous_group=wrapped.start_ms
        for event in group.events:
            if event.has("damage_timing"):
                var timing:Dictionary=event.damage_timing.duplicate(true)
                for field in ["start","flash","hp","number"]:timing[field]+=wrapped.start_ms
                damage_times[event.event_uuid]=timing
        var previous:float=-1.0
        for commit in group.commits:
            check(is_finite(commit.at_ms) and commit.at_ms>=previous,label+": authoritative commits remain ordered")
            previous=commit.at_ms;Compiler.apply_delta(state,commit.delta)
            var absolute:float=wrapped.start_ms+commit.at_ms
            if commit.has("event_uuid"):commits[commit.event_uuid]=absolute
            Conditions.observe(owners,state.actors,absolute)
            for sample in Conditions.samples(owners.duplicate(true),absolute+.001,index.cache):
                if not sample.get("native_spell",false) or sample.spell_id!="shield":continue
                persistent_ids[sample.id]=true
                check(sample.persistent_owner and sample.condition_uuid==owner and sample.actor_uuid==fixture.caster_uuid,label+": native Shield samples follow the disclosed sorcerer condition owner")
        for component in group.components:
            if component.get("native_spell",false):
                check(not native_ids.has(component.id),label+": native phase occurrence is unique")
                native_ids[component.id]=true
                check(events.has(component.source_event_uuid),label+": every native phase keeps original server-event provenance")
                check(component.status=="available" and component.duration_ms>0 and is_finite(component.duration_ms),label+": authored native phase is finite and available")
                if not phase_counts.has(component.spell_id):phase_counts[component.spell_id]={}
                var roles:Dictionary=phase_counts[component.spell_id];roles[component.native_cue.role]=int(roles.get(component.native_cue.role,0))+1
                if component.spell_id=="shield":
                    check(blocked.has(component.source_event_uuid) and blocked[component.source_event_uuid].intercepted_by_condition_uuid==owner,label+": native Shield contact is driven by an actual intercepted delivery")
            if component.kind=="material_flash":
                check(positive.has(component.source_event_uuid),label+": body flash belongs only to positive applied damage")
                check(component.actor_uuid==positive.get(component.source_event_uuid,{}).get("target_entity_uuid") and component.duration_ms==150,label+": recipient and shared150ms flash follow the actual damage")
                flashes[component.source_event_uuid]=wrapped.start_ms+component.start_ms
        for body in group.actor_tracks:
            if body.clip=="TakeDamage":
                check(positive.has(body.source_event_uuid) and body.actor_uuid==positive.get(body.source_event_uuid,{}).get("target_entity_uuid"),label+": TakeDamage belongs to the actual damaged recipient")
                reactions[body.source_event_uuid]=wrapped.start_ms+body.start_ms
    check(phase_counts==ROLES,label+": actual deliveries and misses produce the expected native phase roles; "+JSON.stringify(phase_counts))
    check(flashes.size()==positive.size() and reactions.size()==positive.size(),label+": every actual damage has both a body flash and TakeDamage track")
    for id in positive:
        check(flashes.has(id) and reactions.has(id) and commits.has(id),label+": damage has its own rendering and authoritative commit")
        if flashes.has(id) and reactions.has(id) and commits.has(id):
            check(damage_times.has(id),label+": applied damage exposes its authored body/flash/HP marker timings")
            if damage_times.has(id):
                var timing:Dictionary=damage_times[id]
                check(absf(flashes[id]-timing.flash)<.001 and absf(reactions[id]-timing.start)<.001,label+": body reaction and flash follow their independent authored source frames")
                check(absf(commits[id]-timing.hp)<.001,label+": authoritative HP publishes at the authored HP marker; "+JSON.stringify({"event":id,"body":reactions[id],"flash":flashes[id],"hp_marker":timing.hp,"commit":commits[id]}))
    for id in blocked:check(not flashes.has(id) and not reactions.has(id),label+": intercepted damage produces no fabricated hurt/flash")
    check(persistent_ids.size()==1,label+": native Shield uses one stable owner across all samples")
    check(not Conditions.samples(owners.duplicate(true),index.presentation_end_ms+1000,index.cache).any(func(sample):return sample.get("native_spell",false) and sample.spell_id=="shield"),label+": Shield native source retires after actual removal and authored close")
    check(state==journal.state,label+": complete Studio commits equal independent canonical SDK state")
    check(state.actors[fixture.caster_uuid].last_visual_position==[46,18],label+": sorcerer reaches the recorded Gallery centre")
    var missing:Dictionary={}
    for row in index.rows:
        if row.get("status")=="missing":missing[row.label]=int(missing.get(row.label,0))+1
    evidence.append({"perspective":side.id,"duration_ms":index.duration_ms,"groups":index.groups.size(),"rows":index.rows.size(),"phase_roles":phase_counts,"positive_damage":positive.size(),"shield_contacts":blocked.size(),"damage_timings":damage_times,"missing_rows":missing,"elapsed_ms":Time.get_ticks_msec()-started})
    print("GALLERY_SPELL_STREAM ",JSON.stringify(evidence.back()))

func run()->void:
    native="--native" in OS.get_cmdline_user_args()
    qualify_fixture()
    if not ["--startup-only","--monument-only","--fireball-framing-only"].any(func(flag):return flag in OS.get_cmdline_user_args()):
        for side in fixture.perspectives:qualify_stream(side)
    if native and failures.is_empty():await native_run()
    finish()

func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func settle_native(label:String)->bool:
    var deadline:int=Time.get_ticks_msec()+120000
    while Time.get_ticks_msec()<deadline:
        if not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0 and studio.pending_directory.is_empty() and studio.world.playback_prepared():
            studio.world.timeline.paused=true
            await frame()
            check(studio.world.presentation_errors.is_empty(),label+": displayed world has no presentation errors")
            return true
        await process_frame
    check(false,label+": Studio publishes within the finite readiness budget; "+studio.status.text)
    return false

func find_study(item:TreeItem)->TreeItem:
    if item==null:return null
    var metadata=item.get_metadata(0)
    if metadata is Dictionary and metadata.scenario.get("id")=="gallery.sorcerer_expedition":return item
    for child in item.get_children():
        var found:TreeItem=find_study(child)
        if found!=null:return found
    return null

func open_gallery()->bool:
    studio._show_study_library()
    var panel:Window=studio.study_library
    var deadline:int=Time.get_ticks_msec()+60000
    while not panel.is_prepared() and Time.get_ticks_msec()<deadline:await process_frame
    check(panel.is_prepared() and panel.error.is_empty(),"Actual capability Library is ready for GAL01")
    if not panel.is_prepared():return false
    var item:TreeItem=find_study(panel.tree.get_root())
    check(item!=null,"Actual Library contains the GAL01 Gallery study")
    if item==null:return false
    var parent:TreeItem=item.get_parent()
    while parent!=null:parent.collapsed=false;parent=parent.get_parent()
    panel.tree.scroll_to_item(item,true);await process_frame
    var rect:Rect2=panel.tree.get_item_area_rect(item,0)
    var point:Vector2=panel.tree.global_position+rect.position+Vector2(minf(100,rect.size.x*.5),rect.size.y*.5)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;event.global_position=point
        panel.push_input(event,true)
    await process_frame
    if not await settle_native("Gallery Library selection"):return false
    check(not panel.visible and studio.active_case.id==fixture.id and studio.study_scenario.id=="gallery.sorcerer_expedition","Library selection publishes the actual Gallery study and closes the browser")
    return studio.active_case.id==fixture.id

func camera_observation()->Dictionary:
    var visual:Dictionary=studio.world.visual_actors.get(fixture.caster_uuid,{})
    if visual.is_empty() or not visual.get("valid",false):return {}
    if not visual.entries.any(func(entry):return entry.node.visible):return {}
    var point:Vector3=Placement.contact(visual.row)
    var screen:Vector2=studio.world.camera.unproject_position(point)
    var rect:Rect2=studio.world.get_viewport().get_visible_rect()
    return {"at_ms":studio.world.timeline.display_ms,"world":[point.x,point.y,point.z],
        "focus":[studio.world.camera_focus.x,studio.world.camera_focus.y,studio.world.camera_focus.z],
        "screen":[screen.x,screen.y],"viewport":[rect.size.x,rect.size.y],
        "visible":not studio.world.camera.is_position_behind(point) and rect.has_point(screen)}

func source_pixels(image:Image)->int:
    image.convert(Image.FORMAT_RGBA8)
    var bytes:PackedByteArray=image.get_data();var pixels:int=0
    for i in range(0,bytes.size(),4):
        if maxi(bytes[i],maxi(bytes[i+1],bytes[i+2]))>2:pixels+=1
    return pixels

func native_run()->void:
    check(DisplayServer.get_name()!="headless","Native Gallery qualification uses the actual renderer")
    if DisplayServer.get_name()=="headless":return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.gui_embed_subwindows=true;root.size=Vector2i(1280,800)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    studio=Studio.new();studio.loop_enabled=false;studio.follow_actor_id=fixture.caster_uuid;root.add_child(studio)
    if not await settle_native("Initial Studio"):await close_native();return
    var dimensions:Array=[]
    for host in [studio.world]:
        for path in host.source_images:
            var source:Image=host.source_images[path]
            if source.get_width()>16384 or source.get_height()>16384:
                dimensions.append({"path":path,"width":source.get_width(),"height":source.get_height(),"required":host.media_plan.get("required",{}).has(path),"environment":host.media_environment_required.has(path),"cpu_required":host.media_warmup.cpu_required.has(path)})
    native_evidence.oversized_sources=dimensions
    native_evidence.startup_only="--startup-only" in OS.get_cmdline_user_args()
    print("GALLERY_SOURCE_DIMENSIONS ",JSON.stringify(dimensions))
    FileAccess.open("res://.runtime/gallery-source-dimensions.json",FileAccess.WRITE).store_string(JSON.stringify(dimensions,"  "))
    if "--startup-only" in OS.get_cmdline_user_args():await close_native();return
    if "--monument-only" in OS.get_cmdline_user_args():
        await qualify_final_monument();await close_native();return
    if "--fireball-framing-only" in OS.get_cmdline_user_args():
        await qualify_fireball_framing();await close_native();return
    if not await open_gallery():await close_native();return
    studio.follow_actor_id=fixture.caster_uuid
    studio.loop_enabled=false;studio.loop_button.set_pressed_no_signal(false)
    studio._seek(0)
    if not await settle_native("Gallery initialization"):await close_native();return
    check(is_zero_approx(studio.world.timeline.display_ms),"Full expedition starts at its real initialization")
    var started:int=Time.get_ticks_msec();var deadline:int=started+240000
    var end:float=studio.index.presentation_end_ms
    var prior:float=0;var samples:int=0;var offscreen:Array=[];var native_pixels:Dictionary={};var native_seen:Dictionary={};var errors:Dictionary={};var camera_samples:Array=[]
    var next_camera:float=0;var next_progress:int=started+10000
    studio.play_button.pressed.emit()
    while Time.get_ticks_msec()<deadline and studio.world.timeline.display_ms<end-.001:
        await frame()
        var now:float=studio.world.timeline.display_ms
        if now+0.001<prior:errors["Full run moved backwards without an enabled loop"]=true
        prior=now;samples+=1
        for issue in studio.world.presentation_errors:errors[str(issue)]=true
        var camera:Dictionary=camera_observation()
        if not camera.is_empty():
            if not camera.visible and offscreen.size()<20:offscreen.append(camera)
            if now>=next_camera:camera_samples.append(camera);next_camera=now+1000
        var presenter=studio.world.component_renderer.native_spells
        for component in studio.world.displayed_components:
            if not component.get("native_spell",false):continue
            native_seen[component.id]=component.spell_id
            if native_pixels.has(component.spell_id) or float(component.age_ms)<100:continue
            var handle:Dictionary=presenter.handles.get(component.id,{})
            var group:Dictionary=presenter.groups.get(handle.get("group_key",""),{})
            if group.is_empty():continue
            var image:Image=group.viewport.get_texture().get_image()
            var count:int=source_pixels(image)
            if count<=0:continue
            native_pixels[component.spell_id]={"at_ms":now,"source_pixels":count,"source":component.source_id}
            image.save_png(CAPTURES.path_join(component.spell_id+"-native.png"))
            root.get_texture().get_image().save_png(CAPTURES.path_join(component.spell_id+"-studio.png"))
        if Time.get_ticks_msec()>=next_progress:
            print("GALLERY_NATIVE_PROGRESS ",JSON.stringify({"at_ms":now,"end_ms":end,"sources":native_pixels.keys(),"errors":errors.keys()}));next_progress=Time.get_ticks_msec()+10000
    studio.world.timeline.paused=true
    check(studio.world.timeline.display_ms>=end-.001,"Full native Studio playback reaches the recorded final boundary")
    check(errors.is_empty(),"Complete native expedition has no presentation/clock errors: "+str(errors.keys()))
    check(offscreen.is_empty() and camera_samples.size()>10,"Explicit actor follow keeps the sorcerer visible throughout the large-map excursion")
    check(studio.world.timeline.state==canonical[studio.active_perspective],"Native playback finishes at its own canonical faction state")
    for spell in SPELLS+["shield"]:check(native_pixels.has(spell),"Full expedition submits actual native source pixels for "+spell)
    await frame();root.get_texture().get_image().save_png(CAPTURES.path_join("complete-studio.png"))
    native_evidence={"frames":samples,"elapsed_ms":Time.get_ticks_msec()-started,"end_ms":end,"native_pixels":native_pixels,"occurrences_seen":native_seen.size(),"camera_samples":camera_samples,"offscreen_samples":offscreen,"errors":errors.keys(),"paired":false}
    var rows:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_spell",false))
    var selected:Array=rows.filter(func(row):return row.component.spell_id=="fireball" and row.component.native_cue.role=="area" and row.get("source_perspective",studio.active_perspective)==studio.active_perspective)
    check(selected.size()==1,"Actual run exposes one Fireball area source row for seek/loop inspection")
    if not selected.is_empty():await qualify_transport(selected[0])
    await close_native()

func qualify_fireball_framing()->void:
    check(is_equal_approx(studio.initial_view_size,12.0),"The framing fixture receives --view-size=12 through normal Studio CLI parsing")
    check(studio.follow_tracks,"The framing fixture receives --follow-tracks through normal Studio CLI parsing")
    var selected:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spell_id")=="fireball" and row.component.native_cue.role=="area" and row.get("source_perspective",studio.active_perspective)==studio.active_perspective)
    check(selected.size()==1,"The real Fireball area occurrence supplies the framing clock")
    if selected.size()!=1:return
    var row:Dictionary=selected[0]
    var at:float=row.start_ms+150.0
    studio._select_row(row);studio.tracks.reveal(row.id);studio._seek(at)
    if not await settle_native("Fireball framing impact+150ms"):return
    await frame();await frame()
    var observations:Array=[]
    for host in [studio.world]:
        check(is_equal_approx(host.camera.size,12.0),"Authored startup view size is installed in each actual pane")
        var components:Array=host.displayed_components.filter(func(component):return component.get("native_spell",false) and component.get("spell_id")=="fireball" and component.native_cue.role=="area")
        check(components.size()==1,"Each pane actually displays the same admitted Fireball area occurrence")
        if components.size()!=1:continue
        var component:Dictionary=components[0]
        var viewport:Rect2=host.get_viewport().get_visible_rect()
        var center:Vector3=Vector3(component.to_position[0],component.get("to_elevation_feet",0)/5.0*Placement.HEIGHT_UNIT,component.to_position[1])
        var target:Vector2=host.camera.unproject_position(center)
        var caster:Vector2=host.camera.unproject_position(Placement.contact(host.visual_actors[fixture.caster_uuid].row))
        var bounds:Rect2=Rect2(target,Vector2.ZERO)
        var positions:Array=component.get("resolved_area_positions",[])
        check(component.area_geometry.shape=="sphere" and component.area_geometry.radius_feet==20 and positions.size()==49,"Framing bounds come from the actual20ft Fireball and49 disclosed affected tiles")
        for position in positions:
            var tile:Dictionary=host.timeline.state.tiles.get("%d,%d"%position,{})
            var elevation:float=tile.get("elevation_steps",component.get("to_elevation_feet",0)/5.0)*Placement.HEIGHT_UNIT
            for offset in [Vector2(-.5,-.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(.5,.5)]:
                bounds=bounds.expand(host.camera.unproject_position(Vector3(position[0]+offset.x,elevation,position[1]+offset.y)))
        check(viewport.has_point(caster),"Followed caster is visible at Fireball impact")
        check(viewport.has_point(target),"Authoritative Fireball target center is visible")
        check(viewport.encloses(bounds),"All disclosed Fireball area tile bounds fit the pane: "+str(bounds)+" within "+str(viewport))
        observations.append({"camera_size":host.camera.size,"caster":[caster.x,caster.y],"target":[target.x,target.y],"area_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"viewport":[viewport.size.x,viewport.size.y]})
    root.get_texture().get_image().save_png(CAPTURES.path_join("fireball-framing-studio.png"))
    studio._seek(0)
    if not await settle_native("Fireball framing reverse seek"):return
    for host in [studio.world]:check(is_equal_approx(host.camera.size,12.0),"Reverse seek retains the requested view size")
    studio._seek(at)
    if not await settle_native("Fireball framing repeated seek"):return
    for host in [studio.world]:check(is_equal_approx(host.camera.size,12.0),"Repeated seek retains the requested view size")
    native_evidence.framing={"at_ms":at,"panes":observations,"capture":CAPTURES.path_join("fireball-framing-studio.png")}

func qualify_final_monument()->void:
    studio.follow_actor_id=""
    studio._seek(studio.index.presentation_end_ms)
    if not await settle_native("Final Gallery monument"):return
    var proof:Array=[]
    for host in [studio.world]:
        var monuments:Array=host.world_groups.values().filter(func(group):return group.row.get("asset")=="environment.furniture.slender_monument" and group.row.get("destroyed",false))
        check(monuments.size()==1,"Final recorded state retains the one actually destroyed monument")
        if monuments.is_empty():continue
        var monument:Dictionary=monuments[0]
        var entries:Array=monument.entries.filter(func(entry):return entry.role!="shadow")
        check(not entries.is_empty(),"Destroyed monument has actual receiving geometry")
        for entry in entries:
            var record:Dictionary=entry.record
            check(record.frame==97,"Actual native instance uses destruction frame97")
            for region in [record.geometry_region,record.normal.region]:
                check(host.textures.has(region.path),"Actual destroyed source texture is resident: "+region.path)
                if not host.textures.has(region.path):continue
                var texture:Texture2D=host.textures[region.path]
                check(texture.get_width()==1536 and texture.get_height()==768,"Native settled texture is one exact bounded numeric page")
                check(texture.get_width()<=host.maximum_texture_size_2d and texture.get_height()<=host.maximum_texture_size_2d,"Queried device limit admits the actual resident texture")
                proof.append({"path":region.path,"rect":region.rect,"frame":record.frame,"width":texture.get_width(),"height":texture.get_height(),"device_limit":host.maximum_texture_size_2d})
        host.camera_focus=Placement.contact(monument.row);host.camera.size=8.0;host.position_camera()
        check(host.presentation_errors.is_empty(),"Final destroyed monument host has no media/presentation errors")
    await frame();await frame()
    root.get_texture().get_image().save_png(CAPTURES.path_join("final-monument-studio.png"))
    native_evidence.monument={"at_ms":studio.world.timeline.display_ms,"sources":proof,"capture":CAPTURES.path_join("final-monument-studio.png")}

func qualify_transport(row:Dictionary)->void:
    var at:float=lerpf(row.start_ms,row.end_ms,.35)
    studio._select_row(row);studio.tracks.reveal(row.id);studio._seek(at)
    if not await settle_native("Gallery Fireball seek"):return
    check(studio.world.component_renderer.native_spells.handles.has(row.component.id),"Seek reconstructs the real Fireball source occurrence")
    check(camera_observation().get("visible",false),"Actor follow stays valid after seeking into a later spell")
    var preview:Dictionary=studio.tracks.prepare_visible()
    var deadline:int=Time.get_ticks_msec()+60000
    while preview.pending>0 and Time.get_ticks_msec()<deadline:await process_frame;preview=studio.tracks.prepare_visible()
    check(preview.ready and preview.errors.is_empty(),"Real Gallery spell tracks publish source previews across all camera quarters")
    native_evidence.selected_previews=preview
    studio._seek(0)
    if not await settle_native("Gallery reverse seek"):return
    check(studio.world.displayed_components.all(func(component):return not component.get("native_spell",false)),"Reverse seek to initialization leaves no later native effect")
    studio._seek(at)
    if not await settle_native("Gallery repeated seek"):return
    check(studio.world.component_renderer.native_spells.handles.has(row.component.id),"Repeated seek reconstructs the same recorded source")
    studio._play_clip(row)
    deadline=Time.get_ticks_msec()+120000
    var previous:float=studio.world.timeline.display_ms;var entered:bool=false;var wrapped:bool=false
    while Time.get_ticks_msec()<deadline and not wrapped:
        await process_frame
        var now:float=studio.world.timeline.display_ms
        if now>row.start_ms+10:entered=true
        if entered and now<previous-.001 and previous>=row.end_ms-.01:wrapped=true
        previous=now
    check(wrapped,"Actual Studio clip transport loops the recorded Fireball source at its authored boundaries")
    studio.loop_enabled=false;studio.loop_button.set_pressed_no_signal(false);studio.world.timeline.paused=true
    native_evidence.loop={"row":row.id,"start_ms":row.start_ms,"end_ms":row.end_ms,"wrapped":wrapped}
    await frame();root.get_texture().get_image().save_png(CAPTURES.path_join("fireball-loop-studio.png"))

func close_native()->void:
    if studio!=null:studio.queue_free();await frame();await frame()

func finish()->void:
    var report={"checks":checks,"failures":failures,"perspectives":evidence,"native":native_evidence,
        "scope":"Real Gallery sorcerer60-command capture, both original streams, shared Studio/reducer parity, ordered spell/damage/reaction/destruction ownership and native Studio playback only when requested. No artistic approval or fabricated events."}
    FileAccess.open(REPORT+("-framing" if "--fireball-framing-only" in OS.get_cmdline_user_args() else "-monument" if "--monument-only" in OS.get_cmdline_user_args() else "-startup" if "--startup-only" in OS.get_cmdline_user_args() else "-native" if native else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_GALLERY_SPELL ",checks," / ",failures.size());quit(0 if failures.is_empty() else 1)
