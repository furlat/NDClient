extends "res://tests/support_spell_event_checks.gd"
## Accepted direct casts use actual aim/creation placement before flight timing.
const Creation=preload("res://presentation/creation_inputs.gd")
const ROOT_PATH="res://tests/fixtures/schema16/event-families"
const RELEASES={"spell.freezing_sphere__launch_detonation":"high-level-22/freezing-sphere/launch_delivery",
    "spell.delayed_blast_fireball__concentration_end_detonation":"high-level-22/delayed-blast-fireball/native_place_from_hand",
    "spell.vitriolic_sphere__delayed_end_results":"high-level-22/vitriolic-sphere/native_delivery"}
func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for name in ["freezing_sphere","delayed_blast_fireball","vitriolic_sphere"]:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
        var cue:Resource=entries[id].effects[0]
        check(cue.constructor_input.kind=="payload_release" and cue.role=="flight" and cue.scope=="cast",id+" declares one actual accepted direct release")
        check(cue.unbound_constructor_inputs.is_empty() and cue.source_launch==.3 and cue.source_contact==.75 \
            and cue.charge_seconds==.3,id+" preserves the native preparation/flight/contact source clock")
    var built:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}}, {"spells":paths})
    var cache:Dictionary=source_cache(built,paths)
    for case_id in RELEASES:
        for seat in ["amber","blue"]:read_release(case_id,seat,cache)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both direct casts in both original seats: actual source/destination, canonical placement, accepted release source packets, exact release-hand optical mapping, flight/contact chronology and no second explosion casting gesture. Persistent payloads and native pixels remain separate."}
    FileAccess.open("res://.runtime/payload-release-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PAYLOAD_RELEASE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func read_release(case_id:String,seat:String,cache:Dictionary)->void:
    var label:String=case_id+"/"+seat;var directory:String=ROOT_PATH.path_join(case_id).path_join(seat)
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" unchanged original opens")
    var timeline:RefCounted=Timeline.new();var duration:float=0.0;var releases:int=0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file));var sequence:int=int(file.get_basename())
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,label+" decode "+str(sequence));if not decoded.ok:return
        var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence));if not folded.ok:return
        if sequence==0:timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var graphs:Dictionary={}
        for source in folded.normalized.lineages:
            var native:Dictionary=Occurrences.group(source);var graph:Dictionary=graph_for(native.events)
            graph.original_events=native.events
            for node in native.events:graphs[str(node.id)]=graph
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" actual production compiler "+str(sequence));if not compiled.ok:return
        for group in compiled.value.groups:
            duration+=group.duration_ms
            for component in group.components:
                if component.get("native_clip",{}).get("id")!=RELEASES[case_id]:continue
                releases+=1
                check(component.status=="available" and component.ground_target and component.to_position==[6,7],label+" one actual direct release has its real ground destination")
                if component.status!="available":continue
                var released:Dictionary=component.native_accepted_release
                check(released.event_uuid==str(component.source_event_uuid) and released.acting_holder_uuid==component.actor_uuid \
                    and released.observed and released.release_accepted,label+" actual committed cast owns acceptance without an item/grant UUID")
                var body:Array=group.actor_tracks.filter(func(track):return track.activity=="cast" and track.source_event_uuid==component.source_event_uuid)
                check(body.size()==1,label+" original direct cast retains one authored casting body")
                var launch:float=component.start_ms+float(component.native_cue.launch)*1000.0
                var contact:float=component.start_ms+float(component.native_cue.contact)*1000.0
                check(body.size()==1 and is_equal_approx(launch,float(body[0].contact_ms)) and contact>launch,label+" flight begins at actual authored release and takes positive time to the known destination")
                if component.native_constructor_evidence.destination_source=="placed_object":
                    var placement:Array=group.commits.filter(func(commit):return str(commit.get("event_uuid",""))==str(component.native_constructor_evidence.placement_occurrence))
                    check(placement.size()==1 and placement[0].at_ms>=contact-.001,label+" canonical bead placement never publishes before its actual delivery contact")
                    check(component.native_constructor_evidence.item_id=="spell_payload.delayed_fireball" \
                        and not str(component.native_constructor_evidence.item_uuid).is_empty(),label+" exact actual created bead establishes destination only")
                else:
                    var damage:Array=group.actor_tracks.filter(func(track):return track.activity=="hit")
                    check(not damage.is_empty() and damage.all(func(track):return track.start_ms>=contact-.001),label+" actual immediate results cannot precede projectile arrival")
                    check(group.actor_tracks.filter(func(track):return track.activity=="cast" and track.actor_uuid==component.actor_uuid).size()==1,label+" nested immediate explosion adds no invented second casting gesture")
                source_contract(component,label)
                negative_controls(component,graphs[str(component.source_event_uuid)],group.commits,label)
                evidence.append({"case":case_id,"seat":seat,"release_ms":launch,"contact_ms":contact,"evidence":component.native_constructor_evidence})
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        check(var_to_bytes(folded.normalized)==immutable and FileAccess.get_file_as_bytes(directory.path_join(file))==raw,label+" native originals remain unchanged")
    check(releases==1,label+" exactly one direct release, with no retained/secondary explosion duplicate")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" complete playback drains to unchanged canonical state")
