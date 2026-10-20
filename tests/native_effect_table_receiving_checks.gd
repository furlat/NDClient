extends SceneTree
## Native-source effect receiving lit by the shared light table against the
## former lit Canvas page, built here as the reference: an HDR page with
## CanvasModulate 0.18, a white receiver carrying the composition normals of
## the same captures, and PointLight2D lights configured as the receiving
## pages configured them, read by the former output shader. Same captures,
## same frame registration; the final effect pixels are compared. The page's
## specular map is left out: tests/light_table_checks.gd proves it changes no
## pixel of a native receiving page.
const Preview=preload("res://presentation/native_effect_preview.gd")
const LightTable=preload("res://presentation/light_table.gd")
const Lighting2D=preload("res://presentation/lighting_2d.gd")
const NativeSourceLights=preload("res://presentation/native_source_lights.gd")
const Sources=preload("res://presentation/native_effects.gd")
const REFERENCE_RECEIVER='''shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D native_colour : filter_nearest, repeat_disable;
uniform sampler2D native_normals : filter_nearest, repeat_disable;
vec3 source_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
void fragment() {
    vec4 colour=texture(native_colour,UV);
    if(colour.a<=0.0)discard;
    vec4 field=texture(native_normals,UV);
    vec3 packed=source_decode(field.rgb)/max(field.a,1.0/65535.0);
    vec3 normal=normalize(packed*2.0-1.0);
    NORMAL=vec3(normal.x,-normal.y,normal.z);
    COLOR=vec4(1.0,1.0,1.0,colour.a);
}'''
const REFERENCE_OUTPUT='''shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D effect_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D receiving_texture : filter_nearest, repeat_disable;
uniform float light_cap = 0.0;
vec3 source_encode(vec3 value) {
    return mix(1.055*pow(value,vec3(1.0/2.4))-vec3(.055),12.92*value,lessThanEqual(value,vec3(.0031308)));
}
vec3 source_decode(vec3 value) {
    return mix(pow((value+vec3(.055))/1.055,vec3(2.4)),value/12.92,lessThanEqual(value,vec3(.04045)));
}
void fragment() {
    vec4 value=texture(effect_texture,UV);
    vec3 light=texture(receiving_texture,UV).rgb;
    float peak=max(light.r,max(light.g,light.b));
    if(light_cap>0.0 && peak>light_cap)light*=light_cap/peak;
    vec3 original=source_encode(clamp(value.rgb/max(value.a,1.0/65535.0),vec3(0.0),vec3(1.0)));
    ALBEDO=source_decode(clamp(original*light,vec3(0.0),vec3(1.0)));
    ALPHA=value.a;
}'''
var checks:=0
var failures:Array=[]
var results:Array=[]

func _initialize()->void:run.call_deferred()

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("TABLE_RECEIVING_FAIL ",label)

func frame()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func cookie(request:Callable)->Texture2D:
    var texture:Texture2D=request.call()
    while texture==null:
        await process_frame
        texture=request.call()
    return texture

# The node inputs Lighting2D.project() writes, around a screen point.
func light(id:String,at:Vector2,support:Vector2,texture:Texture2D,diameter:float,ellipse:float,height:float,energy:float,colour:Color)->Dictionary:
    var scale:=Vector2(1,ellipse)
    return {"id":id,"screen_position":at,"cookie_position":support,"texture":texture,"texture_scale":diameter/texture.get_width(),
        "cookie_scale":scale,"offset":(support-at)/scale,"height":height,"energy":energy,"color":colour,"enabled":true}

func page(size:Vector2i,origin:Vector2,colour:Texture2D,normals:Texture2D,sources:Array)->SubViewport:
    var view:=SubViewport.new();view.size=size;view.disable_3d=true;view.transparent_bg=true;view.use_hdr_2d=true
    view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var ambient:=CanvasModulate.new();ambient.color=Color(.18,.18,.18).linear_to_srgb();view.add_child(ambient)
    var rectangle:=Sprite2D.new();rectangle.centered=false
    var white:=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
    var channels:=CanvasTexture.new();channels.diffuse_texture=ImageTexture.create_from_image(white)
    rectangle.texture=channels;rectangle.scale=Vector2(size);rectangle.position=origin
    var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=REFERENCE_RECEIVER;material.shader=shader
    material.set_shader_parameter("native_colour",colour);material.set_shader_parameter("native_normals",normals)
    rectangle.material=material;view.add_child(rectangle)
    view.global_canvas_transform=Transform2D(0,-origin)
    for source in sources:
        var node:=PointLight2D.new();node.texture=source.texture;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
        node.position=source.screen_position;node.scale=source.cookie_scale;node.offset=source.offset
        node.texture_scale=source.texture_scale;node.height=source.height;node.energy=source.energy;node.color=source.color
        view.add_child(node)
    return view

