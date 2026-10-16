extends SceneTree
## Exact native metadata values across the category→selected-clip boundary.
const Sources=preload("res://presentation/body_sources.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
var categories:int=0
var clips:int=0
var descriptors:int=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("THIN_BODY_FAIL ",label)

func expected_descriptor(value:Dictionary,old_path:String,new_path:String)->Dictionary:
    var result:Dictionary=value.duplicate(true)
    # Revision-qualified physical IDs retain their exact category/clip/slot
    # suffix. Only this explicit import's revision directory changes.
    var records:Array=result.source_records.values()+[result.native_record]
    for record in records:
        var id:String=str(record.source_id)
        check(id.begins_with(old_path),"Previous source ID belongs to its native category")
        record.source_id=StringName(new_path+id.trim_prefix(old_path))
    return result

func compare_layer(old_path:String,new_path:String,cache:Dictionary)->void:
    var previous=ResourceLoader.load(old_path,"",ResourceLoader.CACHE_MODE_REUSE)
    var selected=Sources.prepare_layer(new_path,cache)
    check(previous!=null and selected!=null,"Both admitted category revisions load: "+new_path)
    if previous==null or selected==null:return
    categories+=1
    check(previous.rig_id==selected.rig_id and previous.category==selected.category,"Category selector values are exact")
    check(previous.headers==selected.headers,"Every original source header is exact")
    check(previous.clips.keys()==selected.clips.keys(),"Every authored clip remains indexed in order")
    var cold:Dictionary={Sources.KEY:{"index":Sources.index(cache),"loaded":{new_path:selected}}}
    var before:Dictionary=cold[Sources.KEY].loaded
    for clip_name in previous.clips:
        var held:Dictionary=Catalog.source_snapshot(cache)
        var held_loaded:Dictionary=held[Sources.KEY].loaded
        var clip_path:String=selected.clip_sources[clip_name]
        var already_admitted:bool=held_loaded.has(clip_path)
        var heavy=Sources.prepare_clip(selected,clip_name,cache)
        check(heavy!=null,"Selected clip admits: "+new_path+"/"+clip_name)
        if heavy==null:continue
        clips+=1
        check(heavy.descriptors.keys()==previous.clips[clip_name].keys(),"All physical slot descriptors remain ordered")
        for slot in previous.clips[clip_name]:
            var expected:Dictionary=expected_descriptor(previous.clips[clip_name][slot],old_path,new_path)
            var actual:Dictionary=heavy.descriptors[slot]
            descriptors+=1
            check(actual==expected,"All geometry/socket/optical/profile/role facts are exact: "+new_path+"/"+clip_name+"/"+slot)
            check(selected.clips[clip_name][slot]=={"path":actual.path,"companions":actual.companions},"Optional discovery summary preserves actual source paths")
            check(selected.paths_by_slot[slot][clip_name]==actual.path,"Shared actor path map preserves exact clip selection")
            check(Sources.descriptor(actual.path,slot,cold).is_empty(),"Thin category admission cannot expose an unprepared clip")
            check(is_same(before,cold[Sources.KEY].loaded),"Sampling lookup does not admit heavy clip metadata")
        check(already_admitted or not held_loaded.has(clip_path),"New clip admission does not mutate an earlier handoff")
        check(Sources.prepare_clip(selected,clip_name,cache)==heavy,"Repeated physical source admission reuses the clip Resource")
        check(is_same(held_loaded,held[Sources.KEY].loaded),"Later admission does not mutate an earlier handoff")

func run()->void:
    var old_index_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--previous-index="):old_index_path=argument.trim_prefix("--previous-index=")
    if old_index_path.is_empty():printerr("Requires --previous-index=<frozen native category index>");quit(2);return
    var previous=ResourceLoader.load(old_index_path,"",ResourceLoader.CACHE_MODE_REUSE)
    var cache:Dictionary={};var current=Sources.index(cache)
    check(previous!=null and current!=null,"Frozen and current native indexes load")
    if previous==null or current==null:quit(1);return
    for field in ["root_rig","creature_rigs","rigs","equipment","equipment_errors","sheets"]:
        check(previous.get(field)==current.get(field),"Native index preserves "+field)
    check(previous.layers.keys()==current.layers.keys(),"All rig/category selectors remain ordered")
    var seen:Dictionary={}
    for rig in previous.layers:
        check(previous.layers[rig].keys()==current.layers[rig].keys(),"All categories remain available: "+rig)
        for category in previous.layers[rig]:
            compare_layer(previous.layers[rig][category],current.layers[rig][category],cache)
            seen[previous.layers[rig][category]]=true
    for path in previous.source_owners:
        var old_owner:Array=previous.source_owners[path]
        var new_owner:Array=current.source_owners.get(path,[])
        check(not new_owner.is_empty() and old_owner[1]==new_owner[1],"Physical source keeps its exact clip owner: "+path)
        if new_owner.is_empty():continue
        if not seen.has(old_owner[0]):compare_layer(old_owner[0],new_owner[0],cache);seen[old_owner[0]]=true
    var report:Dictionary={"checks":checks,"failures":failures,"categories":categories,"clips":clips,"descriptors":descriptors,
        "scope":"All native category/clip facts against frozen pre-split Resources, required lookup-only admission and immutable handoffs; no live latency claim."}
    FileAccess.open("res://generated/thin_body_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("THIN_BODY_SOURCE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
