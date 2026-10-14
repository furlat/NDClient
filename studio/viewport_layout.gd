extends RefCounted
## Pane geometry changes the visible area, not the user's orthographic pixel zoom.

static func resize(viewport: SubViewport, camera: Camera3D, pane_size: Vector2) -> bool:
    var target=Vector2i(maxi(1,int(pane_size.x)),maxi(1,int(pane_size.y)))
    var previous=viewport.size
    if target==previous:return false
    if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:
        var old_extent=previous.y if camera.keep_aspect==Camera3D.KEEP_HEIGHT else previous.x
        var new_extent=target.y if camera.keep_aspect==Camera3D.KEEP_HEIGHT else target.x
        if old_extent>0:camera.size*=float(new_extent)/old_extent
    viewport.size=target
    return true
