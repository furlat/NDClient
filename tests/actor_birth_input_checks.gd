extends SceneTree
## Original independent-seat summon admissions through the ordinary compiler.
## These are factual/constructor/clock checks; no native pixels or acceptance.
const Birth=preload("res://presentation/actor_birth_inputs.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Delivery=preload("res://presentation/spell_delivery.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const CASES={
    "conjure_elemental":{"fixture":"air-elemental","form":"air_elemental","actor":"615e48e0-09ab-4063-8157-bd1be68e2981","birth":[48,47]},
    "planar_ally":{"fixture":"deva","form":"deva","actor":"ec65bbc6-f89d-4c39-ae06-82aa3ae18904","birth":[48,47]},
    "summon_dragon":{"fixture":"draconic-spirit","form":"draconic_spirit","actor":"92a47894-dfc0-4cd2-b482-e0c88ffb3853","birth":[55,54]}}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ACTOR_BIRTH_INPUT_FAIL "+label)
func source_cache(built:Dictionary,paths:Dictionary)->Dictionary:
    var cache:Dictionary={}
    var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate()
    index.spells=admitted.index.spells.duplicate()
    var loaded:Dictionary=admitted.loaded.duplicate()
    for id in paths:index.spells[id]=paths[id];loaded[id]=built.native.records[id]
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for name in CASES:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
        var cue:Resource=entries[id].effects[0]
        check(cue.constructor_input=={"kind":"actor_birth","component_path":["summon_manifestation"],"input_field":"","creature_id":"creature.spell."+CASES[name].form},id+" exact authored form and native component")
        check(cue.scope=="cast" and cue.at=="cast" and cue.delay==0.0,id+" single observation-owned phase, not one per spell application")
        check(cue.extra.live_endpoints==[{"actor":"target","socket":"ground"}] and not cue.extra.has("review_stationary_ground"),id+" actual born actor owns the one birth endpoint; no review ground/terminal")
        check(is_equal_approx(cue.source_end,2.1291666666666667) and entries[id].status=="partial",id+" full original finite birth, no whole-family acceptance claim")
    var built:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":paths})
    var count:int=0
    for name in CASES:
        for seat in ["amber","blue"]:count+=read_seat(name,seat,entries["spell."+name],built,paths)
    check(count==6,"All three actual births qualify separately in both original seats")
    check(not Birth.packet({}, {"actors":{}},true).ready,"No component birth binding cannot admit a source")
    print("ACTOR_BIRTH_INPUTS ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual actor-birth facts, private constructor and event-time publication; terminal, native output and user approval remain unqualified."}))
    quit(0 if failures.is_empty() else 1)

