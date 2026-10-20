extends SceneTree
## Finite native receiving-plane proof through the lit modular sprite and the
## light table; server categories are never inferred here. The native Canvas
## page with the same PointLight2D nodes measures the uncapped irradiance.
const Lighting=preload("res://presentation/lighting_2d.gd")
const LightTable=preload("res://presentation/light_table.gd")
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Cells=preload("res://sdk/fold_cells.gd")
const Placement=preload("res://placement.gd")
const Modular=preload("res://modular.gdshader")
const AMBIENT=.18
# Original schema16 Blue observations at [4,6], with the same disclosed torch
# moving [10,6] -> [7,6] -> [6,6]. Values are the original world/light_levels
# columns (LightLevel DIM=2, BRIGHT=3, VERY_BRIGHT=4), not inferred radiance.
const PROBES=[
    {"label":"dim","sequence":8,"source_position":[10,6],"world_resolved_light":2,"observer_effective_light":2},
    {"label":"bright","sequence":13,"source_position":[7,6],"world_resolved_light":3,"observer_effective_light":3},
    {"label":"very_bright","sequence":14,"source_position":[6,6],"world_resolved_light":4,"observer_effective_light":4}]
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
    var directory:String=Fixtures.journal("hide-light","blue")
    var index:Dictionary=Recording.read(directory)
    check(index.ok,"Durable original schema16 Blue Hide/light journal admits through shared reducer/compiler")
    if not index.ok:quit(1);return
    var declared:Array=PROBES
    var states:Array=[]
    var frozen_states:Array=[]
    for probe in declared:
        var group_index:int=-1
        for i in index.groups.size():
            var group:Dictionary=index.groups[i].group
            if group.operation_sequence==probe.sequence and group.operation_end:group_index=i
        check(group_index>=0,"Original journal has the exact operation-ending boundary for "+probe.label)
        if group_index<0:quit(1);return
        var actual_group:Dictionary=index.groups[group_index].group
        var timeline:RefCounted=Recording.restore_boundary(index,group_index,actual_group.commits.size())
        var state:Dictionary=timeline.state
        check(timeline.sequence==probe.sequence,"Restore retains the exact real subjective cursor for "+probe.label)
        check(state.tiles["4,6"].resolved_light==probe.world_resolved_light,"Actual objective observation at "+probe.label)
        var perceived:Dictionary=Cells.values_map(state.senses.effective_light_levels)
        check(Cells.contains(state.senses.visible,[4,6]) and perceived.get("4,6")==probe.observer_effective_light,"Actual current perceived observation decodes through the SDK mask at "+probe.label)
        check(state.light_sources.size()==1,"Original "+probe.label+" boundary discloses one optical source")
        if state.light_sources.size()!=1:quit(1);return
        check(state.light_sources.values()[0].position==probe.source_position,"Probe uses the exact original disclosed optical position at "+probe.label)
        states.append(state);frozen_states.append(var_to_bytes(state))
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
                check(source.item_uuid==states[i].light_sources.keys()[0],"Native PointLight2D retains the original optical source UUID")
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
            check(intensities.size()==3,"Every original level produces an actual receiver sample, quarter%d size%d"%[q,size])
            if intensities.size()==3:
                check(intensities[0]<intensities[1] and intensities[1]<intensities[2],"Native dim/bright/very-bright profile samples remain distinct with cap, quarter%d size%d"%[q,size])
    # Named renderer overlap control, not a recorded second gameplay source:
    # native PointLight2D adds irradiance and the existing receiving cap bounds it.
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
    for i in states.size():check(var_to_bytes(states[i])==frozen_states[i],"Native projection/cap/overlap controls preserve original "+declared[i].label+" state")
    var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"recording":directory,"recorded_probes":declared,"samples":samples,
        "scope":"Real observed DIM/BRIGHT/VERY_BRIGHT source ratios through the light table and a flat lit modular receiver with the production light cap; the native PointLight2D page measures irradiance. Source/category evidence is the unchanged current-schema Blue original; duplicated-light overlap is an explicit renderer control. All four quarters/two zooms. Ground projection, occlusion and backend MAX are not claimed by this optical-plane fixture."}
    FileAccess.open("res://generated/light_range_render_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("LIGHT_RANGE_RENDER ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
