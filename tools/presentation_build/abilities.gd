extends RefCounted
## Builds the abilities runtime files from authoring/abilities.tres (spells,
## conditions, actions, attacks, damage types, contexts, native sources):
##   build/presentation/abilities/docs/<old document>.res  the record tables the
##       game reads, in the shape of the old authoring documents (catalog/*,
##       spells/<id>, native_effects/*, sandbox/feedback), so readers keep
##       their code and every pixel stays; condition_lifecycles (the conditions
##       whose package lifecycle the client turns off) and values;
##   build/presentation/abilities/native_spells/  the native spell records
##       (staging, treated recipe, hit material, requirements) and their index;
##   build/presentation/abilities/icons.json  icon per spell, condition and action;
##   coverage of every spell, condition, action and damage type id.
const Common = preload("res://tools/presentation_build/common.gd")
const F = preload("res://tools/presentation_build/ability_fields.gd")
const R = preload("res://tools/presentation_build/ability_records.gd")
const Effects = preload("res://presentation/effect_package.gd")
const Feedback = preload("res://presentation/spell_feedback.gd")
const Requirements = preload("res://presentation/requirements.gd")
const Document = preload("res://presentation/resources/ability_document.gd")
const NativeSpell = preload("res://presentation/resources/native_spell.gd")
const NativeIndex = preload("res://presentation/resources/native_presentation_catalog.gd")
const PACKAGE := "res://assets/vfx/index.json"
const CUES := "res://authoring/audio/cues.json"
const BINDINGS := "res://authoring/audio/bindings.json"
const ORDER := "res://tools/presentation_build/ability_record_order.json"
const Catalog = preload("res://source_catalog.gd")

## Context entry id -> the old document it is.
const CONTEXT_DOCUMENTS := {
    "damage": "catalog/damage_context.json", "healing": "catalog/healing_context.json", "death": "catalog/death_context.json",
    "death_save": "catalog/death_save_context.json", "life_state": "catalog/life_state_context.json",
    "number_style": "catalog/number_style.json", "badge_style": "catalog/badge_style.json", "bolt_style": "catalog/bolt_style.json",
    "dart_style": "catalog/dart_style.json", "movement": "catalog/movement_context.json",
    "movement_reaction": "catalog/movement_reaction_context.json", "forced_movement": "catalog/forced_movement_context.json",
    "forced_movement_profile": "catalog/forced_movement_profile.json", "equipment": "catalog/equipment_context.json",
    "interruptions": "catalog/interruptions.json", "body_release_media": "catalog/body_release_media.json",
    "entity_lifecycle_media": "catalog/entity_lifecycle_media.json", "item_attachments": "catalog/item_attachments.json",
    "shove_feedback": "catalog/shove_feedback.json", "relocation": "catalog/relocation_actions.json",
    "body_materials": "catalog/body_materials.json", "action_materials": "catalog/action_materials.json",
    "action_intakes": "catalog/action_intakes.json", "condition_media": "catalog/condition_media.json",
    "hit_flash": "sandbox/feedback.json", "hit_responses": "native_effects/responses.json",
}
const ACTION_KINDS := ["action", "trait", "reaction", "class_feature", "feat"]

static func build(source: Dictionary, out_dir: String, report: Dictionary) -> void:
    var entries: Dictionary = source.entries
    _validate(entries, report)
    var built: Dictionary = documents(entries, source.root.sections)
    for owner in built.native.get("condition_conflicts",{}):
        Common.warn(report,"abilities/conditions/"+str(owner),"spell finish ownership is unresolved: "+JSON.stringify(built.native.condition_conflicts[owner]))
    DirAccess.make_dir_recursive_absolute(out_dir)
    for path in built.docs:save_document(out_dir, path, built.docs[path], report)
    _save_native(out_dir, built.native, report)
    var icons := FileAccess.open(out_dir.path_join("icons.json"), FileAccess.WRITE)
    icons.store_string(JSON.stringify({"domain": "abilities", "root": "res://assets/", "icons": built.icons}, "  "))
    icons.close()
    _coverage(entries, report)

## The runtime document file for an old document path (catalog/x.json -> docs/catalog/x.res).
static func document_file(out_dir: String, path: String) -> String:
    return out_dir.path_join("docs").path_join(path.get_basename() + ".res")

static func save_document(out_dir: String, path: String, data: Variant, report: Dictionary) -> void:
    var document := Document.new()
    if data is Array:document.items = data;document.is_list = true
    else:document.data = data
    var file := document_file(out_dir, path)
    DirAccess.make_dir_recursive_absolute(file.get_base_dir())
    var error := ResourceSaver.save(document, file, ResourceSaver.FLAG_COMPRESS)
    if error != OK:Common.error(report, "abilities", "cannot save " + file + ": " + str(error))

static func _order() -> Dictionary:
    if not FileAccess.file_exists(ORDER):return {}
    return JSON.parse_string(FileAccess.get_file_as_string(ORDER))

## A document laid out like the old one: spell recipes share one generic
## order, each table its own; exceptions per path.
static func _ordered(order: Dictionary, document: String, value: Variant) -> Variant:
    var spell := document.begins_with("spells/")
    var layout := {"generic": order.get("spells" if spell else document, {}).get("generic", {}),
        "exact": order.get(document, {}).get("exact", {})}
    return F.plain(F.ordered(layout, value, "", not spell))

## A measured file (path relative to res://assets/), parsed.
static func measured(path: String) -> Variant:
    if path.is_empty():return null
    var file := "res://assets/".path_join(path)
    if not FileAccess.file_exists(file):return null
    return JSON.parse_string(FileAccess.get_file_as_string(file))

static func short(spell_id: String) -> String:
    return spell_id.trim_prefix("spell.")

static func _sorted(map: Dictionary) -> Array:
    var keys: Array = map.keys()
    keys.sort()
    return keys

## Every runtime document: {docs: {old path: data}, native: {id: NativeSpell},
## native_conditions: {condition id: spell id}, icons: {id: row}}.
static func documents(entries: Dictionary, paths: Dictionary = {}) -> Dictionary:
    var order := _order()
    var docs := {}
    var spells: Dictionary = entries.get("spells", {})
    var conditions: Dictionary = entries.get("conditions", {})
    var actions: Dictionary = entries.get("actions", {})
    var attacks: Dictionary = entries.get("attacks", {})
    var contexts: Dictionary = entries.get("contexts", {})
    # Spells: one old recipe per spell that has a body recipe, plus the old
    # child drafts its variants carry.
    for id in _sorted(spells):
        var e: Resource = spells[id]
        if e.body != null or not e.unported.is_empty():docs["spells/" + id + ".json"] = _ordered(order, "spells/" + id + ".json", raw_recipe(e))
        for variant in e.variants:
            if not variant.recipe.is_empty():docs["spells/" + variant.id + ".json"] = _ordered(order, "spells/" + variant.id + ".json", variant.recipe)
    # Conditions.
    var recipes := {}
    var rates := {}
    var suppressed: Array = []
    for id in _sorted(conditions):
        var e: Resource = conditions[id]
        if not e.disposition.is_empty() or not e.creation_source_id.is_empty() or not e.effects.is_empty() or not e.responses.is_empty() or not e.lifecycle_opt_in.is_empty() or not e.lifecycle_selections.is_empty() or not e.surface.is_empty():
            var record:Dictionary=R.condition_recipe(e)
            if not e.effects.is_empty() or not e.responses.is_empty() or not e.lifecycle_opt_in.is_empty() or not e.lifecycle_selections.is_empty() or not e.surface.is_empty():record._resource_source=paths.get("conditions",{}).get(id,"")
            if not e.lifecycle_opt_in.is_empty():
                F.put(record,"persistent/lifecycleOptIns",_condition_lifecycle_opt_ins(e))
                F.put(record,"persistent/lifecycleOptInSource",e.lifecycle_opt_in)
                F.put(record,"persistent/lifecycleGeometry",e.lifecycle_geometry)
            recipes[id] = provenance(record, paths.get("conditions", {}).get(id, ""))
        if e.playback_rate != 0.0:rates[id] = e.playback_rate
        if not e.play_package_lifecycle:suppressed.append(id)
    docs["catalog/condition_recipes.json"] = _ordered(order, "catalog/condition_recipes.json", recipes)
    docs["catalog/action_playback_rates.json"] = F.plain(rates)
    docs["condition_lifecycles.json"] = {"suppressed": suppressed}
    # Actions and attacks.
    var bodies := {}
    var shoves := {}
    var bindings := {}
    var deliveries := {}
    for id in _sorted(actions):
        var e: Resource = actions[id]
        if not e.disposition.is_empty():
            if e.shove:shoves[id] = provenance(R.action_recipe(e), paths.get("actions", {}).get(id, ""))
            else:bodies[id] = provenance(R.action_recipe(e), paths.get("actions", {}).get(id, ""))
        if not e.plays.is_empty():
            var binding := {"source_recipe": e.plays, "action_feedback": null}
            if e.feedback != null and e.disposition.is_empty():
                var feedback:Dictionary={}
                R.feedback_to(feedback,"value",e.feedback,R.ACTION_TEXT)
                binding.action_feedback=feedback.value
                binding.action_feedback.enabled=e.feedback.enabled
                binding.action_feedback_source=str(paths.get("actions",{}).get(id,""))+"::feedback"
            if not e.target.is_empty():binding.interaction_target = e.target
            bindings[id] = binding
        if not e.effects.is_empty():
            var binding: Dictionary = bindings.get(id, {})
            binding.effect_cues = []
            binding.source = str(paths.get("actions", {}).get(id, "")) + "::effects"
            for i in e.effects.size():binding.effect_cues.append(action_cue(e.effects[i], i))
            bindings[id] = binding
        if not e.applies_conditions.is_empty():
            var binding: Dictionary = bindings.get(id, {})
            binding.applies_conditions = Array(e.applies_conditions)
            bindings[id] = binding
        if not e.body_fact_kind.is_empty():
            var binding:Dictionary=bindings.get(id,{})
            binding.body_fact_kind=e.body_fact_kind
            binding.body_fact_kind_source=str(paths.get("actions",{}).get(id,""))+"::body_fact_kind"
            bindings[id]=binding
        if not e.delivers_spell.is_empty():deliveries[id] = e.delivers_spell
    docs["catalog/body_action_recipes.json"] = _ordered(order, "catalog/body_action_recipes.json", bodies)
    docs["catalog/shove_recipes.json"] = _ordered(order, "catalog/shove_recipes.json", shoves)
    docs["catalog/body_action_bindings.json"] = F.plain(bindings)
    docs["catalog/action_deliveries.json"] = F.plain(deliveries)
    var attack_recipes := {}
    for id in _sorted(attacks):
        var e: Resource = attacks[id]
        var trail: Variant = measured(e.trail_points)
        var sockets: Variant = measured(e.variant_sockets)
        # The same measured bank is shared by several attack owners. Emit each
        # exact pose once, and admit it only after the actual equipped layer
        # selects that rig/category/clip. The recipe table carries no pose bank.
        var measured_poses:bool=trail is Dictionary and trail.has("poses")
        var record:Dictionary=R.attack_recipe(e,[] if measured_poses else null,sockets if sockets is Dictionary else {})
        if measured_poses:
            record.weaponTrail.erase("poses")
            var documents:Dictionary={}
            for pose in trail.poses:
                var key:String=str(pose.rigId)+"/"+str(pose.category)+"/"+str(pose.clip)
                if documents.has(key):continue # The original selector takes the first exact pose.
                var path:String="weapon_trails/"+e.trail_points.get_basename()+"/"+key+".json"
                documents[key]=path
                if not docs.has(path):docs[path]=F.plain(pose)
            record.weaponTrail.poseDocuments=documents
        attack_recipes[id]=record
    docs["catalog/attack_recipes.json"] = _ordered(order, "catalog/attack_recipes.json", attack_recipes)
    # Contexts, damage types and native sources.
    for id in contexts:
        if CONTEXT_DOCUMENTS.has(id):docs[CONTEXT_DOCUMENTS[id]] = R.context_document(contexts[id], id)
    var damage_types: Dictionary = entries.get("damage_types", {})
    if docs.get("catalog/damage_context.json") is Dictionary and docs["catalog/damage_context.json"].get("palette") is Dictionary:
        var by_type := {}
        for id in damage_types:
            var e: Resource = damage_types[id]
            if e.palette != null or not e.unported.is_empty():by_type[id] = R.damage_type_palette(e)
        docs["catalog/damage_context.json"].palette.byDamageType = by_type
    if docs.get("native_effects/responses.json") is Dictionary:
        var by_type := {}
        for id in damage_types:
            if not damage_types[id].hit_response.is_empty():by_type[id] = damage_types[id].hit_response
        docs["native_effects/responses.json"].damage_types = by_type
    for id in contexts:
        if CONTEXT_DOCUMENTS.has(id):docs[CONTEXT_DOCUMENTS[id]] = _ordered(order, CONTEXT_DOCUMENTS[id], docs[CONTEXT_DOCUMENTS[id]])
    var sources := {}
    for id in _sorted(entries.get("sources", {})):sources[id] = F.plain(F.deep(entries.sources[id].record))
    var native := native_records(spells, docs.get("sandbox/feedback.json", {}), conditions)
    var owners := {}
    for id in _sorted(native.records):
        var selection: Dictionary = native.records[id].selection
        if not selection.lifecycle.is_empty():owners[id] = {"id": selection.id, "lifecycle": F.deep(selection.lifecycle)}
    docs["native_effects/index.json"] = F.plain({"sources": sources, "spells": owners,
        "weapon_result_owners":weapon_result_owners(native.records,docs.get("catalog/body_action_bindings.json",{})),
        "observed_fact_owners":observed_fact_owners(actions)})
    var movement: Resource = contexts.get("movement")
    docs["values.json"] = {"movement_reference_speed_feet": float(movement.values.get("reference_speed_feet", 30.0)) if movement != null else 30.0}
    return {"docs": docs, "native": native, "icons": icons(entries)}

## Use the same EffectUse conversion as spells. These additional typed fields
## belong to the individual action cue rather than a spell's staging record.
static func action_cue(use: Resource, index: int) -> Dictionary:
    var cue: Dictionary = R.cue_from_effect(use, index)
    for field in [["selection", "selection", "string"], ["approach", "approach", "string"],
        ["source_start", "source_start", "float"], ["offset", "offset", "vec3"],
        ["follow_attachment", "follow", "bool"], ["light_color", "light_colour", "colour_html"]]:
        F.emit(cue, field[0], use, field[1], field[2])
    cue.light_multiplier = use.light_multiplier
    return cue

## Derive candidate owners from the authored damage-source predicates once at
## build time. Runtime visits only the matching lazy spell/action records;
## adding a contact does not require another spell-name list in the compiler.
static func weapon_result_owners(spells:Dictionary,actions:Dictionary)->Dictionary:
    var result:Dictionary={}
    for kind in ["spell","action"]:
        var entries:Dictionary=spells if kind=="spell" else actions
        for id in _sorted(entries):
            var cues:Array=entries[id].selection.get("staging",{}).get("cues",[]) if kind=="spell" \
                else entries[id].get("effect_cues",[])
            for cue in cues:
                var descriptor:Dictionary=cue.get("constructor_input",{})
                if descriptor.get("projection")!="weapon_component":continue
                for source in descriptor.get("damage_source_ids",[]):
                    if not result.has(source):result[source]=[]
                    var owner:Dictionary={"kind":kind,"id":str(id)}
                    if owner not in result[source]:result[source].append(owner)
    return result


## A derived index in the existing native-source table, not a second catalog.
static func observed_fact_owners(actions:Dictionary)->Dictionary:
    var result:Dictionary={}
    for id in _sorted(actions):
        var selector:Dictionary=actions[id].observed_fact
        if selector.is_empty():continue
        var kind:String=str(selector.kind)
        if not result.has(kind):result[kind]=[]
        result[kind].append(str(id))
    return result

