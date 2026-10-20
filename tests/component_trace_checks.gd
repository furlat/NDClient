extends SceneTree
## Passive trace contracts using original schema16 observations and SDK captures.
## Private authoring/components/counters below are unit controls, never render proof.
const Trace=preload("res://presentation/event_trace.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks=0
var failures:Array=[]
var cache={}
var originals:Dictionary={}
var packets:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("COMPONENT_TRACE_FAIL ",label)

func observations(id:String,seat:String="amber")->Array:
    var key:String=id+":"+seat
    if originals.has(key):return originals[key]
    var directory:String=Fixtures.journal(id,seat) if id!="thunderwave" else "res://tests/fixtures/schema16/component-trace-thunderwave/"+seat
    var journal=Journal.new()
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Original "+key+" journal opens")
    var result:Array=[]
    if not opened.ok:return result
    var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
    for file in files:
        if file.get_basename().length()!=16 or not file.get_basename().is_valid_int():continue
        var sequence:int=int(file.get_basename())
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
        var decoded:Dictionary=journal.decode_record(sequence,raw)
        check(decoded.ok,"Original "+key+" packet "+str(sequence)+" decodes")
        if not decoded.ok:return result
        var before:Dictionary=journal.state
        var admitted:Dictionary=journal._consume_admitted(decoded.value,raw,true)
        check(admitted.ok,"Original "+key+" packet "+str(sequence)+" folds")
        if not admitted.ok:return result
        if sequence==0:continue
        packets.append({"packet":admitted.normalized,"frozen":var_to_bytes(admitted.normalized)})
        for i in admitted.normalized.lineages.size():
            var lineage:Dictionary=Occurrences.group(admitted.normalized.lineages[i])
            var captures:Array=admitted.transitions.lineages[i].events
            for j in lineage.events.size():
                var event:Dictionary=lineage.events[j]
                result.append({"node":event,"fact":event.fact,"lineage":lineage,"captured":captures[j],"before":before,"after":journal.state,"packet":admitted.normalized,"transitions":admitted.transitions,"sequence":sequence})
    originals[key]=result
    return result

func select(id:String,kind:String,predicate:Callable=Callable(),seat:String="amber")->Dictionary:
    for sample in observations(id,seat):
        if sample.fact!=null and sample.fact.kind==kind and not sample.node.canceled and (not predicate.is_valid() or predicate.call(sample)):
            return sample
    check(false,"Original "+id+" contains requested "+kind+" observation")
    return {}

func component(kind:String,id:String="sample",extra:Dictionary={})->Dictionary:
    var value={"id":id,"kind":kind,"start_ms":100.0,"duration_ms":250.0,"status":"available","source":"unit-selected/source"}
    value.merge(extra,true);return value

func compile(sample:Dictionary,components:Array,recipe:Dictionary={},body:bool=true,body_fields:Dictionary={},cast_owner:String="")->Dictionary:
    var event:Dictionary=sample.node
    var fact:Dictionary=sample.fact if sample.fact!=null else {}
    var actor:Variant=fact.get("target_entity_uuid") if fact.get("kind") in ["damage","heal","forced_movement"] else fact.get("source_entity_uuid",fact.get("entity_uuid"))
    if fact.get("kind")=="actor_change":actor=fact.actors[0].actor_uuid
    var tracks:Array=[]
    if body:
        tracks=[{"trace_track_id":"body","source_event_uuid":event.id,"actor_uuid":actor,"priority":20,
            "rig":Authoring.rig_id(sample.captured.actor_inputs.get(actor,{}),cache),"clip":"Attack","start_ms":0.0,"duration_ms":200.0}]
        tracks[0].merge(body_fields,true)
    var selected:Array=[]
    for original in components:
        var value:Dictionary=original.duplicate(true)
        value.source_event_uuid=event.id;value.source_lineage=event.lineage_id;value.actor_uuid=actor
        selected.append(value)
    # Only schedule/evidence metadata is controlled. Native fact, versions,
    # hierarchy, actor visibility and condition before/after are unchanged.
    var group={"operation_sequence":sample.sequence,"id":sample.lineage.id,"duration_ms":300.0,"actor_tracks":tracks,"components":selected,
        "commits":[{"event_uuid":event.id,"at_ms":100.0}]}
    var lineage:Dictionary=sample.lineage.duplicate();lineage.events=[event]
    var graph={"starts":{event.id:0.0},"ends":{event.id:200.0},"nodes":{},"spell_facts":{},
        "actor_inputs":{event.id:sample.captured.actor_inputs},"recipes":{event.id:recipe},"condition_cues":{event.id:[]}}
    for actual in sample.lineage.events:graph.nodes[actual.lineage_id]=actual
    graph.actor_inputs[event.id]=Compiler._spell_actor_inputs(event,sample.captured.actor_inputs,sample.before,graph)
    for change in sample.captured.get("condition_rows",[]):
        if change.row.field!="condition" or (change.after!=null and change.before!=null):continue
        var member:Variant=change.after if change.after!=null else change.before
        if member==null:continue
        graph.condition_cues[event.id].append({"actor_uuid":change.actor_uuid,"condition":member,"row":change.row,
            "phase":"application" if change.after!=null else "removal","recipe":recipe})
    if not cast_owner.is_empty():
        graph.casts={Trace.SpellDelivery.cast_key(event,graph):{"source_event_uuid":cast_owner}}
    var rows:Array=Trace.compile_rows(lineage,group,graph,cache)
    return {"rows":rows,"group":group,"trace":Trace.create(),"event":event.id,"sequence":sample.sequence,
        "id":"%s:%s"%[sample.sequence,event.id],"actor":actor}
func emit(value:Dictionary,id:String,time:float)->void:
    Trace.record(value.trace,[{"trace_track_id":id,"display_ms":time,"visible":true}])
func commit(value:Dictionary)->void:Trace.commit(value.trace,value.sequence,value.event)
func snapshot(value:Dictionary)->Dictionary:return Trace.snapshot(value.trace,10,value.id,0)
func hierarchy(sample:Dictionary,seat:String)->void:
    var compiled:Dictionary=Compiler.compile_recorded(sample.before,sample.packet,cache,sample.after,sample.transitions)
    check(compiled.ok,seat+" original operation compiles without a second fold")
    if not compiled.ok:return
    var found:bool=false
    for group in compiled.value.groups:
        var rows:Array=group.get("events",[])
        if not rows.any(func(row):return row.event_uuid==sample.node.id):continue
        var by_id:Dictionary={}
        for row in rows:by_id[row.event_uuid]=row
        var native_ids:Array=sample.lineage.events.map(func(event):return event.id)
        var actual_ids:Array=rows.map(func(row):return row.event_uuid)
        var ordered:Array=native_ids.duplicate();ordered.sort_custom(func(a,b):return int(a)<int(b))
        check(actual_ids==ordered,seat+" trace retains every actual occurrence in native source-index order")
        for event in sample.lineage.events:
            var row:Dictionary=by_id[event.id]
            check(row.source_index==int(event.occurrence) and row.lineage_uuid==event.lineage_id and row.parent_event==event.parent_event and row.parent_lineage==event.parent_lineage and row.child_order==event.child_order,seat+" trace preserves native identity and hierarchy "+event.id)
        var trace:Dictionary=Trace.create()
        Trace.activate(trace,rows,0.0)
        for row in rows:
            var parent:String=row.get("_log_parent_id","")
            if row.get("_log")==null or parent.is_empty():continue
            var ancestor:Dictionary=rows.filter(func(value):return value.id==parent)[0]
            Trace.commit(trace,group.operation_sequence,row.event_uuid)
            check(not Trace.logs(trace,Trace.LIMIT).entries.any(func(entry):return entry.event_id==row.id),seat+" committed child log stays private until actual logged ancestor")
            Trace.commit(trace,group.operation_sequence,ancestor.event_uuid)
            var logs:Array=Trace.logs(trace,Trace.LIMIT).entries
            var parent_index:int=-1;var child_index:int=-1
            for i in logs.size():
                if logs[i].event_id==parent:parent_index=i
                if logs[i].event_id==row.id:child_index=i
            check(parent_index>=0 and child_index>parent_index,seat+" native ancestor log precedes its committed outcome")
            found=true;break
    check(found,seat+" actual attack/damage hierarchy exercises parent-gated log publication")

func run()->void:
    for seat in ["amber","blue"]:
        hierarchy(select("melee","attack",Callable(),seat),seat)
    var damage=select("melee","damage",func(value):return value.fact.get("stage")=="applied" and value.fact.applied_damage>0)
    var partial=compile(damage,[component("material_flash")])
    check(partial.rows[0].components.any(func(c):return c.kind=="damage_number" and c.status=="missing"),"Rendered flash cannot hide missing authored damage number")
    check(not partial.rows[0].components.any(func(c):return c.kind=="material_flash" and c.status=="missing"),"Compiled flash removes only its matching old missing requirement")
    var complete=compile(damage,[component("material_flash"),component("damage_number","number"),component("native_effect","blood",{"source_id":"blood.hit_a1"}),component("residue_deposit","residue")])
    check(complete.rows[0].components.size()==5,"Body, impact siblings and authoritative residue are retained individually")
    check(complete.rows[0].components.all(func(c):return c.status=="playing"),"Compilation is pending evidence, never green")
    check(complete.rows[0].components.all(func(c):return not c.has("presentation_actor") and not c.has("source_track")),"Trace stores no source snapshots or native handles")
    Trace.activate(complete.trace,complete.rows,0.0)
    Trace.tick(complete.trace,complete.rows,50.0)
    var early=snapshot(complete)
    check(early.selected.components.size()==1 and early.selected.components[0].kind=="body","Precommit diagnostics do not disclose selected impact components")
    emit(complete,"sample",50.0)
    check(complete.trace.tracks.sample[0].component.sample_count==0,"Too-early component evidence rejected")
    commit(complete)
    emit(complete,"body",150.0);emit(complete,"sample",150.0);emit(complete,"number",150.0);emit(complete,"residue",150.0)
    Trace.tick(complete.trace,complete.rows,300.0)
    check(snapshot(complete).selected.status=="missing","One unwitnessed native sibling prevents full presentation claim")
    emit(complete,"blood",325.0)
    check(snapshot(complete).selected.status=="presented","Actual component interval accepts its post-semantic-tail witness")
    var count=complete.trace.tracks.blood[0].component.sample_count
    emit(complete,"blood",351.0)
    check(complete.trace.tracks.blood[0].component.sample_count==count,"Evidence past component lifetime cannot qualify extra samples")

    var action=select("action-surge","action")
    var source=Authoring.load_data("native_effects/index.json",cache).sources
    var selected=""
    for id in source:
        if "class.action_surge.burst-q0-back" in source[id].get("media_ids",[]):selected=id
    check(not selected.is_empty(),"Fixture uses actual selected Action Surge native source")
    var surge_recipe=Authoring.action(action.fact,cache)
    var surge=compile(action,[component("native_effect","surge",{"source_id":selected})],surge_recipe,false)
    check(not surge.rows[0].components.any(func(c):return c.kind=="media" and c.status=="missing"),"One native composition covers its exact authored rear/front partitions")
    var recipes=Authoring.load_data("catalog/body_action_recipes.json",cache)
    var changed=recipes[action.fact.behavior_id].duplicate(true)
    changed.media.append({"id":"additional","assetId":"fixture.missing"})
    var additional=compile(action,[component("native_effect","surge",{"source_id":selected})],changed,false)
    check(additional.rows[0].components.any(func(c):return c.kind=="media" and c.get("authored_id")=="additional" and c.status=="missing"),"Native rear/front witness cannot hide an unrelated authored media sibling")
    var feedback_recipe={"actor":{"enabled":false},"attackFeedback":{"miss":{"text":"Miss","color":0xffffff}}}
    var attack=select("dodge","attack",func(value):return value.fact.attack_outcome=="Miss" and value.fact.attack_source_kind=="equipped")
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
    var unarmed=select("interaction-media","attack",func(value):return value.fact.attack_source_kind=="unarmed")
    check(not compile(unarmed,[],trail_recipe,false).rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented"),"Unequipped attacks do not demand an equipped blade trail")
    check(compile(attack,[],trail_recipe,false).rows[0].components.any(func(c):return c.reason=="authored_weapon_trail_not_implemented"),"Eligible melee without an actual selected trail remains missing")
    # A private negative selector control, not a recorded elemental attack.
    var elemental=attack.duplicate(true);elemental.fact.damage_types=["Fire"];elemental.node.fact=elemental.fact
    check(compile(elemental,[native_slash],trail_recipe,false).rows[0].components.filter(func(c):return c.reason=="authored_attack_vfx_not_implemented").size()==2,"Selected native trail does not replace elemental slash artwork")
    var spell_recipe={"cast":{"effects":[{"id":"hand","enabled":true}]},"projectile":{"enabled":true}}
    var spell=select("magic-missile","spell",func(value):return Occurrences.application(value.node))
    var cast=select("magic-missile","spell",func(value):return not Occurrences.application(value.node))
    var owner:String=cast.node.id
    var sibling=compile(spell,[component("native_effect","missile",{"attachment":"projectile","source_id":"spell.magic_missile.travel"})],spell_recipe,false,{},owner)
    check(not sibling.rows[0].components.any(func(c):return c.status=="missing"),"Sibling missile owns delivery without duplicating shared cast body/hand requirements")
    var absent_delivery=compile(spell,[],spell_recipe,false,{},owner)
    check(absent_delivery.rows[0].components.size()==1 and absent_delivery.rows[0].components[0].kind=="projectile","Each application still requires its own delivery component")

    var cast_only=compile(cast,[component("sprite_layer","hand",{"layer":{"id":"hand","slot":"magic"}})],spell_recipe,true,{},owner)
    check(not cast_only.rows[0].components.any(func(c):return c.status=="missing"),"Owning aggregate cast requires body/hands without a fabricated fourth projectile")
    var absent_cast=compile(cast,[],spell_recipe,false,{},owner)
    check(absent_cast.rows[0].components.filter(func(c):return c.status=="missing").size()==2,"Missing shared cast body and hand layer remain separate requirements")
    var healing=select("revive","heal",func(value):return value.fact.actual_healing>0)
    var heal_label=str(healing.fact.actual_healing)+" "+str(Authoring.load_data("catalog/healing_context.json",cache).feedbackLabel)
    var healed=compile(healing,[component("feedback_text","heal",{"text":heal_label})],{},false)
    check(not healed.rows[0].components.any(func(c):return c.reason=="authored_healing_feedback_not_implemented"),"Actual healing feedback satisfies its exact authored text")
    var wrong_heal=compile(healing,[component("feedback_text","heal",{"text":"99 Healing"})],{},false)
    check(wrong_heal.rows[0].components.any(func(c):return c.reason=="authored_healing_feedback_not_implemented"),"Unrelated feedback cannot qualify healing")
    var life=select("revive","life",func(value):return value.fact.new_state=="dying")
    var dying=compile(life,[component("feedback_text","life",{"text":"Dying"})])
    check(not dying.rows[0].components.any(func(c):return c.reason=="authored_life_feedback_not_implemented"),"Actual life-state text clears only matching feedback requirement")
    var death=select("oa-jump-lethal","life",func(value):return value.fact.new_state=="dead")
    check(not compile(death,[]).rows[0].components.any(func(c):return c.kind=="death_dust"),"Ordinary death preserves corpse without fabricated disintegration requirement")
    # A private negative requirement control; no recorded disintegration claim.
    death=death.duplicate(true);death.fact.remains_disposition="disintegrated";death.node.fact=death.fact
    check(compile(death,[]).rows[0].components.any(func(c):return c.kind=="death_dust" and c.status=="missing"),"Private disintegration requirement control keeps unimplemented authored dust visible")
    var forced=select("thunderwave","forced_movement")
    var still=compile(forced,[])
    check(still.rows[0].components.any(func(c):return c.reason=="authored_forced_movement_not_implemented"),"Stationary body cannot qualify forced displacement")
    var moved=compile(forced,[],{},true,{"motion":true})
    check(not moved.rows[0].components.any(func(c):return c.reason=="authored_forced_movement_not_implemented"),"Actual motion body satisfies forced-movement requirement")

    var application=select("condition-owners","actor_change",func(value):return value.captured.get("condition_rows",[]).any(func(change):return change.after!=null and change.before==null and change.after.behavior_id=="condition.paralyzed"))
    var change:Dictionary=application.captured.condition_rows.filter(func(value):return value.after!=null and value.after.behavior_id=="condition.paralyzed")[0]
    var condition:Dictionary=change.after
    var condition_recipe:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)[condition.behavior_id]
    var applied=compile(application,[component("feedback_text")],condition_recipe,false)
    var persistent:Array=applied.rows[0].components.filter(func(c):return c.get("persistent",false) and c.kind=="condition")
    check(not persistent.is_empty(),"Actual condition application exposes persistent owner mechanisms")
    var key:String=persistent[0].trace_track_id
    check(key.begins_with("condition:"+condition.condition_uuid+":") and persistent[0].start_ms==100.0,"Persistent witness uses exact disclosed owner/mechanism and commit")
    Trace.activate(applied.trace,applied.rows,0);commit(applied)
    emit(applied,key,99.0)
    check(applied.trace.tracks[key][0].component.sample_count==0,"Persistent visual cannot precede actual condition commit")
    emit(applied,key,900.0)
    check(applied.trace.tracks[key][0].component.sample_count==1,"Persistent witness may occur after originating semantic group")
    # Only a second passive evidence binding is controlled; no extra wire event.
    var refresh:Dictionary=applied.rows[0].duplicate(true)
    refresh.sequence=applied.sequence+1;refresh.id="%s:%s"%[refresh.sequence,applied.event]
    Trace.activate(applied.trace,[refresh],1000.0);Trace.commit(applied.trace,refresh.sequence,applied.event)
    emit(applied,key,950.0)
    check(applied.trace.tracks[key].size()==2 and applied.trace.tracks[key][1].component.sample_count==0,"Same owner refresh retains prior binding without qualifying its future occurrence")
    emit(applied,key,1150.0)
    check(applied.trace.tracks[key].all(func(binding):return binding.component.sample_count>0),"One real owner sample can witness both admitted refresh occurrences")
    var filler:Array=[]
    for i in Trace.LIMIT-1:
        var row:Dictionary=applied.rows[0].duplicate(true);row.id="filler:"+str(i);row.components=[]
        filler.append(row)
    Trace.activate(applied.trace,filler,2000.0)
    check(applied.trace.tracks[key].size()==1 and applied.trace.tracks[key][0].row.id==refresh.id,"Bounded event eviction removes only its own shared-owner witness binding")
    var changed_condition=select("condition-owners","actor_change",func(value):return value.captured.get("condition_rows",[]).any(func(row):return row.before!=null and row.after!=null))
    var refreshed_condition=compile(changed_condition,[],condition_recipe,false)
    check(not refreshed_condition.rows[0].components.any(func(c):return c.get("persistent",false)),"Native member update does not replay sustained application")
    var removed=select("condition-owners","actor_change",func(value):return value.captured.get("condition_rows",[]).any(func(row):return row.before!=null and row.after==null and row.before.condition_uuid==condition.condition_uuid))
    var removal=compile(removed,[component("feedback_text")],condition_recipe,false)
    check(not removal.rows[0].components.any(func(c):return c.get("persistent",false)),"Removal does not require restarting sustained presentation")
    # Missing-source timing is an authoring projection unit, not a fabricated Charm fact.
    var charm_recipe:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)["condition.charmed"]
    var charm_row={"components":[]}
    Trace._media_needed(charm_row,charm_recipe.application.effects,"catalog/condition_recipes.json:condition.charmed.application",100.0,"catalog/condition_recipes.json:/condition.charmed/application/effects")
    var charm_missing:Array=charm_row.components.filter(func(c):return c.get("authored_id")=="control.charm_hearts.back")
    check(charm_missing.size()==1 and charm_missing[0].timing.resolved and charm_missing[0].timing.start_ms==550 and charm_missing[0].timing.end_ms==2050,"Missing authored effect keeps its real commit-relative offset/duration")
    check(charm_missing[0].source_pointer=="catalog/condition_recipes.json:/condition.charmed/application/effects/2","Missing expected effect points at exact canonical authoring field")
    check(unmatched.rows[0].components.filter(func(c):return c.kind=="weapon_trail")[0].timing.resolved==false,"Missing timing is unresolved rather than fabricated at default zero")
    var unsupported={"components":[],"actor_uuid":change.actor_uuid,"target_uuid":change.actor_uuid,"_admit_ms":0.0}
    # Private authoring controls only: bodyScale is implemented and this actual
    # Paralyzed member has no size selector. Still-unimplemented structured and
    # array mechanisms must each remain missing, independent of that neutral arm.
    Trace._persistent_condition(unsupported,condition,{"bodyScale":{"enlarge":2,"reduce":.5},"bodyDistortion":{"amount":.1},"equipmentModifiers":[{"id":"trace-unit-equipment-modifier"}]},cache,"neuroclient.modular")
    var authored:Callable=func(components:Array)->Array:return components.filter(func(c):return not str(c.get("id","")).contains(":lifecycle:"))
    var unsupported_fields:Array=authored.call(unsupported.components)
    check(unsupported_fields.size()==2 and unsupported_fields.any(func(c):return c.reason=="authored_condition_bodyDistortion_not_implemented") and unsupported_fields.any(func(c):return c.reason=="authored_condition_equipmentModifiers_not_implemented"),"Structured and array authoring requirements retain independent missing mechanisms")
    check(not unsupported_fields.any(func(c):return c.get("mechanism")=="bodyScale"),"Supported bodyScale without this actual member's public selector does not invent an output requirement")
    var selected_recipe_case=compile(application,[],{"persistent":{},"application":{"feedbackEnabled":false}},false)
    check(authored.call(selected_recipe_case.rows[0].components).is_empty(),"Trace consumes compiler-selected recipe rather than reselecting catalog recipe")
    check(selected_recipe_case.rows[0].components.any(func(c):return c.id.begins_with("condition:"+condition.condition_uuid+":lifecycle:") and c.persistent),"Actual native condition id owns package lifecycle independent of selected recipe")
    var public_snapshot=Trace.snapshot(applied.trace,10,refresh.id,0)
    public_snapshot.selected.components.clear()
    check(not Trace.snapshot(applied.trace,10,refresh.id,0).selected.components.is_empty(),"Public component diagnostics stay detached")
    for original in packets:check(var_to_bytes(original.packet)==original.frozen,"Trace controls leave original schema16 packets immutable")
    var report={"checks":checks,"failures":failures,"scope":"Passive evidence and requirement matching; test witnesses do not claim native pixels or audio"}
    FileAccess.open("res://generated/component_trace_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("COMPONENT_TRACE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
