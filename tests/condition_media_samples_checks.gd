extends SceneTree
const Samples=preload("res://presentation/condition_media_samples.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Conditions=preload("res://presentation/conditions.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_MEDIA_FAIL ",label)
func run()->void:
    var path=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--oracle="):path=argument.trim_prefix("--oracle=")
    if path.is_empty():push_error("Explicit --oracle required");quit(2);return
    var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var cache={}
    for case in oracle.cases:
        var row=case.duplicate(true);row.alpha=.1;row.selection_alpha=1.0
        var held=row.duplicate(true)
        var parts=Samples.sample(row,cache)
        check(parts.size()==case.expected.size(),"Original bank sample count "+case.name)
        for i in mini(parts.size(),case.expected.size()):
            var sample:Dictionary=parts[i];var expected:Dictionary=case.expected[i]
            var phase:Dictionary=sample.media.definition.phases.impact
            var frame=floori(sample.source_age_ms*phase.fps/1000.0)
            frame=posmod(frame,int(phase.frames)) if phase.get("loop",false) else mini(frame,int(phase.frames)-1)
            check(sample.media.asset_id==expected.asset_id and frame==expected.frame and absf(sample.alpha-expected.alpha)<.000001,"Original phase/frame/opacity "+case.name+":"+str(i))
        check(row==held,"Sampler keeps owner/input immutable "+case.name)
    var condition:Dictionary=oracle.condition
    var owner={"id":condition.condition_uuid,"condition":condition,"actor_uuid":"actor","start_ms":0.0,"end_ms":INF,"initial":false,"life_state":"alive"}
    var owners={owner.id:owner}
    var raw=Conditions.samples(owners,620,cache,{},false).filter(func(row):return row.kind=="registered_media")
    check(raw.size()==2 and raw.all(func(row):return row.media_samples.size()==2),"Actual owner exposes both authored entry/hold blend banks in each partition")
    var ids=raw.map(func(row):return row.id)
    Conditions.observe(owners,{"actor":{"life_state":"alive","conditions":[]}},620)
    var release=Conditions.samples(owners,695,cache,{},false).filter(func(row):return row.kind=="registered_media")
    check(release.map(func(row):return row.id)==ids and release.all(func(row):return row.media_samples.size()==3),"Removal freezes blended entry/hold, adds release under stable layer identities")
    check(is_equal_approx(Conditions.fade_ms(condition,cache),87.0/32.0*1000),"Owner tail uses original release bank duration")
    check(Conditions.samples(owners,620+87.0/32.0*1000,cache).is_empty(),"Released owner expires exactly after finite source bank")
    var initial=owner.duplicate();initial.initial=true;initial.end_ms=INF
    check(Conditions.samples({initial.id:initial},0,cache,{},false).filter(func(row):return row.kind=="registered_media").all(func(row):return row.media_samples.size()==1 and row.media_samples[0].part_id=="sustain"),"Already-active initialization enters sustain without invented application")
    var paths=Conditions.paths({"conditions":[condition]},cache)
    var complete=true
    for asset in ["control.hold_human.apply.back","control.hold_human.hold.back","control.hold_human.release.back","control.hold_human.apply.front","control.hold_human.hold.front","control.hold_human.release.front"]:
        for source in Samples.RegisteredMedia.resolve(asset,cache).paths:complete=complete and paths.has(source)
    check(complete,"Required current condition source closure includes both entry and release banks")
    var thumbnails=Thumbnails.new()
    var thumbnail={"id":"phase-cache","kind":"registered_media","status":"available","start_ms":0.0,"component":raw[0]}
    var first_key=thumbnails.request(thumbnail,1000,0)
    thumbnail.component=release[0]
    var release_key=thumbnails.request(thumbnail,1000,0)
    check(first_key!=release_key and thumbnails.pending.size()==2,"Same owner-clock sample retains distinct entry/hold versus release phase cache identity")
    check(thumbnails.pending[1].component.media_samples==release[0].media_samples,"Thumbnail job retains the complete immutable sampled phase packet")
    thumbnails.close()
    var report={"checks":checks,"failures":failures,"cases":oracle.cases.size(),"source":oracle.source,"recording":oracle.recording,"scope":"Exact original HoldPerson sample operator, owner lifetime and resource closure; native image composition remains separate"}
    FileAccess.open("res://generated/condition_media_samples_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CONDITION_MEDIA_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
