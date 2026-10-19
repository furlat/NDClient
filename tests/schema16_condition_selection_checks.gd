extends SceneTree
## Package-only owners must not alias an absent legacy recipe or inherit its cap.
const Conditions=preload("res://presentation/conditions.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONDITION_SELECTION_FAIL "+label)
func sample(id:String,recipe:Dictionary={},alpha:float=1.0)->Dictionary:
    return {"kind":"condition","condition_uuid":id,"actor_uuid":"actual-actor","recipe":recipe,"alpha":alpha,"source":id}
func _initialize()->void:
    var owners:Array=[sample("first"),sample("second"),sample("third"),sample("fourth")]
    check(Conditions.select_recipes("actual-actor",owners).size()==4,"Four unrelated native-only UUID owners are retained without an invented three-layer legacy cap")
    check(Conditions.recipe_key(owners[0])!=Conditions.recipe_key(owners[1]),"Absent legacy references cannot collapse independent native owners")
    var legacy:Dictionary={"definitionRef":{"id":"authored-shared"}}
    check(Conditions.select_recipes("actual-actor",[sample("weak",legacy,.3),sample("strong",legacy,.7)])[0].condition_uuid=="strong","Explicit legacy aliases retain authored strongest-instance selection")
    var a:Dictionary={"definitionRef":{"id":"a"},"composition":{"group":"authored","maxLayers":1,"priority":5}}
    var b:Dictionary={"definitionRef":{"id":"b"},"composition":{"group":"authored","maxLayers":1,"priority":1}}
    check(Conditions.select_recipes("actual-actor",[sample("a",a),sample("b",b)]).size()==1,"Explicit composition capacity remains enforced for its authored group")
    check(Conditions.select_recipes("another-actor",owners).is_empty(),"Owner selection never crosses recipients")
    var cache:Dictionary={}
    var pointer:String=Catalog.source_pointer("spells/retired-document.json","cast",cache)
    check(pointer=="spells/retired-document.json:/cast" and cache.is_empty(),"A provenance label never loads a retired JSON document")
    var pose:Dictionary=Conditions.ConditionPose.select({"life_state":"alive","conditions":[{"condition_uuid":"internal","behavior_id":null,"state":null}]},"unused","idle",{})
    check(pose.is_empty(),"Disclosed internal condition with null behavior has no invented visual pose")
    print(JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
