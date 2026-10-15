"""Resolve projectile recipe variants and copy their selected native dependency closure.
Factory finishing profiles are retained; no sprite exports. Originals and production bindings stay intact.
"""
import argparse
import copy
import json
import re
from pathlib import Path

TEXT = {'.tscn', '.tres', '.gd', '.gdshader', '.gdshaderinc', '.json', '.obj', '.mtl'}
NAMESPACE = 'assets/native_effects/sandbox/projectiles/'


def write_changed(path, data):
    payload = data.encode() if isinstance(data, str) else data
    if not path.exists() or path.read_bytes() != payload:
        path.write_bytes(payload)


def merge(base, overlay):
    result = copy.deepcopy(base)
    for key, value in overlay.items():
        result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else copy.deepcopy(value)
    return result


def resource_paths(value):
    if isinstance(value, str) and value.startswith('res://'):
        yield value[6:]
    elif isinstance(value, dict):
        for item in value.values(): yield from resource_paths(item)
    elif isinstance(value, list):
        for item in value: yield from resource_paths(item)


def resolve(factory, relative):
    data = json.loads((factory / relative).read_text())
    clips = []
    for variant, overlay in data.get('variants', {'default': {}}).items():
        # Front/back are two exported halves of one native composition.
        if variant.endswith('_front') or variant == 'front': continue
        resolved = merge(data, overlay)
        phases = overlay.get('phase_ids', list(resolved['phases']))
        for phase in phases:
            value = resolved['phases'][phase]
            components = []
            for name in value['components']:
                component = merge(resolved['components'][name], value.get('component_overrides', {}).get(name, {}))
                if 'template' in component:
                    component = merge(json.loads((factory / component['template'][6:]).read_text()), component)
                    component.pop('template')
                component = copy.deepcopy(component)
                component['id'] = name
                source = component['input'].get('scene', '')
                # These two native donors have only particles/shaders, no player.
                if source.endswith(('/VFX_Hadouken.tscn', '/VFX_IceLance.tscn')):
                    component['input']['settings']['animation'] = ''
                    component['sandbox_correction'] = 'Factory declares Init; selected scene has no AnimationPlayer.'
                # Full native world composition, never camera-dependent export halves.
                if 'side' in component['input']: component['input']['side'] = 'full'
                components.append(component)
            clock = resolved['profiles'].get('clock', {})
            if isinstance(clock, str): clock = json.loads((factory / clock[6:]).read_text())
            hz = float(clock.get('simulation_hz', 144))
            ticks = value.get('sampling', {}).get('capture_ticks', [0, 144])
            # Keep the complete source interval, including buildup previously trimmed from sheets.
            seconds = max(ticks) / hz
            formation = [c['input']['duration_seconds'] for c in components if c['script'].endswith('/projectile_formation.gd')]
            if formation: seconds = max(formation)
            if relative.endswith('/scorching_ray.json') and phase == 'lifecycle': seconds = 1.35
            clips.append({'id': f'{Path(relative).parent.name}/{Path(relative).stem}/{variant}/{phase}',
                          'label': phase.replace('_', ' ').title() + (f' · {variant.replace("_back", "")}' if variant not in ('default', phase) else ''),
                          'phase': phase, 'variant': variant, 'source_recipe': relative,
                          'components': components, 'bindings': value['bindings'], 'emitters': value.get('emitters', []),
                          'seconds': max(.25, seconds), 'bounded_formation': bool(formation), 'simulation_hz': hz,
                          'qualification': resolved.get('artwork_status', 'Native candidate')})
    return clips


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factory', type=Path, required=True)
    args = parser.parse_args()
    factory = args.factory.resolve()
    project = Path(__file__).resolve().parents[1]
    spells = []
    for path in sorted((project / 'authoring/spells').glob('*.json')):
        data = json.loads(path.read_text())
        if data.get('projectile'): spells.append((path, data))
    additions = json.loads((project / "authoring/sandbox/projectile_additions.json").read_text())
    library = []
    for path, choreography in spells:
        name = path.stem.removeprefix('spell.')
        if name.endswith('.burst'): continue  # Child phase, not a second library spell.
        native_name = name.split('.')[0]
        source_recipe = json.loads((factory / f'recipes/spells/{native_name}.json').read_text())
        palette = source_recipe.get('profiles', {}).get('palette_pass', {})
        if isinstance(palette, str): palette = json.loads((factory / palette[6:]).read_text())
        clips = resolve(factory, f'recipes/spells/{native_name}.json')
        clips.extend(copy.deepcopy(additions['spells'].get(native_name, {}).get('clips', [])))
        family_variants = {'ice_knife': ['ice_knife_production_xyz','ice_knife_production_xyz_materials'], 'sleep': ['sleep_production_xyz']}
        for extra in family_variants.get(native_name, []):
            for clip in resolve(factory, f'recipes/spells/{extra}.json'):
                clip['label'] = 'Native layers · '+clip['variant']
                clip['optional'] = True
                clips.append(clip)
        windup = f'recipes/projectile-windups/{native_name}.json'
        if (factory / windup).exists():
            if not palette:
                palette = json.loads((factory / windup).read_text()).get('profiles', {}).get('palette_pass', {})
            for clip in resolve(factory, windup):
                clip['label'] = 'Windup'; clip['id'] += '/windup'; clips.append(clip)
        if native_name == 'fireball':
            for clip in resolve(factory, 'recipes/projectile-windups/fireball_travel.json'):
                clip['label'] = 'Travel'; clip['phase'] = 'travel'; clip['id'] += '/travel'; clips.append(clip)
        if name.endswith('.burst'): clips = [clip for clip in clips if clip['phase'] in ('impact','lifecycle')]
        for clip in clips:
            clip.update(copy.deepcopy(additions.get('clip_overrides', {}).get(clip['id'], {})))
            for component in clip['components']:
                component.update(copy.deepcopy(additions.get('component_bindings', {}).get(component['input'].get('scene'), {})))
            clip['stage'] = {'palm': 'cast', 'lifecycle': 'impact'}.get(clip['phase'], clip['phase'])
            if native_name == 'web' and clip['variant'] == 'projectile': clip['stage'] = 'travel'
            if native_name == 'poison_spray' and clip['phase'] == 'lifecycle': clip['stage'] = 'travel'
            if native_name == 'scorching_ray' and clip['phase'] == 'lifecycle':
                clip.update(stage='delivery', travel_source_seconds=.45, tail_seconds=.9,
                            carrier_property='subject')
            if native_name == 'produce_flame' and clip['phase'] in ('travel', 'impact'):
                clip['carrier_property'] = 'asset'
                clip['source_yaw_degrees'] = 90
                if clip['phase'] == 'travel': clip.update(travel_source_seconds=.45, tail_seconds=.25)
        for clip in clips:
            if clip['id'] in additions.get('native_variants', {}):
                for field in ('carrier_path','carrier_property','travel_source_seconds','tail_seconds','source_yaw_degrees'):
                    clip.pop(field, None)
                clip.update(copy.deepcopy(additions['native_variants'][clip['id']]))
        library.append({'id': name, 'title': name.replace('_', ' ').replace('.', ' · ').title(),
                        'choreography': 'res://' + str(path.relative_to(project)), 'clips': clips, 'palette': palette})
    # New capabilities are explicitly selected, not inferred from projectile
    # fields or imported wholesale merely because a Factory recipe exists.
    for batch_path in sorted((project / 'authoring/sandbox/batches').glob('*.json')):
        batch = json.loads(batch_path.read_text())
        for field in ('derived_files', 'file_patches'):
            additions[field] = merge(additions.get(field, {}), batch.get(field, {}))
        for name, specification in batch['spells'].items():
            if any(s['id'] == name for s in library):
                raise ValueError(f'Duplicate sandbox capability: {name}')
            clips = [c for source in specification['sources'] for c in resolve(factory, source)]
            selected = specification['select_clips']
            available = {c['id']: c for c in clips}
            unknown = set(selected) - available.keys()
            if unknown: raise ValueError(f'{name}: missing selected native phases {sorted(unknown)}')
            clips = [available[key] for key in selected]
            for clip in clips:
                clip.update(copy.deepcopy(specification.get('clip_overrides', {}).get(clip['id'], {})))
                clip.setdefault('stage', clip['phase'])
            for cue in specification['staging']['cues']:
                if cue['clip'] not in selected: raise ValueError(f'{name}: unselected sequence cue {cue["clip"]}')
            source = json.loads((factory / specification['sources'][0]).read_text())
            palette = specification.get('palette', source.get('profiles', {}).get('palette_pass', {}))
            if isinstance(palette, str): palette = json.loads((factory / palette[6:]).read_text())
            library.append({'id': name, 'title': name.replace('_', ' ').title(),
                            'choreography': f'res://authoring/spells/spell.{name}.json',
                            'clips': clips, 'palette': palette,
                            'staging': specification['staging'],
                            'batch': batch_path.stem, 'notes': specification.get('notes', '')})
    pending = list(resource_paths(library))
    # Choreography is already local, not an artwork dependency.
    pending = [p for p in pending if not p.startswith('authoring/')]
    seen = set(); files = []; missing = []
    globals_cache = (factory / '.godot/global_script_class_cache.cfg').read_text()
    classes = dict(re.findall(r'"class": &"([^\"]+)".*?"path": "res://([^\"]+)"', globals_cache, re.S))
    while pending:
        relative = pending.pop()
        if relative in seen: continue
        seen.add(relative)
        derived = additions['derived_files'].get(relative)
        source_root = project if derived and 'local_source' in derived else factory
        source = (source_root / (derived.get('local_source', derived.get('archive', relative)) if derived else relative)).resolve()
        source.relative_to(source_root)
        if not source.is_file():
            # Scripts also refer to directory roots and format strings. Those are
            # not files; explicit selected scene paths above own the dependencies.
            if source.suffix in TEXT or source.suffix in {'.png', '.webp', '.svg', '.jpg'}: missing.append(relative)
            continue
        target = project / NAMESPACE / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix in TEXT or derived:
            original = source.read_text()
            if source.suffix == '.json':
                registry = json.loads(original)
                if isinstance(registry, dict) and {'linux_path', 'windows_path', 'sha256'} <= registry.keys():
                    # The selected recipe owns this exact external geometry.
                    # Keep its bytes/provenance, but make the Windows sandbox
                    # independent of an old WSL worktree/network share.
                    geometry = Path(registry['linux_path'])
                    native_path = f'library/source_geometry/{source.stem}/{geometry.name}'
                    destination = project / NAMESPACE / native_path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    write_changed(destination, geometry.read_bytes())
                    seen.add(native_path)
                    files.append({'path': native_path, 'bytes': geometry.stat().st_size})
                    registry['linux_path'] = registry['windows_path'] = 'res://' + native_path
                    original = json.dumps(registry, indent=2)
            if derived:
                for old, new in derived.get('replace', {}).items(): original = original.replace(old, new)
            for patch in additions.get('file_patches', {}).get(relative, []):
                if original.count(patch['old']) != 1:
                    raise ValueError(f'Source patch must match exactly once: {relative}')
                original = original.replace(patch['old'], patch['new'])
            for dependency in re.findall(r'"([^"\n]+\.(?:tres|gdshader|gdshaderinc|png|svg))"', original):
                if not dependency.startswith('res://') and (source.parent / dependency).is_file():
                    pending.append(str((source.parent / dependency).resolve().relative_to(factory)))
            for dependency in re.findall(r'(?:preload|load|@icon)\(\s*"([^"\n]+)"', original):
                if not dependency.startswith('res://'):
                    pending.append(str((source.parent / dependency).resolve().relative_to(factory)))
            for class_name in set(re.findall(r'\bVF(?:SEL)?_[A-Za-z0-9_]+', original)):
                if class_name in classes: pending.append(classes[class_name])
            if source.suffix == '.obj':
                for material in re.findall(r'^mtllib (.+)$', original, re.M):
                    material_path = source.parent / material.strip()
                    if material_path.exists(): pending.append(str(material_path.relative_to(factory)))
                    else: original = re.sub(r'^mtllib '+re.escape(material)+r'\n?', '', original, flags=re.M)
            if source.suffix == '.mtl':
                for material in re.findall(r'^map_\w+ (.+)$', original, re.M):
                    pending.append(str((source.parent / material.strip()).resolve().relative_to(factory)))
            pending.extend(re.findall(r'res://([^"\s\)]+)', original))
            for include in re.findall(r'#include\s+"([^"\n]+)"', original):
                if not include.startswith('res://'):
                    pending.append(str((source.parent / include).resolve().relative_to(factory)))
            value = original.replace('res://', 'res://' + NAMESPACE)
            value = re.sub(r'\b(VF(?:SEL)?_[A-Za-z0-9_]+)', r'Sandbox_\1', value)
            value = re.sub(r' uid="uid://[^"]+"', '', value)
            # These two export adapters assume front/back even for full. Add the
            # explicit full-side branch in the copied adapter, never source art.
            if relative.endswith('/scorching_packet.gd'):
                value = value.replace('packet_hit.name = "AuthoredBoltContact"', '_isolate(packet_hit, {})\n\t\tpacket_hit.name = "AuthoredBoltContact"')
            if relative.endswith('/ss_demon_hand_k5.gdshader'):
                value = value.replace('float dist = vertexDistance - planeDistance;', 'float dist = (vertexDistance - planeDistance) / max(length(cutplane[2].xyz), 0.000001);')
            if relative.endswith('/GPUTrail3D.gd'):
                value = value.replace('func _get_property_list():', 'func _get_property_list() -> Array[Dictionary]:')
            if relative.endswith('/projectile_formation.gd'):
                value = value.replace('component.add_child(component.donor)', 'component.donor.name = "Source"\n\tcomponent.add_child(component.donor)')
            if relative.endswith('/approved_ice_burst.gd'):
                value = value.replace('if is_debris != (settings.material_component == "debris"):', 'if settings.get("material_component", "whole") != "whole" and is_debris != (settings.material_component == "debris"):')
            if relative.endswith('/compact_flame.gd'):
                value = value.replace('code = code.insert(at, split)', 'if side == "full": split = ""\n\t\tcode = code.insert(at, split)')
            if relative.endswith(('/scorching_packet.gd', '/base.gd', '/blessing.gd', '/bane.gd', '/protection.gd', '/sacred_beam.gd')):
                value = value.replace('code = code.insert(pos, prefix)', 'if side == "full": prefix = ""\n\t\tcode = code.insert(pos, prefix)')
            if relative.endswith('/protection.gd'):
                value = value.replace('code = code.insert(at, split)', 'if side == "full": split = ""\n\t\tcode = code.insert(at, split)')
            if relative.endswith('/control_status.gd'):
                value = value.replace('var pos=match0.get_end();code=code.insert(pos,prefix)', 'if side=="full":prefix=""\n  var pos=match0.get_end();code=code.insert(pos,prefix)')
                value = value.replace('var mark=MeshInstance3D.new();mark.mesh=mesh;', 'var mark=MeshInstance3D.new();mark.name="ControlGlyph";mark.mesh=mesh;')
            if relative.endswith('/control_glyph.gdshader'):
                value = value.replace('void fragment(){', 'void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);}\nvoid fragment(){')
            if relative.endswith('/bane.gd'):
                for axis in range(3):
                    value = value.replace(f'INV_VIEW_MATRIX[{axis}],', f'INV_VIEW_MATRIX[{axis}]*length(MODEL_MATRIX[{axis}].xyz),')
            if relative.endswith('/StatusFX/shader/streaks.gdshader') or ('/pack_binbun_godotmagicorbsvfx/' in relative and relative.endswith('/shared/shader/transparent.gdshader')):
                # The donor billboard discarded inherited units. Keep its
                # camera-facing axes and each authored model-axis length.
                for axis in range(3):
                    value = value.replace(f'MAIN_CAM_INV_VIEW_MATRIX[{axis}],',
                        f'MAIN_CAM_INV_VIEW_MATRIX[{axis}] * length(MODEL_MATRIX[{axis}].xyz),')
            if relative.endswith('/sacred_beam.gd'):
                # Keep the native descending beam's Y test, remove only the
                # fixed export camera half-space. split_world remains needed.
                value = value.replace('\t\t\t\tif (\n\t\t\t\t\tString(child.name).begins_with("inner_")',
                    '\t\t\t\tif side == "full": clip = "\\nvec3 split_world=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\\n"\n\t\t\t\tif (\n\t\t\t\t\tString(child.name).begins_with("inner_")')
            write_changed(target, value)
        else: write_changed(target, source.read_bytes())
        files.append({'path': relative, 'bytes': source.stat().st_size})
    # Rewrite native references only; choreography points at existing project data.
    for spell in library:
        spell['clips'] = json.loads(json.dumps(spell['clips']).replace('res://', 'res://' + NAMESPACE))
        spell['palette'] = json.loads(json.dumps(spell['palette']).replace('res://', 'res://' + NAMESPACE))
    output = project / 'authoring/sandbox/projectiles.json'
    write_changed(output, json.dumps({'spells': library, 'native_namespace': NAMESPACE}, indent=2) + '\n')
    (project / '.runtime/projectile-sandbox-intake.json').write_text(json.dumps({'files': files, 'unresolved': missing}, indent=2))
    print(json.dumps({'spells': len(library), 'clips': sum(len(s['clips']) for s in library), 'files': len(files), 'MiB': sum(f['bytes'] for f in files)/1024**2, 'unresolved': missing}))

if __name__ == '__main__': main()
