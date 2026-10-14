extends SceneTree
## Real SDK recordings and authored marker perturbations at the public compiler boundary.
## No invented game facts, native pixels, or renderer qualification.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Tracks=preload("res://presentation/tracks.gd")
const EventTrace=preload("res://presentation/event_trace.gd")
const Characters=preload("res://presentation/characters.gd")
const World=preload("res://presentation/world.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("COMBAT_TIMING_FAIL ",label)

func _cache(mode:String)->Dictionary:
    var cache={}
    if mode=="current":return cache
    var context:Dictionary=Authoring.load_data("catalog/damage_context.json",cache).duplicate(true)
    context.impactDelayMs=13;context.numberFrame=2;context.flashFrame=1
    context.bodyPlaybackSpeed=1.5
    cache["catalog/damage_context.json"]=context
    if mode=="ancestor":
        var recipes:Dictionary=Authoring.load_data("catalog/attack_recipes.json",cache).duplicate(true)
        for recipe in recipes.values():
            recipe.damage={"impactDelayMs":29,"floatingNumber":{"frame":3},"hitFlash":{"frame":2}}
        cache["catalog/attack_recipes.json"]=recipes
    return cache

func _inspect(group:Dictionary,lineage:Dictionary,mode:String,cache:Dictionary,label:String)->Dictionary:
    var counts={"damage":0,"lethal":0,"dying":0,"held_dead":0,"falls":0,"revival":0}
    var events={}
    for node in lineage.events:events[node.uuid]=node
    var rows={}
    for row in group.events:rows[row.event_uuid]=row
    for row in group.events:
        if not row.has("damage_timing"):continue
        counts.damage+=1
        var timing:Dictionary=row.damage_timing
        var node:Dictionary=events[row.event_uuid]
        var bodies:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==row.event_uuid)
        var no_body:bool=timing.lethal or timing.terminal
        check(bodies.is_empty() if no_body else bodies.size()==1,label+" hit body follows actual terminal outcome")
        check(not row.components.any(func(item):return item.kind=="body" and item.status=="missing"),label+" intentional no-hit body is not a false source gap")
        if no_body:
            counts.lethal+=1
            check(timing.hp==timing.start and timing.flash==timing.start and timing.number==timing.start,label+" lethal impact clocks stay at contact plus delay")
        elif not bodies.is_empty():
            var body:Dictionary=bodies[0]
            var clip:Dictionary=Authoring.load_data("catalog/rigs.json",cache)[body.rig].clips[body.clip]
            var rate:float=clip.frames*1000.0/clip.fps/body.duration_ms
            var number_frame:float=3 if mode=="ancestor" else (2 if mode=="defaults" else 0)
            var flash_frame:float=2 if mode=="ancestor" else (1 if mode=="defaults" else 0)
            check(is_equal_approx(timing.hp,body.start_ms+number_frame*1000.0/clip.fps/rate),label+" HP uses authored number frame and selected source rate")
            check(is_equal_approx(timing.flash,body.start_ms+flash_frame*1000.0/clip.fps/rate),label+" flash uses its independent source frame")
        # The real parent request is admitted at the weapon contact; no game
        # outcome or inferred universal pause is inserted for damage feedback.
        var parent:Dictionary={}
        for candidate in lineage.events:
            if candidate.lineage_uuid==node.parent_lineage:parent=candidate;break
        if not parent.is_empty() and rows.has(parent.uuid):
            var delay:float=29 if mode=="ancestor" else (13 if mode=="defaults" else 0)
            check(is_equal_approx(timing.start,rows[parent.uuid]._start_ms+delay),label+" impact delay starts at real request contact")
        check(is_equal_approx(row._commit_ms,timing.hp),label+" exact damage after-value publishes at HP marker")
        for component in group.components:
            if component.source_event_uuid!=row.event_uuid:continue
            if component.kind=="material_flash":check(is_equal_approx(component.start_ms,timing.flash),label+" material flash uses flash marker")
            if component.kind=="damage_number":check(is_equal_approx(component.start_ms,timing.number),label+" floating number uses HP marker")
        evidence.append({"case":label,"mode":mode,"event_uuid":row.event_uuid,"timing":timing})
    for node in lineage.events:
        if node.canceled or node.fact==null or node.fact.kind!="life":continue
        var fact:Dictionary=node.fact
        var bodies:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==node.uuid)
        check(bodies.size()==1,label+" actual life fact owns one body response")
        if bodies.is_empty():continue
        var body:Dictionary=bodies[0]
        var audio:Array=group.components.filter(func(component):return component.source_event_uuid==node.uuid and component.kind=="audio")
        if fact.previous_state=="alive" and fact.new_state=="dying":
            counts.dying+=1
            check(body.duration_ms>0,label+" initial Dying has an actual fall")
            var applied:Array=group.events.filter(func(row):return row.has("damage_timing") and row.target_uuid==fact.entity_uuid)
            check(applied.size()==1 and is_equal_approx(body.start_ms,applied[0].damage_timing.hp),label+" Dying starts at owning HP marker")
            check(audio.size()==1 and is_equal_approx(audio[0].start_ms,body.start_ms+body.duration_ms),label+" body fall cue follows actual fall source end")
            counts.falls+=audio.size()
        elif fact.previous_state in ["dying","stable"] and fact.new_state=="dead":
            counts.held_dead+=1
            check(is_zero_approx(body.duration_ms) and body.holding_pose and body.source_start_seconds==body.source_end_seconds,label+" later Dead retains terminal pose without a second fall")
            var sample:Dictionary=Tracks.samples([body],body.start_ms).get(body.actor_uuid,{})
            check(sample.get("source_seconds")==body.source_end_seconds,label+" exact Dead boundary samples the final source pose")
            check(audio.is_empty(),label+" later death has no repeated body-fall audio")
        elif fact.new_state=="alive":
            counts.revival+=1
            check(body.source_start_seconds>body.source_end_seconds,label+" actual revival retains authored reverse rise")
    return counts

