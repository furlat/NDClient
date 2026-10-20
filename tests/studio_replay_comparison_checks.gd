extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Real independent SDK journals, aligned causes, original rates and exact prefixes.
const Recording=preload("res://studio/recording.gd")
const Compare=preload("res://studio/replay_comparison.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Tracks=preload("res://presentation/tracks.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var max_source_sample_error=0.0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("REPLAY_COMPARISON_FAIL ",label)
func read_case(name:String)->Dictionary:
    return Recording.read_case(Fixtures.case_record(name))
func run()->void:
    for name in ["hide","invisibility","oa-jump","oa-jump-lethal","oa-jump-late-lethal"]:
        var bundle=read_case(name)
        check(bundle.ok,name+": both independent SDK journals admit")
        if not bundle.ok:continue
        var original=JSON.stringify(bundle.views)
        var compared=Recording.compare_case(bundle)
        check(compared.ok,name+": causal comparison admits")
        if not compared.ok:print(compared);continue
        check(JSON.stringify(bundle.views)==original,name+": comparison leaves original single-view indexes immutable")
        if not compared.comparison:
            check(compared.views==bundle.views,name+": identical presentations retain the single-view path")
            continue
        if name=="oa-jump-late-lethal":
            var arrivals={};var starts={};var lengths={}
            for view in compared.views:
                for item in compared.views[view].groups:
                    for track in item.group.actor_tracks:
                        if track.source_event_uuid!="a70ba8a2-4f46-4a1c-998f-22494304d4ab":continue
                        starts[view]=item.start_ms+track.start_ms
                        lengths[view]=track.duration_ms
                        arrivals[view]=starts[view]+lengths[view]
                        for commit in item.group.commits:
                            if commit.get("event_uuid")==track.source_event_uuid:
                                check(absf(arrivals[view]-item.start_ms-commit.at_ms)<.00001,"Late lethal "+view+": native jump arrives at its shared authoritative commit")
            check(absf(lengths.get("amber",0)-425.0)<.00001 and absf(lengths.get("blue",0)-416.666666666667)<.00001,"Late lethal: original independently compiled 425ms/416.667ms jump durations are unchanged")
            check(absf(arrivals.amber-arrivals.blue)<.00001 and absf(starts.blue-starts.amber-8.333333333333)<.00001,"Late lethal: shorter native jump holds before starting and both views reach the same arrival")
        var times={0.0:true,compared.presentation_end_ms:true}
        var shared={}
        for cut in compared.schedule:
            times[cut.common_ms]=true
            if cut.common_ms>.01:times[cut.common_ms-.01]=true
            if cut.correspondence_key.begins_with("shared:"):
                if shared.has(cut.correspondence_key):check(absf(shared[cut.correspondence_key]-cut.common_ms)<.00001,name+": shared event commit has one common causal cut")
                shared[cut.correspondence_key]=cut.common_ms
        for view in bundle.views:
            var old:Dictionary=bundle.views[view];var aligned:Dictionary=compared.views[view]
            check(old.groups.size()==aligned.groups.size(),name+" "+view+": no authoritative groups invented or dropped")
            var expected=old.initialization.state.duplicate(true)
            for g in old.groups.size():
                var a:Dictionary=old.groups[g].group;var b:Dictionary=aligned.groups[g].group
                check(a.id==b.id and a.commits.size()==b.commits.size(),name+" "+view+": own group/commit identities retained")
                var prior=-INF
                for c in a.commits.size():
                    check(a.commits[c].get("event_uuid")==b.commits[c].get("event_uuid") and a.commits[c].delta==b.commits[c].delta,name+" "+view+": original ordered delta retained")
                    check(b.commits[c].at_ms+Compare.EPS>=prior,name+" "+view+": no own commit order inversion")
                    prior=b.commits[c].at_ms
                    Compiler.apply_delta(expected,a.commits[c].delta)
                    var exact=Recording.restore_boundary(aligned,g,c+1)
                    check(exact!=null and exact.state==expected,name+" "+view+": exact ordinal prefix excludes later equal-time commits")
                check(a.actor_tracks.size()==b.actor_tracks.size(),name+" "+view+": no actor animation invented")
                for t in a.actor_tracks.size():
                    var before:Dictionary=a.actor_tracks[t];var after:Dictionary=b.actor_tracks[t]
                    check(before.duration_ms==after.duration_ms and before.get("source_time_keys")==after.get("source_time_keys") and before.source_start_seconds==after.source_start_seconds and before.source_end_seconds==after.source_end_seconds,name+" "+view+": original animation duration and source cadence retained")
                    for f in [.2,.7]:
                        var first:Dictionary=Tracks.samples([before],before.start_ms+before.duration_ms*f).get(before.actor_uuid,{})
                        var second:Dictionary=Tracks.samples([after],after.start_ms+after.duration_ms*f).get(after.actor_uuid,{})
                        for field in ["clip","source_seconds","position","lift_pixels"]:
                            if first.has(field):
                                var same=first[field]==second.get(field)
                                if field=="source_seconds":
                                    # Translating an unchanged interval can round
                                    # (absolute-start)/duration at machine precision.
                                    var error=absf(first[field]-second[field])
                                    max_source_sample_error=maxf(max_source_sample_error,error)
                                    same=error<1e-12
                                check(same,name+" "+view+": source/motion sample unchanged at native phase "+field)
                check(a.get("components",[]).size()==b.get("components",[]).size(),name+" "+view+": no effect or audio component invented")
                for c in a.get("components",[]).size():
                    check(a.components[c].duration_ms==b.components[c].duration_ms,name+" "+view+": source effect/audio duration unchanged")
                    var before:Dictionary=a.components[c];var after:Dictionary=b.components[c]
                    var source_track:Dictionary=before.get("source_track",{})
                    var anchor:float=before.get("contact_ms",before.start_ms)
                    var after_anchor:float=after.get("contact_ms",after.start_ms)
                    if before.kind=="audio":
                        for field in ["source_sync_s","clip_duration_s","source_frame","contact_id","timing_selector"]:
                            if before.has(field):check(before[field]==after.get(field),name+" "+view+": authored audio source/contact provenance unchanged "+field)
                        if before.has("contact_ms"):
                            check(absf((after.contact_ms-after.start_ms)-(before.contact_ms-before.start_ms))<.00001,name+" "+view+": audio preroll translates with contact without scaling source time")
                        if before.has("body_track_id"):
                            for t in a.actor_tracks.size():
                                if a.actor_tracks[t].trace_track_id==before.body_track_id:
                                    check(absf((after_anchor-b.actor_tracks[t].start_ms)-(anchor-a.actor_tracks[t].start_ms))<.00001,name+" "+view+": source contact follows this view's original native body phase")
                    if not before.has("body_track_id") and source_track.get("source_event_uuid")!=before.source_event_uuid:
                        for commit in a.commits.size():
                            if a.commits[commit].get("event_uuid")==before.source_event_uuid and absf(a.commits[commit].at_ms-anchor)<.00001:
                                check(absf(after_anchor-b.commits[commit].at_ms)<.00001,name+" "+view+": impact/audio contact follows its own commit even with another event's recipient pose")
            for time in times:
                var prefix=old.initialization.state.duplicate(true)
                for g in old.groups.size():
                    for c in old.groups[g].group.commits.size():
                        if aligned.groups[g].start_ms+aligned.groups[g].group.commits[c].at_ms<=time+.000001:Compiler.apply_delta(prefix,old.groups[g].group.commits[c].delta)
                var restored=Recording.restore(aligned,time)
                check(restored.state==prefix,name+" "+view+": common-time seek equals only this audience's causal prefix")
            var terminal=Recording.restore(aligned,compared.presentation_end_ms)
            var old_terminal=Recording.restore(old,old.presentation_end_ms)
            check(terminal.state==old_terminal.state,name+" "+view+": final authoritative state unchanged")
        var inspect=Recording.view_index(compared,"amber")
        check(inspect.ok and inspect.rows.all(func(row):return row.kind!="other_view" and row.get("visible_here",true)),name+": both displayed factions retain actual common-time inspection rows")
        var by_id={}
        for row in inspect.rows:by_id[row.id]=row
        check(inspect.rows.all(func(row):return row.parent.is_empty() or by_id.has(row.parent)),name+": comparison subtracks retain real shared parents")
        check(inspect.rows.filter(func(row):return row.kind=="body" and "blue" in row.audiences).size()>0,name+": peer native sprite rows remain inspectable or share the identical source lane")
        evidence.append({"case":name,"original_ms":bundle.views.values().map(func(view):return view.presentation_end_ms),"common_ms":compared.presentation_end_ms,"cuts":compared.schedule.size(),"blocks":compared.blocks.size(),"rows":inspect.rows.size()})
    var canceled=Recording.cancellation();Recording.cancel(canceled)
    var bundle=read_case("hide")
    check(Recording.compare_case(bundle,canceled).get("canceled",false),"Superseded comparison projection cancels without publishing a partial pair")
    var same=bundle.duplicate();same.views={"amber":bundle.views.amber,"blue":bundle.views.amber.duplicate(true)}
    check(not Recording.requires_comparison(same),"Identical initial rendering and event sources retain one pane")
    same.views.blue.initialization.state.hud_snapshot=null
    check(not Recording.requires_comparison(same),"Private HUD differences do not manufacture a rendering comparison")
    var tile:String=same.views.blue.initialization.state.tiles.keys()[0]
    same.views.blue.initialization.state.tiles[tile].elevation_steps+=1
    check(Recording.requires_comparison(same),"Different initial rendered terrain requires two panes even with identical later event signatures")
    var baseline=Compare.build(bundle)
    var renumbered=bundle.duplicate(true)
    for item in renumbered.views.blue.groups:
        item.group.operation_sequence+=1000
        for commit in item.group.commits:commit.source_index+=10000
    var independent=Compare.build(renumbered)
    check(independent.ok and independent.duration_ms==baseline.duration_ms and independent.blocks==baseline.blocks,"Alignment joins actual event/lineage identities, not audience packet sequences or local reducer cursor numbers")
    var conflicting=bundle.duplicate(true)
    var swap=conflicting.views.blue.groups[1]
    conflicting.views.blue.groups[1]=conflicting.views.blue.groups[2];conflicting.views.blue.groups[2]=swap
    check(not Compare.build(conflicting).ok,"Conflicting recorded causal order is rejected instead of reordering a view or stretching source animation")
    var report={"checks":checks,"failures":failures,"evidence":evidence,"max_source_sample_error_seconds":max_source_sample_error,"scope":"Pure real-journal common schedule and independent prefix/animation/source inspection; no native dual-pane rendering claim."}
    FileAccess.open("res://generated/studio_replay_comparison_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_REPLAY_COMPARISON ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
