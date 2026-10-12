extends "res://tests/native_light_output_checks.gd"
# Current HDR white receiving is tested against independent OLD LDR native
# Canvas receiving, never another HDR fixture. Actual artwork is not copied.
const OldOutput=preload("res://tests/fixtures/light_cap_ldr_542303f/canvas_received.gdshader")
const Atlas=preload("res://presentation/native_light_atlas.gd")
const OldFlame=preload("res://tests/fixtures/light_cap_ldr_542303f/canvas_fixture_flame.gdshader")
const OldWater=preload("res://tests/fixtures/light_cap_ldr_542303f/canvas_water.gdshader")
var cap_cases:Array=[]
var cap_shaders:Dictionary={}
const HDR_ORIGINAL_OUTPUT='''shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,depth_draw_never,depth_test_disabled;
uniform sampler2D received:filter_nearest,repeat_disable;
uniform vec4 atlas_region;
uniform float wall_opacity=1.0;
void fragment(){
    vec4 c=texture(received,atlas_region.xy+UV*atlas_region.zw);
    if(c.a<=0.0)discard;
    vec3 encoded=clamp(c.rgb,vec3(0.0),vec3(1.0));
    ALBEDO=mix(pow((encoded+vec3(.055))/1.055,vec3(2.4)),encoded/12.92,lessThanEqual(encoded,vec3(.04045)));
    ALPHA=c.a*wall_opacity;
}'''
var original_hdr_output:Shader

func copy_source(source:ShaderMaterial,destination:ShaderMaterial)->void:
    var accepted={}
    for uniform in destination.shader.get_shader_uniform_list():accepted[uniform.name]=true
    for uniform in source.shader.get_shader_uniform_list():
        if accepted.has(uniform.name):destination.set_shader_parameter(uniform.name,source.get_shader_parameter(uniform.name))

func native_sources(view:SubViewport,fixture:Dictionary,count:int,spectrum:String,energy:float,height:float=56.0,reverse:bool=false)->void:
    var order=range(count)
    if reverse:order.reverse()
    var size=Vector2(fixture.colour.get_size())
    for i in order:
        var light=PointLight2D.new();light.texture=cookie;light.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        light.position=size*Vector2(.40+(i%2)*.18,.45+(i%3)*.07)
        light.height=height;light.texture_scale=800.0/cookie.get_width();light.energy=energy
        light.color=Color(.809372,.429306,.269121) if spectrum=="warm" or i%2==0 else Color(.17,.62,.91)
        view.add_child(light)

func native_receiver(fixture:Dictionary,count:int,spectrum:String,energy:float,hdr:bool,independent:bool=false,raw:bool=false,height:float=56.0,reverse:bool=false,debug:bool=false)->SubViewport:
    var view=page(false);view.use_hdr_2d=hdr
    var ambient=Color.WHITE if raw else Color(.176419,.176419,.176419,1)
    view.get_child(0).color=ambient.linear_to_srgb() if hdr else ambient
    var size:Vector2i=fixture.colour.get_size()
    var material:ShaderMaterial=fixture.material.duplicate()
    if independent and fixture.family in ["modular","environment"]:
        material=ShaderMaterial.new();material.shader=reference_shader
        material.set_shader_parameter("original",ImageTexture.create_from_image(fixture.colour))
        material.set_shader_parameter("decoded_normals",ImageTexture.create_from_image(fixture.normals))
        material.set_shader_parameter("source_origin",Vector2.ZERO)
        material.set_shader_parameter("source_inverse",Vector4(1.0/size.x,0,0,1.0/size.y))
        material.set_shader_parameter("tint",fixture.tint);material.set_shader_parameter("visible_now",fixture.visible)
        sprite(view,material,Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO))
    else:
        if independent and fixture.family=="water":material.shader=OldWater
        if independent and fixture.family=="flame":material.shader=OldFlame
        if debug:
            var shader=Shader.new()
            shader.code="#define SHOW_SOURCE_NORMALS\n"+material.shader.code.replace('#include "','#include "res://presentation/').replace("blend_disabled;","blend_disabled, unshaded;")
            material.shader=shader
        material.set_shader_parameter("store_irradiance",hdr and not independent and not debug and fixture.family in ["modular","environment","water"])
        material.set_shader_parameter("source_crop",Vector4(0,0,1,1));material.set_shader_parameter("atlas_cell_size",Vector2(size))
        material.set_shader_parameter("receiver_visibility",fixture.visible);material.set_shader_parameter("actual_scene_viewport_size",Vector2(size))
        material.set_shader_parameter("receiver_world_origin",Vector3.ZERO)
        var node=sprite(view,material,Transform2D.IDENTITY)
        node.region_enabled=true;node.region_rect=Rect2(0,0,size.x,size.y);node.region_filter_clip_enabled=false
    native_sources(view,fixture,count,spectrum,energy,height,reverse)
    return view