static func _check_action_media(entry:Resource,sources:Dictionary,schema:Dictionary,where:String,report:Dictionary)->void:
    for media in entry.media:
        var source_id:String=str(media.get("source_id",""))
        if not sources.has(source_id):Common.error(report,where,"authored media names no native source: "+source_id);continue
        var record:Dictionary=sources[source_id].record
        if media.get("assetId") not in record.get("media_ids",[]):Common.error(report,where,"native media must retain an actual registered capture alias")
        if float(media.get("durationMs",0.0))<=0.0:Common.error(report,where,"native action media needs its finite authored duration")
        if media.has("poseSocket") and str(media.poseSocket).is_empty():Common.error(report,where,"an authored pose socket cannot be empty")
        var mapping:Array=media.get("timeMap",[])
        if not mapping.is_empty():
            var hz:float=float(record.get("sample_hz",0.0))
            if mapping.size()!=2 or hz<=0.0:
                Common.error(report,where,"native media window needs two actual source frames and a source FPS");continue
            if float(mapping[0].get("elapsedMs",-1.0))!=0.0 or float(mapping[1].get("elapsedMs",0.0))!=float(media.durationMs):Common.error(report,where,"source window must cover the exact finite component interval")
            for endpoint in mapping:
                if float(endpoint.get("sourceFrame",-1.0))<0.0 or float(endpoint.get("sourceFrame",INF))>=float(record.duration)*hz:
                    Common.error(report,where,"source window endpoint exceeds the source's actual frame lattice")
    var selector:Dictionary=entry.observed_fact
    if selector.is_empty():return
    var definitions:Dictionary=schema.get("$defs",{})
    # Only PlayerNode.fact declares public facts. Log payload definitions can
    # reuse a kind string without being that fact or exposing its witnesses.
    var fact_unions:Array=definitions.get("PlayerNode",{}).get("properties",{}).get("fact",{}).get("anyOf",[]).filter(func(value):
        return value.get("discriminator",{}).get("propertyName")=="kind")
    if fact_unions.size()!=1:Common.error(report,where,"observed fact needs one exact public kind/stage contract");return
    var contract:Variant=fact_unions[0].discriminator.mapping.get(str(selector.get("kind","")))
    if contract is Dictionary:
        if contract.get("discriminator",{}).get("propertyName")!="stage":
            Common.error(report,where,"observed fact needs one exact public kind/stage contract");return
        contract=contract.discriminator.mapping.get(str(selector.get("stage","")))
    var properties:Dictionary=definitions.get(str(contract).get_file(),{}).get("properties",{}) if contract is String else {}
    if properties.is_empty() or properties.get("kind",{}).get("const")!=selector.get("kind") \
        or (selector.has("stage") and properties.get("stage",{}).get("const")!=selector.stage):
        Common.error(report,where,"observed fact needs one exact public kind/stage contract");return
    if properties.get(str(selector.get("actor_field","")),{}).get("format")!="uuid":Common.error(report,where,"observed fact actor must name its actual nonnull public UUID field")
    var witness:Dictionary=properties.get(str(selector.get("witness","")),{})
    var variants:Array=witness.get("anyOf",[]).filter(func(value):return value.has("$ref"))
    if variants.size()!=1:Common.error(report,where,"observed fact must name its actual nullable public witness");return
    var fields:Dictionary=definitions.get(str(variants[0]["$ref"]).get_file(),{}).get("properties",{})
    if selector.get("when",{}).is_empty():Common.error(report,where,"observed witness requires its explicit source admission predicate")
    for key in selector.get("when",{}):
        if not fields.has(key) or fields[key].get("type")!="boolean" or not selector.when[key] is bool:
            Common.error(report,where,"observed witness predicate must name an actual public boolean")
    if entry.media.is_empty():Common.error(report,where,"observed fact has no finite native media assignment")

## Old property paths of the retired .tres overlays -> the entry property
## that holds the value now (for the Studio inspector's source pointers).
const PROVENANCE := [["body_filter/opacity", "look/steps/0/alpha"], ["body_filter", "look"], ["body_outline", "look"],
    ["activity_poses", "poses"], ["application_feedback", "application_text"], ["removal_feedback", "removal_text"],
    ["effect_audio_cue", "sounds/0/cue"], ["effect_frame", "unported/anchors/1/frame"], ["playback_speed", "body/playback_speed"], ["clip", "body/clip"]]
const PROVENANCE_NAMES := {"rig_id": "rig", "color": "colour", "duration_ms": "duration"}

## A record whose fields an entry's typed properties hold points at that entry.
static func provenance(record: Dictionary, entry: String) -> Dictionary:
    if entry.is_empty() or not record.has("_resource_source"):return record
    record["_resource_source"] = entry
    var fields: Dictionary = record.get("_source_fields", {})
    for key in fields:
        if not str(fields[key]).begins_with("res://"):continue # Preserved raw document pointers keep their actual owner.
        var property: String = str(fields[key]).get_slice("::", 1)
        for pair in PROVENANCE:
            if property == pair[0] or property.begins_with(pair[0] + "/"):
                property = pair[1] + property.trim_prefix(pair[0]);break
        var parts := property.split("/")
        for i in parts.size():parts[i] = PROVENANCE_NAMES.get(parts[i], parts[i])
        fields[key] = entry + "::" + "/".join(parts)
    return record

## The old recipe of a spell, with its measured sockets.
static func raw_recipe(e: Resource) -> Dictionary:
    var sockets: Variant = measured(e.sockets)
    var recipe:Dictionary=R.spell_recipe(e, sockets if sockets is Dictionary else {})
    _damage_sources(recipe,e.resource_path+"::unported")
    # Only a nondefault typed property replaces the imported raw value.
    for pair in [["impactDelayMs","impact_delay"],["hitFlash/frame","flash_frame"],
        ["hitFlash/durationMs","flash_duration"],["hitFlash/palette","flash_look"],
        ["floatingNumber/frame","number_frame"],["floatingNumber/durationMs","number_duration"]]:
        if not e.resource_path.is_empty() and F.has_path(recipe,"damage/"+pair[0]) and not F.same(e.get(pair[1]),F.default_of(e,pair[1])):
            recipe._source_fields["damage/"+pair[0]]=e.resource_path+"::"+pair[1]
    return recipe

## A damage policy contains both preserved raw options and typed callback/
## duration fields. Keep their real editable owners in the existing metadata.
static func _damage_sources(recipe:Dictionary,source:String)->void:
    if source.begins_with("::") or not recipe.get("damage") is Dictionary:return
    var fields:Dictionary=recipe.get("_source_fields",{}).duplicate()
    for name in ["hitFlash","floatingNumber","death"]:
        var policy:Variant=recipe.damage.get(name)
        if not policy is Dictionary:continue
        var path:String="damage/"+name
        fields[path]=source+"/"+path
        for field in policy:fields[path+"/"+str(field)]=source+"/"+path+"/"+str(field)
    recipe._source_fields=fields

## The native flash treatment is a mixed hand/palette policy. Its overwritten
## fields cannot claim the original raw or typed field as their sole owner.
static func _treated_flash_sources(recipe:Dictionary)->void:
    for field in ["palette","envelope","durationMs","holdMs","blendMode"]:
        recipe.get("_source_fields",{}).erase("damage/hitFlash/"+field)

## Native spell records for the spells whose staged effects play in the game:
## the staging selection, the recipe with the native hand/flash treatment
## (`policy`: hand glow categories and flash envelope), the hit material and
## the requirements; plus which spell owns each condition's lifecycle staging.
static func native_records(spells: Dictionary, policy: Dictionary, conditions:Dictionary={}) -> Dictionary:
    var result := {"records": {}, "conditions": {}, "condition_conflicts":{}}
    for id in _sorted(spells):
        var e: Resource = spells[id]
        if not e.native_staging:continue
        var name := short(id)
        var bounds: Variant = measured(e.bounds)
        var spell := NativeSpell.new()
        spell.selection = F.plain(R.spell_selection(e, name, bounds if bounds is Dictionary else {}))
        if e.body != null or not e.unported.is_empty():
            var raw: Dictionary = F.plain(raw_recipe(e))
            var treatment: Dictionary = Feedback.prepare(raw, spell.selection.palette, spell.selection.staging, policy)
            spell.recipe = raw.duplicate(true)
            spell.recipe.cast = treatment.cast
            if spell.recipe.get("damage") != null and not treatment.flash.is_empty():
                spell.recipe.damage.hitFlash = treatment.flash
                _treated_flash_sources(spell.recipe)
        spell.requirement_source = "spells/" + id + ".json:"
        spell.requirements = Requirements.recipe(spell.recipe, spell.requirement_source, ["spell"], {})
        for variant in e.variants:
            var selected:Dictionary=F.plain(R.variant_selection(spell.selection,variant))
            var variant_recipe:Dictionary=spell.recipe
            if not variant.recipe.is_empty():
                variant_recipe=F.plain(variant.recipe)
                _damage_sources(variant_recipe,e.resource_path+"::variants/"+str(e.variants.find(variant))+"/recipe")
                var treatment:Dictionary=Feedback.prepare(variant_recipe,selected.palette,selected.staging,policy)
                variant_recipe=variant_recipe.duplicate()
                # Body/cast ownership is the original real cast, independent
                # of each recipient's eventual outcome.
                variant_recipe.cast=spell.recipe.get("cast",{})
                if variant_recipe.get("damage")!=null and not treatment.flash.is_empty():
                    variant_recipe.damage=variant_recipe.damage.duplicate()
                    variant_recipe.damage.hitFlash=treatment.flash
                    _treated_flash_sources(variant_recipe)
            var reason:String=variant.dispatch_gap
            if variant.when.is_empty() and reason.is_empty():reason="public_fact_predicate_not_authored"
            spell.variants.append({"id":variant.id,"kind":variant.kind,"value":variant.value,
                "when":F.plain(variant.when),"dispatch_gap":reason,"status":variant.status,
                "save_effect_id":variant.save_effect_id,
                "inherits_recipe":variant.recipe.is_empty(),
                "selection":selected,"recipe":variant_recipe,"requirement_source":spell.requirement_source,
                "requirements":spell.requirements if is_same(variant_recipe,spell.recipe) else Requirements.recipe(variant_recipe,spell.requirement_source,["spell"],{})})
        spell.hit = F.plain(R.spell_hit(e, name))
        result.records[id] = spell
    var ownership:Dictionary=condition_owners(spells,conditions,result.records)
    result.conditions=ownership.owners;result.condition_conflicts=ownership.conflicts
    return result

## Dictionary aliases are not preserved by Godot's Resource serializer. Store
## only recipient recipe differences; admission attaches the one base owner.
static func persisted_native_record(record:Resource)->Resource:
    var stored:Resource=NativeSpell.new()
    stored.selection=record.selection;stored.recipe=record.recipe;stored.hit=record.hit
    stored.requirement_source=record.requirement_source;stored.requirements=record.requirements
    for variant in record.variants:
        var value:Dictionary=variant.duplicate()
        if value.inherits_recipe:
            value.erase("recipe");value.erase("requirements")
        else:
            value.recipe=variant.recipe.duplicate()
            value.recipe.erase("cast")
        stored.variants.append(value)
    return stored

## A shared condition has no implicit first-spell palette/staged-cue owner.
## Explicit condition authoring wins; otherwise only a unique native binding
## can supply that finish. Package lifecycles still play without this optional
## spell treatment, so an ambiguity cannot borrow another spell's appearance.
static func condition_owners(spells:Dictionary,conditions:Dictionary,available:Dictionary)->Dictionary:
    var candidates:Dictionary={};var result:Dictionary={"owners":{},"conflicts":{}}
    for id in _sorted(spells):
        var entry:Resource=spells[id]
        if not available.has(id) or entry.owner_kind!="condition":continue
        for owner in entry.owner_ids:
            if not candidates.has(owner):candidates[owner]=[]
            if id not in candidates[owner]:candidates[owner].append(id)
    for owner in candidates:
        var entry:Resource=conditions.get(owner)
        if entry!=null and not entry.inherit_spell_finish:continue
        var explicit:String=entry.owner_spell if entry!=null else ""
        if not explicit.is_empty():
            if explicit in candidates[owner]:result.owners[owner]=explicit
            else:result.conflicts[owner]={"reason":"explicit_owner_not_available","explicit":explicit,"candidates":candidates[owner]}
        elif candidates[owner].size()==1:result.owners[owner]=candidates[owner][0]
        else:result.conflicts[owner]={"reason":"multiple_authored_spell_owners","candidates":candidates[owner]}
    return result

## Native spell records go to native_spells/<revision>/ with their index, and
## native_spells/current names that index (a Studio reload picks up a new
## build without reusing records cached from the previous one).
static func _save_native(out_dir: String, native: Dictionary, report: Dictionary) -> void:
    var root := out_dir.path_join("native_spells")
    var hashed := PackedStringArray()
    for id in _sorted(native.records):hashed.append(JSON.stringify([id, native.records[id].selection, native.records[id].recipe, native.records[id].hit, native.records[id].variants]))
    var revision := "".join(hashed).sha256_text().left(12) + "-" + str(int(Time.get_unix_time_from_system()))
    var directory := root.path_join(revision)
    if DirAccess.dir_exists_absolute(root):
        for old in DirAccess.get_directories_at(root):
            if old == revision:continue
            for file in DirAccess.get_files_at(root.path_join(old)):DirAccess.remove_absolute(root.path_join(old).path_join(file))
            DirAccess.remove_absolute(root.path_join(old))
    DirAccess.make_dir_recursive_absolute(directory)
    var index := NativeIndex.new()
    var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    for kind in schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping:index.fact_requirements[kind] = Requirements.fact(kind)
    for id in _sorted(native.records):
        var path := directory.path_join(short(id) + ".res")
        if ResourceSaver.save(persisted_native_record(native.records[id]), path, ResourceSaver.FLAG_COMPRESS) != OK:Common.error(report, "abilities", "cannot save " + path);continue
        index.spells[id] = path
    index.conditions = native.conditions
    index.revision = "abilities-" + revision
    var index_path := directory.path_join("index.res")
    if ResourceSaver.save(index, index_path, ResourceSaver.FLAG_COMPRESS) != OK:Common.error(report, "abilities", "cannot save native spell index");return
    var marker := FileAccess.open(root.path_join("current"), FileAccess.WRITE)
    marker.store_string(index_path);marker.close()

## Icon per spell, condition and action id (paths relative to res://assets/).
static func icons(entries: Dictionary) -> Dictionary:
    var result := {}
    for section in ["spells", "conditions", "actions"]:
        for id in _sorted(entries.get(section, {})):
            # Old condition recipes retain feature/spell keys. Those records
            # describe a lifecycle; they cannot replace its typed UI owner.
            var owner:String="spells" if str(id).begins_with("spell.") else "conditions" if str(id).begins_with("condition.") else "actions"
            if section!=owner and entries.get(owner,{}).has(id):continue
            var icon: Resource = entries[section][id].icon
            if icon == null or icon.path.is_empty():continue
            var row := {"path": icon.path, "status": icon.status}
            if icon.rect.size != Vector2i.ZERO:row.rect = [icon.rect.position.x, icon.rect.position.y, icon.rect.size.x, icon.rect.size.y]
            if icon.native_size != Vector2i.ZERO:row.native_size = [icon.native_size.x, icon.native_size.y]
            if not icon.reuses.is_empty():row.reuses = icon.reuses
            if not icon.source.is_empty():row.source = icon.source
            result[id] = row
    return result

