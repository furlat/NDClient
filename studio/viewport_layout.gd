extends RefCounted
const Placement=preload("res://placement.gd")
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

## Passive current-source envelope in camera-plane world units. Camera focus
## and viewport extent do not enter the bound, so resize alone cannot refit it.
static func body_bounds(owner:Node3D)->Variant:
    var found:bool=false
    var bounds:Rect2
    var inverse:Basis=owner.camera.global_basis.inverse()
    for actor in owner.visual_actors.values():
        # Cached actual scale operations conservatively include restoration.
        # Framing does not sample fade alpha/UV or speculate future owners.
        var scale:Dictionary=actor.get("sampled_pose",{}).get("body_scale",{})
        var actual:float=float(scale.get("factor",1.0));var maximum:float=1.0
        if actual<=0.0:continue
        for operation in scale.get("owners",[]):maximum*=maxf(1.0,float(operation.authored_factor))
        var growth:float=maxf(1.0,maximum/actual)
        for entry in actor.get("entries",[]):
            if entry.role=="shadow" or not entry.actor_layer.get("effect",{}).is_empty():continue
            var node:MeshInstance3D=entry.node
            if not node.is_visible_in_tree() or node.mesh==null:continue
            var parameters:Dictionary=entry.get("source_parameters",{})
            if float(parameters.get("layer_alpha",1.0))*float(parameters.get("condition_alpha",1.0))<=0.0:continue
            var local:AABB=node.custom_aabb
            if local==AABB():local=node.mesh.get_aabb()
            # Native admission already owns the registered reference mesh for
            # all clip banks. UV animation never needs another framing scan.
            var reference:Dictionary=entry.get("native_shapes",{}).get("",{})
            if not reference.is_empty():local=local.merge(reference.mesh.get_aabb())
            var model:Transform3D=node.global_transform
            if growth>1.0:
                var anchor:Vector3=Placement.contact(actor.row)
                model=Transform3D(model.basis.scaled_local(Vector3.ONE*growth),anchor+(model.origin-anchor)*growth)
            for corner in 8:
                var point:Vector3=inverse*(model*local.get_endpoint(corner))
                var projected:=Vector2(point.x,point.y)
                bounds=bounds.expand(projected) if found else Rect2(projected,Vector2.ZERO)
                found=true
    return bounds if found else null

## Grow only, then translate only far enough to contain the admitted envelope.
## The caller owns automatic/manual intent and the ordinary candidate draw.
static func body_frame(camera:Camera3D,extent:Vector2i,bounds:Rect2,focus:Vector3,size:float)->Dictionary:
    var aspect:float=float(maxi(1,extent.x))/maxi(1,extent.y)
    var height:float=maxf(bounds.size.y,bounds.size.x/aspect)
    var needed:float=height if camera.keep_aspect==Camera3D.KEEP_HEIGHT else height*aspect
    var fitted:float=maxf(size,needed)
    var span:=Vector2(fitted*aspect,fitted) if camera.keep_aspect==Camera3D.KEEP_HEIGHT else Vector2(fitted,fitted/aspect)
    var inverse:Basis=camera.global_basis.inverse()
    var origin:Vector3=inverse*focus
    var offset:=Vector2(clampf(origin.x,bounds.end.x-span.x*.5,bounds.position.x+span.x*.5)-origin.x,
        clampf(origin.y,bounds.end.y-span.y*.5,bounds.position.y+span.y*.5)-origin.y)
    return {"size":fitted,"focus":focus+camera.global_basis.x*offset.x+camera.global_basis.y*offset.y}
