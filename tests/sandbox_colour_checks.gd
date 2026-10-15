extends SceneTree
## A native viewport's low-alpha edges must survive tinting and compositing.
const Colour=preload("res://sandbox/spell_colour.gdshader")
var failures:Array=[]
var checks=0
func check(value:bool,message:String)->void:
    checks+=1
    if not value:failures.append(message);push_error(message)
func _initialize()->void:run.call_deferred()
func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    var viewport=SubViewport.new()
    # Odd pixel width per source texel gives an exact centre despite filtering.
    viewport.size=Vector2i(170,16);viewport.transparent_bg=true
    viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var image=Image.create(10,1,false,Image.FORMAT_RGBA8)
    var alphas=[0.0,.01,.035,.1,.21,.5,.8,1.0]
    for i in alphas.size():image.set_pixel(i,0,Color(.8*alphas[i],.4*alphas[i],.2*alphas[i],alphas[i]))
    # Radiance may exceed coverage: an additive flare must not vanish or turn
    # into an opaque card when composed with native source-over materials.
    image.set_pixel(8,0,Color(.2,.4,.6,0))
    image.set_pixel(9,0,Color(.2,.4,.6,.1))
    var texture=ImageTexture.create_from_image(image)
    var rect=ColorRect.new();rect.size=viewport.size
    var material=ShaderMaterial.new();material.shader=Colour
    material.set_shader_parameter('native_colour',texture);rect.material=material;viewport.add_child(rect)
    var ramp=Image.create(2,1,false,Image.FORMAT_RGBA8)
    ramp.set_pixel(0,0,Color(0,.1,.2));ramp.set_pixel(1,0,Color(.3,.7,1))
    for tinted in [false,true]:
        material.set_shader_parameter('ramp_count',2 if tinted else 0)
        material.set_shader_parameter('ramp_texture',ImageTexture.create_from_image(ramp))
        for i in 3:
            await process_frame;await RenderingServer.frame_post_draw
        var output=viewport.get_texture().get_image()
        for i in image.get_width():
            var actual=output.get_pixel(i*17+8,8)
            check(absf(actual.a-image.get_pixel(i,0).a)<.015,'Tint %s: preserves native alpha %.3f, including soft export-cut edges'%[tinted,image.get_pixel(i,0).a])
            if not tinted:
                var expected=image.get_pixel(i,0)
                check(maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))<.02,'Native premultiplied RGB is not multiplied by alpha twice')
            if tinted and i>=8:
                check(actual.b>.45,'Palette retains additive radiance without introducing coverage')
            if i==0:check(actual.r==0 and actual.g==0 and actual.b==0,'Empty transparent viewport remains empty after palette lookup')
    var report={'checks':checks,'failures':failures}
    FileAccess.open('res://generated/sandbox_colour_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_COLOUR_CHECKS ',JSON.stringify(report));quit(0 if failures.is_empty() else 1)
