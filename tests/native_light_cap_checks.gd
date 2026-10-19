extends "res://tests/native_light_output_checks.gd"
# The lit sprites' light cap (light_cap global, HDR storage) against independent
# native Canvas receiving: OLD LDR native pages composited analytically in
# linear alpha, and uncapped native HDR pages for the exact alpha/irradiance field.
# Modular and wall references use CPU-decoded normals; water and flame use the
# frozen 542303f native receivers. Actual artwork is not copied.
const OldFlame=preload("res://tests/fixtures/light_cap_ldr_542303f/canvas_fixture_flame.gdshader")
const Flame=preload("res://presentation/fixture_flame.gdshader")
var cap_cases:Array=[]
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
# Independent Normals view: the receiving normal as colour, unshaded, LDR.
const NORMALS_REFERENCE='''shader_type canvas_item;
render_mode blend_disabled,unshaded;
uniform sampler2D original : filter_nearest,repeat_disable;
uniform sampler2D decoded_normals : filter_nearest,repeat_disable;
uniform float alpha_scale = 1.0;
void fragment() {
    float alpha=texture(original,UV).a*alpha_scale;
    if(alpha<=0.0) discard;
    COLOR=vec4(texture(decoded_normals,UV).rgb*.5+.5,alpha);
}'''
var original_hdr_output:Shader

func cap_lights(fixture:Dictionary,count:int,spectrum:String,energy:float,height:float=56.0,reverse:bool=false)->Array:
    var size=Vector2(fixture.colour.get_size())
    var result:Array=[]
    for i in count:
        result.append(light(size*Vector2(.40+(i%2)*.18,.45+(i%3)*.07),WARM if spectrum=="warm" or i%2==0 else Color(.17,.62,.91),energy,height,800.0/cookie.get_width()))
    if reverse:result.reverse()
    return result

# Spatial output of a native HDR page image through the test-only uncapped transfer.
func output_view(fixture:Dictionary,received:Image,opacity:float=1.0)->Image:
    var size:Vector2i=fixture.colour.get_size()
    var view=SubViewport.new();view.size=size;view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0,0,0,0);view.add_child(environment)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.0;camera.position=Vector3(0,0,3);view.add_child(camera)
    var material=ShaderMaterial.new();material.shader=original_hdr_output
    material.set_shader_parameter("received",ImageTexture.create_from_image(received));material.set_shader_parameter("atlas_region",Vector4(0,0,1,1))
    material.set_shader_parameter("source_crop",Vector4(0,0,1,1));material.set_shader_parameter("wall_opacity",opacity)
    var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(2,2);node.material_override=material;view.add_child(node)
    var image:Image=await capture(view)
    view.queue_free()
    return image

# The independent white-irradiance field: the same native receiver with white
# colour and the fixture's stored alpha, in a native HDR page.
func field_fixture(fixture:Dictionary,source:Image)->Dictionary:
    var size:Vector2i=fixture.colour.get_size()
    var colour=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
    var normals:Image=fixture.get("normals")
    if normals==null:
        var b:Basis=fixture.basis;var up:Vector3=(Basis(b.x,-b.y,b.z).transposed()*Vector3.UP).normalized()
        normals=Image.create(size.x,size.y,false,Image.FORMAT_RGBAF);normals.fill(Color(up.x,up.y,up.z,1))
    for y in size.y:
        for x in size.x:
            # Water's alpha comes from its graph: read it from the raw native page.
            var alpha:float=source.get_pixel(x,y).a if fixture.family=="water" else fixture.colour.get_pixel(x,y).a
            colour.set_pixel(x,y,Color(1,1,1,alpha))
    var tint:Color=Color(1,1,1,1) if fixture.family=="water" else Color(1,1,1,fixture.tint.a)
    return {"colour":colour,"normals":normals,"tint":tint,"visible":1.0}

