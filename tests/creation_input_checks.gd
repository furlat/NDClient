extends SceneTree
## Real level10 native item/container admissions; no invented reward props,
## source outcome, cross-seat identity or full-game/visual qualification.
const Creation=preload("res://presentation/creation_inputs.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Effects=preload("res://presentation/effect_package.gd")
const Constructed=preload("res://presentation/native_constructed_occurrence.gd")
const NativeInputs=preload("res://presentation/native_inputs.gd")
const Placement=preload("res://placement.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const PREFIX="action.class.cleric.divine_intervention."
const CASES={"arm_thy_servant":{"argument":"arm","path":"res://tests/fixtures/schema16/scenarios/divine-arm/party"},
    "golden_generosity":{"argument":"golden","path":"res://tests/fixtures/schema16/scenarios/divine-generosity/party"}}
class EventReceiver extends Node:
    var event:Dictionary={}
    func set_event_input(value:Dictionary)->void:event=value
class World extends Node:
    var timeline=Timeline.new()
    var visual_actors:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CREATION_INPUT_FAIL "+label)

func run()->void:
    var entries:Dictionary={};var paths:Dictionary={}
    for suffix in CASES:
        var identity:String=PREFIX+suffix
        var path:String="res://authoring/abilities/actions/"+identity+".tres"
        var source:Resource=load(path)
        check(source!=null and source.effects.size()==2,identity+" has invocation and actual admission cues")
        if source==null:finish();return
        entries[identity]=source;paths[identity]=path
        var cue:Resource=source.effects[1]
        check(cue.constructor_input.kind=="creation_admission" and cue.constructor_input.geometry_actor=="caster" and cue.unbound_constructor_inputs.is_empty(),identity+" uses exact authored admission and actual caster geometry")
        var clip:Dictionary=Effects.clip(cue.clip)
        check("created_item_binding" not in clip.inputs and "weapon_binding" not in clip.inputs,identity+" receiving seam needs no surrogate native weapon or chest")
    var built:Dictionary=Build.documents({"actions":entries},{"actions":paths})
    var qualified:int=0
    for suffix in CASES:
        var directory:String=CASES[suffix].path
        for argument in OS.get_cmdline_user_args():
            if argument.begins_with("--"+CASES[suffix].argument+"="):directory=argument.get_slice("=",1)
        check(DirAccess.dir_exists_absolute(directory),suffix+" original party journal exists")
        if DirAccess.dir_exists_absolute(directory):qualified+=read_case(directory,PREFIX+suffix,entries[PREFIX+suffix],built)
    check(qualified==2,"Both authentic native admissions are independently qualified")
    finish()

func read_case(directory:String,identity:String,source:Resource,built:Dictionary)->int:
    var journal:RefCounted=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,identity+" opens current schema16")
    if not opened.ok:return 0
    var cache:Dictionary={}
    for field in ["catalog/body_action_bindings.json","catalog/body_action_recipes.json"]:
        var current:Dictionary=Authoring.load_data(field,cache).duplicate()
        current.merge(built.docs[field],true);cache[field]=current
    var timeline:RefCounted=Timeline.new();var duration:float=0.0
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    var count:int=0
    for filename in files:
        if not filename.ends_with(".json") or filename.get_basename().length()!=16 or not filename.get_basename().is_valid_int():continue
        var sequence:int=int(filename.get_basename())
        # Unchanged initialization through the committed real creation action.
        # The Arm run's later missing Incense recording is not claimed green.
        if sequence>8:break
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(filename))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,identity+" decode "+str(sequence))
        if not decoded.ok:return 0
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(folded.ok,identity+" reduce "+str(sequence))
        if not folded.ok:return 0
        if sequence==0:
            timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
        var unchanged:PackedByteArray=var_to_bytes(folded.normalized)
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,identity+" compile "+str(sequence))
        if not compiled.ok:return 0
        timeline.accept({"kind":"operation","groups":compiled.value.groups})
        for group in compiled.value.groups:duration+=float(group.duration_ms)
        for original in folded.normalized.lineages:
            var lineage:Dictionary=Occurrences.group(original)
            var owner:Dictionary={}
            var graph={"nodes":{},"actor_inputs":{}}
            for node in lineage.events:
                graph.nodes[node.lineage_id]=node
                if node.get("fact")!=null and node.fact.get("behavior_id")==identity:owner=node
            if owner.is_empty():continue
            var compiled_group:Dictionary=compiled.value.groups.filter(func(group):return group.id==lineage.id)[0]
            # Independently use the SDK's original per-row immutable captures.
            var captures:Array=folded.transitions.lineages[compiled.value.groups.find(compiled_group)].events
            for capture in captures:graph.actor_inputs[str(capture.event_uuid)]=capture.actor_inputs
            var descriptor:Dictionary=source.effects[1].constructor_input
            var observed:Array=Creation.observed(owner,descriptor,graph,lineage.events,compiled_group.commits)
            check(observed.size()==1,identity+" exact native descendants and occurrence cut prove one admission")
            if observed.size()!=1:continue
            var actual:Dictionary=observed[0]
            var rows:Array=compiled_group.components.filter(func(component):return component.has("native_creation"))
            check(rows.size()==1,identity+" compiler creates exactly one receiving accent")
            if rows.size()!=1:continue
            var row:Dictionary=rows[0]
            check(row.status=="available" and row.native_inputs.event_input==actual.event,identity+" receiving packet contains the independently projected actual admission")
            check(row.source_event_uuid==actual.node.id and row.source_lineage==actual.node.lineage_id \
                and row.native_input_evidence.source_occurrence==owner.id and row.native_input_evidence.native_parent_occurrence==actual.node.parent_event,identity+" result occurrence, lineage and actual action parent stay separate")
            check(row.actor_uuid==owner.fact.source_entity_uuid and row.target_uuid==owner.fact.source_entity_uuid \
                and row.native_inputs.event_input.item_uuid!=row.target_uuid,identity+" created object is never a character or geometry owner")
            check(row.native_inputs.event_input.keys().all(func(field):return field not in ["actual_healing","actual_damage","removed_condition_uuids","damage_component_uuid"]),identity+" sample healing/damage/cure outcomes are absent")
            constructor(row,actual,identity)
            if descriptor.admission=="inventory":inventory(row,actual,journal.state,identity)
            else:placed(row,actual,compiled_group,identity)
            negative(owner,descriptor,graph,lineage.events,compiled_group.commits,identity)
            count+=1
        check(var_to_bytes(folded.normalized)==unchanged,identity+" compiler does not rewrite the original native recording")
    timeline.advance(duration+1000.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),identity+" preparation drains to the exact independently folded prefix without presentation holds")
    return count