func _recording(directory:String,role:String)->void:
    var journal=Journal.new()
    var opened=journal.open(directory,true,false)
    check(opened.ok,"Opens actual "+directory)
    if not opened.ok:return
    var regex=RegEx.new();regex.compile("^[0-9]{16}\\.json$")
    var names:Array=[]
    for name in DirAccess.get_files_at(directory):
        if regex.search(name)!=null:names.append(name)
    names.sort()
    var caches={"current":_cache("current"),"defaults":_cache("defaults"),"ancestor":_cache("ancestor")}
    var trace=EventTrace.create()
    var totals={"damage":0,"lethal":0,"dying":0,"held_dead":0,"falls":0,"revival":0}
    for sequence in names.size():
        var raw=FileAccess.get_file_as_bytes(directory.path_join(names[sequence]))
        var decoded=journal.protocol.decode("InitializationResponse" if sequence==0 else "PlayerOperation",raw)
        check(decoded.ok,"Strict actual packet "+str(sequence))
        if not decoded.ok:return
        var before:Dictionary=journal.state
        var admitted=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Canonical actual packet "+str(sequence))
        if not admitted.ok:return
        if sequence==0:continue
        var commits:Array=[]
        for mode in caches:
            var compiled=Compiler.compile_recorded(before,admitted.normalized,caches[mode],journal.state,admitted.transitions)
            check(compiled.ok,"Production compile "+role+" "+mode+" "+str(sequence))
            if not compiled.ok:return
            var display=before.duplicate(true)
            var actual_commits:Array=[]
            var life_events={}
            for lineage in admitted.normalized.lineages:
                for node in lineage.events:
                    if not node.canceled and node.fact!=null and node.fact.kind=="life":life_events[node.uuid]=node.fact
            for index in compiled.value.groups.size():
                var group:Dictionary=compiled.value.groups[index]
                if mode=="current":EventTrace.activate(trace,group.events,0)
                var last=-INF
                for commit in group.commits:
                    check(commit.at_ms>=last,"Original source commits remain monotonically ordered")
                    last=commit.at_ms
                    actual_commits.append({"event_uuid":commit.get("event_uuid"),"source_index":commit.source_index,"delta":commit.delta})
                    Compiler.apply_delta(display,commit.delta)
                    if life_events.has(commit.get("event_uuid")):
                        var life:Dictionary=life_events[commit.event_uuid]
                        var actor:Dictionary=display.actors[life.entity_uuid]
                        var rig:Dictionary=Authoring.load_data("catalog/rigs.json",caches[mode])[Authoring.rig_id(actor,caches[mode])]
                        var rest=Characters.rest_sample(actor,rig,caches[mode])
                        check(actor.life_state==life.new_state and rest.ok,"Exact life after-value owns the subsequent resting source")
                        if rest.ok:
                            if life.new_state in ["dying","stable","dead"]:
                                var clip:Dictionary=rig.clips[rest.value.clip]
                                check(rest.value.source_seconds==float(clip.frames)/clip.fps,"Dying/Dead resting source remains at terminal frame after track retirement")
                            else:check(rest.value.clip=="Idle" and rest.value.source_seconds==0.0,"Real recovery restores ordinary resting source after reverse rise")
                    if mode=="current":
                        if commit.has("event_uuid"):
                            var row:Dictionary=trace.rows.get("%s:%s"%[sequence,commit.event_uuid],{})
                            check(not row.get("committed",false),"No log/occurrence publishes before its own real commit")
                            var original_log:Variant=row.get("_log")
                            EventTrace.commit(trace,sequence,commit.event_uuid)
                            if original_log!=null:check(row.committed_log==original_log,"Committed hierarchical log retains exact original data")
                        EventTrace.append_logs(trace,commit.get("trace_logs",[]))
                if index<admitted.normalized.lineages.size():
                    var counts=_inspect(group,admitted.normalized.lineages[index],mode,caches[mode],role+" seq"+str(sequence))
                    if mode=="current":
                        for key in totals:totals[key]+=counts[key]
            check(display==journal.state and compiled.value.final_state==journal.state,"Timing never changes any final canonical after-value")
            if mode=="current":commits=actual_commits
            else:check(actual_commits==commits,"Authoring markers retain every original commit identity/order/value")
    check(totals.damage>0,role+" contains witnessed positive damage")
    if role=="dying":check(totals.dying==1 and totals.held_dead==1 and totals.falls==1,"Actual Dying→Dead has one fall and one terminal hold")
    if role=="lethal":check(totals.lethal>0,"Actual lethal opportunity attack exercises no-hit path")
    if role=="revival":check(totals.revival==1,"Actual death-save recovery exercises reverse rise")
    if role=="dying":
        var corpses:Array=journal.state.actors.values().filter(func(actor):return actor.life_state=="dead")
        check(corpses.size()==1,"Real completed recording retains one disclosed corpse")
        if not corpses.is_empty():
            var corpse:Dictionary=corpses[0]
            check(not journal.state.senses.entities.has(corpse.uuid),"Server removes final Dead actor from living perception contacts")
            check(World.visible_actor(corpse,journal.state),"Witnessed intact corpse stays rendered at the retained server position")
            var unseen_living=corpse.duplicate();unseen_living.life_state="alive"
            check(not World.visible_actor(unseen_living,journal.state),"Corpse retention does not reveal an unseen living actor")
            for replacement in [{"present":false},{"last_visual_position":null},{"spatial_disposition":"absent"},{"remains_disposition":"disintegrated"}]:
                var removed=corpse.duplicate();removed.merge(replacement,true)
                check(not World.visible_actor(removed,journal.state),"Explicit absence/disintegration still removes corpse: "+str(replacement))
    var log_rows:Array=EventTrace.logs(trace,2000).entries
    var positions={}
    var log_evidence:Array=[]
    var last_save=-1
    var final_dead=-1
    for index in log_rows.size():
        var entry:Dictionary=log_rows[index]
        positions[entry.id]=index
        if not entry.parent_id.is_empty():check(positions.has(entry.parent_id),"Displayed log parent precedes damage/life descendants")
        var event:Dictionary=trace.rows.get(entry.get("event_id",""),{})
        var log_kind:String=entry.entry.get("data",{}).get("kind","") if entry.entry.get("data")!=null else ""
        if event.get("kind") in ["attack","damage","life","death_save"] or log_kind=="death":
            log_evidence.append({"sequence":entry.sequence,"event_uuid":event.get("event_uuid"),"kind":event.get("kind"),"log_kind":log_kind,"parent":entry.parent_id,"entry":entry.entry})
        if log_kind=="death_save":last_save=index
        if log_kind=="death":final_dead=index
    if role=="dying":check(last_save>=0 and final_dead>last_save,"Real death-save logs precede the final Dead life log")
    evidence.append({"recording":directory,"displayed_combat_logs":log_evidence})
    evidence.append({"recording":directory,"role":role,"counts":totals})

func _initialize()->void:
    var paths={}
    for argument in OS.get_cmdline_user_args():
        for role in ["dying","lethal","hit","revival"]:
            if argument.begins_with("--"+role+"="):paths[role]=argument.trim_prefix("--"+role+"=")
    if not paths.has("dying") or not paths.has("lethal"):
        printerr("Requires --dying=<real complete journal> --lethal=<real complete journal>; optional --hit= / --revival=")
        quit(2);return
    for role in paths:_recording(paths[role],role)
    var report={"checks":checks,"failures":failures,"evidence":evidence,"arguments":Array(OS.get_cmdline_user_args()),"qualification":"SDK/compiler value and temporal sampling only; no native graphics/audio output claim."}
    FileAccess.open("res://generated/combat_timing_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("COMBAT_TIMING ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
