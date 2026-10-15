extends SceneTree
## Real offline recording admission and media planning, without a render host.
const Recording=preload("res://studio/recording.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")

func _initialize()->void:run.call_deferred()

func run()->void:
    var path="res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--recording="):path=arg.trim_prefix("--recording=")
    var index:Dictionary=Recording.read(path)
    if not index.ok:printerr(index);quit(1);return
    var started=Time.get_ticks_usec()
    var media:Dictionary=RecordingMedia.plan(index)
    var report={"recording":path,"read_ms":index.compile_ms,"read_profile":index.read_profile,
        "media_ms":(Time.get_ticks_usec()-started)/1000.0,"groups":index.groups.size(),
        "rows":index.rows.size(),"errors":media.errors,"media_profile":media.get("profile",{})}
    FileAccess.open("res://.runtime/studio-loading-profile.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_LOADING_PROFILE ",JSON.stringify(report))
    quit(0 if media.errors.is_empty() else 1)
