extends SceneTree
## Exact native GradientTexture pixels, prepared without publishing lights.
const Lighting=preload("res://presentation/lighting_2d.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const Preparation=preload("res://presentation/world_preparation.gd")
class Host extends Node3D:
    var source_lighting=Lighting.new()
    var generated_shadows=Shadows.new()
var checks:int=0
var failures:Array=[]
var measurements:Array=[]
func _initialize()->void:run.call_deferred()
func timeout()->void:
    printerr("Native cookie preparation fixture exceeded its finite deadline")
    quit(1)
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func source(very:float,bright:float,outer:float)->Dictionary:
    return {"very_bright_radius_feet":very*5.0,"bright_radius_feet":bright*5.0,"outer":outer}
func pixels(texture:Texture2D)->PackedByteArray:
    var image:Image=texture.get_image().duplicate()
    if image.is_compressed():image.decompress()
    image.convert(Image.FORMAT_RGBA8)
    return image.get_data()
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    create_timer(8.0).timeout.connect(timeout)
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(160,120);Engine.max_fps=120
    var host=Host.new();root.add_child(host)
    var prepare=Preparation.new();root.add_child(prepare);prepare.host=host
    prepare.result={"light_sources":[source(0,4,8),source(0,4,8),source(2,4,8)]}
    for index in prepare.result.light_sources.size():prepare._prepare_cookie_resource()
    check(prepare.cookie_jobs.size()==2,"Only distinct native cookie resources require preparation")
    check(host.source_lighting.sources.is_empty() and host.source_lighting.nodes.is_empty(),"Resource preparation publishes no source or native light node")
    check(host.source_lighting.canvas_sources().is_empty(),"Resource preparation publishes no camera projection")
    check(host.generated_shadows._cookie_texture==null and host.generated_shadows._cookie_images.is_empty(),"Future preparation does not publish a shadow atlas")
    prepare._finish_preparation()
    check(not prepare.prepared and prepare.phase=="cookie_images","Missing exact images keep the existing boundary preparation pending")
    prepare.step()
    check(prepare.cookie_image_cursor==0,"Native cookie read waits for a completed draw")
    await process_frame;await RenderingServer.frame_post_draw
    for job in prepare.cookie_jobs:check(job.drawn,"Native renderer completed each newly created resource")
    var deadline:int=Time.get_ticks_msec()+3000
    while not prepare.prepared and prepare.media_issue.is_empty() and Time.get_ticks_msec()<deadline:
        await process_frame
        var started:int=Time.get_ticks_usec();prepare.step()
        measurements.append((Time.get_ticks_usec()-started)/1000.0)
    check(prepare.prepared and prepare.media_issue.is_empty(),"Existing bounded preparation reaches ready")
    var first:Texture2D=prepare.cookie_jobs[0].texture
    var second:Texture2D=prepare.cookie_jobs[1].texture
    for texture in [first,second]:
        check(host.generated_shadows.cookie_prepared(texture),"Prepared resource retains its exact owner")
        if host.generated_shadows.cookie_prepared(texture):
            check(host.generated_shadows._retained_cookies[texture.get_rid()].image.get_data()==pixels(texture),"Prepared CPU bytes equal original native GradientTexture bytes")
    check(host.generated_shadows._cookie_texture==null and host.generated_shadows._sources.is_empty(),"Ready preparation still exposes no future light/shadow state")
    var reference=Shadows.new()
    check(reference._prepare_cookies([{"texture":first},{"texture":second}]),"Original cold cookie registration succeeds")
    host.generated_shadows._last_counts={}
    check(host.generated_shadows._prepare_cookies([{"texture":first},{"texture":second}]),"Prepared cookie registration succeeds")
    check(host.generated_shadows._last_counts.get("cookie_reads",0)==0,"Actual registration performs zero native image reads after preparation")
    check(host.generated_shadows._cookie_texture.get_image().get_data()==reference._cookie_texture.get_image().get_data(),"Complete published cookie atlas is byte-exact against cold registration")
    var repeated=Preparation.new();root.add_child(repeated);repeated.host=host;repeated.result=prepare.result
    for index in repeated.result.light_sources.size():repeated._prepare_cookie_resource()
    repeated._finish_preparation()
    check(repeated.prepared and repeated.cookie_jobs.is_empty(),"An unchanged boundary adds no draw fence or image work")
    # A retained RID entry is never sufficient without the exact texture owner.
    host.generated_shadows._retained_cookies[first.get_rid()].texture=second
    check(not host.generated_shadows.cookie_prepared(first),"Mismatched texture owner cannot admit a cached image")
    host.generated_shadows._last_counts={}
    check(host.generated_shadows.prepare_cookie(first),"A mismatched owner is freshly prepared")
    check(host.generated_shadows._last_counts.get("cookie_reads",0)==1,"Owner mismatch performs the required exact fresh read")
    var cancelled=Preparation.new();root.add_child(cancelled);cancelled.host=host
    cancelled.result={"light_sources":[source(1,3,7)]};cancelled._prepare_cookie_resource();cancelled.free()
    await process_frame;await RenderingServer.frame_post_draw
    check(host.source_lighting.sources.is_empty() and host.source_lighting.nodes.is_empty(),"Cancelling an unpublished boundary cannot create lights")
    reference.close();host.generated_shadows.close()
    check(host.generated_shadows._retained_cookies.is_empty(),"World teardown releases prepared image owners")
    prepare.free();repeated.free();host.free()
    var report={"checks":checks,"failures":failures,"prepare_step_ms":measurements,"scope":"Native ratio cookies only: exact original bytes and packed shadow atlas, post-draw read fence, no future source publication, repeated boundary no-op, owner mismatch, cancellation and teardown. Overall reveal latency is a separate real-play measurement."}
    FileAccess.open("res://.runtime/native-world-cookie-preparation-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("WORLD_COOKIE_PREPARATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
