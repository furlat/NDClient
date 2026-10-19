extends SceneTree
## Explicit body ownership, independent of whether an effect has been implemented.
const Characters=preload("res://presentation/characters.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Encounter=preload("res://presentation/encounter_media.gd")
const Compiler=preload("res://presentation/compiler.gd")
const SourceIndex=preload("res://presentation/resources/body_source_index.gd")
const Lights=preload("res://presentation/native_source_lights.gd")
const Selection=preload("res://presentation/selection_media.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("EFFECT_POLICY_FAIL "+label)
func run()->void:
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/character_sources.json"))
    var actor:Dictionary=state.actors.values()[0].duplicate(true)
    var index:Resource=SourceIndex.new()
    index.effect_owned_creatures={"creature.spell.flaming_sphere":true,"creature.spell.spiritual_weapon":true}
    var cache:Dictionary={Characters.BodySources.KEY:{"index":index,"loaded":{}}}
    var original:PackedByteArray=var_to_bytes(state)
    for id in index.effect_owned_creatures:
        actor.creature_content_ref="content.neurodragon:creature:"+id+"@1"
        var body:Dictionary=Characters.resolve(actor,state,cache)
        check(body.ok and body.value==null,"Explicit effect body never requests a substitute sprite rig: "+id)
        var errors:Array=[]
        check(Media._actor_base(actor,["Idle"],cache,errors).is_empty() and errors.is_empty(),"Media admits no phantom sprite sources for "+id)
        check(Compiler._actor_structure_value(actor,{},[1],cache).is_empty(),"No sprite structural boundary is invented for "+id)
        var media_result:Dictionary={"errors":[],"paths":{},"cpu_required":{},"gpu_only":{},"normal_sets":{}}
        check(Selection._actor_paths(actor,["Idle"],media_result,cache,state).is_empty() and media_result.errors.is_empty(),"An enabled sprite cue does not invent a rig for effect-owned actors: "+id)
        var selected:Dictionary=Selection.plan({"state":{"actors":{actor.uuid:actor},"items":{},"objects":{}},"actor_uuid":actor.uuid,"behavior":"action.move","behaviors":["action.move","action.class.barbarian.rage"],"budget_bytes":1024},cache,{"mutex":Mutex.new(),"cancelled":false})
        check(selected.paths.is_empty() and selected.errors.is_empty(),"Movement selection does not index an absent sprite rig: "+id)
        check(not selected.native_action_clips.is_empty() and not selected.native_action_conditions.is_empty(),"Skipping sprite media retains independently authored native effects and condition candidates: "+id)
        var actual:Resource=load("res://authoring/characters/characters/"+id+".tres")
        check(actual.body_policy=="effect" and actual.rig.is_empty(),"Policy comes from the actual typed spell-construct source")
    actor.creature_content_ref="content.neurodragon:creature:creature.unknown@1"
    check(not Characters.resolve(actor,state,cache).ok,"Unknown or missing body art is still an explicit error, never implicitly an effect actor")
    check(var_to_bytes(state)==original,"Body selection never rewrites canonical actor or world state")
    var host:Node3D=Node3D.new();root.add_child(host)
    var light:DirectionalLight3D=DirectionalLight3D.new();host.add_child(light)
    var sources:RefCounted=Lights.new()
    check(sources.prepare_native_handles({"effect":{"root":host,"optical":{"energy_multiplier":0.0}}}) and sources.preparation_counts.roots==0 and sources.preparation_counts.cookies==0,"Zero emission does no donor discovery or cookie preparation")
    sources.sample_handles({"effect":{"root":host,"optical":{"energy_multiplier":0.0}}})
    check(sources.effect_sources.is_empty() and sources._effect_issues.is_empty() and sources.pending.is_empty(),"Zero authored emission neither submits donor lights nor creates unsupported-light errors/readiness work")
    sources._effect_roots[host.get_instance_id()]=[{"node":light,"path":"DirectionalLight3D"}]
    sources.sample_handles({"effect":{"root":host,"optical":{"energy_multiplier":1.0}}})
    check(sources._effect_issues.size()==1,"An unsupported emitting light is still reported, not silently converted or discarded")
    sources.clear_pages();host.free()
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Explicit effect-owned body policy and inactive optical emission; actual effect rendering remains independently qualified"}));quit(0 if failures.is_empty() else 1)
