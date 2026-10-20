extends SceneTree
## Real autonomous Steps use the shared Timeline motion clock. No sprite
## animation, invented Ram contact or authored trajectory is substituted.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT_PATH="res://tests/fixtures/schema16/scenarios/flaming-sphere-lifecycle"
const SPHERE="9a7daae4-573e-4248-82ca-19eb9430cf2c"
const OWNER="3e1d4d91-5553-4266-951d-0754ac3953c5"
const SPATIAL="b1bfa454-b66a-4dab-8c77-1ce50c5171e8"
const CASTER="ec1f2312-c161-48fd-b711-2d828582420e"
const STEPS=["102","139","201","238","275","312"]
const POINTS=[[6,7],[7,6],[8,6],[8,7],[8,8],[9,8],[10,7]]
class World extends Node:
    var timeline:RefCounted
    var visual_actors:Dictionary={}
    var catalog_cache:Dictionary={}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("EFFECT_OWNED_MOTION_FAIL ",label)
func run()->void:
    for seat in ["amber","blue"]:original(seat)
    print("EFFECT_OWNED_MOTION ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Both original autonomous six-Step FlamingSphere streams: shared position-only timing/interpolation, exact source-body ground registration, actual dismissal/owner retirement and independent canonical seek/loop. Ram and aura damage remain factual evidence, not qualified native contact/trail consumers."}))
    quit(0 if failures.is_empty() else 1)
