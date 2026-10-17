extends SceneTree
## The live player no longer extends the workshop: loading play.gd loads neither
## main.gd nor the workshop-only scripts it preloads.
const WORKSHOP_ONLY=["res://main.gd","res://exploration.gd","res://editor.gd","res://walking.gd",
    "res://map_data.gd","res://view_build.gd","res://grid_renderer.gd","res://terrain_batches.gd"]
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("LIVE_CHAIN_SEPARATION_FAIL ",label)
func _initialize()->void:
    for path in WORKSHOP_ONLY:check(not ResourceLoader.has_cached(path),"Not loaded before the live player: "+path)
    var play:Script=load("res://play.gd")
    check(play!=null and play.can_instantiate(),"Live player script compiles")
    var base:Script=play.get_base_script()
    check(base!=null and base.resource_path=="res://presentation/sprite_sources.gd","Live player extends the shared sprite sources directly")
    for path in WORKSHOP_ONLY:check(not ResourceLoader.has_cached(path),"Live player does not load "+path)
    var report:Dictionary={"checks":checks,"failures":failures}
    print("LIVE_CHAIN_SEPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
