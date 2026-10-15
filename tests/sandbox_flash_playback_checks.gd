extends SceneTree
## Observe real 1x presentation/draw frames, then audit every library contact.
## Pixel captures are inspection evidence, not an aesthetic approval threshold.
const REPORT := "res://.runtime/sandbox-flash-playback-checks.json"
const CAPTURES := "res://.captures/flash-playback"
var checks := 0
var failures: Array = []
var cycles: Array = []
var coverage: Array = []
var material_captures: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        print("FLASH_PLAYBACK_FAIL ", label)

func _initialize() -> void:
    root.unfocusable = true
    root.position = Vector2i(-16000, -16000)
    create_timer(180.0).timeout.connect(func():
        push_error("Flash playback check exceeded its finite 180-second budget")
        quit(1))
    run.call_deferred()

func frame() -> void:
    await process_frame
    await RenderingServer.frame_post_draw

func pause_world(world: Node) -> void:
    world.playing = false
    world.loop = false
    world.set_process(false)

func select(world: Node, id: String) -> bool:
    for index in world.spells.size():
        if world.spells[index].spell_id == id:
            world.select_spell(index)
            pause_world(world)
            return true
    check(false, "Missing capability: " + id)
    return false

func receiver(world: Node, id: String) -> Dictionary:
    var rows: Array = []
    var drawable := 0
    var active := 0
    var agrees := true
    for entry in world.visual_actors[id].entries:
        if entry.role == "shadow": continue
        var source: ShaderMaterial = entry.material
        var output: ShaderMaterial = entry.node.material_override
        var source_strength := float(source.get_shader_parameter("flash_strength"))
        var output_strength := float(output.get_shader_parameter("flash_strength"))
        var visible: bool = entry.node.is_visible_in_tree()
        if visible:
            drawable += 1
            if output_strength > 0.0: active += 1
            agrees = agrees and is_equal_approx(source_strength, output_strength)
        rows.append({"slot":entry.actor_layer.slot, "visible":visible,
            "source_strength":source_strength, "output_strength":output_strength,
            "native_enabled":output.get_shader_parameter("native_body_enabled"),
            "native_strength":output.get_shader_parameter("native_body_strength"),
            "received_output":entry.get("received_material") == output})
    return {"drawable_layers":drawable, "active_layers":active,
        "source_output_agree":agrees, "layers":rows}

func expected_strength(age_ms: float, flash: Dictionary) -> float:
    var duration := float(flash.durationMs)
    if age_ms < 0.0 or age_ms >= duration: return 0.0
    if flash.get("envelope", "") == "hold_fade":
        var hold := float(flash.get("holdMs", 0.0))
        return 1.0 - smoothstep(hold, maxf(hold + .001, duration), age_ms)
    return clampf(1.0 - age_ms / maxf(1.0, duration), 0.0, 1.0)

