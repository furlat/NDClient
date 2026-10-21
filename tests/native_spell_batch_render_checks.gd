extends "res://tests/native_spell_playback_checks.gd"
## Whole imported batch through the real Studio restore and production renderer.
const Effects=preload("res://presentation/effect_package.gd")
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const BASELINES=["acid_splash","chill_touch","eldritch_blast","fire_bolt","fireball","guiding_bolt","ice_knife","magic_missile","poison_spray","produce_flame","ray_of_frost","scorching_ray","sleep","web","bane","command","mage_armor","sanctuary","shield","shocking_grasp","burning_hands","thunderwave","cure_wounds","healing_word","guidance","resistance","light","thaumaturgy","shield_of_faith","true_strike","aid","bless","false_life","sacred_flame"]
## Map duties to actual original cases, without requiring historical case names.
const SHIELD_CONTROLS=[
    {"id":"native-spell-shield-ranged","case":"spell.shield/ranged_attack_lifecycle","duty":"ranged"},
    {"id":"native-spell-shield-walk","case":"interaction.gallery/sorcerer","duty":"opportunity_walk"}]
var missing_originals:Array=[]
var selected_cases:Array=[]
var results:Array=[]
var control_evidence:Array=[]
var sample_fraction:float=.5
func _initialize()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    run.call_deferred()
func run()->void:
    DirAccess.make_dir_recursive_absolute("res://.captures/native-spell-batch")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var records:Array=Library.read()
    var only:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only=argument.trim_prefix("--only=")
        if argument.begins_with("--sample-fraction="):sample_fraction=float(argument.trim_prefix("--sample-fraction="))
    for short_id in BASELINES:
        var id:String="spell."+short_id
        if not only.is_empty() and short_id not in only.split(",") and id not in only.split(","):continue
        var matches:Array=records.filter(func(record):return record.id==id+"/baseline")
        check(matches.size()==1,id+": exact current baseline is present in the one Library")
        if matches.size()!=1:missing_originals.append(id+"/baseline");continue
        var original:Dictionary=matches[0]
        check(original.ready and original.perspectives.size()==2,id+": both independent original seats remain available")
        if not original.ready:missing_originals.append(original.id);continue
        var item:Dictionary=original.duplicate();item.spell_id=id
        selected_cases.append(item.id);await inspect_spell(item)
    for control in SHIELD_CONTROLS:
        if not only.is_empty() and not ["shield","spell.shield",control.id,control.case].any(func(id):return id in only.split(",")):continue
        await inspect_shield_control(records,control)
    check(not selected_cases.is_empty(),"Every requested supported subset includes an actual current original")
    finish()

func inspect_shield_control(records:Array,control:Dictionary)->void:
    var matches:Array=records.filter(func(record):return record.id==control.case)
    check(matches.size()==1 and matches[0].ready and matches[0].perspectives.size()==2,
        control.id+": the actual original and both independent seats are available")
    if matches.size()!=1 or not matches[0].ready or matches[0].perspectives.size()!=2:
        missing_originals.append(control.id);return
    var record:Dictionary=matches[0]
    var duties:Array=[]
    var witnesses:Dictionary={}
    for perspective in record.perspectives:
        var actual:Dictionary=shield_duty(perspective.journal,control.duty)
        duties.append(actual.merged({"perspective":perspective.id}))
        witnesses[perspective.id]=actual
        check(actual.ready,control.id+" "+perspective.id+": actual own Shield, incoming attack and real resumed/retired movement are recorded: "+str(actual))
    control_evidence.append({"control":control.id,"case":record.id,"engine":record.engine,"duties":duties})
    if duties.any(func(duty):return not duty.ready):missing_originals.append(control.id);return
    selected_cases.append(record.id)
    for perspective in record.perspectives:
        var item:Dictionary=record.duplicate();item.spell_id="spell.shield"
        item.perspectives=[perspective];item.shield_control=control.id
        item.shield_condition_uuid=witnesses[perspective.id].condition_uuid
        await inspect_spell(item)