static func _validate(entries: Dictionary, report: Dictionary) -> void:
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
    var producer_schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    var damage_types:Array=producer_schema["$defs"].DamageType["enum"]
    var clips := {}
    for clip in package.get("clips", []):clips[clip.clip_id] = clip
    var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CUES)).get("cues", {})
    var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
    for section in entries:
        for id in entries[section]:
            var e: Resource = entries[section][id]
            var where: String = "abilities/" + section + "/" + id
            if e.get("id") != null and e.id != id:Common.error(report, where, "entry id " + str(e.id) + " differs from its key")
            if e.get("icon") != null:Common.asset(report, where, e.icon.path)
            for field in ["sockets", "bounds", "trail_points", "variant_sockets"]:
                if e.get(field) is String:Common.asset(report, where, e.get(field))
            if e.get("sounds") is Array:
                for sound in e.sounds:
                    if not sound.cue.is_empty() and not cues.has(sound.cue):Common.error(report, where, "sound cue not in the audio library: " + sound.cue)
    for id in entries.get("spells", {}):
        var e: Resource = entries.spells[id]
        var where: String = "abilities/spells/" + id
        for use in e.effects:
            _check_constructor(use,where,clips,report)
            if use.source_phase!=null or clips.has(use.clip):continue
            if e.native_staging:Common.warn(report, where, "staged clip resolves by role or rename, not by id: " + use.clip)
            elif use.staging_from.begins_with("factory"):Common.error(report, where, "imported clip not in the package: " + use.clip)
        _check_variants(e,where,report,damage_types)
        for variant in e.variants:
            for use in variant.effects:
                _check_constructor(use,where,clips,report)
                if use.source_phase==null and not clips.has(use.clip):Common.error(report, where, "variant " + variant.id + " clip not in the package: " + use.clip)
        for sound in e.sounds:_check_binding(report, where, bindings.get("spells", {}).get(id), sound)
    for id in entries.get("attacks",{}):
        var e:Resource=entries.attacks[id]
        var where:String="abilities/attacks/"+id
        for variant in e.variants:
            var creatures:Variant=variant.match.get("creatureIds")
            if creatures!=null and (not creatures is Array or not creatures.all(func(identity):return Common.server_ids().get("ids",{}).get("creature",{}).has(identity))):
                Common.error(report,where,"attack variant needs exact declared source creatures")
            if variant.source_timing.is_empty():continue
            var timing:Dictionary=variant.source_timing
            var source_id:String=str(timing.get("clip",""))
            var contact:float=float(timing.get("contact_seconds",-1.0));var end:float=float(timing.get("end_seconds",0.0))
            var declared:Resource=entries.get("actions",{}).get(id)
            if variant.body==null or variant.body.enabled or not clips.has(source_id) \
                or not is_finite(contact) or not is_finite(end) or contact<0.0 or end<contact or end<=0.0 \
                or end>float(clips.get(source_id,{}).get("seconds",0.0)) or declared==null \
                or not declared.effects.any(func(use):return use.clip==source_id and use.constructor_input.get("projection")=="attack_attempt" \
                    and is_equal_approx(float(use.source_end),end) and use.at=="event.start"):
                Common.error(report,where,"source-owned attack timing needs a finite delivered event source and disabled sprite body")
        if e.trail_points.is_empty():continue
        if e.trail_source==null or not entries.get("sources",{}).has(e.trail_source.id) \
            or not e.trail_source.record.get("weapon_path",false):
            Common.error(report,where,"measured weapon trail requires an explicitly authored imported path source")
        if e.trail_impact_source!=null and not entries.get("sources",{}).has(e.trail_impact_source.id):
            Common.error(report,where,"weapon impact source is absent from the authored source table")
        if not is_finite(e.trail_contact_seconds) or not is_finite(e.trail_end_seconds) \
            or e.trail_contact_seconds<=0.0 or e.trail_end_seconds<e.trail_contact_seconds \
            or e.trail_source!=null and e.trail_end_seconds>float(e.trail_source.record.get("duration",0.0)):
            Common.error(report,where,"measured weapon trail needs a finite authored contact/end window inside its source")
    _check_appearance_definitions(entries.get("conditions",{}),report)
    _check_departure_definitions(entries.get("conditions",{}),clips,report)
    _check_lifecycle_selections(entries.get("conditions",{}),package,clips,report)
    for id in entries.get("conditions", {}):
        var e: Resource = entries.conditions[id]
        for use in e.effects+e.responses:
            _check_constructor(use,"abilities/conditions/"+id,clips,report)
            if not use.owner_projection.is_empty():
                var descriptor:Dictionary=use.owner_projection
                if not producer_schema["$defs"].ConditionState.properties.has(str(descriptor.get("parent_field",""))) \
                    or not entries.conditions.has(str(descriptor.get("parent_behavior_id",""))) \
                    or str(descriptor.get("child_input","")).is_empty() or use.at!="owner_start" \
                    or "owner_projection" not in clips.get(use.clip,{}).get("inputs",[]):
                    Common.error(report,"abilities/conditions/"+id,"child-owner source needs its exact public parent field, authored parent behavior and source projection channel")
            if use.source_phase==null and not clips.has(use.clip):Common.error(report,"abilities/conditions/"+id,"condition cue clip not in the package: "+use.clip)
        if not e.lifecycle_opt_in.is_empty():
            var opted:Array=_condition_lifecycle_opt_ins(e)
            if opted.is_empty():Common.error(report,"abilities/conditions/"+id,"public lifecycle opt-in has no matching playable source rows")
            for row in opted:
                if row.get("event_gate",{}).get("schema")!="vfxfactory.public_condition_readiness.v1" \
                    or row.get("when",{}).is_empty() or row.get("phases",{}).size()!=3:
                    Common.error(report,"abilities/conditions/"+id,"public lifecycle requires its paired readiness gate and three exact phases");continue
                for phase in ["application","sustain","removal"]:
                    var source:Dictionary=row.phases.get(phase,{})
                    var alternatives:Array=clips.get(str(source.get("clip_id","")),{}).get("approaches",[]).filter(func(approach):
                        return approach.get("path")==source.get("constructor") and approach.get("source_phase")==source.get("phase") \
                            and approach.get("condition_prepared",false))
                    if alternatives.size()!=1 or str(source.get("approach_id","")).is_empty() or float(source.get("source_seconds",0.0))<=0.0:
                        Common.error(report,"abilities/conditions/"+id,"public gate requires its exact mapped direct phase and source clock: "+phase)
            var region:Dictionary=e.lifecycle_geometry.get("region",{})
            if e.lifecycle_geometry.get("slots",[]).is_empty() or region.get("id")!="mouth":
                Common.error(report,"abilities/conditions/"+id,"public readiness requires an explicit scoped current mouth receiving source")
            elif region.get("status")=="missing":
                Common.warn(report,"abilities/conditions/"+id,"authentic_mouth_region_not_authored; public gate/source opt-in does not supply anatomical pixels")
            elif region.get("kind")=="authored_pixels":
                var issue:String=_authored_mouth_error(e.lifecycle_geometry,id)
                if not issue.is_empty():Common.error(report,"abilities/conditions/"+id,issue)
            elif region.get("socket")!="mouth" or not is_finite(float(region.get("radius_cells",0.0))) or float(region.get("radius_cells",0.0))<=0.0:
                Common.error(report,"abilities/conditions/"+id,"scoped optical region requires authored source placement")
        for response in e.responses:
            var descriptor:Dictionary=response.condition_response
            if descriptor.get("kind") not in ["attributed_damage","attributed_component","miss_damage","attributed_healing","temporary_hp_refresh","consumed_member"] or descriptor.get("participant") not in ["owner","recipient"]:
                Common.error(report,"abilities/conditions/"+id,"finite condition response needs an actual attributed result and participant")
            if response.role!="impact" or response.source_end<=0 or response.duration_policy!="authored":
                Common.error(report,"abilities/conditions/"+id,"finite condition response must use its bounded impact source clock")
        for phase in e.sounds:_check_binding(report, "abilities/conditions/" + id, bindings.get("conditions", {}).get(id, {}).get(phase), e.sounds[phase])
    for id in entries.get("actions", {}):
        var e: Resource = entries.actions[id]
        var where: String = "abilities/actions/" + id
        if e.body_fact_kind not in ["","spell"] or not e.body_fact_kind.is_empty() and (e.kind!="action" \
            or not Common.server_ids().get("ids",{}).get("action",{}).has(id) \
            or e.body==null or not e.body.enabled or e.body.clip.is_empty() or e.disposition!="authored"):
            Common.error(report,where,"body fact selector needs an actual catalog Action and explicit authored body for its public SpellFact")
        if e.body!=null and e.body.enabled and not e.body.clip.is_empty() and e.disposition.is_empty():
            Common.error(report,where,"selected enabled body requires an explicit disposition; otherwise its recipe is not emitted")
        for outcome in e.reaction_feedback:
            var feedback:Resource=e.reaction_feedback[outcome]
            if outcome not in ["succeeded","failed"] or feedback==null or feedback.enabled and feedback.text.is_empty():
                Common.error(report,where,"reaction feedback needs a disclosed succeeded/failed branch and authored text or explicit disabled feedback")
        if not e.plays.is_empty() and not entries.actions.has(e.plays):Common.error(report, where, "plays an action with no entry: " + e.plays)
        if not e.delivers_spell.is_empty() and not entries.get("spells", {}).has(e.delivers_spell):Common.error(report, where, "delivers a spell with no entry: " + e.delivers_spell)
        if not e.delivers_spell.is_empty() and e.effects.is_empty() and e.effect_sources.is_empty() and e.disposition!="state_only":
            Common.error(report,where,"related spell metadata needs actual action effects or an explicit state-only presentation owner")
        _check_action_media(e,entries.get("sources",{}),producer_schema,where,report)
        for source in e.effect_sources:
            if not entries.get("sources", {}).has(source):Common.error(report, where, "effect source has no entry: " + source)
        for use in e.effects:
            _check_constructor(use,where,clips,report)
            if not use.owner_projection.is_empty():
                var descriptor:Dictionary=use.owner_projection
                if not producer_schema["$defs"].ConditionState.properties.has(str(descriptor.get("parent_field",""))) \
                    or not entries.conditions.has(str(descriptor.get("parent_behavior_id",""))) \
                    or not entries.conditions.has(str(descriptor.get("child_behavior_id",""))) \
                    or str(descriptor.get("child_input","")).is_empty() \
                    or not [str(descriptor.get("parent_behavior_id","")),str(descriptor.get("child_behavior_id",""))].all(func(member):return member in e.applies_conditions) \
                    or "owner_projection" not in clips.get(use.clip,{}).get("inputs",[]):
                    Common.error(report,where,"action child-owner source needs exact authored parent/child memberships and their public parent field")
            if use.source_phase==null and not clips.has(use.clip):Common.error(report, where, "action cue clip not in the package: " + use.clip)
        for sound in e.sounds:
            if sound.at != "effect":_check_binding(report, where, bindings.get("actions", {}).get(id), sound)
    for id in entries.get("contexts",{}):
        var context:Resource=entries.contexts[id]
        _check_context_inactive_fields(context,"abilities/contexts/"+str(id),report)
        for use in context.impact_effects:
            var where:String="abilities/contexts/"+id+"/impact_effects"
            _check_constructor(use,where,clips,report)
            if id!="item_attachments" or use.item_effect_behavior_id.is_empty() or use.role!="impact" \
                or use.at!="body.impact" or use.attachment!="recipient_body" or use.follow:
                Common.error(report,where,"global item contact needs exact actual attack membership and a fixed recipient-body impact")
            if use.source_phase==null and not clips.has(use.clip):Common.error(report,where,"item contact source is not delivered: "+use.clip)
            if not use.constructor_input.is_empty() or use.delay<0.0 or use.source_rate<=0.0 or not is_zero_approx(use.source_start) or not use.lifecycle.is_empty():
                Common.error(report,where,"global item contact needs the ordinary finite weapon-impact source clock")
            if not use.item_effect_damage_type.is_empty() and use.item_effect_damage_type not in damage_types:
                Common.error(report,where,"unknown public item-effect damage type "+use.item_effect_damage_type)
        for use in context.effects:
            var where:String="abilities/contexts/"+id
            _check_constructor(use,where,clips,report)
            if id=="entity_lifecycle_media":
                if use.constructor_input.get("kind")!="actor_terminal" or use.role!="attached" or use.at!="event.commit" \
                    or use.attachment!="recipient_ground" or use.follow or use.delay!=0.0 \
                    or use.source_end<=0.0 or use.source_start!=0.0 or use.source_rate!=1.0 or use.duration_policy!="authored":
                    Common.error(report,where,"terminal accent requires its witnessed commit, fixed ground endpoint and original finite source clock")
                continue
            if id=="movement":
                var rule:Dictionary=use.movement
                if rule.get("trajectory") not in ["path","direct_arc"] or use.at not in ["movement.interval","movement.takeoff","movement.track","movement.landing"] \
                    or use.role!="attached" or use.attachment not in ["recipient_ground","recipient_body"] or use.source_end<=0.0 or use.duration_policy!="authored":
                    Common.error(report,where,"movement use needs an actual trajectory, authored motion phase and finite source clock")
                if use.at=="movement.interval" and (not is_finite(float(rule.get("interval_seconds",0.0))) or float(rule.get("interval_seconds",0.0))<=0.0):
                    Common.error(report,where,"movement interval must be a positive finite authored cadence")
                for field in ["when_conditions","unless_conditions"]:
                    for condition in rule.get(field,[]):
                        if not entries.get("conditions",{}).has(condition):Common.error(report,where,"movement predicate names no condition entry: "+str(condition))
                if use.source_phase==null and not clips.has(use.clip):Common.error(report,where,"movement source is absent from the delivered package: "+use.clip)
                continue
            if use.source_phase==null and not clips.has(use.clip):Common.error(report,where,"item attachment source is not delivered: "+use.clip)
            if not use.item_effect_damage_type.is_empty() and use.item_effect_damage_type not in damage_types:
                Common.error(report,where,"unknown public item-effect damage type "+use.item_effect_damage_type)
            if id!="item_attachments" or use.item_effect_behavior_id.is_empty() or use.role not in ["attached","sustain"] \
                or use.at!="owner_start" or use.attachment not in ["item","recipient_weapon"] or not use.follow or use.recipient_slots.is_empty() \
                or not is_zero_approx(use.source_start) or use.source_end>=0 or not is_equal_approx(use.source_rate,1.0):
                Common.error(report,where,"global item attachment needs exact effect membership and current optical item on its unwrapped owner clock")
            for slot in use.recipient_slots:
                if slot not in ["weapon","offhand"]:Common.error(report,where,"global item attachment requires its actual modular item receiver: "+str(slot))
            if "created_item_binding" in clips.get(use.clip,{}).get("inputs",[]):
                Common.error(report,where,"an actual item-body source cannot replace a held weapon decoration")
            var lifecycle:Dictionary=use.extra.get("item_lifecycle",{})
            if not lifecycle.is_empty():
                if lifecycle.size()!=3 or lifecycle.get("application")!=use.clip:Common.error(report,where,"item lifecycle must name its exact application, sustain and removal sources")
                for phase in ["application","sustain","removal"]:
                    var clip:Dictionary=clips.get(str(lifecycle.get(phase,"")),{})
                    if clip.is_empty() or not ["owner_state","weapon_binding","entity_geometry"].all(func(channel):return channel in clip.get("inputs",[])):
                        Common.error(report,where,"item lifecycle lacks its delivered exact-owner/measured-weapon source: "+phase)
    for id in entries.get("damage_types", {}):
        for sound in entries.damage_types[id].sounds:_check_binding(report, "abilities/damage_types/" + id, bindings.get("damage_types", {}).get(id), sound)
    _validate_rigs(entries, report)
    for id in entries.get("conditions", {}):_validate_condition(entries.conditions[id], "abilities/conditions/" + id, report)

## Deliberately small public selector language. These are actual SpellFact
## fields, not renderer guesses about saves, elements or passive riders.
## effect_id is an opaque disclosed option identity, never a parsed spell name.
const VARIANT_FIELDS={"attack_outcome":["Hit","Miss","Crit","Crit Miss"],"target_kind":["creature","object"],"save_succeeded":[true,false],"effect_id":[],
    "damage_types":[]}
static func _check_context_inactive_fields(context:Resource,where:String,report:Dictionary)->void:
    var seen:Dictionary={}
    for field in context.inactive_legacy_fields:
        if field not in ["silhouetteDust","movementLeadInMs"] or seen.has(field) or not context.unported.has(field):
            Common.error(report,where,"inactive legacy field must name one exact existing top-level unported field: "+field)
        seen[field]=true