func read_seat(name:String,seat:String,entry:Resource,built:Dictionary,paths:Dictionary)->int:
    var label:String=name+"/"+seat;var id:String="spell."+name
    var directory:String="res://tests/fixtures/schema16/scenarios/actor-birth-"+CASES[name].fixture+"/"+seat
    var journal:RefCounted=Journal.new()
    check(journal.open(directory,true,false).ok,label+" opens unchanged schema16 prefix")
    var cache:Dictionary=source_cache(built,paths)
    var timeline:RefCounted=Timeline.new();var duration:float=0.0;var count:int=0
    var initial:Dictionary={};var groups:Array=[]
    for sequence in 9:
        var filename:String="%016d.json"%sequence
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,label+" decode "+str(sequence))
        if not decoded.ok:return count
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,label+" fold "+str(sequence))
        if not folded.ok:return count
        if sequence==0:
            initial=journal.state
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var immutable:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" ordinary compile "+str(sequence))
        if not compiled.ok:return count
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        groups.append_array(compiled.value.groups)
        for group in compiled.value.groups:duration+=float(group.duration_ms)
        for index in folded.normalized.lineages.size():
            var lineage:Dictionary=Occurrences.group(folded.normalized.lineages[index])
            var owner:Dictionary={}
            var graph:Dictionary={"nodes":{},"body_records":lineage.get("bodies",[]),"contacts":{},"positions":{}}
            for node in lineage.events:
                graph.nodes[node.lineage_id]=node
                if node.get("fact")!=null and node.fact.get("behavior_id")==id:owner=node
            if owner.is_empty():continue
            var group:Dictionary=compiled.value.groups[index]
            # Contacts use the independently folded canonical ground, not the
            # projector or a review placement. Both recorded maps are flat.
            for actor in journal.state.actors.values():
                graph.positions[actor.uuid]=actor.last_visual_position
                if actor.last_visual_position==null:continue
                var tile:Dictionary=journal.state.tiles["%d,%d"%actor.last_visual_position]
                graph.contacts[actor.uuid]={"from_elevation_feet":float(tile.elevation_steps)*5.0}
            var descriptor:Dictionary=entry.effects[0].constructor_input
            var observed:Array=Birth.observed(owner,descriptor,graph,group.commits)
            check(owner.fact.target_entity_uuid==null,label+" original spell does not pretend the future actor is its target")
            check(observed.size()==1,label+" exact source ancestry and admitted body prove one birth")
            if observed.size()!=1:continue
            count+=1
            var actual:Dictionary=observed[0]
            var expected:String=CASES[name].actor
            var expected_birth:int=CASES[name].birth[0 if seat=="amber" else 1]
            check(actual.target_uuid==expected and actual.position==[6,7] and actual.elevation_feet==0.0,label+" independent original identity/position/elevation")
            check(actual.binding.birth_occurrence==str(expected_birth),label+" original public birth identity remains local to this seat")
            check((actual.binding.body_occurrence==actual.binding.birth_occurrence)==(seat=="amber"),label+" opposing-seat body disclosure is not confused with its earlier birth identity")
            var components:Array=group.components.filter(func(row):return row.get("native_actor_birth",{}).get("actor_uuid")==expected)
            check(components.size()==1,label+" exactly one manifestation, no body/cast replay")
            if components.size()!=1:continue
            var component:Dictionary=components[0]
            var admission:Dictionary=group.commits.filter(func(commit):return str(commit.get("event_uuid",""))==str(actual.node.id))[0]
            check(component.status=="available" and component.start_ms==admission.at_ms,label+" actual monotonic spatial commit owns source start")
            check(component.source_event_uuid==actual.node.id and component.source_lineage==actual.node.lineage_id,label+" exact admission occurrence and lineage retained")
            check(component.native_cast_id==owner.id and component.actor_uuid==owner.fact.source_entity_uuid and component.target_uuid==expected,label+" rule caster retained separately from actual receiving actor")
            check(component.to_position==[6,7] and component.to_elevation_feet==0.0 and not component.ground_target,label+" actual actor ground endpoint has no review origin")
            check(is_equal_approx(component.duration_ms,entry.effects[0].source_end*1000.0),label+" original complete birth source duration retained")
            var caster_tracks:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==owner.id and track.get("activity")=="cast")
            check(caster_tracks.size()==1 and caster_tracks[0].actor_uuid==owner.fact.source_entity_uuid,label+" original caster body gesture occurs once")
            constructor(component,actual,label)
            packets(component,admission.delta,journal.state,label)
            negative(owner,descriptor,graph,group.commits,actual,label)
            var selected:Dictionary=built.native.records[id].selection
            check(not Delivery.endpoints(owner.fact,graph,journal.state,selected).is_empty(),label+" root can compile before the real future target is admitted")
            var recipient:Dictionary=selected.duplicate(true)
            recipient.staging.cues[0].constructor_input={}
            check(Delivery.endpoints(owner.fact,graph,journal.state,recipient).is_empty(),label+" ordinary recipient effects still require a disclosed target")
            evidence.append({"spell":id,"seat":seat,"source":owner.id,"birth":actual.binding.birth_occurrence,"body":actual.binding.body_occurrence,
                "admission":actual.node.id,"start_ms":component.start_ms,"actor":expected,"position":actual.position,"terminal":"not_observed"})
        check(var_to_bytes(folded.normalized)==immutable,label+" compiler never modifies original public journal rows")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" exact independent canonical prefix drains in original order without holds")
    # Ordinary replay restores the original independent reducer prefix then
    # advances the same compiled groups; no delayed pose or terminal is made.
    var replay:RefCounted=Timeline.new()
    replay.accept({"kind":"initialization","state":initial,"sequence":0})
    replay.accept({"kind":"operation","groups":groups})
    check(not replay.state.actors.has(CASES[name].actor),label+" rewind restores the real pre-birth prefix")
    replay.advance(duration+1000.0)
    check(Compare.difference(replay.state,journal.state).is_empty(),label+" replay seeks through the exact prefix without a fabricated terminal")
    return count

