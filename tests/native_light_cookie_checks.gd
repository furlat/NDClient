extends SceneTree
## Preserve the previous native gradient artwork while eliminating duplicate
## occurrence-owned textures and repeated CPU reads after inactive gaps.
const Lights=preload("res://presentation/native_source_lights.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
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

func passive()->void:
    var lights=Lights.new()
    var first:GradientTexture2D=lights._effect_cookie("first",1.0)
    var first_colours:PackedColorArray=first.gradient.colors.duplicate()
    for id in 40:check(is_same(first,lights._effect_cookie(str(id),1.0)),"Identical attenuation shares immutable pixels across occurrences "+str(id))
    var changed:GradientTexture2D=lights._effect_cookie("first",.8)
    check(changed!=first and changed.get_rid()!=first.get_rid(),"An attenuation change has a new texture registration identity")
    check(first.gradient.colors==first_colours,"Changing another source cannot mutate the admitted cookie")
    check(is_same(first,lights._effect_cookie("first",1.0)),"Restoring attenuation reuses the exact prior image")
    var near:GradientTexture2D=lights._effect_cookie("first",1.000001)
    check(near!=first,"Attenuation keys are exact, without quantization")
    lights.effect_sources=[]
    for value in 24:
        lights.effect_sources.append({"native_attenuation":float(value)})
        lights._effect_cookie(str(value),float(value))
    lights._trim_effect_cookies()
    for value in 24:check(lights._effect_cookies.has(float(value)),"Required active attenuation is never evicted "+str(value))
    lights.sample_handles({})
    check(lights._effect_cookies.size()==lights.RETAINED_EFFECT_COOKIES,"Inactive native cookies have an exact bounded lifetime")
    lights.clear_pages();check(lights._effect_cookies.is_empty(),"Page teardown releases retained native cookies")
    var shadows=Shadows.new();var owners:Array=[]
    # Passive memory fixture exercises the real inactive retention bounds. No
    # image readback or native pixel claim is made in this part of the test.
    for i in 24:
        var texture=GradientTexture2D.new();owners.append(texture)
        shadows._retained_cookies[texture.get_rid()]={"texture":texture,"image":Image.create(1,1,false,Image.FORMAT_RGBA8),"bytes":4,"used":i}
    var active:Dictionary={owners[0].get_rid():true}
    shadows._trim_cookie_images(active)
    check(shadows._retained_cookies.size()==Shadows.RETAINED_COOKIE_IMAGES+1,"Inactive shadow-image count is bounded independently of active images")
    check(shadows._retained_cookies.has(owners[0].get_rid()),"Old active image is protected from LRU eviction")
    check(not shadows._retained_cookies.has(owners[1].get_rid()) and shadows._retained_cookies.has(owners[-1].get_rid()),"Oldest inactive image retires first")
    for record in shadows._retained_cookies.values():record.bytes=1024*1024
    shadows._trim_cookie_images(active)
    check(shadows._retained_cookies.size()==5,"Inactive CPU-image bytes are bounded, not only object count")
    shadows.close();check(shadows._retained_cookies.is_empty(),"Shadow teardown drops all retained texture/image owners")

func native_pixels()->void:
    var lights=Lights.new()
    # Four exact values occur in the selected native source metadata; include
    # additional boundary/changed values without rounding their native floats.
    for attenuation in [-0.280000001192093,0.0,0.800000011920929,1.0,1.13199996948242,2.0,5.0]:
        var before:GradientTexture2D=original(attenuation)
        var after:GradientTexture2D=lights._effect_cookie("fixture",attenuation)
        await process_frame;await RenderingServer.frame_post_draw
        var old_image:Image=before.get_image();var new_image:Image=after.get_image()
        var equal:bool=old_image!=null and new_image!=null and old_image.get_data()==new_image.get_data()
        check(equal,"Full native cookie pixels equal the original at attenuation "+str(attenuation))
        raster_rows.append({"attenuation":attenuation,"byte_exact":equal})
    var first:GradientTexture2D=lights._effect_cookie("one",1.0)
    var second:GradientTexture2D=lights._effect_cookie("two",1.0)
    var changed:GradientTexture2D=lights._effect_cookie("one",.8)
    await process_frame;await RenderingServer.frame_post_draw
    var shadows=Shadows.new()
    check(shadows._prepare_cookies([{"texture":first},{"texture":second}]),"Two identical light cookies register")
    check(shadows._last_counts.get("cookie_reads",0)==1 and shadows._cookie_rects.size()==1,"One cold readback for shared immutable artwork")
    var before:PackedByteArray=shadows._cookie_texture.get_image().get_data()
    shadows._last_counts={}
    check(shadows._prepare_cookies([]) and shadows._prepare_cookies([{"texture":first}]),"A cookie can retire and return normally")
    check(shadows._last_counts.get("cookie_reads",0)==0 and shadows._last_counts.get("cookie_cache_hits",0)==1,"Returning cookie reuses its exact retained CPU image")
    check(shadows._cookie_texture.get_image().get_data()==before,"Repacked shadow-cookie pixels after a gap remain byte-exact")
    shadows._last_counts={}
    check(shadows._prepare_cookies([{"texture":changed}]),"Changed attenuation registers normally")
    check(shadows._last_counts.get("cookie_reads",0)==1,"Changed attenuation performs its required fresh readback")
    var changed_image:Image=changed.get_image();changed_image.convert(Image.FORMAT_RGBA8)
    check(shadows._cookie_images[changed.get_rid()].get_data()==changed_image.get_data(),"Shadow receiving image matches the newly authored attenuation")
    check(shadows._cookie_texture.get_image().get_data()!=before,"Changed attenuation cannot reuse the prior shadow atlas pixels")
    shadows.close();lights.clear_pages()

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(160,120);Engine.max_fps=120
    passive()
    var native:bool=DisplayServer.get_name()!="headless"
    if native:await native_pixels()
    var report={"checks":checks,"failures":failures,"native_pixels":native,"raster":raster_rows,
        "scope":"Exact immutable cookie identity/attenuation, bounded inactive ownership, and (only native) original GradientTexture byte parity plus shadow readback/registration parity. Full frame-time improvement remains unmeasured."}
    FileAccess.open("res://.runtime/native-light-cookie-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_COOKIE ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