## Read original public completion facts using that journal's admitted decoder.
## A case name or unjoined Shield membership cannot prove either incoming duty.
func shield_duty(directory:String,duty:String)->Dictionary:
    var journal=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    if not opened.ok:return {"ready":false,"reason":"journal_unavailable","journal":directory}
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var rows:Array=[];var applications:Dictionary={};var removals:Dictionary={}
    for file in files:
        if not file.ends_with(".json") or file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename())
        if sequence==0:continue
        var decoded:Dictionary=journal.decode_record(sequence,FileAccess.get_file_as_bytes(directory.path_join(file)))
        if not decoded.ok:return {"ready":false,"reason":"original_packet_refused","sequence":sequence,"journal":directory}
        for lineage in decoded.value.lineages:
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if node.get("canceled",false) or node.get("phase")!="completion" or fact==null:continue
                var row:Dictionary={"order":rows.size(),"sequence":sequence,"lineage":lineage.lineage,"node":node,"fact":fact}
                rows.append(row)
                if fact.kind!="actor_change":continue
                for actor in fact.get("actors",[]):
                    for change in actor.rows:
                        if change.field!="condition":continue
                        var identity:String=str(change.condition_uuid)
                        var member:Variant=change.get("member")
                        if member!=null and member.get("behavior_id")=="condition.spell.shield" and not applications.has(identity):
                            applications[identity]=row.merged({"actor_uuid":str(actor.actor_uuid)})
                        elif member==null and not removals.has(identity):removals[identity]=row.merged({"actor_uuid":str(actor.actor_uuid)})
    for attack in rows:
        var fact:Dictionary=attack.fact
        if fact.kind!="attack" or fact.get("intercepted_by_condition_uuid")==null or fact.get("source_item_uuid")==null:continue
        if fact.get("attack_source_kind")!="equipped" or fact.get("attack_outcome")!="Miss":continue
        var ranged:bool=duty=="ranged"
        if ranged and (str(fact.get("behavior_id","")).is_empty() or fact.get("weapon_slot") not in ["RANGED_MAIN","RANGED_OFF"]):continue
        if not ranged and fact.get("behavior_id")!="reaction.opportunity_attack":continue
        var identity:String=str(fact.intercepted_by_condition_uuid)
        var actor:String=str(fact.get("target_entity_uuid",""))
        var application:Dictionary=applications.get(identity,{})
        var removal:Dictionary=removals.get(identity,{})
        if application.is_empty() or removal.is_empty() or application.actor_uuid!=actor or removal.actor_uuid!=actor \
            or application.order>attack.order or removal.order<=attack.order:continue
        if not attack.node.get("content_attributions",[]).any(func(row):return row.get("role")=="effective_handler" \
            and row.get("behavior_id")=="reaction.spell.shield" and row.get("source_entity_uuid")==actor and row.get("outcome")=="modified_event"):continue
        for step in rows:
            if step.order<=(removal.order if ranged else attack.order) or step.fact.kind!="step" \
                or step.fact.get("source_entity_uuid")!=actor or not step.fact.get("committed",false) \
                or step.fact.get("from_position")==step.fact.get("to_position"):continue
            if not ranged and (step.sequence!=attack.sequence or step.lineage!=attack.lineage):continue
            for movement in rows:
                if movement.order<=step.order or movement.sequence!=step.sequence or movement.lineage!=step.lineage \
                    or movement.fact.kind!="movement" or movement.fact.get("source_entity_uuid")!=actor:continue
                return {"ready":true,"journal":directory,"condition_uuid":identity,"actor_uuid":actor,
                    "source_item_uuid":fact.source_item_uuid,"weapon_slot":fact.weapon_slot,"attack_behavior_id":fact.behavior_id,
                    "application_occurrence":application.node.occurrence,"attack_occurrence":attack.node.occurrence,
                    "attack_sequence":attack.sequence,"attack_lineage":attack.lineage,
                    "step_occurrence":step.node.occurrence,"movement_occurrence":movement.node.occurrence,
                    "removal_occurrence":removal.node.occurrence}
    return {"ready":false,"reason":"exact_shield_"+duty+"_join_not_recorded","journal":directory}

