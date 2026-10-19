extends SceneTree
const Session = preload("res://presentation/session.gd")
const WorldRows = preload("res://presentation/world.gd")
const Catalog = preload("res://source_catalog.gd")
const EventTrace = preload("res://presentation/event_trace.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var recording=""
    var args=OS.get_cmdline_user_args()
    for i in args.size()-1:
        if args[i]=="--recording": recording=args[i+1]
    if recording.is_empty():
        push_error("Pass --recording with an actual current-SDK journal directory.")
        quit(1);return
    var session=Session.new()
    session.open_recording(recording)
    var events=[]
    var deadline=Time.get_ticks_msec()+60000
    while not session.terminal and Time.get_ticks_msec()<deadline:
        session.poll()
        if not session.issue.is_empty(): break
        for message in session.take_prepared():
            if message.kind=="initialization": session.set_displayed_sequence(int(message.sequence))
            else:
                for group in message.groups:
                    var trace=EventTrace.create()
                    EventTrace.activate(trace,group.events,0)
                    for commit in group.commits:
                        if commit.has("event_uuid"):EventTrace.commit(trace,int(group.operation_sequence),commit.event_uuid)
                    EventTrace.tick(trace,group.events,group.duration_ms)
                    for row in EventTrace.snapshot(trace,2000,"",0).events:
                        if row.kind in ["object_destroyed","object_damage","mechanism_activation","spell","spatial_effect_state"]:
                            events.append({"sequence":row.sequence,"kind":row.kind,"name":row.name,"status":row.status,"reasons":row.reasons,"components":row.components.map(func(c):return c.kind)})
                    session.set_displayed_sequence(int(group.operation_sequence))
        await process_frame
    var cache={}
    var broken=[]
    for id in session.journal.state.get("objects",{}):
        var object:Dictionary=session.journal.state.objects[id]
        if object.item.integrity!="destroyed": continue
        var result=WorldRows.rows({"tiles":{},"objects":{id:object}},cache)
        broken.append({"name":object.item.name,"item_id":object.item.item_id,"kind":result.rows[0].kind if not result.rows.is_empty() else "unresolved",
            "projected_destroyed":result.rows[0].get("destroyed",false) if not result.rows.is_empty() else false})
    var traps=[]
    var index=Catalog.environment_index(cache)
    for id in index.traps:
        var object={"placement":{"position":[0,0],"base_height_steps":0,"kind":"prop"},"item":{"item_id":id,"is_engaged":true}}
        var row:Dictionary=WorldRows.rows({"tiles":{},"objects":{"trap":object}},cache).rows[0]
        var owner=index.traps[id]
        traps.append({"id":id,"projected_state":row.state,"authored_states":owner.state_frames.keys(),"resolves":owner.state_frames.has(row.state)})
    var api={}
    for cls in ["AnimationPlayer","AnimationMixer","GPUParticles3D","GPUParticles2D"]:
        var methods=[];var properties=[]
        for method in ClassDB.class_get_method_list(cls):
            if method.name in ["seek","advance","restart","request_particles_process"]: methods.append({"name":method.name,"args":method.args.map(func(a):return a.name)})
        for property in ClassDB.class_get_property_list(cls):
            if property.name in ["use_fixed_seed","seed","process_mode","callback_mode_process"]:properties.append(property.name)
        api[cls]={"methods":methods,"properties":properties}
    var catalog_index=Catalog.read_file("catalog-index.json",cache)
    var inventory={"spell_drafts":catalog_index.drafts.size(),"paired_banks":catalog_index.paired_banks.size(),
        "environment_doors":index.doors.size(),"environment_props":index.props.size(),"environment_traps":index.traps.size()}
    for name in ["attack_recipes","body_action_recipes","condition_recipes","rigs","resources","world_animations"]:
        inventory[name]=Catalog.read_file(catalog_index[name],cache).size()
    var report={"review_baseline_commit":"0635d5f","recording":recording.get_file(),"last_sequence":session.latest_sequence,"registered_inventory":inventory,
        "terminal":session.terminal,"session_issue":session.issue,"events":events,"retained_destroyed_objects":broken,"engaged_trap_projection":traps,
        "godot_version":Engine.get_version_info().string,"godot_api":api,
        "scope":"Read-only compilation and settled diagnostic projection of an actual recorded SDK prefix without renderer witnesses; current final-world adapter projection; engaged trap selector values; installed native API inspection. No new live commands, rendering changes or claim of exhaustive gameplay coverage."}
    session.close()
    FileAccess.open("res://generated/client_studio_review_evidence.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify({"events":events.size(),"broken":broken,"trap_unresolved":traps.filter(func(t):return not t.resolves).size(),"session_issue":report.session_issue,"terminal":report.terminal}))
    quit(0 if report.session_issue.is_empty() and report.terminal else 1)
