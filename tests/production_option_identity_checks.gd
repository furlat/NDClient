extends SceneTree
## Real production resources + unchanged original journals. Option identity is
## routing evidence, not seventeen new effects or visual acceptance.
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const ROOT="res://tests/fixtures/schema16/option-identities/"
const CASES={
    "bestow_curse":{"folder":"bestow-curse","effect":"control.bestow_curse.option_1","owner":"condition.spell.bestow_curse.ability","lifecycle":"condition_bestow_curse_ability_persistent"},
    "blindness_deafness":{"folder":"blindness-deafness","effect":"control.blinded","owner":"condition.blinded","lifecycle":"condition_blinded_native"},
    "enhance_ability":{"folder":"enhance-ability","effect":"support.enhance_ability.strength","owner":"condition.spell.enhance_ability","lifecycle":"condition_enhance_ability_strength_persistent"},
    "protection_from_energy":{"folder":"protection-from-energy","effect":"support.protection_from_energy.fire","owner":"condition.spell.protection_from_energy","lifecycle":"condition_protection_from_energy_fire_persistent"}}
const OPTIONS={
    "bestow_curse":["control.bestow_curse.option_1","control.bestow_curse.option_2","control.bestow_curse.option_3","control.bestow_curse.option_4"],
    "blindness_deafness":["control.blinded","control.deafened"],
    "enhance_ability":["support.enhance_ability.charisma","support.enhance_ability.constitution","support.enhance_ability.dexterity","support.enhance_ability.intelligence","support.enhance_ability.strength","support.enhance_ability.wisdom"],
    "protection_from_energy":["support.protection_from_energy.acid","support.protection_from_energy.cold","support.protection_from_energy.fire","support.protection_from_energy.lightning","support.protection_from_energy.thunder"]}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("PRODUCTION_OPTION_IDENTITY_FAIL ",label)
func run()->void:
    var count:int=0;var cache:Dictionary={}
    for name in CASES:
        var id:String="spell."+name;var typed:Resource=load("res://authoring/abilities/spells/"+id+".tres")
        var report:Dictionary=Common.report();Build._check_variants(typed,id,report)
        check(report.errors.is_empty(),id+" production typed predicates satisfy the offline authoring rules")
        var active:Array=[]
        for variant in typed.variants:
            if variant.when.is_empty():continue
            count+=1;active.append(variant.id)
            check(variant.when=={"effect_id":[variant.id]} and variant.id in OPTIONS[name],id+" exact native effect identity is the only authored predicate")
            check(variant.recipe.is_empty(),id+" option has no obsolete full recipe/body snapshot")
        check(active.size()==OPTIONS[name].size() and OPTIONS[name].all(func(option):return option in active),id+" all exact production options are represented once")
        var record:Resource=Sources.find(id,cache)
        check(record!=null,id+" actual built production source is available")
        if record==null:continue
        var source:Dictionary=Spells.source(id,cache)
        var frozen:PackedByteArray=var_to_bytes([record.recipe,record.selection,record.variants])
        for option in OPTIONS[name]:
            var choice:Dictionary=Spells.selected(source,{"behavior_id":id,"effect_id":option})
            check(choice.selection.get("variant",{}).get("id")==option,id+" built selector retains exact option identity "+option)
            check(is_same(choice.recipe,record.recipe) and is_same(choice.recipe.cast,record.recipe.cast),id+" option borrows the same immutable recipe and caster")
        for fact in [{"behavior_id":id},{"behavior_id":id,"effect_id":null},{"behavior_id":id,"effect_id":"unrecognized.option"}]:
            check(is_same(Spells.selected(source,fact).selection,record.selection),id+" absent/null/unknown identity remains the baseline")
        if name=="blindness_deafness":deaf_controls(source)
        for seat in ["amber","blue"]:original(name,seat,source,cache)
        if name=="enhance_ability":
            for ability in ["charisma","constitution","dexterity","intelligence","wisdom"]:
                var spec:Dictionary={"folder":"enhance-ability-"+ability,"effect":"support.enhance_ability."+ability, \
                    "owner":"condition.spell.enhance_ability","lifecycle":"condition_enhance_ability_"+ability+"_persistent","removed":true,"journal_suffix":""}
                for seat in ["amber","blue"]:original(name,seat,source,cache,spec)
        check(var_to_bytes([record.recipe,record.selection,record.variants])==frozen,id+" selection/Studio/seek leave the shared production source immutable")
    check(count==17,"Exactly seventeen existing option identities are routed; no draft native alternative is implicitly activated")
    print("PRODUCTION_OPTION_IDENTITIES ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Seventeen actual typed predicates and nine original two-seat option paths, including five complete Enhance membership/move/remove/restoration journals; existing fifteen condition forms are not new graphics. Native output, alternate original recordings and native finite Deafness output remain separate."}))
    quit(0 if failures.is_empty() else 1)