func constructor(component:Dictionary,actual:Dictionary,label:String)->void:
    var phase:Resource=load(Effects.choice(component.native_clip).approaches[0].source_phase)
    var original:Dictionary=phase.to_clip();var sealed:PackedByteArray=var_to_bytes(original)
    var private:Dictionary=Constructed.clip_with_inputs(phase,component.native_constructor_inputs)
    var input:Dictionary=private.components[0].input
    var original_input:Dictionary=original.components[0].input
    check(input.owner_uuid==actual.target_uuid and input.birth_event_uuid==actual.binding.birth_occurrence,label+" exact actual identity replaces review constructor UUIDs")
    check(input.initial_state=={"owner_uuid":actual.target_uuid,"birth_admitted":false,"observed":false,"suppressed":false} and input.review_states.is_empty(),label+" constructor starts optically inactive and cannot replay review terminal states")
    check(input.entries==original_input.entries and input.form==original_input.form,label+" original native art/material/composition and birth timing unchanged")
    var birth:Dictionary=input.entries.filter(func(row):return row.kind=="birth")[0]
    check(is_equal_approx(birth.begin_seconds+birth.seconds,component.native_cue.source_end),label+" source window ends after every original birth frame")
    check(input.entries.any(func(row):return row.kind=="terminal") and not input.initial_state.has("terminal_event_uuid"),label+" original terminal art retained without fabricated terminal admission")
    check(var_to_bytes(phase.to_clip())==sealed,label+" shared sealed phase remains immutable")

func packets(component:Dictionary,cut:Dictionary,state:Dictionary,label:String)->void:
    var identity:String=component.target_uuid
    var original:PackedByteArray=var_to_bytes(component)
    var before:Dictionary={"actors":{}}
    var absent:Dictionary=Birth.packet(component,before,true)
    check(absent.ready and not absent.value.observed and not absent.value.birth_admitted,label+" future prepared source is not displayed before actual publication")
    var admitted:Dictionary=Birth.packet(component,cut,true)
    check(admitted.ready and admitted.value=={"owner_uuid":identity,"birth_admitted":true,"observed":true,"suppressed":false},label+" exact published actor and displayed membership admit birth")
    var hidden:Dictionary=Birth.packet(component,state,false)
    check(hidden.ready and hidden.value.birth_admitted and not hidden.value.observed,label+" hidden renderer membership cannot emit or invent removal")
    var other:Dictionary={"actors":{component.actor_uuid:state.actors[component.actor_uuid]}}
    check(not Birth.packet(component,other,true).value.observed,label+" caster visibility cannot admit an absent summoned actor")
    check(not admitted.value.has("terminal_event_uuid") and not hidden.value.has("terminal_event_uuid") and not absent.value.has("terminal_event_uuid"),label+" present/hidden/withdrawn are never terminal evidence")
    check(var_to_bytes(component)==original,label+" optical permission leaves immutable occurrence operands unchanged")

func negative(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array,actual:Dictionary,label:String)->void:
    # Explicit cloned compiler controls, never presented as server recordings.
    var canceled:Dictionary=owner.duplicate();canceled.canceled=true
    check(Birth.observed(canceled,descriptor,graph,commits).is_empty(),label+" canceled cast cannot borrow an actual admission")
    var application:Dictionary=owner.duplicate();application.resolution_record={"application_id":"compiler-control"}
    check(Birth.observed(application,descriptor,graph,commits).is_empty(),label+" application cannot replay the root birth")
    var unrelated:Dictionary=owner.duplicate();unrelated.lineage_id="unrelated-root-control"
    check(Birth.observed(unrelated,descriptor,graph,commits).is_empty(),label+" another native root cannot acquire this birth")
    var wrong:Dictionary=descriptor.duplicate();wrong.creature_id="creature.spell.not_this_form"
    check(Birth.observed(owner,wrong,graph,commits).is_empty(),label+" incompatible actual creature cannot select this source")
    var missing:Dictionary=graph.duplicate();missing.body_records=[]
    check(Birth.observed(owner,descriptor,missing,commits).is_empty(),label+" spatial entry alone cannot fabricate a known actor form")
    check(Birth.observed(owner,descriptor,graph,[]).is_empty(),label+" retained or future state cannot replace the actual admission cut")
    var changed:Dictionary=graph.duplicate(true)
    changed.nodes[actual.node.lineage_id].fact.creation=null
    check(Birth.observed(owner,descriptor,changed,commits).is_empty(),label+" movement/entity entry without explicit birth is not a creation")
    changed=graph.duplicate(true);changed.nodes[actual.node.lineage_id].fact.position=[11,11]
    check(Birth.observed(owner,descriptor,changed,commits).is_empty(),label+" mismatching admitted placement stays unbound")