static func _check_variants(e:Resource,where:String,report:Dictionary,damage_types:Array=[])->void:
    var active:Array=[];var identities:Dictionary={}
    for variant in e.variants:
        if identities.has(variant.id):Common.error(report,where,"duplicate variant id: "+variant.id)
        identities[variant.id]=true
        if variant.when.has("save_succeeded") and variant.save_effect_id.is_empty():
            Common.error(report,where,"variant "+variant.id+" needs the exact save_effect_id")
        for field in variant.when:
            if not VARIANT_FIELDS.has(field):
                Common.error(report,where,"variant "+variant.id+" uses unsupported public fact field: "+str(field));continue
            var values:Variant=variant.when[field]
            if not values is Array or values.is_empty():
                Common.error(report,where,"variant "+variant.id+" predicate needs a nonempty value array");continue
            for value in values:
                if field=="effect_id":
                    if not value is String or value.is_empty():Common.error(report,where,"variant "+variant.id+" needs an exact nonempty effect_id")
                elif field=="damage_types":
                    if value not in damage_types:Common.error(report,where,"variant "+variant.id+" needs a canonical declared damage type: "+str(value))
                elif value not in VARIANT_FIELDS[field]:Common.error(report,where,"variant "+variant.id+" has noncanonical "+field+" value: "+str(value))
        if variant.when.is_empty() or not variant.dispatch_gap.is_empty():continue
        if variant.override_owner_cues:
            var cue_count:int=variant.effects.size() if not variant.effects.is_empty() else e.effects.size()
            for cue_index in variant.owner_cues:
                if cue_index<0 or cue_index>=cue_count:Common.error(report,where,"variant "+variant.id+" owner cue outside its own cue list")
        if not variant.effects.is_empty() and ((not e.owner_cues.is_empty() and not variant.override_owner_cues) or not e.contact_cues.is_empty() or not e.excluded_cues.is_empty() or e.explicit_event_cues):
            Common.error(report,where,"variant "+variant.id+" cannot inherit base cue-index ownership over a replaced cue list")
        if variant.recipe.has("cast") and variant.recipe.cast!=raw_recipe(e).get("cast",{}):
            Common.error(report,where,"variant "+variant.id+" changes the shared caster body; outcome dispatch owns only recipient delivery")
        for prior in active:
            var disjoint:bool=false
            for field in variant.when:
                # Different saves are independent observations, so opposite
                # booleans alone cannot prove these predicates exclusive.
                if field=="save_succeeded" and prior.save_effect_id!=variant.save_effect_id:continue
                if prior.when.has(field) and not variant.when[field].any(func(value):return value in prior.when[field]):disjoint=true;break
            if not disjoint:Common.error(report,where,"overlapping variant predicates: "+prior.id+" / "+variant.id)
        active.append(variant)

