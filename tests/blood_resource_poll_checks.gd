extends SceneTree
## A passive zero-allowance world poll cannot consume the actual native page
## constructor's frame admission. Uses the real shaders and receiving pages.
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
    # or fake readiness is installed to reach the receiving-page boundary.
    var attempts:int=0
    while BloodRenderer._programs_prepared<4 and attempts<16:
        var before:int=BloodRenderer._programs_prepared
        renderer.prepare_resources(host,{"used_usec":0,"limit_usec":10000})
        check(BloodRenderer._programs_prepared>=before and BloodRenderer._programs_prepared<=before+1,"Actual shader admission advances at most one authored program per frame")
        attempts+=1;await frame()
    check(BloodRenderer._programs_prepared==4 and renderer.pages.is_empty(),"All four actual shader programs warm before any receiving-page constructor")
    if BloodRenderer._programs_prepared!=4:host.queue_free();quit(1);return
    for name in ["floor","air"]:
        var previous:int=renderer.resource_frame
        var before_count:int=renderer.pages.size()
        var zero={"used_usec":0,"limit_usec":0}
        check(not renderer.prepare_resources(host,zero),"Passive poll waits for missing "+name+" page")
        check(renderer.resource_frame==previous and renderer.pages.size()==before_count and zero.used_usec==0,"Zero allowance consumes no "+name+" constructor admission, budget or native page")
        var same_frame:int=Engine.get_process_frames()
        var allowed={"used_usec":0,"limit_usec":10000}
        check(not renderer.prepare_resources(host,allowed),"New "+name+" page still waits for its actual first draw")
        check(renderer.pages.has(name) and renderer.pages.size()==before_count+1 and renderer.resource_frame==same_frame,"Positive allowance in the SAME frame constructs exact "+name+" receiving page")
        var view:SubViewport=renderer.pages[name].view
        renderer.prepare_resources(host,{"used_usec":0,"limit_usec":10000})
        check(is_same(renderer.pages[name].view,view) and renderer.pages.size()==before_count+1,"Repeated same-frame preparation neither reconstructs nor admits another receiving page")
        await frame()
        check(renderer.pages[name].ready,"Real post-draw fence completes "+name+" page readiness")
    var settled={"used_usec":0,"limit_usec":0}
    check(renderer.prepare_resources(host,settled) and renderer.resources_ready and renderer.pages.size()==2,"Passive polling can acknowledge both completed pages without constructor allowance")
    check(settled.used_usec==0 and host.actor_entries.is_empty(),"Page preparation invents no displayed residue and consumes no budget after completion")
    renderer.close(host);host.queue_free();await process_frame;await process_frame
    var report={"checks":checks,"failures":failures,"scope":"Real four-shader admission and floor/air first draws, zero-budget poll followed by same-frame positive constructor admission; no gameplay performance claim."}
    FileAccess.open("res://.runtime/blood-resource-poll-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_RESOURCE_POLL_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
