extends SceneTree
## The native presentation catalog carries the animation schema's supplied
## movement reference speed; the compiler reads only the catalog.
const Authoring=preload("res://presentation/authoring.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("MOVEMENT_REFERENCE_SPEED_FAIL ",label)
func _initialize()->void:
    var schema:Dictionary=Catalog.read_file("schemas/animation.schema.json",{})
    var authored:float=float(schema.properties.movement_reference_speed_feet.default)
    var cache:Dictionary={}
    var native:float=Authoring.movement_reference_speed(cache)
    check(native==authored,"Native catalog value equals the schema default exactly")
    check(typeof(native)==TYPE_FLOAT,"Compiler operand stays a float")
    check(not cache.has("schemas/animation.schema.json"),"Compiling a movement no longer parses the animation schema")
    var report:Dictionary={"checks":checks,"failures":failures,"authored":authored,"native":native}
    print("MOVEMENT_REFERENCE_SPEED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
