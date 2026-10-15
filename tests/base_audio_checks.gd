extends SceneTree
## Actual recorded base mechanics must bind sounds to their own authored markers.
const Authoring=preload("res://presentation/authoring.gd")
const AudioCues=preload("res://presentation/audio_cues.gd")
const Recording=preload("res://studio/recording.gd")
const Library=preload("res://studio/case_library.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
var heard={}
var authoring_gaps=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("BASE_AUDIO_FAIL ",label)

func inspect(directory:String)->void:
    var index=Recording.read(directory)
    check(index.ok,"Actual journal compiles: "+directory)
    if not index.ok:return
    var facts={}
    for name in DirAccess.get_files_at(directory):
        if not name.ends_with(".json"):continue
        var packet=JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(name)))
        if not packet is Dictionary:continue
        for lineage in packet.get("lineages",[]):
            for node in lineage.events:facts[node.uuid]=node.get("fact")
    var count=0
    for item in index.groups:
        var group:Dictionary=item.group
        var ids={}
        for cue in group.components:
            if cue.kind!="audio":continue
            count+=1
            if cue.status=="available":
                heard[cue.cue_id]=true
                check(cue.cue_id not in ["spell_release","condition_loop"] and not cue.clip.contains("/magical-") and not cue.clip.contains("/energy-loop/"),"Actual recordings emit base physical sounds only: "+cue.id)
            check(not ids.has(cue.id),"Sound occurrence is unique: "+cue.id);ids[cue.id]=true
            check(facts.get(cue.source_event_uuid)!=null,"Sound has an actually disclosed server fact: "+cue.id)
            if cue.status=="missing" and cue.reason in ["source_contact_markers_not_authored","invalid_contact_end_boundary"]:
                check(cue.duration_ms==0 and cue.has("timing_source"),"Unaudited contact remains an inspectable gap: "+cue.id)
                authoring_gaps.append({"recording":directory,"source":cue.timing_source})
            elif cue.status=="missing" and cue.reason=="spell_audio_deferred":
                check(not cue.assignment_enabled and cue.duration_ms==0 and not cue.has("clip"),"Deferred spell assignment has no executable stream: "+cue.id)
            elif cue.status=="missing" and cue.cue_id=="torch_extinguish":
                check(cue.duration_ms==0 and not cue.has("clip") and cue.reason==Authoring.load_data("audio/cues.json",{}).missing_cues.torch_extinguish,"Unselected extinguishing source remains a real owner gap")
                authoring_gaps.append({"recording":directory,"source":cue.assignment_source})
            else:check(cue.status=="available" and FileAccess.file_exists(cue.clip),"Sound source is present: "+cue.id)
            check(cue.has("timing_source"),"Timing authoring is inspectable: "+cue.id)
            check(cue.has("assignment_source"),"Selected binding is inspectable: "+cue.id)
        for track in group.actor_tracks:
            var fact:Dictionary=facts.get(track.source_event_uuid,{})
            var own=group.components.filter(func(c):return c.kind=="audio" and c.source_event_uuid==track.source_event_uuid)
            if fact.get("kind")=="equipment":
                var handling=own.filter(func(c):return c.cue_id=="equipment_handle")
                check(handling.size()==1 and handling[0].status=="available" and is_equal_approx(handling[0].contact_ms,track.commit_ms),"Equipment handling follows the authored visual/state commit once")
            if fact.get("kind")=="attack" and fact.attack_source_kind=="unarmed":
                check(own.size()==1 and own[0].cue_id=="unarmed_swing" and own[0].attachment=="body" and is_equal_approx(own[0].contact_ms,track.contact_ms),"Explicit unarmed attack has a physical body release at its authored contact")
            if fact.get("kind")=="action" and fact.behavior_id=="action.item.potion_haste.drink":
                check(own.size()==1 and own[0].cue_id=="potion_drink" and is_equal_approx(own[0].contact_ms,track.contact_ms),"Potion swallow follows the physical body effect once")
            if fact.get("kind")=="attack" and fact.get("source_item_id") in ["weapon.longbow","weapon.shortbow"]:
                var release=own.filter(func(c):return c.cue_id=="projectile_release")
                check(release.size()==1,"Actual bow attack owns one bow release")
                if release.size()==1:
                    check(is_equal_approx(release[0].start_ms,track.contact_ms),"Bow sound follows authored release, not windup or target impact")
            if fact.get("kind")=="step" and track.get("motion",false) and (fact.movement_mode=="walking" or track.trajectory=="connector_transfer"):
                var marker_set=Authoring.load_data("audio/contacts.json",{}).rigs.get(track.rig,{}).get(track.clip,{}).get(track.trajectory,{})
                var steps=own.filter(func(c):return c.get("body_track_id")==track.trace_track_id)
                if marker_set.is_empty():
                    check(steps.size()==1 and steps[0].status=="missing","Unreviewed rig/trajectory has an explicit audio authoring gap")
                    continue
                var clip=Authoring.clip(track.presentation_actor,track.clip,{})
                var expected=0
                for marker in marker_set.markers:
                    expected+=AudioCues.source_frame_times(track,marker.frame,clip.fps,int(clip.frames),marker.direction).size() if AudioCues.contact_marker_error(marker,clip,track.loop).is_empty() else 1
                check(steps.size()==expected,"Each actual body frame crossing has exactly one contact cue")
                for cue in steps:
                    if cue.status=="missing":continue
                    check(is_equal_approx(cue.contact_ms-cue.start_ms,cue.source_sync_s*1000),"Source transient aligns with authored body contact")
                    check(cue.contact_ms>=track.start_ms and cue.contact_ms<=track.start_ms+track.duration_ms+.001,"Contact belongs to its actual body segment")
                    if cue.cue_id=="landing":
                        check(track.motion_fraction_to>=1 and is_equal_approx(cue.contact_ms,track.start_ms+track.duration_ms),"Landing transient meets completed actual world touchdown")
                    elif cue.cue_id=="jump_takeoff":
                        check(track.motion_fraction_from<=0 and is_equal_approx(cue.contact_ms,track.start_ms),"Takeoff belongs only to first jump segment")
        for id in facts:
            var fact:Variant=facts[id]
            if fact==null:continue
            var commits=group.commits.filter(func(c):return c.get("event_uuid")==id)
            if commits.is_empty():continue
            var owned=group.components.filter(func(c):return c.source_event_uuid==id)
            if fact.kind=="life":
                var falls=owned.filter(func(c):return c.kind=="audio" and c.cue_id=="body_fall")
                check(falls.size()==int(fact.previous_state=="alive" and fact.new_state in ["dying","dead"]),"Falling sound is not repeated when an already fallen character dies")
            elif fact.kind=="death_save":
                check(owned.any(func(c):return c.kind=="feedback_text" and c.source.begins_with("catalog/death_save_context.json:")),"Every actual death save has its authored feedback")
            elif fact.kind=="object_destroyed" and fact.item_id=="environment.window.fantasy_g8.insert":
                var breaking=owned.filter(func(c):return c.kind=="audio" and c.cue_id=="wood_break")
                check(breaking.size()==1 and Vector2(breaking[0].position[0],breaking[0].position[1])==Vector2(fact.placement.position[0],fact.placement.position[1]),"Window break belongs to the actual destroyed insert and placement")
    evidence.append({"recording":directory,"audio_components":count})

func run()->void:
    var paths={}
    for item in Library.read():
        for audience in item.perspectives:paths[audience.journal]=true
    paths["res://.runtime/studio-cases/dying-seed5/amber/journal"]=true
    var explicit=false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):
            if not explicit:paths.clear();explicit=true
            paths[arg.trim_prefix("--recording=")]=true
    for path in paths:inspect(path)
    for cue in ["footstep","landing","jump_takeoff","weapon_swing","weapon_swing_heavy","projectile_release","physical_impact","stance_transition","body_fall","stand_up","wood_break","action_surge","hide_transition","equipment_handle","unarmed_swing","potion_drink","torch_ignite"]:
        if explicit:continue
        check(heard.has(cue),"Actual recorded suite exercises cue "+cue)
    var report={"checks":checks,"failures":failures,"recordings":evidence,"cues":heard.keys(),"authoring_gaps":authoring_gaps,"scope":"Actual shared-compiler cue assignments, disclosed owners, authored markers and source availability; native audible output is separately checked."}
    FileAccess.open("res://generated/base_audio_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BASE_AUDIO ",JSON.stringify({"checks":checks,"failures":failures,"recordings":evidence.size(),"cues":heard.size()}))
    quit(0 if failures.is_empty() else 1)
