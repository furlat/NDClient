"""Generate independent pixels by executing the original Pygame operators.

Only the named original function bodies are loaded, unchanged. This avoids
importing the obsolete game's app/runtime while retaining its actual math.
Inputs and output directory are explicit; no artwork is modified or imported.
"""

import argparse
import ast
import json
from math import pi, sin
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pygame


def original_operators(path: Path) -> dict:
    names = {"_smoothstep", "condition_body_color", "condition_body_ramp", "condition_body_outline"}
    parsed = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    definitions = [node for node in parsed.body if isinstance(node, ast.FunctionDef) and node.name in names]
    if {node.name for node in definitions} != names:
        raise ValueError("Original condition operator set is incomplete")
    future = ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0)
    module = ast.fix_missing_locations(ast.Module(body=[future, *definitions], type_ignores=[]))
    namespace = {"np": np, "pygame": pygame, "sin": sin, "pi": pi}
    exec(compile(module, str(path), "exec"), namespace)
    return namespace


def source_pixels() -> pygame.Surface:
    image = pygame.Surface((128, 128), pygame.SRCALPHA)
    colors = [(27, 143, 219), (212, 61, 39), (80, 183, 46), (137, 91, 202)]
    for x in range(128):
        for y in range(128):
            rgb = colors[(x // 8) % len(colors)]
            alpha = [64, 128, 255, 0][x // 32]
            image.set_at((x, y), (*rgb, alpha))
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--authoring", required=True, type=Path)
    parser.add_argument("--media", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    operators = original_operators(args.source)
    recipes = json.loads((args.authoring / "catalog/condition_recipes.json").read_text())
    resources = json.loads((args.authoring / "catalog/resources.json").read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    source = source_pixels()
    pygame.image.save(source, args.output / "source.png")
    cases = []
    for recipe_id in ["condition.poisoned", "condition.spell.haste", "class_feature.barbarian.raging", "class_feature.barbarian.frenzied"]:
        persistent = recipes[recipe_id]["persistent"]
        color = persistent["bodyColor"]
        coloured = operators["condition_body_color"](source, SimpleNamespace(**color))
        name = recipe_id.replace(".", "-") + "-colour"
        pygame.image.save(coloured, args.output / (name + ".png"))
        cases.append({"name": name, "kind": "colour", "recipe_id": recipe_id, "age_ms": 0, "expected": name + ".png"})
        if "bodyRamp" not in persistent:
            continue
        ramp_values = {"textureFps": 32.0, **persistent["bodyRamp"]}
        path = resources[ramp_values["texture"]]
        film = pygame.image.load(args.media / path.removeprefix("/media/"))
        for age in [0.0, 90.0, 180.0, 593.75]:
            ramp = SimpleNamespace(**ramp_values)
            strength = min(1.0, age / ramp.applicationMs)
            expected = operators["condition_body_ramp"](coloured, ramp, texture=film, cell_size=(128, 128), strength=strength, age_ms=age)
            name = recipe_id.replace(".", "-") + "-film-" + str(age)
            pygame.image.save(expected, args.output / (name + ".png"))
            cases.append({"name": name, "kind": "film", "recipe_id": recipe_id, "age_ms": age, "expected": name + ".png"})
        # Explicit external-authoring reload changes sampling rate, not clock ownership.
        ramp_values["textureFps"] = 16.0
        ramp = SimpleNamespace(**ramp_values)
        expected = operators["condition_body_ramp"](coloured, ramp, texture=film, cell_size=(128, 128), strength=1.0, age_ms=593.75)
        name = recipe_id.replace(".", "-") + "-film-fps16"
        pygame.image.save(expected, args.output / (name + ".png"))
        cases.append({"name": name, "kind": "film", "recipe_id": recipe_id, "age_ms": 593.75, "texture_fps": 16.0, "expected": name + ".png"})

    # Two real alpha layers overlap. Their internal seam must not be outlined.
    parts = []
    for rect, alpha in [(pygame.Rect(20, 12, 54, 101), 255), (pygame.Rect(53, 29, 57, 79), 128)]:
        part = pygame.Surface((128, 128), pygame.SRCALPHA)
        pygame.draw.rect(part, (49, 137, 203, alpha), rect)
        parts.append(part)
    assembled = pygame.Surface((128, 128), pygame.SRCALPHA)
    for index, part in enumerate(parts):
        pygame.image.save(part, args.output / ("part" + str(index) + ".png"))
        assembled.blit(part, (0, 0))
    pygame.image.save(assembled, args.output / "assembled.png")
    outline_values = {"alphaThreshold": 100, "opacity": .55, "pulseOpacity": .75, "periodMs": 1400.0, "onsetMs": 300.0,
                      **recipes["condition.paralyzed"]["persistent"]["bodyOutline"]}
    for age, initial in [(0.0, True), (0.0, False), (350.0, False), (1400.0, False)]:
        expected = operators["condition_body_outline"](assembled, SimpleNamespace(**outline_values), None if initial else age, quiet_age_ms=age)
        name = "outline-" + str(age) + ("-initial" if initial else "-applied")
        pygame.image.save(expected, args.output / (name + ".png"))
        cases.append({"name": name, "kind": "outline", "recipe_id": "condition.paralyzed", "age_ms": age, "initial": initial, "expected": name + ".png"})
    report = {"source": str(args.source), "operator_functions": sorted(name for name in operators if name.startswith("condition_") or name == "_smoothstep"),
              "inputs": "Unequal RGB × alpha64/128/255/0; all128 rows include chest35/48/84/94; overlapping assembled alpha parts", "cases": cases}
    (args.output / "oracle.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"cases": len(cases), "output": str(args.output), "source": str(args.source)}))


if __name__ == "__main__":
    main()
