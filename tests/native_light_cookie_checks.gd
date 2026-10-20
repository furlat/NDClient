extends SceneTree
## Preserve the previous native gradient artwork while eliminating duplicate
## occurrence-owned textures and repeated CPU reads after inactive gaps.
const Lights=preload("res://presentation/native_source_lights.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const LightCookies=preload("res://presentation/light_cookies.gd")
var checks:int=0
var failures:Array=[]
var raster_rows:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)

func original(attenuation:float)->GradientTexture2D:
    # Frozen original per-occurrence cookie, before immutable reuse. This is a
    # pixel parity control, not a new falloff definition or analytical oracle.
    var texture=GradientTexture2D.new()
    texture.width=256;texture.height=256;texture.fill=GradientTexture2D.FILL_RADIAL
    texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5);texture.gradient=Gradient.new()
    var offsets=PackedFloat32Array();var colours=PackedColorArray()
    for index in 65:
        var radius=float(index)/64.0
        var envelope=1.0-smoothstep(0.0,1.0,radius)
        var value=pow(envelope,1.0+maxf(0.0,attenuation))
        offsets.append(radius);colours.append(Color(value,value,value,1.0))
    texture.gradient.offsets=offsets;texture.gradient.colors=colours
    return texture

func ready_cookie(lights:RefCounted,attenuation:float)->Texture2D:
    var deadline:int=Time.get_ticks_msec()+10000
    var texture:Texture2D=lights._effect_cookie("fixture",attenuation)
    while texture==null and Time.get_ticks_msec()<deadline:
        await process_frame
        texture=lights._effect_cookie("fixture",attenuation)
    check(texture!=null,"Existing asynchronous cookie preparation completes for attenuation "+str(attenuation))
    return texture

func passive()->void:
    var lights=Lights.new()
    var first:Texture2D=await ready_cookie(lights,1.0)
    if first==null:lights.clear_pages();return
    var first_pixels:PackedByteArray=first.get_meta(&"cookie_image").get_data().duplicate()
    for id in 40:check(is_same(first,lights._effect_cookie(str(id),1.0)),"Identical attenuation shares immutable pixels across occurrences "+str(id))
    var changed:Texture2D=await ready_cookie(lights,.8)
    if changed==null:lights.clear_pages();return
    check(changed!=first and changed.get_rid()!=first.get_rid(),"An attenuation change has a new texture registration identity")
    check(first.get_meta(&"cookie_image").get_data()==first_pixels,"Changing another source cannot mutate the admitted cookie")
    check(is_same(first,lights._effect_cookie("first",1.0)),"Restoring attenuation reuses the exact prior image")
    var near:Texture2D=await ready_cookie(lights,1.000001)
    check(near!=first,"Attenuation keys are exact, without quantization")
    lights.effect_sources=[]
    for value in 24:
        lights.effect_sources.append({"native_attenuation":float(value)})
        await ready_cookie(lights,float(value))
    lights._trim_effect_cookies()
    for value in 24:check(lights._effect_cookies.has(float(value)),"Required active attenuation is never evicted "+str(value))
    lights.sample_handles({})
    lights.prepare_native_handles({})
    check(lights._effect_cookies.size()==lights.RETAINED_EFFECT_COOKIES,"Inactive native cookies have an exact bounded lifetime")
    var future_root:=Node3D.new();root.add_child(future_root)
    var future_light:=OmniLight3D.new();future_light.omni_attenuation=37.0;future_root.add_child(future_light)
    var future_handles:Dictionary={"received_future_occurrence":{"root":future_root}}
    var deadline:int=Time.get_ticks_msec()+10000
    while not lights.prepare_native_handles(future_handles) and Time.get_ticks_msec()<deadline:await process_frame
    check(lights.native_preparation_ready and lights._effect_cookies.has(37.0),"Prepared future occurrence owns its exact cookie before optical publication")
    for value in 12:await ready_cookie(lights,float(value)+50.0)
    lights.prepare_native_handles(future_handles)
    check(lights.effect_sources.is_empty() and lights._effect_cookies.has(37.0) and lights._effect_cookies.size()==lights.RETAINED_EFFECT_COOKIES+1,
        "Inactive trimming preserves the prepared future input in addition to the bounded reusable cache")
    lights.prepare_native_handles({})
    check(lights._effect_cookies.size()==lights.RETAINED_EFFECT_COOKIES,"Retiring the future occurrence returns its cookie to the same bounded cache")
    lights._effect_cookie("canceled_unfinished",99.0)
    var unfinished:Dictionary=lights._effect_cookies[99.0].cookie
    lights.clear_pages();check(lights._effect_cookies.is_empty(),"Page teardown releases retained native cookies")
    check(unfinished.task==-1,"Teardown joins its own unfinished cookie job without uploading a retired texture")
    future_root.queue_free();await process_frame
    var shadows=Shadows.new()
    # Shadows use the image a cookie carries and never read a texture back.
    check(shadows.cookie_image(GradientTexture2D.new())==null and not shadows.issues.is_empty(),"A cookie without its generated image is refused, never read back")
    var carried:=Image.create(4,4,false,Image.FORMAT_RGBA8);carried.fill(Color.WHITE)
    var texture:=ImageTexture.create_from_image(carried);texture.set_meta(&"cookie_image",carried)
    check(is_same(shadows.cookie_image(texture),carried),"A generated cookie's carried image is used as is")
    shadows.close()

