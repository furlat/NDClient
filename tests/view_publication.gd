extends RefCounted
# Test-only wait at the same publication boundary used by production input.
static func finish(scene: Node, target: int) -> bool:
    scene.request_view(target)
    var deadline = Time.get_ticks_msec()+60000
    while scene.rotation_pending() and Time.get_ticks_msec()<deadline:
        if not scene.is_processing(): scene._prepare_rotation()
        await scene.get_tree().process_frame
    if scene.rotation_pending() or scene.quarter!=target: return false
    # Frozen fixtures also change camera focus, wall mode and visibility directly.
    # Run their ordinary presentation boundary after publication, including a
    # same-quarter request that correctly performs no source reconstruction.
    scene._sync_scenery(true)
    scene.update_wall_visibility()
    return true
