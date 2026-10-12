extends RefCounted
const Placement = preload("res://placement.gd")
const TerrainBatches = preload("res://terrain_batches.gd")
# A background job receives only immutable placement/rectangle snapshots.
# All scene-node and rendering work stays on the main thread in bounded steps.
static func invalidate(world: Node) -> void:
    world.view_revision+=1
    if world.view_thread==null:world.view_build.clear()

static func prepare(snapshot: Array, quarter: int) -> Dictionary:
    var cache={}
    Placement.compose_exploration(snapshot,quarter,cache)
    cache.erase("merged_order")
    cache.erase("mobile_positions")
    return cache

static func step(world: Node) -> bool:
    var started=Time.get_ticks_usec()
    if world.view_build.is_empty():
        world.view_build={"revision":world.view_revision,"phase":"snapshot","cursor":0,"source":world.entries.duplicate(),"entries":[],"snapshot":[]}
    var state: Dictionary=world.view_build
    if state.phase=="snapshot":
        while state.cursor<state.source.size():
            var entry: Dictionary=state.source[state.cursor];state.cursor+=1
            if entry.get("retired",false) or not (entry.node.visible or entry.get("batched",false) or entry.get("pending_activation",false) or entry.get("mobile",false)):continue
            state.entries.append(entry)
            state.snapshot.append({"id":entry.id,"placement":entry.placement.duplicate(),"role":entry.role,
                "layer":entry.layer,"mobile":entry.get("mobile",false),"floor_group":entry.get("floor_group",false),"screen_rect":entry.screen_rect})
            if Time.get_ticks_usec()-started>4000:return false
        state.phase="sorting";state.started=Time.get_ticks_usec()
        world.view_thread=Thread.new()
        world.view_thread.start(prepare.bind(state.snapshot,world.quarter))
        return false
    if state.phase=="sorting":
        if world.view_thread.is_alive():return false
        var cache: Dictionary=world.view_thread.wait_to_finish()
        world.view_thread=null
        world.last_sort_job_ms=(Time.get_ticks_usec()-state.started)/1000.0
        if state.revision!=world.view_revision:
            world.view_build.clear()
            return false
        world.composition_cache=cache
        world.composition_cache.visible_entries=state.entries
        var result=Placement.compose_exploration(state.entries,world.quarter,cache)
        world.draw_order=result.order.map(func(index):return state.entries[index])
        world.unresolved=result.unresolved
        if not world.unresolved.is_empty():push_error("Composition cycle: "+str(world.unresolved))
        state.phase="publish";state.cursor=0
        return false
    if state.phase=="publish":
        while state.cursor<world.draw_order.size():
            var rank: int=state.cursor;var entry: Dictionary=world.draw_order[rank];state.cursor+=1
            entry.node.sorting_offset=rank*world.camera.far;entry.draw_rank=rank
            if entry.has("pending_activation"):
                entry.node.visible=entry.pending_activation;entry.erase("pending_activation")
            if Time.get_ticks_usec()-started>4000:return false
        # Entries whose selected source frame is hidden were not in the order.
        for entry in state.source:entry.erase("pending_activation")
        state.phase="batch";state.batch=TerrainBatches.begin(world)
        return false
    if state.phase=="batch":
        if not TerrainBatches.step(world,state.batch):return false
        world.batches_dirty=false
        world.composition_dirty=false
        world.view_build.clear()
        return true
    return false
