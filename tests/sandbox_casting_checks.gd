extends SceneTree
## Pose selection changes only offline casting; source markers and hand ownership stay explicit.
const Casting = preload("res://sandbox/casting.gd")
const Tracks = preload("res://presentation/tracks.gd")
const Catalog = preload("res://source_catalog.gd")
var checks := 0
var failures: Array = []
var coverage: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("SANDBOX_CASTING_FAIL ", label)

func read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _initialize() -> void:
    run.call_deferred()

func hand_material(cast: Dictionary) -> Dictionary:
    var layers: Array = [cast.get("weaponGlow"), cast.get("aura")]
    layers.append_array(cast.get("effects", []))
    for layer in layers:
        if layer != null and layer.get("category", "") in ["Magic1", "Magic2", "Magic3"]: return layer
    return {}

func source_distance(image: Image, point: Dictionary, frame: int, row: int) -> float:
    var nearest := INF
    for y in 128:
        for x in 128:
            var pixel := image.get_pixel(frame * 128 + x, row * 128 + y)
            if pixel.a <= .5 or maxf(pixel.r, maxf(pixel.g, pixel.b)) <= 32.0 / 255.0: continue
            nearest = minf(nearest, Vector2(x, y).distance_to(Vector2(point.x, point.y)))
    return nearest

