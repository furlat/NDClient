extends RefCounted
## Discarded performance candidate: exact visibility, but first-admission cost
## outweighed its small steady-pan saving. This is test-only evidence.
var static_receivers:Array=[]
var plane_to_screen:=Transform2D.IDENTITY
const CULL_BIN_SIZE = 4.0
var cull_bins: Dictionary = {}
var cull_visible: Dictionary = {}
var cull_half_extent := Vector2.ZERO
var cull_generation := 0
var cull_index_ready := false

func _visibility(receiver: Dictionary, screen: Rect2) -> bool:
    var shown: bool = receiver.entry.node.is_visible_in_tree() and (plane_to_screen*receiver.bounds).intersects(screen)
    if receiver.node.visible!=shown: receiver.node.visible=shown
    receiver.view_visible=shown
    if not receiver.dynamic:
        if shown: cull_visible[receiver.id]=receiver
        else: cull_visible.erase(receiver.id)
    return shown

func _cull_remove(receiver: Dictionary) -> void:
    if receiver.get("cull_generation",-1)==cull_generation:
        var cell: Vector2i=receiver.cull_cell
        cull_bins[cell].erase(receiver.id)
        if cull_bins[cell].is_empty(): cull_bins.erase(cell)
        receiver.erase("cull_generation"); receiver.erase("cull_cell")
    cull_visible.erase(receiver.id)

func _cull_put(receiver: Dictionary) -> void:
    var bounds: Rect2=receiver.bounds
    var cell=Vector2i((bounds.get_center()/CULL_BIN_SIZE).floor())
    if receiver.get("cull_generation",-1)==cull_generation and receiver.cull_cell!=cell:
        _cull_remove(receiver)
    if not cull_bins.has(cell): cull_bins[cell]={}
    cull_bins[cell][receiver.id]=receiver
    receiver.cull_generation=cull_generation; receiver.cull_cell=cell
    cull_half_extent=cull_half_extent.max(bounds.size*.5)
    if receiver.get("view_visible",false): cull_visible[receiver.id]=receiver

func _cull_rebuild() -> void:
    cull_bins.clear(); cull_visible.clear(); cull_half_extent=Vector2.ZERO
    cull_generation+=1
    for receiver in static_receivers: _cull_put(receiver)
    cull_index_ready=true

func _cull_candidates(screen: Rect2) -> Dictionary:
    # Original visibility intersects the transformed AABB, not the projected
    # quadrilateral. Expand by the exact maximum transformed half-extent before
    # inverse projection, so even that predicate's corner false positives stay.
    if is_zero_approx(plane_to_screen.determinant()):
        var all: Dictionary={}
        for receiver in static_receivers: all[receiver.id]=receiver
        return all
    var half=Vector2(absf(plane_to_screen.x.x)*cull_half_extent.x+absf(plane_to_screen.y.x)*cull_half_extent.y,
        absf(plane_to_screen.x.y)*cull_half_extent.x+absf(plane_to_screen.y.y)*cull_half_extent.y)
    var query: Rect2=plane_to_screen.affine_inverse()*Rect2(screen.position-half,screen.size+half*2)
    # Inclusive neighbouring bins make floating-point cell-edge rounding only
    # add candidates; the unchanged final predicate rejects them exactly.
    var first=Vector2i((query.position/CULL_BIN_SIZE).floor())-Vector2i.ONE
    var last=Vector2i((query.end/CULL_BIN_SIZE).floor())+Vector2i.ONE
    var candidates: Dictionary=cull_visible.duplicate()
    for x in range(first.x,last.x+1):
        for y in range(first.y,last.y+1):
            var cell=Vector2i(x,y)
            if cull_bins.has(cell): candidates.merge(cull_bins[cell])
    return candidates
