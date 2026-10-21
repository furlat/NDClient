extends RefCounted
## Passive metadata only. A pool preparation may await this one read without
## scheduling another pool task; no scene, texture or presentation clock lives here.
static var _read_mutex:=Mutex.new()
static func _read(path:String,cache_mode:ResourceLoader.CacheMode,profile:Dictionary)->Resource:
    var began:int=Time.get_ticks_usec() if not profile.is_empty() else 0
    # All passive domains share native Resource/Script admission. Acquire on
    # the actual reader, never on a pool caller waiting for that reader.
    _read_mutex.lock()
    var admitted:int=Time.get_ticks_usec() if began>0 else 0
    var value:Resource=ResourceLoader.load(path,"",cache_mode)
    _read_mutex.unlock()
    if began>0:
        profile.native_reader_wait_usec=admitted-began
        profile.native_read_usec=Time.get_ticks_usec()-admitted
    return value

static func read(path:String,cache_mode:ResourceLoader.CacheMode,profile:Dictionary={})->Resource:
    # A finite dedicated metadata job already owns a safe reader. Only pool
    # callers need the separate reader that avoids nested ResourceLoader tasks.
    if Thread.is_main_thread() or (WorkerThreadPool.get_caller_task_id()<0 and WorkerThreadPool.get_caller_group_id()<0):
        return _read(path,cache_mode,profile)
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