func output_view(fixture:Dictionary,received:SubViewport,cap:float,old:bool=false,opacity:float=1.0,bypass:bool=false,hdr_original:bool=false)->SubViewport:
    var size:Vector2i=fixture.colour.get_size()
    var view=SubViewport.new();view.size=size;view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0);view.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;camera.position=Vector3(0,0,3);view.add_child(camera)
    var material=ShaderMaterial.new()
    material.shader=original_hdr_output if hdr_original else OldOutput if old else PassThrough if bypass or cap<=0 else cap_shaders[fixture.family]
    copy_source(fixture.material,material)
    material.set_shader_parameter("received",received.get_texture());material.set_shader_parameter("atlas_region",Vector4(0,0,float(size.x)/512,float(size.y)/512))
    material.set_shader_parameter("source_crop",Vector4(0,0,1,1));material.set_shader_parameter("current_visibility",fixture.visible)
    material.set_shader_parameter("wall_opacity",opacity);material.set_shader_parameter("light_cap",cap);material.set_shader_parameter("source_quad_size",Vector2(2,2))
    material.set_shader_parameter("received_is_encoded_hdr",received.use_hdr_2d and bypass)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2);node.material_override=material;view.add_child(node)
    return view

func scalar_oracle(source:Image,field:Image,alpha_reference:Image)->Dictionary:
    var expected=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
    var over=0;var maximum=0.0;var black=0
    for y in source.get_height():
        for x in source.get_width():
            var colour=source.get_pixel(x,y);var light=field.get_pixel(x,y)
            var peak=maxf(light.r,maxf(light.g,light.b));maximum=maxf(maximum,peak)
            var scale=1.0/maxf(1.0,peak)
            var encoded=Color(colour.r*light.r*scale,colour.g*light.g*scale,colour.b*light.b*scale,colour.a)
            encoded=Color8(roundi(encoded.r*255),roundi(encoded.g*255),roundi(encoded.b*255),colour.a8)
            var linear=encoded.srgb_to_linear();linear.r*=light.a;linear.g*=light.a;linear.b*=light.a
            var pixel=linear.linear_to_srgb()
            # Image.set_pixel(RGBA8, floatColour) truncates; native UNORM and
            # the final framebuffer round. Quantize explicitly so the CPU
            # reference does not add a systematic extra one-byte dark bias.
            expected.set_pixel(x,y,Color8(roundi(pixel.r*255),roundi(pixel.g*255),roundi(pixel.b*255),alpha_reference.get_pixel(x,y).a8))
            if colour.a>0 and peak>1.0:over+=1
            if colour.a>0 and colour.r==0 and colour.g==0 and colour.b==0:black+=1
    return {"expected":expected,"over_cap_pixels":over,"maximum_native_irradiance":maximum,"opaque_source_black_pixels":black}

func alpha_bounds(a:Image,b:Image)->Dictionary:
    var maximum=0;var coverage=0
    for y in a.get_height():
        for x in a.get_width():
            var first=a.get_pixel(x,y).a8;var second=b.get_pixel(x,y).a8
            maximum=maxi(maximum,absi(first-second))
            if (first==0)!=(second==0):coverage+=1
    return {"maximum_byte_error":maximum,"coverage_changes":coverage}

func alpha_trace(old:Image,field:Image,before:Image,after:Image,raw:Image)->Array:
    var result:Array=[]
    for y in before.get_height():
        for x in before.get_width():
            if before.get_pixel(x,y).a8!=after.get_pixel(x,y).a8:
                result.append({"x":x,"y":y,"raw_source_alpha":raw.get_pixel(x,y).a,"old_atlas":old.get_pixel(x,y).a,"hdr_atlas":field.get_pixel(x,y).a,"old_final":before.get_pixel(x,y).a8,"new_final":after.get_pixel(x,y).a8})
                if result.size()==12:return result
    return result

func dispose(views:Array)->void:
    for view in views:view.queue_free()
    await process_frame