func source_contract(component:Dictionary,label:String)->void:
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var immutable:PackedByteArray=var_to_bytes(phase.to_clip())
    var clip:Dictionary=Adapter.clip_with_inputs(phase,component.native_constructor_inputs)
    var input:Dictionary=clip.components[0].input
    check(input.caster_uuid==component.actor_uuid and input.acting_holder_uuid==component.actor_uuid \
        and input.cast_or_throw_accepted and not input.has("item_uuid") and not input.has("lifetime_uuid"),label+" finite constructor receives actual accepted caster and no manufactured held identity")
    var point:Vector3=Vector3(2.0,3.0,4.0);var hand:Vector3=Vector3(9.0,8.0,7.0)
    var projected:Dictionary=Creation.release_packet(component,{"from":point,"hand":hand})
    check(projected.ready and projected.packet.point==point and projected.packet.point!=hand,label+" optical projection uses exact authored release socket rather than moving preparation hand")
    var program:Node3D=load(clip.components[0].script).new();program.specification=input
    check(program.set_accepted_release(projected.packet) and program.authoritative_release and program.release_snapshot==point,label+" sealed source accepts actual release packet and retains its supplied hand point")
    var wrong:Dictionary=projected.packet.duplicate();wrong.acting_holder_uuid="foreign-holder"
    check(not program.set_accepted_release(wrong),label+" foreign holder cannot take over accepted release")
    var canceled:Dictionary=component.duplicate(true);canceled.native_accepted_release.release_accepted=false
    check(not Creation.release_packet(canceled,{"from":point,"hand":hand}).ready,label+" absent acceptance cannot become a release from geometry alone")
    program.free();check(var_to_bytes(phase.to_clip())==immutable,label+" Factory phase resource stays immutable")
func negative_controls(component:Dictionary,graph:Dictionary,commits:Array,label:String)->void:
    var owner:Dictionary=graph.original_events.filter(func(node):return str(node.id)==str(component.source_event_uuid))[0]
    var descriptor:Dictionary=component.native_cue.constructor_input
    var canceled:Dictionary=owner.duplicate(true);canceled.canceled=true
    check(not Creation.payload_release(canceled,descriptor,graph,commits).ready,label+" canceled original cast cannot release a payload")
    if descriptor.admission=="declared_aim":
        var no_aim:Dictionary=owner.duplicate(true);no_aim.fact.erase("aoe_position")
        check(not Creation.payload_release(no_aim,descriptor,graph,commits).ready,label+" missing ground aim cannot fall back to caster or nearest target")
    else:
        var absent:Array=commits.duplicate(true)
        for commit in absent:commit.delta.objects={}
        var missing:Dictionary=Creation.payload_release(owner,descriptor,graph,absent)
        check(not missing.ready and missing.applies and missing.reason=="payload_exact_placement_not_disclosed",label+" a placement fact without its actual canonical created object cannot borrow review coordinates")