func run() -> void:
    var rig: Dictionary = read("res://authoring/catalog/rigs.json")["neuroclient.modular"]
    var profiles := Casting.variants()
    check(profiles.size() == 6 and profiles[0].id == "authored", "Authored and the five established spell-casting clips are selectable")
    check(profiles.all(func(profile):return profile.id in ["authored","Attack1","Attack4","Attack5","Attack6","Special1"]), "The bow and unapproved sweeping-attack adaptations are excluded")
    var expected := {
        "Attack1":[3,6,10,1.0],
        "Attack4":[7,9,11,1.0], "Attack5":[4,7,11,1.0], "Attack6":[3,6,9,1.0], "Special1":[8,11,13,1.0]}
    var original := read("res://authoring/spells/spell.fire_bolt.json")
    var resources := read("res://authoring/catalog/resources.json")
    for profile in profiles:
        if profile.id == "authored": continue
        var chosen := Casting.apply(original, rig, profile.id)
        var cast: Dictionary = chosen.cast
        var marks: Array = expected[profile.id]
        check(int(cast.prepareFrame) == marks[0] and int(cast.releaseFrame) == marks[1] and int(cast.recoverFrame) == marks[2] and is_equal_approx(cast.bodyPlaybackSpeed,marks[3]),
            profile.id + " uses its source-derived phase markers and speed")
        var track := Tracks.body("caster", "neuroclient.modular", cast.actionClip, rig.clips[cast.actionClip], cast.bodyPlaybackSpeed, 1)
        var release_seconds := float(cast.releaseFrame) / float(rig.clips[cast.actionClip].fps) / float(cast.bodyPlaybackSpeed)
        check(release_seconds < track.duration_ms / 1000.0, profile.id + " release occurs inside the complete body/hand clip")
        check(is_equal_approx(track.duration_ms, 15000.0 / 12.0 / float(cast.bodyPlaybackSpeed)), profile.id + " plays all fifteen source frames without an inherited crop")
        var sheet: String = rig.clips[cast.actionClip].sheets.Magic2
        check(cast.weaponGlow.sourceSheet == sheet and cast.weaponGlow.category == "Magic2", profile.id + " selects its own hand sheet")
        var image := Image.load_from_file(Catalog.media_path(resources[sheet]))
        check(image != null and image.get_size() == Vector2i(1920,1024), profile.id + " source hand sheet has all fifteen frames and eight facing rows")
        var distances: Dictionary = {}
        for facing in rig.facing_rows:
            var points: Array = cast.sourceSockets.preparation[facing]
            check(points.size() == 15, profile.id + "/" + facing + " retains its full source hand path")
            check(cast.sourceSockets.release[facing] == points[cast.releaseFrame], profile.id + "/" + facing + " charge and release use one hand point")
            for frame in range(cast.prepareFrame, cast.releaseFrame + 1):
                check(points[frame] != null, "%s/%s has an authored charged-hand point at frame%d" % [profile.id,facing,frame])
            if image != null:
                distances[facing] = source_distance(image, cast.sourceSockets.release[facing], cast.releaseFrame, rig.facing_rows[facing])
        coverage.append({"clip":profile.id,"prepare":cast.prepareFrame,"release":cast.releaseFrame,"recover":cast.recoverFrame,
            "speed":cast.bodyPlaybackSpeed,"duration_ms":track.duration_ms,"release_to_magic_core_pixels":distances,
            "qualification":profile.reason})
    var library := read("res://authoring/sandbox/projectiles.json")
    var spell_count := 0
    for capability in library.spells:
        var spell = load("res://authoring/sandbox/" + capability.id + ".tres")
        var recipe := read(spell.choreography)
        var before := recipe.duplicate(true)
        var authored := Casting.apply(recipe, rig, "authored")
        check(authored == recipe, spell.spell_id + " Authored preserves the complete original recipe")
        authored.cast.actionClip = "changed-copy"
        check(recipe == before, spell.spell_id + " Authored result does not alias the source recipe")
        var old_material := hand_material(recipe.cast)
        for profile in profiles:
            if profile.id == "authored": continue
            var selected := Casting.apply(recipe, rig, profile.id)
            check(selected.cast.enabled and selected.cast.actionClip == profile.id, spell.spell_id + "/" + profile.id + " explicitly previews the selected pose")
            for key in recipe:
                if key not in ["cast", "projectile"]: check(selected[key] == recipe[key], spell.spell_id + "/" + profile.id + " preserves " + key)
            check(selected.cast.effects.is_empty() and not selected.cast.has("aura"), spell.spell_id + "/" + profile.id + " keeps only selected hand magic")
            if not old_material.is_empty():
                for key in ["colors", "palette"]:
                    check(selected.cast.weaponGlow.get(key) == old_material.get(key), spell.spell_id + "/" + profile.id + " preserves its own " + key)
            if selected.get("projectile") != null:
                check(selected.projectile.sourceSockets == selected.cast.sourceSockets, spell.spell_id + "/" + profile.id + " replaces old projectile sockets")
                if selected.projectile.get("prepare") != null:
                    check(selected.projectile.prepare.startFrame == selected.cast.prepareFrame, spell.spell_id + "/" + profile.id + " replaces old preparation start")
                var projectile: Dictionary = selected.projectile.duplicate(true)
                projectile.sourceSockets = recipe.projectile.get("sourceSockets")
                if not recipe.projectile.has("sourceSockets"): projectile.erase("sourceSockets")
                if projectile.get("prepare") != null: projectile.prepare = recipe.projectile.prepare
                check(projectile == recipe.projectile, spell.spell_id + "/" + profile.id + " preserves travel and impact authoring")
            check(recipe == before, spell.spell_id + "/" + profile.id + " leaves original data unchanged")
        spell_count += 1
    check(spell_count == 34, "All34 sandbox spell defaults and alternatives were covered")
    var burning := read("res://authoring/spells/spell.burning_hands.json")
    var thrust := Casting.apply(original, rig, "Attack6")
    check(thrust.cast.sourceSockets == burning.cast.sourceSockets, "Attack6 retains the corrected lower Magic2 hand from Burning Hands")
    check(thrust.cast.sourceSockets.release.SE != rig.pose_sockets.hand.Attack6.SE[6], "Attack6 does not regress to the other-arm rig anchor")
    var true_strike := read("res://authoring/spells/spell.true_strike.json")
    check(not Casting.apply(true_strike,rig,"authored").cast.enabled, "Authored True Strike keeps its disabled cast")
    var true_cast := Casting.apply(true_strike,rig,"Attack5")
    check(true_cast.cast.enabled and true_cast.cast.weaponGlow.palette.colors == [true_strike.elementColors.tertiary,true_strike.elementColors.primary,true_strike.elementColors.secondary], "Explicit True Strike pose adds hand magic using its own authored colours")
    var cropped := original.duplicate(true)
    cropped.cast.weaponGlow.frameKeys = [[0,4],[1,7]]
    cropped.cast.weaponGlow.startFrame = 4
    cropped.cast.weaponGlow.durationMs = 250
    var full := Casting.apply(cropped,rig,"Special1")
    for facing in rig.facing_rows:
        for frame in range(full.cast.prepareFrame,full.cast.releaseFrame+1):
            var left:Dictionary=rig.pose_sockets.hand.Special1[facing][frame]
            var right:Dictionary=rig.pose_sockets.other_hand.Special1[facing][frame]
            var point:Dictionary=full.cast.sourceSockets.preparation[facing][frame]
            check(is_equal_approx(point.x,(left.x+right.x)*.5) and is_equal_approx(point.y,(left.y+right.y)*.5),
                "Invocation/%s/frame%d uses the midpoint of both authored hands"%[facing,frame])
    check(not full.cast.weaponGlow.has("frameKeys") and not full.cast.weaponGlow.has("startFrame") and not full.cast.weaponGlow.has("durationMs"), "Selecting an invocation discards the previous hand clip crop")
    var report := {"checks":checks,"failures":failures,"spell_count":spell_count,"profiles":coverage,
        "qualification":"Headless source-data, PNG, marker and nonmutation checks. Pixel distances are source-inspection evidence, not a rendered alignment or aesthetic claim."}
    FileAccess.open("res://.runtime/sandbox-casting-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SANDBOX_CASTING_CHECKS ",checks," failures=",failures.size())
    quit(0 if failures.is_empty() else 1)
