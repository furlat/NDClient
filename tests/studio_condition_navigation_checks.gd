extends SceneTree
## Recorded condition spans retain their causal identity across faction views.
## This checks index/navigation values, not native rendering or new SDK states.
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_NAVIGATION_FAIL ",label)

func _initialize()->void:
    var name="condition_owners-seed4"
    var perspectives=[]
    for id in ["amber","blue"]:
        perspectives.append({"id":id,"label":id.capitalize(),"journal":"res://.runtime/studio-cases/"+name+"/"+id+"/journal"})
    var bundle=Recording.read_case({"id":name,"perspectives":perspectives})
    check(bundle.ok,"Actual independent condition-owner recordings compile")
    if not bundle.ok:_finish();return
    var views={}
    for id in bundle.views:views[id]=Recording.view_index(bundle,id)
    var later=0
    var exits=0
    var missing_checked=false
    var reselection_checked=false
    for id in views:
        var source:Dictionary=views[id]
        var target:Dictionary=views["blue" if id=="amber" else "amber"]
        var target_rows={}
        for row in target.rows:
            if row.get("visible_here",true):target_rows[row.id]=row
        for row in source.rows:
            if not row.get("visible_here",true) or not row.has("owner") or not ":member:" in row.id:continue
            check(target_rows.has(row.id),"Same recorded owner component exists in both actual views")
            if not target_rows.has(row.id):continue
            var counterpart:Dictionary=target_rows[row.id]
            var at=lerpf(row.start_ms,row.end_ms,.5)
            var anchor=Recording.navigation_anchor(source,at,row)
            check(is_equal_approx(Recording.anchor_time(source,anchor),at),"Selecting a real span maps back to itself: "+row.id)
            var mapped=Recording.anchor_time(target,anchor)
            var expected=lerpf(counterpart.start_ms,counterpart.end_ms,.5)
            check(is_equal_approx(mapped,expected),"Faction navigation keeps this exact span: "+row.id)
            anchor.mapped_time_ms=mapped
            var returning=Recording.navigation_anchor(target,mapped,counterpart,anchor)
            check(is_equal_approx(Recording.anchor_time(source,returning),at),"Faction roundtrip retains exact span phase: "+row.id)
            if not reselection_checked and anchor.event_uuid.is_empty():
                for other in source.rows:
                    if not other.get("visible_here",true) or not other.has("owner") or other.id==row.id or at<other.start_ms or at>other.end_ms:continue
                    var changed=Recording.navigation_anchor(source,at,other)
                    if not changed.event_uuid.is_empty() or changed.row_key==anchor.row_key:continue
                    var held=anchor.duplicate();held.mapped_time_ms=at
                    check(Recording.navigation_anchor(source,at,other,held).row_key==changed.row_key,"Selecting another real condition row at the held time replaces the old anchor despite both having no event UUID")
                    reselection_checked=true;break
            if row.start_ms>row.owner.start_ms:later+=1
            if row.condition_phase=="condition_exit":exits+=1
            if evidence.size()<8 and row.start_ms>row.owner.start_ms:
                evidence.append({"view":id,"row":row.id,"causes":row.interval_causes,"source_ms":at,"mapped_ms":mapped,"expected_ms":expected})
            if missing_checked or row.start_ms<=row.owner.start_ms:continue
            var commit:Variant=null
            for cause in row.interval_causes:
                if not cause.begins_with("event:"):continue
                var event:Dictionary=target.clock_events.get(cause.trim_prefix("event:"),{})
                for marker in event.get("markers",[]):
                    if marker.kind=="commit":commit=marker.at_ms;break
                if commit!=null:break
            if commit==null:continue
            # Navigation-only value fixture: omit exactly this inspected span,
            # retaining the actual target recording and its causal commit rows.
            var without=target.duplicate()
            without.rows=target.rows.filter(func(value):return value.id!=counterpart.id)
            check(is_equal_approx(Recording.anchor_time(without,anchor),commit),"Absent visual span falls back to its actual shared commit, never an earlier same-kind span")
            missing_checked=true
    check(later>0 and exits>0,"Real fixture exercises later active spans and removal tails")
    check(missing_checked,"Actual later span supplies the missing-span causal fallback case")
    check(reselection_checked,"Actual overlapping condition rows exercise held-time reselection")
    _finish()

func _finish()->void:
    FileAccess.open("res://generated/studio_condition_navigation_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real condition-owner faction navigation values; no pixel or renderer qualification."},"  "))
    print("STUDIO_CONDITION_NAVIGATION ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