func inspect_spell(item:Dictionary)->void:
    var index=Recording.read(item.perspectives[0].journal)
    check(index.ok,item.spell_id+": actual Studio index loads")
    if not index.ok:return
    # Preserve the package selection ID, distinct from the canonical behavior/case ID.
    var source_id:String=item.spell_id.trim_prefix("spell.")
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("native_spell",false) and row.component.get("spell_id")==source_id and row.kind=="native_effect" \
        and (not item.has("shield_condition_uuid") or row.component.get("condition_uuid")==item.shield_condition_uuid))
    check(not rows.is_empty(),item.spell_id+": Studio exposes native source tracks")
    if rows.is_empty():return
    var view=SubViewport.new();view.size=Vector2i(960,640);view.own_world_3d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var world=Play.new();world.external_playback=true;world.external_clock=true
    world.catalog_cache=Play.Catalog.source_snapshot(index.cache);world.media_warmup.budget_bytes=0
    view.add_child(world);world.install_playback(Recording.restore(index,0))
    if not await settle(world,item.spell_id+" initial"):
        view.queue_free();await frame();return
    world.camera_focus=Vector3(6,.5,7);world.initial_focus=true;world.camera.size=12
    world.position_camera();world.wall_mode="hidden";world.update_wall_visibility()
    var visited:Dictionary={}
    var counts:Dictionary={}
    var native_pixels:int=0
    for row in rows:
        var component:Dictionary=row.component
        var key:String=str(component.native_clip.id)+":"+str(component.native_cue.role)+":"+str(component.get("persistent_owner",false))+":"+str(row.get("condition_phase",""))
        if visited.has(key):continue
        visited[key]=true
        var at:float=representative_time(row)
        if component.native_cue.role=="flight":at=row.start_ms+(component.native_cue.launch+component.native_cue.contact)*500.0
        if row.end_ms<=row.start_ms:continue
        check(world.try_reset_hidden_playback(Recording.restore(index,at)),item.spell_id+": seek publishes independent owner state")
        if not await settle(world,item.spell_id+" "+key):break
        if item.has("shield_control"):
            var recipient:Dictionary=world.visual_actors.get(component.get("target_uuid",component.actor_uuid),{}).get("row",{})
            check(not recipient.is_empty(),item.shield_control+": actual disclosed recipient supplies control framing")
            if recipient.is_empty():break
            world.camera_focus=Sockets.Placement.contact(recipient)+Vector3(0,.5,0)
            world.position_camera()
            if not await settle(world,item.shield_control+" current recipient view"):break
        await frame();await frame()
        var native=world.component_renderer.native_spells
        var active=world.displayed_components.filter(func(sample):return sample.get("native_spell",false) and sample.get("spell_id")==source_id \
            and (not item.has("shield_condition_uuid") or sample.get("condition_uuid")==item.shield_condition_uuid))
        check(not active.is_empty(),item.spell_id+": selected native interval is active "+key)
        for sample in active:
            var status:Dictionary=native.diagnostics.get(sample.id,{})
            check(status.get("status") in ["prepared","rendered"],item.spell_id+": admitted native phase has usable placement "+str(status))
            check(native.handles.has(sample.id),item.spell_id+": occurrence source prepared")
            if native.handles.has(sample.id):
                var handle:Dictionary=native.handles[sample.id]
                check(handle.root.is_visible_in_tree(),item.spell_id+": occurrence submitted to its viewport")
                check(handle.rendered_once,item.spell_id+": source completes native draw")
        counts[key]=active.size()
        world.set_process(false)
        await frame()
        var shown:Image=view.get_texture().get_image()
        var hidden_nodes:Array=[]
        if item.has("shield_control"):
            for sample in active:
                if native.handles.has(sample.id):
                    var node:Node3D=native.handles[sample.id].root
                    hidden_nodes.append([node,node.visible]);node.hide()
        else:
            for layer in native.groups.values():hidden_nodes.append([layer.output,layer.output.visible]);layer.output.hide()
        await frame()
        var hidden:Image=view.get_texture().get_image()
        var first:PackedByteArray=shown.get_data();var second:PackedByteArray=hidden.get_data()
        var changed:int=0
        for i in range(0,mini(first.size(),second.size()),4):
            if absi(int(first[i])-int(second[i]))>3 or absi(int(first[i+1])-int(second[i+1]))>3 or absi(int(first[i+2])-int(second[i+2]))>3:changed+=1
        native_pixels+=changed
        for entry in hidden_nodes:entry[0].visible=entry[1]
        world.set_process(true);await frame()
        var capture_name:String=item.id.replace("/","__")+"-"+str(item.perspectives[0].id)
        shown.save_png("res://.captures/native-spell-batch/"+capture_name+"-"+str(visited.size())+".png")
    check(native_pixels>0,item.spell_id+": source contributes actual framebuffer pixels")
    check(world.presentation_errors.is_empty(),item.spell_id+": no renderer errors")
    check(world.try_reset_hidden_playback(Recording.restore(index,0)),item.spell_id+": reverse seek reconstructs start")
    await settle(world,item.spell_id+" reverse")
    results.append({"spell":item.spell_id,"case":item.id,"perspective":item.perspectives[0].id,
        "control":item.get("shield_control",""),"condition_uuid":item.get("shield_condition_uuid"),
        "native_pixels":native_pixels,"intervals":counts,"errors":world.presentation_errors.duplicate()})
    print("BATCH_RENDER_CASE ",JSON.stringify(results.back()))
    view.queue_free();await frame();await frame()
func representative_time(row:Dictionary)->float:
    var component:Dictionary=row.component
    var at:float=lerpf(row.start_ms,row.end_ms,sample_fraction)
    # A finite source can already be closed halfway through its particle tail.
    # Sample its authored opening, rather than treating an empty tail as failure.
    if component.native_cue.role=="attached" and not component.get("persistent_owner",false):
        for part in component.native_clip.get("components",[]):
            var source:Dictionary=part.get("input",{})
            var close:float=source.get("settings",{}).get("close",INF)
            var hz:float=source.get("simulation_hz",component.native_clip.get("simulation_hz",144))
            if close>0 and is_finite(close):
                var seconds:float=close/maxf(1,hz)/maxf(.001,component.native_cue.get("source_rate",1))
                at=minf(at,row.start_ms+seconds*500.0)
    return at
func finish()->void:
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":results,
        "factory_version":JSON.parse_string(FileAccess.get_file_as_string(Effects.INDEX)).version,
        "selected_current_cases":selected_cases,"missing_original_controls":missing_originals,"shield_control_evidence":control_evidence,
        "scope":"Selected original baseline/control cohort through ordinary Studio restore/Play, representative phase samples, native scene pixels, reverse seek and source retirement. Shield controls require exact original own-UUID incoming attribution, real movement and retirement in both independent seats, plus selected Shield output. Missing or nonmatching originals remain failures. A requested subset does not qualify all-spell safety or art acceptance."}
    FileAccess.open("res://generated/native_spell_batch_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BATCH_RENDER ",JSON.stringify({"checks":checks,"failures":failures,"missing_original_controls":missing_originals}));quit(0 if failures.is_empty() else 1)