func scalar_oracle(source:Image,field:Image,alpha_reference:Image)->Dictionary:
    var expected=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
    var over=0;var maximum=0.0;var black=0
    for y in source.get_height():
        for x in source.get_width():
            var colour=source.get_pixel(x,y);var light=field.get_pixel(x,y)
            var peak=maxf(light.r,maxf(light.g,light.b));maximum=maxf(maximum,peak)
            var scale=1.0/maxf(1.0,peak)
            var encoded=Color(colour.r*light.r*scale,colour.g*light.g*scale,colour.b*light.b*scale,colour.a)
            encoded=Color8(roundi(clampf(encoded.r,0,1)*255),roundi(clampf(encoded.g,0,1)*255),roundi(clampf(encoded.b,0,1)*255),colour.a8)
            var alpha:float=alpha_reference.get_pixel(x,y).a
            var linear=encoded.srgb_to_linear();linear.r*=alpha;linear.g*=alpha;linear.b*=alpha
            var pixel=linear.linear_to_srgb()
            # Image.set_pixel(RGBA8, floatColour) truncates; the native target
            # rounds. Quantize explicitly so the CPU reference has no dark bias.
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

func overlap_matrix(fixture:Dictionary)->void:
    var source:Image=await native_receiving(fixture,[],true)
    # The analytic formula needs original fractional tint/style, not already
    # quantized LDR albedo. Decode those directly from original bytes. Water's
    # frozen native graph is sampled separately before byte quantization.
    var floating_source:Image
    if fixture.family=="water":
        floating_source=await native_receiving(fixture,[],true,1.0,true)
        floating_source.convert(Image.FORMAT_RGBAF)
    else:
        floating_source=Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBAF)
        for y in source.get_height():
            for x in source.get_width():
                var value:Color=fixture.colour.get_pixel(x,y)*fixture.tint
                if fixture.family=="environment":
                    var grey=value.r*.2126+value.g*.7152+value.b*.0722
                    var remembered=Color(lerpf(grey,value.r,.35)*.62,lerpf(grey,value.g,.35)*.62,lerpf(grey,value.b,.35)*.62,value.a)
                    value=remembered.lerp(value,fixture.visible)
                value.a=source.get_pixel(x,y).a;floating_source.set_pixel(x,y,value)
    var white_field:Dictionary=field_fixture(fixture,source)
    for spectrum in ["warm","mixed"]:
        for count in [0,1,2,8]:
            var energy=0.2 if count<=1 else 3.0
            var lights:Array=cap_lights(fixture,count,spectrum,energy)
            var old:Image=await native_receiving(fixture,lights)
            var field:Image=await native_receiving(white_field,lights,false,1.0,true)
            var native_original:Image=await native_receiving(fixture,lights,false,1.0,true)
            var native_alpha_reference:Image=await output_view(fixture,native_original)
            var original:Image=linear_alpha_reference(old)
            var actual:Image=await lit_receiving(fixture,lights,false,1.0,1.0)
            if count==0 and spectrum=="warm":
                source.save_png("res://.captures/native-light-cap/"+fixture.family+"-old-source.png")
                floating_source.save_exr("res://.captures/native-light-cap/"+fixture.family+"-source.exr")
                field.save_exr("res://.captures/native-light-cap/"+fixture.family+"-field.exr")
                original.save_png("res://.captures/native-light-cap/"+fixture.family+"-ambient-before.png")
                actual.save_png("res://.captures/native-light-cap/"+fixture.family+"-ambient-after.png")
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
            var reversed_output:Image=await lit_receiving(fixture,cap_lights(fixture,count,spectrum,energy,56.0,true),false,1.0,1.0)
            var ordering=compare(actual,reversed_output)
            check(ordering.alpha_mismatches==0 and ordering.maximum_byte_error<=1,label+" light table order changes at most half-float rounding: "+str(ordering))
            # The setting off: the same sprite in LDR storage, no other change.
            # Water's half-byte alpha rows may round the other way in the native
            # RGBA8 page; those one-byte flips are counted and composited as stored.
            var restored:Image=await lit_receiving(fixture,lights,false,1.0,0.0)
            var water:bool=fixture.family=="water"
            var off=compare(restored,linear_alpha_reference(old,restored if water else null))
            off.alpha_half_byte_flips=alpha_flips(restored,old) if water else 0
            check(off.alpha_mismatches==0 and off.maximum_byte_error<=1,label+" toggle off restores independent native LDR baseline: "+str(off))
            cap_cases.append({"id":label,"native_hdr_alpha_mismatches":native_alpha,"native_hdr_vs_ldr_alpha":storage_alpha,"baseline":baseline,"scalar_oracle":formula,"native_peak":oracle.maximum_native_irradiance,"over_cap_pixels":oracle.over_cap_pixels,"order":ordering,"toggle_off":off})
            if count==8 and spectrum=="warm":
                original.save_png("res://.captures/native-light-cap/"+fixture.family+"-before.png");actual.save_png("res://.captures/native-light-cap/"+fixture.family+"-capped.png")

