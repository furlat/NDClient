extends "res://tests/native_vampiric_touch_render_checks.gd"
## Original explicit spell cohort, current real case IDs and native Play.
## The old handcounted export/layout matrix is retired. Every actual indexed
## source occurrence below still needs canonical ownership and native pixels;
## source presence, scenario admission and user approval remain separate.
const Library=preload("res://studio/case_library.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const NativeAuthoring=preload("res://presentation/native_spell_authoring.gd")
const EXPECTED=["acid_splash","chill_touch","eldritch_blast","fire_bolt","fireball","guiding_bolt","ice_knife","magic_missile","poison_spray","produce_flame","ray_of_frost","scorching_ray","sleep","web","bane","command","mage_armor","sanctuary","shield","shocking_grasp","burning_hands","thunderwave","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike","aid","bless","false_life","sacred_flame"]
const EXTRA_CASES=["spell.shield/reaction"]
var unexercised:Array=[]
var selected_cases:Array=[]
var only_case:String=""

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(800,600)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only-case="):only_case=argument.trim_prefix("--only-case=")
    check(DisplayServer.get_name()!="headless","Spell cohort requires actual native output, not a static catalog-only pass")
    if DisplayServer.get_name()=="headless":finish();return
    var records:Array=Library.read()
    var requested:Array=EXPECTED.map(func(id):return "spell."+id+"/baseline")+EXTRA_CASES
    for id in requested:
        var matches:Array=records.filter(func(record):return record.id==id)
        check(matches.size()==1,"One exact current original cohort recording: "+id)
        if matches.size()!=1:continue
        var record:Dictionary=matches[0]
        check(record.ready and record.perspectives.size()==2,id+": both independent original audiences are selectable")
        if not record.ready:continue
        if not only_case.is_empty() and id!=only_case:unexercised.append(id);continue
        selected_cases.append(id)
        var spell:String=id.get_slice("/",0)
        for perspective in record.perspectives:await inspect_case(record,perspective,spell)
    check(not selected_cases.is_empty(),"Requested actual native cohort is nonempty")
    for record in records:
        if record.kind=="spell" and record.id not in selected_cases and record.id not in unexercised:unexercised.append(record.id)
    finish()

func inspect_case(record:Dictionary,perspective:Dictionary,spell:String)->void:
    var label:String=record.id+" / "+perspective.id
    var failures_before:int=failures.size()
    var index:Dictionary=Recording.read(perspective.journal)
    check(index.ok,label+": complete original journal builds Studio index")
    if not index.ok:return
    var canonical=Journal.new()
    var admitted:Dictionary=canonical.open(perspective.journal,true,true)
    check(admitted.ok,label+": independently admitted public journal")
    if not admitted.ok:return
    var state:Dictionary=index.initialization.state.duplicate(true)
    var events:Dictionary={};var actual_conditions:Dictionary={};var actual_spatial:Dictionary={}
    for wrapped in index.groups:
        var group:Dictionary=wrapped.group;var previous:float=-1.0
        for event in group.events:events[str(event.event_uuid)]=true
        for commit in group.commits:
            check(commit.at_ms>=previous,label+": actual commits remain chronologically ordered")
            previous=commit.at_ms
            for row in commit.get("condition_rows",[]):
                if row.before==null and row.after!=null:actual_conditions[row.after.condition_uuid]=true
            Compiler.apply_delta(state,commit.delta)
            if state.get("senses")!=null:
                for id in state.senses.get("spatial_effects",{}):actual_spatial[id]=true
    check(state==canonical.state,label+": all indexed commits reproduce the independent canonical after-value")
    for moment in record.get("moments",[]):
        if moment.get("faction","amber")!=perspective.id:continue
        var sequence:int=int(moment.sequence);var occurrence:int=int(moment.occurrence)
        var matches:Array=index.rows.filter(func(row):return row.kind=="event" and int(row.event.sequence)==sequence and (int(row.event.event_uuid)==occurrence or row.event.get("versions",[]).any(func(version):return int(version.occurrence)==occurrence)))
        check(not matches.is_empty(),label+": recorded inventory moment belongs to this actual faction's event prefix")
    var selected:Dictionary=NativeAuthoring.selection(spell,index.cache)
    if spell in Library.REJECTED:
        var authored:Resource=load("res://authoring/abilities/spells/"+spell+".tres")
        check(authored!=null and not authored.native_staging and selected.is_empty(),label+": rejected presentation remains explicitly disabled in its typed source")
        evidence.append({"case":record.id,"spell_id":spell,"perspective":perspective.id,"operations":index.operations,
            "source_status":"native_staging_disabled","scenario_status":record.scenario_status,"presentation_status":"missing",
            "approval_status":"rejected","gaps":[{"reason":"user_rejected_presentation_not_migrated"}]})
        return
    check(not selected.is_empty(),label+": engine spell resolves its actual typed presentation selection")
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("native_spell",false) and row.component.get("spell_id")==selected.get("id"))
    check(not rows.is_empty(),label+": actual spell exposes indexed native source work")
    var sources:Dictionary={};var roles:Dictionary={};var owners:Dictionary={};var gaps:Array=[]
    var view=SubViewport.new();view.size=Vector2i(800,600);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true;world.media_warmup.budget_bytes=0
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.playback_end_ms=index.presentation_end_ms
    world.component_renderer.audio.set_enabled(false);view.add_child(world)
    for row in rows:
        var component:Dictionary=row.component
        sources[str(component.source_id)]=true;roles[component.native_cue.role]=int(roles.get(component.native_cue.role,0))+1
        if component.get("persistent_owner",false):
            var condition:Variant=component.get("condition_uuid");var spatial:Variant=component.get("spatial_effect_uuid")
            check(actual_conditions.has(condition) or actual_spatial.has(spatial),label+": persistent native occurrence has a real disclosed UUID admission")
            owners[component.id]=condition if condition!=null else spatial
        else:check(events.has(str(component.source_event_uuid)),label+": finite source belongs to an actual local event")
        check(component.status=="available" and not component.native_clip.is_empty(),label+": actual native phase has an installed source, not a placeholder")
        if component.status!="available" or component.native_clip.is_empty():
            gaps.append({"id":component.id,"reason":component.get("reason","source_missing")});continue
        var expected:PackedByteArray=var_to_bytes(component)
        var end:float=minf(float(row.end_ms),float(index.presentation_end_ms))
        check(end>float(row.start_ms),label+": actual source has a nonempty recorded interval")
        if end<=float(row.start_ms):continue
        var visible:int=0;var drawn:Array=[]
        # Source envelopes can have authored leading/tail silence. Both sample
        # clocks are inside this actual indexed interval; no source is replaced
        # merely because one legitimate phase sample has empty native pixels.
        for fraction in [.10,.35,.65]:
            var at:float=lerpf(float(row.start_ms),end,fraction)
            world.install_playback(Recording.restore(index,at))
            if not await settle(world,component.id):break
            var restored:RefCounted=Recording.restore(index,at)
            check(world.timeline.state==restored.state,label+": native seek displays the exact independently restored original prefix")
            var native=world.component_renderer.native_spells
            check(native.handles.has(component.id),label+": indexed source obtains its actual native occurrence owner")
            if not native.handles.has(component.id):continue
            var handle:Dictionary=native.handles[component.id]
            check(str(handle.clip.id)==str(component.native_clip.id),label+": actual renderer uses the exact indexed Factory clip")
            var bindings:Dictionary=native.diagnostics.get(component.id,{}).get("input_bindings",{})
            check(bindings.get("unavailable",{}).is_empty(),label+": actual source has no fabricated or unresolved required inputs")
            var actor:Dictionary=world.visual_actors.get(component.get("target_uuid"),world.visual_actors.get(component.actor_uuid,{}))
            if not actor.is_empty():world.camera_focus=Play.Placement.contact(actor.row);world.initial_focus=true
            world.camera.size=4.5;world.position_camera();world.grid_visible=false
            await frame();await frame();world.set_process(false)
            var canonical_bytes:PackedByteArray=var_to_bytes(world.timeline.state)
            var shown:Image=view.get_texture().get_image()
            var was_visible:bool=handle.root.visible
            handle.root.hide();await frame();await frame()
            var hidden:Image=view.get_texture().get_image();var pixels:int=changed(shown,hidden)
            # Concurrent beams/contacts can exactly overlap or saturate. Keep
            # their final-world contribution diagnostic, then independently
            # expose this same submitted source without its sibling geometry.
            # No owner, source age, root placement, material or light is rebuilt.
            var siblings:Array=[];var seen:Dictionary={}
            for other in native.handles.values():
                var node:Node3D=other.root
                if node==handle.root or seen.has(node.get_instance_id()):continue
                seen[node.get_instance_id()]=true;siblings.append([node,node.visible]);node.hide()
            handle.root.visible=was_visible;await frame();await frame()
            var isolated:Image=view.get_texture().get_image()
            handle.root.hide();await frame();await frame()
            var isolated_pixels:int=changed(isolated,view.get_texture().get_image())
            handle.root.visible=was_visible
            for sibling in siblings:sibling[0].visible=sibling[1]
            visible=maxi(visible,maxi(pixels,isolated_pixels));drawn.append({"at_ms":at,"changed_pixels":pixels,"isolated_pixels":isolated_pixels,"source_visible":was_visible,"inputs":bindings})
            check(var_to_bytes(world.timeline.state)==canonical_bytes and var_to_bytes(component)==expected,label+": drawing/hiding preserves canonical state and immutable source operands")
            world.set_process(true)
        check(visible>0,label+": exact indexed source contributes actual native framebuffer pixels: "+component.id)
        if visible==0:gaps.append({"id":component.id,"reason":"no_native_pixels","clip":component.native_clip.id,"cue":component.native_cue,"samples":drawn})
    check(world.presentation_errors.is_empty() and world.media_issue.is_empty(),label+": all real source seeks have no runtime/resource errors")
    world.component_renderer.native_spells.close(world);view.queue_free();await frame();await frame()
    evidence.append({"case":record.id,"spell_id":spell,"perspective":perspective.id,"operations":index.operations,"native_sources":sources.keys(),
        "roles":roles,"persistent_instances":owners,"native_rows":rows.size(),"gaps":gaps,"duration_ms":index.presentation_end_ms,
        "source_status":"actual_installed_sources_checked","scenario_status":record.scenario_status,"presentation_status":"native_pixels_checked" if gaps.is_empty() and not rows.is_empty() and failures.size()==failures_before else "gaps",
        "approval_status":"rejected" if spell in Library.REJECTED else "needs_review"})

func finish()->void:
    var report:Dictionary={"checks":checks,"failures":failures,"cases":evidence,"selected_cases":selected_cases,"unexercised_current_cases":unexercised,
        "legacy_scope_gaps":["Old native-spell-shield-ranged and native-spell-shield-walk IDs are absent from the current Library; current spell.shield/baseline and /reaction both prove real Magic Missile interruption, not a new ranged-attack/movement recording."],
        "scope":"Explicit original34 spell baseline cohort plus actual Shield reaction; independent original faction journals/canonical commits/source UUID ownership and each indexed native source's actual Play output. Current role counts are reported from actual cases rather than frozen old-export handcounts. All189 live/native safety remains separate; neither source presence nor this technical gate accepts artwork."}
    FileAccess.open("res://generated/studio_spell_batch_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SPELL_BATCH ",JSON.stringify({"checks":checks,"failures":failures,"selected_cases":selected_cases,"unexercised":unexercised.size()}));quit(0 if failures.is_empty() else 1)