func real_playback(world: Node) -> void:
    if not select(world, "fire_bolt"): return
    world.spell_hit_flash = true
    world.hit_appearance = 1
    check(world.body_material.material != null, "Fire Bolt has an actual native body material")
    check(not world.feedback.colors.is_empty(), "Fire Bolt retains its separate colour-treatment authoring")
    # Warm the real fixture, then let its ordinary _process own both cycles.
    for tick in 3: await frame()
    world.rate = 1.0
    world.restart()
    var first_loop: int = world.loop_count
    world.loop = true
    world.set_process(true)
    var started := Time.get_ticks_msec()
    var previous_usec := Time.get_ticks_usec()
    var samples: Array = []
    var capture_keys: Dictionary = {}
    var surface_frames: Dictionary = {}
    var pending_captures: Array = []
    var timeout_ms: int = maxi(30000, ceili(world.duration * 4000.0))
    while Time.get_ticks_msec() - started < timeout_ms:
        await frame()
        var now := Time.get_ticks_usec()
        var cycle: int = world.loop_count - first_loop
        if cycle > 1: break
        var contact: Dictionary = world.cue_plan.contacts[0]
        var age_ms: float = (world.elapsed - float(contact.time)) * 1000.0
        var current := receiver(world, str(contact.target))
        var expected := expected_strength(age_ms, world.feedback.flash)
        var row := {"cycle":cycle, "elapsed":world.elapsed, "contact":contact.time,
            "age_ms":age_ms, "native_draw_delta_ms":float(now - previous_usec) / 1000.0,
            "expected_strength":expected, "receiver":current}
        previous_usec = now
        if age_ms >= -100.0 and age_ms <= float(world.feedback.flash.durationMs) + 100.0:
            samples.append(row)
            check(current.source_output_agree, "Cycle%d age%.1f: drawn and sampled receiver materials agree" % [cycle, age_ms])
            for layer in current.layers:
                if layer.visible:
                    check(is_equal_approx(float(layer.output_strength), expected),
                        "Cycle%d age%.1f %s: actual output carries the current flash" % [cycle, age_ms, layer.slot])
                    check(bool(layer.native_enabled) == (expected > 0.0),
                        "Cycle%d age%.1f %s: actual output uses the selected native material" % [cycle, age_ms, layer.slot])
                    check(is_equal_approx(float(layer.native_strength), expected),
                        "Cycle%d age%.1f %s: native material has the current envelope" % [cycle, age_ms, layer.slot])
        if expected > 0.0:
            var hold_ms:float=world.feedback.flash.get("holdMs",0.0)
            var late_ms:float=lerpf(hold_ms,float(world.feedback.flash.durationMs),.5)
            var label := "contact" if age_ms < hold_ms else "after-peak" if age_ms >= late_ms else ""
            var key := "%d-%s" % [cycle, label]
            if not label.is_empty() and not capture_keys.has(key):
                pending_captures.append({"path":CAPTURES + "/fire-bolt-cycle" + key + ".png", "image":root.get_texture().get_image()})
                capture_keys[key] = {"age_ms":age_ms, "elapsed":world.elapsed}
                if world.body_material.surfaces.has(str(contact.target)):
                    var surface: Dictionary = world.body_material.surfaces[str(contact.target)]
                    var native_image: Image = surface.viewport.get_texture().get_image()
                    pending_captures.append({"path":CAPTURES + "/native-surface-cycle" + key + ".png", "image":native_image})
                    surface_frames[key] = native_image.get_data()
                    var clock: String = world.body_material.definition.get("clock_parameter", "")
                    if not clock.is_empty():
                        check(is_equal_approx(float(surface.material.get_shader_parameter(clock)), age_ms / 1000.0),
                            "Cycle%d %s: the actual native source clock advances with feedback" % [cycle, label])
        if cycle == 1 and age_ms > float(world.feedback.flash.durationMs) + 100.0: break
    pause_world(world)
    # PNG compression/file writes are outside the observed playback interval.
    # Retain actual drawn Images; no re-sampling substitutes for those frames.
    for capture in pending_captures:capture.image.save_png(capture.path)
    check(world.loop_count - first_loop >= 1, "Fire Bolt reaches its second cycle through the actual loop")
    for cycle in 2:
        var all_rows: Array = samples.filter(func(row): return row.cycle == cycle)
        var active: Array = all_rows.filter(func(row): return row.expected_strength > 0.0 and row.receiver.active_layers > 0)
        check(not active.is_empty(), "Cycle%d has actual draw frames carrying the receiving flash" % cycle)
        var span := 0.0 if active.is_empty() else float(active.back().age_ms - active.front().age_ms)
        var contact_key := "%d-contact" % cycle
        var later_key := "%d-after-peak" % cycle
        check(surface_frames.has(contact_key) and surface_frames.has(later_key),
            "Cycle%d captures native material at contact and after peak" % cycle)
        if surface_frames.has(contact_key) and surface_frames.has(later_key):
            check(surface_frames[contact_key] != surface_frames[later_key],
                "Cycle%d native material pixels animate during the flash" % cycle)
        cycles.append({"cycle":cycle, "drawable_flash_frames":active.size(),
            "observed_first_to_last_flash_ms":span, "sampled_frames":all_rows})
    cycles.append({"capture_times":capture_keys, "duration_ms":world.feedback.flash.durationMs,"hold_ms":world.feedback.flash.holdMs,"wall_elapsed_ms":Time.get_ticks_msec() - started,
        "qualification":"Actual _process at playback rate1, observed after frame_post_draw. Drawable means a visible recipient layer with an active final output material; screenshots separately expose native-VFX occlusion and perceptual readability."})

