extends SceneTree
## Evidence semantics only: no test-supplied witness is a native render claim.
const Trace=preload("res://presentation/event_trace.gd")
const Authoring=preload("res://presentation/authoring.gd")
var checks=0
var failures:Array=[]
var cache={}
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("COMPONENT_TRACE_FAIL ",label)
func node(fact:Dictionary)->Dictionary:
    return {"uuid":"event","lineage_uuid":"lineage","phase":"committed","fact":fact,"canceled":false,
        "combat_log":null,"parent_event":null,"parent_lineage":null,"children_lineages":[]}
func component(kind:String,id:String="sample",extra:Dictionary={})->Dictionary:
    var value={"id":id,"kind":kind,"source_event_uuid":"event","source_lineage":"lineage","actor_uuid":"actor",
        "start_ms":100.0,"duration_ms":250.0,"status":"available","source":"typed/source"}
    value.merge(extra,true);return value
func compile(fact:Dictionary,components:Array,recipe:Dictionary={},body:bool=true,body_fields:Dictionary={},cast_owner:String="")->Dictionary:
    var event=node(fact)
    var tracks:Array=[]
    if body:tracks=[{"trace_track_id":"body","source_event_uuid":"event","actor_uuid":"actor","priority":20,
        "rig":"typed","clip":"Attack","start_ms":0.0,"duration_ms":200.0}]
    if body:tracks[0].merge(body_fields,true)
    var group={"operation_sequence":7,"id":"group","duration_ms":300.0,"actor_tracks":tracks,"components":components,
        "commits":[{"event_uuid":"event","at_ms":100.0}]}
    var lineage={"events":[event],"version_rows":[{"event_uuid":"event","lineage_uuid":"lineage","source_index":1}]}
    var actor={"uuid":"actor","last_visual_position":[0,0]}
    var graph={"starts":{"event":0.0},"ends":{"event":200.0},"actor_inputs":{"event":{"actor":actor}},"recipes":{"event":recipe}}
    if not cast_owner.is_empty():
        var key:String=fact.application.lineage_uuid if fact.get("application")!=null else event.lineage_uuid
        graph.casts={key:{"source_event_uuid":cast_owner}}
    var rows=Trace.compile_rows(lineage,group,graph,cache)
    return {"rows":rows,"group":group,"trace":Trace.create()}
func emit(case:Dictionary,id:String,time:float)->void:
    Trace.record(case.trace,[{"trace_track_id":id,"display_ms":time,"visible":true}])
