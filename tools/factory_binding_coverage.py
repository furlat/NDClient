"""Offline exact-ID join of typed bindings, the installed Factory and engine IDs.

Reads TRES source properties without loading Godot, artwork or native programs.
Provider presence is not a claim of event coverage, pixels or user acceptance.
This ability-source join covers spells/actions/conditions; canonical Ground
programs are inspected by the Studio source/capability inventory separately.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "generated/reports/factory-binding-completion.json"
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
PROVIDERS = set("root_path owner_state owner_visibility targets live_endpoints recipient_geometry entity_geometry source_geometry actor_context history_state actor_layers treatment_state appearance_provider weapon_binding pose_provider admitted_cells binding_owners delivery_timing owner_projection activation_projection owner_binding actual_owner_state item_snapshot created_item_identity reaction_observation interrupted_presentation interrupted_path".split())
EVENT_PROVIDERS = {"event_input", "lease_input"}
# Exact channels projected by ApplicationResults; conditional provider presence
# remains separate from any original recording supplying the required operands.
EVENT_PROJECTIONS = {
    "applied_contact": {"native_state"},
    "cast_completion": {"observation"},
    "healing_return": {"healing_input"},
    "owned_fire_contact": {"contact_event"},
    "finite_contact": {"damage_event"},
    "divine_outcome": {"observation"},
    "condition_set_outcome": {"observation"},
    "immediate_blast": {"blast_event"},
    "retired_payload_blast": {"blast_event"},
    "condition_contact": {"native_state"},
    "spatial_contact": set(),
    "condition_outcome": set(),
    "owner_activity": {"owner_input"},
    "prismatic_outcomes": set(),
    "breath_grant": {"grant_state"},
    "breath_exhale": {"grant_state"},
    "weapon_component": {"strike_input"},
    "quarry_application": {"owner_input", "quarry_input"},
    "accepted_area_blast": {"blast_event"},
    "portable_payload_blast": {"observed_explosion"},
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
    typed_dictionary = re.fullmatch(r"Dictionary\[[^\]]+\]\((.*)\)", raw, re.S)
    if typed_dictionary:
        raw = typed_dictionary[1]
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
    external = {re.search(r'\bid="([^"]+)"', head)[1]: re.search(r'\bpath="([^"]+)"', head)[1]
                for head in blocks if head.startswith("[ext_resource")}
    def cues(raw):
        result = []
        for identity in re.findall(r'SubResource\("([^"]+)"\)', raw or ""):
            fields = sub[identity]
            phase = re.fullmatch(r'ExtResource\("([^"]+)"\)', fields.get("source_phase", ""))
            result.append({"clip": value(fields.get("clip"), ""), "selection": value(fields.get("selection"), ""),
                "role": value(fields.get("role"), ""), "scope": value(fields.get("scope"), ""),
                "at": value(fields.get("at"), ""), "constructor_input": value(fields.get("constructor_input"), {}),
                "source_phase": external.get(phase[1], "") if phase else "",
                "source_inputs": value(fields.get("source_inputs"), {}),
                "source_seekable": value(fields.get("source_seekable"), False),
                "input_arguments": value(fields.get("input_arguments"), {}),
                "when": value(fields.get("when"), value(fields.get("extra"), {}).get("when", {})),
                "condition_response": value(fields.get("condition_response"), {}),
                "incoming_track": value(fields.get("incoming_track"), {}),
                "item_effect_behavior_id": value(fields.get("item_effect_behavior_id"), ""),
                "input_policies": value(fields.get("extra"), {}).get("input_policies", {}),
                "membership_input": value(fields.get("extra"), {}).get("membership_input", ""),
                "authored_suppressed": value(fields.get("extra"), {}).get("authored_suppressed"),
                "unbound_constructor_inputs": value(fields.get("unbound_constructor_inputs"), []),
                "source_index": len(result), "source_resource": str(path.relative_to(ROOT)) + "::" + identity})
        return result
    row = {"id": value(root["id"]), "section": section, "source": str(path.relative_to(ROOT)),
        "status": value(root.get("status"), "ready" if section == "conditions" else "missing"),
        "disposition": value(root.get("disposition"), ""), "native_staging": value(root.get("native_staging"), False),
        "play_package_lifecycle": value(root.get("play_package_lifecycle"), True),
        "lifecycle_selections": value(root.get("lifecycle_selections"), []),
        "owner_kind": value(root.get("owner_kind"), ""), "owner_ids": value(root.get("owner_ids"), []),
        "owner_cues": value(root.get("owner_cues"), []), "excluded_cues": value(root.get("excluded_cues"), []),
        "explicit_event_cues": value(root.get("explicit_event_cues"), False),
        "event_cues": value(root.get("event_cues"), []), "effects": cues(root.get("effects")),
        "responses": cues(root.get("responses")), "variants": [],
        "other_authored_methods": {"body": "body" in root, "look": "look" in root, "poses": "poses" in root,
            "layers": "layers" in root, "appearance_layers": "appearance_layers" in root,
            "application_body": "application_body" in root, "removal_body": "removal_body" in root,
            "reaction_cast": value(root.get("reaction_cast"), ""), "plays": value(root.get("plays"), ""),
            "delivers_spell": value(root.get("delivers_spell"), ""), "effect_sources": value(root.get("effect_sources"), [])}}
    for identity in re.findall(r'SubResource\("([^"]+)"\)', root.get("variants", "")):
        fields = sub[identity]
        row["variants"].append({"id": value(fields.get("id"), ""), "kind": value(fields.get("kind"), ""),
            "selection": value(fields.get("selection"), ""), "when": value(fields.get("when"), {}),
            "save_effect_id": value(fields.get("save_effect_id"), ""),
            "override_owner_cues": value(fields.get("override_owner_cues"), False),
            "owner_cues": value(fields.get("owner_cues"), []),
            "dispatch_gap": value(fields.get("dispatch_gap"), ""), "effects": cues(fields.get("effects"))})
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
    descriptor = cue.get("constructor_input", {})
    repeated = descriptor.get("behavior_id") == "action.spell.vampiric_touch.strike" \
        and descriptor.get("owner_condition_id") == "condition.spell.vampiric_touch"
    reason = "accepted_repeat_impact_does_not_consume_healing_condition_tick_inputs" if repeated else "first_cast_impact_does_not_consume_owner_or_repeat_inputs"
    names = ("healing_input", "condition_input", "tick_input") if repeated else ("owner_input", "healing_input", "condition_input", "tick_input")
    policies = {name: {"mode": "not_applicable", "reason": reason} for name in names}
    if clip.get("clip_id") != "bg3-36/vampiric-touch/vampiric_touch_native/impact" or cue.get("input_policies") != policies:
        return {}
    if descriptor.get("component_path") != ["owned_contact"] or not (repeated or descriptor.get("behavior_id") == "spell.vampiric_touch"):
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
    condition_selections = {s["key"]: s for s in factory["selections"] if s.get("condition")}
    standalone = json.loads((ROOT / "assets/vfx/format/speed-completion-20261021-source-resources.json").read_text()).get("resources", [])
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
        lifecycles = {s["key"]: s for s in owners[row["id"]]} if row["section"] == "conditions" else {}
        row["unresolved_lifecycle_selections"] = []
        for key in row["lifecycle_selections"]:
            if key not in condition_selections:
                row["unresolved_lifecycle_selections"].append(key)
            elif row["section"] == "conditions" and key not in lifecycles:
                lifecycles[key] = condition_selections[key]
        row["factory_lifecycles"] = [{"selection": s["key"], "owner_kind": s["condition"].get("owner_kind"),
            "assignment": "typed_explicit_selection" if s["key"] in row["lifecycle_selections"] else "package_owner_membership",
            "when": s["condition"].get("when", {}), "phases": s["condition"].get("phases", {})}
            for s in lifecycles.values()]
        for variant, collection, cues in [("default", "effects", row["effects"]), ("default", "responses", row["responses"])] + [(v["id"], "effects", v["effects"]) for v in row["variants"]]:
            variant_record = next((v for v in row["variants"] if v["id"] == variant), {})
            variant_gap = variant_record.get("dispatch_gap", "") or ("public_fact_predicate_not_authored" if variant != "default" and not variant_record.get("when") else "")
            for cue in cues:
                clip = cue["clip"]
                if clip not in clips:
                    selection = selections.get(cue["selection"] or row["id"].removeprefix("spell."), {})
                    renamed = [c for c in selection.get("clips", []) if c.startswith(clip + "/")]
                    matching = [c["clip"] for c in selection.get("staging", {}).get("cues", []) if c.get("role") == cue["role"] and c.get("clip") in clips]
                    clip = renamed[0] if len(renamed) == 1 else matching[0] if len(matching) == 1 else clip
                cue["resolved_clip"] = clip
                source_record = clips.get(clip, {})
                if cue["source_phase"]:
                    matches = [r for r in standalone if r["phase"] == cue["source_phase"]]
                    phase_path = ROOT / cue["source_phase"].removeprefix("res://")
                    phase_fields = properties(phase_path.read_text().split("[resource]", 1)[1]) if phase_path.is_file() else {}
                    source_record = {"inputs": list(cue["source_inputs"])} if len(matches) == 1 and cue["source_inputs"] and value(phase_fields.get("clip_id")) == matches[0]["clip_id"] else {}
                required = set(source_record.get("inputs", []))
                constructor = cue["constructor_input"].get("kind")
                event_channels = EVENT_PROVIDERS if constructor in {"observed_event", "creation_admission"} else set()
                if constructor == "observed_operation":
                    event_channels = {"operation_state"}
                if constructor == "observed_event":
                    projection = cue["constructor_input"].get("projection", "event")
                    event_channels = EVENT_PROJECTIONS.get(projection, EVENT_PROVIDERS)
                if constructor == "payload_release":
                    event_channels = {"accepted_release"}
                if cue["input_arguments"]:
                    event_channels = event_channels | set(cue["input_arguments"])
                supplied = PROVIDERS | event_channels
                if constructor == "spatial_owner":
                    cell_input = cue["constructor_input"].get("cell_input")
                    if cell_input in {"owned_field", "wall_geometry", "partitioned_surface"}:
                        supplied = supplied | {"owner_state"}
                    if cell_input == "wall_geometry":
                        supplied = supplied | {"zone_geometry"}
                    elif cell_input == "partitioned_surface":
                        supplied = supplied | {"surface_partition"}
                    elif cell_input == "owned_cells":
                        supplied = supplied | {"retirement_time"}
                    supplied = supplied | {"surface_presence"}
                    if cue["constructor_input"].get("cell_input") == "cells":
                        supplied = supplied | {"removed_cells"}
                    elif cue["constructor_input"].get("cell_input") == "surface_groups":
                        supplied = supplied | {"surface_records"}
                    elif cue["constructor_input"].get("cell_input") == "surface_state":
                        supplied = supplied | {"surface_state"}
                if row["section"] == "conditions" and cue["membership_input"]:
                    supplied = supplied | {cue["membership_input"]}
                if cue["authored_suppressed"] is not None:
                    supplied = supplied | {"suppressed"}
                if constructor in {"propagation_links", "area_links"} or cue["constructor_input"].get("packet") == "electric_network":
                    supplied = supplied | {"link_edges"}
                if constructor == "spell_strike":
                    supplied = supplied | {"strike_input"}
                    if cue["constructor_input"].get("owner_condition_id"):
                        supplied = supplied | {"owner_input"}
                inapplicable = {name: policy["reason"] for name, policy in cue["input_policies"].items()
                                if policy.get("mode") == "not_applicable" and policy.get("reason")}
                cue["source_checked_input_policies"] = qualified_input_policies(cue, source_record)
                cue["declared_inputs"] = sorted(required)
                cue["provided_channels"] = sorted(required & supplied)
                cue["not_applicable_channels"] = inapplicable
                cue["missing_provider_channels"] = sorted(required - supplied - set(inapplicable))
                cue["provider_evidence"] = "static_channel_match_only_no_original_operand_or_runtime_readiness_proof"
                cue["source_present"] = bool(source_record)
                disabled = row["section"] == "spells" and not row["native_staging"]
                excluded = collection == "effects" and cue["source_index"] in row["excluded_cues"]
                owner_cues = variant_record.get("owner_cues", []) if variant_record.get("override_owner_cues", False) else row["owner_cues"]
                handed_over = collection == "effects" and cue["source_index"] in owner_cues and (row["owner_kind"] == "spatial_effect" or any(s["condition"].get("body_channel_included", False) for owner in row["owner_ids"] for s in owners[owner]))
                cue["dispatch"] = "authored_disabled" if disabled else variant_gap if variant != "default" and variant_gap else "excluded_probe" if excluded else "owner_handover" if handed_over else "not_selected_for_event" if collection == "effects" and row["explicit_event_cues"] and cue["source_index"] not in row["event_cues"] else "explicit_gap" if cue["unbound_constructor_inputs"] else "source_not_resolved" if not cue["source_present"] else "provider_not_statically_matched" if cue["missing_provider_channels"] else "bound_provider_present_unqualified"
                cue["variant_when"] = variant_record.get("when", {})
                references[clip].append({"id": row["id"], "variant": variant, "collection": collection, "source_index": cue["source_index"], "source_resource": cue["source_resource"], "dispatch": cue["dispatch"],
                    "unbound_constructor_inputs": cue["unbound_constructor_inputs"], "dispatch_gap": variant_gap,
                    "provided_channels": cue["provided_channels"], "not_applicable_channels": inapplicable,
                    "missing_provider_channels": cue["missing_provider_channels"]})
        row["engine_kind"] = engine_ids.get(row["id"], "typed_only")
        row["visual_approval"] = "needs_review"
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
        typed_references = [dict(ref, clip=c) for c in s.get("clips", []) for ref in references.get(c, [])]
        programs.append({"selection": s["key"], "owner_ids": ids, "declared_runtime_key": runtime,
            "mapping": "package_condition_owner" if condition else "exact_definition_ref" if exact in engine_ids else "exact_runtime_key" if runtime in engine_ids else "documented_frozen_divine_semantics" if study else "no_authoritative_owner_mapping",
            "when": condition.get("when", {}), "clips": s.get("clips", []), "declared_inputs": sorted(required),
            "undisclosed_condition_selector_fields": sorted(set(condition.get("when", {})) - public_condition_fields),
            "semantic_gaps": [{"source_resource": ref["source_resource"], "variant": ref["variant"],
                "unbound_constructor_inputs": ref["unbound_constructor_inputs"], "dispatch_gap": ref["dispatch_gap"]}
                for ref in typed_references if ref["unbound_constructor_inputs"] or ref["dispatch_gap"]],
            "typed_references": typed_references,
            "package_lifecycle_enabled": bool(condition) and all(any(r["section"] == "conditions" and r["play_package_lifecycle"] for r in by_id[o]) for o in ids),
            "unmatched_provider_channels": sorted({name for ref in typed_references for name in ref["missing_provider_channels"]}),
            "assignment": "typed_cues_present" if typed_references else "no_direct_typed_cue_reference_package_lifecycle_or_alternative_not_measured",
            "package_review_metadata": {"visual_approval": s.get("visual_approval"), "visual_acceptance": condition.get("visual_acceptance")},
            "visual_approval": "needs_review"})
    subjects = [{"id": identity, "engine_kind": engine_ids.get(identity, "typed_only"), "sources": by_id[identity],
        "factory_selections": [p["selection"] for p in programs if identity in p["owner_ids"]]}
        for identity in sorted(engine_ids.keys() | by_id.keys() | {o for p in programs for o in p["owner_ids"]})]
    return {"factory_version": factory["version"], "engine": engine["header"],
        "scope": "Exact static typed effects, variants, condition responses and delivered standalone phase assignments only. Semantic gaps come from authored unresolved inputs/dispositions, never a fixed missing-backend list. Channel matches and authored not-applicable policies do not prove original operands or runtime readiness; unmatched channels are not proof of missing public facts. Package lifecycle-only and global item/context assignments are not expanded here. All artwork needs review; original package review metadata is historical. No native draws, scenario completeness, timing or user acceptance inferred.",
        "counts": {"engine_ids": len(engine_ids), "typed_sources": len(typed), "subjects": len(subjects), "selections": len(programs), "clips": len(clips),
            "typed_sections": dict(Counter(r["section"] for r in typed)),
            "cue_dispatch": dict(Counter(c["dispatch"] for r in typed for c in r["effects"] + r["responses"] + [c for v in r["variants"] for c in v["effects"]]))},
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
            cue_fields = ["clip", "selection", "source_phase", "source_inputs", "input_arguments", "role", "scope", "at", "when", "condition_response", "constructor_input", "unbound_constructor_inputs"]
            return [dict({k: row[k] for k in fields}, lifecycle_selections=row.get("lifecycle_selections", []), effects=[{k: cue.get(k) for k in cue_fields} for cue in row["effects"]],
                responses=[{k: cue.get(k) for k in cue_fields} for cue in row.get("responses", [])],
                variants=[{"id": v["id"], "when": v.get("when", {}), "dispatch_gap": v.get("dispatch_gap", ""), "effects": [{k: cue.get(k) for k in cue_fields} for cue in v["effects"]]} for v in row["variants"]]) for row in subject["sources"]]
        result["delta"] = [{"id": s["id"], "before": old.get(s["id"]), "after": s} for s in result["subjects"] if bindings(s) != bindings(old.get(s["id"]))]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({"counts": result["counts"], "changed_ids": len(result.get("delta", [])), "output": str(args.out)}))


if __name__ == "__main__":
    main()
