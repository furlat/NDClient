extends SceneTree
# Visible contract: disclosed tile outlines keep their original native projected
# positions after sight-only changes, tile/elevation edits and camera changes.
# Compare native HUD pixels with uncached direct projection of the same tiles.
const HUD = preload("res://play_hud.gd")
const FixtureWorld = preload("res://tests/ui_fixture_world.gd")
const Placement = preload("res://placement.gd")
class ReferenceGrid extends Control:
    var world: Node3D
    func _draw() -> void:
        var lines = PackedVector2Array()
        for tile in world.timeline.state.tiles.values():
            var corners = PackedVector2Array()
            for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
                corners.append(world.camera.unproject_position(Vector3(tile.position[0]+offset.x,tile.elevation_steps*Placement.HEIGHT_UNIT,tile.position[1]+offset.y)))
            for i in range(4):
                lines.append(corners[i]); lines.append(corners[(i+1)%4])
        if not lines.is_empty(): draw_multiline(lines,Color(0.56,0.70,0.85,0.12),1,false)
var checks = 0
var failures: Array = []
var world: Node3D
var hud: Control
var reference: Control
func _initialize() -> void: run.call_deferred()
func run() -> void:
    if DisplayServer.get_name()=="headless":
        push_error("Grid pixel checks require native rendering"); quit(1); return
    root.unfocusable = true; root.position = Vector2i(-16000,-16000)
    root.size = Vector2i(640,400)
    world = FixtureWorld.new()
    world.timeline.state = {"tiles":{},"actors":{},"current_actor_uuid":""}
    world.grid_visible = true
    root.add_child(world)
    world.camera = Camera3D.new()
    world.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    world.camera.size = 12
    world.add_child(world.camera)
    hud = HUD.new(); hud.world = world; hud.set_process(false); root.add_child(hud)
    for child in hud.get_children():
        if child is CanvasItem: child.hide()
    reference = ReferenceGrid.new(); reference.world = world; reference.hide(); root.add_child(reference)
    for q in range(4):
        var angle = PI/4+q*PI/2
        world.camera.position = Vector3(sin(angle)*10,8,cos(angle)*10)
        world.camera.look_at(Vector3.ZERO)
        world.timeline.state.tiles = {}
        world.timeline.world_revision += 1
        await compare("q%d empty view" % q)
        world.timeline.state.tiles = {"0,0":{"position":[0,0],"elevation_steps":0}}
        world.timeline.world_revision += 1
        await compare("q%d origin after prior buffer shrink" % q)
        for x in range(-8,9):
            for y in range(-8,9):
                world.timeline.state.tiles["%d,%d" % [x,y]] = {"position":[x,y],"elevation_steps":2 if x>3 else 0}
        world.timeline.world_revision += 1
        await compare("q%d new cells and elevated supports" % q)
        world.timeline.world_revision += 1
        await compare("q%d sight-only revision" % q)
        world.timeline.state.tiles["0,0"] = {"position":[0,0],"elevation_steps":-2}
        world.timeline.world_revision += 1
        await compare("q%d changed elevation" % q)
        var reordered = {}
        var keys: Array = world.timeline.state.tiles.keys(); keys.reverse()
        for key in keys:
            if key != "1,1": reordered[key] = world.timeline.state.tiles[key]
        world.timeline.state.tiles = reordered
        world.timeline.world_revision += 1
        await compare("q%d removal and reordered rows" % q)
        world.camera.size += 0.375
        await compare("q%d fractional zoom" % q)
    root.size = Vector2i(800,450)
    await process_frame
    await compare("viewport resize")
    var report = {"checks":checks,"failures":failures,"ok":failures.is_empty(),"comparison":"exact native RGBA pixels against uncached original tile projection"}
    var file = FileAccess.open("res://generated/hud_grid_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    hud.free(); reference.free(); world.free()
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
func compare(label: String) -> void:
    reference.hide(); hud.show(); hud.queue_redraw()
    await process_frame; await RenderingServer.frame_post_draw
    var actual = root.get_texture().get_image()
    hud.hide(); reference.show(); reference.queue_redraw()
    await process_frame; await RenderingServer.frame_post_draw
    var expected = root.get_texture().get_image()
    checks += 1
    if actual.get_size()!=expected.get_size() or actual.get_data()!=expected.get_data():
        failures.append(label); print("HUD_GRID_FAIL ",label)
        actual.save_png("res://.captures/hud-grid-actual.png")
        expected.save_png("res://.captures/hud-grid-reference.png")
