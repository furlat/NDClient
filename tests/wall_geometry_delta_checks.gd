extends SceneTree
# Explicit geometry fixtures: sparse source changes must qualify the same wall
# members as exhaustive finite-wall/diamond intersection, including views which
# were inactive through several publications. No artwork or backend is invented.
const Player = preload("res://play.gd")
const Reveal = preload("res://presentation/wall_reveal.gd")
var checks = 0
var failures: Array = []
var members: Array = []

func _initialize() -> void: run.call_deferred()
func verify(scene: Node, quarters: Array, label: String) -> void:
    for q in quarters:
        scene.quarter = q
        var geometry: Dictionary = scene._wall_geometry()
        for member in members:
            var actual: Array = Reveal.targets(member,geometry,q).map(func(tile):return tile.cell)
            var expected: Array = []
            var tiles: Dictionary = scene.timeline.presentation_state().tiles
            for cell in tiles:
                if Reveal.occludes(member,tiles[cell],q): expected.append(cell)
            actual.sort(); expected.sort()
            checks += 1
            if actual!=expected: failures.append("%s q%d %s" % [label,q,member.id])

func publish(scene: Node, cells: Array, full: bool = false) -> void:
    scene.world_generation += 1
    var keys = {}
    for cell in cells: keys[cell] = true
    scene._queue_wall_geometry_changes({"full":full,"tiles":keys,"objects":{},"senses":false})

func run() -> void:
    var scene = Player.new()
    scene.timeline.state = {"tiles":{},"objects":{}}
    for x in range(-3,4):
        for y in range(-3,4):
            scene.timeline.state.tiles["%d,%d" % [x,y]] = {"position":[x,y],"elevation_steps":0}
    for direction in ["east","west","north","south"]:
        members.append({"id":direction,"position":[0,0],"boundaries":[direction],"base_height_steps":0,"top_height_steps":3})
    publish(scene,[],true)
    verify(scene,[0,1,2,3],"initial")
    scene.timeline.state.tiles["1,1"] = {"position":[1,1],"elevation_steps":8}
    scene.timeline.state.tiles["-1,-1"] = {"position":[-1,-1],"elevation_steps":-3}
    publish(scene,["1,1","-1,-1"])
    verify(scene,[0],"height changes")
    scene.timeline.state.tiles.erase("0,1")
    scene.timeline.state.tiles["4,0"] = {"position":[4,0],"elevation_steps":-1}
    publish(scene,["0,1","4,0"])
    verify(scene,[1],"addition/removal after inactive height change")
    scene.timeline.state.tiles["1,0"] = {"position":[1,0],"elevation_steps":0,"resolved_light":"bright"}
    publish(scene,["1,0"])
    verify(scene,[2,3,0,1],"accumulated updates and metadata-only change")
    scene.timeline.state.tiles["0,1"] = {"position":[0,1],"elevation_steps":0}
    publish(scene,["0,1"])
    verify(scene,[3,2,1,0],"reintroduced support")
    scene.timeline.state.tiles.clear()
    publish(scene,[],true)
    verify(scene,[0,1,2,3],"complete reset")
    scene.timeline.current = {"staged_tiles":{"0,1":{"position":[0,1],"elevation_steps":0},"1,0":{"position":[1,0],"elevation_steps":0}}}
    publish(scene,["0,1","1,0"])
    verify(scene,[0,1,2,3],"admitted staged supports before canonical commit")
    scene.timeline.state.tiles["0,1"] = scene.timeline.current.staged_tiles["0,1"]
    publish(scene,["0,1"])
    verify(scene,[0,1,2,3],"staged support becomes canonical")
    scene.timeline.current = {}
    publish(scene,["1,0"])
    verify(scene,[0,1,2,3],"uncommitted staged support retires")
    var report = {"checks":checks,"failures":failures,"scope":"Sparse finite-wall target qualification versus exhaustive intersections across four views, elevation, removal, insertion, inactive quarters, reset and admitted staged-support lifetime."}
    var file = FileAccess.open("res://generated/wall_geometry_delta_checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(report,"  ")); file.close()
    print("WALL_GEOMETRY_DELTA_CHECKS ",JSON.stringify(report))
    # This pure geometry fixture never enters _ready(), where the popup would
    # normally become a scene child and gain ordinary tree ownership.
    scene.context_menu.free()
    scene.free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
