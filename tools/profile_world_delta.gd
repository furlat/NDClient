extends SceneTree
# Focused CPU attribution of authentic late Gallery commits. Headless resources
# exercise live GDScript world/floor/scenery code; this is not a GPU benchmark.
const Journal = preload("res://sdk/journal.gd")
const Compiler = preload("res://presentation/compiler.gd")
const World = preload("res://presentation/world.gd")
class Probe extends "res://tests/ground_visibility_checks.gd".Probe:
    var ground_samples=[]
    func _add_fixture_flame(_row:Dictionary)->void:pass # shader animation upload excluded
    func _ground_update(entry:Dictionary,rows:Array)->void:
        var packets:Dictionary=entry.ground_packets.duplicate()
        var copy: Array=rows.duplicate()
        var started=Time.get_ticks_usec();_ground_sort(copy,packets)
        var sort_ms=(Time.get_ticks_usec()-started)/1000.0
        started=Time.get_ticks_usec()
        super._ground_update(entry,rows)
        ground_samples.append({"rows":rows.size(),"sort_ms":sort_ms,"total_ms":(Time.get_ticks_usec()-started)/1000.0})
var samples=[]
func _initialize()->void:run.call_deferred()
func observe(scene:Node,label:String,delta:Dictionary)->void:
    var state:Dictionary=scene.timeline.presentation_state()
    var misses=0;var changed=0;var same_geometry=0
    for field in ["tiles","objects"]:
        for id in delta.get(field,{}):
            var key:String=field+":"+id
            var old:Dictionary=scene.world_row_cache.get("records",{}).get(key,{})
            if old.is_empty():changed+=1;continue
            if not is_same(old.source,state[field][id]):misses+=1
            var single={"tiles":{},"objects":{},"senses":state.senses};single[field][id]=state[field][id]
            var rows=World.rows(single,scene.catalog_cache).rows
            if not rows.is_empty() and rows[0]==old.row:same_geometry+=1
            else:changed+=1
    scene.profile.phases.clear();scene.ground_samples=[]
    var started=Time.get_ticks_usec();scene._sync_world();var world_ms=(Time.get_ticks_usec()-started)/1000.0
    var index_dirty:bool=scene.scenery_index_dirty
    started=Time.get_ticks_usec();scene._sync_scenery();var scenery_ms=(Time.get_ticks_usec()-started)/1000.0
    started=Time.get_ticks_usec();scene.update_wall_visibility(false);var walls_ms=(Time.get_ticks_usec()-started)/1000.0
    samples.append({"label":label,"delta_tiles":delta.get("tiles",{}).size(),"delta_objects":delta.get("objects",{}).size(),
        "pointer_misses":misses,"same_geometry":same_geometry,"changed_rows":changed,
        "cache_resolved":scene.world_row_cache.resolved,"total_tiles":state.tiles.size(),"total_objects":state.objects.size(),
        "world_ms":world_ms,"scenery_ms":scenery_ms,"walls_ms":walls_ms,"scenery_index_rebuilt":index_dirty,
        "phases":scene.profile.phases.duplicate(),"ground":scene.ground_samples.duplicate()})
func run()->void:
    var directory="res://.runtime/gallery-route/journal"
    var journal=Journal.new();var opened=journal.open(directory,true,false)
    if not opened.ok:print(opened);quit(1);return
    var reduced=journal.replay(97)
    if not reduced.ok:print(reduced);quit(1);return
    var scene=Probe.new();root.add_child(scene);scene.timeline.state=journal.state
    scene.timeline.world_revision=1;scene.timeline.revision=1
    scene._sync_world();scene._sync_scenery();scene.update_wall_visibility(false)
    var cache={}
    for sequence in range(98,101):
        var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence)))
        if not decoded.ok:print(decoded);quit(1);return
        var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
        var compiled=Compiler.compile(scene.timeline.state,packet,cache)
        if not compiled.ok:print(compiled);quit(1);return
        for group in compiled.value.groups:
            # Use exact first-admitted supports before the group's commits.
            scene.timeline.current=group;scene.timeline.group_start_ms=scene.timeline.display_ms
            if not group.staged_tiles.is_empty():observe(scene,"%d staged"%sequence,{})
            for i in range(group.commits.size()):
                var commit:Dictionary=group.commits[i];var delta:Dictionary=commit.delta
                scene.timeline.display_ms=scene.timeline.group_start_ms+float(commit.at_ms)
                Compiler.apply_delta(scene.timeline.state,delta)
                scene.timeline.revision+=1
                if not delta.get("tiles",{}).is_empty() or not delta.get("objects",{}).is_empty() or not delta.get("objects_removed",[]).is_empty() or delta.get("set",{}).has("senses"):
                    scene.timeline.world_revision+=1
                    observe(scene,"%d %s/%d"%[sequence,group.id,i],delta)
            scene.timeline.current={}
        scene.timeline.sequence=sequence
    var report={"scope":"Headless CPU of live world/floor/scenery code on original operation98–100 sparse commits and staged support. Fixture flame uploads and all GPU time excluded; initial source decode excluded.","samples":samples}
    FileAccess.open("res://generated/gallery_world_delta_cpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_DELTA_CPU ",samples.size()," samples")
    scene.queue_free();await process_frame;quit()
