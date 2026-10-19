extends RefCounted
## Passive metadata only. A pool preparation may await this one read without
## scheduling another pool task; no scene, texture or presentation clock lives here.
static func _read(path:String,cache_mode:ResourceLoader.CacheMode,profile:Dictionary)->Resource:
    var began:int=Time.get_ticks_usec() if not profile.is_empty() else 0
    var value:Resource=ResourceLoader.load(path,"",cache_mode)
    if began>0:profile.native_read_usec=Time.get_ticks_usec()-began
    return value

static func read(path:String,cache_mode:ResourceLoader.CacheMode,profile:Dictionary={})->Resource:
    if Thread.is_main_thread():return _read(path,cache_mode,profile)
    # ResourceLoader.load() from a pool task schedules another pool task.
    # Admission callers can exhaust that pool while awaiting a shared owner.
    # A Godot Thread reads synchronously without that dependency or Godot 4.7's
    # nested loader token leak: https://github.com/godotengine/godot/pull/121025
    var began:int=Time.get_ticks_usec() if not profile.is_empty() else 0
    var thread:=Thread.new()
    var error:Error=thread.start(_read.bind(path,cache_mode,profile))
    if error!=OK:return null
    var launch_usec:int=Time.get_ticks_usec()-began if began>0 else 0
    var value:Resource=thread.wait_to_finish() as Resource
    # The read thread is joined before the caller writes this private profile.
    if began>0:
        profile.thread_start_usec=launch_usec
        profile.thread_total_usec=Time.get_ticks_usec()-began
    return value