static func _check_constructor(use:Resource,where:String,clips:Dictionary,report:Dictionary)->void:
    if use.preparation_inputs not in ["construction","phase"]:
        Common.error(report,where,"immutable preparation inputs must be construction or phase")
    if use.preparation_inputs=="phase" and use.source_phase==null:
        Common.error(report,where,"phase preparation requires an explicit standalone PhaseResource")
    if not use.axis_scale.is_finite() or minf(use.axis_scale.x,minf(use.axis_scale.y,use.axis_scale.z))<=0.0:
        Common.error(report,where,"source axis calibration requires three positive finite factors")
    if use.requires_spatial_anchor and (use.scope!="spatial" or use.at!="owner_start"):
        Common.error(report,where,"required spatial anchor belongs to an actual retained owner_start source")
    if use.source_phase!=null:
        var standalone:Dictionary=Effects.for_cue(R.cue_from_effect(use,-1))
        if standalone.is_empty():
            Common.error(report,where,"standalone source is not an exact delivered mapped PhaseResource with declared inputs");return
        if not use.source_phase.validate().is_empty():Common.error(report,where,"standalone phase does not validate")
        if not use.clip.is_empty() and use.clip!=standalone.id:Common.error(report,where,"standalone identity differs from actual PhaseResource.clip_id")
        if use.source_seekable and use.source_phase.options.get("seekable")==false:
            Common.error(report,where,"standalone source explicitly refuses seek qualification")
        for channel in use.source_inputs:
            if channel.is_empty() or str(use.source_inputs[channel]).is_empty():Common.error(report,where,"standalone source channel/setter must be explicit")
        # A standalone opt-in can deliberately retain an indexed clip ID.
        # Validate its explicit PhaseResource/constructor, not that ID's
        # older default indexed source.
        clips=clips.merged({standalone.id:standalone},true)
    # Actual member lifetime can supply a declared boolean setter; it cannot
    # stand in for a source's geometry/event packet. Offline only.
    var membership:String=str(use.extra.get("membership_input",""))
    if not membership.is_empty():
        if not where.begins_with("abilities/conditions/") or membership!="wet_presence" \
            or membership not in clips.get(use.clip,{}).get("inputs",[]) \
            or use.role!="attached" or use.at!="owner_start" or use.delay!=0.0:
            Common.error(report,where,"membership input needs a declared boolean setter and actual condition owner_start clock");return
    var binding:Dictionary=use.constructor_input
    if binding.has("recipient_condition"):
        var predicate:Dictionary=binding.recipient_condition
        if binding.get("projection")!="weapon_component" or str(predicate.get("condition_key","")).is_empty() \
            or typeof(predicate.get("present"))!=TYPE_BOOL:
            Common.error(report,where,"weapon result condition selection requires an exact public condition authoring key and membership predicate");return
    if not use.observed_result.is_empty():
        var outcome:Dictionary=use.observed_result
        var inputs:Array=clips.get(use.clip,{}).get("inputs",[])
        if not where.begins_with("abilities/spells/") or not binding.is_empty() or outcome.get("outcomes",[]).is_empty() \
            or not outcome.outcomes.all(func(kind):return kind in ["revival","heal"]) \
            or outcome.get("relocation") not in ["absent","committed"] \
            or use.role!="attached" or use.at!="cast" or use.delay!=0.0 \
            or use.attachment!="recipient_ground" or inputs!=["recipient_geometry"]:
            Common.error(report,where,"observed result requires actual revival/healing, explicit relocation admission and a recipient-geometry-only source at its result clock");return
    if use.replaces_cast_body and (binding.get("kind")!="observed_event" or binding.get("outcome")!="cast" \
        or use.scope!="cast" or use.at!="cast" or use.delay!=0.0):
        Common.error(report,where,"cast body replacement needs an actual cast-scoped observed result at its own occurrence");return
    for channel in use.input_arguments:
        var fields:Variant=use.input_arguments[channel]
        if channel not in clips.get(use.clip,{}).get("inputs",[]) or not fields is Array or fields.is_empty():
            Common.error(report,where,"source arguments require a declared input and nonempty ordered fields");continue
        for field in fields:
            if not field is String or field.is_empty():Common.error(report,where,"source argument fields must be explicit names")
    if not use.extra.get("input_policies",{}).is_empty() and binding.is_empty() and use.scope=="spatial":
        if use.extra.input_policies.has("live_particles"):_check_static_liquid_policy(use,clips,where,report)
        else:_check_unused_geometry_policy(use,clips,where,report)
        return
    var wall_review_policy:bool=binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="wall_assembly"
    if not use.extra.get("input_policies",{}).is_empty() and not wall_review_policy and binding.get("kind") not in ["propagation_links","area_links","spell_strike","observed_event","condition_application","quarry_owner"]:
        Common.error(report,where,"explicit input policy has no qualified source constructor");return
    if binding.is_empty():return
    var identity_projection:String=str(binding.get("projection",""))
    if identity_projection in ["prismatic_outcomes","quarry_application","immediate_blast","accepted_area_blast","portable_payload_blast","retired_payload_blast"] \
        or binding.get("kind") in ["payload_release","retained_payload"]:
        var declared:Dictionary=Common.server_ids().get("ids",{})
        var behavior:String=str(binding.get("source_behavior_id",binding.get("behavior_id","")))
        if behavior.is_empty() or not ["spell","action"].any(func(kind):return declared.get(kind,{}).has(behavior)):
            Common.error(report,where,"source admission needs an explicitly assigned current spell/action identity");return
        if identity_projection in ["immediate_blast","accepted_area_blast","portable_payload_blast","retired_payload_blast"] and str(binding.get("payload_kind","")).is_empty():
            Common.error(report,where,"blast source needs its assigned source payload kind");return
        if identity_projection=="accepted_area_blast" and str(binding.get("area_shape","")).is_empty():
            Common.error(report,where,"direct area blast needs its assigned public geometry shape");return
        if identity_projection=="portable_payload_blast" and (str(binding.get("explosion_behavior_id","")).is_empty() \
            or str(binding.get("area_shape","")).is_empty() or str(binding.get("area_propagation","")).is_empty()):
            Common.error(report,where,"portable blast needs its actual explosion behavior and public area discriminator");return
        if identity_projection=="retired_payload_blast" or binding.get("kind")=="retained_payload":
            if not declared.get("condition",{}).has(binding.get("lifetime_condition_id")) or not declared.get("item",{}).has(binding.get("item_id")):
                Common.error(report,where,"retained payload needs its assigned current item and lifetime condition");return
    if binding.has("quarry_kind"):
        var declared:Dictionary=Common.server_ids().get("ids",{}).get("condition",{})
        if not declared.has(binding.get("owner_condition_id")) or not declared.has(binding.get("recipient_condition_id")):
            Common.error(report,where,"quarry source needs its assigned current sustain and recipient conditions");return
    if binding.get("kind")=="observed_event":
        if binding.get("outcome") not in ["cast","attack","heal","damage","removal","revival","condition_application"] or use.scope not in ["source","recipient","cast"] or binding.get("geometry_actor") not in ["caster","target"]:
            Common.error(report,where,"observed event needs an outcome, declared event scope and actual geometry role");return
        var projection:String=str(binding.get("projection","event"))
        if projection not in ["event","owned_outcome","condition_outcome","owner_activity","spatial_contact","applied_contact","cast_completion","healing_return","owned_fire_contact","finite_contact","condition_set_outcome","condition_contact","immediate_blast","retired_payload_blast","breath_grant","breath_exhale","weapon_component","quarry_application","attack_attempt","owner_removal","effective_handler","accepted_area_blast","portable_payload_blast","prismatic_outcomes","spatial_fire_contact"] \
            or projection in ["applied_contact","cast_completion"] and use.scope!="cast" \
            or projection=="applied_contact" and (binding.outcome!="damage" or str(binding.get("damage_type","")).is_empty() or use.at!="cast" or use.delay!=0.0) \
            or projection=="cast_completion" and (binding.outcome!="cast" or binding.get("recipient_role")!="target") \
            or projection=="healing_return" and (binding.outcome!="heal" or binding.geometry_actor!="target" or use.at!="cast" or use.delay!=0.0):
            Common.error(report,where,"observed projection must match its actual result, source clock and recipient contract");return
        if projection=="spatial_fire_contact" and (binding.outcome!="damage" or binding.geometry_actor!="target" \
            or use.scope!="recipient" or use.role!="impact" or use.at!="contact" or use.delay!=0.0 \
            or use.condition_response.get("kind")!="attributed_damage" or use.condition_response.get("participant")!="recipient" \
            or use.condition_response.get("turn_event_type") not in ["turn_start","turn_end"] \
            or str(use.condition_response.get("save_effect_id","")).is_empty() \
            or use.condition_response.get("trigger")!=binding.get("trigger")):
            Common.error(report,where,"spatial fire response needs its exact retained source, native turn/save/result and finite recipient clock");return
        if projection=="condition_set_outcome":
            if str(binding.get("behavior_id","")).is_empty() or binding.get("outcome_branches",[]).is_empty() \
                or binding.outcome!="condition_application" or use.scope!="cast" or use.at!="cast" or use.delay!=0.0:
                Common.error(report,where,"condition outcome selection needs an actual behavior and authored result branches");return
            var declared_conditions:Dictionary=Common.server_ids().get("ids",{}).get("condition",{})
            var outcomes:Dictionary={}
            for branch in binding.outcome_branches:
                var outcome:String=str(branch.get("outcome",""))
                var conditions:Array=branch.get("condition_ids",[])
                if outcome.is_empty() or outcomes.has(outcome) or (branch.get("result_kind")!="death" and conditions.is_empty()):
                    Common.error(report,where,"condition outcome branches need unique source outcomes and actual death or condition operands");return
                outcomes[outcome]=true
                for condition in conditions:
                    if not declared_conditions.has(condition):
                        Common.error(report,where,"condition outcome names no server condition: "+str(condition))
        if projection=="effective_handler" and (str(binding.get("required_effective_handler","")).is_empty() \
            or use.scope!="recipient" or use.at!="event.start" or use.delay!=0.0 or binding.outcome not in ["heal","damage"]):
            Common.error(report,where,"finite passive needs an exact emitted handler, committed result and result-owned clock");return
        if projection=="prismatic_outcomes" and (binding.outcome!="cast" or use.scope!="cast" or use.at!="release" \
            or use.delay!=0.0 or float(binding.get("contact_seconds",-1.0))<0.0 \
            or float(binding.contact_seconds)!=use.result_contact_seconds \
            or str(binding.get("behavior_id","")).is_empty() or str(binding.get("save_effect_prefix","")).is_empty() \
            or int(binding.get("recipient_endpoint_start",-1))!=use.extra.get("live_endpoints",[]).size() \
            or str(binding.get("recipient_socket","")).is_empty()):
            Common.error(report,where,"Prismatic needs one actual cone, disclosed application colours and its authored result contact");return
        if projection in ["breath_grant","breath_exhale"] and (str(binding.get("behavior_id","")).is_empty() or str(binding.get("condition_id","")).is_empty() \
            or not str(binding.get("constructor_script","")).ends_with(".gd") or not FileAccess.file_exists(str(binding.get("constructor_script",""))) \
            or binding.get("element") not in ["acid","cold","fire","lightning","poison"] \
            or use.scope!="cast" or use.at not in ["cast","event.start"] or use.delay!=0.0 or use.role!="attached" \
            or binding.get("component_path")!=["effect"] or binding.get("input_field")!="" \
            or projection=="breath_grant" and binding.outcome!="condition_application" \
            or projection=="breath_exhale" and binding.outcome!="cast"):
            Common.error(report,where,"breath grant/exhale needs its exact elemental member, finite observed occurrence and unchanged source phase");return
        if projection=="weapon_component" and (binding.outcome!="damage" or use.scope!="cast" or use.at!="event.start" \
            or use.delay!=0.0 or use.role!="attached" or binding.get("input_field")!="" \
            or binding.get("damage_source_ids",[]).is_empty() or str(binding.get("damage_type","")).is_empty() and binding.get("damage_type_policy")!="actual_component"):
            Common.error(report,where,"weapon component requires actual attributed positive result, exact source IDs and event clock");return
        if projection=="quarry_application":
            var retained:bool=binding.get("owner_admission","created")=="retained"
            var fact_kind:String="action" if retained else "spell"
            if str(binding.get("quarry_kind","")).is_empty() or binding.outcome!="condition_application" \
                or binding.get("owner_admission","created") not in ["created","retained"] \
                or not Common.server_ids().get("ids",{}).get(fact_kind,{}).has(binding.get("behavior_id")) \
                or use.scope!="cast" or use.at!=("event.start" if retained else "cast") or use.delay!=0.0 \
                or use.role!="attached" or binding.get("component_path")!=["owned_quarry"] or binding.get("input_field")!="":
                Common.error(report,where,"quarry application needs its exact created or retained root and actual recipient admission");return
        if projection=="owner_removal" and (binding.outcome!="removal" or use.scope!="recipient" or use.at!="event.start" \
            or use.delay!=0.0 or use.role!="attached" or binding.get("input_field")!="" \
            or not Common.server_ids().get("ids",{}).get("action",{}).has(binding.get("behavior_id")) \
            or not Common.server_ids().get("ids",{}).get("condition",{}).has(binding.get("owner_condition_id")) \
            or binding.geometry_actor!="target"):
            Common.error(report,where,"owner removal needs an actual consumed caster member and exact committed recipient/removal role");return
        if projection=="attack_attempt" and (binding.outcome!="attack" or use.scope!="cast" or use.at!="event.start" \
            or use.delay!=0.0 or use.role!="attached" or binding.get("input_field")!="" \
            or not Common.server_ids().get("ids",{}).get("action",{}).has(binding.get("behavior_id")) \
            or binding.get("source_creature_ids",[]).is_empty() or binding.get("weapon_slots",[]).is_empty() \
            or binding.get("source_kinds",[]).is_empty() \
            or not binding.source_creature_ids.all(func(identity):return Common.server_ids().get("ids",{}).get("creature",{}).has(identity)) \
            or not binding.weapon_slots.all(func(slot):return slot in ["MELEE_MAIN","MELEE_OFF","RANGED_MAIN","RANGED_OFF"]) \
            or not binding.source_kinds.all(func(kind):return kind in ["equipped","natural","unarmed"])):
            Common.error(report,where,"attack attempt requires an exact actual attack/source/slot event contract");return
        if projection=="accepted_area_blast" and (binding.outcome!="cast" or use.scope!="cast" or use.at!="contact" \
            or use.delay!=0.0 or binding.get("component_path")!=["effect"] or binding.get("input_field")!="" \
            or use.extra.get("live_endpoints",[])!=[{"cue_point":"source"}]):
            Common.error(report,where,"accepted area blast needs its completed direct cast, real resolved cells and existing delivery contact");return
        if projection=="portable_payload_blast" and (binding.outcome!="cast" or use.scope!="cast" or use.at!="event.start" \
            or use.delay!=0.0 or binding.get("component_path")!=["effect"] or binding.get("input_field")!="" \
            or use.source_phase==null or use.source_inputs!={"observed_explosion":"set_observed_explosion","targets":"set_targets"} \
            or use.extra.get("live_endpoints",[])!=[{"cue_point":"source"}]):
            Common.error(report,where,"portable blast requires its delivered public occurrence source, actual explosion/ancestors and throw destination");return
        if projection=="immediate_blast" and (binding.outcome!="cast" or use.scope!="cast" or use.at!="cast" \
            or use.delay!=0.0 or binding.geometry_actor!="caster" or use.extra.get("live_endpoints",[])!=[{"cue_point":"source"}]):
            Common.error(report,where,"immediate blast needs its native resolved footprint and exact explosion source clock/origin");return
        if projection=="retired_payload_blast" and (binding.outcome!="cast" or use.scope!="cast" or use.at!="event.start" \
            or use.delay!=0.0 or binding.geometry_actor!="caster" or str(binding.get("item_id","")).is_empty() \
            or str(binding.get("save_effect_id","")).is_empty() \
            or use.extra.get("live_endpoints",[])!=[{"cue_point":"source"}]):
            Common.error(report,where,"retired payload blast needs exact lifetime/object retirement, resolved footprint and native explosion clock");return
        if projection=="finite_contact":
            var save_effect:Variant=binding.get("save_effect_id")
            var save_selector:bool=save_effect is String and not save_effect.is_empty()
            if binding.has("save_effect_id") and save_effect==null:
                var declared:Dictionary=Common.server_ids().get("ids",{})
                var accepted:String=str(binding.get("accepted_behavior_id",""))
                var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
                var abilities:Array=schema.get("$defs",{}).get("SavingThrowFact",{}).get("properties",{}).get("ability_name",{}).get("enum",[])
                save_selector=not accepted.is_empty() and ["spell","action"].any(func(kind):return declared.get(kind,{}).has(accepted)) \
                    and binding.get("save_ability") in abilities
            if binding.outcome!="damage" or binding.geometry_actor!="target" or str(binding.get("damage_type","")).is_empty() \
                or not save_selector or use.scope!="cast" or use.at not in ["cast","event.start"] or use.delay!=0.0:
                Common.error(report,where,"finite contact needs an exact native save/result family and its actual result clock");return
        if projection=="divine_outcome" and (binding.outcome!="condition_application" or use.scope!="cast" \
            or use.at!="cast" or use.delay!=0.0 or binding.geometry_actor!="target"):
            Common.error(report,where,"recipient outcome needs actual child memberships/life and zero-delay source clock");return
        if projection=="condition_contact" and (binding.outcome!="damage" or use.scope!="cast" or use.at!="cast" \
            or use.delay!=0.0 or str(binding.get("condition_id","")).is_empty() or str(binding.get("damage_type","")).is_empty()):
            Common.error(report,where,"condition contact needs its exact disclosed source owner and result family");return
        if projection=="owned_fire_contact" and (use.scope!="source" or use.at!="event.start" or use.delay!=0.0 \
            or binding.outcome!="damage" or binding.get("damage_type")!="Fire" or binding.geometry_actor!="target" \
            or str(binding.get("owner_condition_id","")).is_empty() or str(binding.get("save_effect_id","")).is_empty() \
            or binding.get("trigger")!="sphere_ram" or binding.get("input_field")!=""):
            Common.error(report,where,"owned fire contact needs an actual source member, exact save/result and zero-delay accepted-action clock");return
    elif binding.get("kind")=="payload_release":
        if use.scope!="cast" or use.role!="flight" or use.at!="release" or use.delay!=0.0 \
            or use.source_launch<0.0 or use.source_contact<=use.source_launch or use.charge_seconds<0.0 \
            or binding.get("input_field")!="" or binding.get("admission") not in ["declared_aim","placed_object"] \
            or str(binding.get("behavior_id","")).is_empty() or str(binding.get("payload_kind","")).is_empty() \
            or binding.get("admission")=="placed_object" and str(binding.get("item_id","")).is_empty() \
            or use.extra.get("live_endpoints",[])!=[{"actor":"caster","socket":"cast_hand"},{"cue_point":"target"},{"cue_point":"source"}]:
            Common.error(report,where,"payload release needs exact accepted cast/destination, authored release hand and source clock path");return
    elif binding.get("kind")=="condition_application":
        if use.scope!="cast" or use.at not in ["cast","release"] or use.delay!=0.0 \
            or binding.get("owner_actor")!="caster" or str(binding.get("condition_id","")).is_empty() or binding.get("input_field")!="":
            Common.error(report,where,"condition application needs a real actor-owned descendant member and cast scope");return
    elif binding.get("kind")=="observed_operation":
        if use.scope!="source" or binding.get("operation") not in ["accepted","scribe"] or binding.get("input_field")!="" \
            or use.at!="event.start" or use.delay!=0.0 or use.extra.get("live_endpoints",[])!=[{"actor":"caster","socket":"cast_hand"}]:
            Common.error(report,where,"accepted operation needs source scope, its actual completion clock and source-hand endpoint");return
    elif binding.get("kind")=="item_consumption":
        if use.scope!="source" or binding.get("input_field")!="" or use.at!="event.start" or use.delay!=0.0 \
            or use.attachment!="caster_ground" or use.extra.get("live_endpoints",[])!=[{"actor":"caster","socket":"hand"},{"actor":"caster","socket":"face"}]:
            Common.error(report,where,"item consumption needs the accepted source action and its actual hand/face endpoints");return
    elif binding.get("kind")=="reaction_observation":
        var incoming:bool=not use.incoming_track.is_empty()
        if use.scope!="source" or binding.get("trigger_kind")!="spell" or not binding.get("succeeded") is bool \
            or binding.get("input_field")!=("" if incoming else "observation"):
            Common.error(report,where,"reaction observation needs source scope, spell trigger, observed outcome and observation member");return
        if incoming and (use.source_phase==null or use.incoming_track!={"source_role":"cast_preparation","end_at":"body.release","capture_at":"reaction.contact","socket":"hand"} \
            or use.at!="body.release" or use.delay!=0.0 or use.role!="attached" or binding.get("component_path")!=["effect"] \
            or use.source_inputs!={"reaction_observation":"set_reaction_observation","interrupted_presentation":"set_interrupted_presentation","interrupted_path":"set_interrupted_path"}):
            Common.error(report,where,"incoming preparation requires the declared body role/source endpoint and exact actual-presentation Phase setters");return
    elif binding.get("kind")=="retained_payload":
        if str(binding.get("lifetime_condition_id","")).is_empty() or where!="abilities/conditions/"+str(binding.lifetime_condition_id) \
            or str(binding.get("source_behavior_id","")).is_empty() or str(binding.get("item_id","")).is_empty() \
            or use.scope!="source" or use.role!="attached" or use.at!="owner_start" or use.delay!=0.0 or binding.get("input_field")!="" \
            or str(binding.get("payload_kind","")).is_empty() or binding.get("component_path")!=["effect"] \
            or use.extra.get("live_endpoints",[])!=[{"cue_point":"source"}]:
            Common.error(report,where,"retained payload requires its exact lifetime owner, supplied immutable identity and current optical anchor");return
    elif binding.get("kind")=="quarry_owner":
        if str(binding.get("quarry_kind","")).is_empty() or str(binding.get("recipient_condition_id","")).is_empty() \
            or where!="abilities/conditions/"+str(binding.recipient_condition_id) \
            or use.scope!="source" or use.at!="owner_start" or use.role!="attached" or use.delay!=0.0 \
            or binding.get("component_path")!=["owned_quarry"] or binding.get("input_field")!="":
            Common.error(report,where,"quarry owner requires its actual original sustain/recipient pair and shared member clock");return
    elif binding.get("kind")=="spatial_owner":
        if use.scope!="spatial" or binding.get("input_field")!="":
            Common.error(report,where,"spatial owner requires spatial scope and whole component input");return
        if not use.area_mask and (use.source_phase==null or not ["surface_partition","zone_geometry","admitted_cells"].any(func(channel):return channel in clips[use.clip].get("inputs",[]))):
            Common.error(report,where,"source-owned footprint needs its actual declared partition, geometry or admitted-cell source interface");return
        if binding.get("cell_input") in ["owned_field","wall_geometry","partitioned_surface"]:
            if use.source_phase==null or use.role!="attached" or use.at!="owner_start" or use.orientation!="world" \
                or not Common.server_ids().get("ids",{}).get("spatial_effect",{}).has(binding.get("content_id")) \
                or not ["owner_state","targets"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"actual owner source requires its declared current content, exact live owner/target inputs and world frame");return
            if binding.get("cell_input")=="wall_geometry" and (binding.get("geometry_shapes",[]).is_empty() \
                or not ["zone_geometry","admitted_cells"].any(func(channel):return channel in clips[use.clip].get("inputs",[]))):
                Common.error(report,where,"actual wall requires resource-selected native geometry shapes and its live footprint source input");return
            if binding.get("cell_input")=="partitioned_surface" and (binding.get("component_path") not in [["effect"],["surface"]] \
                or int(binding.get("capacity",0))!=128 or not ResourceLoader.exists(str(binding.get("topology_script","")),"Script") \
                or "surface_partition" not in clips[use.clip].get("inputs",[]) or use.area_mask or use.scale!=1.0):
                Common.error(report,where,"connected surface needs the delivered topology helper,128-cell disjoint draw source and unscaled native footprint");return
        if binding.get("cell_input")=="zone_geometry" and (use.source_phase==null \
            or use.source_inputs!={"zone_geometry":"set_zone_geometry","owner_state":"set_owner_state","targets":"set_targets"} \
            or not use.requires_spatial_anchor or use.at!="owner_start" or use.orientation!="world" \
            or use.extra.get("cell_capacity")!=64 or use.extra.get("cell_span_capacity")!=[8,8] \
            or not is_equal_approx(use.scale,1.0/2.121320344) or use.axis_scale!=Vector3(1.0,sqrt(2.0/3.0),1.0)):
            Common.error(report,where,"observed zone requires its exact owner/geometry/anchor source and authored coordinate/capacity calibration");return
        if binding.get("cell_input")=="owned_cells" and (str(binding.get("cells_field","")).is_empty() \
            or str(binding.get("retirement_field","")).is_empty() or binding.cells_field==binding.retirement_field \
            or int(use.extra.get("cell_capacity",0))<=0):
            Common.error(report,where,"owned cells require explicit source constructor cells/retirement fields and a bounded cell capacity");return
        if binding.has("contact_behavior_id") and (binding.get("cell_input")!="wall_assembly" \
            or not Common.server_ids().get("ids",{}).get("spell",{}).has(binding.contact_behavior_id)):
            Common.error(report,where,"wall contact requires a declared current source spell and actual wall assembly");return
    elif binding.get("kind")=="actor_terminal":
        var creatures:Array=binding.get("creature_ids",[])
        if where!="abilities/contexts/entity_lifecycle_media" or use.scope!="event" or creatures.is_empty() \
            or creatures.any(func(id):return not id is String or id.is_empty()) \
            or binding.get("component_path")!=["summon_terminal"] or binding.get("input_field")!="" \
            or use.source_phase==null or use.source_inputs!={"terminal_departure":"set_terminal_departure","live_endpoints":"set_live_endpoints"} \
            or use.extra.get("live_endpoints")!=[{"cue_point":"target"}]:
            Common.error(report,where,"terminal source requires actual creature choices and the public terminal/ground callbacks without a birth/body dependency");return
    elif binding.get("kind")=="actor_birth":
        var creatures:Array=binding.get("creature_ids",[])
        if creatures.is_empty() and not str(binding.get("creature_id","")).is_empty():creatures=[str(binding.creature_id)]
        if use.scope!="cast" or use.at!="cast" or use.delay!=0.0 or use.attachment!="recipient_ground" \
            or creatures.is_empty() or creatures.any(func(id):return not id is String or id.is_empty()) \
            or binding.has("creature_ids") and binding.has("creature_id") or binding.get("input_field")!="" \
            or use.extra.get("live_endpoints",[])!=[{"actor":"target","socket":"ground"}]:
            Common.error(report,where,"actor birth needs explicit observed creature choices and its exact ground endpoint");return
    elif binding.get("kind")=="creation_admission":
        if use.scope!="recipient" or binding.get("admission") not in ["inventory","placed_object"] or binding.get("geometry_actor")!="caster" or str(binding.get("item_id","")).is_empty() or binding.get("input_field")!="":
            Common.error(report,where,"creation admission needs an exact ordinary item kind, admission source and caster geometry");return
    elif binding.get("kind")=="area_links":
        var clock:bool=use.at=="release" and use.delay==-0.28 or where.begins_with("abilities/actions/") and use.at=="event.start" and use.delay==0.0
        if use.scope!="cast" or use.role!="attached" or not clock \
            or binding.get("input_field")!="" or binding.get("area_shape") not in ["line","sphere"] \
            or binding.get("endpoint_count")!=2 or not binding.get("edges") is Array \
            or binding.edges.is_empty() or use.extra.get("live_endpoints",[]).size()!=2:
            Common.error(report,where,"electric area needs its declared geometry, exact authored edges and two optical endpoints");return
    elif binding.get("kind")=="propagation_links":
        if use.scope!="application" or use.role!="flight" or binding.get("input_field")!="" \
            or binding.get("source_launch")!=use.source_launch or float(binding.get("speed_tiles_per_second",0.0))<=0.0 \
            or float(binding.get("minimum_travel_seconds",0.0))!=0.045 \
            or binding.get("secondary_source_socket")!="body_center" \
            or use.extra.get("live_endpoints",[]).size()!=2:
            Common.error(report,where,"propagation links need application flight scope, native launch and positive optical travel");return
    elif binding.get("kind")=="spell_strike":
        var repeat:bool=binding.get("behavior_id")=="action.spell.vampiric_touch.strike"
        if use.scope!="recipient" or use.role!="impact" or binding.get("input_field")!="" \
            or binding.get("behavior_id") not in ["spell.vampiric_touch","action.spell.vampiric_touch.strike"] \
            or repeat and (binding.get("owner_condition_id")!="condition.spell.vampiric_touch" or use.at!="event.start" or use.delay!=0.0) \
            or not repeat and not str(binding.get("owner_condition_id","")).is_empty():
            Common.error(report,where,"spell strike needs recipient impact scope and its exact initial or condition-granted repeat contract");return
    elif binding.get("kind")=="application_result" and use.scope=="application":
        if str(binding.get("save_effect_id","")).is_empty() or str(binding.get("damage_type","")).is_empty():
            Common.error(report,where,"application result lacks save effect or damage type");return
    else:
        Common.error(report,where,"constructor input projection or scope is unsupported");return
    if binding.get("component_path",[]).is_empty():Common.error(report,where,"constructor input lacks component path");return
    # Match the runtime's explicit selection boundary. Delivered, unselected
    # studies are not constructors this production use has opted into.
    var candidates:Array=clips.get(use.clip,{}).get("approaches",[]).filter(func(approach):return approach.has("source_phase") \
        and (str(approach.id)==use.approach if not use.approach.is_empty() else not str(approach.get("runtime_selection","")).begins_with("Unselected alternative")))
    if candidates.is_empty():Common.error(report,where,"constructor input has no public source phase: "+use.clip);return
    for approach in candidates:
        var phase:Resource=load(approach.source_phase)
        var components:Array=phase.to_clip().components
        if binding.has("argument"):
            var argument:Variant=binding.argument
            var fields:Variant=phase.options.get("construction_operands",[])
            var contract:Variant=approach.get("construction_input_contract")
            if not argument is String or argument.is_empty() or argument in ["layer_mask","phase","operands","clip"] \
                or binding.get("component_path")!=[argument] or binding.get("input_field","")!="" \
                or components.size()!=1 or components[0].id!=argument \
                or not fields is Array or fields.is_empty() or not fields.all(func(field):return field is String and not field.is_empty()) \
                or not contract is String or contract.is_empty():
                Common.error(report,where,"named constructor argument requires one declared source component and its factual operand fields");return
        # A mapped public constructor can expose one virtual operand for
        # several actual source layers. It is not a Source.make child path.
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="partitioned_surface" and binding.component_path==["surface"]:
            _check_public_surface_constructor(use,approach,components,where,report)
            continue
        var input:Dictionary={}
        var component:Dictionary={}
        for id in binding.component_path:
            var selected:Array=components.filter(func(component):return component.id==id)
            if selected.size()!=1:Common.error(report,where,"constructor component path is unavailable: "+str(binding.component_path));return
            component=selected[0];input=component.input;components=input.get("components",[])
        if binding.get("kind") in ["application_result","reaction_observation"] and not binding.get("input_field","").is_empty() and not input.get(binding.get("input_field","")) is Dictionary:Common.error(report,where,"constructor input member is not a supplied dictionary: "+str(binding.get("input_field")))
        if binding.get("kind")=="observed_operation":
            if not input.get("state") is Dictionary or not input.has("operation_uuid") or "operation_state" not in clips[use.clip].get("inputs",[]) \
                or binding.operation=="scribe" and (not input.has("item_uuid") or not input.has("learned_spell_id")):
                Common.error(report,where,"accepted operation needs the public operation state and exact source item/book constructor members")
        if binding.get("kind")=="item_consumption":
            if input.get("mode")!="consume" or not input.get("item_uuids") is Array or not input.get("healing_admitted") is bool:
                Common.error(report,where,"item consumption needs the supplied one-item/healing constructor contract")
        if binding.get("kind")=="observed_event":
            var projection:String=str(binding.get("projection","event"))
            if projection in ["immediate_blast","accepted_area_blast","portable_payload_blast","retired_payload_blast"] \
                and input.get("kind")!=binding.get("payload_kind"):
                Common.error(report,where,"blast assignment must match the selected source's actual payload kind");return
            if projection=="portable_payload_blast" and not candidates.any(func(candidate):return \
                candidate.get("construction_input_contract",{}).get("kind")=="portable_observed_freezing"):
                Common.error(report,where,"portable blast requires the mapped public observed-explosion constructor contract");return
            if projection=="applied_contact" and (not input.get("state") is Dictionary or "native_state" not in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"applied contact needs its supplied state member and native_state setter")
            elif projection=="cast_completion" and (not input.get("owner") is Dictionary or not input.get("observation") is Dictionary or "observation" not in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"cast completion needs supplied owner/observation members and observation setter")
            elif projection=="healing_return":
                _check_healing_return_input_policies(use,component,where,report)
                if "healing_input" not in clips[use.clip].get("inputs",[]):Common.error(report,where,"healing return requires its actual healing_input setter")
            elif projection in ["owned_fire_contact","spatial_fire_contact"]:
                if component.get("script")!="res://assets/vfx/sources/40a136ae47ae570e43c9/fire_contact.gd" \
                    or not input.get("event") is Dictionary or not input.has("owner_uuid") or not input.has("source_uuid") \
                    or input.event.get("trigger")!=binding.trigger or "contact_event" not in clips[use.clip].get("inputs",[]):
                    Common.error(report,where,"owned fire contact requires the selected source's exact identity/event interface")
            elif projection=="retired_payload_blast":
                if component.get("script")!="res://assets/vfx/sources/d707add0ebd05c501c49/fire_explosion_readable.gd" \
                    or input.get("kind")!="delayed_fire" or not input.get("event") is Dictionary \
                    or not input.has("item_uuid") or not input.has("lifetime_uuid") or "blast_event" not in clips[use.clip].get("inputs",[]):
                    Common.error(report,where,"retired payload blast requires the exact item/lifetime/event source interface")
            elif projection=="spatial_contact" and binding.get("packet")=="element_contact":
                if component.get("script")!="res://assets/vfx/sources/4bbc6a884fea6c024ae6/element_contact.gd" \
                    or not Common.server_ids().get("ids",{}).get("spatial_effect",{}).has(binding.get("content_id")) \
                    or str(binding.get("save_effect_id","")).is_empty() \
                    or input.get("element")!=str(binding.get("damage_type","")).to_lower() \
                    or not Common.server_ids().get("ids",{}).get("damage_type",{}).has(binding.get("damage_type")) \
                    or use.scope!="source" or use.at!="cast" or use.delay!=0.0 \
                    or not ["damage_event","recipient_geometry","targets"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                    Common.error(report,where,"elemental receiver needs its declared spatial content, exact result/save and matching finite source interface");return
            elif projection=="finite_contact" and binding.get("packet")=="electric_network":
                if component.get("script")!="res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd" \
                    or binding.get("damage_type")!="Lightning" or binding.get("component_path")!=["network"] \
                    or use.extra.get("live_endpoints",[]).size()!=1 or use.extra.live_endpoints[0].get("actor")!="target" \
                    or use.extra.live_endpoints[0].get("socket")!="body_center":
                    Common.error(report,where,"electric contact needs its exact native save/result and one actual recipient body");return
                _check_input_policies(use,component,where,report)
            elif projection=="weapon_component":
                var smite:bool=component.get("script") in ["res://assets/vfx/sources/5667d04933db041e08fd/divine_smite.gd","res://assets/vfx/sources/36d8596898bdb446e1e9/branding_smite.gd","res://assets/vfx/sources/616d3afb7538708b0f1e/searing_smite.gd"]
                var favor:bool=component.get("script")=="res://assets/vfx/sources/9e80f76781257e6a4d5d/divine_favor.gd"
                var quarry:bool=component.get("script") in ["res://assets/vfx/sources/7ad647fcc09f7a163ed6/hex.gd","res://assets/vfx/sources/a79f812dc5413c9a1bcf/hunters_mark.gd"]
                var event:bool=binding.get("packet")=="event" and component.get("script")=="res://assets/vfx/sources/9741d79e4578df647fec/intervention.gd" \
                    and input.get("part") in ["strike","improved_smite"] and input.get("mode")=="instant" and input.get("outcome_kind")=="damage" \
                    and ["lease_input","event_input"].all(func(channel):return channel in clips[use.clip].get("inputs",[]))
                if not smite and not favor and not quarry and not event or smite and input.get("phase")!="impact" or (favor or quarry) and input.get("phase")!="hit":
                    Common.error(report,where,"attributed weapon component requires a qualified finite impact/hit source branch")
                var policies:Dictionary=use.extra.get("input_policies",{})
                if smite and policies!={"condition_input":{"mode":"not_applicable","reason":"selected_smite_impact_does_not_consume_condition"},"tick_input":{"mode":"not_applicable","reason":"selected_smite_impact_does_not_consume_tick"}}:
                    Common.error(report,where,"smite finite impact must expose unused condition/tick methods accurately")
            elif projection=="owner_removal":
                if input.get("mode")!="response" \
                    or not ["lease_input","event_input"].all(func(channel):return channel in clips[use.clip].get("inputs",[])) \
                    or use.extra.get("input_policies",{})!={"lease_input":{"mode":"not_applicable","reason":"selected_response_consumes_actual_removal_event_without_held_lease"}}:
                    Common.error(report,where,"owner removal needs the selected finite event-owned response and explicitly unused held-lease method")
            elif projection=="attack_attempt":
                if input.get("phase")!="strike" or not ["owner_state","targets"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                    Common.error(report,where,"attack attempt needs the selected autonomous strike source interface")
            elif projection=="quarry_application":
                if input.get("phase") not in ["windup","application"] or not input.get("owner") is Dictionary or not input.get("quarry_state") is Dictionary \
                    or not ["owner_input","quarry_input"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                    Common.error(report,where,"quarry application requires the exact selected owner/recipient source interface")
            elif projection=="condition_contact" and binding.get("packet_kind")=="condition_tick":
                if input.get("phase")!="tick" or not input.get("condition") is Dictionary or not input.get("tick") is Dictionary \
                    or binding.get("turn_event_type") not in ["turn_start","turn_end"] \
                    or not ["condition_input","tick_input"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                    Common.error(report,where,"condition tick needs actual member/result packets and an authored turn boundary")
                for channel in use.extra.get("input_policies",{}):
                    var policy:Dictionary=use.extra.input_policies[channel]
                    if channel not in clips[use.clip].get("inputs",[]) or channel in ["condition_input","tick_input","recipient_geometry","targets"] \
                        or policy.get("mode")!="not_applicable" or str(policy.get("reason","")).is_empty():
                        Common.error(report,where,"condition tick policy must name an unused declared source input and its phase reason")
            elif projection=="owner_activity":
                if input.get("phase") not in ["windup","activation"] or not input.get("owner") is Dictionary \
                    or "owner_input" not in clips[use.clip].get("inputs",[]):
                    Common.error(report,where,"owner activity needs the source's finite owner-only startup interface")
                for channel in use.extra.get("input_policies",{}):
                    var policy:Dictionary=use.extra.input_policies[channel]
                    if channel not in ["recipient_geometry","healing_input","strike_input","condition_input","tick_input"] \
                        or policy.get("mode")!="not_applicable" or str(policy.get("reason","")).is_empty():
                        Common.error(report,where,"owner startup may omit only source methods unused by its actual finite branch")
            elif not use.extra.get("input_policies",{}).is_empty():
                Common.error(report,where,"observed input policy has no exact source-branch proof")
        if binding.get("kind")=="actor_birth":
            if not input.get("initial_state") is Dictionary or not input.get("review_states") is Array \
                or not input.has("birth_event_uuid") or not input.has("owner_uuid") \
                or "owner_state" not in clips[use.clip].get("inputs",[]):
                Common.error(report,where,"actor birth requires the source's explicit owner/birth/state interface")
        if binding.get("kind")=="actor_terminal":
            if input.get("entry",{}).get("kind")!="terminal" or input.has("birth_event_uuid") \
                or not ["terminal_departure","live_endpoints"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"terminal assignment must use the delivered independent terminal entry, never the arrival composition")
        if binding.get("kind")=="condition_application":
            if component.get("script")!="res://assets/vfx/sources/9e80f76781257e6a4d5d/divine_favor.gd" \
                or input.get("phase") not in ["windup","application"] or not input.get("ownership") is Dictionary \
                or input.ownership.get("owner_kind")!="caster" \
                or use.extra.get("input_policies",{})!={"hit_input":{"mode":"not_applicable","reason":"selected_weapon_blessing_phase_does_not_consume_hit"}}:
                Common.error(report,where,"condition application input policy needs the exact non-hit weapon blessing source branch")
        if binding.get("kind")=="retained_payload":
            var required:Array=["payload_state","payload_anchor","targets"]
            if input.get("kind")!=binding.payload_kind or use.source_phase==null                 or not required.all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"retained payload needs the delivered actual-state/anchor/endpoint interface with no review owner")
        if binding.get("kind")=="quarry_owner":
            if input.get("phase")!="condition" or not input.get("owner") is Dictionary or not input.get("quarry_state") is Dictionary \
                or not ["owner_input","quarry_input"].all(func(channel):return channel in clips[use.clip].get("inputs",[])):
                Common.error(report,where,"quarry condition requires the selected actual owner/current-child source interface")
            if use.extra.get("input_policies",{}).keys().any(func(channel):return channel not in ["healing_input","strike_input","condition_input","tick_input","hit_input"]):
                Common.error(report,where,"quarry condition may omit only methods unused by its exact current-state source branch")
        if binding.get("projection") in ["breath_grant","breath_exhale"]:
            var breath_phase:String="grant" if binding.projection=="breath_grant" else "exhale"
            if component.get("script")!=binding.get("constructor_script") \
                or input.get("phase")!=breath_phase or input.get("element")!=binding.element \
                or "grant_state" not in clips[use.clip].get("inputs",[]):
                Common.error(report,where,"breath phase must consume the exact delivered grant state, selected element and original phase")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="wall_assembly":
            var wall_policies:Dictionary=use.extra.get("input_policies",{})
            if not wall_policies.is_empty():
                var expected_wall_policy:Dictionary={"review_contacts":{"mode":"not_applicable","reason":"selected_actual_wall_source_uses_observed_visual_state_contacts"},
                    "visual_occupants":{"mode":"not_applicable","reason":"selected_actual_wall_source_uses_observed_visual_state_occupants"}}
                if wall_policies!=expected_wall_policy or use.approach!="runtime-prepared-production-review-20261020" \
                    or component.get("script")!="res://assets/vfx/extensions/production-review-20261020/sources/0ccf258744a7a69592fc/thorns.gd" \
                    or not phase.options.get("owner_lifetime",false) or "visual_state" not in clips[use.clip].get("inputs",[]):
                    Common.error(report,where,"unused review inputs require the selected actual Thorns wall source; visual_state remains mandatory")
            var setter:String=str(clips[use.clip].get("input_setters",{}).get("visual_state",""))
            var declared_assembly:bool=binding.get("argument")==component.id \
                and phase.options.get("construction_operands",[])==["wall_uuid","anchor_position","wall_geometry"] \
                and phase.options.get("owner_lifetime",false)==true and not setter.is_empty() \
                and (setter in approach.get("public_setters",[]) or approach.get("public_callbacks",{}).get("visual_state")==setter)
            var legacy_assembly:bool=use.approach in ["runtime-prepared-production-review-20261020","runtime-prepared-wall-child-v3-20261021"]
            if binding.get("component_path")!=["wall"] or not (legacy_assembly or declared_assembly) \
                or "visual_state" not in clips[use.clip].get("inputs",[]) or use.orientation!="world" \
                or not is_equal_approx(use.scale,0.471404520693175) or use.extra.get("wall_forms",[]).is_empty():
                Common.error(report,where,"actual wall requires its exact opt-in geometry/state source, construction component and source-unit conversion")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="zone_geometry":
            if component.get("script")!="res://assets/vfx/extensions/wall-child-v3-20261021/sources/39a8f882a0878cd303e3/field.gd" \
                or not input.has("frigid_air_bank") or input.has("owner_uuid") or binding.get("component_path")!=["effect"] \
                or not Common.server_ids().get("ids",{}).get("spatial_effect",{}).has(binding.get("content_id")):
                Common.error(report,where,"observed zone must retain its delivered bank and require actual construction ownership without a fixture UUID")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="wall_segment":
            if not Common.server_ids().get("ids",{}).get("spatial_effect",{}).has(binding.get("content_id")) \
                or not input.has("owner_uuid") or not input.get("state") is Dictionary or not input.get("review_states") is Array \
                or not input.has("length_cells") or float(input.get("width_cells",0.0))*5.0!=float(binding.get("width_feet",0.0)) \
                or float(input.get("height_cells",0.0))*5.0!=float(binding.get("height_feet",0.0)) \
                or not ["owner_state","targets"].all(func(channel):return channel in clips[use.clip].get("inputs",[])) \
                or use.extra.get("live_endpoints",[])!=[{"area_point":"segment_start"},{"area_point":"segment_end"}] \
                or use.orientation!="world" or use.scale!=1.0:
                Common.error(report,where,"retained segment needs exact source owner, length, dimensions and disclosed segment endpoints")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="cells":
            if not input.get("cells") is Array or not input.get("observed_removals") is Array \
                or use.orientation!="world" or use.scale!=1.0:
                Common.error(report,where,"constructed spatial cells need supplied topology/removals and an unscaled world frame")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="owned_cells":
            if not input.get(str(binding.cells_field)) is Array \
                or typeof(input.get(str(binding.retirement_field))) not in [TYPE_FLOAT,TYPE_INT] \
                or not ["admitted_cells","retirement_time"].all(func(channel):return channel in clips[use.clip].get("inputs",[])) \
                or use.orientation!="world" or use.scale!=1.0:
                Common.error(report,where,"owned cells require the selected actual cell/retirement source interface in an unscaled world frame")
            var bank_path:String=str(input.get("prepared_surface_bank",""))
            if not bank_path.is_empty():
                var bank:Resource=load(bank_path)
                if bank==null or bank.static_settings.has(str(binding.cells_field)) or bank.static_settings.has(str(binding.retirement_field)):
                    Common.error(report,where,"prepared owner source must keep actual cells and retirement outside its immutable shape")
        if binding.get("kind")=="spatial_owner" and binding.get("cell_input")=="surface_state":
            if component.get("script")!="res://assets/vfx/sources/0f16646410ac17d1f620/observed_ice_contrast.gd" \
                or not Common.server_ids().get("ids",{}).get("spatial_effect",{}).has(binding.get("content_id")) \
                or not input.get("state") is Dictionary or str(binding.get("surface_kind","")).is_empty() \
                or binding.surface_kind!=input.state.get("surface_kind") \
                or not input.has("surface_uuid") or "surface_state" not in clips[use.clip].get("inputs",[]) \
                or use.extra.get("cell_capacity")!=128 or use.orientation!="world" or use.scale!=1.0:
                Common.error(report,where,"observed ice needs exact spatial UUID/state/128-cell source and an unscaled world frame")
        if binding.get("kind")=="area_links":
            if component.get("script")!="res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd" \
                or binding.edges!=input.get("edges") or binding.get("component_path")!=["network"] \
                or binding.get("area_shape")=="line" and use.extra.live_endpoints!=[{"actor":"caster","socket":"cast_hand"},{"area_point":"line_end"}] \
                or binding.get("area_shape")=="sphere" and use.extra.live_endpoints!=[{"area_point":"center","offset_cells":[0.0,7.5,0.0]},{"area_point":"center"}]:
                Common.error(report,where,"electric area must retain exact delivered optical edges and authored declaration endpoints");return
            _check_input_policies(use,component,where,report)
        if binding.get("kind")=="propagation_links":
            if input.get("edges",[]).size()!=1 or input.get("endpoint_count")!=2 \
                or float(input.edges[0].delay)!=float(binding.source_launch) or float(input.get("speed",0))!=float(binding.speed_tiles_per_second):
                Common.error(report,where,"single-link projection must match the delivered endpoint/ribbon/launch/speed contract")
            _check_input_policies(use,component,where,report)
        elif binding.get("kind")=="spell_strike":_check_vampiric_input_policies(use,component,where,report)

## An explicitly static source pose uses its own sealed field. Its optional
## live-event/electric channels are not evidence about a gameplay surface.
static func _check_static_liquid_policy(use:Resource,clips:Dictionary,where:String,report:Dictionary)->void:
    var expected:Dictionary={
        "transition_events":{"mode":"not_applicable","reason":"selected_static_liquid_pose_precedes_review_transitions"},
        "live_particles":{"mode":"not_applicable","reason":"selected_static_liquid_pose_uses_original_packaged_field"}}
    for channel in ["link_edges","targets","density_field"]:
        expected[channel]={"mode":"not_applicable","reason":"selected_static_liquid_pose_has_no_active_electric_network"}
    var clip:Dictionary=clips.get(use.clip,{})
    var channels:Array=clip.get("inputs",[])
    var choices:Array=clip.get("approaches",[]).filter(func(approach):return str(approach.id)==use.approach and approach.get("kind")=="native")
    if use.extra.input_policies!=expected or channels.size()!=expected.size() \
        or channels.any(func(channel):return not expected.has(channel)) or choices.size()!=1 \
        or use.role!="attached" or use.at!="owner_start" or use.attachment!="recipient_ground" \
        or not use.requires_spatial_anchor or use.orientation!="world" or use.scale!=1.0 \
        or use.source_start!=0.0 or use.source_rate!=1.0 or use.fade_out!=0.0:
        Common.error(report,where,"static liquid policy needs one prepared source at the actual anchor with no projected event or electric inputs");return
    var lifecycle:Dictionary=use.lifecycle
    var pose:float=float(lifecycle.get("hold_start_seconds",-1.0))
    if pose<=0.0 or float(lifecycle.get("enter_end_seconds",-1.0))!=pose \
        or float(lifecycle.get("exit_start_seconds",-1.0))!=pose or float(lifecycle.get("exit_end_seconds",-1.0))!=pose \
        or use.source_end!=pose:
        Common.error(report,where,"static liquid policy needs an explicit deployed pose and immediate actual teardown");return
    var phase:Resource=load(choices[0].source_phase)
    var components:Array=phase.to_clip().components
    var constructor:String="res://assets/vfx/extensions/late-20261020/sources/c952b48391f8cc44666f/live.gd"
    if components.size()!=1 or components[0].get("script")!=constructor:
        Common.error(report,where,"static liquid policy requires the delivered prepared adaptive liquid constructor");return
    var bank_path:String=str(components[0].get("input",{}).get("liquid_bank",""))
    var bank:Resource=load(bank_path) if not bank_path.is_empty() else null
    if bank==null or bank.layout.get("family")!="oil_liquid_reflection":
        Common.error(report,where,"static liquid policy has no original Oil field bank");return
    var settings:Dictionary=bank.settings
    if float(settings.get("freeze_at",0.0))<=pose or float(settings.get("remove_at",0.0))<=pose \
        or float(settings.get("thaw_at",0.0))<=pose \
        or settings.get("events",[]).any(func(event):return float(event.get("at",0.0))<=pose):
        Common.error(report,where,"static liquid pose reaches a review transition or retirement");return
    # The sealed leaf supplies its own original field when no optional live
    # packet is admitted. Its electric network stays hidden before any charge;
    # no recipient geometry or empty density packet substitutes for a source.
    var leaf:String=FileAccess.get_file_as_string(constructor)
    var source:String=FileAccess.get_file_as_string("res://assets/vfx/extensions/late-20261020/sources/161f0610c6995cab5fde/liquid.gd")
    if not leaf.begins_with('extends "res://assets/vfx/extensions/late-20261020/sources/161f0610c6995cab5fde/liquid.gd"') \
        or not source.contains('elif cursor != last_source_cursor:') or not source.contains('_set_fluid(_source_field(cursor))') \
        or not source.contains('var active := _charge_can_be_visible(seconds) and charge_age >= 0.0 and retirement > .01') \
        or not source.contains('if event.operation == "charge": return true'):
        Common.error(report,where,"prepared liquid optional-field or inactive-network source contract changed")

## The declared wrapper only forwards geometry when its actual child receives
## it. This exact source chain has no receiver; no actor or empty packet is
## manufactured merely to satisfy the indexed optional forwarding method.
static func _check_unused_geometry_policy(use:Resource,clips:Dictionary,where:String,report:Dictionary)->void:
    var expected:Dictionary={"recipient_geometry":{"mode":"not_applicable","reason":"selected_native_source_has_no_geometry_receiver"}}
    var clip:Dictionary=clips.get(use.clip,{})
    var choices:Array=clip.get("approaches",[]).filter(func(approach):return str(approach.id)==use.approach and approach.get("kind")=="native")
    if use.extra.get("input_policies",{})!=expected or clip.get("inputs",[])!=["recipient_geometry"] or choices.size()!=1:
        Common.error(report,where,"unused geometry policy needs one explicit native source and its only declared recipient geometry input");return
    var phase:Resource=load(choices[0].source_phase)
    var components:Array=phase.to_clip().components
    var nested:Array=components[0].get("input",{}).get("components",[]) if components.size()==1 else []
    var wrapper:String="res://assets/vfx/sources/3966d6cc724927baedcb/occurrence_opacity.gd"
    var leaf:String="res://assets/vfx/sources/b11ff4928ba15c1739d9/globe_readable_far_side.gd"
    if nested.size()!=1 or nested[0].get("script")!=wrapper or nested[0].input.get("constructor_script")!=leaf:
        Common.error(report,where,"unused geometry policy has no exact optional-forwarding source wrapper");return
    var forwarding:String=FileAccess.get_file_as_string(wrapper)
    if not forwarding.contains('if source_component.has_method("set_entity_geometry"):') \
        or not forwarding.contains("source_component.set_entity_geometry(geometry)"):
        Common.error(report,where,"optional geometry forwarding contract changed");return
    var chain:Array=[leaf,"res://assets/vfx/sources/c0fc8f9a283c64e75067/gold_globe.gd","res://assets/vfx/sources/a4fd0883f0b17d893a03/base.gd"]
    for index in chain.size():
        var source:String=FileAccess.get_file_as_string(chain[index])
        var parent:String='extends "'+str(chain[index+1])+'"' if index+1<chain.size() else "extends Node3D"
        if not source.begins_with(parent) or source.contains("func set_entity_geometry") or source.contains("func set_recipient_geometry"):
            Common.error(report,where,"selected native source now consumes geometry; review its explicit input policy")

## One explicit client choice, not an optional-input claim about the Factory.
## Its source condition is checked offline; no shader/source inspection in play.
static func _check_public_surface_constructor(use:Resource,approach:Dictionary,components:Array,where:String,report:Dictionary)->void:
    var source:String=FileAccess.get_file_as_string(str(approach.path))
    var parent:String=source.get_slice("\n",0).get_slice('"',1)
    var parent_source:String=FileAccess.get_file_as_string(parent) if parent.begins_with("res://assets/vfx/") else ""
    if use.preparation_inputs!="phase" or components.size()!=2 \
        or components[0].id!="ground" or components[1].id!="film" \
        or components[0].script!=components[1].script \
        or not components.all(func(part):return part.input.get("surface_bank") is String) \
        or approach.get("public_callbacks",{})!={"targets":"set_targets","owner_state":"set_owner_state","surface_partition":"set_surface_partition"} \
        or not source.begins_with('extends "') or not source.contains("parameters.phase =") \
        or not parent_source.contains('const FIELD := "'+str(components[0].script)+'"') \
        or not parent_source.contains('operand.get("component_path") != ["surface"]') \
        or not parent_source.contains('values.size() != 1') \
        or not parent_source.contains('for part: Dictionary in clip.components:\n\t\tpart.input.surface_uuid = values.surface_uuid'):
        Common.error(report,where,"virtual surface input requires its mapped public ground/film constructor and phase-owned immutable preparation")

static func _check_input_policies(use:Resource,component:Dictionary,where:String,report:Dictionary)->void:
    var expected:Dictionary={"density_field":{"mode":"not_applicable","reason":"selected_factory_density_mask_disabled"}}
    if use.clip not in ["live-electric/chain_live_single","live-electric/bolt_live_heavy","live-electric/call_live_strike"] or use.extra.get("input_policies",{})!=expected \
        or component.get("script")!="res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd" \
        or component.input.get("density_mask",false)!=false:
        Common.error(report,where,"density not_applicable requires the exact delivered unmasked electric source");return
    var parent_source:String=FileAccess.get_file_as_string("res://assets/vfx/sources/038f154b06649f707e70/live_network.gd")
    if not parent_source.contains('if settings.get("density_mask", false):'):
        Common.error(report,where,"qualified Factory density-mask default changed; review this explicit client input policy")

## Exact sealed impact branches consume initial strike or the completed grant
## witness. Neither consumes healing, recipient condition or delayed ticks.
static func _check_vampiric_input_policies(use:Resource,component:Dictionary,where:String,report:Dictionary)->void:
    var repeat:bool=use.constructor_input.get("behavior_id")=="action.spell.vampiric_touch.strike"
    var policies:Dictionary={}
    for name in (["healing_input","condition_input","tick_input"] if repeat else ["owner_input","healing_input","condition_input","tick_input"]):
        policies[name]={"mode":"not_applicable","reason":"accepted_repeat_impact_does_not_consume_healing_condition_tick_inputs" if repeat else "first_cast_impact_does_not_consume_owner_or_repeat_inputs"}
    if use.clip!="bg3-36/vampiric-touch/vampiric_touch_native/impact" \
        or use.constructor_input.component_path!=["owned_contact"] or use.extra.get("input_policies",{})!=policies \
        or component.get("script")!="res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd" \
        or component.input.get("phase")!="impact" or component.input.get("behavior_id")!="spell.vampiric_touch":
        Common.error(report,where,"strike input policy is restricted to the exact sealed Vampiric Touch impact source")


## The sealed healing branch admits the actual HealFact independently of the
## owner/strike/condition/tick review packets. This is build-time source proof.
static func _check_healing_return_input_policies(use:Resource,component:Dictionary,where:String,report:Dictionary)->void:
    var policies:Dictionary={}
    for name in ["owner_input","strike_input","condition_input","tick_input"]:
        policies[name]={"mode":"not_applicable","reason":"positive_healing_return_does_not_consume_owner_or_strike_inputs"}
    var input:Dictionary=component.get("input",{})
    if use.clip!="bg3-36/vampiric-touch/vampiric_touch_native/healing" \
        or use.constructor_input.component_path!=["owned_contact"] or use.extra.get("input_policies",{})!=policies \
        or component.get("script")!="res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd" \
        or input.get("phase")!="healing" or not input.get("healing") is Dictionary:
        Common.error(report,where,"healing return input policy is restricted to its exact native source/phase");return
    var source:String=FileAccess.get_file_as_string(str(component.script))
    if not source.contains('if phase == "healing":\n\t\tadmitted = healing_admitted()'):
        Common.error(report,where,"sealed healing-return admission branch changed; review explicit input policy")

static func _in(value: float, low: float, high: float) -> bool:
    return is_finite(value) and value >= low and value <= high

static func _colour(value: Color) -> bool:
    return _in(value.r, 0, 1) and _in(value.g, 0, 1) and _in(value.b, 0, 1)

## The ranges the old overlay enforced, now checked once at build time: body
## adjust (alpha 0-1, saturation and brightness 0-2), outline (alpha 0-1,
## onset up to 10 s, colours), feedback durations, pose speeds.
static func _check_appearance_definitions(conditions:Dictionary,report:Dictionary)->void:
    var definitions:Dictionary={}
    for condition_id in conditions:
        for layer in conditions[condition_id].appearance_layers:
            var where:String="abilities/conditions/"+str(condition_id)
            if str(layer.get("id","")).is_empty() or str(layer.get("slot","")).is_empty() or str(layer.get("category","")).is_empty():
                Common.error(report,where,"appearance layer needs id, slot and category");continue
            if definitions.has(layer.id) and definitions[layer.id]!=layer:
                Common.error(report,where,"appearance id has distinct definitions: "+str(layer.id))
            else:definitions[layer.id]=layer

static func _check_departure_definitions(conditions:Dictionary,clips:Dictionary,report:Dictionary)->void:
    var declarations:Array=JSON.parse_string(FileAccess.get_file_as_string(PACKAGE)).get("selections",[])
    for id in conditions:
        if not conditions[id].capture_departure:continue
        var where:String="abilities/conditions/"+str(id)
        var selected:Array=declarations.filter(func(selection):return id in selection.get("condition",{}).get("owner_ids",[]))
        if selected.is_empty():Common.error(report,where,"departure capture has no delivered condition lifecycle");continue
        for selection in selected:
            var registration:Dictionary=selection.condition.registration
            if registration.get("attachment")!="recipient_ground" or registration.get("anchor")!="ground":Common.error(report,where,"departure needs the actual delivered recipient-ground registration")
            for clip_id in selection.condition.phases.values():
                var approaches:Array=clips.get(clip_id,{}).get("approaches",[]).filter(func(value):return value.get("condition_prepared",false))
                if approaches.is_empty():Common.error(report,where,"departure lifecycle is not a prepared source: "+str(clip_id));continue
                var source:Node3D=load(approaches[0].path).make_component({})
                var history:Dictionary=source.parameters.get("actor_history",{})
                if not history.get("capture_departure",false) or history.get("mirror",false):Common.error(report,where,"departure capture must select a non-Mirror departure constructor: "+str(clip_id))
                source.free()

static func _validate_condition(e: Resource, where: String, report: Dictionary) -> void:
    if e.look != null:
        for step in e.look.steps:
            match step.kind:
                "body_adjust":
                    if not _in(step.alpha, 0, 1) or not _in(step.saturation, 0, 2) or not _in(step.brightness, 0, 2) or not _colour(step.rgb):Common.error(report, where, "body adjust out of range")
                    for change in step.scale_by_size_change:
                        var factor:float=step.scale_by_size_change[change]
                        if change not in ["enlarge","reduce"] or not is_finite(factor) or factor<=0:Common.error(report,where,"body scale needs a known public size_change and positive finite factor")
                "outline":
                    if not _in(step.alpha, 0, 1) or not _in(step.fade_in, 0, 10) or not _colour(step.rgb) or not _colour(step.pulse_colour):Common.error(report, where, "outline out of range")
                    var outline: Dictionary = e.unported.get("persistent", {}).get("bodyOutline", {})
                    if outline.has("pulseOpacity") and not _in(float(outline.pulseOpacity), 0, 1):Common.error(report, where, "outline pulse opacity out of range")
                    if outline.has("periodMs") and not _in(float(outline.periodMs), 1, 10000):Common.error(report, where, "outline period out of range")
                    if outline.has("alphaThreshold") and not _in(float(outline.alphaThreshold), 1, 255):Common.error(report, where, "outline alpha threshold out of range")
                "body_film":
                    if not _in(step.fade_in, 0, 10) or not _in(step.fade_out, 0, 10):Common.error(report, where, "body film fades out of range")
    for text in [e.application_text, e.removal_text]:
        if text != null and text.duration != 0.0 and not _in(text.duration, 0.001, 10):Common.error(report, where, "feedback duration out of range")
## Poses and markers against the rigs' clips (the characters source, which the
## game's body sources are built from): a pose's rig and clip exist, a held frame
## lies inside the clip, speeds are sane, and a rig-specific action's markers
## fall inside its clip.
static func _validate_rigs(entries: Dictionary, report: Dictionary) -> void:
    var rigs: Dictionary = _source_rigs()
    for id in entries.get("conditions", {}):
        for pose in entries.conditions[id].poses:
            var where: String = "abilities/conditions/" + id
            var clip: Dictionary = rigs.get(str(pose.get("rig", "")), {}).get("clips", {}).get(str(pose.get("clip", "")), {})
            if clip.is_empty():Common.error(report, where, "pose has no rig clip: " + str(pose.get("rig", "")) + "/" + str(pose.get("clip", "")));continue
            if pose.get("sampling") == "hold" and float(pose.get("frame", 0)) >= float(clip.frames):Common.error(report, where, "held pose frame outside its clip")
            var speed := float(pose.get("playback_speed", 1.0))
            if not is_finite(speed) or speed < 0.01 or speed > 8.0:Common.error(report, where, "pose playback speed out of range")
    for id in entries.get("actions", {}):
        var body: Resource = entries.actions[id].body
        if body == null or body.rig.is_empty():continue
        var where: String = "abilities/actions/" + id
        var clip: Dictionary = rigs.get(body.rig, {}).get("clips", {}).get(body.clip, {})
        if clip.is_empty():Common.error(report, where, "body has no rig clip: " + body.rig + "/" + body.clip);continue
        if not is_finite(body.playback_speed) or body.playback_speed < 0.01 or body.playback_speed > 8.0:Common.error(report, where, "body playback speed out of range")
        for name in body.markers:
            if body.markers[name] > float(clip.frames):Common.error(report, where, "marker " + name + " after the clip's last frame")

## Sounds mirror the audio library's bindings; the build says when they differ.
## Condition ids the installed package plays a lifecycle for (owner_ids).
static func package_lifecycles() -> Dictionary:
    var result := {}
    var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
    for selection in package.get("selections", []):
        for id in selection.get("condition", {}).get("owner_ids", []):result[id] = true
    return result

static func package_version() -> String:
    return str(JSON.parse_string(FileAccess.get_file_as_string(PACKAGE)).get("version", ""))

## Old sprite media ids a native source draws (their media_ids).
static func drawn_media(entries: Dictionary) -> Dictionary:
    var result := {}
    for id in entries.get("sources", {}):
        for media in entries.sources[id].record.get("media_ids", []):result[media] = true
    return result

## Coverage of a condition: the installed package's lifecycle or a client
## look that draws makes it ready; a recipe with only feedback or old
## sprite layers, or a zone whose surface draws it, is partial.
static func condition_coverage(e: Resource, lifecycle: bool, drawn: Dictionary) -> String:
    if e.status == "internal":return "internal"
    if ((lifecycle or not e.lifecycle_selections.is_empty()) and e.play_package_lifecycle) or not e.poses.is_empty() or _visible_look(e.look):return "ready"
    for use in e.effects+e.responses:
        if use.unbound_constructor_inputs.is_empty() and not Effects.for_cue(R.cue_from_effect(use,-1),use.selection,use.role).is_empty():return "ready"
    if e.layers.any(func(layer): return layer is Dictionary and drawn.has(str(layer.get("assetId", "")))):return "ready"
    if e.disposition=="state_only":return "state_only"
    if not e.effects.is_empty() or not e.responses.is_empty():return "partial"
    if (not e.disposition.is_empty() and e.disposition != "state_only") or not e.surface.is_empty():return "partial"
    return "missing"

## Reuse a declared condition source without changing its package owner_ids.
## The explicit assignment must still supply the same real member/recipient
## lifecycle inputs as the ordinary owner-indexed route.
static func _check_lifecycle_selections(conditions:Dictionary,package:Dictionary,clips:Dictionary,report:Dictionary)->void:
    for id in conditions:
        var entry:Resource=conditions[id]
        var keys:Array=Array(entry.lifecycle_selections)
        if entry.owner_kind not in ["condition","temporary_hp_grant"]:
            Common.error(report,"abilities/conditions/"+str(id),"unknown actual lifetime owner kind")
        if entry.owner_kind=="temporary_hp_grant" and (entry.id.is_empty() or keys.is_empty() or entry.disposition!="authored" \
            or not entry.effects.is_empty() or not entry.responses.is_empty() or not entry.appearance_layers.is_empty()):
            Common.error(report,"abilities/conditions/"+str(id),"temporary-HP grant source needs its exact source_id and selected lifecycle, without condition-only phases/appearance")
        if keys.is_empty():continue
        var where:String="abilities/conditions/"+str(id)
        if not entry.play_package_lifecycle or not entry.lifecycle_opt_in.is_empty():
            Common.error(report,where,"explicit lifecycle selections require package playback and cannot replace a public lifecycle opt-in")
        var seen:Dictionary={}
        for key in keys:
            if str(key).is_empty() or seen.has(key):
                Common.error(report,where,"lifecycle selection keys must be nonempty and unique");continue
            seen[key]=true
            var matches:Array=package.get("selections",[]).filter(func(selection):return selection.get("key")==key)
            if matches.size()!=1:
                Common.error(report,where,"lifecycle selection is not an exact unique package key: "+str(key));continue
            var lifecycle:Dictionary=matches[0].get("condition",{})
            if entry.owner_kind=="temporary_hp_grant" and (not lifecycle.get("when",{}).is_empty() or not lifecycle.get("marker",{}).is_empty()):
                Common.error(report,where,"grant lifecycle requires a generic recipient body source without condition-state predicates/marker ownership")
            var registration:Dictionary=lifecycle.get("registration",{})
            var attachment:String=str(registration.get("attachment",""))
            var anchor:String=str(registration.get("anchor","ground" if registration.get("attachment")=="recipient_ground" else ""))
            var recipient_mount:bool=(attachment=="recipient_body" and anchor in ["head","body_center"]) \
                or (attachment=="recipient_head" and anchor=="head") or (attachment=="recipient_ground" and anchor=="ground")
            if lifecycle.get("schema")!="vfxfactory.condition_lifecycle.v1" or lifecycle.get("owner_kind")!="condition" \
                or not recipient_mount or lifecycle.get("phases",{}).size()!=3:
                Common.error(report,where,"explicit selection needs its declared recipient condition lifecycle contract: "+str(key));continue
            for phase in ["application","sustain","removal"]:
                var clip:Dictionary=clips.get(str(lifecycle.phases.get(phase,"")),{})
                var inputs:Array=clip.get("inputs",[])
                var mounted:bool=(attachment=="recipient_body" and "targets" in inputs) \
                    or (attachment=="recipient_head" and "root_path" in inputs) \
                    or (attachment=="recipient_ground" and ("targets" in inputs or "root_path" in inputs))
                if clip.is_empty() or float(clip.get("seconds",0.0))<=0.0 or "owner_state" not in inputs or not mounted:
                    Common.error(report,where,"explicit lifecycle phase needs its real owner clock and declared recipient mount input: "+str(key)+"/"+phase)
                if "appearance_provider" in inputs and entry.appearance_layers.is_empty():
                    Common.error(report,where,"explicit appearance lifecycle needs its actual recipient outfit declaration: "+str(key)+"/"+phase)

## This route selects the installed Dragon's authored source pixels. It is
## deliberately separate from socket/radius regions and optional body imports.
static func _authored_mouth_error(geometry:Dictionary,condition_id:String)->String:
    const OVERLAY="res://dragon_overlay/index.json"
    if not FileAccess.file_exists(OVERLAY):return "authored mouth overlay is not installed"
    var overlay:Variant=JSON.parse_string(FileAccess.get_file_as_string(OVERLAY))
    if not overlay is Dictionary or overlay.get("schema")!="factory.dragon_creature_overlay.v1":return "authored mouth overlay identity is unavailable"
    var mouth:Dictionary=overlay.get("mouth",{})
    var region:Dictionary=geometry.get("region",{})
    if geometry.get("actor")!="target" or geometry.get("slots")!=["body"] \
        or region.get("id")!="mouth" or region.get("status")!="authored" or region.get("kind")!="authored_pixels" \
        or region.get("layout")!="selected768" or region.get("rig")!=mouth.get("rig") or condition_id!=mouth.get("condition_id"):
        return "authored mouth requires its exact selected Dragon body/condition/768 registration"
    if region.get("table")!=mouth.get("data") or region.get("receiver_inputs")!=mouth.get("receiver_inputs"):
        return "authored mouth requires its installed pixel table and receiver inputs"
    for path in [str(region.get("table","")),str(region.get("receiver_inputs","")),str(mouth.get("helper",""))]:
        if path.is_empty() or not FileAccess.file_exists(path):return "authored mouth input is unavailable: "+path
    var table:Variant=JSON.parse_string(FileAccess.get_file_as_string(region.table))
    if not table is Dictionary or table.get("schema")!="dragon_mouth.authored_surfaces.v1" or table.get("banks",{}).is_empty():
        return "authored mouth pixel registrations are unavailable"
    var receivers:Variant=JSON.parse_string(FileAccess.get_file_as_string(region.receiver_inputs))
    if not receivers is Dictionary or receivers.get("schema")!="factory.dragon_mouth.receiver_inputs.v1" \
        or receivers.get("condition_id")!=condition_id or receivers.get("rig")!=region.rig or receivers.get("rows",[]).is_empty():
        return "authored mouth receiver inputs do not match its condition and rig"
    return ""

## This delivered table is authoring input only. Runtime recipes retain the
## explicit public gate/direct-constructor pairing; no second runtime loader.
static func _condition_lifecycle_opt_ins(e:Resource)->Array:
    if e.lifecycle_opt_in.is_empty() or not FileAccess.file_exists(e.lifecycle_opt_in):return []
    var table:Variant=JSON.parse_string(FileAccess.get_file_as_string(e.lifecycle_opt_in))
    if not table is Dictionary or table.get("schema")!="factory.public_admission.condition_opt_ins.v1":return []
    var result:Array=table.get("selections",[]).filter(func(row):return row.get("condition_id")==e.id \
        and row.get("playable_type",false) and not row.get("art_alternative_only",true))
    var package:Variant=JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
    var clips:Dictionary={}
    if package is Dictionary:
        for clip in package.get("clips",[]):clips[str(clip.clip_id)]=clip
    for row in result:
        for phase in row.get("phases",{}).values():
            var matches:Array=clips.get(str(phase.get("clip_id","")),{}).get("approaches",[]).filter(func(approach):
                return approach.get("path")==phase.get("constructor") and approach.get("source_phase")==phase.get("phase"))
            if matches.size()==1:phase.approach_id=matches[0].id
            var source:Resource=load(str(phase.get("phase",""))) if FileAccess.file_exists(str(phase.get("phase",""))) else null
            if source!=null:phase.source_seconds=float(source.get("seconds"))
    return result

static func _visible_look(look: Resource) -> bool:
    if look == null:return false
    for step in look.steps:
        if step.kind != "body_adjust" or step.alpha < 1.0 or step.rgb != Color.WHITE or step.saturation != 1.0 or step.brightness != 1.0 or not step.scale_by_size_change.is_empty():return true
    return false

static func _check_binding(report: Dictionary, where: String, binding: Variant, sound: Resource) -> void:
    if not binding is Dictionary:Common.warn(report, where, "sound " + sound.cue + " has no binding in the audio library");return
    if binding.get("cue") != sound.cue or binding.get("timing") != sound.at or binding.get("enabled", true) != sound.enabled:
        Common.warn(report, where, "sound differs from the audio library binding: " + sound.cue)

static func _coverage(entries: Dictionary, report: Dictionary) -> void:
    for id in entries.get("spells", {}):Common.cover(report, "spell", id, entries.spells[id].status)
    var lifecycles := package_lifecycles()
    var drawn := drawn_media(entries)
    var without := 0
    for id in entries.get("conditions", {}):
        var e: Resource = entries.conditions[id]
        var status := condition_coverage(e, lifecycles.has(id), drawn)
        if status == "missing":without += 1
        Common.cover(report, "condition", id, status)
    Common.warn(report, "abilities", "%d conditions draw nothing yet: no lifecycle in the installed package (%s) and no client look" % [without, package_version()])
    for id in entries.get("actions", {}):
        var e: Resource = entries.actions[id]
        Common.cover(report, e.kind if e.kind in ACTION_KINDS else "action", id, e.status)
    for id in entries.get("damage_types", {}):Common.cover(report, "damage_type", id, entries.damage_types[id].status)

## The characters source's rigs as {rig id: {clips: {clip name: {frames}}}}.
static func _source_rigs() -> Dictionary:
    var root: Resource = load("res://authoring/characters.tres") if FileAccess.file_exists("res://authoring/characters.tres") else null
    var result: Dictionary = {}
    if root == null:return result
    for id in root.sections.get("rigs", {}):
        var rig: Resource = load(root.sections.rigs[id])
        if rig == null:continue
        var clips: Dictionary = {}
        for clip in rig.clips:clips[clip.name] = {"frames": clip.frames}
        result[id] = {"clips": clips}
    return result