func appearance(world: Node, index: int) -> void:
    world.hit_appearance_choice.select(index)
    world.hit_appearance_choice.item_selected.emit(index)
    await frame()
    await frame()

func recipient_crop(world: Node, image: Image) -> Image:
    var at: Vector2 = world.camera.unproject_position(world.get_node("Target").global_position)
    return image.get_region(Rect2i(Vector2i(at) - Vector2i(65,145), Vector2i(130,165)))

func tint_recipient(world: Node, values: Array) -> void:
    var index := 0
    for entry in world.visual_actors.target.entries:
        if entry.role == "shadow": continue
        entry.material.set_shader_parameter("tint", values[index])
        entry.source_version += 1
        index += 1
    world._sync_native_lighting()
    await frame()
    await frame()

func paused_mode_control(world: Node) -> void:
    if not select(world, "fire_bolt"): return
    world.elapsed = float(world.cue_plan.contacts[0].time) + float(world.feedback.flash.holdMs) / 2000.0
    world._sample_frame(0.0)
    await appearance(world, 1)
    var original_tints: Array = []
    var changed_tints: Array = []
    for entry in world.visual_actors.target.entries:
        if entry.role == "shadow": continue
        original_tints.append(entry.material.get_shader_parameter("tint"))
        changed_tints.append(Vector3(.85,.03,.85))
    var source_age: float = world.playbacks.target.sample_seconds
    var full_image: Image = root.get_texture().get_image()
    var full: Image = recipient_crop(world, full_image)
    full_image.save_png(CAPTURES + "/paused-full-material.png")
    await tint_recipient(world, changed_tints)
    var full_changed: Image = recipient_crop(world, root.get_texture().get_image())
    check(full.get_data() == full_changed.get_data(),
        "At full strength native material RGB is independent of the recipient outfit tint")
    await tint_recipient(world, original_tints)
    await appearance(world, 0)
    var colour_image: Image = root.get_texture().get_image()
    var colour: Image = recipient_crop(world, colour_image)
    colour_image.save_png(CAPTURES + "/paused-colour-treatment.png")
    check(full.get_data() != colour.get_data(), "Mode control changes actual recipient pixels at the same pose and source time")
    await tint_recipient(world, changed_tints)
    check(colour.get_data() != recipient_crop(world, root.get_texture().get_image()).get_data(),
        "Colour-treatment control retains outfit tint dependence on visible receiver pixels")
    await tint_recipient(world, original_tints)
    await appearance(world, 1)
    check(full.get_data() == recipient_crop(world, root.get_texture().get_image()).get_data(),
        "Switching back restores the same paused full-material pixels")
    check(world.playbacks.target.clip == "TakeDamage" and is_equal_approx(world.playbacks.target.sample_seconds, source_age),
        "Mode changes preserve the receiving pose and its clock")

