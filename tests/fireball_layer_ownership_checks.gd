extends "res://tests/global_publication_checks.gd"
const Recording=preload("res://studio/recording.gd")

func prepare_cast(scene:Node)->void:
    var deadline:int=Time.get_ticks_msec()+30000
    while Time.get_ticks_msec()<deadline and not scene.publication_failed:
        var budget:Dictionary=scene._preparation_budget()
        scene._warm_media(true,budget);scene._prepare_media();scene._prepare_future_world();scene._step_world_preparation()
        if scene.pending_world!=null and scene.pending_world.prepared:return
        await process_frame
    check(false,"Actual Fireball candidate completes: "+scene.media_issue+str(scene.presentation_errors))

func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(960,640)
    var index:Dictionary=Fixtures.read("gallery")
    check(index.ok,"Actual live journal compiles")
    if not index.ok:quit(1);return
    var cast:Dictionary={}
    for item in index.groups:
        if item.group.events.any(func(event):return event.get("kind")=="spell" and event.get("behavior_id")=="spell.fireball"):
            cast=item;break
    check(not cast.is_empty(),"Actual Gallery Fireball following four earlier spell casts exists")
    if cast.is_empty():quit(1);return
    var scene=Player.instantiate();scene.external_playback=true
    scene.native_startup_plan=scene.NativeStartup.recording_plan(index.rows)
    scene.catalog_cache=index.cache;scene.install_playback(Recording.restore(index,float(cast.start_ms)-.01))
    root.add_child(scene)
    var deadline:int=Time.get_ticks_msec()+60000
    while (scene.world_revision<0 or not scene._character_sources_ready(cast.group,cast.start_ms)) and not scene.publication_failed and Time.get_ticks_msec()<deadline:await process_frame
    scene.set_process(false)
    if scene.hud!=null:scene.hud.hide()
    check(scene.world_revision>=0 and not scene.publication_failed,"Actual pre-cast world initializes through strict publication")
    if scene.world_revision<0 or scene.publication_failed:scene.queue_free();await process_frame;quit(1);return
    var id:String=cast.group.actor_tracks[0].actor_uuid
    var actor:Dictionary=scene.visual_actors[id]
    var entries:Array=actor.entries.duplicate()
    var graph:Node=scene.playbacks[id]
    var shadow:Dictionary=scene.generated_shadows.actors.get(id,{})
    var caster_nodes:Dictionary={}
    for entry in entries:
        if not shadow.is_empty() and shadow.casters.has(entry.id):caster_nodes[entry.actor_layer.slot]=shadow.casters[entry.id]
    var source_versions:Array=entries.map(func(entry):return entry.source_version)
    var before_state:PackedByteArray=var_to_bytes(scene.timeline.state)
    var before_clock:float=scene.timeline.display_ms
    await prepare_cast(scene)
    if scene.pending_world==null or not scene.pending_world.prepared:scene.queue_free();await process_frame;quit(1);return
    var prepared:Dictionary=scene.pending_world.native_actors[id]
    check(prepared.new_entries.size()==1 and prepared.new_entries[0].actor_layer.category=="Magic2","Only actual Magic2 source is constructed")
    check(prepared.retained_entries.size()==8 and prepared.playback==graph,"All eight unchanged sources and animation graph are borrowed")
    # Lit sprites have no receiver membership: the added layer is actor-owned
    # and the candidate's static world membership stays unchanged.
    check(scene.pending_world.membership.removed.is_empty() and scene.pending_world.membership.upserts.is_empty(),"Adding Magic2 leaves static world membership unchanged")
    check(source_versions==entries.map(func(entry):return entry.source_version),"Preparing the new cast does not modify retained source operands")
    var private_node=weakref(prepared.new_entries[0].node)
    scene._discard_world_preparation()
    for frame in 80:
        scene._dispose_views(scene._preparation_budget(),true);await process_frame
        if scene.retiring_node_count==0:break
    check(private_node.get_ref()==null,"Cancellation retires the candidate's new source")
    check(entries.all(func(entry):return is_instance_valid(entry.node) and entry.node.get_parent()==scene) and scene.playbacks[id]==graph,
        "Cancellation leaves borrowed sources and animation graph alive")
    check(is_same(scene.visual_actors[id],actor) and (shadow.is_empty() or is_same(scene.generated_shadows.actors[id],shadow)),"Cancellation preserves current actor and shadow ownership")
    check(var_to_bytes(scene.timeline.state)==before_state and scene.timeline.display_ms==before_clock,"Preparation and cancellation leave current state and clock untouched")
    await prepare_cast(scene)
    scene.timeline.paused=false
    for frame in 240:
        scene._process(.001)
        if scene.timeline.current.get("id")==cast.group.id or scene.publication_failed:break
        await process_frame
    scene.timeline.paused=true
    check(not scene.publication_failed and scene.timeline.current.get("id")==cast.group.id,"Exact actual cast publishes through strict world admission: "+JSON.stringify({"display":scene.timeline.display_ms,"target":cast.start_ms,"current":scene.timeline.current.get("id"),"world_wait":scene.timeline.waiting_for_world,"media_wait":scene.timeline.waiting_for_media,"gate":scene.media_gate,"phase":scene.pending_world.phase if scene.pending_world!=null else "none","issue":scene.media_issue,"errors":scene.presentation_errors}))
    if scene.timeline.current.get("id")!=cast.group.id:
        scene.queue_free();await process_frame;quit(1);return
    check(scene.playbacks[id]==graph and entries.all(func(entry):return entry in scene.visual_actors[id].entries),"Publication retains existing graph and every unchanged source")
    check(shadow.is_empty() or is_same(scene.generated_shadows.actors[id],shadow),"Publication retains existing native shadow viewport")
    for entry in scene.visual_actors[id].entries:
        if caster_nodes.has(entry.actor_layer.slot):check(scene.generated_shadows.actors[id].casters[entry.id]==caster_nodes[entry.actor_layer.slot],"Shifted layer index retains caster: "+entry.actor_layer.slot)
    sample_frame(scene)
    var actual:Image=await capture()
    var state:PackedByteArray=var_to_bytes(scene.timeline.state);var clock:float=scene.timeline.display_ms
    var epoch:int=scene.world_prepare_epoch
    scene._retire_actor(id);scene.world_prepare_epoch=-1;scene.actor_revision=-1;scene._sync_actors();scene.world_prepare_epoch=epoch
    scene._sample_actors();scene._sample_fixtures()
    await compare_full(scene,actual,"fireball-layer")
    check(var_to_bytes(scene.timeline.state)==state and scene.timeline.display_ms==clock,"Independent full construction changes neither actual event state nor its clock")
    check(scene.presentation_errors.is_empty() and scene.media_issue.is_empty(),"Actual cast leaves no presentation errors: "+str(scene.presentation_errors.slice(0,3))+" "+scene.media_issue)
    var report={"checks":checks,"failures":failures,"comparisons":comparisons,"retained_layers":entries.size(),"scope":"Actual Gallery Fireball following four earlier spell casts onset; private cancellation and retained source/graph/shadow ownership; first framebuffer versus full actor construction at the same published clock."}
    FileAccess.open("res://generated/fireball_layer_ownership_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("FIREBALL_LAYER_OWNERSHIP ",JSON.stringify(report))
    scene.queue_free();await process_frame;await process_frame
    quit(0 if failures.is_empty() else 1)
