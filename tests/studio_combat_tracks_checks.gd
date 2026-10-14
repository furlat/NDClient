extends SceneTree
## Real recording -> default visible timeline: attacker and defender bodies are
## inspectable together beneath the same attack, with their actual owners and
## unchanged source clock. This checks UI projection, not render acceptance.
const Recording=preload("res://studio/recording.gd")
const TimelineView=preload("res://studio/timeline_view.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_COMBAT_TRACKS_FAIL ",label)
func run()->void:
    for name in ["dash-seed3","melee-seed3"]:
        var index=Recording.read("res://.runtime/studio-cases/"+name+"/amber/journal")
        check(index.ok,name+" real journal admits")
        if not index.ok:continue
        var before=index.groups.duplicate(true)
        var attacks=index.rows.filter(func(row):return row.kind=="event" and row.event.kind=="attack")
        var hits=index.rows.filter(func(row):return row.kind=="body" and row.track.clip=="TakeDamage")
        check(not attacks.is_empty() and not hits.is_empty(),name+" contains real attack and defender hit reaction")
        if attacks.is_empty() or hits.is_empty():continue
        var view=TimelineView.new();view.size=Vector2(1280,400);view.set_index(index)
        var hit:Dictionary=hits[0]
        check(view.rows.any(func(item):return item.row.id==hit.id),name+" default visible timeline exposes defender TakeDamage")
        for attack in attacks:
            view.reveal(attack.id)
            var descendants={attack.id:true}
            # Actual source parent IDs may precede or follow their descendants.
            for pass_index in index.rows.size():
                var grew=false
                for row in index.rows:
                    if descendants.has(row.parent) and not descendants.has(row.id):descendants[row.id]=true;grew=true
                if not grew:break
            for body in index.rows:
                if body.kind!="body" or not descendants.has(body.id):continue
                var shown=view.rows.filter(func(item):return item.row.id==body.id)
                check(shown.size()==1,name+" focused attack exposes every affected actor body: "+body.track.clip)
                if not shown.is_empty():check(shown[0].row.start_ms==body.start_ms and shown[0].row.end_ms==body.end_ms,name+" visible body retains exact authored clock")
                var actor=index.initialization.state.actors.get(body.track.actor_uuid,{})
                check(body.get("actor_name","")==actor.get("name") and not body.get("actor_name","").is_empty(),name+" body identifies its actual admitted actor")
                check(not view.rows.any(func(item):return item.row.kind=="part" and descendants.has(item.row.id)),name+" equipment details remain compact")
        view.filter=index.initialization.state.actors[hit.track.actor_uuid].name;view.rebuild_rows()
        check(view.rows.any(func(item):return item.row.id==hit.id),name+" actor-name filter finds defender hit reaction")
        var allowances=index.rows.filter(func(row):return row.has("movement_allowance"))
        var unique={}
        for row in allowances:
            var allowance:Dictionary=row.movement_allowance
            var key=str(allowance.operation_sequence)+":"+allowance.actor_uuid
            check(not unique.has(key),name+" resource annotation appears once per operation and actor")
            unique[key]=true
            var hud:Dictionary=index.initialization.state.hud_snapshot
            var previous:Dictionary=hud
            for sequence in range(1,allowance.operation_sequence+1):
                var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(index.directory.path_join("%016d.json"%sequence)))
                previous=hud
                if packet.get("hud")!=null:hud=packet.hud
            var prior_resource:Dictionary={};var next_resource:Dictionary={}
            for sheet in previous.sheets:
                if sheet.actor_uuid==allowance.actor_uuid:
                    for resource in sheet.resources:
                        if resource.key=="movement":prior_resource=resource
            for sheet in hud.sheets:
                if sheet.actor_uuid==allowance.actor_uuid:
                    for resource in sheet.resources:
                        if resource.key=="movement":next_resource=resource
            check(not prior_resource.is_empty() and not next_resource.is_empty(),name+" allowance annotations require both disclosed HUD values")
            if not prior_resource.is_empty() and not next_resource.is_empty():
                check(allowance.before_feet==prior_resource.current and allowance.after_feet==next_resource.current,name+" annotation exactly matches recorded operation boundary HUD values")
            check(row.event.actor_uuid==allowance.actor_uuid and row.parent.is_empty(),name+" root occurrence owns its actual actor resource annotation")
        if name=="dash-seed3":
            var dashes=allowances.filter(func(row):return row.event.behavior_id=="action.dash")
            check(dashes.size()==1 and dashes[0].movement_allowance.before_feet==30 and dashes[0].movement_allowance.after_feet==60,"Recorded Dash visibly adds its actual30ft allowance")
        var deposits=index.rows.filter(func(row):return row.kind=="residue_deposit")
        check(not deposits.is_empty(),name+" contains an actual authoritative blood deposit")
        for deposit in deposits:
            view.filter="";view.reveal(deposit.id)
            check(view.rows.any(func(item):return item.row.id==deposit.id),name+" actual deposit source lane is visible under its damage occurrence")
            check(view._height(deposit)>=view._height(hit),name+" deposit lane provides full source-thumbnail height")
            var key=view.thumbnails.request(deposit,lerpf(deposit.start_ms,deposit.end_ms,.5),0)
            check(not key.is_empty() and view.thumbnails.pending.any(func(job):return job.key==key and is_same(job.component,deposit.component)),name+" deposit thumbnail uses the exact compiled blood component")
        check(index.groups==before,name+" timeline inspection never changes causal groups or schedule")
        evidence.append({"case":name,"target_uuid":hit.track.actor_uuid,"target_name":hit.get("actor_name",""),"clip":hit.track.clip,"start_ms":hit.start_ms,"end_ms":hit.end_ms})
        view.free()
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Real server recordings, default and focused visible attack consequences, actor names and source times. No native framebuffer claim."}
    FileAccess.open("res://generated/studio_combat_tracks_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_COMBAT_TRACKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
