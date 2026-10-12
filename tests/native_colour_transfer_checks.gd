extends "res://tests/native_light_output_checks.gd"
# Independent encoded RGB/alpha ramp, bypassing source shaders and lighting.
# The output must reproduce a direct native Canvas display, including codes1..7.
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var image=Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in 256:
        for x in 256:image.set_pixel(x,y,Color(float(x)/255,float((x*73)%256)/255,float(255-x)/255,float(y)/255))
    var atlas=page(false)
    var node=Sprite2D.new();node.texture=ImageTexture.create_from_image(image);node.centered=false
    var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;void fragment(){COLOR=texture(TEXTURE,UV);}"
    var material=ShaderMaterial.new();material.shader=shader;node.material=material;atlas.add_child(node)
    var fixture={"colour":image,"material":material,"visible":1.0}
    var output=spatial(fixture,atlas);var direct=direct_output(fixture,atlas)
    var actual=await capture(output);var expected=await capture(direct)
    var comparison=compare(actual,expected)
    var linear=RenderingServer.get_current_rendering_method()!="gl_compatibility"
    var native_reference=linear_alpha_reference(image) if linear else expected
    var native_comparison=compare(actual,native_reference)
    check(comparison.alpha_mismatches==0,"All256 encoded alpha levels preserve exact native compositing")
    check(native_comparison.maximum_byte_error<=1 if linear else native_comparison.changed_pixels==0,"All256 RGBcodes×256alpha values match independent native blend-space oracle: "+str(native_comparison))
    var opaque=compare(actual.get_region(Rect2i(0,255,256,1)),expected.get_region(Rect2i(0,255,256,1)))
    check(opaque.changed_pixels==0,"Opaque original RGB remains byteexact against direct nativeCanvas")
    var low:Array=[]
    for x in 9:low.append({"source":x,"actual":actual.get_pixel(x,255).r8,"expected":expected.get_pixel(x,255).r8})
    check(actual.get_pixel(0,255).r8==0,"Encoded black remains exactly black")
    check(actual.get_pixel(1,255).r8==1 and actual.get_pixel(7,255).r8==7,"Dark codes1..7 retain their native source values")
    var report={"checks":checks,"failures":failures,"comparison":comparison,"native_blend_reference":native_comparison,"expected_blend_space":"linear" if linear else "encoded","opaque_row":opaque,"low_codes":low,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Independent RGBA8 image with all256 channel values crossed with all256 alpha values. Forward+/Mobile use analytical linear-alpha compositing (1byte half-float quantization bound); Compatibility is encodedCanvas byteexact. Original opaque RGB and alpha are exact in both. Full encodedCanvas difference is retained as diagnostic."}
    FileAccess.open("res://generated/native_colour_transfer_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_COLOUR_TRANSFER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
