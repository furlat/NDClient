#!/usr/bin/env python3
"""Snapshot every content id the dnd_engine server can send to this client.

    python3 tools/snapshot_server_ids.py [--engine PATH] [--python PATH] [--output PATH | -]

The command reruns itself under the engine interpreter (python -B, cwd = engine,
PYTHONDONTWRITEBYTECODE=1) to read the engine registries, and writes only --output.
The engine tree is never written and its git state is only read.
No presentation keys (icon, portrait, sprite, vfx) are copied: the client binds its own.
"""

import argparse
import importlib
import inspect
import json
import os
import pkgutil
import re
import subprocess
import sys
import uuid

DEFAULT_ENGINE = "/home/tommaso/.cache/ndclient/dnd_engine-1f044792b1"
DEFAULT_PYTHON = "/home/tommaso/.cache/dnd-engine/venv/bin/python"
DEFAULT_OUTPUT = "authoring/server_ids.json"

# Item ids the engine creates while a spell or object runs; no builder owns them.
# Found by searching the engine for item_id literals; extend when it adds more.
RUNTIME_ITEMS = {
    "weapon.flame_blade": "weapon",
    "spell_payload.freezing_sphere": "usable",
    "spell_payload.delayed_fireball": "usable",
    "spell_construction.ice.section": "item",
    "spell_construction.stone.section": "item",
    "spell_construction.force.section": "item",
    "spell_construction.forcecage.section": "item",
    "environment.standing_torch": "item",
    "environment.control_lever": "item",
}

# Protocol enums copied from the engine player schema: output name -> $defs name.
SCHEMA_ENUMS = {
    "tile_material": "Material",
    "boundary_structure": "BoundaryStructureKind",
    "connector": "TraversalConnectorKind",
    "damage_type": "DamageType",
    "species": "Species",
    "species_variant": "SpeciesVariant",
    "class": "CharacterClass",
    "subclass": "CharacterSubclass",
    "background": "Background",
    "size": "Size",
    "item_kind": "ItemPresentationKind",
    "spatial_effect_layer": "SpatialEffectLayer",
}

# Engine packages whose modules define spatial-effect refs; imported so none is missed.
CONTENT_PACKAGES = ("dnd.spatial", "dnd.spells", "dnd.classes", "dnd.items",
                    "dnd.monsters", "dnd.content", "dnd.summoning")
SCHOOLS = {"abjuration", "conjuration", "divination", "enchantment",
           "evocation", "illusion", "necromancy", "transmutation"}
CONTROL = {"Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", "Paralyzed",
           "Petrified", "Poisoned", "Prone", "Restrained", "Stunned", "Unconscious"}
# What the body does, for ids whose class alone does not say it (id without its first segment).
BODY_BY_ID = {
    "attack": "weapon_attack", "monster.natural_attack": "natural_attack",
    "monster.shield_bash": "shield_bash", "opportunity_attack": "weapon_attack",
    "move": "move", "swim": "move", "dash": "move", "jump": "move", "trait.aggressive": "move",
    "traverse_connector": "traverse", "disengage": "stance", "dodge": "stance", "hide": "hide",
    "shove": "shove", "pick_up": "pick_up", "core.drop": "drop", "core.drop_prone": "prone",
    "core.stand_up": "stand", "stand_when_healed": "stand", "drop_concentration": "none",
    "summon.dismiss": "none", "shake_awake": "assist", "ally_help": "assist", "help_attack": "assist",
    "wizard.learn_scroll": "use_item", "monster.parry": "block",
    "class_feature.fighter.protection": "block", "spell.payload.throw": "throw",
    "spell.delayed_blast_fireball.touch": "interact",
}
OBJECT_BY_ENVIRONMENT_ACTION = {"escape_jaw": "environment.trap.jaw",
                                "heroes_feast": "environment.spell_object.heroes_feast"}