func normals_reference(fixture:Dictionary)->Image:
    var size:Vector2i=fixture.colour.get_size()
    var view=page(false,null,size)
    var material=ShaderMaterial.new();var shader=Shader.new();shader.code=NORMALS_REFERENCE;material.shader=shader
    material.set_shader_parameter("original",ImageTexture.create_from_image(fixture.colour))
    material.set_shader_parameter("decoded_normals",ImageTexture.create_from_image(fixture.normals))
    material.set_shader_parameter("alpha_scale",fixture.tint.a)
    sprite(view,material,Transform2D(Vector2(size.x,0),Vector2(0,size.y),Vector2.ZERO))
    var image:Image=await capture(view)
    view.queue_free()
    return image

func secondary_cases(body:Dictionary,wall:Dictionary)->void:
    var low:Image=await lit_receiving(body,cap_lights(body,1,"warm",.2,20),false,1.0,1.0)
    var high:Image=await lit_receiving(body,cap_lights(body,1,"warm",.2,56),false,1.0,1.0)
    var response=compare(low,high)
    check(response.changed_pixels>10 and response.alpha_mismatches==0,"Native authored normal/height response remains visible below cap")
    cap_cases.append({"id":"height20-vs56","comparison":response})
    for opacity in [0.0,.28,1.0]:
        var lights:Array=cap_lights(wall,8,"mixed",3)
        var reference:Image=await native_receiving(wall,lights,false,1.0,true)
        var before:Image=await output_view(wall,reference,opacity)
        var after:Image=await lit_receiving(wall,lights,false,1.0,1.0,false,null,opacity)
        var comparison=compare(before,after)
        check(comparison.alpha_mismatches==0,"Whole-wall opacity"+str(opacity)+" stays exact across cap")
    # Normals: play.gd writes light_normals; HDR storage needs cap>0 and not Normals.
    for fixture in [body,wall]:
        var lights:Array=cap_lights(fixture,8,"mixed",3)
        var capped:Image=await lit_receiving(fixture,lights,false,1.0,1.0,true)
        var uncapped:Image=await lit_receiving(fixture,lights,false,1.0,0.0,true)
        var bypass=compare(capped,uncapped)
        check(bypass.changed_pixels==0,fixture.family+" Normals bypasses illumination cap byte exactly: "+str(bypass))
        var straight:Image=await normals_reference(fixture)
        var independent=compare(capped,linear_alpha_reference(straight))
        check(independent.alpha_mismatches==0 and independent.maximum_byte_error<=1,fixture.family+" Normals shows the independent CPU-decoded receiving normals: "+str(independent))
        var restored:Image=await lit_receiving(fixture,lights,false,1.0,1.0)
        var reference:Image=await lit_receiving(fixture,lights,false,1.0,1.0)
        check(compare(restored,reference).changed_pixels==0,fixture.family+" leaving Normals restores the capped HDR output")
        cap_cases.append({"id":fixture.family+"-normals","cap_bypass":bypass,"independent_normals":independent})

func black_fixture()->Dictionary:
    var colour=Image.create(8,8,false,Image.FORMAT_RGBA8)
    var normal=Image.create(8,8,false,Image.FORMAT_RGBAF);normal.fill(Color(0,0,1,1))
    for y in 8:
        for x in 8:colour.set_pixel(x,y,Color8(0 if x<4 else 2,0 if x<4 else 30,0 if x<4 else 91,[0,63,194,255][y%4]))
    var material=ShaderMaterial.new();material.shader=Modular
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(colour));material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
    material.set_shader_parameter("material_cell_size",Vector2(8,8))
    return {"id":"typed-black-and-dark-source","family":"modular","colour":colour,"normals":normal,"material":material,"tint":Color.WHITE,"visible":1.0,"mirror":false,"basis":Basis.IDENTITY}

