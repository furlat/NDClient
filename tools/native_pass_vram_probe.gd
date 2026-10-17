extends SceneTree
## Video memory of one spell appearance pass and of the shared receiver pass at
## a given screen size, measured as the renderer's own texture/video memory
## counters across their first render.
## Usage: --script res://tools/native_pass_vram_probe.gd -- [--size=1600x900] [--passes=3]
const Layer=preload("res://presentation/native_effect_layer.gd")
const Support=preload("res://presentation/native_scene_support.gd")

class Host extends Node3D:
    var camera:Camera3D

func _initialize()->void:run.call_deferred()

func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

func memory()->Dictionary:
    return {"texture_mib":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)/1048576.0,
        "video_mib":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)/1048576.0}

func settle()->void:
    for i in 4:
        await process_frame
        await RenderingServer.frame_post_draw

func run()->void:
    var size:=argument("--size","1600x900").split("x")
    root.size=Vector2i(int(size[0]),int(size[1]))
    var host:=Host.new();root.add_child(host)
    host.camera=Camera3D.new();host.add_child(host.camera);host.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;host.camera.size=12
    await settle()
    var before:=memory()
    var support:=Support.new();support.attach_shared(host)
    await settle()
    var after_support:=memory()
    support.set_enabled(false)
    var rows:Array=[]
    var last:=memory()
    for index in int(argument("--passes","3")):
        var layer:Dictionary=Layer.make(host,1<<(index+1));Layer.integrate(layer,support)
        await settle()
        var now:=memory()
        rows.append({"pass":index,"texture_mib":snappedf(now.texture_mib-last.texture_mib,0.01),"video_mib":snappedf(now.video_mib-last.video_mib,0.01)})
        last=now
    print("NATIVE_PASS_VRAM ",JSON.stringify({"size":root.size,"support_texture_mib":snappedf(after_support.texture_mib-before.texture_mib,0.01),
        "support_video_mib":snappedf(after_support.video_mib-before.video_mib,0.01),"appearance_passes":rows}))
    quit(0)