def field_default(cls, name):
    field = getattr(cls, "model_fields", {}).get(name)
    if field is None:
        return None
    try:
        return field.get_default(call_default_factory=True)
    except Exception:
        return None


def source_of(cls, prefixes=("dnd.spells", "dnd.items", "dnd.classes", "dnd.monsters", "dnd.conditions")):
    parts = []
    for owner in getattr(cls, "__mro__", ()):
        if owner.__module__.startswith(prefixes):
            try:
                parts.append(inspect.getsource(owner))
            except (OSError, TypeError):
                pass
    return "\n".join(parts)


def created_classes(cls):
    from dnd.actions import SpellAction
    seen, pending = [], list(getattr(cls, "creates", ()))
    while pending:
        product = pending.pop()
        if product in seen or (isinstance(product, type) and issubclass(product, SpellAction)):
            continue
        seen.append(product)
        pending.extend(getattr(product, "creates", ()))
    return seen


def spatial_effect_of(cls):
    content_id = getattr(field_default(cls, "content_ref"), "content_id", "")
    return content_id if content_id.startswith("spatial_effect.") else None


def layer_of(cls):
    return getattr(field_default(cls, "layer"), "value", None)


def spell_harmful(cls):
    from dnd.spells.content_metadata import get_spell_catalog_metadata
    try:
        meta = get_spell_catalog_metadata(cls)
    except Exception:
        return None
    return bool(meta.saving_throws or meta.attack_roll or meta.damage_types)


def spell_shape(meta, cls, source, conditions, zone_layers):
    from dnd.spells.summoning import SummonSpell
    if isinstance(cls, type) and issubclass(cls, SummonSpell):
        return "summon"
    if meta is None:
        return "other"
    if meta.delivery in ("self", "none") and re.search("[Tt]eleport", source):
        return "teleport"
    area = meta.aoe.shape if meta.aoe else None
    if area == "wall":
        return "wall"
    direct = {"single_projectile": "projectile", "missile_volley": "projectile_volley",
              "ray": "ray", "beam": "ray", "touch": "melee_spell_attack" if meta.attack_roll else "touch"}
    if meta.delivery in direct:
        return direct[meta.delivery]
    if "cloud" in zone_layers:
        return "cloud"
    if zone_layers:
        return "zone"
    if meta.delivery == "aoe_projectile":
        return "projectile"
    if area:
        return area
    if meta.delivery == "self":
        return "self"
    if meta.target_type in ("entity", "multi_entity", "object"):
        return "condition_only" if conditions else "targeted"
    return "point"