func original(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent original and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var originals:Dictionary={}
    for sequence in [5,6,8,9,10,11]:
        var decoded:Dictionary=journal.protocol.decode_server("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence)))
        check(decoded.ok,seat+": original Step packet decodes exact typed public operands "+str(sequence))
        if not decoded.ok:return
        var packet:Dictionary=decoded.value
        for lineage in packet.lineages:
            for node in lineage.events:
                var fact:Variant=node.get("fact")
                if fact!=null and fact.kind=="step" and fact.source_entity_uuid==SPHERE:
                    originals[str(int(node.occurrence))]=fact
    check(originals.keys().size()==6 and STEPS.all(func(id):return originals.has(id)),seat+": six exact committed original sphere Steps are disclosed")
    if originals.size()!=6:return
    var lives:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==OWNER)
    check(lives.size()==1 and not lives[0].owner.initial and is_finite(float(lives[0].owner.start_ms)) \
        and float(lives[0].owner.start_ms)>0.0 and is_inf(float(lives[0].owner.end_ms)),seat+": actual later-admitted aura membership has no invented removal clock")
    if lives.size()!=1:return
    var owner:Dictionary=lives[0].owner
    var tracks:Dictionary={}
    for item in index.groups:
        for track in item.group.actor_tracks:
            if track.actor_uuid==SPHERE and track.get("motion",false):tracks[str(track.source_event_uuid)]={"item":item,"track":track}
    check(tracks.size()==6 and STEPS.all(func(id):return tracks.has(id)),seat+": all six actual Steps acquire position-only tracks")
    if tracks.size()!=6:return
    var motion:Dictionary=Recording.Compiler.Authoring.load_data("catalog/movement_context.json",index.cache)
    var reference:float=Recording.Compiler.Authoring.movement_reference_speed(index.cache)
    var world:=World.new();world.catalog_cache=index.cache
    var clocks:Array=[]
    for step_index in STEPS.size():
        var id:String=STEPS[step_index];var fact:Dictionary=originals[id]
        var selected:Dictionary=tracks[id];var track:Dictionary=selected.track
        check(fact.committed and fact.trajectory=="path" and fact.from_position==POINTS[step_index] and fact.to_position==POINTS[step_index+1],seat+": original path is exact for Step "+id)
        check(track.get("spatial_only",false) and not track.has("rig") and not track.has("clip") \
            and not track.has("source_start_seconds") and not track.has("source_end_seconds"),seat+": Step "+id+" claims no sprite rig, pose or frame clock")
        var duration:float=motion.walkStepDurationMs*Vector2(fact.from_position[0],fact.from_position[1]).distance_to(Vector2(fact.to_position[0],fact.to_position[1]))/(float(fact.resolved_speed_feet)/reference)
        check(is_equal_approx(track.duration_ms,duration) and track.from_elevation_feet==fact.from_elevation_feet \
            and track.to_elevation_feet==fact.to_elevation_feet,seat+": Step "+id+" uses unchanged shared movement duration and disclosed elevation")
        var start:float=float(selected.item.start_ms)+float(track.start_ms)
        check(is_finite(start) and is_finite(float(track.duration_ms)) and float(track.duration_ms)>0.0,seat+": Step "+id+" has finite positive presentation timing")
        if not is_finite(start) or not is_finite(float(track.duration_ms)) or float(track.duration_ms)<=0.0:world.free();return
        for fraction in [.25,.5,.75]:
            var at:float=start+float(track.duration_ms)*fraction
            world.timeline=Recording.restore(index,at)
            var sample:Dictionary=world.timeline.actor_samples().get(SPHERE,{})
            var components:Array=world.timeline.component_samples(index.cache).filter(func(component):return component.get("condition_uuid")==OWNER and component.get("native_body_owner",false))
            check(not sample.is_empty() and components.size()==1,seat+": Step "+id+" has one shared motion sample and one original body owner")
            if sample.is_empty() or components.size()!=1:continue
            var expected:=Vector3(lerpf(fact.from_position[0],fact.to_position[0],fraction), \
                lerpf(fact.from_elevation_feet,fact.to_elevation_feet,fraction)/5.0*Sockets.Placement.HEIGHT_UNIT, \
                lerpf(fact.from_position[1],fact.to_position[1],fraction))
            var endpoint:Dictionary=Sockets.effect_owned_ground(world,components[0],SPHERE)
            check(endpoint.ready and endpoint.point.is_equal_approx(expected) and not sample.has("source_seconds"),seat+": Step "+id+" native ground follows actual interpolated position without a fake body clock")
            check(is_equal_approx(float(components[0].age_ms),at-float(owner.start_ms)) and world.timeline.state.senses.spatial_effects.has(SPATIAL),seat+": Step "+id+" never restarts its native owner or merges the independent spatial aura")
        clocks.append({"occurrence":id,"start_ms":start,"duration_ms":duration,"from":fact.from_position,"to":fact.to_position})
    var movement_rows:Array=index.rows.filter(func(row):return row.kind=="motion" and row.get("track",{}).get("actor_uuid")==SPHERE)
    check(movement_rows.size()==6 and movement_rows.all(func(row):return row.status=="available" and row.source_fps==0),seat+": Studio exposes six actual movements without missing sprite-source rows")
    check(index.groups.all(func(item):return not item.group.components.any(func(component):return component.get("actor_uuid")==SPHERE and component.get("kind")=="audio" and component.get("assignment_source","").begins_with("audio/bindings.json:/movement/"))),seat+": spatial tracks do not fabricate sprite footstep contacts")
    var decoded_departure:Dictionary=journal.protocol.decode_server("PlayerOperation",FileAccess.get_file_as_bytes(directory.path_join("0000000000000016.json")))
    check(decoded_departure.ok,seat+": original dismissal packet decodes")
    if not decoded_departure.ok:world.free();return
    var dismissed:Dictionary=decoded_departure.value
    var departures:Array=[]
    for lineage in dismissed.lineages:
        for node in lineage.events:
            var fact:Variant=node.get("fact")
            if fact!=null and fact.kind=="spatial" and fact.get("entity_uuid")==SPHERE:departures.append(fact)
    check(departures.size()==1 and departures[0].terminal_departure and departures[0].terminal_cause=="dismissed",seat+": original terminal is actual dismissed departure, not a source-duration guess")
    var terminal:Dictionary=terminal_cut(index,seat)
    check(terminal.get("found",false) and is_finite(float(terminal.get("at_ms",INF))),seat+": actual terminal SpatialFact has one finite publication cut")
    if not terminal.get("found",false) or not is_finite(float(terminal.at_ms)):world.free();return
    var departed:RefCounted=Recording.restore(index,float(terminal.at_ms)+.01)
    check(not departed.state.actors[SPHERE].present and departed.state.actors[SPHERE].last_visual_position==null \
        and departed.state.actors[SPHERE].conditions.any(func(member):return member.condition_uuid==OWNER),seat+": finite dismissal withdraws the actual actor while preserving the recorded remembered member")
    check(is_finite(float(index.presentation_end_ms)),seat+": final original presentation cut is finite")
    if not is_finite(float(index.presentation_end_ms)):world.free();return
    var end:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    var canonical_difference:String=Compare.difference(end.state,journal.state)
    check(canonical_difference.is_empty(),seat+": final canonical state equals the independent journal: "+canonical_difference)
    check(not end.state.actors[SPHERE].present and end.state.actors[SPHERE].last_visual_position==null \
        and end.state.actors[SPHERE].conditions.any(func(member):return member.condition_uuid==OWNER) \
        and not end.state.senses.spatial_effects.has(SPATIAL),seat+": real dismissal retires visible actor/spatial aura without inventing membership removal")
    check(not end.state.senses.spatial_effects.is_empty(),seat+": genuine separately owned FireSurfaces survive sphere retirement")
    var first:Dictionary=tracks[STEPS[0]];var again:RefCounted=Recording.restore(index,float(first.item.start_ms)+float(first.track.start_ms)+float(first.track.duration_ms)*.5)
    check(again.condition_owners.has(OWNER) and not again.actor_samples().get(SPHERE,{}).is_empty(),seat+": reverse seek/loop restores the actual former motion and original owner")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": inspection and seek never mutate original source facts/cuts")
    evidence.append({"seat":seat,"actor_uuid":SPHERE,"condition_uuid":OWNER,"spatial_aura_uuid":SPATIAL,"steps":clocks,
        "native_contact_gap":"Ram/result source adapter and observed trail cells are not qualified by this movement proof"})
    world.free()

static func terminal_cut(index:Dictionary,seat:String)->Dictionary:
    var occurrence:String="411" if seat=="amber" else "410"
    var cuts:Array=[]
    for item in index.groups:
        for commit in item.group.commits:
            if str(commit.get("event_uuid",""))==occurrence:cuts.append(float(item.start_ms)+float(commit.at_ms))
    return {"found":cuts.size()==1,"occurrence":occurrence,"at_ms":cuts[0] if cuts.size()==1 else INF}
