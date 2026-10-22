extends SceneTree
## Independent typed/measured originals qualify the small attack table and
## selected native pose documents. These selector controls are not recordings
## or framebuffer/visual approval; real compiled-prefix parity is separate.
const Authoring=preload("res://presentation/authoring.gd")
const Documents=preload("res://presentation/ability_documents.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Components=preload("res://presentation/components.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Characters=preload("res://presentation/characters.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("ATTACK_ADMISSION_FAIL "+label)
func measured(path:String)->Variant:
    return null if path.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+path))
# The pre-split selector, retained independently of the new borrowed-shell
# implementation. Its input is rebuilt from actual authored Resources and the
# original measured JSON, not the runtime selector's own result.
func reference(fact:Dictionary,rig:String,source:Dictionary,creature:String="")->Dictionary:
    var recipe:Dictionary=source.duplicate(true)
    var delivery:String="projectile" if fact.weapon_slot in ["RANGED_MAIN","RANGED_OFF"] else "melee"
    var outcomes:Dictionary={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}
    var selected:Dictionary={}
    for variant in recipe.get("variants",[]):
        var matchers:Dictionary=variant.match
        var matches:bool=matchers.get("kind","attack")=="attack"
        for pair in [["delivery",delivery],["weaponSlots",fact.weapon_slot],["outcomes",outcomes[fact.attack_outcome]],
                ["sourceItemIds",fact.source_item_id],["sourceKinds",fact.attack_source_kind],["rigIds",rig],["creatureIds",creature]]:
            var constraint:Variant=matchers.get(pair[0])
            if constraint==null:continue
            if constraint is Array:
                if pair[1] not in constraint:matches=false
            elif pair[1]!=constraint:matches=false
        if matchers.get("sourceItemRefs")!=null:
            var found:bool=false
            for item in matchers.sourceItemRefs:
                if item.content_id==fact.source_item_id:found=true
            if not found:matches=false
        if matchers.get("elemental")!=null:
            var elemental:bool=false
            for type in fact.damage_types:
                if type not in ["Bludgeoning","Piercing","Slashing"]:elemental=true
            if matchers.elemental!=elemental:matches=false
        var types:Variant=matchers.get("primaryDamageTypes")
        if types!=null and (fact.damage_types.is_empty() or fact.damage_types[0] not in types):matches=false
        if matches and (selected.is_empty() or variant.precedence>selected.precedence):selected=variant
    if not selected.is_empty():
        for field in ["actor","anchors","projectile","attackVfx","attackFeedback","weaponTrail","sourceTiming"]:
            if selected.has(field):recipe[field]=selected[field]
        recipe.selected_variant=selected.id
    return recipe
func without_pose_storage(recipe:Dictionary)->Dictionary:
    var value:Dictionary=recipe.duplicate()
    if value.get("weaponTrail")!=null:
        value.weaponTrail=value.weaponTrail.duplicate()
        value.weaponTrail.erase("poses");value.weaponTrail.erase("poseDocuments")
    return value
func reference_trail(recipe:Dictionary,fact:Dictionary,actor:Dictionary,cache:Dictionary)->Dictionary:
    var trail:Dictionary=recipe.get("weaponTrail",{}) if recipe.get("weaponTrail")!=null else {}
    if trail.is_empty() or recipe.get("projectile")!=null or fact.attack_source_kind!="equipped":return {}
    if str(trail.get("source_id","")).is_empty() or float(trail.get("contact_seconds",0.0))<=0.0 \
        or float(trail.get("end_seconds",0.0))<float(trail.get("contact_seconds",0.0)):return {}
    var outcome:String={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}[fact.attack_outcome]
    if fact.behavior_id not in trail.get("behaviorIds",[]) and outcome not in trail.get("outcomes",[]):return {}
    var rig_id:String=Authoring.rig_id(actor,cache)
    var outfit:Dictionary=Characters._select_layers(actor,Authoring.rigs(cache)[rig_id],actor.appearance.presentation_kind=="layered",cache)
    if not outfit.ok:return {}
    var slot:String="offhand" if fact.weapon_slot=="MELEE_OFF" else "weapon"
    for layer in outfit.value:
        if layer.slot!=slot:continue
        for pose in trail.poses:
            if pose.rigId==rig_id and pose.category==layer.category and pose.clip==recipe.actor.clip:
                return {"pose":pose,"palette":trail.palette,"source_id":str(trail.source_id),
                    "impact_source_id":str(trail.get("impact_source_id","")),"contact_seconds":float(trail.contact_seconds),
                    "end_seconds":float(trail.end_seconds),"source":str(trail.get("source",""))}
    return {}
