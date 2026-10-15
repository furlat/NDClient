extends SceneTree
## Actual prepared Fireball/Acid keep procedural image pixels while recipient
## materials/clocks stay private; animated procedural resources stay private.
const Factory=preload("res://presentation/native_factory_source.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func walk(value:Variant,seen:Dictionary,materials:Array,noises:Array)->void:
    if value is Resource:
        if seen.has(value):return
        seen[value]=true
        if value is Material:materials.append(value)
        if value is NoiseTexture2D:noises.append(value);return
        if value is Shader or value is Script or value is Texture2D:return
        if value is Mesh:
            for surface in value.get_surface_count():walk(value.surface_get_material(surface),seen,materials,noises)
        for field in value.get_property_list():
            if int(field.usage)&PROPERTY_USAGE_STORAGE:
                var child:Variant=value.get(field.name)
                if child is Resource or child is Array or child is Dictionary:walk(child,seen,materials,noises)
    elif value is Array or value is Dictionary:
        for child in (value if value is Array else value.values()):walk(child,seen,materials,noises)
func resources(handle:Dictionary)->Dictionary:
    var materials:Array=[];var noises:Array=[];var seen:Dictionary={}
    for piece in handle.geometry:
        walk(piece.node.material_override,seen,materials,noises)
        walk(piece.node.material_overlay,seen,materials,noises)
        if piece.node is MeshInstance3D:walk(piece.node.mesh,seen,materials,noises)
        if piece.node is GPUParticles3D:
            walk(piece.node.process_material,seen,materials,noises)
            for index in piece.node.draw_passes:walk(piece.node.get_draw_pass_mesh(index),seen,materials,noises)
    return {"materials":materials,"noises":noises}
func synthetic(path:String,adapter:String="clocked_source",unknown_driver:bool=false,method_track:bool=false)->bool:
    var component=Node3D.new();var mesh=MeshInstance3D.new();mesh.name="Mesh";component.add_child(mesh)
    var texture=NoiseTexture2D.new();texture.noise=FastNoiseLite.new();texture.color_ramp=Gradient.new();texture.resource_local_to_scene=true
    var material=ShaderMaterial.new();material.shader=Shader.new();material.shader.code="shader_type spatial; uniform sampler2D noise;"
    material.set_shader_parameter("noise",texture);mesh.material_override=material
    if unknown_driver:
        var driver=Node3D.new();var script=GDScript.new();script.source_code="extends Node3D\n";script.reload();driver.set_script(script);component.add_child(driver)
    if not path.is_empty():
        var player=AnimationPlayer.new();component.add_child(player)
        var animation=Animation.new();var track:int=animation.add_track(Animation.TYPE_METHOD if method_track else Animation.TYPE_VALUE)
        animation.track_set_path(track,NodePath(path))
        if method_track:animation.track_insert_key(track,0,{"method":"show","args":[]})
        else:animation.track_insert_key(track,0,1);animation.track_insert_key(track,1,2)
        var library=AnimationLibrary.new();library.add_animation("source",animation);player.add_animation_library("",library)
    Variants._share_constant_noise(component,{"script":Variants.PREFIX+"recipient/"+adapter+".gd"},{texture:true})
    var shared:bool=not texture.resource_local_to_scene
    component.free();return shared
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    create_timer(90).timeout.connect(func():printerr("NOISE_CHECK deadline");quit(2))
    for adapter in Variants.CONSTANT_NOISE_ADAPTERS:
        check(synthetic("",adapter),"Unanimated clock-only procedural texture may share: "+adapter)
        check(not synthetic("Mesh:material_override:shader_parameter/noise:noise:seed",adapter),"Animated noise seed remains per-instance: "+adapter)
        check(not synthetic("Mesh:material_override:shader_parameter/noise:color_ramp:offsets",adapter),"Animated procedural gradient remains per-instance: "+adapter)
    check(not synthetic("","clocked_source",true),"Unknown runtime controller keeps procedural contents private")
    check(not synthetic("Mesh","clocked_source",false,true),"Native method animation keeps procedural contents private")
    check(not synthetic("","silk_area"),"Unaudited adapter retains private procedural resources")
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    var expected:Dictionary={"spells/fireball/fire/lifecycle":2,"spells/acid_splash/default/impact":6,"spells/acid_splash/default/travel":1}
    var all_sources:bool="--all-sources" in OS.get_cmdline_user_args()
    var clips:Array=[]
    for spell in manifest.spells:
        for item in spell.clips:
            if all_sources or expected.has(item.id):clips.append(item)
    check(clips.size()>=expected.size() if all_sources else clips.size()==expected.size(),"Requested original source definitions are present")
    var cache:Dictionary={}
    while true:
        var loaded:Dictionary=Factory.prepare(clips,cache)
        if not loaded.errors.is_empty():failures.append_array(loaded.errors);break
        if loaded.ready:break
        await process_frame;await RenderingServer.frame_post_draw
    for clip in clips if failures.is_empty() else []:
        var owner=Node3D.new();root.add_child(owner)
        var original:Dictionary=Factory.make(owner,clip.duplicate(true),0,false)
        var current:Dictionary=Factory.make(owner,clip.duplicate(true),0)
        var peer:Dictionary=Factory.make(owner,clip.duplicate(true),0)
        check(original.error.is_empty() and current.error.is_empty() and peer.error.is_empty(),"Actual original and private prepared sources construct")
        if original.error.is_empty() and current.error.is_empty() and peer.error.is_empty():
            var a:Dictionary=resources(original);var b:Dictionary=resources(current);var c:Dictionary=resources(peer)
            check(a.noises.size()==b.noises.size() and b.noises.size()==c.noises.size(),"Actual selected procedural image inventory preserved: "+clip.id)
            if not all_sources:check(a.noises.size()==expected[clip.id],"Known original noise count: "+clip.id)
            check(b.materials.size()==c.materials.size(),"Private occurrence material inventories match")
            for index in b.materials.size():check(not is_same(b.materials[index],c.materials[index]),"Recipient material remains private "+str(index))
            for index in b.noises.size():
                check(is_same(b.noises[index],c.noises[index]) if not b.noises[index].resource_local_to_scene else not is_same(b.noises[index],c.noises[index]),"Declared procedural image ownership retained: "+clip.id+" / "+str(index))
            await process_frame;await RenderingServer.frame_post_draw
            for age in [0.0,.2,.7,1.2]:
                Factory.sample(original,age,0);Factory.sample(current,age,0);Factory.sample(peer,age*.5,0)
                await process_frame;await RenderingServer.frame_post_draw
                for index in b.noises.size():
                    var source:Image=a.noises[index].get_image();var prepared:Image=b.noises[index].get_image()
                    check(source!=null and prepared!=null and source.get_data()==prepared.get_data(),clip.id+" original generated noise bytes retained at "+str(age)+" / "+str(index))
                check(current.age==age and peer.age==age*.5,"Independent native occurrence clocks at "+str(age))
            a.clear();b.clear();c.clear()
        Factory.close(original);Factory.close(current);Factory.close(peer);owner.queue_free()
        await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"source_count":clips.size(),"scope":"Actual selected native sources generated pixels/private materials/clocks plus static/animated procedural resource ownership. No source artistic or timing changes."}
    FileAccess.open("res://.runtime/native-source-noise"+("-all" if all_sources else "")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_NOISE_CHECK_COMPLETE ",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