func overlap_matrix(fixture:Dictionary)->void:
    var raw=native_receiver(fixture,0,"warm",0,false,true,true)
    var source=(await capture(raw)).get_region(Rect2i(Vector2i.ZERO,fixture.colour.get_size()))
    # The analytic formula needs original fractional tint/style, not already
    # quantized LDR albedo. Decode those directly from original bytes. Water's
    # unchanged native graph is sampled separately before byte quantization;
    # oldLDR remains the independent appearance/alpha baseline for every case.
    var floating_source:Image
    var raw_source_alpha:Image
    if fixture.family=="water":
        var raw_view=native_receiver(fixture,0,"warm",0,true,true,true)
        floating_source=(await capture(raw_view)).get_region(Rect2i(Vector2i.ZERO,fixture.colour.get_size()))
        raw_source_alpha=floating_source.duplicate();floating_source.convert(Image.FORMAT_RGBAF);raw_view.queue_free()
    else:
        floating_source=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBAF)
        raw_source_alpha=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBAF)
    for y in source.get_height():
        for x in source.get_width():
            var value:Color
            if fixture.family=="water":value=floating_source.get_pixel(x,y)
            else:
                value=fixture.colour.get_pixel(x,y)*fixture.tint
                if fixture.family=="environment":
                    var grey=value.r*.2126+value.g*.7152+value.b*.0722
                    var remembered=Color(lerpf(grey,value.r,.35)*.62,lerpf(grey,value.g,.35)*.62,lerpf(grey,value.b,.35)*.62,value.a)
                    value=remembered.lerp(value,fixture.visible)
                raw_source_alpha.set_pixel(x,y,value)
            value.a=source.get_pixel(x,y).a;floating_source.set_pixel(x,y,value)
    raw.queue_free()
    for spectrum in ["warm","mixed"]:
        for count in [0,1,2,8]:
            var energy=0.2 if count<=1 else 3.0
            var old=native_receiver(fixture,count,spectrum,energy,false,true)
            var native=native_receiver(fixture,count,spectrum,energy,true)
            var native_original=native_receiver(fixture,count,spectrum,energy,true,true)
            var original_hdr=output_view(fixture,native_original,0,false,1,false,true)
            var native_alpha_reference=await capture(original_hdr)
            var before=output_view(fixture,old,0,true)
            var after=output_view(fixture,native,1)
            var original=await capture(before);var actual=await capture(after)
            var field=(await capture(native)).get_region(Rect2i(Vector2i.ZERO,fixture.colour.get_size()))
            if count==0 and spectrum=="warm":
                source.save_png("res://.captures/native-light-cap/"+fixture.family+"-old-source.png")
                floating_source.save_exr("res://.captures/native-light-cap/"+fixture.family+"-source.exr")
                field.save_exr("res://.captures/native-light-cap/"+fixture.family+"-field.exr")
                original.save_png("res://.captures/native-light-cap/"+fixture.family+"-ambient-before.png")
                actual.save_png("res://.captures/native-light-cap/"+fixture.family+"-ambient-after.png")
            var alpha_examples=alpha_trace(source,field,original,actual,raw_source_alpha) if count==0 else []
            var oracle=scalar_oracle(floating_source,field,native_alpha_reference);var formula=compare(actual,oracle.expected)
            var baseline=compare(actual,original)
            var black_errors=0
            for y in source.get_height():
                for x in source.get_width():
                    var pixel=source.get_pixel(x,y)
                    if pixel.a>0 and pixel.r==0 and pixel.g==0 and pixel.b==0:
                        var result=actual.get_pixel(x,y)
                        if result.r8!=0 or result.g8!=0 or result.b8!=0:black_errors+=1
            var label=fixture.id+" "+spectrum+" "+str(count)+" lights"
            check(black_errors==0,label+" exact black source pixels stay black")
            var native_alpha=compare(actual,native_alpha_reference).alpha_mismatches
            var storage_alpha=alpha_bounds(original,native_alpha_reference)
            check(native_alpha==0,label+" alpha exactly matches uncapped original-source nativeHDR")
            check(storage_alpha.maximum_byte_error<=1 and storage_alpha.coverage_changes==0,label+" nativeHDR versus oldLDR alpha storage bound and exact coverage: "+str(storage_alpha))
            check(formula.alpha_mismatches==0 and formula.maximum_byte_error<=1,label+" matches independent max-channel scalar illumination cap: "+str(formula))
            if count<=1:
                check(oracle.over_cap_pixels==0,label+" is actually below the ceiling")
                check(baseline.maximum_byte_error<=1,label+" preserves independent oldLDR appearance below cap: "+str(baseline))
            else:
                check(oracle.over_cap_pixels>0,label+" exercises genuinely accumulated HDR illumination above1")
                check(baseline.changed_pixels>0,label+" visibly limits excessive native accumulation")
            var reverse=native_receiver(fixture,count,spectrum,energy,true,false,false,56,true)
            var reversed_output=output_view(fixture,reverse,1)
            var ordering=compare(actual,await capture(reversed_output))
            check(ordering.alpha_mismatches==0 and ordering.maximum_byte_error<=1,label+" native insertion order changes at most half-float rounding: "+str(ordering))
            # Return the same receiver from HDR to original LDR, exactly as the
            # setting does; no new simulated lighting formula is involved.
            native.use_hdr_2d=false;native.get_child(0).color=Color(.176419,.176419,.176419,1)
            native.get_child(1).material.set_shader_parameter("store_irradiance",false)
            var restored=output_view(fixture,native,0)
            var restored_image=await capture(restored)
            var off=compare(restored_image,original)
            check(off.alpha_mismatches==0 and off.maximum_byte_error<=1,label+" toggle off restores independent native LDR baseline: "+str(off))
            cap_cases.append({"id":label,"alpha_examples":alpha_examples,"native_hdr_alpha_mismatches":native_alpha,"native_hdr_vs_ldr_alpha":storage_alpha,"baseline":baseline,"scalar_oracle":formula,"native_peak":oracle.maximum_native_irradiance,"over_cap_pixels":oracle.over_cap_pixels,"order":ordering,"toggle_off":off})
            if count==8 and spectrum=="warm":
                original.save_png("res://.captures/native-light-cap/"+fixture.family+"-before.png");actual.save_png("res://.captures/native-light-cap/"+fixture.family+"-capped.png")
            await dispose([old,native,native_original,original_hdr,before,after,reverse,reversed_output,restored])

