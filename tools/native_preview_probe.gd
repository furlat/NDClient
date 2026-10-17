extends SceneTree
## Per-occurrence cost of a native-source presenter (blood hits, class effects):
## configure + bind_receiving + first draw, repeated, in a fresh process.
## Usage: --script res://tools/native_preview_probe.gd -- [--sources=blood.hit_a1,class.rage.mantle] [--repeats=3]
const Preview=preload("res://presentation/native_effect_preview.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
const Profile=preload("res://frame_profile.gd")

func _initialize()->void:run.call_deferred()

func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

func compiled()->Dictionary:return Profile.pipeline_compilations()

func run()->void:
    root.size=Vector2i(1280,720)
    var owner:=Node3D.new();root.add_child(owner)
    var camera:=Camera3D.new();owner.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=6.0;camera.current=true
    var basis:=Basis.looking_at(Vector3(-6,-sqrt(24.0),-6))
    camera.basis=basis;camera.position=basis.z*12.0
    var lights:=Lighting.new()
    var cache:Dictionary={}
    for i in 5:await process_frame
    for id in argument("--sources","blood.hit_a1,class.rage.mantle").split(","):
        for attempt in int(argument("--repeats","3")):
            var before:=compiled();var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
            var preview:=Preview.new();owner.add_child(preview)
            var started:=Time.get_ticks_usec()
            var loading:Dictionary=Preview.Sources.prepare([id],cache)
            while not loading.ready and loading.errors.is_empty():
                await process_frame;loading=Preview.Sources.prepare([id],cache)
            while not Preview.Sources.Admission.can_mutate():await process_frame
            started=Time.get_ticks_usec()
            var issue:=preview.configure(id,cache,73+attempt)
            var configure_ms:=(Time.get_ticks_usec()-started)/1000.0
            started=Time.get_ticks_usec()
            if issue.is_empty():issue=preview.bind_receiving()
            var bind_ms:=(Time.get_ticks_usec()-started)/1000.0
            var record:Dictionary=preview.record;var ppu:=float(record.get("pixels_per_unit",1))
            var context:={"screen_origin":Vector2(400,200),"pixel_scale":1.0,"light_cap":1.0,"supports":[Transform3D(Basis.from_scale(Vector3(3,1,3)),Vector3.ZERO)]}
            var frame_ms:Array=[]
            for frame in 4:
                var at:=Time.get_ticks_usec()
                preview.sample(.2+frame/60.0,basis,Vector3.ZERO,1.0,[],context)
                await process_frame
                frame_ms.append(snappedf((Time.get_ticks_usec()-at)/1000.0,0.1))
            var after:=compiled();var delta:={}
            for key in after:if int(after[key])!=int(before.get(key,0)):delta[key]=int(after[key])-int(before.get(key,0))
            var viewports:=preview.find_children("*","SubViewport",true,false).size()
            print("NATIVE_PREVIEW ",JSON.stringify({"source":id,"attempt":attempt,"error":issue,"configure_ms":snappedf(configure_ms,0.01),"bind_receiving_ms":snappedf(bind_ms,0.01),
                "frames_ms":frame_ms,"pipelines":delta,"viewports":viewports,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))-nodes}))
            preview.close();preview.queue_free()
            for i in 3:await process_frame
    quit(0)
