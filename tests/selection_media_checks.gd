extends SceneTree
## Real admitted state/actions and authored sources; no invented events or GPU.
const Selection = preload("res://presentation/selection_media.gd")
const Characters = preload("res://presentation/characters.gd")
const Authoring = preload("res://presentation/authoring.gd")
const Choices = preload("res://sdk/choices.gd")
const Catalog = preload("res://source_catalog.gd")
const NativeSupport = preload("res://presentation/native_scene_support.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Protocol = preload("res://sdk/protocol.gd")
const Reducer = preload("res://sdk/reducer.gd")
var checks=0
var failures: Array=[]
var notes={}
func check(ok: bool, label: String) -> void:
    checks+=1
    if not ok: failures.append(label);printerr("SELECTION_MEDIA_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func state_from(directory: String) -> Dictionary:
    var protocol=Protocol.new()
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    check(decoded.ok,"Recorded initialization passes actual strict SDK admission")
    if not decoded.ok:return {}
    var packet=protocol.normalize("InitializationResponse",decoded.value)
    var reduced=Reducer.reduce_initialization(packet.initialization,packet.content_additions)
    check(reduced.ok,"Recorded initialization reduces through canonical SDK")
    return reduced.value if reduced.ok else {}
func settle(owner: Dictionary) -> void:
    var deadline=Time.get_ticks_msec()+60000
    while owner.worker!=null and Time.get_ticks_msec()<deadline:
        Selection.poll(owner)
        await process_frame
    check(owner.worker==null,"Finite selection metadata task completes")
func run() -> void:
    var fixture="";var gallery="";var hover=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--case="):fixture=arg.trim_prefix("--case=")
        if arg.begins_with("--gallery="):gallery=arg.trim_prefix("--gallery=")
        if arg.begins_with("--hover="):hover=arg.trim_prefix("--hover=")
    if fixture.is_empty():printerr("Pass actual --case=<targeting checks.json> and optional --gallery=<journal>");quit(2);return
    var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
    var state=state_from(fixture.get_base_dir())
    if state.is_empty():quit(1);return
    var immutable=var_to_bytes(state)
    var action: Dictionary=Choices.all_actions(evidence.choices).filter(func(row):return row.behavior_id=="spell.fireball")[0]
    var actor_uuid: String=evidence.choices.entity_uuid
    # Available choices must warm their real authored body path even when a
    # mechanic uses a movement context rather than a body-action recipe.
    var move_hint=Selection.create()
    var before_move=var_to_bytes(state)
    Selection.request(move_hint,[1,"available movement"],actor_uuid,"",state,16*1024*1024*1024,
        {},{},[],{},"reference",["action.move"])
    await settle(move_hint)
    var move_cache={}
    var movement=Authoring.body("movement",state.actors[actor_uuid],{"trajectory":"path","movement_mode":"walking"},move_cache)
    var movement_sources=Characters.sheet_paths(state.actors[actor_uuid],[movement.actor.clip],move_cache)
    var selected_movement=Characters.CharacterGeometry.for_profile(movement_sources.value,movement_sources.normal_sets,"reference")
    check(movement_sources.ok and not selected_movement.is_empty()
        and selected_movement.keys().all(func(path):return move_hint.value.paths.has(path)),
        "Available movement prepares the actual walking context and its selected normal companions before a command")
    check(selected_movement.keys().all(func(path):return move_hint.value.onset_paths.has(path)),
        "The offered movement's authored sheets receive onset priority without an authoritative event")
    check(var_to_bytes(state)==before_move and move_hint.value.errors.is_empty(),
        "Available movement only prepares disclosed source operands; canonical state and conditions stay unchanged")
    Selection.close(move_hint)
    var owner=Selection.create()
    Selection.request(owner,[1,"fireball"],actor_uuid,action.behavior_id,state,16*1024*1024*1024)
    var first_worker:Thread=owner.worker
    Selection.request(owner,[2,"replacement"],actor_uuid,action.behavior_id,state,16*1024*1024*1024)
    check(owner.worker==first_worker and owner.pending.key==[2,"replacement"],"Replacement owns one running metadata task and one latest request")
    await settle(owner)
    check(owner.discarded==1 and owner.value.paths.size()>0,"Canceled metadata cannot publish; current replacement has authored candidates")
    var value: Dictionary=owner.value
    var cache={}
    var recipe=preload("res://presentation/native_spell_authoring.gd").recipe({"behavior_id":action.behavior_id},cache)
    var caster=Characters.sheet_paths(state.actors[actor_uuid],[recipe.cast.actionClip],cache)
    check(caster.ok and caster.value.keys().all(func(path):return value.paths.has(path)),"Actual selected native cast clip includes every current caster outfit and geometry source")
    check(value.native_selection.id=="fireball","Actual selected native spell metadata is resolved without creating a scene")
    var required={}
    for actor in state.actors.values():
        var clips=[]
        for role in ["damage","death"]: clips.append(Authoring.body(role,actor,{},cache).actor.clip)
        var sources=Characters.sheet_paths(actor,clips,cache)
        check(sources.ok and sources.value.keys().all(func(path):return value.paths.has(path)),"Visible recipient's authored damage/death closure is prepared: "+actor.name)
        required.merge(sources.value)
        var rest=Characters.sheet_paths(actor,["Idle"],cache)
        for path in rest.geometry_slots:
            required.merge(NativeSupport.required_paths(path,rest.geometry_slots[path],cache))
    check(value.paths.keys().any(func(path):return path.ends_with("solid-valid.png")),"Idle/rest optical support masks are included before a native overlap")
    check(value.bytes<=16*1024*1024*1024 and value.source_sizes.size()==value.paths.size(),"All admitted candidates carry header estimates within the supplied budget")
    check(value.cpu_required.keys().all(func(path):return not value.gpu_only.has(path)),"CPU retention wins shared source role conflicts")
    var exact={};var exact_cpu={};var exact_gpu={};var errors=[]
    for actor in state.actors.values():
        var clips=[Authoring.body("damage",actor,{},cache).actor.clip,Authoring.body("death",actor,{},cache).actor.clip,"Idle"]
        if actor.uuid==actor_uuid:clips.append(recipe.cast.actionClip)
        Media._add_actor(exact,actor,clips,cache,errors,exact_gpu,exact_cpu,true)
    var warmed={};var warmed_cpu={};var warmed_gpu={}
    for path in exact:
        if not value.paths.has(path):continue
        warmed[path]=value.paths[path]
        if exact_cpu.has(path):warmed_cpu[path]=true
        if exact_gpu.has(path):warmed_gpu[path]=true
    check(warmed_cpu.keys().all(func(path):return value.cpu_required.has(path)),"Selection mirrors authoritative native optics CPU roles, including original socket pixels")
    var demand=Media.create()
    Media.adopt_source_sizes(demand,value.source_sizes,1)
    Media.demand(demand,value.paths,{}, {},value.gpu_only,value.cpu_required)
    demand.pending=[];demand.queued.clear();demand.stats={}
    for path in value.paths:
        Media.published(demand,{"path":path,"gpu_bytes":value.source_sizes[path],"cpu_bytes":value.source_sizes[path] if value.cpu_required.has(path) else 0})
    Media.demand(demand,warmed,{}, {},warmed_gpu,warmed_cpu)
    check(Media.ready(demand,warmed) and demand.pending.is_empty(),"Typed existing-media publication acknowledgement remains ready with zero redecodes when authoritative group takes matching paths/roles")
    Media.close(demand)
    check(var_to_bytes(state)==immutable,"Selection metadata never changes canonical recorded state")
    notes.paths=value.paths.size();notes.bytes=value.bytes;notes.actors=value.actors
    var empty_aim: Dictionary=evidence.records.filter(func(row):return row.behavior==action.behavior_id)[-1].preview
    var exact_owners=Selection.owners(owner,state,empty_aim)
    check(exact_owners.exact and exact_owners.recipients.is_empty(),"Actual computed empty-area reply is an exact recipient set, not unknown potential victims")
    check(is_same(exact_owners,Selection.owners(owner,state,empty_aim)),"Unchanged immutable preview/world reuses exact source-owner projection")
    Selection.request(owner,[2,"exact empty"],actor_uuid,action.behavior_id,state,16*1024*1024*1024,{},empty_aim,[],exact_owners)
    await settle(owner)
    check(owner.value.bytes<value.bytes and owner.value.paths.size()<value.paths.size(),"Exact empty recipient area releases speculative damage/death candidates while retaining caster/rest closure")
    check(caster.value.keys().all(func(path):return owner.value.paths.has(path)),"Recipient narrowing keeps every actual caster cast source")
    var jobs: int=owner.jobs
    Selection.request(owner,[2,"exact empty"],actor_uuid,action.behavior_id,state,16*1024*1024*1024,{},empty_aim,[],exact_owners)
    check(owner.jobs==jobs and owner.worker==null,"Identical resource-owner request cannot schedule another metadata job")
    Selection.request(owner,[2,"active Reference"],actor_uuid,action.behavior_id,state,16*1024*1024*1024,{},empty_aim,[],exact_owners,"reference")
    await settle(owner)
    var projected=Characters.CharacterGeometry.for_profile(owner.value.paths,owner.value.normal_sets,"reference")
    check(owner.value.paths==projected and owner.value.normal_sets.size()>0,"Selected spell worker publishes active-profile sources with neutral normal metadata")
    check(caster.normal_sets.values().all(func(profiles):return owner.value.paths.has(profiles.reference) and not owner.value.paths.has(profiles.gentle) and not owner.value.paths.has(profiles.original)),"Actual caster cast closure retains Reference and excludes both inactive normal variants")
    Selection.cancel(owner)
    check(owner.value.is_empty() and owner.pending.is_empty(),"Explicit cancellation releases selection-owned candidates immediately")
    Selection.request(owner,[3,"tiny"],actor_uuid,action.behavior_id,state,1)
    await settle(owner)
    check(owner.value.paths.is_empty() and owner.value.skipped>0,"Insufficient budget skips optional candidates without any required readiness gate")
    Selection.request(owner,[4,"closing"],actor_uuid,action.behavior_id,state,16*1024*1024*1024)
    Selection.close(owner)
    check(owner.worker==null and owner.pending.is_empty() and owner.value.is_empty() and owner.cache.is_empty(),"Close cancels and joins only its own finite worker and releases metadata")
    if not gallery.is_empty():
        var gallery_state=state_from(gallery)
        var protocol=Protocol.new()
        for sequence in range(1,5):
            var decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(gallery.path_join("%016d.json" % sequence)))
            check(decoded.ok,"Real Gallery operation admits before actual Fireball: "+str(sequence))
            var reduced=Reducer.reduce_operation(gallery_state,protocol.normalize("PlayerOperation",decoded.value))
            check(reduced.ok,"Real Gallery operation reduces before actual Fireball: "+str(sequence))
            gallery_state=reduced.value
        var gallery_owner=Selection.create()
        var gallery_frozen=var_to_bytes(gallery_state)
        Selection.request(gallery_owner,[5,"gallery"],gallery_state.audience.controlled[0],action.behavior_id,gallery_state,16*1024*1024*1024)
        await settle(gallery_owner)
        var gallery_value: Dictionary=gallery_owner.value
        check(gallery_value.banks.is_empty() and gallery_value.environment.is_empty(),"Before an authoritative area/binding preview, whole Gallery furniture banks stay outside selection demand")
        var rows=preload("res://presentation/world.gd").rows({"tiles":{},"objects":gallery_state.objects,"senses":gallery_state.senses},cache)
        var banks=[]
        for row in rows.rows:banks.append_array(Selection._break_banks(row,cache))
        check("prop.interior-writing-desk.break" in banks and "prop.interior-wooden-chair.break" in banks,"Actual disclosed Gallery desk/chair have registered break owners available for later exact area refinement")
        check(var_to_bytes(gallery_state)==gallery_frozen,"Borrowed Gallery actor/object/senses graph remains byte-identical after worker metadata and bank resolution")
        notes.gallery={"paths":gallery_value.paths.size(),"banks":gallery_value.banks,"bytes":gallery_value.bytes,"errors":gallery_value.errors}
        Selection.close(gallery_owner)
    if not hover.is_empty():
        var witness: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(hover))
        var recorded=hover.get_base_dir().path_join("journal")
        var current=state_from(recorded)
        var protocol=Protocol.new()
        for sequence in range(1,int(witness.sequence_before)+1):
            var decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(recorded.path_join("%016d.json" % sequence)))
            check(decoded.ok,"Captured hover's original operation admits: "+str(sequence))
            var reduced=Reducer.reduce_operation(current,protocol.normalize("PlayerOperation",decoded.value))
            check(reduced.ok,"Captured hover's original operation reduces: "+str(sequence))
            current=reduced.value
        var live_owner=Selection.create()
        Selection.request(live_owner,[7,"base"],current.audience.controlled[0],witness.request.behavior,current,16*1024*1024*1024)
        await settle(live_owner)
        var first: Dictionary=witness.previews[1].preview
        var second: Dictionary=witness.previews[2].preview
        var first_owners=Selection.owners(live_owner,current,first)
        var second_owners=Selection.owners(live_owner,current,second)
        check(first.affected_positions!=second.affected_positions or first.positions!=second.positions,"Actual recorded prospective area moves between the two source-owner samples")
        var first_key=[7,first_owners.object_resources,first_owners.response_resources,first_owners.exact]
        var second_key=[7,second_owners.object_resources,second_owners.response_resources,second_owners.exact]
        check(first_key==second_key,"Different actual affected instances/area reuse the same authored bank and recipient source families")
        Selection.request(live_owner,first_key,current.audience.controlled[0],witness.request.behavior,current,16*1024*1024*1024,{},first,[],first_owners)
        await settle(live_owner)
        var settled_jobs: int=live_owner.jobs
        var settled_revision: int=live_owner.revision
        Selection.request(live_owner,second_key,current.audience.controlled[0],witness.request.behavior,current,16*1024*1024*1024,{},second,[],second_owners)
        check(live_owner.jobs==settled_jobs and live_owner.revision==settled_revision and live_owner.worker==null,"Moving real area across unchanged authored sources neither cancels demand nor schedules metadata again")
        var prior_environment: Dictionary=live_owner.value.environment
        var wider: Dictionary=witness.previews[3].preview
        var wider_owners=Selection.owners(live_owner,current,wider)
        Selection.request(live_owner,[7,wider_owners.object_resources,wider_owners.response_resources,wider_owners.exact],current.audience.controlled[0],witness.request.behavior,current,16*1024*1024*1024,{},wider,[],wider_owners)
        check(prior_environment.keys().all(func(path):return live_owner.value.environment.has(path)),"Expanding actual area retains shared desk/chair bank pins while new metadata is pending")
        Selection.close(live_owner)
    cache.clear()
    # Worker-created Resources retire through the scene-thread deferred queue.
    await process_frame
    await process_frame
    var report={"ok":failures.is_empty(),"checks":checks,"failures":failures,"notes":notes,"scope":"Actual admitted state/action to optional source candidates, cancellation/worker ownership and header budgets; no events, commands, decoding or GPU"}
    FileAccess.open("res://generated/selection_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