func secondary_cases(body:Dictionary,wall:Dictionary)->void:
    var a=native_receiver(body,1,"warm",.2,true,false,false,20)
    var b=native_receiver(body,1,"warm",.2,true,false,false,56)
    var ao=output_view(body,a,1);var bo=output_view(body,b,1)
    var response=compare(await capture(ao),await capture(bo))
    check(response.changed_pixels>10 and response.alpha_mismatches==0,"Native authored normal/height response remains visible below cap")
    cap_cases.append({"id":"height20-vs56","comparison":response})
    await dispose([a,b,ao,bo])
    for opacity in [0.0,.28,1.0]:
        var old=native_receiver(wall,8,"mixed",3,false,true)
        var native=native_receiver(wall,8,"mixed",3,true)
        var reference=native_receiver(wall,8,"mixed",3,true,true)
        var before=output_view(wall,reference,0,false,opacity,false,true);var after=output_view(wall,native,1,false,opacity)
        var comparison=compare(await capture(before),await capture(after))
        check(comparison.alpha_mismatches==0,"Whole-wall opacity"+str(opacity)+" stays exact across cap")
        await dispose([old,native,reference,before,after])
    var holder=Node3D.new();root.add_child(holder)
    var adapter=Atlas.new();adapter.attach(holder);adapter.set_light_cap(1.0);adapter.set_normals_visible(true)
    check(not adapter.viewport.use_hdr_2d,"Production Normals mode uses nativeLDR even while cap setting remains enabled")
    for fixture in [body,wall]:
        var old=native_receiver(fixture,8,"mixed",3,false,false,false,56,false,true)
        var native=native_receiver(fixture,8,"mixed",3,adapter.viewport.use_hdr_2d,false,false,56,false,true)
        var before=output_view(fixture,old,0,true);var after=output_view(fixture,native,1,false,1,true)
        var comparison=compare(await capture(before),await capture(after))
        check(comparison.changed_pixels==0,fixture.family+" Normals diagnostic bypasses illumination cap byte exactly: "+str(comparison))
        cap_cases.append({"id":fixture.family+"-normals","comparison":comparison})
        await dispose([old,native,before,after])

    adapter.set_normals_visible(false)
    check(adapter.viewport.use_hdr_2d,"Leaving Normals restores enabled cap HDR storage")
    adapter.close();holder.queue_free()

func black_fixture()->Dictionary:
    var colour=Image.create(8,8,false,Image.FORMAT_RGBA8)
    var normal=Image.create(8,8,false,Image.FORMAT_RGBAF);normal.fill(Color(0,0,1,1))
    for y in 8:
        for x in 8:colour.set_pixel(x,y,Color8(0 if x<4 else 2,0 if x<4 else 30,0 if x<4 else 91,[0,63,194,255][y%4]))
    var material=ShaderMaterial.new();material.shader=Modular
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(colour));material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
    return {"id":"typed-black-and-dark-source","family":"modular","colour":colour,"normals":normal,"material":material,"tint":Color.WHITE,"visible":1.0,"mirror":false}