func capability_coverage(world: Node) -> void:
    var damaging := 0
    var non_damaging := 0
    var available := 0
    var unsupported := 0
    for index in world.spells.size():
        world.rotate_view(-world.quarter)
        world.split_targets = world.spells[index].spell_id == "magic_missile"
        world.select_spell(index)
        pause_world(world)
        world.spell_hit_flash = true
        var id: String = world.spell.spell_id
        var damage: bool = world.recipe.get("damage") != null
        var native_available: bool = world.body_material.material != null
        if native_available:
            available += 1
            await appearance(world, 1)
        else:
            check(world.hit_appearance == 0 and world.hit_appearance_choice.selected == 0,
                id + ": unavailable native material visibly falls back to Colour treatment")
            check(world.hit_appearance_choice.is_item_disabled(1), id + ": unavailable native choice is disabled")
            if damage:
                unsupported += 1
                var reason: String = world.body_material.definition.get("reason", "")
                check(not reason.is_empty() and world.hit_appearance_choice.tooltip_text.contains(reason),
                    id + ": unsupported native material exposes its source-specific reason")
        if damage: damaging += 1
        else: non_damaging += 1
        var contacts: Array = world.cue_plan.contacts.duplicate(true)
        var observed: Array = []
        if damage:
            check(not world.feedback.flash.is_empty() and world.feedback.flash.get("enabled", false), id + ": damaging spell has enabled receiver authoring")
            check(not world.feedback.colors.is_empty(), id + ": receiver has a resolved material palette")
            check(not contacts.is_empty(), id + ": damaging fixture has contacts")
        var expected_targets: Dictionary = {}
        for contact in contacts:
            world.elapsed = float(contact.time) + float(world.feedback.flash.get("holdMs",0.0)) / 2000.0
            world._sample_frame(0.0)
            await frame()
            await frame()
            var target: String = contact.target
            expected_targets[target] = true
            var current := receiver(world, target)
            var flashes: Array = world.displayed_components.filter(func(sample): return sample.kind == "material_flash")
            if damage:
                check(flashes.any(func(sample): return sample.actor_uuid == target), id + ": contact%d owns recipient%s flash" % [contact.index, target])
                check(current.drawable_layers > 0 and current.active_layers == current.drawable_layers and current.source_output_agree,
                    id + ": contact%d binds every painted recipient layer" % contact.index)
                check(world.playbacks[target].clip == "TakeDamage", id + ": contact%d has receiving body animation" % contact.index)
                check_receiver_native(world, target, native_available, id + ": contact%d" % contact.index)
                if native_available:
                    check(world.body_material.surfaces.has(target), id + ": native sampler exists for recipient " + target)
                    var surface: Dictionary = world.body_material.surfaces[target]
                    var actor_samples: Array = flashes.filter(func(sample): return sample.actor_uuid == target)
                    var clock: String = world.body_material.definition.get("clock_parameter", "")
                    if not clock.is_empty():
                        check(is_equal_approx(float(surface.material.get_shader_parameter(clock)), float(actor_samples.back().age_ms) / 1000.0),
                            id + ": recipient-specific source clock matches its latest contact")
                    if int(contact.index) == int(contacts[0].index):
                        await capture_material(world, id, target, 0)
                        if id == "fire_bolt":
                            for view in [1, 2, 3]:
                                world.rotate_view(view - world.quarter)
                                await frame()
                                await frame()
                                await capture_material(world, id, target, view)
                            world.rotate_view(-world.quarter)
                            await frame()
                            await frame()
                var reaction_age: float = world.playbacks[target].sample_seconds
                world.spell_hit_flash = false
                world._sample_frame(0.0)
                await frame()
                check(receiver(world, target).active_layers == 0, id + ": flash toggle immediately clears receiving material")
                check_receiver_native(world, target, false, id + ": flash toggle")
                check(world.playbacks[target].clip == "TakeDamage" and is_equal_approx(world.playbacks[target].sample_seconds, reaction_age),
                    id + ": flash toggle preserves the contact animation and time")
                world.spell_hit_flash = true
                world._sample_frame(0.0)
                await frame()
                check(receiver(world, target).active_layers == receiver(world, target).drawable_layers,
                    id + ": paused toggle restores the receiving material")
            else:
                check(flashes.is_empty(), id + ": non-damaging contact does not invent a damage flash")
                for actor in world.actor_markers:
                    check(receiver(world, str(actor)).active_layers == 0, id + ": non-damage leaves%s without flash" % actor)
            observed.append({"index":contact.index, "target":target, "time":contact.time,
                "drawable_layers":current.drawable_layers, "active_layers":current.active_layers})
        if id == "magic_missile":
            check(contacts.size() == 3 and expected_targets.has("target") and expected_targets.has("target2"),
                "Magic Missile samples all three deliveries across both split recipients")
            if native_available and world.body_material.surfaces.has("target") and world.body_material.surfaces.has("target2"):
                check(world.body_material.surfaces.target.material != world.body_material.surfaces.target2.material,
                    "Magic Missile split recipients own independent native material clocks")
        if not contacts.is_empty():
            world.elapsed = float(contacts.back().time) + float(world.feedback.flash.get("durationMs", 150.0)) / 1000.0 + .02
            world._sample_frame(0.0)
            await frame()
            for actor in world.actor_markers:
                check(receiver(world, str(actor)).active_layers == 0, id + ": recipient%s flash expires after the last contact" % actor)
                check_receiver_native(world, str(actor), false, id + ": expiry " + str(actor))
        else:
            world.elapsed = minf(world.duration * .5, world.release + .2)
            world._sample_frame(0.0)
            await frame()
            for actor in world.actor_markers:
                check(receiver(world, str(actor)).active_layers == 0, id + ": no-contact spell never invents damage")
                check_receiver_native(world, str(actor), false, id + ": no contact " + str(actor))
        world.restart()
        pause_world(world)
        await frame()
        check(is_zero_approx(world.elapsed), id + ": recast resets the local timeline")
        for actor in world.actor_markers:
            check(receiver(world, str(actor)).active_layers == 0, id + ": recast clears prior receiving flash")
            check_receiver_native(world, str(actor), false, id + ": recast " + str(actor))
        var paused_at: float = world.elapsed
        await frame()
        await frame()
        check(is_equal_approx(world.elapsed, paused_at), id + ": pause holds the recast clock")
        coverage.append({"spell":id, "damaging":damage, "contacts":observed,
            "native_available":native_available, "native_definition":world.body_material.definition.duplicate(true),
            "palette_count":world.feedback.colors.size(), "qualification":"Paused contact sampling, actual native texture/final-frame capture, toggle/expiry/recast. Pixel evidence does not constitute artistic approval."})
        print("FLASH_LIBRARY_DONE ", id)
    check(damaging == 16 and non_damaging == 18, "All current 34 capabilities are classified:16 damaging,18 non-damaging")
    check(available == 12 and unsupported == 4, "Native mappings classify 12 available and four explicit unsupported damaging spells")