func deaf_controls(source:Dictionary)->void:
    # Selection-only policy controls, not an invented Deafness recording.
    var deaf:Dictionary=Spells.selected(source,{"behavior_id":"spell.blindness_deafness","effect_id":"control.deafened"})
    var phases:Array=Spells.phases(deaf.selection,{"prepare":0.0},100.0,0.0,0,true)
    check(phases.size()==1 and phases[0].get("status","available")=="available" \
        and phases[0].native_clip.id=="production-review/deafness/finite_application" \
        and is_equal_approx(phases[0].duration_ms,1200.0),
        "Exact Deafness identity selects its delivered finite source without borrowing Blinded art")
    var clips:Array=Spells.effect_clips(deaf.selection)
    check(clips.size()==1 and clips[0].id=="production-review/deafness/finite_application" \
        and clips[0].input_setters.get("live_endpoints")=="set_live_endpoints","The exact Deafness receiving source enters preparation with its actual geometry contract")
    var markers:Array=Persistent.lifecycles({"behavior_id":"condition.deafened","state":{}})
    check(markers.any(func(selection):return selection.key=="condition_deafened_native" \
        and selection.condition.get("marker",{}).get("group")=="deafened" \
        and not selection.condition.get("body_channel_included",false)),
        "The condition marker remains distinct from the finite Deafness receiving source")
func original(name:String,seat:String,source:Dictionary,cache:Dictionary,override:Dictionary={})->void:
    var spec:Dictionary=CASES[name] if override.is_empty() else override;var label:String=spec.folder+"/"+seat
    var directory:String=ROOT+spec.folder+"/"+seat+str(spec.get("journal_suffix","/journal"))
    var index:Dictionary=Recording.read(directory,{},{},cache)
    check(index.ok,label+" ordinary Studio indexes unchanged original operations")
    if not index.ok:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var expected:RefCounted=Journal.new();var opened:Dictionary=expected.open(directory,true,true)
    check(opened.ok,label+" original SDK journal independently folds")
    if not opened.ok:return
    var restored:RefCounted=Recording.restore(index,index.presentation_end_ms+1000.0)
    check(Compare.difference(restored.state,expected.state).is_empty(),label+" presentation end equals that audience's independently folded canonical state")
    var traces:Dictionary={};var tracks:Array=[]
    for wrapped in index.groups:
        for event in wrapped.group.events:traces[str(event.event_uuid)]=event
        tracks.append_array(wrapped.group.actor_tracks.filter(func(track):return track.get("activity")=="cast"))
    var actual:int=0;var sparse:int=0;var declarations:Dictionary={}
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int() or int(file.get_basename())==0:continue
        var decoded:Dictionary=expected.decode_record(int(file.get_basename()),FileAccess.get_file_as_bytes(directory.path_join(file)))
        check(decoded.ok,label+" original SDK admits "+file)
        if not decoded.ok:return
        var frozen:PackedByteArray=var_to_bytes(decoded.value)
        for raw in decoded.value.lineages:
            var lineage:Dictionary=Occurrences.group(raw);var graph:Dictionary={"nodes":{},"spell_facts":{}}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            for node in lineage.events:
                if node.get("fact")==null or node.fact.kind!="spell":continue
                var fact:Dictionary=Occurrences.spell(node,graph)
                if fact.get("behavior_id")!="spell."+name:continue
                actual+=1
                check(fact.get("effect_id")==spec.effect,label+" exact option is disclosed by this actual cast declaration")
                if Occurrences.application(node):
                    sparse+=1
                    check(not node.fact.has("effect_id") and fact.effect_id==spec.effect,label+" sparse application inherits only its real cast's effect identity")
                var choice:Dictionary=Spells.selected(source,fact)
                var trace:Dictionary=traces.get(str(node.id),{})
                check(not trace.is_empty() and trace.get("native_variant",{}).get("id")==spec.effect,label+" Studio event trace and actual selected production variant agree")
                check(is_same(choice.recipe,source.recipe) and is_same(choice.recipe.cast,source.recipe.cast),label+" recipient choice retains the single caster/recipe owner")
                if not trace.is_empty():declarations[str(trace.cast_owner_event)]=true
        check(var_to_bytes(decoded.value)==frozen,label+" sparse resolution never edits original disclosed facts")
    check(actual==(2 if name=="blindness_deafness" else 1) and sparse==(1 if name=="blindness_deafness" else 0),label+" actual cast/application cardinality is preserved")
    check(tracks.size()==1 and declarations.size()==1,label+" option choice never creates another casting animation or cast owner")
    var owners:Array=[]
    for actor in expected.state.actors.values():
        owners.append_array(actor.get("conditions",[]).filter(func(condition):return condition.behavior_id==spec.owner))
    if spec.get("removed",false):
        check(owners.is_empty(),label+" authoritative final state removed the actual condition")
        for row in index.rows:
            if row.kind=="condition" and row.get("owner",{}).get("condition",{}).get("behavior_id")==spec.owner:
                owners.append(row.owner.condition)
        var movement:Array=index.rows.filter(func(row):return row.kind=="body" and row.get("track",{}).get("trajectory")=="path")
        check(movement.size()>=2,label+" actual movement is recorded before and after removal")
    check(not owners.is_empty(),label+" expected condition form was actually admitted")
    for owner in owners:
        check(Persistent.lifecycles(owner).any(func(selection):return selection.key==spec.lifecycle),label+" original condition state routes its already delivered form")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==immutable,label+" inspection/seek preserves original indexed source cuts")
    evidence.append({"case":name,"seat":seat,"effect_id":spec.effect,"spell_occurrences":actual,"sparse_applications":sparse,"condition_uuids":owners.map(func(owner):return owner.condition_uuid)})
