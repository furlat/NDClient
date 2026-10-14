extends SceneTree
## Same real encounter, separate authorized reducers, shared causal navigation.
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("PERSPECTIVE_FAIL ",label)

func _case(name:String)->Dictionary:
    var perspectives=[]
    for id in ["amber","blue"]:
        perspectives.append({"id":id,"label":id.capitalize(),"journal":"res://.runtime/studio-cases/"+name+"/"+id+"/journal"})
    return {"id":name,"perspectives":perspectives}

func _initialize()->void:
    for name in ["dash-seed3","hide-seed3-v3","oa_jump_lethal-seed5-v2","invisibility-seed3-v2"]:
        var bundle=Recording.read_case(_case(name))
        check(bundle.ok,"Original faction prefixes compile: "+name)
        if not bundle.ok:continue
        var views={}
        for id in bundle.views:
            var original:Dictionary=bundle.views[id]
            var before=JSON.stringify(original.initialization)
            var view=Recording.view_index(bundle,id);views[id]=view
            check(view.ok,"Combined inspection index opens: "+name+" / "+id)
            check(is_same(view.groups,original.groups) and is_same(view.initialization,original.initialization),"Inspection shares unchanged executable recording, no union gameplay state")
            var ids={}
            for row in view.rows:
                check(not ids.has(row.id),"Inspection row identity remains unique")
                ids[row.id]=true
            for row in view.rows:
                check(row.parent.is_empty() or ids.has(row.parent),"Every inspected effect retains an existing causal owner")
                if row.kind=="event" and row.get("split_views",false):
                    var branches=view.rows.filter(func(child):return child.kind=="perspective" and child.parent==row.id)
                    check(branches.size()==bundle.perspectives.size(),"One shared occurrence contains every recorded faction branch")
                    check(branches.all(func(branch):return branch.source_event_uuid==row.event.event_uuid),"Split branches refer to the same event identity")
                if row.get("kind")=="other_view":
                    check(not row.visible_here and row.source_perspective!=id and not row.source_row_id.is_empty(),"Other faction requirement has explicit source and navigation")
                    if row.get("timing_status")=="other_perspective":check(row.end_ms==row.start_ms,"Unknown audience timing is not a fabricated interval")
            for fraction in [0.0,.25,.5,1.0]:
                var at=original.get("presentation_end_ms",original.duration_ms)*fraction
                var expected=Recording.restore(original,at)
                var actual=Recording.restore(view,at)
                check(actual.state==expected.state and actual.sequence==expected.sequence,"Combined inspection never changes faction reduction at %.3f"%at)
            check(before==JSON.stringify(original.initialization),"Repeated view restores do not mutate recorded initialization")
            evidence.append({"case":name,"faction":id,"own_rows":original.rows.size(),"combined_rows":view.rows.size(),"duration_ms":view.duration_ms})
        var a:Dictionary=views.amber;var b:Dictionary=views.blue
        for row in a.clock_events.values():
            if row.end_ms<=row.start_ms or not b.clock_events.has(row.event.event_uuid):continue
            var counterpart:Dictionary=b.clock_events[row.event.event_uuid]
            if counterpart.end_ms<=counterpart.start_ms:continue
            for phase in [.1,.5,.9]:
                var at=lerpf(row.start_ms,row.end_ms,phase)
                var mapped=Recording.switch_time(a,b,at,row)
                check(is_equal_approx(mapped,lerpf(counterpart.start_ms,counterpart.end_ms,phase)),"Faction switch preserves shared occurrence phase")
                check(is_equal_approx(Recording.switch_time(b,a,mapped,counterpart),at),"Faction roundtrip returns to the same occurrence phase")
        if name=="invisibility-seed3-v2":
            var actor_steps=a.clock_events.values().filter(func(row):return row.event.kind=="step")
            var enemy_steps=b.clock_events.values().filter(func(row):return row.event.kind=="step")
            actor_steps.sort_custom(func(x,y):return x.start_ms<y.start_ms)
            check(actor_steps.size()==2 and enemy_steps.size()==1,"Real Invisibility case has one unseen move and one move revealed by See Invisibility")
            if actor_steps.size()==2 and enemy_steps.size()==1:
                check(enemy_steps[0].event.event_uuid==actor_steps[1].event.event_uuid,"Enemy sees the second actual movement occurrence, never a fabricated copy of the unseen one")
                var invisible=actor_steps[0]
                var shared=a.rows.filter(func(row):return row.kind=="event" and row.event.event_uuid==invisible.event.event_uuid)
                check(shared.size()==1 and shared[0].get("split_views",false),"Unseen movement has one causal event with split audience tracks")
                var at=lerpf(invisible.start_ms,invisible.end_ms,.5)
                var anchor=Recording.navigation_anchor(a,at,invisible)
                var enemy_at=Recording.anchor_time(b,anchor);anchor.mapped_time_ms=enemy_at
                var counterpart:Dictionary={}
                for row in b.rows:
                    if (row.kind=="event" or row.get("source_kind")=="event") and row.get("event",{}).get("event_uuid")==invisible.event.event_uuid:counterpart=row;break
                check(not counterpart.is_empty(),"Enemy inspection retains the shared unseen occurrence as a selectable event")
                var back=Recording.navigation_anchor(b,enemy_at,counterpart,anchor)
                check(is_equal_approx(Recording.anchor_time(a,back),at),"Invisible movement phase survives a switch through the enemy's zero-duration view")
        if name=="hide-seed3-v3":
            var hidden:Dictionary={}
            for row in a.rows:
                if row.kind=="condition" and row.owner.condition.behavior_id=="condition.hidden":hidden=row
            check(not hidden.is_empty(),"Actual Hide capture supplies hidden condition lifetime")
            if not hidden.is_empty():
                check(b.rows.any(func(row):return row.get("source_kind")=="condition" and row.get("owner",{}).get("id")==hidden.owner.id and not row.visible_here),"Combined Blue inspector exposes Amber-only Hidden lifetime")
                check(not bundle.views.blue.rows.any(func(row):return row.kind=="condition" and row.owner.id==hidden.owner.id),"Blue production recording never receives Amber's hidden condition")
                var cause=hidden.owner.condition.get("event_uuid","")
                var by_id={}
                for row in a.rows:by_id[row.id]=row
                var parent:String=hidden.parent
                while by_id.has(parent) and by_id[parent].kind!="event":parent=by_id[parent].parent
                check(a.clock_events.has(cause) and parent==a.clock_events[cause].id,"Retained condition is nested under its recorded application cause and faction")
                check(a.rows.any(func(row):return row.kind=="event" and row.get("split_views",false) and row.event.event_uuid==cause),"Real hidden condition creates split inspection timelines for the same occurrence")
                var at=minf(hidden.end_ms-.001,hidden.start_ms+30)
                var anchor=Recording.navigation_anchor(a,at,hidden)
                var enemy_time=Recording.anchor_time(b,anchor)
                anchor.mapped_time_ms=enemy_time
                var other_hidden:Dictionary={}
                for row in b.rows:
                    if row.get("source_kind")=="condition" and row.get("owner",{}).get("id")==hidden.owner.id:other_hidden=row;break
                var returning=Recording.navigation_anchor(b,enemy_time,other_hidden,anchor)
                check(is_equal_approx(Recording.anchor_time(a,returning),at),"Amber30ms through unseen zero-duration Blue view returns to same Hidden phase, not later attack")
    var mixed=_case("dash-seed3")
    mixed.perspectives[1].journal="res://.runtime/studio-cases/hide-seed3-v3/blue/journal"
    check(not Recording.read_case(mixed).ok,"Reject two unrelated encounter epochs instead of treating them as factions")
    var report={"checks":checks,"failures":failures,"recordings":evidence,"scope":"Real recorded faction switching and combined requirements, with unchanged authorized reducer/display input per faction."}
    FileAccess.open("res://generated/studio_perspective_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_PERSPECTIVES ",checks," checks; ",failures.size()," failures")
    quit(0 if failures.is_empty() else 1)