func check_receiver_native(world: Node, actor: String, enabled: bool, label: String) -> void:
    for entry in world.visual_actors[actor].entries:
        if entry.role == "shadow" or not entry.node.is_visible_in_tree(): continue
        var output: ShaderMaterial = entry.node.material_override
        check(bool(output.get_shader_parameter("native_body_enabled")) == enabled,
            label + ": " + entry.actor_layer.slot + " native mode agrees with its current contact")
        if not enabled:
            check(is_zero_approx(float(output.get_shader_parameter("native_body_strength"))),
                label + ": " + entry.actor_layer.slot + " inactive native strength is zero")
            check(output.get_shader_parameter("native_body_surface") == null,
                label + ": " + entry.actor_layer.slot + " inactive viewport binding is cleared")

func material_stats(image: Image) -> Dictionary:
    var nonblack := 0
    var covered := 0
    var maximum := 0.0
    var minimum := INF
    var sum := 0.0
    for y in image.get_height():
        for x in image.get_width():
            var color := image.get_pixel(x, y)
            var energy := maxf(color.r, maxf(color.g, color.b))
            if energy > 0.0: nonblack += 1
            if color.a > 0.0: covered += 1
            maximum = maxf(maximum, energy)
            minimum = minf(minimum, energy)
            sum += energy
    return {"width":image.get_width(), "height":image.get_height(), "rgb_nonzero_pixels":nonblack,
        "alpha_nonzero_pixels":covered, "minimum_energy":minimum, "maximum_energy":maximum,
        "mean_energy":sum / float(image.get_width() * image.get_height())}