func constructor(row:Dictionary,actual:Dictionary,identity:String)->void:
    var phase:Resource=load(Effects.choice(row.native_clip).approaches[0].source_phase)
    var sealed:Dictionary=phase.to_clip()
    var private_clip:Dictionary=Constructed.clip_with_inputs(phase,row.native_constructor_inputs)
    var values:Dictionary=private_clip.components[0].input
    check(values.event.is_empty() and values.lease.is_empty() and not values.plan_only,identity+" constructor clears sample successful outcomes before make")
    check(values.event_uuid==actual.node.id and values.source_entity_uuid==row.actor_uuid \
        and values.recipient_entity_uuid==row.actor_uuid and values.geometry_actor==row.actor_uuid,identity+" constructor remaps native aliases and exact character receiving frame")
    check(values.actor_roles=={"caster":row.actor_uuid,"target":row.actor_uuid} and values.native_behavior_id==identity,identity+" authored roles are explicit presentation projections of the real invoking actor")
    check(phase.to_clip()==sealed,identity+" delivered material/source Resource remains immutable")

func inventory(row:Dictionary,actual:Dictionary,state:Dictionary,identity:String)->void:
    var holder:String=actual.location.holder_uuid
    check(row.native_creation.holder_uuid==holder and row.native_creation.item_uuid in state.actors[holder].controlled_items,identity+" item UUID belongs to the actual current holder")
    check(not actual.event.has("creation_position_cells") and row.native_creation.presentation_position_socket=="cast_hand",identity+" inventory admission does not assert a nonexistent server world item position")
    # Explicit renderer-position fixture tests only packet conversion; it is
    # not a claim that a native pose or its framebuffer has been qualified.
    var point:=Vector3(10.25,1.3,9.8)
    var endpoints:Array=[{"actor_uuid":holder,"socket":"cast_hand","point":point}]
    var packet:Dictionary=Creation.event_packet(row,state,endpoints)
    check(packet.ready and packet.event.creation_position_cells==[point.x,point.y,point.z],identity+" authored renderer socket supplies the hand position without server-position fiction")
    check(not row.native_inputs.event_input.has("creation_position_cells") and row.native_input_evidence.position_source=="renderer_socket:cast_hand",identity+" runtime projection leaves the immutable event operands and position provenance intact")
    check(Creation.event_packet(row,state,[]).reason=="creation_holder_socket_not_bound",identity+" absent socket stays missing")
    endpoints[0].actor_uuid="not-the-holder"
    check(not Creation.event_packet(row,state,endpoints).ready,identity+" another actor's hand cannot position the actual item")
    var after:Dictionary=state.duplicate();after.actors=state.actors.duplicate();after.actors[holder]=state.actors[holder].duplicate();after.actors[holder].controlled_items=[]
    check(Creation.event_packet(row,after,[]).reason=="creation_item_no_longer_held",identity+" a cached ItemRecord does not retain current holdings")

