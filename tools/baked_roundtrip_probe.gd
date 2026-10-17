extends SceneTree
## Debug probe: play a baked clip in the capture world and read back what the
## playback shader produced, next to the recorded values for the same frame.
##   -- --clip=spells/fire_bolt/default/impact --frame=12
const Capture=preload("res://presentation/baked_effect_capture.gd")
const Baked=preload("res://presentation/baked_effect.gd")

func _initialize()->void:run.call_deferred()
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func run()->void:
    var arguments:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        var parts:PackedStringArray=argument.trim_prefix("--").split("=",true,1)
        arguments[parts[0]]=parts[1] if parts.size()>1 else "true"
    var id:String=arguments.get("clip","spells/fire_bolt/default/impact")
    var at:int=int(arguments.get("frame","12"))
    var bundle:Resource=load(Baked.path_for(id))
    print("bundle frames=",bundle.frames," systems=",bundle.systems.size())
    var capture=Capture.new();root.add_child(capture.viewport)
    var holder:=Node3D.new();capture.world.add_child(holder)
    var handle:Dictionary=Baked.make(holder,bundle,{"id":id},1<<1)
    print("make error='",handle.error,"'")
    var emitters:Array=bundle.systems.map(func(system):return handle.root.get_node(system.path))
    for particles in emitters:
        print(particles.name," amount=",particles.amount," emitting=",particles.emitting," lifetime=",particles.lifetime," local=",particles.local_coords," aabb=",particles.visibility_aabb," process=",particles.process_material.shader.resource_path," slot=",particles.process_material.get_shader_parameter("clock_slot")," vat=",particles.process_material.get_shader_parameter("vat"))
    capture.bind(emitters)
    handle.root.show()
    for step in 4:
        Baked.sample(handle,float(at)/bundle.rate);Baked.flush()
        capture.update_reference()
        await frame()
    var rows:Array=capture.read()
    for index in emitters.size():
        var vat:Image=bundle.systems[index].vat.get_image()
        for particle in mini(3,rows[index].size()):
            var state:Dictionary=rows[index][particle]
            var column:int=at-int(emitters[index].process_material.get_shader_parameter("vat_first"))
            var c:Color=vat.get_pixel(column,particle*6+3)
            print("   colour played=",state.colour," recorded=",c," custom played=",state.custom," recorded=",vat.get_pixel(column,particle*6+4))
            var life:Color=vat.get_pixel(column,particle*6+5)
            var x:Color=vat.get_pixel(column,particle*6);var y:Color=vat.get_pixel(column,particle*6+1);var z:Color=vat.get_pixel(column,particle*6+2)
            print("system ",index," particle ",particle," played origin=",state.transform.origin," alive=",state.written," | recorded alive=",life.r," start=",life.g," origin=",Vector3(x.a,y.a,z.a))
    print("clock texel=",Baked._clock_image.get_pixel(handle.slot,0))
    quit(0)
