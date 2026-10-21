extends SceneTree
## Independent typed/measured originals qualify the small attack table and
## selected native pose documents. These selector controls are not recordings
## or framebuffer/visual approval; real compiled-prefix parity is separate.
const Authoring=preload("res://presentation/authoring.gd")
const Documents=preload("res://presentation/ability_documents.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Components=preload("res://presentation/components.gd")
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
func reference(fact:Dictionary,rig:String,source:Dictionary)->Dictionary:
    var recipe:Dictionary=source.duplicate(true)
    var delivery:String="projectile" if fact.weapon_slot in ["RANGED_MAIN","RANGED_OFF"] else "melee"
    var outcomes:Dictionary={"Hit":"hit","Miss":"miss","Crit":"critical","Crit Miss":"critical_miss"}
    var selected:Dictionary={}
    for variant in recipe.get("variants",[]):
        var matchers:Dictionary=variant.match
        var matches:bool=matchers.get("kind","attack")=="attack"
        for pair in [["delivery",delivery],["weaponSlots",fact.weapon_slot],["outcomes",outcomes[fact.attack_outcome]],
                ["sourceItemIds",fact.source_item_id],["sourceKinds",fact.attack_source_kind],["rigIds",rig]]:
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
        for field in ["actor","anchors","projectile","attackVfx","attackFeedback","weaponTrail"]:
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
            var expected:Dictionary=reference(input,rig,original)
            check(without_pose_storage(selected)==without_pose_storage(expected),"Independent pre-split selector equality: "+entry.id+" control"+str(controls))
            check(Components.weapon_trail(selected,input,actor,cache)==reference_trail(expected,input,actor,cache),"Actual outfit/slot selects the exact original pose, palette and impact source: "+entry.id+" control"+str(controls))
            controls+=1
        var one:Dictionary=Authoring.attack(fact,actor,cache)
        var two:Dictionary=Authoring.attack(fact,actor,cache)
        var held:PackedByteArray=var_to_bytes(two)
        check(not is_same(one,two) and is_same(one.get("variants"),built.get("variants")),"Occurrences own distinct shells and borrow immutable variants: "+entry.id)
        one.actor={"enabled":false};one.anchors=[];one.selected_variant="private-occurrence"
        check(var_to_bytes(two)==held and var_to_bytes(actual)==prior,"Changing one selected shell leaves other occurrence/source untouched: "+entry.id)
    check(owners==actual.size(),"Built table has exactly the actual authored attack owners")
    check(unique.size()==135,"All135 original measured poses are independently qualified")
    check(var_to_bytes(actual)==prior,"Every selector and document admission leaves immutable source table unchanged")
    evidence.append({"owners":owners,"unique_poses":unique.size(),"selector_controls":controls,"recipe_table_variant_bytes":prior.size()})
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Typed originals and135 exact measured pose documents, shared physical admission, independent prior selector and private occurrence shells. No framebuffer or art-approval claim."}
    FileAccess.open("res://generated/attack_recipe_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATTACK_RECIPE_ADMISSION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