def spell_entry(decl, cls, ids_by_class):
    from dnd.spells.content_metadata import get_spell_catalog_metadata
    from dnd.spells.summoning import SummonSpell
    from dnd.summoning.forms import SUMMON_FORMS
    tags = set(decl.descriptor.tags)
    level = 0 if "cantrip" in tags else next(
        (int(tag[6:]) for tag in tags if tag.startswith("level_")), field_default(cls, "spell_level"))
    school = next((tag for tag in tags if tag in SCHOOLS), field_default(cls, "spell_school"))
    try:
        meta = get_spell_catalog_metadata(cls)
    except Exception:
        meta = None
    conditions, effects, zone_layers = set(), set(), set()
    for product in created_classes(cls):
        product_id = ids_by_class.get(product, "")
        effect_id = spatial_effect_of(product) or (product_id if product_id.startswith("spatial_effect.") else None)
        if effect_id:
            effects.add(effect_id)
            if effect_id.startswith("spatial_effect.spell."):
                zone_layers.add(layer_of(product))
        if product_id.startswith(("condition.", "trait.")) and product_id != "condition.concentrating":
            conditions.add(product_id)
    summons = {dep.target_ref.content_id for dep in decl.dependencies if dep.relation.value == "summons_creature"}
    if isinstance(cls, type) and issubclass(cls, SummonSpell):
        family = field_default(cls, "family")
        summons |= {form.recipe.ref.content_id for form in SUMMON_FORMS if form.family == family}
    source = source_of(cls)
    variants = set()
    if any("facet_domain" in vars(owner) for owner in getattr(cls, "__mro__", ())
           if owner.__module__.startswith(("dnd.spells", "dnd.items", "dnd.classes"))):
        keys = set(re.findall("ActionVariantFacet\\(key=\"(\\w+)\"", source))
        variants |= {"choice:" + key for key in keys} or {"choice"}
    if isinstance(level, int) and level > 0 and re.search("At Higher Levels|cast_at_level|get_upcast_bonus|upcast", source):
        variants.add("upcast")
    if level == 0 and re.search("caster_level|character_level", source):
        variants.add("cantrip_scaling")
    area = None
    if meta and meta.aoe:
        area = {key: value for key, value in meta.aoe.model_dump().items() if value is not None}
    return {
        "visibility": decl.descriptor.visibility.value,
        "level": level,
        "school": school,
        "shape": spell_shape(meta, cls, source, conditions, zone_layers),
        "delivery": {
            "catalog": meta.delivery if meta else None,
            "projectile": meta.projectile_type if meta else None,
            "area": area,
            "max_targets": meta.multi_target.max_targets if meta and meta.multi_target else None,
            "concentration": meta.concentration if meta else None,
            "damage_types": sorted(kind.value for kind in meta.damage_types) if meta else [],
        },
        "conditions": sorted(conditions),
        "spatial_effects": sorted(effects),
        "summons": sorted(summons),
        "variants": sorted(variants),
    }


def condition_family(condition_id, decl, names):
    if decl.ref.pack_id == "core.rules":
        return "core"
    if condition_id.startswith("spatial_effect."):
        return "spatial_effect"
    second = condition_id.split(".")[1]
    if second == "spell":
        return "spell_zone" if "AreaCondition" in names else "spell"
    if second.startswith("summon"):
        return "summon"
    if second in ("tile", "consumable", "environment", "class"):
        return second
    if second == "wight":
        return "creature"
    return "other"


def condition_entry(condition_id, decl, cls, harm):
    names = {owner.__name__ for owner in getattr(cls, "__mro__", ())}
    category = getattr(field_default(cls, "condition_category"), "value", None)
    controls = {product.__name__.lower() for product in getattr(cls, "creates", ()) if product.__name__ in CONTROL}
    if cls is not None and cls.__name__ in CONTROL:
        controls.add(cls.__name__.lower())
    lifecycle = decl.condition_lifecycle
    if category == "internal":
        kind = "internal"
    elif "AreaCondition" in names or condition_id.startswith("spatial_effect."):
        kind = "zone_membership" if "MembershipAreaCondition" in names else "zone"
    elif "aura" in condition_id:
        kind = "aura"
    elif "weapon_coat" in condition_id:
        kind = "coating"
    elif field_default(cls, "grants_invisibility") or "Invisible" in names or re.search(
            "grants_invisibility[^\n]*True", source_of(cls)):
        kind = "invisibility"
    elif controls:
        kind = "control:" + "/".join(sorted(controls))
    elif re.search("enlarge|petrif|flesh_to_stone|transmuted", condition_id):
        kind = "transformation"
    elif lifecycle and lifecycle.agency_denial.value != "none":
        kind = "control"
    elif category == "status":
        kind = "state"
    elif harm == {True}:
        kind = "debuff"
    elif harm == {False}:
        kind = "buff"
    else:
        kind = "unclassified"
    zone = spatial_effect_of(cls) if "AreaCondition" in names else None
    return {
        "family": condition_family(condition_id, decl, names),
        "kind": kind,
        "category": category,
        "visible": category != "internal" and decl.descriptor.visibility.value != "internal",
        "zone_spatial_effect": zone,
        "layer": layer_of(cls) if "AreaCondition" in names else None,
    }