func bypass_cases(wall:Dictionary)->void:
    var assets:Dictionary=Catalog.read_file("assets.json",cache)
    var source_path:String=assets.resources[assets.animations["torch.flame"].frames[0]].path
    var source=Image.load_from_file(Catalog.media_path(source_path))
    var array=Texture2DArray.new();var frames:Array[Image]=[source];array.create_from_images(frames)
    var flame=ShaderMaterial.new();flame.shader=load("res://presentation/canvas_fixture_flame.gdshader")
    flame.set_shader_parameter("frames",array);flame.set_shader_parameter("alpha_pedestal",1.0/255.0)
    var shadow:ShaderMaterial=wall.material.duplicate();shadow.shader=load("res://presentation/canvas_environment_unshaded.gdshader");shadow.set_shader_parameter("source_unlit",true)
    for fixture in [{"id":"original-torch-flame","family":"flame","colour":source,"material":flame,"visible":1.0},
            {"id":"original-wall-shadow","family":"shadow","colour":wall.colour,"material":shadow,"visible":wall.visible}]:
        var old=native_receiver(fixture,8,"mixed",3,false)
        var native=native_receiver(fixture,8,"mixed",3,true)
        var reference=native_receiver(fixture,8,"mixed",3,true,true)
        var native_output=output_view(fixture,reference,0,false,1,false,true)
        var before=output_view(fixture,old,0,true);var after=output_view(fixture,native,1,false,1,true)
        var original=await capture(before);var result=await capture(after)
        var comparison=compare(original,result)
        original.save_png("res://.captures/native-light-cap/"+fixture.family+"-bypass-before.png")
        result.save_png("res://.captures/native-light-cap/"+fixture.family+"-bypass-after.png")
        var native_image=await capture(native_output)
        var bypass=compare(native_image,result);var storage=alpha_bounds(original,native_image)
        check(bypass.alpha_mismatches==0 and bypass.maximum_byte_error<=1,fixture.id+" bypass matches uncapped original-source nativeHDR: "+str(bypass))
        check(storage.maximum_byte_error<=1 and storage.coverage_changes==0,fixture.id+" nativeHDR/oldLDR alpha storage bound, exact coverage: "+str(storage))
        var raw_alpha:Image=fixture.colour.duplicate()
        if fixture.family=="flame":
            raw_alpha.convert(Image.FORMAT_RGBAF)
            for y in raw_alpha.get_height():
                for x in raw_alpha.get_width():
                    var value=raw_alpha.get_pixel(x,y);value.a=maxf(0,(value.a-1.0/255)/(1-1.0/255));raw_alpha.set_pixel(x,y,value)
        var examples=alpha_trace(await capture(old),await capture(native),original,result,raw_alpha)
        cap_cases.append({"id":fixture.id,"comparison":comparison,"native_hdr_reference":bypass,"native_hdr_vs_ldr_alpha":storage,"alpha_examples":examples})
        await dispose([old,native,reference,native_output,before,after])

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=texture(COOKIE)
    reference_shader=Shader.new();reference_shader.code=REFERENCE
    original_hdr_output=Shader.new();original_hdr_output.code=HDR_ORIGINAL_OUTPUT
    for family in ["modular","environment","water"]:cap_shaders[family]=load("res://presentation/canvas_capped_"+family+".gdshader")
    DirAccess.make_dir_recursive_absolute("res://.captures/native-light-cap")
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular"
    var wall=corner(1,true);wall.family="environment"
    await overlap_matrix(body);await overlap_matrix(wall);await overlap_matrix(water_fixture())
    await overlap_matrix(black_fixture())
    await secondary_cases(body,wall);await bypass_cases(wall)
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"cases":cap_cases,"scope":"Actual modular/wall/water. Independent oldLDR native Canvas normals oracle plus frozen542303f water graph/output; source-black/scalar cap, alpha,0/1/2/8 warm/mixed overlaps, below-cap fidelity, native order, off restoration, normal-height response, wall opacity, Normals bypass. RGB comparison bound1; capped alpha exactly matches original-source nativeHDR; oldLDR storage difference separately bounded1alpha byte with exact coverage. Normals nativeLDR byteexact."}
    FileAccess.open("res://generated/native_light_cap_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_CAP_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
