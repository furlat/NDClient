extends SceneTree
# Headless native-data boundary: prepared sight/order versus independent current
# state and full ordering. Pixel acceptance remains the recorded-world GPU lane.
const Preparation = preload("res://presentation/world_preparation.gd")
const Order = preload("res://grid_order.gd")
class Probe extends "res://play.gd":
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false)
        add_child(context_menu)
        camera = Camera3D.new(); add_child(camera)
    func _process(_delta: float) -> void: pass
var checks = 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("PREPARED_ADMISSION_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func entry(scene: Node, id: String, x: int) -> Dictionary:
    var node = MeshInstance3D.new(); node.mesh = QuadMesh.new(); scene.add_child(node)
    var material = ShaderMaterial.new(); material.shader = scene.ENVIRONMENT_SHADER
    node.material_override = material
    return {"id":id,"placement":{"id":id,"kind":"terrain","position":[x,0],"base_height_steps":0},
        "node":node,"material":material,"role":"terrain","layer":0}
func receipt(scene: Node, visibility: Dictionary, changes: Dictionary) -> Dictionary:
    return {"visibility":visibility,"visible_cells":{"1,0":true},"base":scene.scenery_visibility,
        "changes":changes,"revision":scene.timeline.world_revision,"generation":scene.world_generation,
        "quarter":scene.world_quarter,"epoch":scene.timeline.initialization_revision}
func reset_sight(scene: Node) -> void:
    scene.scenery_visibility = {"a":true}; scene.scenery_visible_cells = {"0,0":true}
    scene.scenery_revision = -1; scene.scenery_new_consumers = {}
    for value in scene.static_entries:
        value.scenery_value = 1.0 if value.placement.id=="a" else 0.0
        value.material.set_shader_parameter("current_visibility",value.scenery_value)
func assert_sight(scene: Node, label: String) -> void:
    check(scene.scenery_visibility=={"b":true} and scene.scenery_visible_cells=={"1,0":true},label+" exact admitted sight")
    check(scene.static_entries.all(func(value):return value.material.get_shader_parameter("current_visibility")== (1.0 if value.placement.id=="b" else 0.0)),label+" native consumer styles")
func assert_order(scene: Node, label: String) -> void:
    var expected: Array = scene.static_entries.map(func(value):return {"entry":value,"key":Order.key(value.placement,value.role,value.layer,scene.quarter,scene.ground_is_background)})
    expected.sort_custom(func(a,b):return Order.less(a.key,b.key) if a.key!=b.key else a.entry.id<b.entry.id)
    check(scene.static_complete_order.map(func(value):return value.id)==expected.map(func(value):return value.entry.id),label+" complete original order")
    expected = expected.filter(func(value):return value.entry.node.visible)
    check(scene.draw_order.map(func(value):return value.id)==expected.map(func(value):return value.entry.id),label+" visible subsequence")
    var offsets = true
    for i in range(expected.size()):
        var value: Dictionary = expected[i].entry
        if value.node.sorting_offset!=i*8.0+(-scene.camera.global_basis.z).dot(value.node.global_position): offsets=false
    check(offsets,label+" native painter offsets")
func publish_order(scene: Node) -> void:
    var prepared = Preparation.new()
    prepared.host=scene; prepared.epoch=scene.timeline.initialization_revision; prepared.quarter=scene.quarter
    prepared.result={"needs_order":true,"background":scene.ground_is_background,"worker_ms":0.0}
    prepared._collect_order(scene.static_entries); prepared._sort_order(); prepared.publish_order()
    prepared.free()
func run() -> void:
    var scene = Probe.new(); root.add_child(scene)
    scene.timeline.initialization_revision=1; scene.timeline.world_revision=7
    scene.world_revision=7; scene.world_generation=3; scene.world_quarter=0; scene.quarter=0
    scene.ground_is_background=false
    scene.timeline.state={"tiles":{"0,0":{"tile_uuid":"a","position":[0,0]},"1,0":{"tile_uuid":"b","position":[1,0]}},
        "objects":{},"senses":{"visible":[[1,0]],"objects":{}}}
    var canonical: Dictionary = scene.timeline.state.duplicate(true)
    scene.world_row_cache={"boundaries":{}}
    scene.static_entries=[entry(scene,"a",0),entry(scene,"b",1),entry(scene,"c",2)]
    scene.entries=scene.static_entries
    scene._sync_scenery(true)
    reset_sight(scene)
    scene.prepared_scenery=receipt(scene,{"b":true},{"a":false,"b":true})
    scene._sync_scenery(); assert_sight(scene,"prepared boundary")
    # A refreshed prior owner or unrelated epoch/view cannot authorize stale
    # sight. Deliberately stale receipts must produce the current state's output.
    for invalid in ["base","epoch","revision","generation","quarter","force","refresh"]:
        reset_sight(scene)
        var stale=receipt(scene,{"a":true},{})
        if invalid=="base": stale.base=scene.scenery_visibility.duplicate()
        elif invalid in ["epoch","revision","generation","quarter"]: stale[invalid]+=1
        scene.prepared_scenery=stale
        scene._sync_scenery(invalid=="force",invalid=="refresh")
        assert_sight(scene,"reject stale "+invalid)
    # Replacing a native consumer needs its current grant even with no change
    # in the admitted visibility set (for example a tile material replacement).
    var replacement: Dictionary = scene.static_entries[1]
    replacement.scenery_value=0.0; replacement.material.set_shader_parameter("current_visibility",0.0)
    scene.scenery_new_consumers={"b":true}; scene.prepared_scenery=receipt(scene,{"b":true},{})
    scene._sync_scenery(); assert_sight(scene,"same-ID replacement")
    scene.static_entries[1].node.visible=false
    publish_order(scene); scene.static_order_dirty=true; scene._sort_draws()
    assert_order(scene,"prepared total order")
    # Trust is consumed once. A later direct placement change on the SAME
    # entries array must rediscover its key; visibility-only changes still filter.
    scene.static_entries[2].placement=scene.static_entries[2].placement.duplicate()
    scene.static_entries[2].placement.position=[-2,0]
    scene.static_entries[1].node.visible=true
    scene.static_order_dirty=true; scene._sort_draws()
    assert_order(scene,"same-array later placement")
    # A replacement membership owner after preparation invalidates the proof.
    publish_order(scene); scene.static_entries=scene.static_entries.duplicate()
    scene.static_entries[2].placement=scene.static_entries[2].placement.duplicate()
    scene.static_entries[2].placement.position=[3,0]
    scene.static_order_dirty=true; scene._sort_draws()
    assert_order(scene,"replaced membership owner")
    check(scene.timeline.state==canonical,"All presentation checks preserve canonical state")
    var report={"checks":checks,"failures":failures,"scope":"Headless native visibility uniforms and total/visible painter order; exact prepared sight, stale owner/epoch/revision/generation/quarter and force/refresh fallback, same-ID replacement, one-shot order trust and same-array later geometry. No pixel/performance claim."}
    FileAccess.open("res://generated/prepared_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("PREPARED_ADMISSION_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