def action_family(action_id, decl, cls):
    kind = decl.ref.definition_kind.value
    if kind in ("trait", "reaction", "class_feature", "feat"):
        return kind
    parts = action_id.split(".")
    if decl.ref.pack_id == "core.rules" or parts[1] == "core" or len(parts) == 2:
        return "core"
    if parts[1] in ("class", "wizard"):
        return "class"
    if parts[1] in ("environment", "item", "spell", "trait", "summon", "monster"):
        return parts[1]
    if parts[1] == "creature":
        return "monster"
    if "summon" in getattr(cls, "__module__", ""):
        return "summon_form"
    return "other"


def action_body(action_id, decl, category, target_type, presentation):
    kind = decl.ref.definition_kind.value
    short = action_id.split(".", 1)[1]
    last = action_id.rsplit(".", 1)[1]
    if kind in ("trait", "class_feature", "feat"):
        return "passive"
    if short in BODY_BY_ID:
        return BODY_BY_ID[short]
    if "multiattack" in action_id:
        return "multiattack"
    if "smite" in action_id:
        return "weapon_rider"
    if presentation == "drink" or last in ("drink", "eat"):
        return "consume"
    if last.startswith("escape") or ".escape_" in action_id:
        return "struggle"
    if last == "dismiss":
        return "none"
    if action_id.startswith("action.environment."):
        return "interact"
    if action_id.startswith("action.item."):
        return "use_item"
    if kind == "reaction":
        return "cast" if ".spell." in action_id else "unclassified"
    if category == "attack":
        return "area_attack" if target_type == "position_aoe" else "attack"
    if category == "spell":
        return "cast"
    if category == "movement":
        return "move"
    if category == "ability":
        if target_type == "self":
            return "self_ability"
        return "area_ability" if (target_type or "").startswith("position") else "targeted_ability"
    return "unclassified"


def action_entry(action_id, decl, cls):
    target_type = getattr(field_default(cls, "target_type"), "value", None)
    binding = getattr(field_default(cls, "interaction_affordance"), "binding", None)
    parts = action_id.split(".")
    if parts[1] == "environment":
        target = OBJECT_BY_ENVIRONMENT_ACTION.get(parts[2], "environment." + parts[2])
    elif parts[1] == "item" or binding == "source_item":
        target = "source_item"
    elif binding == "connector" or parts[-1] == "traverse_connector":
        target = "connector"
    elif decl.ref.definition_kind.value in ("trait", "class_feature", "feat"):
        target = None
    elif "multiattack" in action_id:
        target = "creature_or_object"
    else:
        target = target_type
    category = getattr(field_default(cls, "action_category"), "value", None)
    presentation = getattr(field_default(cls, "presentation_kind"), "value", None)
    return {"family": action_family(action_id, decl, cls),
            "body": action_body(action_id, decl, category, target_type, presentation),
            "target": target}


def creature_entries(declarations):
    from dnd.content_system.creature_materialization import materialize_creature
    from dnd.core.content.materialization import CreatureDeploymentRole, CreaturePossessionMode
    from dnd.core.content.recipes import ContentRecipe
    entries = {}
    for decl in declarations:
        entity = materialize_creature(
            ContentRecipe.create(ref=decl.ref, parameters={}), runtime_entity_uuid=uuid.uuid4(),
            display_name=decl.descriptor.display_name, faction=None, position=(0, 0),
            deployment_role=CreatureDeploymentRole(role_id="snapshot.probe"),
            possession_mode=CreaturePossessionMode.INCLUDE_DEFAULT_POSSESSIONS)
        entries[decl.ref.content_id] = {"name": decl.descriptor.display_name, "size": entity.size.value,
                                        "ui_group": decl.descriptor.presentation.ui_group}
    return entries


