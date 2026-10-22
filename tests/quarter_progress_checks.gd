extends SceneTree
# Exhausting a preparation slice must not leave a valid target waiting forever.
# This headless fixture builds support geometry without artwork or pixel claims.
const Quarter = preload("res://presentation/quarter_view.gd")
const Placement = preload("res://placement.gd")
const Cells=preload("res://sdk/fold_cells.gd")
class Probe extends "res://play.gd":
    func _ready() -> void:
        set_process(false); set_process_unhandled_input(false); add_child(context_menu)
        camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
        add_child(camera); position_camera()
    func _process(_delta: float) -> void: pass
var checks=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok: failures.append(label); print("QUARTER_PROGRESS_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var host=Probe.new(); root.add_child(host)
    var tiles={
        "0,0":{"position":[0,0],"elevation_steps":0},
        "1,0":{"position":[1,0],"elevation_steps":1},
        "2,0":{"position":[2,0],"elevation_steps":-1}}
    host.timeline.state={"tiles":tiles,"objects":{},"senses":{"visible":Cells.mask([[0,0],[1,0],[2,0]])}}
    host.world_generation=4; host.world_quarter=0
    host.scenery_visibility={"support0":true,"support1":true,"support2":true}
    var original: Dictionary=host.timeline.state.duplicate(true)
    var camera_transform: Transform3D=host.camera.transform
    var target=Quarter.new(); host.add_child(target); target.configure(host,1)
    var calls=0
    while not target.is_prepared and calls<32:
        target.step(0); calls+=1
    check(target.is_prepared,"Zero-budget slices eventually complete a valid native target")
    check(target.geometry.targets.size()==tiles.size(),"Every supplied support is prepared despite exhausted slices")
    for cell in tiles:
        var source: Dictionary=tiles[cell]
        var actual: Dictionary=target.geometry.targets.get(cell,{})
        check(not actual.is_empty() and actual.elevation==source.elevation_steps and actual.center==Placement.project(Vector2(source.position[0],source.position[1]),source.elevation_steps,1),"Exact elevated support geometry "+cell)
    check(not target.visible and host.quarter==0 and host.camera.transform==camera_transform and host.timeline.state==original,"Unpublished preparation preserves current camera, canonical state and visibility")
    if target.is_prepared:
        var geometry: Dictionary=target.geometry.duplicate(true)
        var mask: SubViewport=target.mask_viewport
        var phases: Dictionary=host.profile.phases.duplicate()
        # The owner validates stale style before publication; calling step on a
        # complete job must not silently restart it or allocate another mask.
        host.wall_mode="hidden"
        target.step(0)
        check(target.is_prepared and target.wall_mode=="solid" and target.geometry==geometry and target.mask_viewport==mask and host.profile.phases==phases,"Completed target does no additional work; owner retains style validation")
        check(not target.style_is_current(),"Changed wall style remains detectable before publication")
        target.is_prepared=false; target.begin_style()
        calls=0
        while not target.is_prepared and calls<32:
            target.step(0); calls+=1
        check(target.is_prepared and target.style_is_current() and target.wall_mode=="hidden","Owner-requested style refresh also completes under zero budget")
        host.timeline.state.senses.visible=Cells.mask([[2,0],[0,0],[1,0]])
        check(target.style_is_current(),"Equivalent disclosed cells retain prepared style across a new mask")
        host.timeline.state.senses.visible=Cells.mask([[0,0],[1,0],[3,0]])
        check(not target.style_is_current(),"Same-sized visibility replacement invalidates prepared style")
        host.timeline.state.senses.visible=Cells.mask([[0,0],[1,0],[2,0]])
        host.scenery_visibility.support1=false
        check(not target.style_is_current(),"Changed scenery disclosure invalidates prepared style with unchanged cells")
    var report={"checks":checks,"failures":failures,"scope":"Headless zero-budget quarter support construction, source elevations, current-view isolation, completed-job no-op and explicit stale-style refresh. No GPU pixel or performance claim."}
    FileAccess.open("res://generated/quarter_progress_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("QUARTER_PROGRESS_CHECKS ",JSON.stringify(report))
    host.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
