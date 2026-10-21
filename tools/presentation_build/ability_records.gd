extends RefCounted
## The abilities source (typed entries) and the records the game reads today,
## both ways. `*_from_*` fill an entry from an old record (the converter);
## the other functions write the record back from the entry (the build).
## The build's output is exactly today's records, so the switch to it keeps
## every pixel; later steps can change the runtime shape without touching
## the source.
const F = preload("res://tools/presentation_build/ability_fields.gd")
const EffectUse = preload("res://presentation/source/effect_use.gd")
const Look = preload("res://presentation/source/look.gd")
const LookStep = preload("res://presentation/source/look_step.gd")
const Palette = preload("res://presentation/source/palette.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const CastLayer = preload("res://presentation/source/abilities/cast_layer.gd")
const Feedback = preload("res://presentation/source/abilities/feedback.gd")

## Fields of the old staging cues that are prose or calibration notes with no
## reader (footprint, notes, sandbox ids); the converter leaves them out.
const DEAD_CUE_FIELDS := ["footprint", "registration_note", "timing_note", "id"]
const HIDDEN_SLOTS := ["weapon", "offhand"]

# --- Shared pieces ---------------------------------------------------------

## A palette_ramp look from an old palette {colors, noiseSheet, gamma}.
static func ramp_from(raw: Dictionary, path: String, kind: String = "colours") -> Look:
    if not F.value_at(raw, path) is Dictionary:return null
    var step := LookStep.new();step.kind = "palette_ramp"
    var moved := F.move(raw, path + "/colors", step, "colours", kind)
    moved = F.move(raw, path + "/noiseSheet", step, "noise", "string") or moved
    moved = F.move(raw, path + "/gamma", step, "gamma", "float") or moved
    if not moved:return null
    var look := Look.new();look.steps.append(step)
    return look

static func ramp_to(record: Dictionary, path: String, look: Look, kind: String = "colours") -> void:
    if look == null or look.steps.is_empty():return
    var step: LookStep = look.steps[0]
    if not F.has_path(record, path):F.put(record, path, {})
    F.emit(record, path + "/colors", step, "colours", kind)
    F.emit(record, path + "/noiseSheet", step, "noise", "string")
    F.emit(record, path + "/gamma", step, "gamma", "float")

## A body from an old actor block {enabled, clip, playbackSpeed, hiddenSlots}
## (every field always present in those blocks).
static func body_from_actor(raw: Dictionary, path: String, role: String) -> BodyUse:
    if not F.value_at(raw, path) is Dictionary:return null
    var body := BodyUse.new();body.role = role
    F.move(raw, path + "/clip", body, "clip", "string", true)
    F.move(raw, path + "/enabled", body, "enabled", "bool", true)
    F.move(raw, path + "/playbackSpeed", body, "playback_speed", "float", true)
    F.move(raw, path + "/hiddenSlots", body, "hidden_slots", "strings", true)
    return body

static func body_to_actor(record: Dictionary, path: String, body: BodyUse) -> void:
    if body == null:return
    if not F.has_path(record, path):F.put(record, path, {})
    F.emit(record, path + "/enabled", body, "enabled", "bool", true)
    F.emit(record, path + "/clip", body, "clip", "string", true)
    F.emit(record, path + "/playbackSpeed", body, "playback_speed", "float", true)
    F.emit(record, path + "/hiddenSlots", body, "hidden_slots", "strings", true)

## Typed body fields are editable source operands, including newly authored
## entries with no imported overlay metadata. Preserve a raw value's existing
## provenance whenever the emitter leaves that value in place.
static func _body_sources(record:Dictionary,before:Dictionary,source:String,fields:Dictionary)->void:
    if source.is_empty():return
    for field in fields:
        if F.has_path(before,field) or not F.has_path(record,field):continue
        record._resource_source=source
        if not record.has("_source_fields"):record._source_fields={}
        record._source_fields[field]=source+"::body/"+str(fields[field])

## Marker order when two share a frame.
const MARKER_ORDER := ["action_start", "prepare", "release", "contact", "effect", "commit", "recover"]

## Old anchors [{name, frame}] -> body markers, when every name is distinct
## and the list is in frame order (an empty or irregular list stays as exported).
static func markers_from(raw: Dictionary, path: String, body: BodyUse) -> void:
    var anchors: Variant = F.value_at(raw, path)
    if body == null or not anchors is Array or anchors.is_empty():return
    var names := {}
    for anchor in anchors:
        if not anchor is Dictionary or anchor.keys() != ["name", "frame"] or not anchor.name is String or not anchor.frame is float or names.has(anchor.name):return
        names[anchor.name] = anchor.frame
    if not F.same(anchor_list(names), anchors):return
    for name in names:body.markers[name] = names[name]
    F.erase_path(raw, path)

## Markers as the old anchors list: by frame, then by MARKER_ORDER.
static func anchor_list(markers: Dictionary) -> Array:
    var names: Array = markers.keys()
    names.sort_custom(func(a, b):
        if markers[a] != markers[b]:return markers[a] < markers[b]
        var left: int = MARKER_ORDER.find(a);var right: int = MARKER_ORDER.find(b)
        return (left if left >= 0 else 99) < (right if right >= 0 else 99) if left != right else str(a) < str(b))
    return names.map(func(name): return {"name": name, "frame": markers[name]})

static func markers_to(record: Dictionary, path: String, body: BodyUse) -> void:
    if body == null or body.markers.is_empty() or F.has_path(record, path):return
    F.put(record, path, anchor_list(body.markers))

## Feedback text from an old block, with that block's own key names.
static func feedback_from(raw: Dictionary, path: String, keys: Dictionary) -> Feedback:
    if not F.value_at(raw, path) is Dictionary:return null
    var feedback := Feedback.new()
    var moved := false
    for property in keys:moved = F.move(raw, path + "/" + keys[property][0], feedback, property, keys[property][1], keys[property][2]) or moved
    return feedback if moved else null

static func feedback_to(record: Dictionary, path: String, feedback: Feedback, keys: Dictionary) -> void:
    if feedback == null:return
    if not F.has_path(record, path):F.put(record, path, {})
    for property in keys:F.emit(record, path + "/" + keys[property][0], feedback, property, keys[property][1], keys[property][2])

# --- Effects (staging cues) ------------------------------------------------

const CUE_FIELDS := [
    ["area_mask", "area_mask", "bool", true],
    ["clip", "clip", "string", true], ["role", "role", "string", true], ["scale", "scale", "float", true],
    ["selection", "selection", "string", false],
    ["at", "at", "string", false], ["delay_seconds", "delay", "float", false],
    ["approach", "approach", "string", false],
    ["immutable_preparation", "immutable_preparation", "string", false],
    ["preparation_inputs", "preparation_inputs", "string", false],
    ["sampling", "sampling", "string", false], ["scope", "scope", "string", false], ["constructor_input", "constructor_input", "same", false], ["observed_result", "observed_result", "same", false], ["incoming_track", "incoming_track", "same", false], ["movement", "movement", "same", false], ["condition_response", "condition_response", "same", false],
    ["endpoint_actor_uuids", "endpoint_actor_uuids", "bool", false],
    ["when", "when", "same", false],
    ["owner_projection", "owner_projection", "same", false],
    ["requires_spatial_anchor", "requires_spatial_anchor", "bool", false],
    ["item_effect_behavior_id", "item_effect_behavior_id", "string", false],
    ["item_effect_damage_type", "item_effect_damage_type", "string", false],
    ["replaces_cast_body", "replaces_cast_body", "bool", false],
    ["input_arguments", "input_arguments", "same", false],
    ["lifecycle", "lifecycle", "same", false],
    ["attachment", "attachment", "string", false], ["orientation", "orientation", "string", false],
    ["offset", "offset", "vec3", false],
    ["recipient_slots", "recipient_slots", "strings", false], ["follow", "follow", "bool", false],
    ["rotation_degrees", "rotation_degrees", "vec3", false],
    ["axis_scale", "axis_scale", "vec3", false],
    ["source_start", "source_start", "float", false],
    ["source_launch", "source_launch", "float", false], ["source_contact", "source_contact", "float", false],
    ["result_contact_seconds", "result_contact_seconds", "float", false],
    ["source_end", "source_end", "float", false], ["source_rate", "source_rate", "float", false],
    ["charge_seconds", "charge_seconds", "float", false], ["charge_scale_from", "charge_scale_from", "float", false],
    ["duration_policy", "duration_policy", "string", false],
    ["stop_emission_at_contact", "stop_emission_at_contact", "bool", false],
    ["stop_emission_at_release", "stop_emission_at_release", "bool", false],
    ["emission_seconds", "emission_seconds", "float", false],
    ["contact_hide", "hide_at_contact", "strings", false], ["release_hide", "hide_at_release", "strings", false],
    ["hide_nodes", "hide_nodes", "strings", false], ["show_nodes", "show_nodes", "strings", false],
    ["origin_path", "origin_path", "string", false],
    ["opacity_keys", "opacity_keys", "vec2s", false], ["opacity_uniform", "opacity_uniform", "string", false],
    ["light_color", "light_colour", "colour_html", false], ["light_multiplier", "light_multiplier", "float", false],
    ["fade_in_seconds", "fade_in", "float", false], ["fade_out_seconds", "fade_out", "float", false],
    ["unbound_constructor_inputs", "unbound_constructor_inputs", "strings", false],
]

## One staged cue -> an effect use; fields with no typed home stay in `extra`.
static func effect_from_cue(cue: Dictionary, staging_from: String, drop_dead: bool = true) -> EffectUse:
    var raw: Dictionary = cue.duplicate(true)
    raw.erase("source_index")
    if drop_dead:
        for field in DEAD_CUE_FIELDS:raw.erase(field)
    var use := EffectUse.new()
    if raw.has("source_phase"):
        use.source_phase=load(str(raw.source_phase));raw.erase("source_phase")
        use.source_inputs.assign(raw.get("source_inputs",{}));raw.erase("source_inputs")
        use.source_seekable=bool(raw.get("source_seekable",false));raw.erase("source_seekable")
    for field in CUE_FIELDS:F.move(raw, field[0], use, field[1], field[2], field[3])
    use.extra = F.plain(raw)
    use.staging_from = staging_from
    return use

static func cue_from_effect(use: EffectUse, index: int) -> Dictionary:
    var cue := {}
    for field in CUE_FIELDS:F.emit(cue, field[0], use, field[1], field[2], field[3])
    if use.source_phase!=null:
        cue.source_phase=use.source_phase.resource_path
        cue.source_inputs=use.source_inputs.duplicate()
        cue.source_seekable=use.source_seekable
    cue.merge(use.extra.duplicate(true), true)
    if index >= 0:cue.source_index = index
    return cue

# --- Spells: the old recipe (spells/<id>.json) ------------------------------

## Fills the body, hand layers, colours, flight and hit of `e` from the old
## recipe; returns the measured sockets (old path -> value) for the file
## beside it and leaves everything else in `e.unported`.
static func spell_from_recipe(e: Resource, recipe: Dictionary) -> Dictionary:
    var raw: Dictionary = recipe.duplicate(true)
    var sockets := {}
    for path in ["cast/sourceSockets", "cast/sourceSocketsByRig", "projectile/sourceSockets", "projectile/sourceAnchorsByFacing"]:
        if F.has_path(raw, path):sockets[path] = F.value_at(raw, path);F.erase_path(raw, path)
    if raw.get("cast") is Dictionary:
        var body := BodyUse.new();body.role = "cast"
        F.move(raw, "cast/actionClip", body, "clip", "string", true)
        F.move(raw, "cast/bodyPlaybackSpeed", body, "playback_speed", "float", true)
        F.move_item(raw, "cast/releaseFrame", body, "markers", "release", "float")
        F.move(raw, "cast/enabled", body, "enabled", "bool")
        if F.same(raw.cast.get("equipment"), {"kind": "hidden"}):
            body.hidden_slots = PackedStringArray(HIDDEN_SLOTS);raw.cast.erase("equipment")
        for place in ["weaponGlow", "aura"]:
            if raw.cast.get(place) is Dictionary:
                var layer := cast_layer_from(raw.cast[place], "aura" if place == "aura" else "weapon_glow")
                e.hand_layers.append(layer);raw.cast.erase(place)
        if raw.cast.get("effects") is Array:
            for item in raw.cast.effects:e.hand_layers.append(cast_layer_from(item, "effect"))
            raw.cast.erase("effects")
        body.unported = F.plain(raw.cast);raw.erase("cast")
        e.body = body
    if raw.get("elementColors") is Dictionary:
        e.colours = Palette.new()
        for role in ["primary", "secondary", "tertiary"]:F.move_item(raw, "elementColors/" + role, e.colours, "roles", role, "colour")
        if raw.elementColors.is_empty():raw.erase("elementColors")
    if raw.get("projectile") is Dictionary:
        F.move(raw, "projectile/speedPxPerSecond", e, "flight_tiles_per_second", "tiles", true)
        F.move(raw, "projectile/minimumTravelDurationMs", e, "minimum_travel_seconds", "ms", true)
        F.move(raw, "projectile/missileStaggerMs", e, "stagger_seconds", "ms", true)
    if raw.get("damage") is Dictionary:
        F.move(raw, "damage/impactDelayMs", e, "impact_delay", "ms", true)
        F.move(raw, "damage/hitFlash/frame", e, "flash_frame", "float", true)
        F.move(raw, "damage/hitFlash/durationMs", e, "flash_duration", "ms", true)
        e.flash_look = ramp_from(raw, "damage/hitFlash/palette")
        F.move(raw, "damage/floatingNumber/frame", e, "number_frame", "float", true)
        F.move(raw, "damage/floatingNumber/durationMs", e, "number_duration", "ms", true)
    e.unported = F.plain(raw)
    return sockets

static func cast_layer_from(layer: Dictionary, place: String) -> CastLayer:
    var raw: Dictionary = layer.duplicate(true)
    var result := CastLayer.new();result.place = place
    F.move(raw, "category", result, "category", "string", true)
    F.move(raw, "sourceSheet", result, "sheet", "string", true)
    F.move(raw, "enabled", result, "enabled", "bool", true)
    F.move(raw, "hidden", result, "hidden", "bool", true)
    result.look = ramp_from(raw, "palette")
    result.unported = F.plain(raw)
    return result

static func cast_layer_to(layer: CastLayer) -> Dictionary:
    var record: Dictionary = layer.unported.duplicate(true)
    F.emit(record, "enabled", layer, "enabled", "bool", true)
    F.emit(record, "hidden", layer, "hidden", "bool", true)
    F.emit(record, "category", layer, "category", "string", true)
    F.emit(record, "sourceSheet", layer, "sheet", "string", true)
    ramp_to(record, "palette", layer.look)
    return record

## The old recipe from the entry (`sockets` is its measured file).
static func spell_recipe(e: Resource, sockets: Dictionary) -> Dictionary:
    var record: Dictionary = e.unported.duplicate(true)
    if e.body != null:
        var cast: Dictionary = e.body.unported.duplicate(true)
        record.cast = cast
        F.emit(record, "cast/actionClip", e.body, "clip", "string", true)
        F.emit(record, "cast/bodyPlaybackSpeed", e.body, "playback_speed", "float", true)
        F.emit_item(record, "cast/releaseFrame", e.body, "markers", "release")
        F.emit(record, "cast/enabled", e.body, "enabled", "bool")
        if Array(e.body.hidden_slots) == HIDDEN_SLOTS:cast.equipment = {"kind": "hidden"}
        _body_sources(record,{"cast":e.body.unported},e.resource_path,{
            "cast/actionClip":"clip","cast/bodyPlaybackSpeed":"playback_speed"})
        if e.body.markers.has("release"):
            _body_sources(record,{},e.resource_path,{"cast/releaseFrame":"markers/release"})
        if not F.same(e.body.enabled,F.default_of(e.body,"enabled")):
            _body_sources(record,{},e.resource_path,{"cast/enabled":"enabled"})
        if Array(e.body.hidden_slots)==HIDDEN_SLOTS:
            _body_sources(record,{},e.resource_path,{"cast/equipment":"hidden_slots"})
        var effects: Array = []
        for layer in e.hand_layers:
            match layer.place:
                "weapon_glow":cast.weaponGlow = cast_layer_to(layer)
                "aura":cast.aura = cast_layer_to(layer)
                _:effects.append(cast_layer_to(layer))
        cast.effects = effects
    if e.colours != null:
        if not record.has("elementColors"):record.elementColors = {}
        for role in ["primary", "secondary", "tertiary"]:F.emit_item(record, "elementColors/" + role, e.colours, "roles", role, "colour")
    if record.get("projectile") is Dictionary:
        F.emit(record, "projectile/speedPxPerSecond", e, "flight_tiles_per_second", "tiles")
        F.emit(record, "projectile/minimumTravelDurationMs", e, "minimum_travel_seconds", "ms")
        F.emit(record, "projectile/missileStaggerMs", e, "stagger_seconds", "ms")
    # An authored typed delay creates its own section; imported legacy damage
    # fields are not a prerequisite for a new spell's impact chronology.
    F.emit(record, "damage/impactDelayMs", e, "impact_delay", "ms")
    if record.get("damage") is Dictionary:
        F.emit(record, "damage/hitFlash/frame", e, "flash_frame", "float")
        F.emit(record, "damage/hitFlash/durationMs", e, "flash_duration", "ms")
        ramp_to(record, "damage/hitFlash/palette", e.flash_look)
        F.emit(record, "damage/floatingNumber/frame", e, "number_frame", "float")
        F.emit(record, "damage/floatingNumber/durationMs", e, "number_duration", "ms")
    for path in sockets:F.put(record, path, F.deep(sockets[path]))
    return record

# --- Spells: native staging (the old import's selection) --------------------

## Fills the staged effects, lifecycle owner, light, finish and hit material
## of `e` from the old import's selection; returns the measured bounds.
static func spell_from_selection(e: Resource, selection: Dictionary, hit: Dictionary, staging_from: String) -> Dictionary:
    var raw: Dictionary = selection.duplicate(true)
    for field in ["id", "clips", "clip_by_id"]:raw.erase(field)
    var bounds: Dictionary = raw.get("source_bounds", {});raw.erase("source_bounds")
    var staging: Dictionary = raw.get("staging", {});raw.erase("staging")
    for cue in staging.get("cues", []):e.effects.append(effect_from_cue(cue, staging_from))
    staging.erase("cues")
    staging.erase("light_color_source")
    F.move(staging, "bends", e, "bends", "same", true)
    F.move(staging, "light_color", e, "light_colour", "string", true)
    F.move(staging, "decorative_light_multiplier", e, "light_multiplier", "float", true)
    if staging.get("feedback_palette") is Dictionary:
        staging.feedback_palette.erase("source")
        F.move(staging, "feedback_palette/colors", e, "feedback_ramp", "strings", true)
        if staging.feedback_palette.is_empty():staging.erase("feedback_palette")
    var delivery: Dictionary = raw.get("delivery", {});raw.erase("delivery")
    delivery.erase("authored_footprints")
    F.move(delivery, "scope", e, "effect_scope", "string", true)
    F.move(delivery, "roles", e, "effect_roles", "strings", true)
    F.move(delivery, "effects", e, "effect_roles_by_effect", "same", true)
    F.move(raw, "event_cue_indices", e, "event_cues", "ints", true)
    F.move(raw, "explicit_event_cues", e, "explicit_event_cues", "bool", true)
    F.move(raw, "excluded_cue_indices", e, "excluded_cues", "ints", true)
    var lifecycle: Dictionary = raw.get("lifecycle", {});raw.erase("lifecycle")
    lifecycle.erase("replaces_media")
    F.move(lifecycle, "owner_kind", e, "owner_kind", "string", true)
    F.move(lifecycle, "owner_ids", e, "owner_ids", "strings", true)
    F.move(lifecycle, "cue_ids", e, "owner_cues", "float_ints", true)
    F.move(lifecycle, "contact_cue_ids", e, "contact_cues", "float_ints", true)
    F.move(lifecycle, "optical_owner", e, "optical_owner", "string", true)
    var windows: Dictionary = lifecycle.get("cues", {});lifecycle.erase("cues")
    for index in windows:
        var window: Dictionary = windows[index].duplicate(true)
        window.erase("source_evidence")
        e.effects[int(index)].lifecycle = window
    var finish: Dictionary = raw.get("palette", {});raw.erase("palette")
    if not finish.is_empty():
        var step := LookStep.new();step.kind = "palette_ramp"
        F.move(finish, "ramp", step, "colours", "hex_colours")
        F.move(finish, "parameters/ramp_floor", step, "ramp_floor", "float")
        F.move(finish, "parameters/ramp_ceiling", step, "ramp_ceiling", "float")
        F.move(finish, "parameters/ramp_uses_luma", step, "uses_luma", "bool")
        e.finish = Look.new();e.finish.steps.append(step)
    e.body_material = F.plain(hit.get("definition", {}))
    for field in ["cue_role", "material_class", "source_note"]:e.body_material.erase(field)
    var rest := {}
    for key in raw:rest[key] = raw[key]
    if not staging.is_empty():rest["staging"] = staging
    if not delivery.is_empty():rest["delivery"] = delivery
    if not lifecycle.is_empty():rest["lifecycle"] = lifecycle
    if not finish.is_empty():rest["palette"] = finish
    e.staging_unported = F.plain(rest)
    e.staging_from = staging_from
    return bounds

## The finish profile of the staged effects (the old import's palette).
static func spell_finish(e: Resource) -> Dictionary:
    var finish: Dictionary = e.staging_unported.get("palette", {}).duplicate(true)
    if e.finish != null and not e.finish.steps.is_empty():
        var step: LookStep = e.finish.steps[0]
        F.emit(finish, "ramp", step, "colours", "hex_colours")
        F.emit(finish, "parameters/ramp_floor", step, "ramp_floor", "float")
        F.emit(finish, "parameters/ramp_ceiling", step, "ramp_ceiling", "float")
        F.emit(finish, "parameters/ramp_uses_luma", step, "uses_luma", "bool")
    return finish

## The selection the game's native spell path reads.
static func spell_selection(e: Resource, short_id: String, bounds: Dictionary) -> Dictionary:
    var staging: Dictionary = e.staging_unported.get("staging", {}).duplicate(true)
    var cues: Array = []
    for i in e.effects.size():
        var cue:Dictionary=cue_from_effect(e.effects[i], i)
        if not e.resource_path.is_empty():cue.source=e.resource_path+"::effects/"+str(i)
        cues.append(cue)
    staging.cues = cues
    F.emit(staging, "bends", e, "bends")
    F.emit(staging, "light_color", e, "light_colour", "string")
    F.emit(staging, "decorative_light_multiplier", e, "light_multiplier", "float")
    if not e.feedback_ramp.is_empty():F.put(staging, "feedback_palette/colors", Array(e.feedback_ramp))
    var lifecycle: Dictionary = e.staging_unported.get("lifecycle", {}).duplicate(true)
    if not e.owner_kind.is_empty():
        F.emit(lifecycle, "cue_ids", e, "owner_cues", "float_ints", true)
        var windows := {}
        for i in e.effects.size():
            if not e.effects[i].lifecycle.is_empty():windows[str(i)] = e.effects[i].lifecycle.duplicate(true)
        if not windows.is_empty():lifecycle.cues = windows
        F.emit(lifecycle, "owner_ids", e, "owner_ids", "strings", true)
        F.emit(lifecycle, "owner_kind", e, "owner_kind", "string", true)
        F.emit(lifecycle, "contact_cue_ids", e, "contact_cues", "float_ints")
        F.emit(lifecycle, "optical_owner", e, "optical_owner", "string")
    var delivery: Dictionary = e.staging_unported.get("delivery", {}).duplicate(true)
    F.emit(delivery, "scope", e, "effect_scope", "string", true)
    F.emit(delivery, "roles", e, "effect_roles", "strings")
    F.emit(delivery, "effects", e, "effect_roles_by_effect")
    var result := {"id": short_id, "palette": spell_finish(e), "source_bounds": F.deep(bounds), "lifecycle": lifecycle,
        "delivery": delivery, "event_cue_indices": Array(e.event_cues).map(func(i): return int(i)), "explicit_event_cues": e.explicit_event_cues,
        "excluded_cue_indices": Array(e.excluded_cues).map(func(i): return int(i)), "staging": staging}
    for key in e.staging_unported:
        if key not in ["staging", "lifecycle", "delivery", "palette"]:result[key] = F.deep(e.staging_unported[key])
    if not result.has("source") or str(result.source).is_empty():result.source=e.resource_path
    result._resource_source=e.resource_path
    return result

## Variant cues replace the finite event selection; the base cast body stays
## shared by the real cast. Build validation rejects inherited index policies
## that would refer to a different cue list.
static func variant_selection(base:Dictionary,variant:Resource)->Dictionary:
    var selected:Dictionary=base.duplicate()
    selected.staging=base.staging.duplicate()
    if not variant.effects.is_empty():
        selected.staging.cues=[]
        for i in variant.effects.size():
            var cue:Dictionary=cue_from_effect(variant.effects[i],i)
            cue.source=str(base.get("_resource_source",base.source))+"::variants/"+variant.id+"/effects/"+str(i)
            selected.staging.cues.append(cue)
    if variant.override_owner_cues:
        selected.lifecycle=base.lifecycle.duplicate()
        selected.lifecycle.cue_ids=Array(variant.owner_cues)
        if not variant.effects.is_empty():
            selected.lifecycle.erase("cues")
            var windows:Dictionary={}
            for i in variant.effects.size():
                if not variant.effects[i].lifecycle.is_empty():windows[str(i)]=variant.effects[i].lifecycle.duplicate()
            if not windows.is_empty():selected.lifecycle.cues=windows
    selected.variant={"id":variant.id,"when":F.deep(variant.when),"save_effect_id":variant.save_effect_id,"selection":variant.selection,"replaces_effects":not variant.effects.is_empty()}
    return selected

## The native hit record (body material and finish) the game reads.
static func spell_hit(e: Resource, short_id: String) -> Dictionary:
    var hit := {"spell_id": short_id, "definition": e.body_material.duplicate(true), "finish_profile": spell_finish(e)}
    if e.body_material.get("status") == "available":hit.clip = {"id": str(e.body_material.get("clip", ""))}
    return hit

# --- Conditions (catalog/condition_recipes.json with the old .tres overlays applied) ---

const CONDITION_TEXT := {"enabled": ["feedbackEnabled", "bool", true], "colour": ["feedbackColor", "colour", true],
    "prefix": ["feedbackPrefix", "string", false], "duration": ["feedbackDurationMs", "ms", false]}
const POSE_KEYS := [["rigId", "rig"], ["activity", "activity"], ["clip", "clip"], ["sampling", "sampling"], ["frame", "frame"], ["playbackSpeed", "playback_speed"]]

static func step_of(look: Look, kind: String, role: String = "") -> LookStep:
    if look == null:return null
    for step in look.steps:
        if step.kind == kind and (role.is_empty() or step.pose_role == role):return step
    return null

static func condition_from_recipe(e: Resource, recipe: Dictionary) -> void:
    var raw: Dictionary = recipe.duplicate(true)
    F.move(raw, "label", e, "label", "string", true)
    F.move(raw, "disposition", e, "disposition", "string", true)
    F.move(raw, "ownerKind", e, "owner_kind", "string")
    F.move(raw, "reactionCastBinding", e, "reaction_cast", "string", true)
    F.move(raw, "surfaceOwner", e, "surface", "string")
    F.move(raw, "persistent/lifecycleSelections", e, "lifecycle_selections", "strings")
    F.move(raw, "persistent/actorHistory/captureDeparture", e, "capture_departure", "bool")
    F.move(raw, "persistent/creationIdentity/source_behavior_id", e, "creation_source_id", "string")
    F.move(raw, "persistent/creationIdentity/item_id", e, "creation_item_id", "string")
    F.move(raw, "persistent/nativeAim", e, "aim_policy", "string")
    F.move(raw, "composition/group", e, "group", "string", true)
    F.move(raw, "composition/exclusiveGroup", e, "exclusive_group", "string", true)
    F.move(raw, "composition/priority", e, "priority", "float", true)
    F.move(raw, "composition/maxLayers", e, "max_layers", "float")
    var look := Look.new()
    var adjust := LookStep.new();adjust.kind = "body_adjust"
    var moved := F.move(raw, "persistent/alphaMultiplier", adjust, "alpha", "float", true)
    moved = F.move(raw, "persistent/bodyColor/tintRgb", adjust, "rgb", "colour") or moved
    moved = F.move(raw, "persistent/bodyColor/saturation", adjust, "saturation", "float") or moved
    moved = F.move(raw, "persistent/bodyColor/brightness", adjust, "brightness", "float") or moved
    moved = F.move(raw, "persistent/bodyScale", adjust, "scale_by_size_change", "same") or moved
    if moved:look.steps.append(adjust)
    if F.value_at(raw, "persistent/bodyRamp") is Dictionary:
        var film := LookStep.new();film.kind = "body_film"
        F.move(raw, "persistent/bodyRamp/colors", film, "colours", "colours")
        F.move(raw, "persistent/bodyRamp/mapping", film, "mapping", "string")
        F.move(raw, "persistent/bodyRamp/texture", film, "texture", "string")
        F.move(raw, "persistent/bodyRamp/textureWeight", film, "weight", "float")
        F.move(raw, "persistent/bodyRamp/textureFrames", film, "texture_frames", "int")
        F.move(raw, "persistent/bodyRamp/textureFps", film, "texture_fps", "float")
        F.move(raw, "persistent/bodyRamp/gain", film, "gain", "float")
        F.move(raw, "persistent/bodyRamp/applicationMs", film, "fade_in", "ms")
        F.move(raw, "persistent/bodyRamp/removalMs", film, "fade_out", "ms")
        look.steps.append(film)
    if F.value_at(raw, "persistent/bodyOutline") is Dictionary:
        var outline := LookStep.new();outline.kind = "outline"
        F.move(raw, "persistent/bodyOutline/color", outline, "rgb", "colour")
        F.move(raw, "persistent/bodyOutline/pulseColor", outline, "pulse_colour", "colour")
        F.move(raw, "persistent/bodyOutline/opacity", outline, "alpha", "float")
        F.move(raw, "persistent/bodyOutline/onsetMs", outline, "fade_in", "ms")
        look.steps.append(outline)
    if F.value_at(raw, "persistent/frozenPose") is Dictionary:
        var frozen := LookStep.new();frozen.kind = "pose";frozen.pose_role = "frozen"
        F.move(raw, "persistent/frozenPose/captureCurrent", frozen, "capture_current", "bool")
        F.move(raw, "persistent/frozenPose/clip", frozen, "pose_clip", "string", true)
        F.move(raw, "persistent/frozenPose/frame", frozen, "pose_frame", "int", true)
        look.steps.append(frozen)
    if F.value_at(raw, "persistent/bodyPose") is String:
        var rest := LookStep.new();rest.kind = "pose";rest.pose_role = "rest"
        F.move(raw, "persistent/bodyPose", rest, "pose_clip", "string", true)
        look.steps.append(rest)
    if not look.steps.is_empty():e.look = look
    var poses: Variant = F.value_at(raw, "persistent/activityPoses")
    if poses is Array and poses.all(func(pose): return pose is Dictionary and pose.keys() == POSE_KEYS.map(func(pair): return pair[0])):
        for pose in poses:
            var row := {}
            for pair in POSE_KEYS:row[pair[1]] = pose[pair[0]]
            e.poses.append(F.plain(row))
        F.erase_path(raw, "persistent/activityPoses")
    raw = F.plain(raw)
    F.move(raw, "persistent/layers", e, "layers", "same", true)
    # The empty default is not emitted below: retain its original presence in
    # the record instead of moving it into a field that writes nothing back.
    F.move(raw, "persistent/appearanceLayers", e, "appearance_layers", "same")
    for phase in ["application", "removal"]:
        e.set(phase + "_text", feedback_from(raw, phase, CONDITION_TEXT))
        if F.value_at(raw, phase + "/bodyAnimation") is Dictionary:
            var body := BodyUse.new();body.role = "apply" if phase == "application" else "remove"
            F.move(raw, phase + "/bodyAnimation/bodyClip", body, "clip", "string", true)
            F.move(raw, phase + "/bodyAnimation/bodyPlaybackSpeed", body, "playback_speed", "float", true)
            F.move(raw, phase + "/bodyAnimation/reversed", body, "reversed", "bool")
            e.set(phase + "_body", body)
    e.unported = F.plain(raw)

static func condition_recipe(e: Resource) -> Dictionary:
    var record: Dictionary = e.unported.duplicate(true)
    F.emit(record, "label", e, "label", "string", true)
    F.emit(record, "disposition", e, "disposition", "string", true)
    if e.owner_kind!="condition":F.emit(record, "ownerKind", e, "owner_kind", "string")
    F.emit(record, "reactionCastBinding", e, "reaction_cast", "string")
    F.emit(record, "surfaceOwner", e, "surface", "string")
    F.emit(record, "persistent/lifecycleSelections", e, "lifecycle_selections", "strings")
    F.emit(record, "persistent/actorHistory/captureDeparture", e, "capture_departure", "bool")
    F.emit(record, "persistent/actorHistory/windowSeconds", e, "history_window_seconds", "float")
    F.emit(record, "persistent/creationIdentity/source_behavior_id", e, "creation_source_id", "string")
    F.emit(record, "persistent/creationIdentity/item_id", e, "creation_item_id", "string")
    F.emit(record, "persistent/nativeAim", e, "aim_policy", "string")
    # A metadata-only owner has no legacy composition policy. In particular,
    # an exported default maxLayers=0 would suppress its native lifecycle.
    var legacy_composition:bool=not e.disposition.is_empty()
    if not F.has_path(record, "composition/group"):F.emit(record, "composition/group", e, "group", "string", legacy_composition)
    if not F.has_path(record, "composition/exclusiveGroup"):F.emit(record, "composition/exclusiveGroup", e, "exclusive_group", "string", legacy_composition)
    F.emit(record, "composition/priority", e, "priority", "float", legacy_composition)
    # A newly authored condition may declare its visual disposition without
    # declaring a layer limit. Default zero would suppress its actual native
    # owners. Preserve an explicit old zero, and emit authored nondefault caps.
    F.emit(record, "composition/maxLayers", e, "max_layers", "float", F.has_path(record,"composition/maxLayers"))
    var adjust := step_of(e.look, "body_adjust")
    if adjust != null:
        F.emit(record, "persistent/alphaMultiplier", adjust, "alpha", "float", true)
        F.emit(record, "persistent/bodyColor/tintRgb", adjust, "rgb", "colour")
        F.emit(record, "persistent/bodyColor/saturation", adjust, "saturation", "float")
        F.emit(record, "persistent/bodyColor/brightness", adjust, "brightness", "float")
        F.emit(record, "persistent/bodyScale", adjust, "scale_by_size_change", "same")
    var film := step_of(e.look, "body_film")
    if film != null:
        if not F.has_path(record, "persistent/bodyRamp"):F.put(record, "persistent/bodyRamp", {})
        F.emit(record, "persistent/bodyRamp/colors", film, "colours", "colours")
        F.emit(record, "persistent/bodyRamp/mapping", film, "mapping", "string")
        F.emit(record, "persistent/bodyRamp/texture", film, "texture", "string")
        F.emit(record, "persistent/bodyRamp/textureWeight", film, "weight", "float")
        F.emit(record, "persistent/bodyRamp/textureFrames", film, "texture_frames", "int")
        F.emit(record, "persistent/bodyRamp/textureFps", film, "texture_fps", "float")
        F.emit(record, "persistent/bodyRamp/gain", film, "gain", "float")
        F.emit(record, "persistent/bodyRamp/applicationMs", film, "fade_in", "ms")
        F.emit(record, "persistent/bodyRamp/removalMs", film, "fade_out", "ms")
    var outline := step_of(e.look, "outline")
    if outline != null:
        if not F.has_path(record, "persistent/bodyOutline"):F.put(record, "persistent/bodyOutline", {})
        F.emit(record, "persistent/bodyOutline/color", outline, "rgb", "colour")
        F.emit(record, "persistent/bodyOutline/pulseColor", outline, "pulse_colour", "colour")
        F.emit(record, "persistent/bodyOutline/opacity", outline, "alpha", "float")
        F.emit(record, "persistent/bodyOutline/onsetMs", outline, "fade_in", "ms")
    var frozen := step_of(e.look, "pose", "frozen")
    if frozen != null:
        F.emit(record, "persistent/frozenPose/captureCurrent", frozen, "capture_current", "bool")
        F.emit(record, "persistent/frozenPose/clip", frozen, "pose_clip", "string", true)
        F.emit(record, "persistent/frozenPose/frame", frozen, "pose_frame", "int", true)
    var rest := step_of(e.look, "pose", "rest")
    if rest != null:F.emit(record, "persistent/bodyPose", rest, "pose_clip", "string", true)
    if not e.poses.is_empty():
        var poses: Array = []
        for pose in e.poses:
            var row := {}
            for pair in POSE_KEYS:row[pair[0]] = pose[pair[1]]
            poses.append(row)
        F.put(record, "persistent/activityPoses", poses)
    F.emit(record, "persistent/layers", e, "layers", "same", F.has_path(record, "persistent"))
    if not e.appearance_layers.is_empty():F.emit(record, "persistent/appearanceLayers", e, "appearance_layers", "same", true)
    if not e.effects.is_empty():
        var effects:Array=[]
        for index in e.effects.size():effects.append(cue_from_effect(e.effects[index],index))
        F.put(record,"persistent/nativeEffects",effects)
    if not e.responses.is_empty():
        var responses:Array=[]
        for index in e.responses.size():
            var cue:Dictionary=cue_from_effect(e.responses[index],index)
            cue.light_multiplier=e.responses[index].light_multiplier
            if not e.resource_path.is_empty():cue.source=e.resource_path+"::responses/"+str(index)
            responses.append(cue)
        record.nativeResponses=responses
    for phase in ["application", "removal"]:
        feedback_to(record, phase, e.get(phase + "_text"), CONDITION_TEXT)
        var body: BodyUse = e.get(phase + "_body")
        if body != null:
            F.emit(record, phase + "/bodyAnimation/bodyClip", body, "clip", "string", true)
            F.emit(record, phase + "/bodyAnimation/bodyPlaybackSpeed", body, "playback_speed", "float", true)
            F.emit(record, phase + "/bodyAnimation/reversed", body, "reversed", "bool")
    return record

# --- Actions (catalog/body_action_recipes.json, shove_recipes.json) ---------

const ACTION_TEXT := {"text": ["text", "string", true], "colour": ["color", "colour", true], "duration": ["durationMs", "ms", false]}

static func action_from_recipe(e: Resource, recipe: Dictionary) -> void:
    var raw: Dictionary = recipe.duplicate(true)
    F.move(raw, "disposition", e, "disposition", "string", true)
    e.body = body_from_actor(raw, "actor", "act")
    markers_from(raw, "anchors", e.body)
    if e.body != null:F.move(raw, "rigId", e.body, "rig", "string", true)
    e.feedback = feedback_from(raw, "actionFeedback", ACTION_TEXT)
    if raw.get("effectAudioCue") is String:
        var sound := SoundRef.new();sound.cue = raw.effectAudioCue;sound.at = "effect"
        e.sounds.append(sound);raw.erase("effectAudioCue")
    if raw.get("media") is Array and not raw.media.is_empty() and raw.media.all(func(row):return row is Dictionary):
        e.media.assign(raw.media);raw.erase("media")
    F.move(raw,"observedFact",e,"observed_fact","same")
    e.unported = F.plain(raw)

static func action_recipe(e: Resource) -> Dictionary:
    var record: Dictionary = e.unported.duplicate(true)
    F.emit(record, "disposition", e, "disposition", "string", true)
    if not e.media.is_empty():record.media=e.media.duplicate(true)
    if not e.observed_fact.is_empty():record.observedFact=e.observed_fact.duplicate(true)
    if (not e.media.is_empty() or not e.observed_fact.is_empty()) and not e.resource_path.is_empty():
        record._resource_source=e.resource_path
        record._source_fields=record.get("_source_fields",{}).duplicate()
        if not e.media.is_empty():record._source_fields.media=e.resource_path+"::media"
        if not e.observed_fact.is_empty():record._source_fields.observedFact=e.resource_path+"::observed_fact"
    body_to_actor(record, "actor", e.body)
    markers_to(record, "anchors", e.body)
    if e.body != null:
        F.emit(record, "rigId", e.body, "rig", "string")
        _body_sources(record,e.unported,e.resource_path,{
            "actor/enabled":"enabled","actor/clip":"clip","actor/playbackSpeed":"playback_speed",
            "actor/hiddenSlots":"hidden_slots","anchors":"markers"})
        if not e.body.rig.is_empty():_body_sources(record,{},e.resource_path,{"rigId":"rig"})
    feedback_to(record, "actionFeedback", e.feedback, ACTION_TEXT)
    if e.feedback != null:record.actionFeedback.enabled=e.feedback.enabled
    for outcome in e.reaction_feedback:
        if e.reaction_feedback[outcome]==null:continue
        feedback_to(record,"reactionFeedback/"+outcome,e.reaction_feedback[outcome],ACTION_TEXT)
        record.reactionFeedback[outcome].enabled=e.reaction_feedback[outcome].enabled
        if not e.resource_path.is_empty():
            record._resource_source=e.resource_path
            if not record.has("_source_fields"):record._source_fields={}
            record._source_fields["reactionFeedback/"+outcome]=e.resource_path+"::reaction_feedback/"+outcome
    for sound in e.sounds:
        if sound.at == "effect":record.effectAudioCue = sound.cue
    return record

# --- Attacks (catalog/attack_recipes.json) -----------------------------------

const OUTCOME_TEXT := {"text": ["text", "string", true], "colour": ["color", "colour", true], "duration": ["durationMs", "ms", false]}

## Fills `e`; returns {"trail": poses, "sockets": {variant id: sockets}} measured.
static func attack_from_recipe(e: Resource, recipe: Dictionary, AttackVariant: Script) -> Dictionary:
    var raw: Dictionary = recipe.duplicate(true)
    var measured := {"trail": null, "sockets": {}}
    e.body = body_from_actor(raw, "actor", "attack")
    markers_from(raw, "anchors", e.body)
    if raw.get("attackFeedback") is Dictionary:
        for outcome in raw.attackFeedback.keys():
            var text := feedback_from(raw, "attackFeedback/" + outcome, OUTCOME_TEXT)
            if text != null:e.outcome_texts[outcome] = text
    if raw.get("variants") is Array and not raw.variants.is_empty():
        for item in raw.variants:
            var variant_raw: Dictionary = item.duplicate(true)
            var variant = AttackVariant.new()
            F.move(variant_raw, "id", variant, "id", "string", true)
            F.move(variant_raw, "precedence", variant, "precedence", "float", true)
            F.move(variant_raw, "match", variant, "match", "same", true)
            variant.body = body_from_actor(variant_raw, "actor", "attack")
            markers_from(variant_raw, "anchors", variant.body)
            F.move(variant_raw, "attackVfx", variant, "slash", "same", true)
            if variant_raw.get("projectile") is Dictionary:
                F.move(variant_raw, "projectile/speedPxPerSecond", variant, "flight_tiles_per_second", "tiles", true)
                if F.has_path(variant_raw, "projectile/sourceSocketsByRig"):
                    measured.sockets[variant.id] = variant_raw.projectile.sourceSocketsByRig;variant_raw.projectile.erase("sourceSocketsByRig")
            variant.unported = F.plain(variant_raw)
            e.variants.append(variant)
        raw.erase("variants")
    if raw.get("weaponTrail") is Dictionary:
        measured.trail = raw.weaponTrail.get("poses");raw.weaponTrail.erase("poses")
        F.move(raw, "weaponTrail/palette", e, "trail_palette", "strings", true)
        F.move(raw, "weaponTrail/outcomes", e, "trail_outcomes", "strings", true)
        F.move(raw, "weaponTrail/behaviorIds", e, "trail_behaviours", "strings", true)
        e.trail_unported = F.plain(raw.weaponTrail);raw.erase("weaponTrail")
    e.unported = F.plain(raw)
    return measured

static func attack_recipe(e: Resource, trail: Variant, sockets: Dictionary) -> Dictionary:
    var record: Dictionary = e.unported.duplicate(true)
    body_to_actor(record, "actor", e.body)
    markers_to(record, "anchors", e.body)
    for outcome in e.outcome_texts:feedback_to(record, "attackFeedback/" + outcome, e.outcome_texts[outcome], OUTCOME_TEXT)
    if not e.variants.is_empty():
        var variants: Array = []
        for variant in e.variants:
            var row: Dictionary = variant.unported.duplicate(true)
            F.emit(row, "id", variant, "id", "string", true)
            F.emit(row, "precedence", variant, "precedence", "float", true)
            F.emit(row, "match", variant, "match", "same", true)
            body_to_actor(row, "actor", variant.body)
            markers_to(row, "anchors", variant.body)
            F.emit(row, "attackVfx", variant, "slash", "same", true)
            if row.get("projectile") is Dictionary:
                F.emit(row, "projectile/speedPxPerSecond", variant, "flight_tiles_per_second", "tiles", true)
                if sockets.has(variant.id):row.projectile.sourceSocketsByRig = F.deep(sockets[variant.id])
            variants.append(row)
        record.variants = variants
    if trail != null or not e.trail_unported.is_empty():
        var weapon_trail: Dictionary = e.trail_unported.duplicate(true)
        if trail != null:weapon_trail.poses = F.deep(trail)
        F.emit(weapon_trail, "palette", e, "trail_palette", "strings", true)
        F.emit(weapon_trail, "outcomes", e, "trail_outcomes", "strings", true)
        F.emit(weapon_trail, "behaviorIds", e, "trail_behaviours", "strings", true)
        if e.trail_source!=null:weapon_trail.source_id=e.trail_source.id
        if e.trail_impact_source!=null:weapon_trail.impact_source_id=e.trail_impact_source.id
        weapon_trail.contact_seconds=e.trail_contact_seconds
        weapon_trail.end_seconds=e.trail_end_seconds
        weapon_trail.source=e.resource_path
        record.weaponTrail = weapon_trail
    return record

# --- Contexts and shared tables ---------------------------------------------

## Body fields per context document: [old key, body property, kind].
const CONTEXT_BODY := {
    "damage": [["bodyClip", "clip", "string"], ["bodyPlaybackSpeed", "playback_speed", "float"]],
    "healing": [["bodyClip", "clip", "string"], ["bodyPlaybackSpeed", "playback_speed", "float"]],
    "death": [["bodyClip", "clip", "string"], ["bodyPlaybackSpeed", "playback_speed", "float"], ["hiddenSlots", "hidden_slots", "strings"]],
    "equipment": [["bodyEnabled", "enabled", "bool"], ["bodyClip", "clip", "string"], ["bodyPlaybackSpeed", "playback_speed", "float"]],
    "movement_reaction": [["bodyEnabled", "enabled", "bool"], ["bodyClip", "clip", "string"], ["bodyPlaybackSpeed", "playback_speed", "float"]],
    "movement": [["walkClip", "clip", "string"], ["walkPlaybackSpeed", "playback_speed", "float"]],
}
## Named texts per context document: name -> [path, {property: [key, kind, always]}].
const STATE_TEXT := {"enabled": ["enabled", "bool", true], "text": ["text", "string", true], "colour": ["color", "colour", true]}
const CONTEXT_TEXTS := {
    "healing": {"heal": ["", {"enabled": ["feedbackEnabled", "bool", true], "colour": ["feedbackColor", "colour", true], "text": ["feedbackLabel", "string", true], "duration": ["feedbackDurationMs", "ms", true]}]},
    "death_save": {"success": ["success", STATE_TEXT], "failure": ["failure", STATE_TEXT], "critical_success": ["criticalSuccess", STATE_TEXT], "critical_failure": ["criticalFailure", STATE_TEXT]},
    "life_state": {"dying": ["dying", STATE_TEXT], "stable": ["stable", STATE_TEXT], "revived": ["revived", STATE_TEXT]},
    "shove_feedback": {"resisted": ["resisted", STATE_TEXT], "blocked": ["succeeded_blocked", STATE_TEXT], "prone": ["succeeded_prone", STATE_TEXT], "push": ["succeeded_push", STATE_TEXT]},
    "forced_movement": {"forced": ["", {"enabled": ["feedbackEnabled", "bool", true], "colour": ["feedbackColor", "colour", true], "text": ["label", "string", true]}]},
    "movement_reaction": {"reaction": ["", {"enabled": ["feedbackEnabled", "bool", true], "colour": ["feedbackColor", "colour", true], "text": ["label", "string", true]}]},
}
## Seconds-valued fields per context: [old key, value name].
const CONTEXT_SECONDS := {
    "damage": [["impactDelayMs", "impact_delay"], ["flashDurationMs", "flash_duration"]],
    "number_style": [["durationMs", "duration"]], "badge_style": [["durationMs", "duration"]],
    "forced_movement_profile": [["duration_ms", "duration"]],
    "movement": [["walkStepDurationMs", "walk_step_duration"]],
}

static func context_from(e: Resource, id: String, document: Variant) -> void:
    if not document is Dictionary:e.unported = {"document": document};return
    var raw: Dictionary = document.duplicate(true)
    F.move(raw,"inactiveLegacyFields",e,"inactive_legacy_fields","strings",true)
    raw.erase("_resource_source") # Derived export provenance is not legacy authoring.
    if CONTEXT_BODY.has(id):
        var body := BodyUse.new();body.role = id
        for field in CONTEXT_BODY[id]:F.move(raw, field[0], body, field[1], field[2], true)
        e.body = body
    for name in CONTEXT_TEXTS.get(id, {}):
        var spec: Array = CONTEXT_TEXTS[id][name]
        var text: Feedback
        if spec[0].is_empty():
            text = Feedback.new()
            var moved := false
            for property in spec[1]:moved = F.move(raw, spec[1][property][0], text, property, spec[1][property][1], spec[1][property][2]) or moved
            if not moved:text = null
        else:text = feedback_from(raw, spec[0], spec[1])
        if text != null:e.texts[name] = text
    for field in CONTEXT_SECONDS.get(id, []):
        if raw.get(field[0]) is float:e.values[field[1]] = raw[field[0]] / 1000.0;raw.erase(field[0])
    e.unported = F.plain(raw)

static func context_document(e: Resource, id: String) -> Variant:
    if e.unported.has("document") and e.unported.size() == 1 and not e.unported.document is Dictionary:return F.deep(e.unported.document)
    var record: Dictionary = e.unported.duplicate(true)
    if not e.inactive_legacy_fields.is_empty():
        record.inactiveLegacyFields=Array(e.inactive_legacy_fields)
        if not e.resource_path.is_empty():record._resource_source=e.resource_path
    record.merge(e.release_sources.duplicate(true),true)
    if e.body != null:
        for field in CONTEXT_BODY.get(id, []):F.emit(record, field[0], e.body, field[1], field[2], true)
    for name in e.texts:
        var spec: Array = CONTEXT_TEXTS[id][name]
        if spec[0].is_empty():
            for property in spec[1]:F.emit(record, spec[1][property][0], e.texts[name], property, spec[1][property][1], spec[1][property][2])
        else:feedback_to(record, spec[0], e.texts[name], spec[1])
    for field in CONTEXT_SECONDS.get(id, []):
        if e.values.has(field[1]):record[field[0]] = F.to_legacy("ms", e.values[field[1]])
    for field in ["effects","impact_effects"]:
        var uses:Array=e.effects if field=="effects" else e.impact_effects
        if uses.is_empty():continue
        var key:String="nativeEffects" if field=="effects" else "nativeImpactEffects"
        record[key]=[]
        for ordinal in uses.size():
            var cue:Dictionary=cue_from_effect(uses[ordinal],ordinal)
            cue.source=e.resource_path+"::"+field+"/"+str(ordinal)
            if not uses[ordinal].recipient_slots.is_empty():
                cue.entity_geometry={"actor":"recipient","slots":Array(uses[ordinal].recipient_slots)}
            record[key].append(cue)
    return record

# --- Damage types (damage_context palette, hit responses) -------------------

static func damage_type_from(e: Resource, palette: Variant, response: String) -> void:
    if palette is Dictionary:
        var raw: Dictionary = palette.duplicate(true)
        e.palette = Palette.new();e.palette.id = "damage." + e.id.to_lower()
        for role in ["primary", "secondary", "tertiary"]:F.move_item(raw, "elementColors/" + role, e.palette, "roles", role, "colour")
        if raw.get("elementColors") is Dictionary and raw.elementColors.is_empty():raw.erase("elementColors")
        F.move(raw, "impactColor", e, "impact_colour", "hex", true)
        e.unported = F.plain(raw)
    e.hit_response = response

static func damage_type_palette(e: Resource) -> Dictionary:
    var record: Dictionary = e.unported.duplicate(true)
    if e.palette != null:
        record.elementColors = {}
        for role in ["primary", "secondary", "tertiary"]:F.emit_item(record, "elementColors/" + role, e.palette, "roles", role, "colour")
    F.emit(record, "impactColor", e, "impact_colour", "hex")
    return record