func bypass_cases(wall:Dictionary)->void:
    var assets:Dictionary=Catalog.environment_resources(cache)
    var source_path:String=assets.resources[assets.animations["torch.flame"].frames[0]].path
    var source=Image.load_from_file(Catalog.media_path(source_path))
    var array=Texture2DArray.new();var frames:Array[Image]=[source];array.create_from_images(frames)
    var flame=ShaderMaterial.new();flame.shader=Flame
    flame.set_shader_parameter("frames",array);flame.set_shader_parameter("alpha_pedestal",1.0/255.0)
    var old_flame=ShaderMaterial.new();old_flame.shader=OldFlame
    old_flame.set_shader_parameter("frames",array);old_flame.set_shader_parameter("alpha_pedestal",1.0/255.0)
    var shadow:ShaderMaterial=wall.material.duplicate();shadow.set_shader_parameter("source_unlit",true)
    var shadow_tint:=Color(0,0,0,wall.tint.a)
    for fixture in [{"id":"original-torch-flame","family":"flame","colour":source,"material":flame,"reference_material":old_flame,"visible":1.0,"basis":Basis.IDENTITY,"mirror":false,"tint":Color.WHITE},
            {"id":"original-wall-shadow","family":"shadow","colour":wall.colour,"normals":wall.normals,"material":shadow,"visible":wall.visible,"basis":wall.basis,"mirror":false,"tint":shadow_tint}]:
        var lights:Array=cap_lights(fixture,8,"mixed",3)
        var old:Image=await native_receiving(fixture,lights)
        var reference:Image=await native_receiving(fixture,lights,false,1.0,true)
        var native_image:Image=await output_view(fixture,reference)
        var original:Image=linear_alpha_reference(old)
        var result:Image=await lit_receiving(fixture,lights,false,1.0,1.0)
        var comparison=compare(original,result)
        original.save_png("res://.captures/native-light-cap/"+fixture.family+"-bypass-before.png")
        result.save_png("res://.captures/native-light-cap/"+fixture.family+"-bypass-after.png")
        var bypass=compare(native_image,result);var storage=alpha_bounds(original,native_image)
        check(bypass.alpha_mismatches==0 and bypass.maximum_byte_error<=1,fixture.id+" bypass matches uncapped original-source nativeHDR: "+str(bypass))
        check(storage.maximum_byte_error<=1 and storage.coverage_changes==0,fixture.id+" nativeHDR/oldLDR alpha storage bound, exact coverage: "+str(storage))
        cap_cases.append({"id":fixture.id,"comparison":comparison,"native_hdr_reference":bypass,"native_hdr_vs_ldr_alpha":storage})

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var one=Image.create(1,1,false,Image.FORMAT_RGBA8);one.fill(Color.WHITE);white=ImageTexture.create_from_image(one);cookie=light_cookie()
    reference_shader=Shader.new();reference_shader.code=REFERENCE
    original_hdr_output=Shader.new();original_hdr_output.code=HDR_ORIGINAL_OUTPUT
    DirAccess.make_dir_recursive_absolute("res://.captures/native-light-cap")
    var body=modular("Chest14","chest",0,"reference",false);body.family="modular"
    var wall=corner(1,true);wall.family="environment"
    await overlap_matrix(body);await overlap_matrix(wall);await overlap_matrix(water_fixture())
    await overlap_matrix(black_fixture())
    await secondary_cases(body,wall);await bypass_cases(wall)
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"cases":cap_cases,"scope":"Actual modular/wall/water through the lit sprite shaders with light_cap on/off. Independent oldLDR native Canvas references (CPU-decoded normals; frozen542303f water/flame receivers) composited analytically in linear alpha, plus uncapped native HDR pages for the irradiance field and alpha. Source-black/scalar cap, alpha,0/1/2/8 warm/mixed overlaps, below-cap fidelity, light table order, off restoration, normal-height response, wall opacity, Normals bypass and independent normals, flame/shadow bypass. RGB comparison bound1; capped alpha exactly matches original-source nativeHDR; oldLDR storage difference separately bounded1alpha byte with exact coverage."}
    FileAccess.open("res://generated/native_light_cap_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_CAP_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
