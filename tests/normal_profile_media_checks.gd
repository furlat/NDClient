extends SceneTree
## Real authored closures, existing demand owner and atomic display preferences.
const Geometry=preload("res://presentation/character_geometry.gd")
const Characters=preload("res://presentation/characters.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Settings=preload("res://presentation/render_settings.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
class ProfilePlayer extends "res://play.gd":
    var settings_path=""
    var saves=0
    func _ready() -> void:
        set_process(false);set_process_unhandled_input(false);add_child(context_menu)
    func _save_character_light_profile(name: String) -> Error:
        saves+=1
        return Settings.write(name,settings_path)
var checks=0
var failures=[]
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label);printerr("NORMAL_PROFILE_FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
    var recording=Fixtures.journal("gallery")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):recording=arg.trim_prefix("--recording=")
    var protocol=Protocol.new()
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(recording.path_join("0000000000000000.json")))
    check(decoded.ok,"Actual initialization passes strict SDK admission")
    if not decoded.ok:quit(1);return
    var packet:Dictionary=decoded.value
    var reduced=Reducer.reduce_initialization(packet.initialization,packet.get("content_additions",[]))
    check(reduced.ok,"Actual initialization reduces without a profile-dependent event")
    var state: Dictionary=reduced.value
    var frozen=var_to_bytes(state)
    var cache={}
    var plan=Media.plan(state,[],cache)
    var raw=var_to_bytes(plan)
    check(not plan.normal_sets.is_empty(),"Neutral metadata owner publishes authored normal sets")
    var roles=Media.roles_for(plan,plan.required)
    check(is_same(roles.normal_sets,plan.normal_sets),"Exact role packet carries neutral normal metadata without a deep copy")
    var variants={}
    for profiles in plan.normal_sets.values():
        for path in profiles.values():variants[path]=true
    var removed_bytes=0
    for profile in Geometry.PROFILES:
        var active=Geometry.for_profile(plan.required,plan.normal_sets,profile,cache,"test")
        var chosen={}
        for profiles in plan.normal_sets.values():chosen[profiles[profile]]=true
        check(plan.required.keys().all(func(path):return active.has(path)==(not variants.has(path) or chosen.has(path))),"Only registered inactive normal variants leave "+profile+" exact paths")
        check(is_same(active,Geometry.for_profile(plan.required,plan.normal_sets,profile,cache,"test")),"Unchanged "+profile+" owner reuses its immutable projection")
        for actor in state.actors.values():
            var sheets=Characters.sheet_paths(actor,["Idle"],cache,Characters.item_looks(actor,state))
            check(sheets.ok and not sheets.normal_sets.is_empty(),"Actual outfit sources carry all authored profile alternatives")
            for path in sheets.geometry_slots:
                var companions=Geometry.paths(path,sheets.geometry_slots[path],cache,profile)
                var normals=Geometry.normal_paths(path,sheets.geometry_slots[path],cache)
                check(companions.has(normals.value[profile]),"Renderer readiness retains chosen "+profile+" map")
    check(var_to_bytes(plan)==raw and var_to_bytes(state)==frozen,"Profile projection never mutates neutral metadata or canonical state")
    var scene=ProfilePlayer.new();root.add_child(scene)
    scene.settings_path="user://normal-profile-checks-%s.cfg" % Time.get_ticks_usec()
    Settings.write(Settings.DEFAULT_PROFILE,scene.settings_path)
    scene.timeline.accept({"kind":"initialization","sequence":0,"state":state})
    scene._reset_media_epoch()
    var completed:Dictionary={}
    Media._plan_sources({"key":[scene.timeline.initialization_revision,[],scene.timeline.revision],"state":Media._snapshot(state),"groups":[]},completed,cache)
    check(completed.complete and completed.value.errors.is_empty(),"Actual native source owner completes the profile-neutral handoff")
    scene._adopt_media_plan(completed,false)
    scene._prepare_media()
    check(not scene.media_empty_plan.get("source_records",{}).is_empty(),"The actual profile lifecycle publishes source records through the production media owner")
    var reference=Geometry.for_profile(plan.required,plan.normal_sets,"reference",cache,"expected")
    check(scene.media_plan.required==reference,"Actual Play demand requires only active Reference companions")
    var required_identity: Dictionary=scene.media_plan.required
    check(scene.character_light_profile=="reference","Approved default remains Reference")
    scene.notice_text=""
    scene.set_character_light_profile("gentle")
    check(scene.character_light_profile=="reference" and scene.requested_character_light_profile=="gentle" and scene.saves==0,"Cold switch retains active profile and saved setting until every target map is ready")
    scene._prepare_media()
    check(scene.character_profile_pending_paths.keys().all(func(path):return scene.media_warmup.wanted.has(path) and not scene.media_plan.required.has(path)),"Pending setting maps use existing demand outside active playback readiness")
    scene.set_character_light_profile("original")
    check(scene.character_light_profile=="reference" and scene.requested_character_light_profile=="original" and scene.character_profile_pending_paths.keys().all(func(path):return not plan.normal_sets.values().any(func(profiles):return profiles.gentle==path)),"Replacement cancels old pending profile pins without changing displayed profile")
    scene.set_character_light_profile("reference")
    check(scene.requested_character_light_profile.is_empty() and scene.character_profile_pending_paths.is_empty() and scene.notice_text.is_empty(),"Returning to active profile cancels pending work and its owned preparation notice")
    scene.set_character_light_profile("gentle");scene.notice_text="Unrelated command notice"
    scene.set_character_light_profile("reference")
    check(scene.notice_text=="Unrelated command notice","Canceling profile preparation preserves unrelated notices")
    scene.notice_text="";scene.set_character_light_profile("gentle")
    check(not scene.character_profile_pending_paths.is_empty(),"A cold profile has actual selected normal maps to prepare")
    if scene.character_profile_pending_paths.is_empty():
        Media.close(scene.media_warmup);scene.free();quit(1);return
    var failed_path: String=scene.character_profile_pending_paths.keys()[0]
    scene.media_warmup.failed[failed_path]="Exact optional normal failed"
    scene._poll_character_light_profile()
    check(scene.character_light_profile=="reference" and scene.requested_character_light_profile.is_empty() and scene.saves==0 and scene.media_issue.is_empty() and not scene.command_busy,"Failed optional profile keeps approved rendering/settings and does not block gameplay readiness")
    scene.media_warmup.failed.clear();scene.notice_text=""
    var tiny=Image.create(1,1,false,Image.FORMAT_RGBA8)
    var resident=ImageTexture.create_from_image(tiny)
    scene.set_character_light_profile("gentle")
    var needed: Array=scene.character_profile_pending_paths.keys()
    for path in needed.slice(0,-1):scene.textures[path]=resident
    scene._poll_character_light_profile()
    check(scene.character_light_profile=="reference" and scene.saves==0,"Partial resident target closure cannot produce a mixed or fallback profile frame")
    scene.textures[needed[-1]]=resident;scene._poll_character_light_profile()
    check(scene.character_light_profile=="gentle" and scene.requested_character_light_profile.is_empty() and scene.saves==1 and Settings.read(scene.settings_path).profile=="gentle","Complete target closure applies and persists atomically exactly once")
    scene.set_character_light_profile("reference")
    for profiles in plan.normal_sets.values():scene.textures[profiles.reference]=resident
    scene._poll_character_light_profile()
    var saves: int=scene.saves
    scene.set_character_light_profile("gentle")
    check(scene.character_light_profile=="gentle" and scene.requested_character_light_profile.is_empty() and scene.saves==saves+1,"Already resident profile switch remains immediate")
    check(not scene.set_character_light_profile("invented") and scene.character_light_profile=="gentle","Invalid profile cannot change rendering or preparation")
    check(var_to_bytes(state)==frozen,"Display setting lifecycle preserves canonical actor/event data")
    DirAccess.remove_absolute(scene.settings_path)
    Media.close(scene.media_warmup);scene.free();cache.clear()
    await process_frame
    await process_frame
    var report={"ok":failures.is_empty(),"checks":checks,"failures":failures,"recording":recording,"scope":"Actual native16 SDK/authored normal closure projection, completed source-record handoff, Play demand and atomic local setting lifecycle; tiny typed residency acknowledgements, no normal bitmap changes, no native pixel/performance claim"}
    FileAccess.open("res://generated/normal_profile_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