func capture_material(world: Node, id: String, target: String, view: int) -> void:
    var prefix := CAPTURES + "/library-" + id + "-v%d" % view
    var full: Image = root.get_texture().get_image()
    full.save_png(prefix + "-full.png")
    var native_image: Image = world.body_material.surfaces[target].viewport.get_texture().get_image()
    native_image.save_png(prefix + "-native-surface.png")
    var stats := material_stats(native_image)
    check(stats.rgb_nonzero_pixels > 0, id + " view%d: native quad produces colour, including zero-alpha additive radiance" % view)
    check(stats.maximum_energy > stats.minimum_energy, id + " view%d: actual source surface is not a blank uniform quad" % view)
    var material: Material = world.body_material.surfaces[target].material
    var shader_path: String = material.shader.resource_path if material is ShaderMaterial else ""
    var full_crop: Image = recipient_crop(world, full)
    await appearance(world, 0)
    var colour: Image = root.get_texture().get_image()
    colour.save_png(prefix + "-colour-control.png")
    var differs: bool = full_crop.get_data() != recipient_crop(world, colour).get_data()
    var unobscured_differs: bool = differs
    if not differs:
        # A native explosion can completely cover its recipient. Keep the full
        # scene capture honest, and qualify body output separately without
        # changing any actor, native material, clock, or receiving light.
        var output: CanvasItem = world.effect_layer.output
        var original_visibility: bool = output.visible
        output.hide()
        await frame()
        var isolated_colour: Image = root.get_texture().get_image()
        isolated_colour.save_png(prefix + "-unobscured-colour.png")
        await appearance(world, 1)
        var isolated_full: Image = root.get_texture().get_image()
        isolated_full.save_png(prefix + "-unobscured-full.png")
        unobscured_differs = recipient_crop(world, isolated_full).get_data() != recipient_crop(world, isolated_colour).get_data()
        output.visible = original_visibility
        await frame()
    check(unobscured_differs, id + " view%d: native material changes recipient pixels when source effects do not cover them" % view)
    await appearance(world, 1)
    check(world.playbacks[target].clip == "TakeDamage", id + " view%d: captured full body remains the contact animation" % view)
    material_captures.append({"spell":id, "view":view, "elapsed":world.elapsed, "target":target,
        "material_class":material.get_class(), "shader":shader_path, "source_pixels":stats,
        "full_vs_colour_recipient_differs":differs, "unobscured_recipient_differs":unobscured_differs, "capture_prefix":prefix,
        "qualification":"Source nonzero/variation checks reject blank material sampling only; they are not a perceptual readability threshold."})

func run() -> void:
    DirAccess.make_dir_recursive_absolute(CAPTURES)
    var scene: PackedScene = load("res://spell-sandbox.tscn")
    var world: Node = scene.instantiate()
    root.add_child(world)
    pause_world(world)
    check(world.fixture_ready and world.presentation_errors.is_empty(), "Actual sandbox fixture prepares without presentation errors")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 60
    await real_playback(world)
    await paused_mode_control(world)
    if "--all-capabilities" in OS.get_cmdline_user_args():
        await capability_coverage(world)
    check(world.presentation_errors.is_empty(), "Playback and full contact audit add no presentation errors")
    var report := {"checks":checks, "failures":failures,
        "renderer":RenderingServer.get_current_rendering_method(), "cycles":cycles, "coverage":coverage, "material_captures":material_captures,
        "scope":"Two actual1x Fire Bolt cycles including automatic loop, native material animation and paused mode/tint controls. Optional --all-capabilities audits every contact binding separately. No arbitrary pixel count claims visual readability. User preview remains a separate untouched process."}
    FileAccess.open(REPORT, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
    print("SANDBOX_FLASH_PLAYBACK ", JSON.stringify({"checks":checks, "failures":failures, "report":REPORT}))
    world.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
