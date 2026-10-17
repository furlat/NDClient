extends SceneTree
## Native spell source construction latency, first and repeated use, in a fresh
## process. Per clip: frames and milliseconds until Factory.prepare admits it
## (resource loads, program jobs, draw fences), then two constructions with
## their phases and the first draw of each in a private viewport.
## Usage: --script res://tools/native_construction_probe.gd -- [--spells=spell.magic_missile,spell.shield]
const Factory=preload("res://presentation/native_factory_source.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
const Profile=preload("res://frame_profile.gd")

func _initialize()->void:run.call_deferred()

func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

func compiled()->int:
    var total:=0
    for value in Profile.pipeline_compilations().values():total+=int(value)
    return total

func frame()->float:
    var started:=Time.get_ticks_usec()
    await process_frame
    return (Time.get_ticks_usec()-started)/1000.0

func run()->void:
    root.size=Vector2i(1280,720)
    var host:=Node3D.new();root.add_child(host)
    var camera:=Camera3D.new();host.add_child(camera)
    var view:=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true;view.transparent_bg=true
    view.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(view)
    var eye:=Camera3D.new();eye.projection=Camera3D.PROJECTION_ORTHOGONAL;eye.size=8;eye.cull_mask=Factory.DEFAULT_LAYER
    eye.position=Vector3(0,0,10);view.add_child(eye)
    var parent:=Node3D.new();view.add_child(parent)
    for i in 5:await process_frame
    var catalog:Dictionary={}
    var cache:Dictionary={}
    for behavior in argument("--spells","spell.magic_missile,spell.shield").split(","):
        var clips:Array=Authoring.selection(behavior,catalog).get("clips",[])
        for clip in clips:
            var started:=Time.get_ticks_usec();var frames:=0;var worst:=0.0
            var loading:Dictionary=Factory.prepare([clip],cache)
            while not loading.ready and loading.errors.is_empty() and frames<2000:
                worst=maxf(worst,await frame());frames+=1
                loading=Factory.prepare([clip],cache)
            var admitted_ms:=(Time.get_ticks_usec()-started)/1000.0
            var rows:Array=[]
            for attempt in 2:
                for i in 3:await process_frame
                while not Factory.Admission.can_mutate():await process_frame
                var before:=compiled()
                var made:=Time.get_ticks_usec()
                var handle:Dictionary=Factory.make(parent,clip.duplicate(true))
                var make_ms:=(Time.get_ticks_usec()-made)/1000.0
                if not handle.error.is_empty():rows.append({"error":handle.error});Factory.close(handle);break
                handle.root.show()
                Factory.sample(handle,0.2,1.0/60.0)
                view.render_target_update_mode=SubViewport.UPDATE_ONCE
                var drawn:=await frame()
                rows.append({"make_ms":snappedf(make_ms,0.01),"phases":handle.construction_phases,"draw_frame_ms":snappedf(drawn,0.1),"pipelines":compiled()-before})
                Factory.close(handle)
            print("NATIVE_CONSTRUCTION ",JSON.stringify({"spell":behavior,"clip":clip.get("id",""),"admit_frames":frames,"admit_ms":snappedf(admitted_ms,0.1),
                "admit_worst_frame_ms":snappedf(worst,0.1),"errors":loading.errors,"constructions":rows}))
    quit(0)