def item_kinds():
    """Builder items, then every item the materialized creatures carry, then RUNTIME_ITEMS."""
    from dnd.blocks.base_item import BaseItem
    from dnd.content.items.authored_item_builders import DIRECT_ITEM_BUILDERS
    from dnd.core.base_object import BaseObject
    kinds = {item_id: build(uuid.uuid4()).to_item_presentation_state().item_kind.value
             for item_id, build in DIRECT_ITEM_BUILDERS.items()}
    for obj in list(BaseObject._registry.values()):
        if isinstance(obj, BaseItem):
            kinds.setdefault(obj.item_id, obj.to_item_presentation_state().item_kind.value)
    for item_id, kind in RUNTIME_ITEMS.items():
        kinds.setdefault(item_id, kind)
    return kinds


def spatial_effect_entries(registry_ids, classes_by_id):
    """Registry-backed effects plus every spatial_effect ref or class the engine content modules define."""
    from dnd.core.content.identities import ContentRef
    for package in CONTENT_PACKAGES:
        for info in pkgutil.walk_packages(importlib.import_module(package).__path__, package + "."):
            importlib.import_module(info.name)
    entries = {content_id: {"in_registry": True, "layer": layer_of(classes_by_id.get(content_id))}
               for content_id in registry_ids}
    for module in [m for name, m in list(sys.modules.items()) if name.startswith("dnd.")]:
        for value in list(vars(module).values()):
            if isinstance(value, ContentRef):
                content_id = value.content_id
            elif isinstance(value, type):
                content_id = spatial_effect_of(value)
            else:
                continue
            if content_id and content_id.startswith("spatial_effect."):
                entry = entries.setdefault(content_id, {"in_registry": False, "layer": None})
                if isinstance(value, type) and entry["layer"] is None:
                    entry["layer"] = layer_of(value)
    return entries


def git(engine, *args):
    result = subprocess.run(["git", "--no-optional-locks", "-C", engine, *args], capture_output=True, text=True)
    return result.stdout.strip()