func run()->void:
    var damage={"kind":"damage","stage":"applied","applied_damage":7,"target_entity_uuid":"actor","source_entity_uuid":"actor"}
    var partial=compile(damage,[component("material_flash")])
    check(partial.rows[0].components.any(func(c):return c.kind=="damage_number" and c.status=="missing"),"Rendered flash cannot hide missing authored damage number")
    check(not partial.rows[0].components.any(func(c):return c.kind=="material_flash" and c.status=="missing"),"Compiled flash removes only its matching old missing requirement")
    var complete=compile(damage,[component("material_flash"),component("damage_number","number"),component("native_effect","blood",{"source_id":"blood.hit_a1"})])
    check(complete.rows[0].components.size()==4,"Body and three actual impact components retained individually")
    check(complete.rows[0].components.all(func(c):return c.status=="playing"),"Compilation is pending evidence, never green")
    check(complete.rows[0].components.all(func(c):return not c.has("presentation_actor") and not c.has("source_track")),"Trace stores no source snapshots or native handles")
    Trace.activate(complete.trace,complete.rows,0.0)
    Trace.tick(complete.trace,complete.rows,50.0)
    var early=Trace.snapshot(complete.trace,10,"7:event",0)
    check(early.selected.components.size()==1 and early.selected.components[0].kind=="body","Precommit diagnostics do not disclose selected impact components")
    emit(complete,"sample",50.0)
    check(complete.trace.tracks.sample[0].component.sample_count==0,"Too-early component evidence rejected")
    Trace.commit(complete.trace,7,"event")
    emit(complete,"body",150.0);emit(complete,"sample",150.0);emit(complete,"number",150.0)
    Trace.tick(complete.trace,complete.rows,300.0)
    check(Trace.snapshot(complete.trace,10,"7:event",0).selected.status=="missing","One unwitnessed native sibling prevents full presentation claim")
    emit(complete,"blood",325.0)
    check(Trace.snapshot(complete.trace,10,"7:event",0).selected.status=="presented","Actual component interval accepts its post-semantic-tail witness")
    var count=complete.trace.tracks.blood[0].component.sample_count
    emit(complete,"blood",351.0)
    check(complete.trace.tracks.blood[0].component.sample_count==count,"Evidence past component lifetime cannot qualify extra samples")

    var action={"kind":"action","behavior_id":"action.class.fighter.action_surge","source_entity_uuid":"actor"}
    var source=Authoring.load_data("native_effects/index.json",cache).sources
    var selected=""
    for id in source:
        if "class.action_surge.burst-q0-back" in source[id].get("media_ids",[]):selected=id
    check(not selected.is_empty(),"Fixture uses actual selected Action Surge native source")
    var surge_recipe=Authoring.action(action,cache)
    var surge=compile(action,[component("native_effect","surge",{"source_id":selected})],surge_recipe,false)
    check(not surge.rows[0].components.any(func(c):return c.kind=="media" and c.status=="missing"),"One native composition covers its exact authored rear/front partitions")
    var recipes=Authoring.load_data("catalog/body_action_recipes.json",cache)
    var changed=recipes[action.behavior_id].duplicate(true)
    changed.media.append({"id":"additional","assetId":"fixture.missing"})
    var additional=compile(action,[component("native_effect","surge",{"source_id":selected})],changed,false)
    check(additional.rows[0].components.any(func(c):return c.kind=="media" and c.get("authored_id")=="additional" and c.status=="missing"),"Native rear/front witness cannot hide an unrelated authored media sibling")
    var feedback_recipe={"actor":{"enabled":false},"attackFeedback":{"miss":{"text":"Miss","color":0xffffff}}}
    var attack={"attack_source_kind":"equipped","kind":"attack","behavior_id":"action.attack","source_entity_uuid":"actor","attack_outcome":"Miss"}
    var wrong=compile(attack,[component("feedback_text","wrong",{"text":"Critical!!"})],feedback_recipe,false)
    check(wrong.rows[0].components.any(func(c):return c.reason=="authored_attack_feedback_not_implemented"),"Wrong text does not fulfill authored miss feedback")
    var right=compile(attack,[component("feedback_text","right",{"text":"Miss"})],feedback_recipe,false)
    check(not right.rows[0].components.any(func(c):return c.reason=="authored_attack_feedback_not_implemented"),"Matching occurrence and text satisfy only that feedback requirement")
    var vfx_recipe={"actor":{"enabled":false},"attackVfx":{"onMiss":{"slash":{"category":"Slash1"},"magic":{"category":"Magic1"}}}}
    var slash=compile(attack,[component("sprite_layer","slash",{"layer":{"id":"attack.slash","slot":"slash"}})],vfx_recipe,false)
    check(slash.rows[0].components.filter(func(c):return c.reason=="authored_attack_vfx_not_implemented").size()==1,"One authored attack slot cannot satisfy another missing slot")
    var all_slots=compile(attack,[component("sprite_layer","slash",{"layer":{"id":"attack.slash","slot":"slash"}}),component("sprite_layer","magic",{"layer":{"id":"attack.magic","slot":"magic"}})],vfx_recipe,false)
    check(not all_slots.rows[0].components.any(func(c):return c.reason=="authored_attack_vfx_not_implemented"),"Each actual attack layer qualifies its exact authored slot")
    var trail_recipe=vfx_recipe.duplicate(true);trail_recipe.weaponTrail={"outcomes":["miss"]}
    var native_slash=component("native_effect","native-slash",{"source_id":"class.martial.slash","weapon_pose":{"clip":"Slash1"}})
    var replaced=compile(attack,[native_slash],trail_recipe,false)
    check(not replaced.rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented") and replaced.rows[0].components.filter(func(c):return c.reason=="authored_attack_vfx_not_implemented").size()==1,"Actual selected native weapon pose replaces only physical slash and retains magic sibling requirement")
    var unmatched=compile(attack,[component("native_effect","native-slash",{"source_id":"class.martial.slash"})],trail_recipe,false)
    check(unmatched.rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented") and unmatched.rows[0].components.filter(func(c):return c.reason=="authored_attack_vfx_not_implemented").size()==2,"Native source without selected weapon pose cannot hide failed matching or slots")
    var ranged_recipe=trail_recipe.duplicate(true);ranged_recipe.projectile={"geometry":{"enabled":true}}
    check(not compile(attack,[],ranged_recipe,false).rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented"),"Projectile attacks exclude melee weapon trail exactly as the original selector")
    var unarmed=attack.duplicate();unarmed.attack_source_kind="unarmed"
    check(not compile(unarmed,[],trail_recipe,false).rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented"),"Unequipped attacks do not demand an equipped blade trail")
    check(compile(attack,[],trail_recipe,false).rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented"),"Eligible melee without an actual selected trail remains missing")
    var elemental=attack.duplicate();elemental.damage_types=["Fire"]
    check(compile(elemental,[native_slash],trail_recipe,false).rows[0].components.filter(func(c):return c.reason=="authored_attack_vfx_not_implemented").size()==2,"Selected native trail does not replace elemental slash artwork")
    var spell_recipe={"cast":{"effects":[{"id":"hand","enabled":true}]},"projectile":{"enabled":true}}
    var spell={"kind":"spell","behavior_id":"spell.magic_missile","source_entity_uuid":"actor","application":{"lineage_uuid":"shared-cast","index":1}}
    var sibling=compile(spell,[component("native_effect","missile",{"attachment":"projectile","source_id":"spell.magic_missile.travel"})],spell_recipe,false,{},"owning-event")
    check(not sibling.rows[0].components.any(func(c):return c.status=="missing"),"Sibling missile owns delivery without duplicating shared cast body/hand requirements")
    var absent_delivery=compile(spell,[],spell_recipe,false,{},"owning-event")
    check(absent_delivery.rows[0].components.size()==1 and absent_delivery.rows[0].components[0].kind=="projectile","Each application still requires its own delivery component")
    var cast=spell.duplicate();cast.application=null
    var cast_only=compile(cast,[component("sprite_layer","hand",{"layer":{"id":"hand","slot":"magic"}})],spell_recipe,true,{},"event")
    check(not cast_only.rows[0].components.any(func(c):return c.status=="missing"),"Owning aggregate cast requires body/hands without a fabricated fourth projectile")
    var absent_cast=compile(cast,[],spell_recipe,false,{},"event")
    check(absent_cast.rows[0].components.filter(func(c):return c.status=="missing").size()==2,"Missing shared cast body and hand layer remain separate requirements")
    var healing={"kind":"heal","actual_healing":7,"target_entity_uuid":"actor"}
    var heal_label="7 "+str(Authoring.load_data("catalog/healing_context.json",cache).feedbackLabel)
    var healed=compile(healing,[component("feedback_text","heal",{"text":heal_label})],{},false)
    check(not healed.rows[0].components.any(func(c):return c.reason=="authored_healing_feedback_not_implemented"),"Actual healing feedback satisfies its exact authored text")
    var wrong_heal=compile(healing,[component("feedback_text","heal",{"text":"99 Healing"})],{},false)
    check(wrong_heal.rows[0].components.any(func(c):return c.reason=="authored_healing_feedback_not_implemented"),"Unrelated feedback cannot qualify healing")
    var life={"kind":"life","new_state":"dying","entity_uuid":"actor"}
    var dying=compile(life,[component("feedback_text","life",{"text":"Dying"})])
    check(not dying.rows[0].components.any(func(c):return c.reason=="authored_life_feedback_not_implemented"),"Actual life-state text clears only matching feedback requirement")
    var death={"kind":"life","new_state":"dead","entity_uuid":"actor","remains_disposition":"intact"}
    check(not compile(death,[]).rows[0].components.any(func(c):return c.kind=="death_dust"),"Ordinary death preserves corpse without fabricated disintegration requirement")
    death.remains_disposition="disintegrated"
    check(compile(death,[]).rows[0].components.any(func(c):return c.kind=="death_dust" and c.status=="missing"),"Actual disintegration keeps unimplemented authored dust visible")
    var forced={"kind":"forced_movement","start_position":[0,0],"end_position":[1,0],"target_entity_uuid":"actor"}
    var still=compile(forced,[])
    check(still.rows[0].components.any(func(c):return c.reason=="authored_forced_movement_not_implemented"),"Stationary body cannot qualify forced displacement")
    var moved=compile(forced,[],{},true,{"motion":true})
    check(not moved.rows[0].components.any(func(c):return c.reason=="authored_forced_movement_not_implemented"),"Actual motion body satisfies forced-movement requirement")

    var condition={"condition_uuid":"owner","behavior_id":"condition.poisoned","name":"Poisoned"}
    var application={"kind":"condition","event_type":"condition_application","target_entity_uuid":"actor","condition":condition}
    var condition_recipe:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)[condition.behavior_id]
    var applied=compile(application,[component("feedback_text")],condition_recipe,false)
    var key="condition:owner:bodyColor"
    check(applied.rows[0].components.any(func(c):return c.trace_track_id==key and c.start_ms==100.0),"Persistent material witness is scoped to exact owner/mechanism and actual commit")
    Trace.activate(applied.trace,applied.rows,0);Trace.commit(applied.trace,7,"event")
    emit(applied,key,99.0)
    check(applied.trace.tracks[key][0].component.sample_count==0,"Persistent visual cannot precede actual condition commit")
    emit(applied,key,900.0)
    check(applied.trace.tracks[key][0].component.sample_count==1,"Persistent witness may occur after originating semantic group")
    var refresh:Dictionary=applied.rows[0].duplicate(true)
    refresh.id="8:event";refresh.sequence=8
    Trace.activate(applied.trace,[refresh],1000.0);Trace.commit(applied.trace,8,"event")
    emit(applied,key,950.0)
    check(applied.trace.tracks[key].size()==2 and applied.trace.tracks[key][1].component.sample_count==0,"Same owner refresh retains prior binding without qualifying its future occurrence")
    emit(applied,key,1150.0)
    check(applied.trace.tracks[key].all(func(binding):return binding.component.sample_count>0),"One real owner sample can witness both admitted refresh occurrences")
    var filler:Array=[]
    for i in Trace.LIMIT-1:
        var row:Dictionary=applied.rows[0].duplicate(true);row.id="filler:"+str(i);row.components=[]
        filler.append(row)
    Trace.activate(applied.trace,filler,2000.0)
    check(applied.trace.tracks[key].size()==1 and applied.trace.tracks[key][0].row.id=="8:event","Bounded event eviction removes only its own shared-owner witness binding")
    var changed_condition=application.duplicate(true);changed_condition.event_type="condition_state_changed"
    var suppression=compile(changed_condition,[],condition_recipe,false)
    check(suppression.rows[0].components.is_empty() and suppression.rows[0].reasons==["condition_state_change_no_application_replay"],"Suppression update does not invent application or feedback requirements")
    var removed=application.duplicate(true);removed.event_type="condition_removal"
    var removal=compile(removed,[component("feedback_text")],condition_recipe,false)
    check(not removal.rows[0].components.any(func(c):return c.get("persistent",false)),"Removal does not require restarting sustained presentation")
    var charm_fact=application.duplicate(true)
    charm_fact.condition={"condition_uuid":"charm","behavior_id":"condition.charmed"}
    var charm_missing=compile(charm_fact,[],Authoring.load_data("catalog/condition_recipes.json",cache)["condition.charmed"],false).rows[0].components.filter(func(c):return c.get("authored_id")=="control.charm_hearts.back")
    check(charm_missing.size()==1 and charm_missing[0].timing.resolved and charm_missing[0].timing.start_ms==550 and charm_missing[0].timing.end_ms==2050,"Missing authored effect keeps its real commit-relative offset/duration")
    check(charm_missing[0].source_pointer=="catalog/condition_recipes.json:/condition.charmed/application/effects/2","Missing expected effect points at exact canonical authoring field")
    check(unmatched.rows[0].components.filter(func(c):return c.kind=="weapon_trail")[0].timing.resolved==false,"Missing timing is unresolved rather than fabricated at default zero")
    var unsupported={"components":[],"actor_uuid":"actor","target_uuid":"actor","_admit_ms":0.0}
    Trace._persistent_condition(unsupported,condition,{"bodyScale":{"enlarge":2,"reduce":.5},"equipmentModifiers":[]},cache,"neuroclient.modular")
    check(unsupported.components.size()==1 and unsupported.components[0].reason=="authored_condition_bodyScale_not_implemented","Structured and array authoring requirements retain independent missing mechanisms")
    var selected_recipe_case=compile(application,[],{"persistent":{},"application":{"feedbackEnabled":false}},false)
    check(selected_recipe_case.rows[0].components.is_empty(),"Trace consumes the compiler-selected recipe rather than reselecting the catalog recipe")
    var snapshot=Trace.snapshot(applied.trace,10,"8:event",0)
    snapshot.selected.components.clear()
    check(not Trace.snapshot(applied.trace,10,"8:event",0).selected.components.is_empty(),"Public component diagnostics stay detached")
    var report={"checks":checks,"failures":failures,"scope":"Passive evidence and requirement matching; test witnesses do not claim native pixels or audio"}
    FileAccess.open("res://generated/component_trace_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("COMPONENT_TRACE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
