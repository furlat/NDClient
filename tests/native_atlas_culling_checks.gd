extends SceneTree
## Discarded performance alternative; pure broad-phase proof against the unchanged Godot transformed-AABB predicate.
const Atlas=preload("res://tests/native_atlas_culling_candidate.gd")
var atlas=Atlas.new()
var checks:int=0
var failures:Array=[]
var parent:Node3D
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label)
func receiver(id:String,bounds:Rect2)->Dictionary:
    var source=Node3D.new();parent.add_child(source)
    var sprite=Sprite2D.new();sprite.visible=false;root.add_child(sprite)
    return {"id":id,"bounds":bounds,"entry":{"node":source},"node":sprite,"dynamic":false,"view_visible":false}
func verify(screen:Rect2,label:String)->void:
    var expected:Dictionary={}
    for row in atlas.static_receivers:
        if row.entry.node.is_visible_in_tree() and (atlas.plane_to_screen*row.bounds).intersects(screen):expected[row.id]=true
    var candidates=atlas._cull_candidates(screen)
    var actual:Dictionary={}
    for row in candidates.values():
        if atlas._visibility(row,screen):actual[row.id]=true
    check(actual.size()==expected.size(),label+" count")
    for id in expected:check(actual.has(id),label+" exact original visibility "+id)
    for row in atlas.static_receivers:check(row.node.visible==expected.has(row.id),label+" node visibility "+row.id)
func run()->void:
    parent=Node3D.new();root.add_child(parent)
    for x in range(-12,13):
        for y in range(-8,9):
            var size=Vector2(0.1+posmod(x+3*y,5)*.7,0.1+posmod(2*x-y,4)*.8)
            atlas.static_receivers.append(receiver(str(x)+":"+str(y),Rect2(Vector2(x*2,y*2),size)))
    for bounds in [Rect2(-41,-.01,82,.02),Rect2(-.01,-32,.02,64),Rect2(-4,-4,0,0),Rect2(-4.00001,-4,.00002,.01)]:
        atlas.static_receivers.append(receiver("edge"+str(atlas.static_receivers.size()),bounds))
    atlas._cull_rebuild()
    var transforms=[Transform2D(0.0,Vector2(32,24)),Transform2D(.785,Vector2(32,24)),Transform2D(Vector2(4,.2),Vector2(.35,5),Vector2(32,24)),Transform2D(Vector2(-3,0),Vector2(0,2),Vector2(32,24))]
    for i in transforms.size():
        atlas.plane_to_screen=transforms[i]
        for offset in [Vector2.ZERO,Vector2(-.00001,.00001),Vector2(84,-32),Vector2(-120,40)]:
            verify(Rect2(offset,Vector2(64,48)),"affine "+str(i)+" "+str(offset))
    # New/replaced/moved rows update only their actual admitted bounds.
    var old=atlas.static_receivers.pop_back();atlas._cull_remove(old)
    old.node.free();old.entry.node.free()
    var replacement=receiver(old.id,Rect2(-1,-1,3,2));atlas.static_receivers.append(replacement);atlas._cull_put(replacement)
    atlas.plane_to_screen=Transform2D(0.0,Vector2(32,24));verify(Rect2(0,0,64,48),"same-count replacement")
    replacement.bounds=Rect2(500,500,2,2);atlas._cull_put(replacement);verify(Rect2(0,0,64,48),"moved receiver leaves prior view")
    parent.visible=false;verify(Rect2(0,0,64,48),"hidden source parent")
    parent.visible=true;verify(Rect2(0,0,128,96),"resized viewport and revealed parent")
    atlas._cull_rebuild();verify(Rect2(0,0,64,48),"basis/index rebuild")
    check(atlas.cull_bins.size()<atlas.static_receivers.size(),"Index owns spatial bins, not a second scene")
    var report={"production_enabled":false,"checks":checks,"failures":failures,"scope":"Exact original transformed-AABB/node visibility predicate; affine/quarter-like transforms, negative and boundary coordinates, oversized and zero-area bounds, replacement/movement/removal, inherited visibility, resize and rebuild. CPU broad-phase proof, not gameplay or framebuffer qualification."}
    FileAccess.open("res://.runtime/native-atlas-culling-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report))
    print("ATLAS_CULLING ",JSON.stringify(report))
    for row in atlas.static_receivers:row.node.free()
    parent.free();quit(0 if failures.is_empty() else 1)