# Actual typed body choices on existing substitute rigs; these are source and
# selector controls, not a recording, contact measurement or rendered approval.
func provisional_creature_choices(actor:Dictionary,cache:Dictionary)->void:
    for choice in [
            {"id":"action.cambion.draining_kiss","creature":"creature.spell.cambion","rig":"smallscale.demonelite01","clip":"Attack4"},
            {"id":"action.djinni.sweetplum_gales","creature":"creature.spell.djinni","rig":"smallscale.characters.6mage","clip":"Special1"},
            {"id":"action.draconic_spirit.breath","creature":"creature.spell.draconic_spirit","rig":"summon.draconic_spirit.violet-astral","clip":"Ground_Breathe","frames":24}]:
        var entry:Resource=load("res://authoring/abilities/actions/"+choice.id+".tres")
        var owner:Dictionary=actor.duplicate(true);owner.creature_content_ref=choice.creature
        var fact:Dictionary={"kind":"action","behavior_id":choice.id,"source_entity_uuid":owner.uuid}
        var original:PackedByteArray=var_to_bytes(fact)
        var selected:Dictionary=Authoring.action(fact,cache,owner)
        var clip:Dictionary=Authoring.clip(owner,choice.clip,cache)
        check(entry.disposition=="authored" and entry.status=="partial" and entry.body.rig==choice.rig \
            and selected.actor.enabled and selected.actor.clip==choice.clip and selected.get("anchors",[]).is_empty() \
            and Authoring.rig_id(owner,cache)==choice.rig and clip.frames==choice.get("frames",15) and clip.fps==12.0 \
            and var_to_bytes(fact)==original,
            choice.id+": explicit current body choice keeps its actual clip clock without invented contact/fact")
        check(Authoring.action(fact,cache,actor).is_empty(),choice.id+": exact rig refuses an unrelated body")
    # Source selector operands from the real Draconic original: public kind
    # equipped, despite the producer's internal BODY/natural weapon usage.
    var dragon:Dictionary=actor.duplicate(true);dragon.creature_content_ref="creature.spell.draconic_spirit"
    var rend:Dictionary={"kind":"attack","behavior_id":"action.attack","weapon_slot":"MELEE_MAIN",
        "attack_outcome":"Miss","source_item_id":"weapon.spell_summon.draconic_spirit","attack_source_kind":"equipped","damage_types":["Piercing"]}
    var dragon_recipe:Dictionary=Authoring.attack(rend,dragon,cache)
    var dragon_clip:Dictionary=Authoring.clip(dragon,"Ground_Attack",cache)
    check(dragon_recipe.get("selected_variant")=="draconic-native-bound-rend-grounded-presentation" and dragon_recipe.actor.enabled
        and dragon_recipe.actor.clip=="Ground_Attack" and dragon_recipe.anchors.is_empty() and not dragon_recipe.has("sourceTiming")
        and dragon_recipe.get("projectile")==null and dragon_recipe.get("weaponTrail")==null
        and dragon_clip.frames==16 and dragon_clip.fps==12.0,
        "Actual equipped Rend selects own16-pose grounded body without generic contact8/recover10/trail inheritance")
    for changed in [{"weapon_slot":"MELEE_OFF"},{"attack_source_kind":"natural"},{"source_item_id":"weapon.claws"}]:
        var refused:Dictionary=Authoring.attack(rend.merged(changed,true),dragon,cache)
        check(refused.get("selected_variant")=="draconic-native-rig-unmatched-refusal" and not refused.actor.enabled and refused.anchors.is_empty(),
            "Unmatched selected-dragon source/item/slot retains explicit body refusal: "+str(changed))
    var deva:Dictionary=actor.duplicate(true);deva.creature_content_ref="creature.spell.deva"
    var fact:Dictionary={"kind":"attack","behavior_id":"action.deva.concussive_smash","weapon_slot":"MELEE_MAIN", \
        "attack_outcome":"Hit","source_item_id":"weapon.spell_summon.deva","attack_source_kind":"equipped","damage_types":["Bludgeoning","Radiant"]}
    var selected:Dictionary=Authoring.attack(fact,deva,cache)
    var clip:Dictionary=Authoring.clip(deva,"Attack1",cache)
    check(selected.get("selected_variant")=="actual-deva-bound-mace-stand-in" and selected.actor.enabled \
        and selected.actor.clip=="Attack1" and selected.anchors.is_empty() and not selected.has("sourceTiming") \
        and Authoring.rig_id(deva,cache)=="smallscale.characters.4paladin" and clip.frames==15 and clip.fps==12.0,
        "Actual Deva equipped bound-Mace Attack selects only its provisional real clip with unmarked scheduling")
    for changed in [{"weapon_slot":"MELEE_OFF"},{"attack_source_kind":"natural"},{"source_item_id":"weapon.mace"}]:
        var wrong:Dictionary=fact.merged(changed,true)
        check(not Authoring.attack(wrong,deva,cache).actor.enabled,"Deva source/item/slot mismatch retains disabled default: "+str(changed))
    check(not Authoring.attack(fact,actor,cache).actor.enabled,"Wrong creature cannot borrow Deva's attack body")
    var admission:Dictionary=Characters.BodySources.admission(cache)
    var private_index:Resource=admission.index.duplicate()
    private_index.creature_rigs=admission.index.creature_rigs.duplicate()
    private_index.creature_rigs["creature.spell.deva"]=Authoring.rig_id(actor,cache)
    var private_cache:Dictionary=cache.duplicate()
    var private_admission:Dictionary=admission.duplicate();private_admission.index=private_index
    private_cache[Characters.BodySources.KEY]=private_admission
    check(not Authoring.attack(fact,deva,private_cache).actor.enabled,"Future body replacement cannot inherit the current4Paladin stand-in")
    var wrapper:Resource=load("res://authoring/abilities/actions/action.deva.concussive_smash.tres")
    check(wrapper.disposition=="state_only" and not wrapper.body.enabled,
        "Deva wrapper delegates the actual Attack instead of adding an unused second gesture")

