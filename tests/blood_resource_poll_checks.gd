extends SceneTree
## Blood shader programs warm one per frame through their real admission; a
## passive zero-allowance poll then acknowledges readiness.
const BloodRenderer=preload("res://presentation/blood_renderer.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
class Host extends Node3D:
    var source_lighting=Lighting.new()
    var actor_entries:Array=[]
    var draw_order_dirty:bool=false
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BLOOD_RESOURCE_POLL_FAIL ",label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw
func run()->void:
    create_timer(20).timeout.connect(func():printerr("Blood resource poll deadline");quit(2))
    var host=Host.new();root.add_child(host)
    var renderer=BloodRenderer.new()
    # Warm each actual shader through its real admission path; no static count
    # or fake readiness is installed.
    var attempts:int=0
    var programs:int=BloodRenderer.PROGRAMS.size()
    while BloodRenderer._programs_prepared<programs and attempts<16:
        var before:int=BloodRenderer._programs_prepared
        renderer.prepare_resources(host,{"used_usec":0,"limit_usec":10000})
        check(BloodRenderer._programs_prepared>=before and BloodRenderer._programs_prepared<=before+1,"Actual shader admission advances at most one authored program per frame")
        attempts+=1;await frame()
    check(BloodRenderer._programs_prepared==programs,"All three admission steps (kernel and field copy, surface, droplet) warm their actual programs")
    if BloodRenderer._programs_prepared!=programs:host.queue_free();quit(1);return
    # Blood lights itself from the light table: once its programs are warm,
    # a passive poll acknowledges readiness without constructors or budget.
    var settled={"used_usec":0,"limit_usec":0}
    check(renderer.prepare_resources(host,settled) and renderer.resources_ready,"Passive polling acknowledges warmed programs without constructor allowance")
    check(settled.used_usec==0 and host.actor_entries.is_empty() and host.find_children("*","SubViewport",true,false).is_empty(),"Preparation invents no displayed residue, receiving viewport or budget use")
    renderer.close(host);host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Real three-step shader admission and zero-budget readiness poll; no gameplay performance claim."}
    FileAccess.open("res://.runtime/blood-resource-poll-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_RESOURCE_POLL_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
