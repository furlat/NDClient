extends SceneTree
## Finite native receiving-plane proof through the lit modular sprite and the
## light table; server categories are never inferred here. The native Canvas
## page with the same PointLight2D nodes measures the uncapped irradiance.
const Lighting=preload("res://presentation/lighting_2d.gd")
const LightTable=preload("res://presentation/light_table.gd")
const Recording=preload("res://studio/recording.gd")
const Placement=preload("res://placement.gd")
const Modular=preload("res://modular.gdshader")
const AMBIENT=.18
const DIRECTORY="res://.runtime/studio-cases/hide-light-seed3/blue"
var checks=0
var failures:Array=[]
var samples:Array=[]
var light_table=LightTable.new()
var cookie_images:Dictionary={}
func cookie_image(texture:Texture2D)->Image:
    if not cookie_images.has(texture.get_rid()):
        var image:Image=texture.get_image().duplicate();image.convert(Image.FORMAT_RGBA8);cookie_images[texture.get_rid()]=image
    return cookie_images[texture.get_rid()]
# The receiving globals as play.gd _publish_receiving writes them.
func publish(sources:Array,cap:float)->void:
    light_table.publish(sources,cookie_image)
    var ambient:=Color(AMBIENT,AMBIENT,AMBIENT)
    RenderingServer.global_shader_parameter_set(&"light_ambient",ambient.linear_to_srgb().srgb_to_linear().r if cap>0.0 else AMBIENT)
    RenderingServer.global_shader_parameter_set(&"light_cap",cap)
    RenderingServer.global_shader_parameter_set(&"light_normals",false)
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("LIGHT_RANGE_RENDER_FAIL ",label)
func _initialize()->void:run.call_deferred()
func capture(view:SubViewport)->Image:
    await process_frame;await RenderingServer.frame_post_draw
    return view.get_texture().get_image()
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000)
    var index=Recording.read(DIRECTORY+"/journal")
    check(index.ok,"Original server journal admitted through shared reducer/compiler")
    if not index.ok:quit(1);return
    var descriptor:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"/case.json"))
    var declared:Array=descriptor.light_probes.filter(func(row):return row.label in ["dim","bright","very_bright"])
    var states:Array=[]
    for probe in declared:
        var boundary=0.0
        for item in index.groups:
            if item.group.operation_sequence==probe.sequence:boundary=maxf(boundary,item.start_ms+item.group.duration_ms)
        var timeline=Recording.restore(index,boundary+.01)
        check(timeline.state.tiles["4,6"].resolved_light==probe.world_resolved_light,"Actual objective observation at "+probe.label)
        check(timeline.state.senses.effective_light_levels.get("4,6")==probe.observer_effective_light,"Actual perceived observation at "+probe.label)
        states.append(timeline.state)
    var canvas=SubViewport.new();canvas.size=Vector2i(256,256);canvas.disable_3d=true;canvas.use_hdr_2d=true
    canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(canvas)
    var ambient=CanvasModulate.new();ambient.color=Color(.18,.18,.18).linear_to_srgb();canvas.add_child(ambient)
    var shader=Shader.new();shader.code="shader_type canvas_item; render_mode blend_disabled; void fragment(){COLOR=vec4(1.0); NORMAL=vec3(0.0,0.0,1.0);}"
    var receiver=ColorRect.new();receiver.size=Vector2(256,256);receiver.material=ShaderMaterial.new();receiver.material.shader=shader;canvas.add_child(receiver)
    var output=SubViewport.new();output.size=canvas.size;output.own_world_3d=true;output.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(output)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.position=Vector3(0,0,3);output.add_child(camera)
    var image=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
    # A flat white lit modular receiver filling the output; one texel per pixel.
    var material=ShaderMaterial.new();material.shader=Modular
    material.set_shader_parameter("sheet",ImageTexture.create_from_image(image));material.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
    material.set_shader_parameter("material_cell_size",Vector2(canvas.size));material.set_shader_parameter("source_quad_size",Vector2(2,2))
    var quad=MeshInstance3D.new();quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2);quad.material_override=material;output.add_child(quad)
    var projection=SubViewport.new();projection.size=canvas.size;root.add_child(projection)
    var source_camera=Camera3D.new();source_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;projection.add_child(source_camera)
    var lighting=Lighting.new();lighting.attach(canvas)
    DirAccess.make_dir_recursive_absolute("res://.captures/light-ranges")
    var references={}
    for q in 4:
        for size in [32.0,24.0]:
            var intensities=[]
            for i in declared.size():
                lighting.sync(states[i]);lighting.sample({})
                # Range cookies are generated off the main thread; wait for this one.
                while lighting.sources.size()==1 and lighting.cookie_pending(lighting.sources[0]):await process_frame
                lighting.sync(states[i]);lighting.sample({})
                check(lighting.sources.size()==1,"Only real disclosed lit Blue torch at "+declared[i].label)
                if lighting.sources.size()!=1:continue
                var source:Dictionary=lighting.sources[0]
                var at:Vector3=lighting.sampled[source.item_uuid].position
                source_camera.size=size;source_camera.position=at+Basis(Vector3.UP,q*PI*.5)*Vector3(10,10/sqrt(3.0),10)
                source_camera.look_at(at);lighting.project(source_camera)
                var light:PointLight2D=lighting.nodes[source.item_uuid]
                var ratio=Vector2(declared[i].source_position[0]-4,declared[i].source_position[1]-6).length()/source.outer
                # Same cookie-relative radius after native support-plane projection;
                # its normal-light vector still uses the actual optical origin.
                var exposure: Dictionary=lighting.canvas_sources()[0]
                var pixel=Vector2i((exposure.cookie_position+Vector2(ratio*exposure.span.x*.5,0)).round())
                publish(lighting.canvas_sources(),1.0)
                var capped=await capture(output);var c=capped.get_pixelv(pixel)
                publish(lighting.canvas_sources(),0.0)
                var uncapped=await capture(output);var u=uncapped.get_pixelv(pixel)
                var row={"quarter":q,"camera_size":size,"recorded_zone":declared[i].label,"sequence":declared[i].sequence,
                    "normalized_optical_radius":ratio,"pixel":str(pixel),"capped": [c.r8,c.g8,c.b8],"uncapped":[u.r8,u.g8,u.b8]}
                samples.append(row);intensities.append(c.r8)
                check(c.a8==255 and u.a8==255,"Profile preserves opaque receiver coverage")
                check(c.r8>=c.g8 and c.g8>=c.b8,"Profile preserves warm colour ordering")
                var key=str(size)+declared[i].label
                if q==0:references[key]=c
                else:check(abs(c.r8-references[key].r8)<=1 and abs(c.g8-references[key].g8)<=1,"Equal native optical radius is rotation invariant")
                if q==0 and size==32:
                    capped.save_png("res://.captures/light-ranges/"+declared[i].label+"-cap.png")
            check(intensities[0]<intensities[1] and intensities[1]<intensities[2],"Native dim/bright/very-bright profile samples remain distinct with cap, quarter%d size%d"%[q,size])
    # Actual multiple-source additivity remains native, and the existing cap still bounds it.
    var sources:Array=lighting.canvas_sources()
    publish(sources,1.0)
    var one=await capture(output)
    var duplicate=lighting.nodes.values()[0].duplicate();canvas.add_child(duplicate)
    var second:Dictionary=sources[0].duplicate();second.id=str(second.id)+"-second"
    publish(sources+[second],1.0)
    var two=await capture(output)
    var irradiance=await capture(canvas)
    var peak=Vector2i(sources[0].cookie_position.round())
    check(irradiance.get_pixelv(peak).r>1.0 and one.get_pixelv(peak).r8==255 and two.get_pixelv(peak).r8==255,
        "Measured over-cap native irradiance reaches the same capped source peak with one/two lights")
    check(two.get_data()!=one.get_data(),"Overlapping native lights still contribute; no claim of engine MAX composition")
    duplicate.queue_free();publish(sources,1.0);await process_frame
    var restored=await capture(output)
    check(restored.get_data()==one.get_data(),"Removing second light restores original pixels")
    lighting.clear_pages()
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":samples,
        "scope":"Real observed DIM/BRIGHT/VERY_BRIGHT source ratios through the light table and a flat lit modular receiver with the production light cap; the native PointLight2D page measures irradiance. All four quarters/two zooms. Ground projection, occlusion and backend MAX are not claimed by this optical-plane fixture."}
    FileAccess.open("res://generated/light_range_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_RANGE_RENDER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
