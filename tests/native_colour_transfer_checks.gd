extends "res://tests/native_light_output_checks.gd"
# Independent encoded RGB/alpha ramp through the lit sprites' unlit transfer
# (the flame/shadow path: stored byte or half, decoded, spatial output), with the
# light cap off and on. The output must reproduce a direct native Canvas display
# of the same image, including codes1..7.
const Flame=preload("res://presentation/fixture_flame.gdshader")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var image=Image.create(256,256,false,Image.FORMAT_RGBA8)
    for y in 256:
        for x in 256:image.set_pixel(x,y,Color(float(x)/255,float((x*73)%256)/255,float(255-x)/255,float(y)/255))
    # Direct native Canvas display of the original image.
    var canvas=page(false,null,Vector2i(256,256))
    var node=Sprite2D.new();node.texture=ImageTexture.create_from_image(image);node.centered=false
    var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded;void fragment(){COLOR=texture(TEXTURE,UV);}"
    var direct_material=ShaderMaterial.new();direct_material.shader=shader;node.material=direct_material;canvas.add_child(node)
    var expected=await capture(canvas)
    var frames=Texture2DArray.new();var layers:Array[Image]=[image];frames.create_from_images(layers)
    var material=ShaderMaterial.new();material.shader=Flame;material.set_shader_parameter("frames",frames)
    var fixture={"colour":image,"material":material,"visible":1.0,"basis":Basis.IDENTITY,"mirror":false}
    var linear=RenderingServer.get_current_rendering_method()!="gl_compatibility"
    var native_reference=linear_alpha_reference(image) if linear else expected
    var rows:Dictionary={}
    for cap in [0.0,1.0]:
        var mode:String="cap" if cap>0.0 else "ldr"
        var actual:Image=await lit_receiving(fixture,[],true,1.0,cap)
        var comparison=compare(actual,expected)
        var native_comparison=compare(actual,native_reference)
        check(comparison.alpha_mismatches==0,mode+": all256 encoded alpha levels preserve exact native compositing: "+str(comparison))
        check(native_comparison.maximum_byte_error<=1 if linear else native_comparison.changed_pixels==0,mode+": all256 RGBcodes×256alpha values match independent native blend-space oracle: "+str(native_comparison))
        var opaque=compare(actual.get_region(Rect2i(0,255,256,1)),expected.get_region(Rect2i(0,255,256,1)))
        check(opaque.changed_pixels==0,mode+": opaque original RGB remains byteexact against direct nativeCanvas")
        var low:Array=[]
        for x in 9:low.append({"source":x,"actual":actual.get_pixel(x,255).r8,"expected":expected.get_pixel(x,255).r8})
        check(actual.get_pixel(0,255).r8==0,mode+": encoded black remains exactly black")
        check(actual.get_pixel(1,255).r8==1 and actual.get_pixel(7,255).r8==7,mode+": dark codes1..7 retain their native source values")
        rows[mode]={"comparison":comparison,"native_blend_reference":native_comparison,"opaque_row":opaque,"low_codes":low}
    var report={"checks":checks,"failures":failures,"modes":rows,"expected_blend_space":"linear" if linear else "encoded","renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Independent RGBA8 image with all256 channel values crossed with all256 alpha values through the lit sprites' unlit storage/decode (presentation/fixture_flame.gdshader), light cap off (byte storage) and on (half storage). Forward+/Mobile use analytical linear-alpha compositing (1byte half-float quantization bound). Original opaque RGB and alpha are exact. Full encodedCanvas difference is retained as diagnostic."}
    FileAccess.open("res://generated/native_colour_transfer_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_COLOUR_TRANSFER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