func run()->void:
    var main:=SubViewport.new();main.size=Vector2i(768,768);main.own_world_3d=true;main.transparent_bg=true
    main.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(main)
    var owner:=Node3D.new();main.add_child(owner)
    # Native field deposits have their actual source/support/landing oracle
    # in blood_kernel_cache_checks / blood_residue_checks (CPU) and
    # studio_blood_residue_checks / blood_world_preparation_checks (native).
    # These old IDs
    # intentionally cannot reintroduce a per-impact client-invented decal.
    for retired in ["blood.deposit_a1","blood.deposit_j1"]:
        var source:Dictionary=Sources.source_record(retired,{})
        var children:int=owner.get_child_count()
        check(source.is_empty(),retired+" remains absent from current typed sources")
        var refused:Dictionary=Sources.make(owner,source)
        check(not refused.get("error","").is_empty() and owner.get_child_count()==children,retired+" cannot attach an invented ground effect")
    var camera:=Camera3D.new();owner.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=6.0;camera.current=true
    var world:=Lighting2D.new();var spells:=NativeSourceLights.new()
    var near:Texture2D=await cookie(world._source_cookie.bind({"outer":6.0,"very_bright_radius_feet":10,"bright_radius_feet":20}))
    var spell:Texture2D=await cookie(spells._effect_cookie.bind("",1.0))
    for i in 3:await process_frame
    var table:=LightTable.new()
    var reference_shader:=Shader.new();reference_shader.code=REFERENCE_OUTPUT
    var empty:=0
    for quarter in 4:
        var basis:=Basis(Vector3.UP,quarter*PI*.5)*Basis.looking_at(Vector3(-6,-sqrt(24.0),-6))
        camera.basis=basis;camera.position=Vector3(0,.9*.816496580927726,0)+basis.z*12.
        var centre:=camera.unproject_position(Vector3.ZERO)
        var sources:Array=[
            light("torch",centre+Vector2(40,-70),centre+Vector2(40,-30),near,300.0,0.57735,79.19,1.86,Lighting2D.TORCH_COLOUR),
            light("spell",centre+Vector2(-25,10),centre+Vector2(-25,10),spell,180.0,1.0,31.3,3.5,Color(0.35,0.55,0.95))]
        table.publish(sources,func(_texture):return null)
        check(table.issues.is_empty() and table.count==2,"q"+str(quarter)+": the table holds both lights")
        for id in ["blood.hit_a1","blood.hit_a2"]:
            var preview:=Preview.new();owner.add_child(preview)
            var configured:String=preview.configure(id,{},73)
            check(configured.is_empty(),id+" builds selected native source: "+configured)
            if not configured.is_empty():preview.close();preview.free();continue
            var receiving:String=preview.bind_receiving()
            check(receiving.is_empty(),id+" binds table receiving: "+receiving)
            if not receiving.is_empty():preview.close();preview.free();continue
            var record:Dictionary=preview.record;var ppu:=float(record.pixels_per_unit)
            var origin:=camera.unproject_position(basis*Vector3(-record.pivot[0]/ppu,record.pivot[1]/ppu,0))
            var pixel_scale:=(camera.unproject_position(basis*Vector3.RIGHT)-camera.unproject_position(Vector3.ZERO)).length()/ppu
            var context:={"screen_origin":origin,"pixel_scale":pixel_scale,"light_cap":1.0,"source_basis":Basis(Vector3.UP,.4),"supports":[]}
            var age:=.2
            var sample:Dictionary=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            var deadline:=Time.get_ticks_msec()+10000
            while not sample.ready and sample.error.is_empty() and Time.get_ticks_msec()<deadline:
                await frame();sample=preview.sample(age,basis,Vector3.ZERO,1.0,[],context)
            check(sample.ready,id+" q"+str(quarter)+" samples")
            await frame()
            # The reference: per view, the former page and output shader over
            # the same captures, drawn by a twin of the effect quad.
            var references:Array=[];var pages:Array=[]
            for index in preview.views.size():
                var row:Dictionary=preview.views[index];var state:Dictionary=preview.receiving_halves[index]
                var view:=page(Vector2i(row.viewport.size),origin,row.viewport.get_texture(),state.normal.get_texture(),sources)
                pages.append(view)
                var surface:MeshInstance3D=preview.surfaces[index].node
                var twin:=MeshInstance3D.new();twin.mesh=surface.mesh;twin.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                var material:=ShaderMaterial.new();material.shader=reference_shader
                material.set_shader_parameter("effect_texture",surface.material_override.get_shader_parameter("effect_texture"))
                material.set_shader_parameter("receiving_texture",view.get_texture());material.set_shader_parameter("light_cap",1.0)
                twin.material_override=material;twin.visible=false;owner.add_child(twin);twin.global_transform=surface.global_transform
                references.append(twin)
            await frame()
            var actual:=main.get_texture().get_image()
            for row in preview.surfaces:row.node.visible=false
            for twin in references:twin.visible=true
            await frame();await frame()
            var expected:=main.get_texture().get_image()
            var worst:=0;var over:=0;var different:=0;var covered:=0
            for y in actual.get_height():
                for x in actual.get_width():
                    var a:=actual.get_pixel(x,y);var b:=expected.get_pixel(x,y)
                    if b.a>0:covered+=1
                    var error:=roundi(maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))*255.0)
                    if error>0:different+=1
                    if error>1:over+=1
                    worst=maxi(worst,error)
            var result:={"source":id,"quarter":quarter,"covered_pixels":covered,"different_pixels":different,"over_one_byte":over,"worst_byte_error":worst}
            results.append(result);print("TABLE_RECEIVING ",JSON.stringify(result))
            # A spray sample can be empty at this age (seeded native emission):
            # such a case compares nothing and is counted, never passed.
            if covered==0:empty+=1
            check(over==0,id+" q"+str(quarter)+": table receiving equals the former lit page within one byte")
            for twin in references:twin.free()
            for view in pages:view.free()
            preview.close();preview.free()
    check(empty<=2,"At most two of eight samples are empty native sprays ("+str(empty)+")")
    main.free()
    print("TABLE_RECEIVING_REPORT ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)
