extends SceneTree
## Actual selected authoring and server packet; passive metadata, no GPU or commands.
const Session=preload("res://presentation/session.gd")
const Selection=preload("res://presentation/selection_media.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Samples=preload("res://presentation/surface_socket_samples.gd")
const BodySources=preload("res://presentation/body_sources.gd")
class BoundarySession extends Session:
    var entered=Semaphore.new()
    var release_boundary=Semaphore.new()
    var merged=Semaphore.new()
    var block_once=true
    func _merge_prepared_sources()->void:
        if block_once:
            block_once=false;entered.post();release_boundary.wait()
        super._merge_prepared_sources()
        merged.post()
var checks=0
var failures=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SELECTION_SOURCE_HANDOFF_FAIL ",label)
func _initialize()->void:run.call_deferred()
func settle(owner:Dictionary)->void:
    for turn in 1200:
        Selection.poll(owner)
        if owner.task<0:return
        await process_frame
    check(false,"Finite selected metadata job completes")
func source_count(cache:Dictionary)->int:
    return cache.get(BodySources.KEY,{}).get("loaded",{}).size()
func run()->void:
    var directory="res://.runtime/player-runs/20261015T152417.554892Z"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--run="):directory=arg.trim_prefix("--run=")
    var journal=Journal.new()
    check(journal.open(directory.path_join("journal"),true,false).ok,"Actual live recording opens offline")
    check(journal.replay(4).ok,"Actual state before first Fireball reduces through SDK")
    var raw=FileAccess.get_file_as_bytes(directory.path_join("journal/0000000000000005.json"))
    var decoded=journal.protocol.decode("PlayerOperation",raw)
    check(decoded.ok,"Actual received Fireball packet passes strict admission")
    var cache={}
    # Match the session worker's existing authoring lifetime before this packet.
    for sequence in range(1,5):
        check(journal.replay(sequence-1).ok,"Prior actual state reduces: "+str(sequence))
        var prior=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("journal/%016d.json" % sequence)))
        check(prior.ok,"Prior actual operation admits: "+str(sequence))
        var planned=Compiler.compile(journal.state,journal.protocol.normalize("PlayerOperation",prior.value),cache)
        check(planned.ok,"Prior actual operation compiles: "+str(sequence))
        Media.prepare_handoff(journal.state,planned.value.groups,cache)
    check(journal.replay(4).ok,"Original first Fireball boundary restored after authoring warmup")
    var compiled=Compiler.compile(journal.state,journal.protocol.normalize("PlayerOperation",decoded.value),cache)
    check(compiled.ok,"Actual Fireball compiles with current authoring")
    var frozen=var_to_bytes(journal.state)
    var witness:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("fireball-hover-4.json")))
    var owner=Selection.create()
    Selection.request(owner,[1,"selected"],journal.state.audience.controlled[0],witness.request.behavior,journal.state,16*1024*1024*1024,{}, {},[],{},"reference")
    await settle(owner)
    check(not owner.value.is_empty() and source_count(owner.value.source_files)>0,
        "Actual selected spell admits native body descriptors and their baked socket samples before server playback")
    var files:Dictionary=owner.value.source_files
    var count=source_count(files)
    var source_owner:Dictionary=files[BodySources.KEY]
    check(source_owner.is_read_only() and source_owner.loaded.is_read_only(),"Selected source references belong to an immutable admitted shell")
    var shared=BoundarySession.new();shared.authoring_cache=cache.duplicate()
    var active_owner:Dictionary=shared.authoring_cache.get(BodySources.KEY,{})
    check(shared._ensure_preparer().ok,"Existing session preparer starts")
    shared.entered.wait()
    shared.offer_prepared_sources(files,owner.value.get("source_headers",{}))
    shared.offer_prepared_sources(files,owner.value.get("source_headers",{}))
    check(is_same(shared.authoring_cache.get(BodySources.KEY,{}),active_owner) and source_count(shared.source_files_pending)==count,
        "Offers coalesce under mutex without touching the active worker's admitted source owner")
    check(shared.source_files_pending.keys().all(func(path):return ((path is String and path.ends_with(".json") and not path.begins_with("__"))
        or path in [BodySources.KEY,"__native_spell_admission","__environment_source_records","native_references_validated","native_authoring_errors"]))
        and not shared.source_files_pending.has("__required_headers"),"Only immutable source documents and native admissions cross, not mutable derived caches")
    shared.release_boundary.post();shared.merged.wait()
    check(shared.source_files_pending.is_empty() and source_count(shared.authoring_cache)>=count,"Worker boundary adopts all prepared native sources and clears the pending shell")
    check(source_owner.loaded.keys().all(func(path):return is_same(shared.authoring_cache[BodySources.KEY].loaded.get(path),source_owner.loaded[path])),
        "Immutable native metadata and its baked optical samples transfer without copying source Resources")
    check(shared.authoring_cache.get("__required_headers",{}).size()>=owner.value.get("source_headers",{}).size(),"Already inspected image headers cross the same worker boundary")
    var warm_cache=shared.authoring_cache.duplicate()
    shared.close()
    shared.offer_prepared_sources(files)
    check(shared.source_files_pending.is_empty(),"Closed session rejects late offers and has no pending metadata")
    var untouched=Session.new()
    var mutable_manifest={Samples.MANIFEST:{"valid":true}}
    untouched.offer_prepared_sources(mutable_manifest)
    check(not untouched.source_files_pending.has(Samples.MANIFEST),"Mutable or unqualified legacy sample documents cannot enter the mailbox")
    untouched.offer_prepared_sources(files)
    untouched.close()
    check(untouched.source_files_pending.is_empty() and untouched.authoring_cache.is_empty(),"Close discards offered work before any preparer starts")
    var canceled=Selection.create()
    Selection.request(canceled,[2,"obsolete"],journal.state.audience.controlled[0],witness.request.behavior,journal.state,16*1024*1024*1024)
    Selection.cancel(canceled)
    await settle(canceled)
    check(canceled.value.is_empty(),"Canceled selected work never publishes a source offer")
    Selection.close(canceled)
    var cold=Media.prepare_handoff(journal.state,compiled.value.groups,cache)
    var prior_count=source_count(warm_cache)
    var warmed=Media.prepare_handoff(journal.state,compiled.value.groups,warm_cache)
    check(warmed.value==cold.value,"Actual required paths, roles, sizes and errors remain identical after metadata transfer")
    check(source_count(warm_cache)==prior_count,"Actual first Fireball requires no additional native body admission after selected metadata transfer")
    check(var_to_bytes(journal.state)==frozen,"Selection/source transfer changes no canonical actor or event data")
    var report={"checks":checks,"failures":failures,"native_body_sources":count,"cold_phases_ms":cold.phases,"selected_phases_ms":warmed.phases,"scope":"Actual selected native authoring to actual received Fireball metadata; worker boundary, coalescing, immutable identity, cancel/close. No image readiness, GPU or full-game latency claim."}
    Selection.close(owner)
    FileAccess.open("res://.runtime/selection-source-handoff-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SELECTION_SOURCE_HANDOFF_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