func placed(row:Dictionary,actual:Dictionary,group:Dictionary,identity:String)->void:
    var cut:Dictionary=group.commits.filter(func(commit):return str(commit.get("event_uuid"))==actual.node.id)[0].delta
    var placement:Dictionary=cut.objects[actual.event.item_uuid].placement
    var expected:Array=[placement.position[0],float(placement.base_height_steps)*Placement.HEIGHT_UNIT,placement.position[1]]
    check(actual.event.creation_position_cells==expected and actual.location.position==actual.node.fact.position,identity+" actual object placement supplies the event location and engine-to-render base elevation")
    check(placement.top_height_steps!=placement.base_height_steps and actual.event.creation_position_cells[1]!=float(placement.top_height_steps)*Placement.HEIGHT_UNIT,identity+" chest top height is not its base position")
    check(row.native_creation.kind=="placed_object" and row.native_input_evidence.position_source=="canonical_object_placement",identity+" placed admission is explicitly different from an inventory/hand location")
    # Production generic event-input routing, no source construction/drawing.
    var receiver:EventReceiver=EventReceiver.new();var world:World=World.new()
    var inputs:RefCounted=NativeInputs.new()
    var clip:Dictionary=row.native_clip.duplicate();clip.inputs=["event_input"]
    var handle={"clip":clip,"occurrence":receiver,"root":receiver}
    var result:Dictionary=inputs.sync(world,handle,row,{})
    check(result.unavailable.is_empty() and receiver.event==actual.event,identity+" production event-input adapter forwards the actual placed-container packet")
    inputs.clear();world.free();receiver.free()

func negative(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,events:Array,commits:Array,identity:String)->void:
    var original:PackedByteArray=var_to_bytes([graph,events,commits])
    var wrong:Dictionary=descriptor.duplicate();wrong.item_id="not-this-item"
    check(Creation.observed(owner,wrong,graph,events,commits).is_empty(),identity+" other items cannot stand in for the declared ordinary item")
    check(Creation.observed(owner,descriptor,graph,events,[]).is_empty(),identity+" no independently captured after-value means no admitted reward")
    var foreign:Dictionary=owner.duplicate();foreign.lineage_id="not-the-owner"
    check(Creation.observed(foreign,descriptor,graph,events,commits).is_empty(),identity+" unrelated native lineages do not activate this action's effect")
    var canceled:Array=events.duplicate(true)
    for node in canceled:
        if node.fact!=null and node.fact.kind in ["actor_change","spatial"]:node.canceled=true
    check(Creation.observed(owner,descriptor,graph,canceled,commits).is_empty(),identity+" canceled admissions do not produce successful creation art")
    if descriptor.admission=="inventory":
        var previous:Dictionary=graph.duplicate(true)
        for node in events:
            if node.fact==null or node.fact.kind!="actor_change":continue
            for actor in node.fact.get("actors",[]):
                for row in actor.rows:
                    if row.get("field")=="inventory" and row.held:
                        previous.actor_inputs[node.id][actor.actor_uuid].controlled_items.append(row.item_uuid)
        check(Creation.observed(owner,descriptor,previous,events,commits).is_empty(),identity+" already-held records do not replay an admission")
    check(var_to_bytes([graph,events,commits])==original,identity+" projection borrows immutable native facts/captures without mutation")

func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Original real level10 party prefixes through actual Arm/Golden admissions; source/canonical/constructor/setter checks. Hand point is an explicit renderer packet fixture; no native pixels, second seat or later Incense qualification claimed."}))
    quit(0 if failures.is_empty() else 1)
