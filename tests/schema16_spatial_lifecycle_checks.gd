extends SceneTree
const Library=preload("res://studio/case_library.gd")
const Recording=preload("res://studio/recording.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SPATIAL_LIFECYCLE_FAIL "+label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var cases:Array=Library.read().filter(func(row):return row.id=="spell.web/baseline" and row.ready)
    check(cases.size()==1,"Real current Web recording is available")
    if cases.is_empty():finish();return
    var index:Dictionary=Recording.read(cases[0].journals.amber)
    check(index.get("ok",false),"Original Web journal folds and compiles through production")
    if not index.get("ok",false):finish();return
    var rows:Array=index.rows.filter(func(row):return row.get("component",{}).get("spatial_owner",false))
    check(not rows.is_empty(),"Studio exposes the actual spatial owner")
    if rows.is_empty():finish();return
    var component:Dictionary=rows[0].component
    check(component.has("lifecycle_phases") and component.native_clip.id=="conditions/continuation/spatial_web_persistent/application","Spatial owner uses the delivered lifecycle rather than the old staged net")
    check("admitted_cells" in component.native_clip.inputs,"Declared membership setter controls the delivered net")
    check(not component.resolved_area_positions.is_empty(),"Original disclosed footprint supplies the spatial net cells")
    check(component.actor_uuid==null and component.ground_target,"Spatial visibility has no substituted caster body owner")
    var after:Dictionary=Persistent.lifecycle_state(component,2.0)
    check(after.phase=="sustain","A held spatial owner survives beyond its finite application clip")
    check(rows[0].trace_track_id==component.id,"Studio track refers to the same production spatial occurrence")
    finish()
func finish()->void:
    print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Real spatial owner/clip/clock/membership binding; native visibility and first-use are separate"}));quit(0 if failures.is_empty() else 1)
