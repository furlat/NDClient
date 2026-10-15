extends RefCounted
# Diagnostic state is a passive record. Phase values are inclusive elapsed CPU
# time; nested phases overlap and must not be added to their parent totals.
const HISTORY = 1800
const RECORDING_HISTORY = 60000
static func create() -> Dictionary:
    return {"phases":{},"frames":[],"cursor":0,"recording":false,"recorded":[],"recorded_total":0,"recorded_cursor":0,"last_usec":0,"started_usec":Time.get_ticks_usec(),"label":"interactive"}

static func end_phase(data: Dictionary, name: String, started: int) -> void:
    data.phases[name] = data.phases.get(name,0.0)+(Time.get_ticks_usec()-started)/1000.0

static func frame(data: Dictionary, viewport: Viewport, context: Dictionary) -> void:
    var now = Time.get_ticks_usec()
    if data.last_usec == 0:
        data.last_usec = now
        data.phases.clear()
        return
    var rid = viewport.get_viewport_rid()
    var sample = {"frame":Engine.get_process_frames(),"time_ms":(now-data.started_usec)/1000.0,
        "interval_start_us":data.last_usec,"interval_end_us":now,
        "frame_ms":(now-data.last_usec)/1000.0,"cpu_ms":data.phases.duplicate(),
        "render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),
        "render_setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),
        "gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),
        "draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
        "render_objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
        "primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
        "static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
        "video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
        "view":context}
    if data.frames.size()<HISTORY: data.frames.append(sample)
    else: data.frames[data.cursor]=sample
    data.cursor = (data.cursor+1)%HISTORY
    if data.recording:
        sample.pipeline_compilations=pipeline_compilations()
        if data.recorded.is_empty():
            data.recorded_total = 0
            data.recorded_cursor = 0
        if data.recorded.size() < RECORDING_HISTORY: data.recorded.append(sample)
        else: data.recorded[data.recorded_cursor] = sample
        data.recorded_cursor = (data.recorded_cursor+1)%RECORDING_HISTORY
        data.recorded_total += 1
    data.phases.clear()
    data.last_usec = now

static func distribution(values: Array) -> Dictionary:
    if values.is_empty(): return {}
    values.sort()
    var total=0.0
    for value in values: total+=value
    return {"mean":total/values.size(),"p50":values[int((values.size()-1)*0.5)],"p95":values[int((values.size()-1)*0.95)],"p99":values[int((values.size()-1)*0.99)],"max":values.back()}

static func pipeline_compilations()->Dictionary:
    # Cumulative native counters. Differences identify new programs/pipelines;
    # counts alone do not attribute elapsed time to GPU compilation.
    return {"canvas":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
        "mesh":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
        "surface":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
        "draw":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
        "specialization":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)}

static func save(data: Dictionary, viewport: Viewport, label: String = "", use_recording: bool = true) -> String:
    var samples: Array = data.recorded.duplicate() if use_recording and not data.recorded.is_empty() else data.frames.duplicate()
    samples.sort_custom(func(a,b): return a.frame < b.frame)
    var names = {}
    for sample in samples:
        for name in sample.cpu_ms: names[name]=true
    var phases = {}
    for name in names: phases[name] = distribution(samples.map(func(s):return s.cpu_ms.get(name,0.0)))
    var stamp=Time.get_datetime_string_from_system().replace(":","-")
    var path="res://generated/profiles/"+stamp+"-"+(label if not label.is_empty() else data.label)+".json"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://generated/profiles"))
    var result={"schema_version":1,"godot":Engine.get_version_info().string,
        "gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),
        "resolution":[viewport.get_visible_rect().size.x,viewport.get_visible_rect().size.y],
        "vsync_mode":DisplayServer.window_get_vsync_mode(),"display_refresh_hz":DisplayServer.screen_get_refresh_rate(),
        "timing_notes":"frame_ms measures intervals between process callbacks. CPU phase times are inclusive; children overlap parents. View context is sampled at interval end. Renderer CPU/GPU values are last available viewport timings and can lag this frame. Zero renderer timings mean unavailable or below resolution, not proof of no cost.",
        "sample_count":samples.size(),"recording_total":data.recorded_total,
        "recording_evicted":maxi(0,data.recorded_total-data.recorded.size()),"recording_capacity":RECORDING_HISTORY,"summary":{"frame_ms":distribution(samples.map(func(s):return s.frame_ms)),"cpu_ms":phases,
            "render_cpu_ms":distribution(samples.map(func(s):return s.render_cpu_ms)),"gpu_ms":distribution(samples.map(func(s):return s.gpu_ms)),
            "frames_over_10ms":samples.filter(func(s):return s.frame_ms>10.0).size(),"frames_over_16ms":samples.filter(func(s):return s.frame_ms>16.667).size(),
            "frames_over_33ms":samples.filter(func(s):return s.frame_ms>33.333).size(),"frames_over_100ms":samples.filter(func(s):return s.frame_ms>100).size()},"frames":samples}
    var file=FileAccess.open(path,FileAccess.WRITE)
    if file==null: return "Could not write profile: "+error_string(FileAccess.get_open_error())
    file.store_string(JSON.stringify(result,"  "))
    print("PROFILE_SAVED ",ProjectSettings.globalize_path(path))
    return ProjectSettings.globalize_path(path)
