"""Offline exact-ID join of typed bindings, the installed Factory and engine IDs.

Reads TRES source properties without loading Godot, artwork or native programs.
Provider presence is not a claim of event coverage, pixels or user acceptance.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "generated/reports/factory-binding-completion.json"
UNACCEPTED = {"spell.aid", "spell.bless", "spell.false_life", "spell.sacred_flame"}
# Exact native mappings established by the frozen definitions/grants, documented
# in FACTORY_INTEGRATION_COVERAGE_2026-10-19.md. A study title is never a join.
DIVINE = {
    "turn_undead_radial": "action.class.cleric.turn_undead",
    "turn_unholy_radial": "action.class.paladin.turn_unholy",
    "destroy_undead": "class_feature.cleric.destroy_undead",
    "preserve_life": "action.class.cleric.preserve_life",
    "blessed_healer": "class_feature.cleric.blessed_healer",
    "divine_strike": "class_feature.cleric.divine_strike",
    "improved_divine_smite": "class_feature.paladin.improved_divine_smite",
    "divine_sense": "condition.class.paladin.divine_sense",
    "lay_on_hands_lesser": "action.class.paladin.lay_on_hands",
    "lay_on_hands_greater": "action.class.paladin.lay_on_hands",
    "lay_on_hands_cure": "action.class.paladin.lay_on_hands",
    "cleansing_touch": "action.class.paladin.cleansing_touch",
    "aura_protection": "condition.class.paladin.aura_benefit",
    "aura_devotion_fitted": "condition.class.paladin.aura_benefit",
    "aura_courage": "condition.class.paladin.aura_benefit",
    "holy_nimbus": "condition.class.paladin.holy_nimbus",
    "intervention_sunder_clefts": "action.class.cleric.divine_intervention.sunder_heretical",
    "intervention_revival_living": "action.class.cleric.divine_intervention.opulent_revival",
    "intervention_revival_dead": "action.class.cleric.divine_intervention.opulent_revival",
    "intervention_arm_admission": "action.class.cleric.divine_intervention.arm_thy_servant",
    "intervention_generosity_admission": "action.class.cleric.divine_intervention.golden_generosity",
    "devotee_mace_heal": "action.item.devotees_mace.healing_incense",
    "sacred_weapon": "condition.class.paladin.sacred_weapon",
}
# Declared setter bridges in native_inputs.gd and native_action_authoring.gd.
# Some are conditional/partial. The report lists unsupported channels separately
# and never mistakes the generic condition-state passthrough for a producer.
PROVIDERS = set("root_path owner_state owner_visibility targets live_endpoints recipient_geometry entity_geometry source_geometry actor_context history_state actor_layers treatment_state appearance_provider weapon_binding pose_provider admitted_cells binding_owners delivery_timing owner_projection activation_projection".split())
EVENT_PROVIDERS = {"event_input", "lease_input"}
DIVINE_GAPS = {
    "destroy_undead": ["effective_handler_attribution"],
    "blessed_healer": ["effective_handler_attribution", "attributed_self_heal"],
    "divine_strike": ["effective_handler_attribution", "exact_rider_damage_component"],
    "improved_divine_smite": ["effective_handler_attribution", "exact_rider_damage_component"],
    "lay_on_hands_lesser": ["selected_form_not_disclosed"],
    "lay_on_hands_greater": ["selected_form_not_disclosed"],
    "lay_on_hands_cure": ["selected_form_not_disclosed"],
    "aura_protection": ["aura_kind_not_disclosed"],
    "aura_devotion_fitted": ["aura_kind_not_disclosed"],
    "aura_courage": ["aura_kind_not_disclosed"],
    "holy_nimbus": ["contact_needs_exact_source_condition_uuid"],
    "devotee_mace_heal": ["source_item_owner_contribution_link"],
    "sacred_weapon": ["actual_condition_or_item_membership_not_disclosed"],
}


def properties(block: str) -> dict[str, str]:
    fields = list(re.finditer(r"^(\w+) = ", block, re.M))
    return {m[1]: block[m.end():fields[i + 1].start() if i + 1 < len(fields) else len(block)].strip()
            for i, m in enumerate(fields)}


def value(raw: str, default=None):
    if raw is None:
        return default
    packed = re.fullmatch(r"Packed(?:String|Int32|Int64)Array\((.*)\)", raw, re.S)
    if packed:
        return json.loads("[" + packed[1] + "]")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return default


def typed_source(path: Path, section: str) -> dict:
    text = path.read_text()
    parts = re.split(r"^(\[(?:gd_resource|ext_resource|sub_resource|resource)\b[^\n]*\])\n", text, flags=re.M)
    blocks = {head: body for head, body in zip(parts[1::2], parts[2::2])}
    root = properties(blocks["[resource]"])
    sub = {re.search(r'\bid="([^"]+)"', head)[1]: properties(body)
           for head, body in blocks.items() if head.startswith("[sub_resource")}
    def cues(raw):
        result = []
        for identity in re.findall(r'SubResource\("([^"]+)"\)', raw or ""):
            fields = sub[identity]
            result.append({"clip": value(fields.get("clip"), ""), "selection": value(fields.get("selection"), ""),
                "role": value(fields.get("role"), ""), "scope": value(fields.get("scope"), ""),
                "at": value(fields.get("at"), ""), "constructor_input": value(fields.get("constructor_input"), {}),
                "input_policies": value(fields.get("extra"), {}).get("input_policies", {}),
                "unbound_constructor_inputs": value(fields.get("unbound_constructor_inputs"), []),
                "source_index": len(result)})
        return result
    row = {"id": value(root["id"]), "section": section, "source": str(path.relative_to(ROOT)),
        "status": value(root.get("status"), "ready" if section == "conditions" else "missing"),
        "disposition": value(root.get("disposition"), ""), "native_staging": value(root.get("native_staging"), False),
        "play_package_lifecycle": value(root.get("play_package_lifecycle"), True),
        "owner_kind": value(root.get("owner_kind"), ""), "owner_ids": value(root.get("owner_ids"), []),
        "owner_cues": value(root.get("owner_cues"), []), "excluded_cues": value(root.get("excluded_cues"), []),
        "explicit_event_cues": value(root.get("explicit_event_cues"), False),
        "event_cues": value(root.get("event_cues"), []), "effects": cues(root.get("effects")), "variants": [],
        "other_authored_methods": {"body": "body" in root, "look": "look" in root, "poses": "poses" in root,
            "layers": "layers" in root, "appearance_layers": "appearance_layers" in root,
            "application_body": "application_body" in root, "removal_body": "removal_body" in root,
            "reaction_cast": value(root.get("reaction_cast"), ""), "plays": value(root.get("plays"), ""),
            "delivers_spell": value(root.get("delivers_spell"), ""), "effect_sources": value(root.get("effect_sources"), [])}}
    for identity in re.findall(r'SubResource\("([^"]+)"\)', root.get("variants", "")):
        fields = sub[identity]
        row["variants"].append({"id": value(fields.get("id"), ""), "kind": value(fields.get("kind"), ""),
            "selection": value(fields.get("selection"), ""), "effects": cues(fields.get("effects"))})
    return row


def qualified_input_policies(cue: dict, clip: dict) -> dict:
    """Explicit consumer choice, distinct from a supplied Factory operand."""
    if cue.get("constructor_input", {}).get("kind") == "spell_strike":
        return qualified_vampiric_input_policies(cue, clip)
    if cue.get("constructor_input", {}).get("projection") == "healing_return":
        return qualified_healing_return_input_policies(cue, clip)
    expected = {"density_field": {"mode": "not_applicable", "reason": "selected_factory_density_mask_disabled"}}
    if cue.get("input_policies") != expected or clip.get("clip_id") != "live-electric/chain_live_single":
        return {}
    if cue.get("constructor_input", {}).get("kind") != "propagation_links":
        return {}
    for approach in clip.get("approaches", []):
        path = approach.get("source_phase")
        if not path:
            return {}
        text = (ROOT / path.removeprefix("res://")).read_text()
        script = re.search(r'^constructor_script = (.+)$', text, re.M)
        inputs = re.search(r'^input = (.+)$', text, re.M)
        if not script or value(script[1]) != "res://assets/vfx/sources/c43d754ae69cc0329592/electric_network.gd" or not inputs:
            return {}
        if value(inputs[1], {}).get("density_mask", False) is not False:
            return {}
    source = (ROOT / "assets/vfx/sources/038f154b06649f707e70/live_network.gd").read_text()
    return {"density_field": expected["density_field"]["reason"]} if 'if settings.get("density_mask", false):' in source else {}


def qualified_vampiric_input_policies(cue: dict, clip: dict) -> dict:
    reason = "first_cast_impact_does_not_consume_owner_or_repeat_inputs"
    policies = {name: {"mode": "not_applicable", "reason": reason}
                for name in ("owner_input", "healing_input", "condition_input", "tick_input")}
    descriptor = cue.get("constructor_input", {})
    if clip.get("clip_id") != "bg3-36/vampiric-touch/vampiric_touch_native/impact" or cue.get("input_policies") != policies:
        return {}
    if descriptor.get("component_path") != ["owned_contact"] or descriptor.get("behavior_id") != "spell.vampiric_touch":
        return {}
    for approach in clip.get("approaches", []):
        if not approach.get("source_phase"):
            return {}
        text = (ROOT / approach["source_phase"].removeprefix("res://")).read_text()
        script = re.search(r'^constructor_script = (.+)$', text, re.M)
        inputs = re.search(r'^input = (.+)$', text, re.M)
        if not script or value(script[1]) != "res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd" or not inputs:
            return {}
        settings = value(inputs[1], {})
        if settings.get("phase") != "impact" or settings.get("behavior_id") != "spell.vampiric_touch":
            return {}
    return dict.fromkeys(policies, reason)


def qualified_healing_return_input_policies(cue: dict, clip: dict) -> dict:
    reason = "positive_healing_return_does_not_consume_owner_or_strike_inputs"
    policies = {name: {"mode": "not_applicable", "reason": reason}
                for name in ("owner_input", "strike_input", "condition_input", "tick_input")}
    descriptor = cue.get("constructor_input", {})
    if clip.get("clip_id") != "bg3-36/vampiric-touch/vampiric_touch_native/healing" or cue.get("input_policies") != policies:
        return {}
    if descriptor.get("kind") != "observed_event" or descriptor.get("component_path") != ["owned_contact"] \
            or descriptor.get("outcome") != "heal" or descriptor.get("geometry_actor") != "target":
        return {}
    for approach in clip.get("approaches", []):
        if not approach.get("source_phase"):
            return {}
        text = (ROOT / approach["source_phase"].removeprefix("res://")).read_text()
        script = re.search(r'^constructor_script = (.+)$', text, re.M)
        inputs = re.search(r'^input = (.+)$', text, re.M)
        if not script or value(script[1]) != "res://assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd" or not inputs:
            return {}
        settings = value(inputs[1], {})
        if settings.get("phase") != "healing" or not isinstance(settings.get("healing"), dict):
            return {}
    source = (ROOT / "assets/vfx/sources/8d17316149890f77c98b/vampiric_touch.gd").read_text()
    if 'if phase == "healing":\n\t\tadmitted = healing_admitted()' not in source:
        return {}
    return dict.fromkeys(policies, reason)


def report() -> dict:
    factory = json.loads((ROOT / "assets/vfx/index.json").read_text())
    engine = json.loads((ROOT / "authoring/server_ids.json").read_text())
    clips = {c["clip_id"]: c for c in factory["clips"]}
    selections = {s.get("spell_id", s["key"]): s for s in factory["selections"]}
    typed = [typed_source(p, section) for section in ["spells", "conditions", "actions"]
             for p in sorted((ROOT / "authoring/abilities" / section).glob("*.tres"))]
    by_id = defaultdict(list)
    references = defaultdict(list)
    owners = defaultdict(list)
    engine_ids = {identity: kind for kind in ["spell", "condition", "spatial_effect", "action", "reaction", "trait", "class_feature", "feat"]
                  for identity in engine["ids"].get(kind, {})}
    registered = set(re.findall(r'"(res://authoring/abilities/[^"\n]+)"', (ROOT / "authoring/abilities.tres").read_text()))
    # These are the actual public fields of this frozen producer, not the
    # Factory review dictionary's richer example state.
    state_source = (Path(engine["header"]["engine"]) / "dnd/types/actor.py").read_text()
    state_source = state_source.split("class ConditionState(BaseModel):", 1)[1].split("class TemporaryHitPointsGrant", 1)[0]
    public_condition_fields = set(re.findall(r"^    (\w+):", state_source, re.M))
    for s in factory["selections"]:
        for owner in s.get("condition", {}).get("owner_ids", []):
            owners[owner].append(s)
    for row in typed:
        row["registered"] = "res://" + row["source"] in registered
        row["factory_lifecycles"] = [{"selection": s["key"], "owner_kind": s["condition"].get("owner_kind"),
            "when": s["condition"].get("when", {}), "phases": s["condition"].get("phases", {})}
            for s in owners[row["id"]]] if row["section"] == "conditions" else []
        for variant, cues in [("default", row["effects"])] + [(v["id"], v["effects"]) for v in row["variants"]]:
            for cue in cues:
                clip = cue["clip"]
                if clip not in clips:
                    selection = selections.get(cue["selection"] or row["id"].removeprefix("spell."), {})
                    renamed = [c for c in selection.get("clips", []) if c.startswith(clip + "/")]
                    matching = [c["clip"] for c in selection.get("staging", {}).get("cues", []) if c.get("role") == cue["role"] and c.get("clip") in clips]
                    clip = renamed[0] if len(renamed) == 1 else matching[0] if len(matching) == 1 else clip
                cue["resolved_clip"] = clip
                required = set(clips.get(clip, {}).get("inputs", []))
                constructor = cue["constructor_input"].get("kind")
                event_channels = EVENT_PROVIDERS if constructor in {"observed_event", "creation_admission"} else set()
                if constructor == "observed_event":
                    projection = cue["constructor_input"].get("projection", "event")
                    if projection == "applied_contact":
                        event_channels = {"native_state"}
                    elif projection == "cast_completion":
                        event_channels = {"observation"}
                    elif projection == "healing_return":
                        event_channels = {"healing_input"}
                supplied = PROVIDERS | event_channels
                if constructor == "spatial_owner":
                    supplied = supplied | {"surface_presence"}
                    if cue["constructor_input"].get("cell_input") == "cells":
                        supplied = supplied | {"removed_cells"}
                if constructor == "propagation_links":
                    supplied = supplied | {"link_edges"}
                if constructor == "spell_strike":
                    supplied = supplied | {"strike_input"}
                inapplicable = qualified_input_policies(cue, clips.get(clip, {}))
                cue["declared_inputs"] = sorted(required)
                cue["provided_channels"] = sorted(required & supplied)
                cue["not_applicable_channels"] = inapplicable
                cue["missing_provider_channels"] = sorted(required - supplied - set(inapplicable))
                cue["source_present"] = clip in clips
                disabled = row["section"] == "spells" and not row["native_staging"]
                excluded = cue["source_index"] in row["excluded_cues"]
                handed_over = cue["source_index"] in row["owner_cues"] and (row["owner_kind"] == "spatial_effect" or any(s["condition"].get("body_channel_included", False) for owner in row["owner_ids"] for s in owners[owner]))
                cue["dispatch"] = "authored_disabled" if disabled else "variant_requires_actual_selector" if variant != "default" else "excluded_probe" if excluded else "owner_handover" if handed_over else "not_selected_for_event" if row["explicit_event_cues"] and cue["source_index"] not in row["event_cues"] else "explicit_gap" if cue["unbound_constructor_inputs"] else "bound_provider_gap" if cue["missing_provider_channels"] else "bound_provider_present_unqualified"
                references[clip].append({"id": row["id"], "variant": variant, "source_index": cue["source_index"], "dispatch": cue["dispatch"],
                    "provided_channels": cue["provided_channels"], "not_applicable_channels": inapplicable,
                    "missing_provider_channels": cue["missing_provider_channels"]})
        row["engine_kind"] = engine_ids.get(row["id"], "typed_only")
        row["visual_approval"] = "not_user_accepted" if row["id"] in UNACCEPTED else "not_inferred_from_source_status"
        row["scenario_coverage"] = "not_measured_by_this_offline_binding_join"
        by_id[row["id"]].append(row)
    programs = []
    for s in factory["selections"]:
        condition = s.get("condition", {})
        exact = s.get("definition_ref", {}).get("content_id")
        runtime = s.get("runtime_key", "")
        study_key = s["key"].removeprefix("divine_").removesuffix("_study")
        study = DIVINE.get(study_key) if s["key"].startswith("divine_") and s["key"].endswith("_study") else None
        ids = list(condition.get("owner_ids", [])) or ([exact] if exact in engine_ids else [runtime] if runtime in engine_ids else [study] if study else [])
        required = {i for c in s.get("clips", []) for i in clips[c].get("inputs", [])}
        programs.append({"selection": s["key"], "owner_ids": ids, "declared_runtime_key": runtime,
            "mapping": "package_condition_owner" if condition else "exact_definition_ref" if exact in engine_ids else "exact_runtime_key" if runtime in engine_ids else "documented_frozen_divine_semantics" if study else "no_authoritative_owner_mapping",
            "when": condition.get("when", {}), "clips": s.get("clips", []), "declared_inputs": sorted(required),
            "undisclosed_condition_selector_fields": sorted(set(condition.get("when", {})) - public_condition_fields),
            "semantic_gaps": DIVINE_GAPS.get(study_key, []) if study else [],
            "typed_references": [dict(ref, clip=c) for c in s.get("clips", []) for ref in references.get(c, [])],
            "package_lifecycle_enabled": bool(condition) and all(any(r["section"] == "conditions" and r["play_package_lifecycle"] for r in by_id[o]) for o in ids),
            "unsupported_declared_inputs": sorted(required - PROVIDERS - (EVENT_PROVIDERS if study else set())),
            "visual_approval": s.get("visual_approval", condition.get("visual_acceptance", "not_inferred"))})
    subjects = [{"id": identity, "engine_kind": engine_ids.get(identity, "typed_only"), "sources": by_id[identity],
        "factory_selections": [p["selection"] for p in programs if identity in p["owner_ids"]]}
        for identity in sorted(engine_ids.keys() | by_id.keys() | {o for p in programs for o in p["owner_ids"]})]
    return {"factory_version": factory["version"], "engine": engine["header"],
        "scope": "Exact static source/owner/phase/input coverage only. Provider presence is conditional and unqualified; no native draws, gameplay/scenario completeness, timing or user approval inferred. Spatial-owner package lookup does not require a second typed condition alias.",
        "counts": {"engine_ids": len(engine_ids), "typed_sources": len(typed), "subjects": len(subjects), "selections": len(programs), "clips": len(clips),
            "typed_sections": dict(Counter(r["section"] for r in typed)),
            "cue_dispatch": dict(Counter(c["dispatch"] for r in typed for c in r["effects"]))},
        "subjects": subjects, "selections": programs}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUTPUT)
    parser.add_argument("--baseline", type=Path)
    args = parser.parse_args()
    result = report()
    if args.baseline:
        before = json.loads(args.baseline.read_text())
        old = {s["id"]: s for s in before["subjects"]}
        def bindings(subject):
            if subject is None:
                return []
            fields = ["source", "native_staging", "play_package_lifecycle", "owner_kind", "owner_ids", "owner_cues", "excluded_cues", "explicit_event_cues", "event_cues"]
            cue_fields = ["clip", "selection", "role", "scope", "at", "constructor_input", "unbound_constructor_inputs"]
            return [dict({k: row[k] for k in fields}, effects=[{k: cue[k] for k in cue_fields} for cue in row["effects"]],
                variants=[{"id": v["id"], "effects": [{k: cue[k] for k in cue_fields} for cue in v["effects"]]} for v in row["variants"]]) for row in subject["sources"]]
        result["delta"] = [{"id": s["id"], "before": old.get(s["id"]), "after": s} for s in result["subjects"] if bindings(s) != bindings(old.get(s["id"]))]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({"counts": result["counts"], "changed_ids": len(result.get("delta", [])), "output": str(args.out)}))


if __name__ == "__main__":
    main()
