extends SceneTree
## Actual delivered modular sheets, explicit source poses and native transforms.
const Sockets = preload("res://sandbox/surface_sockets.gd")
const Geometry = preload("res://presentation/character_geometry.gd")
const Catalog = preload("res://source_catalog.gd")
const Placement = preload("res://placement.gd")
class Fixture extends Node:
    var visual_actors := {}
    var rigs := {}
    var catalog_cache := {}
    var source_images := {}
    var camera: Camera3D
var checks := 0
var failures: Array = []
var evidence: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("SURFACE_SOCKET_FAIL ", label)

func _initialize() -> void:
    run.call_deferred()

func _painted(entry: Dictionary, pixel: Vector2) -> Vector3:
    return entry.node.to_global(Vector3(pixel.x - entry.pivot.x, entry.pivot.y - pixel.y, 0.0) * entry.scale / Placement.PIXELS_PER_UNIT)

func run() -> void:
    var fixture := Fixture.new()
    root.add_child(fixture)
    fixture.rigs = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/catalog/rigs.json"))
    fixture.catalog_cache[Geometry.TABLE] = JSON.parse_string(FileAccess.get_file_as_string(Geometry.TABLE))
    var rig: Dictionary = fixture.rigs["neuroclient.modular"]
    fixture.camera = Camera3D.new()
    fixture.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    fixture.camera.size = 8.0
    fixture.add_child(fixture.camera)
    fixture.camera.position = Vector3(8.0, 6.5319726474, 8.0)
    fixture.camera.look_at(Vector3.ZERO)
    var entries: Array = []
    var selected := {"body":"NakedBody", "legs":"Legs2", "chest":"Chest14", "belt":"Belt2", "head":"Head10"}
    var material_shader := Shader.new()
    material_shader.code = "shader_type spatial; uniform float condition_alpha=1.0;"
    for slot in rig.slot_order:
        if not selected.has(slot): continue
        var node := MeshInstance3D.new()
        node.mesh = QuadMesh.new()
        fixture.add_child(node)
        node.position = Vector3(3.0, 2.0, 1.0)
        node.basis = fixture.camera.basis
        var material := ShaderMaterial.new()
        material.shader = material_shader
        var entry := {"id":"caster/" + slot, "node":node, "material":material,
            "scale":2.0, "pivot":Vector2(64.0, 87.0), "role":"body",
            "actor_layer":{"slot":slot, "alpha":1.0, "paths":{}}}
        for clip in ["Idle", "Attack5"]:
            var path: String = "/media/smallscale/modular/" + selected[slot] + "/" + clip + ".png"
            entry.actor_layer.paths[clip] = path
            fixture.source_images[path] = Image.load_from_file(Catalog.media_path(path))
            var record := Geometry.record(path, slot, fixture.catalog_cache)
            var geometry_root := Geometry._root(record)
            for relative in [record.files.depth, record.files.support, str(record.reference).get_base_dir().path_join("solid-valid.png")]:
                var absolute := geometry_root.path_join(relative)
                fixture.source_images[absolute] = Image.load_from_file(absolute)
        entries.append(entry)
    fixture.visual_actors.caster = {"valid":true, "row":{"rig":"neuroclient.modular"}, "entries":entries}
    var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://authoring/spells/spell.fire_bolt.json"))
    var release_frame: int = recipe.cast.releaseFrame
    var anchor: Dictionary = entries[0]
    for quarter in 4:
        fixture.camera.position = Vector3(8.0, 6.5319726474, 8.0).rotated(Vector3.UP, quarter * PI / 2.0)
        fixture.camera.look_at(Vector3.ZERO)
        for entry in entries: entry.node.basis = fixture.camera.basis
        for facing in recipe.projectile.sourceSockets.release:
            var authored: Dictionary = recipe.projectile.sourceSockets.release[facing]
            var pixel := Vector2(authored.x, authored.y)
            var painted := _painted(anchor, pixel)
            var resolved := Sockets.resolve(fixture, "caster", "Attack5", release_frame, facing, pixel, painted)
            check(resolved.supported, "Quarter%d/%s: future release resolves its actual Attack5/frame7 source" % [quarter, facing])
            if not resolved.supported: continue
            check(fixture.camera.unproject_position(resolved.point).is_equal_approx(fixture.camera.unproject_position(painted)), "Quarter%d/%s: depth correction preserves authored screen position" % [quarter, facing])
            check(is_equal_approx(resolved.point.y, anchor.node.global_position.y + resolved.height_above_optical_ground), "Quarter%d/%s: surface height uses actual world elevation and subtracts optical ground" % [quarter, facing])
            evidence.append({"quarter":quarter, "facing":facing, "owner":resolved.owner,
                "source_frame":resolved.frame, "ray_offset":resolved.ray_offset,
                "height_above_ground":resolved.height_above_optical_ground})
    var release: Dictionary = recipe.projectile.sourceSockets.release.E
    var pixel := Vector2(release.x, release.y)
    var painted := _painted(anchor, pixel)
    var future := Sockets.resolve(fixture, "caster", "Attack5", release_frame, "E", pixel, painted)
    var idle := Sockets.resolve(fixture, "caster", "Idle", 0, "E", pixel, painted)
    check(future.supported and not idle.supported and idle.point == painted, "Future hand release does not borrow transparent Idle geometry")
    var covered_pixel := Vector2(69.5, 71.5)
    var covered := Sockets.resolve(fixture, "caster", "Attack5", 7, "SW", covered_pixel, _painted(anchor, covered_pixel))
    var source: Dictionary = Geometry.record("/media/smallscale/modular/Legs2/Attack5.png", "legs", fixture.catalog_cache)
    var expected_depth: float = source.depth_range[0] + (118.0 - 32.0) * (source.depth_range[1] - source.depth_range[0]) / 192.0
    check(covered.supported and covered.owner == "caster/legs" and is_equal_approx(covered.depth, expected_depth), "Painted Legs2 byte118 owns the socket instead of hidden NakedBody byte135")
    var uncovered := Sockets.resolve(fixture, "caster", "Attack5", 7, "SW", covered_pixel, _painted(anchor, covered_pixel), ["legs"])
    check(uncovered.supported and uncovered.owner == "caster/body", "Explicit requested-pose hidden slots change painted ownership")
    var unknown_pixel := Vector2(67.5, 66.5)
    var unknown_painted := _painted(anchor, unknown_pixel)
    var unknown := Sockets.resolve(fixture, "caster", "Attack5", 7, "SW", unknown_pixel, unknown_painted)
    check(not unknown.supported and unknown.owner == "caster/belt" and unknown.point == unknown_painted, "Unsupported painted belt does not fall through to covered known chest depth")
    var deformation := Vector3(-1.0, .7, 1.0)
    for entry in entries: entry.node.basis = fixture.camera.basis.scaled_local(deformation)
    var transformed_painted := _painted(anchor, pixel)
    var transformed := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", pixel, transformed_painted)
    check(transformed.supported and fixture.camera.unproject_position(transformed.point).is_equal_approx(fixture.camera.unproject_position(transformed_painted)), "Actual mirror/passage transform retains its displayed socket projection")
    var expected_deformed: Vector3 = anchor.node.global_position + fixture.camera.global_basis * ((fixture.camera.global_basis.inverse() * (future.point - anchor.node.global_position)) * deformation)
    check(transformed.point.is_equal_approx(expected_deformed), "Receiver correction applies the displayed affine deformation once")
    for entry in entries: entry.node.position.y += 1.75
    var lifted_painted := _painted(anchor, pixel)
    var lifted := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", pixel, lifted_painted)
    check(lifted.point.is_equal_approx(transformed.point + Vector3.UP * 1.75), "Airborne/world origin translation survives reconstruction exactly once")
    var body_material: ShaderMaterial = anchor.material
    body_material.set_shader_parameter("condition_alpha", .55)
    var translucent := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", pixel, lifted_painted)
    check(not translucent.supported and translucent.reason == "translucent_display_owner" and translucent.point == lifted_painted, "Translucent display owner stays an explicit unresolved surface")
    body_material.set_shader_parameter("condition_alpha", 1.0)
    var mask: Image = fixture.source_images[future.solid_source]
    fixture.source_images.erase(future.solid_source)
    var missing := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", pixel, lifted_painted)
    check(not missing.supported and missing.reason == "source_solid_not_prepared" and missing.point == lifted_painted, "Missing preloaded mask does not perform a disk fallback")
    fixture.source_images[future.solid_source] = mask
    var out_of_bounds := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", Vector2(-1, 50), lifted_painted)
    check(not out_of_bounds.supported and out_of_bounds.point == lifted_painted and out_of_bounds.reason == "socket_outside_source_cell", "Outside-cell socket is not clamped to an invented nearby surface")
    var bad_frame := Sockets.resolve(fixture, "caster", "Attack5", 15, "E", pixel, lifted_painted)
    check(not bad_frame.supported and bad_frame.reason == "source_frame_out_of_bounds", "Unavailable pose is not replaced with the last source frame")
    var cached: Dictionary = fixture.catalog_cache[Geometry.TABLE]
    fixture.catalog_cache.erase(Geometry.TABLE)
    var missing_catalog := Sockets.resolve(fixture, "caster", "Attack5", 7, "E", pixel, lifted_painted)
    check(not missing_catalog.supported and missing_catalog.reason == "source_geometry_catalog_not_prepared", "Resolve cannot lazily reload a missing metadata catalog")
    fixture.catalog_cache[Geometry.TABLE] = cached
    if "--compact" in OS.get_cmdline_user_args(): compact_samples(fixture,entries,rig)
    var report := {"checks":checks, "failures":failures, "release_surface_samples":evidence,
        "qualification":"Real delivered optical data with source-over ownership; no physical arbitrary-assembly or temporal-consistency claim"}
    FileAccess.open("res://generated/sandbox_surface_socket_checks.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    fixture.queue_free()
    await process_frame
    print("SURFACE_SOCKET_CHECKS ", checks, " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)

func compact_samples(fixture:Fixture,entries:Array,rig:Dictionary)->void:
    var samples=load("res://presentation/surface_socket_samples.gd")
    var sidecars={};var queries={}
    for entry in entries:
        for clip in entry.actor_layer.paths:
            var path:String=entry.actor_layer.paths[clip]
            var source:Dictionary=Geometry.record(path,entry.actor_layer.slot,fixture.catalog_cache)
            var file:String=samples.file_for(path,source)
            check(FileAccess.file_exists(file),"Actual fixture sidecar exists: "+path)
            if not FileAccess.file_exists(file):return
            var sidecar:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
            sidecars[path]={"source":source,"root":Geometry._root(source)}
            if not queries.has(clip):queries[clip]={}
            for key in sidecar.samples:queries[clip][key]=true
    var original_images:Dictionary=fixture.source_images.duplicate()
    var baseline_cache:Dictionary=fixture.catalog_cache.duplicate()
    var compact_cache:Dictionary=fixture.catalog_cache.duplicate()
    for path in sidecars:
        check(samples.prepare(path,sidecars[path].source,sidecars[path].root,compact_cache),"Small sample metadata admits current source: "+path)
    var count=0
    for quarter in 4:
        fixture.camera.position=Vector3(8,6.5319726474,8).rotated(Vector3.UP,quarter*PI/2)
        fixture.camera.look_at(Vector3.ZERO)
        for entry in entries:entry.node.basis=fixture.camera.basis.scaled_local(Vector3(-1,.7,1) if quarter==1 else Vector3.ONE)
        for clip in queries:
            var cases=[]
            fixture.catalog_cache=baseline_cache;fixture.source_images=original_images
            for key in queries[clip]:
                var xy=key.split(",")
                var sheet=Vector2i(int(xy[0]),int(xy[1]))
                var frame=sheet.x/int(rig.cell_width)
                var facing:String=rig.facing_rows.find_key(float(sheet.y/int(rig.cell_height)))
                var pixel=Vector2(sheet.x%int(rig.cell_width)+.5,sheet.y%int(rig.cell_height)+.5)
                var painted=_painted(entries[0],pixel)
                cases.append([frame,facing,pixel,painted,Sockets.resolve(fixture,"caster",clip,frame,facing,pixel,painted)])
            fixture.catalog_cache=compact_cache;fixture.source_images={}
            for path in original_images:
                if path.begins_with("/media/"):fixture.source_images[path]=original_images[path]
            for case in cases:
                var actual=Sockets.resolve(fixture,"caster",clip,case[0],case[1],case[2],case[3])
                check(actual==case[4],"CPU-free optical sample retains painted owner/mask/depth/point q%d/%s/%s/%d/%s"%[quarter,clip,case[1],case[0],case[2]])
                count+=1
    evidence.append({"compact_samples_compared":count,"cpu_images_retained":fixture.source_images.size(),"qualification":"Exact assembled output with all depth/support/solid CPU images removed; four camera quarters including mirrored passage scale."})
