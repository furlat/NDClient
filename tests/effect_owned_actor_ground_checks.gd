extends SceneTree
## Original effect-owned actor, not a synthetic modular stand-in. Mutated
## visibility/source-contract cases are explicitly unit controls only.
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Sockets=preload("res://presentation/spell_placement.gd")
const Inputs=preload("res://presentation/native_inputs.gd")
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ROOT_PATH="res://tests/fixtures/schema16/effect-owned-actors/flaming-sphere"
const ACTOR="f0dcbb26-c72b-4d7b-b8bd-2a87bc4ceff3"
const AURA="83713b60-58b4-4e52-aa8c-5091374bd98f"
const SPATIAL="202889e7-0b76-491a-bbdf-6645cadbc624"
const CASTER="9a9f4b18-6736-49e4-9cb0-48beeb30fda8"
class World extends Node:
    var timeline:RefCounted
    var visual_actors:Dictionary={}
    var catalog_cache:Dictionary={}
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("EFFECT_OWNED_GROUND_FAIL ",label)
func run()->void:
    var entry:Resource=load("res://authoring/abilities/spells/spell.flaming_sphere.tres")
    check(Array(entry.owner_ids)==["condition.spell.flaming_sphere.aura"] and Array(entry.owner_cues)==[1],"Only the actual native body is delegated to its actual aura membership")
    check(Array(entry.excluded_cues)==[2,3,4,5],"Timed light/trajectory/Ram/turn-end review copies are explicitly excluded")
    for seat in ["amber","blue"]:original(seat)
    print("EFFECT_OWNED_ACTOR_GROUND ",JSON.stringify({"checks":checks,"failures":failures,"scope":"Genuine both-seat FlamingSphere actor/aura birth and held source; exact effect-owned ground registration, strict missing/hidden/non-ground controls and canonical seek. Movement/Ram/retirement/native pixels remain separate qualification."}))
    quit(0 if failures.is_empty() else 1)
func original(seat:String)->void:
    var directory:String=ROOT_PATH.path_join(seat)
    var journal:RefCounted=Journal.new();var opened:Dictionary=journal.open(directory,true,true)
    var index:Dictionary=Recording.read(directory)
    check(opened.ok and index.ok,seat+": independent original and ordinary Studio index open")
    if not opened.ok or not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var rows:Array=index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("lifecycle_key")=="condition_flaming_sphere_persistent")
    check(not rows.is_empty(),seat+": actual aura UUID has its provided native body lifecycle")
    if rows.is_empty():return
    var owner:Dictionary=rows[0].owner
    var timeline:RefCounted=Recording.restore(index,owner.start_ms+800.0)
    var samples:Array=timeline.component_samples(index.cache).filter(func(sample):return sample.get("lifecycle_key")=="condition_flaming_sphere_persistent")
    check(samples.size()==1 and owner.id==AURA and owner.actor_uuid==ACTOR,seat+": exactly one actual actor/aura owns the body")
    if samples.size()!=1:return
    var component:Dictionary=samples[0]
    var world:=World.new();world.timeline=timeline;world.catalog_cache=index.cache
    var source:Dictionary=Effects.conditions("condition.spell.flaming_sphere.aura").filter(func(selection):return selection.key=="condition_flaming_sphere_persistent")[0]
    check(source.condition.body_channel_included and source.condition.registration.attachment=="recipient_ground" and component.native_body_owner,seat+": source-declared body contract is carried explicitly")
    var actual:Dictionary=Sockets.effect_owned_ground(world,component,ACTOR)
    var points:Dictionary=Sockets.endpoints(world,component)
    check(actual.ready and points.ready and actual.point==Vector3(6,0,7) and points.to==actual.point and points.ground==actual.point,seat+": actual disclosed floor/position registers without inventing a sprite")
    check(world.visual_actors.is_empty() and timeline.state.senses.spatial_effects.has(SPATIAL),seat+": native body needs no proxy and the actual spatial aura remains separate")
    check(Spells.owned_cues(Spells.selection("spell.flaming_sphere",index.cache))==[1],seat+": normal ownership filter removes exactly the duplicate cast body")
    var adapter:RefCounted=Inputs.new()
    var authored:Dictionary=component.duplicate();authored.native_cue=component.native_cue.duplicate();authored.native_cue.live_endpoints=[{"actor":"target","socket":"ground"}]
    var packet:Dictionary=adapter.endpoint_packet(world,{},authored,points,{})
    check(packet.reason.is_empty() and packet.rows.size()==1 and packet.rows[0].actor_uuid==ACTOR and packet.rows[0].point==actual.point,seat+": explicit ground setter uses the same exact registration")
    authored.native_cue.live_endpoints=[{"actor":"target","socket":"hand"}]
    check(not adapter.endpoint_packet(world,{},authored,points,{}).reason.is_empty(),seat+": labelled missing-hand control cannot borrow the ground point")
    var no_contract:Dictionary=component.duplicate();no_contract.native_body_owner=false
    check(not Sockets.endpoints(world,no_contract).ready,seat+": no source body contract means no global missing-sprite fallback")
    var ordinary:Dictionary=component.duplicate();ordinary.target_uuid=CASTER
    check(not Sockets.effect_owned_ground(world,ordinary,CASTER).ready and not Sockets.endpoints(world,ordinary).ready,seat+": an ordinary missing modular actor cannot use native-body registration")
    var original_state:Dictionary=timeline.state
    var hidden:Dictionary=original_state.duplicate();hidden.actors=original_state.actors.duplicate();hidden.actors[ACTOR]=original_state.actors[ACTOR].duplicate();hidden.actors[ACTOR].present=false
    timeline.state=hidden
    check(not Sockets.effect_owned_ground(world,component,ACTOR).ready,seat+": labelled withdrawn actor cannot render from retained metadata")
    timeline.state=original_state
    var before:RefCounted=Recording.restore(index,maxf(0.0,owner.start_ms-.01))
    check(not before.condition_owners.has(AURA),seat+": before-admission seek does not invent the future body owner")
    var final:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(final.state==journal.state,seat+": endpoint selection preserves the independent original canonical drain")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+": unit controls leave actual immutable original data unchanged")
    world.free()