def extract(engine):
    sys.path.insert(0, engine)
    from dnd.content_system.bootstrap import bootstrap_content_system
    from dnd.content_system.runtime import SERVER_CONTENT_SYSTEM_RUNTIME
    from dnd.residues import ResidueProfile
    import dnd.residues as residues
    from dnd.scenarios.battlefield_catalog import BATTLEFIELDS_BY_ID
    loaded = SERVER_CONTENT_SYSTEM_RUNTIME.install(bootstrap_content_system())
    classes_by_id = {decl.ref.content_id: cls for cls, decl in loaded.behavior_declarations_by_class.items()}
    ids_by_class = {cls: content_id for content_id, cls in classes_by_id.items()}
    by_kind = {}
    for decl in loaded.registry.declarations.values():
        by_kind.setdefault(decl.ref.definition_kind.value, []).append(decl)
    harm = {}  # condition id -> harmfulness of the spells that create it
    for cls, decl in loaded.behavior_declarations_by_class.items():
        if decl.ref.definition_kind.value == "spell" and spell_harmful(cls) is not None:
            for product in getattr(cls, "creates", ()):
                if product in ids_by_class:
                    harm.setdefault(ids_by_class[product], set()).add(spell_harmful(cls))
    ids = {
        "spell": {d.ref.content_id: spell_entry(d, classes_by_id.get(d.ref.content_id), ids_by_class)
                  for d in by_kind["spell"]},
        "condition": {d.ref.content_id: condition_entry(d.ref.content_id, d, classes_by_id.get(d.ref.content_id),
                                                        harm.get(d.ref.content_id, set()))
                      for d in by_kind["condition"]},
        "creature": creature_entries(by_kind["creature"]),
    }
    for kind in ("action", "trait", "reaction", "class_feature", "feat"):
        ids[kind] = {d.ref.content_id: action_entry(d.ref.content_id, d, classes_by_id.get(d.ref.content_id))
                     for d in by_kind.get(kind, [])}
    kinds = item_kinds()
    ids["item"] = {i: {"kind": k} for i, k in kinds.items() if not i.startswith("environment.")}
    ids["environment_object"] = {i: {"kind": k} for i, k in kinds.items() if i.startswith("environment.")}
    ids["spatial_effect"] = spatial_effect_entries(
        [i for i in ids["condition"] if i.startswith("spatial_effect.")], classes_by_id)
    ids["residue"] = {p.residue_id: {"max_amount": p.max_amount} for p in vars(residues).values()
                      if isinstance(p, ResidueProfile)}
    with open(os.path.join(engine, "sdk", "protocol", "player-api-v1.schema.json"), encoding="utf-8") as handle:
        schema_defs = json.load(handle)["$defs"]
    for name, definition in SCHEMA_ENUMS.items():
        ids[name] = {str(value): {} for value in schema_defs[definition]["enum"]}
    light = schema_defs.get("LightRow") or schema_defs["PerceivedLightSource"]
    ids["light_appearance"] = {value: {} for value in light["properties"]["appearance"]["enum"]}
    ids["battlefield"] = {key: {"title": spec.title} for key, spec in BATTLEFIELDS_BY_ID.items()}
    with open(os.path.join(engine, "sdk", "protocol", "protocol-identity.json"), encoding="utf-8") as handle:
        identity = json.load(handle)
    provenance_path = os.path.join(engine, ".source.json")
    provenance = {}
    if os.path.isfile(provenance_path):
        with open(provenance_path, encoding="utf-8") as provenance_file:
            provenance = json.load(provenance_file)
    header = {
        "engine": engine,
        "commit": git(engine, "rev-parse", "HEAD") or provenance.get("commit", ""),
        "branch": git(engine, "rev-parse", "--abbrev-ref", "HEAD") or provenance.get("branch", ""),
        "uncommitted_paths": len([line for line in git(engine, "status", "--porcelain").splitlines() if line]),
        "protocol_version": identity["protocol_version"],
        "player_schema_version": identity["player_schema_version"],
        "schema_digest": identity["schema_digest"],
        "content_set_digest": loaded.content_set_digest,
        "generator": "tools/snapshot_server_ids.py",
    }
    return {"header": header, "counts": {kind: len(rows) for kind, rows in ids.items()}, "ids": ids}


def main():
    parser = argparse.ArgumentParser(description="Snapshot every content id the dnd_engine server can send.")
    parser.add_argument("--engine", default=DEFAULT_ENGINE)
    parser.add_argument("--python", help="engine interpreter (default: cached engine venv, else ENGINE/.venv)")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="path relative to the client root, or - for stdout")
    parser.add_argument("--extract", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    engine = os.path.abspath(args.engine)
    if args.extract:
        stdout, sys.stdout = sys.stdout, sys.stderr  # keep engine prints out of the JSON
        data = extract(engine)
        sys.stdout = stdout
        json.dump(data, sys.stdout)
        return
    python = args.python or next((path for path in (DEFAULT_PYTHON, os.path.join(engine, ".venv", "bin", "python"))
                                  if os.path.exists(path)), sys.executable)
    result = subprocess.run([python, "-B", os.path.abspath(__file__), "--extract", "--engine", engine],
                            cwd=engine, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1",
                                PYTHONPATH=os.pathsep.join((engine, os.path.join(engine, "sdk/python/src")))),
                            capture_output=True, text=True)
    if result.returncode:
        sys.stderr.write(result.stderr)
        sys.exit(result.returncode)
    text = json.dumps(json.loads(result.stdout), indent=1, sort_keys=True) + "\n"
    if args.output == "-":
        sys.stdout.write(text)
        return
    client_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output = os.path.join(client_root, args.output)
    with open(output, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print(output, json.loads(text)["counts"], file=sys.stderr)


if __name__ == "__main__":
    main()
