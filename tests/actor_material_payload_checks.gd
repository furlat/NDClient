extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Actors=preload("res://presentation/actor_construction.gd")
const Characters=preload("res://presentation/characters.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Profile=preload("res://frame_profile.gd")
const Catalog=preload("res://source_catalog.gd")
const Modular=preload("res://modular.gd")
var checks:int=0
var failures:Array=[]
var old:Script
var old_actors:Script
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func compare(a:ShaderMaterial,b:ShaderMaterial,label:String)->void:
    for field in a.shader.get_shader_uniform_list():check(a.get_shader_parameter(field.name)==b.get_shader_parameter(field.name),label+" "+str(field.name))
func _initialize()->void:run.call_deferred()
func material_key(value:Dictionary,textures:Dictionary,resources:Dictionary)->Array:
    return [Conditions.parameters(value,textures,resources)]
func material()->ShaderMaterial:
    var result=ShaderMaterial.new();result.shader=Actors.MODULAR_SHADER
    return result
func operand_transitions(item:Dictionary,cache:Dictionary)->void:
    var a=material();var b=material()
    var texture=ImageTexture.new();var textures:Dictionary={"/operand/noise":texture,"/operand/film":texture}
    var resources:Dictionary={"operand-noise":"/operand/noise","operand-film":"/operand/film"}
    var neutral=Conditions.material(item.id,[])
    var flash:Dictionary=item.value.duplicate(true)
    flash.flash.native_surface=texture;flash.flash.native_ramp=texture
    flash.flash.native_finishing=flash.flash.native_hit.get("finish_profile",{})
    flash.flash.material.palette={"noiseSheet":"operand-noise","gamma":1.2,"untinted":true}
    var film:Dictionary=neutral.duplicate(true)
    var recipes:Dictionary=Catalog.read_file("catalog/condition_recipes.json",cache)
    for recipe in recipes.values():
        var ramp:Variant=recipe.get("persistent",{}).get("bodyRamp")
        if ramp!=null and ramp.get("mapping")=="flowing_film":film.ramp=ramp.duplicate(true);break
    if not film.ramp.is_empty():film.ramp.texture="operand-film";film.time_ms=75.0
    var surface:Dictionary=neutral.duplicate(true)
    surface.body_surfaces={"layers":[{"provenance":"not_a_shader_operand"}],"missing":[],
        "parameters":{"body_surface_enabled":true,"body_surface_count":1,"body_surface_strength":PackedFloat32Array([.25,0,0,0,0,0,0,0])}}
    for value in [neutral,flash,film,surface,neutral]:
        old.bind(a,value,textures,resources)
        var key=material_key(value,textures,resources)
        Conditions.bind_parameters(b,key[0]);compare(a,b,"Finite native/film/surface/neutral operand transition")
    var key=material_key(surface,textures,resources).duplicate(true)
    surface.body_surfaces.parameters.body_surface_strength[0]=.75
    check(key[0].body_surface_strength[0]==.25,"Owned compact key isolates mutable packed surface operands")
    surface.body_surfaces.layers[0].provenance="changed"
    check(key[0].body_surface_strength[0]==.25,"Surface provenance never aliases material snapshot")
func benchmark(cases:Array)->Dictionary:
    var costs:Array=[[],[]]
    for iteration in 31:
        for mode in ([0,1] if iteration%2==0 else [1,0]):
            var began:int=Time.get_ticks_usec()
            for item in cases:
                var key:Array=old_actors.material_key(item.value,{},{}) if mode==0 else material_key(item.value,{},{})
                var snapshot:Array=key.duplicate(true)
                var previous:Array=item.previous[mode]
                for target in item.materials[mode]:
                    if previous!=key:
                        if mode==0:old.bind(target,item.value,{},{})
                        else:Conditions.bind_parameters(target,key[0])
                # The live owner keeps this exact compact/deep snapshot.
                if snapshot!=key:failures.append("Owned snapshot changed during binding")
            costs[mode].append((Time.get_ticks_usec()-began)/1000.0)
    return {"before_ms":Profile.distribution(costs[0]),"after_ms":Profile.distribution(costs[1]),"scope":"Actual17recipient-layer key projection/copy/comparison and complete uniform binding; excludes geometry/node work and GPU render time"}
func page(cases:Array,mode:int)->Dictionary:
    var view=SubViewport.new();view.size=Vector2i(320,192);view.own_world_3d=true;view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.0;camera.position=Vector3(0,.65,10);view.add_child(camera)
    var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=1.0;view.add_child(environment)
    var entries:Array=[]
    for actor_index in cases.size():
        var item:Dictionary=cases[actor_index]
        for layer_index in item.layers.size():
            var layer:Dictionary=item.layers[layer_index]
            var node=MeshInstance3D.new();node.mesh=QuadMesh.new();node.mesh.size=Vector2(1.1,1.1);node.position=Vector3((actor_index-.5)*1.2,.65,0)
            node.material_override=material();node.material_override.render_priority=layer_index
            node.material_override.set_shader_parameter("tint",Modular.rgb(layer.tint));node.material_override.set_shader_parameter("layer_alpha",layer.alpha)
            node.material_override.set_shader_parameter("shadow",layer.slot=="shadow")
            view.add_child(node);entries.append({"node":node,"layer":layer,"actor":item,"mode":mode})
    return {"view":view,"entries":entries}
func native(cases:Array)->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    var textures:Dictionary={}
    var pages:Array=[page(cases,0),page(cases,1)]
    for quarter in 4:
        for age in [0.0,50.0,100.0,200.0]:
            for frame in pages:
                for entry in frame.entries:
                    var item:Dictionary=entry.actor
                    var layer:Dictionary=entry.layer
                    var path:String=layer.paths[item.clip]
                    if not textures.has(path):
                        var image=Image.load_from_file(Catalog.media_path(path))
                        check(image!=null and not image.is_empty(),"Actual recipient sheet loads")
                        if image==null or image.is_empty():continue
                        textures[path]=ImageTexture.create_from_image(image)
                    var sheet:Texture2D=textures[path]
                    var rig:Dictionary=item.rig
                    var facing:String=["SW","NW","NE","SE"][quarter]
                    var source_frame:int=mini(1,int(rig.clips[item.clip].frames)-1)
                    var output:ShaderMaterial=entry.node.material_override
                    output.set_shader_parameter("sheet",sheet)
                    output.set_shader_parameter("frame_uv",Vector4(float(source_frame*rig.cell_width)/sheet.get_width(),float(rig.facing_rows[facing]*rig.cell_height)/sheet.get_height(),float(rig.cell_width)/sheet.get_width(),float(rig.cell_height)/sheet.get_height()))
                    var samples:Array=[]
                    for source in item.samples:
                        if age>=source.duration_ms:continue
                        var sample=source.duplicate();sample.age_ms=age;samples.append(sample)
                    var value=Conditions.material(item.id,samples)
                    if entry.mode==0:old.bind(output,value,{},{})
                    else:Conditions.bind_parameters(output,Conditions.parameters(value,{},{}))
            await process_frame;await RenderingServer.frame_post_draw
            await process_frame;await RenderingServer.frame_post_draw
            var a:Image=pages[0].view.get_texture().get_image();var b:Image=pages[1].view.get_texture().get_image()
            check(a.get_data()==b.get_data(),"Exact actual17layer receiver pixels view%d age%.0f"%[quarter,age])
            check(a.get_used_rect().has_area(),"Actual authored recipient pixels are present")
    for frame in pages:frame.view.queue_free()
    await process_frame;await RenderingServer.frame_post_draw
func run()->void:
    create_timer(90).timeout.connect(func():quit(2))
    var dir="";var old_path="";var old_actor_path="";var render:bool=false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):dir=arg.trim_prefix("--recording=")
        if arg.begins_with("--conditions-oracle="):old_path=arg.trim_prefix("--conditions-oracle=")
        if arg.begins_with("--actor-oracle="):old_actor_path=arg.trim_prefix("--actor-oracle=")
        if arg=="--native":render=true
    if dir.is_empty() or old_path.is_empty() or old_actor_path.is_empty():printerr("Requires real journal and immediate conditions/actor oracles");quit(2);return
    old=load(old_path);old_actors=load(old_actor_path)
    var protocol=Protocol.new();var cache:Dictionary={};var reports:Array=[];var render_cases:Array=[]
    var decoded=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(dir+"/0000000000000000.json"))
    check(decoded.ok,"Actual initialization admits")
    var normalized=protocol.normalize("InitializationResponse",decoded.value)
    var state:Dictionary=Reducer.reduce_initialization(normalized.initialization,normalized.content_additions).value
    for sequence in range(1,7):
        decoded=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(dir+"/%016d.json"%sequence));check(decoded.ok,"Actual operation admits")
        normalized=protocol.normalize("PlayerOperation",decoded.value)
        var reduced=Reducer._reduce_operation_recorded(state,normalized)
        var compiled=Compiler.compile_recorded(state,normalized,cache,reduced.value,reduced.transitions);check(compiled.ok,"Actual transitions compile")
        if sequence<5:state=reduced.value;continue
        var source_bytes=var_to_bytes(compiled.value.groups)
        var sources:Array=[];var ids:Dictionary={}
        for group in compiled.value.groups:
            for component in group.components:
                if component.kind=="material_flash":sources.append(component);ids[component.actor_uuid]=true
        var current:Array=[];var previous:Array=[]
        for source in sources:
            var sample=source.duplicate();sample.age_ms=minf(50.0,source.duration_ms*.5);current.append(sample)
            sample=sample.duplicate();sample.age_ms-=1;previous.append(sample)
        var cases:Array=[];var layer_count:int=0
        var index:Dictionary=Characters._read("catalog-index.json",cache)
        var rigs:Dictionary=Characters._read(index.rigs,cache)
        for id in ids:
            var selected=Characters.resolve(state.actors[id],state,cache);check(selected.ok and selected.value!=null,"Actual recipient resolves")
            var rig:Dictionary=rigs[selected.value.rig]
            var layers=Characters.layers(selected.value,rig,cache);layer_count+=layers.size()
            var value=Conditions.material(id,current);var prior=Conditions.material(id,previous)
            var new_key=material_key(value,{},{});var old_key=old_actors.material_key(value,{},{})
            var materials:Array=[[],[]]
            for layer in layers:
                var a=material();var b=material()
                old.bind(a,value,{},{});Conditions.bind_parameters(b,new_key[0]);compare(a,b,"Actual recipient full uniform parity")
                materials[0].append(a);materials[1].append(b)
            cases.append({"id":id,"value":value,"layers":layers,"rig":rig,"clip":"TakeDamage" if rig.clips.has("TakeDamage") else "Idle",
                "samples":sources,"materials":materials,"previous":[old_actors.material_key(prior,{},{}).duplicate(true),material_key(prior,{},{}).duplicate(true)]})
            var snapshot=new_key.duplicate(true);value.flash.age_ms+=10
            check(snapshot!=material_key(value,{},{}),"Age-dependent actual uniforms invalidate compact snapshot")
            value.flash.age_ms-=10
            var decorated:Dictionary=value.flash
            var original:Variant=decorated.get("native_hit")
            decorated.native_hit={"unconsumed_metadata":true}
            check(snapshot==material_key(value,{},{}),"Unconsumed native-hit authoring metadata stays outside condition key")
            if original==null:decorated.erase("native_hit")
            else:decorated.native_hit=original
            check(var_to_bytes(snapshot).size()<var_to_bytes(old_key).size(),"Compact key excludes authored provenance")
        check(layer_count==17,"Actual Fireball recipient outfits contain seventeen layers")
        operand_transitions(cases[0],cache)
        reports.append({"sequence":sequence,"layers":layer_count,"timing":benchmark(cases)})
        check(var_to_bytes(compiled.value.groups)==source_bytes,"Projection and binding leave compiled source immutable")
        if render_cases.is_empty():render_cases=cases
        state=reduced.value
    if render:await native(render_cases)
    var report={"checks":checks,"failures":failures,"records":reports,"native":render,"scope":"Actual compiled Fireball17recipient layers, complete source-shader uniform equality, compact snapshot isolation, original versus projected key+uniform CPU comparison; optional4view native authored-sheet pixel oracle"}
    FileAccess.open("res://.runtime/actor-material-payload-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ACTOR_MATERIAL_PAYLOAD ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