func run()->void:
    var cache:Dictionary={}
    var actual:Dictionary=Authoring.load_data("catalog/attack_recipes.json",cache)
    var prior:PackedByteArray=var_to_bytes(actual)
    var state:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/schema16/character_sources.json"))
    var actor:Dictionary=state.actors.values()[0]
    var rig:String=Authoring.rig_id(actor,cache)
    var files:PackedStringArray=DirAccess.get_files_at("res://authoring/abilities/attacks");files.sort()
    var unique:Dictionary={};var owners:int=0;var controls:int=0
    for file in files:
        if not file.ends_with(".tres"):continue
        var entry:Resource=load("res://authoring/abilities/attacks/"+file)
        var source:Variant=measured(entry.trail_points)
        var sockets:Variant=measured(entry.variant_sockets)
        var original:Dictionary=Records.attack_recipe(entry,source.get("poses") if source is Dictionary else null,sockets if sockets is Dictionary else {})
        check(actual.has(entry.id),"Every authored attack has a built owner: "+entry.id)
        if not actual.has(entry.id):continue
        owners+=1
        var built:Dictionary=actual[entry.id]
        check(without_pose_storage(built)==without_pose_storage(original),"All actor/variant/marker/feedback/trail metadata remains exact: "+entry.id)
        if source is Dictionary:
            var wanted:Dictionary={}
            for pose in source.poses:
                var key:String=str(pose.rigId)+"/"+str(pose.category)+"/"+str(pose.clip)
                if not wanted.has(key):wanted[key]=pose
            var paths:Dictionary=built.get("weaponTrail",{}).get("poseDocuments",{})
            check(not built.weaponTrail.has("poses") and paths.size()==wanted.size(),"No embedded bank, exact original first-match pose membership: "+entry.id)
            for key in wanted:
                check(paths.has(key),"Measured pose has an exact document: "+entry.id+"/"+key)
                if not paths.has(key):continue
                var path:String=paths[key]
                check(path=="weapon_trails/"+entry.trail_points.get_basename()+"/"+key+".json","Physical document follows the actual authored measured source: "+key)
                check(Documents.owns(path),"Selected pose belongs to the native document owner: "+key)
                var loaded:Dictionary=Authoring.load_data(path,cache)
                check(loaded==wanted[key] and var_to_bytes(loaded)==var_to_bytes(wanted[key]),"Every pose point/facing/numeric type and byte is exact: "+key)
                if unique.has(key):
                    check(unique[key].path==path and is_same(unique[key].value,loaded),"Attack aliases borrow one physical admitted pose: "+entry.id+"/"+key)
                else:unique[key]={"path":path,"value":loaded}
        var fact:Dictionary={"kind":"attack","behavior_id":entry.id,"weapon_slot":"MELEE_MAIN","attack_outcome":"Hit",
            "source_item_id":"weapon.longsword","attack_source_kind":"equipped","damage_types":["Slashing"]}
        var witnesses:Array=[fact]
        # Actual authored constraints provide useful selector controls; these
        # intentionally vary presentation inputs, not server recording facts.
        for variant in original.get("variants",[]):
            var candidate:Dictionary=fact.duplicate(true)
            var matchers:Dictionary=variant.match
            for pair in [["weaponSlots","weapon_slot"],["sourceItemIds","source_item_id"],["sourceKinds","attack_source_kind"]]:
                var value:Variant=matchers.get(pair[0])
                if value!=null:candidate[pair[1]]=value[0] if value is Array else value
            if matchers.get("delivery")=="projectile":candidate.weapon_slot="RANGED_MAIN"
            if matchers.get("sourceItemRefs")!=null:candidate.source_item_id=matchers.sourceItemRefs[0].content_id
            if matchers.get("outcomes")!=null:
                var outcome:Variant=matchers.outcomes[0] if matchers.outcomes is Array else matchers.outcomes
                candidate.attack_outcome={"hit":"Hit","miss":"Miss","critical":"Crit","critical_miss":"Crit Miss"}[outcome]
            if matchers.get("elemental",false):candidate.damage_types=["Fire"]
            if matchers.get("primaryDamageTypes")!=null:candidate.damage_types=[matchers.primaryDamageTypes[0]]
            witnesses.append(candidate)
        for input in witnesses:
            var selected:Dictionary=Authoring.attack(input,actor,cache)
            var expected:Dictionary=reference(input,rig,original,Characters.content_id(actor.get("creature_content_ref")))
            check(without_pose_storage(selected)==without_pose_storage(expected),"Independent pre-split selector equality: "+entry.id+" control"+str(controls))
            check(Components.weapon_trail(selected,input,actor,cache)==reference_trail(expected,input,actor,cache),"Actual outfit/slot selects the exact original pose, palette and impact source: "+entry.id+" control"+str(controls))
            controls+=1
        var one:Dictionary=Authoring.attack(fact,actor,cache)
        var two:Dictionary=Authoring.attack(fact,actor,cache)
        var held:PackedByteArray=var_to_bytes(two)
        check(not is_same(one,two) and is_same(one.get("variants"),built.get("variants")),"Occurrences own distinct shells and borrow immutable variants: "+entry.id)
        one.actor={"enabled":false};one.anchors=[];one.selected_variant="private-occurrence"
        check(var_to_bytes(two)==held and var_to_bytes(actual)==prior,"Changing one selected shell leaves other occurrence/source untouched: "+entry.id)
    var spirit_actor:Dictionary=actor.duplicate(true)
    spirit_actor.creature_content_ref="creature.spell.spiritual_weapon"
    var spirit_fact:Dictionary={"kind":"attack","behavior_id":"action.spell.spiritual_weapon.strike","weapon_slot":"MELEE_MAIN",
        "attack_outcome":"Hit","source_item_id":null,"attack_source_kind":"natural","damage_types":["Force"]}
    var spirit:Dictionary=Authoring.attack(spirit_fact,spirit_actor,cache)
    check(not spirit.actor.enabled and spirit.selected_variant=="actual-autonomous-spiritual-weapon" \
        and spirit.sourceTiming.clip=="bg3-36/spiritual-weapon/strike" \
        and spirit.sourceTiming.contact_seconds==0.45 and spirit.sourceTiming.end_seconds==1.1,
        "Exact effect-bodied source uses its declared finite contact/end without a borrowed sprite rig")
    var wrong:Dictionary=spirit_fact.duplicate();wrong.weapon_slot="MELEE_OFF"
    check(not Authoring.attack(wrong,spirit_actor,cache).has("sourceTiming") \
        and not Authoring.attack(spirit_fact,actor,cache).has("sourceTiming"),
        "Wrong slot or creature cannot inherit the autonomous source timing")
    var shield:Dictionary=spirit_fact.duplicate();shield.behavior_id="action.monster.shield_bash"
    shield.attack_source_kind="equipped";shield.weapon_slot="MELEE_OFF";shield.source_item_id="shield.shield"
    var bash:Dictionary=Authoring.attack(shield,actor,cache)
    check(bash.actor.enabled and bash.actor.clip=="Attack5" and bash.anchors==[{"name":"action_start","frame":0.0},{"name":"contact","frame":8.0},{"name":"recover","frame":10.0}],
        "Shield Bash reuses the existing measured modular offhand body/anchors exactly")
    var gateplate:Dictionary=actor.duplicate(true)
    gateplate.creature_content_ref="creature.enemy_gateplate"
    var gate:Dictionary=Authoring.attack(shield,gateplate,cache)
    check(gate.get("selected_variant")=="actual-gateplate-shield-offhand" and Authoring.rig_id(gateplate,cache)=="smallscale.enemies.3footsoldier" \
        and gate.actor.clip=="Attack5" and gate.anchors==bash.anchors,
        "Exact Gateplate rig inherits only the existing0/8/10 Attack5-to-Attack4 stand-in choice")
    var public_actor:Dictionary=spirit_actor.duplicate(true)
    public_actor.uuid="selector-source";public_actor.present=true;public_actor.last_visual_position=[1,1]
    var actual_cut:Dictionary={"actors":{"selector-source":public_actor},"senses":{"entities":{
        "selector-source":{"position":[5,7],"visual":true}}},"tiles":{"5,7":{"elevation_steps":1},"1,1":{"elevation_steps":0}},
        "audience":{"controlled":[]}}
    var receiving:Dictionary=Compiler._response_inputs(actual_cut.actors,actual_cut,"attack")
    check(receiving["selector-source"]=={"position":[5,7],"elevation_steps":1},
        "Current public visual contact owns the Attack point even when its Body was admitted later")
    actual_cut.senses.entities["selector-source"].visual=false
    check(Compiler._response_inputs(actual_cut.actors,actual_cut,"attack").is_empty(),
        "Nonvisual uncontrolled actor cannot reuse a remembered position as observed")
    actual_cut.senses.entities.clear()
    check(Compiler._response_inputs(actual_cut.actors,actual_cut,"attack").is_empty(),
        "Absent current sight cannot borrow the stale Body position")
    actual_cut.audience.controlled=["selector-source"]
    check(Compiler._response_inputs(actual_cut.actors,actual_cut,"attack")["selector-source"].position==[1,1],
        "Actual controlled actor retains its current canonical position without requiring a self contact")
    public_actor.present=false
    check(Compiler._response_inputs(actual_cut.actors,actual_cut,"attack").is_empty(),
        "Departed controlled actor does not retain an optical Attack point")
    for outcome in ["Hit","Crit","Miss","Crit Miss"]:
        var input:Dictionary=spirit_fact.duplicate();input.attack_outcome=outcome
        input.source_entity_uuid="selector-source";input.target_entity_uuid="selector-target"
        var source:Dictionary=spirit_actor.duplicate();source.uuid=input.source_entity_uuid
        var node:Dictionary={"id":"18","lineage_id":"17","phase":"completion","canceled":false,"fact":input}
        var descriptor:Dictionary=load("res://authoring/abilities/actions/action.spell.spiritual_weapon.strike.tres").effects[0].constructor_input
        var input_graph:Dictionary={"actor_inputs":{"18":{"selector-source":source}},"condition_response_inputs":{"18":{
            "selector-source":{"position":[5,7],"elevation_steps":1},"selector-target":{"position":[6,7],"elevation_steps":2}}}}
        var projected:Array=Components.ApplicationResults.observed(node,descriptor,input_graph)
        check(projected.size()==1 and projected[0].origin_position==[5,7] and projected[0].destination_position==[6,7] \
            and projected[0].origin_elevation_feet==5.0 and projected[0].destination_elevation_feet==10.0 \
            and projected[0].values.contact_enabled==(outcome in ["Hit","Crit"]),
            "Actual "+outcome+" controls autonomous contact without an invented hit")
        input_graph.condition_response_inputs["18"].erase("selector-source")
        check(Components.ApplicationResults.observed(node,descriptor,input_graph).is_empty(),
            "Undisclosed current source contact cannot become an origin from an opaque actor record")
    provisional_creature_choices(actor,cache)
    check(owners==actual.size(),"Built table has exactly the actual authored attack owners")
    check(unique.size()==135,"All135 original measured poses are independently qualified")
    check(var_to_bytes(actual)==prior,"Every selector and document admission leaves immutable source table unchanged")
    evidence.append({"owners":owners,"unique_poses":unique.size(),"selector_controls":controls,"recipe_table_variant_bytes":prior.size()})
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Typed originals and135 exact measured pose documents, shared physical admission, independent prior selector and private occurrence shells. No framebuffer or art-approval claim."}
    FileAccess.open("res://generated/attack_recipe_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATTACK_RECIPE_ADMISSION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