func native_pixels()->void:
    var lights=Lights.new()
    # Four exact values occur in the selected native source metadata; include
    # additional boundary/changed values without rounding their native floats.
    for attenuation in [-0.280000001192093,0.0,0.800000011920929,1.0,1.13199996948242,2.0,5.0]:
        var before:GradientTexture2D=original(attenuation)
        var after:Texture2D=await ready_cookie(lights,attenuation)
        if after==null:continue
        await process_frame;await RenderingServer.frame_post_draw
        var old_image:Image=before.get_image();var new_image:Image=after.get_image()
        var equal:bool=old_image!=null and new_image!=null and old_image.get_data()==new_image.get_data()
        check(equal,"Full native cookie pixels equal the original at attenuation "+str(attenuation))
        raster_rows.append({"attenuation":attenuation,"byte_exact":equal})
    var jobs:Array=[LightCookies.start(original(1.0).gradient),LightCookies.start(original(.8).gradient)]
    var generated:Array=[null,null]
    while generated.has(null):
        await process_frame
        for i in jobs.size():generated[i]=LightCookies.texture(jobs[i])
    var first:Texture2D=generated[0];var changed:Texture2D=generated[1]
    var shadows=Shadows.new()
    check(shadows._prepare_cookies([first]) and is_same(shadows._cookie_images[first.get_rid()],first.get_meta(&"cookie_image")),"A generated cookie registers from its carried image")
    var before:PackedByteArray=shadows._cookie_texture.get_image().get_data()
    check(shadows._prepare_cookies([]) and shadows._prepare_cookies([first]),"A cookie can retire and return normally")
    check(shadows._cookie_texture.get_image().get_data()==before,"Repacked shadow-cookie pixels after a gap remain byte-exact")
    check(shadows._prepare_cookies([changed]),"Changed attenuation registers normally")
    check(shadows._cookie_images[changed.get_rid()].get_data()==changed.get_meta(&"cookie_image").get_data(),"Shadow receiving image matches the newly authored attenuation")
    check(shadows._cookie_texture.get_image().get_data()!=before,"Changed attenuation cannot reuse the prior shadow atlas pixels")
    shadows.close();lights.clear_pages()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(160,120);Engine.max_fps=120
    await passive()
    var native:bool=DisplayServer.get_name()!="headless"
    if native:await native_pixels()
    var report={"checks":checks,"failures":failures,"native_pixels":native,"raster":raster_rows,
        "scope":"Exact immutable cookie identity/attenuation, bounded inactive ownership, and (only native) original GradientTexture byte parity plus shadow registration from carried cookie images (no readback). Full frame-time improvement remains unmeasured."}
    FileAccess.open("res://.runtime/native-light-cookie-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_COOKIE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
