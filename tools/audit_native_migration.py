"""Read authored selections and recorded source provenance; never imports media.
No rendering, source selection, or runtime qualification is performed.
"""
from pathlib import Path
import argparse, collections, json

P = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--factory', type=Path, required=True)
parser.add_argument('--class-source', type=Path, required=True)
parser.add_argument('--class-records', type=Path, required=True,
                    help='Original class_media directory containing source.json and bindings.json')
parser.add_argument('--output', type=Path, default=P/'generated/native_migration_inventory.json')
args = parser.parse_args()
A = P/'authoring'
def read(path):
    return json.loads(path.read_text())
def pointer(key):
    return str(key).replace('~','~0').replace('/','~1')
def rows(value, location='', enabled=True):
    if isinstance(value, dict):
        enabled = enabled and value.get('enabled', True) is not False
        for key, child in value.items():
            yield key, child, location+'/'+pointer(key), enabled
            yield from rows(child, location+'/'+pointer(key), enabled)
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from rows(child, location+'/'+str(i), enabled)

def media_references(name, key, value, where):
    """Only declared source fields; IDs used as labels/selectors are not media.

    Additional fields are from animation.schema.json ConditionAbsenceEcho,
    DoorwayArt, ReactionMedia, StudioCancellationMedia, BodyActionMediaTrack,
    StudioMediaTrack and ConstructionPhaseMedia; world.schema.json supplies
    residue_particles. No media identity is inferred from a string's value.
    """
    scalar = key.lower().replace('_', '').endswith('assetid')
    scalar |= name == 'catalog/condition_recipes.json' and where.endswith(('/persistent/absenceEcho/back', '/persistent/absenceEcho/front'))
    scalar |= name == 'catalog/portals.json' and len(where.split('/')) == 3 and key in ('back', 'front')
    scalar |= key == 'dissipationMask' and name == 'catalog/interruptions.json' and where.startswith('/reactions/')
    scalar |= name == 'world.json' and where.startswith('/residue_particles/') and len(where.split('/')) == 3
    if scalar and isinstance(value, str):
        yield value, where
    arrays = key == 'assetIdsByCamera'
    arrays |= key in ('successByCamera', 'failureByCamera') and (name == 'catalog/interruptions.json' or name.startswith('spells/'))
    arrays |= name == 'world.json' and where.startswith('/construction_media/') and key in ('application', 'intact', 'destruction', 'removal')
    if arrays and isinstance(value, list):
        for i, asset in enumerate(value):
            if isinstance(asset, str):yield asset, where+'/'+str(i)

index = read(A/'catalog-index.json')
selected = read(A/'native_effects/index.json')['sources']
condition_media = read(A/'catalog/condition_media.json')
inline = read(A/'catalog/action_media_assets.json')
static_images={}
for parent, metadata in condition_media.items():
    for facing, image in metadata.get('images_by_facing',{}).items():
        static_images[image['asset_id']]={'source':'catalog/condition_media.json#/'+pointer(parent)+'/images_by_facing/'+pointer(facing),**image}
files = set(index['drafts'].values())
# Only authored consumers/metadata, not all 1,055 definitions or sprite rigs.
for key, value in index.items():
    if isinstance(value, str) and key not in ['rigs','creature_rigs','resources','action_media_assets','sheet_components']:
        files.add(value.split('#')[0])
references = collections.defaultdict(list)
for name in sorted(files):
    source = A/name
    if not source.is_file():
        raise FileNotFoundError('Authored inventory input absent: '+str(source))
    for key, value, where, enabled in rows(read(source)):
        for asset, at in media_references(name, key, value, where):
            references[asset].append({'source':name+'#'+at, 'enabled':enabled,
                'kind':'registration_metadata' if name=='catalog/condition_media.json' else 'authored_consumer'})

# Named metadata owners are registrations too, even if no current recipe uses
# them. Their children are not falsely reported as missing sprite banks.
for asset in condition_media:
    references[asset].append({'source':'catalog/condition_media.json#/'+pointer(asset),
                              'enabled':True,'kind':'registration_metadata'})

imported_by_asset = collections.defaultdict(list)
for id, record in selected.items():
    for asset in record.get('media_ids', []):imported_by_asset[asset].append(id)

# Exact original storage -> selected conversion -> preserved native capture.
# No name-based guessed effect/scene matches.
class_source = read(args.class_records/'source.json')
class_bindings = read(args.class_records/'bindings.json')['projectileStorage']
conversion_by_file = {row['selected']:row for row in class_source['conversions']}
class_maps = {}
for asset, storage in class_bindings.items():
    originals = set()
    for key, value, _, _ in rows(storage):
        prefix = 'game/assets/class_media/'
        if key=='file' and isinstance(value,str) and value.startswith(prefix):originals.add(value[len(prefix):])
    source_rows=[]
    for filename in sorted(originals):
        if filename not in conversion_by_file:continue
        conversion=conversion_by_file[filename]
        capture=args.class_source/'native'/Path(conversion['source']).stem/'capture.json'
        source_rows.append({'selection':filename,'native_export':conversion['source'],
            'capture_metadata':str(capture) if capture.is_file() else None,
            'capture':read(capture) if capture.is_file() else {},
            'palette':conversion.get('palette'), 'operator':conversion.get('operator'),
            'provenance':str(args.class_records/'source.json')+'#/conversions/'+str(class_source['conversions'].index(conversion))})
    if source_rows:class_maps[asset]=source_rows

factory_recipes=[]
factory_by_asset=collections.defaultdict(list)
for path in sorted((args.factory/'recipes').glob('*.json')):
    recipe=read(path)
    assets=[row['assetId'] for row in recipe.get('registeredAssets',[]) if 'assetId' in row]
    matching=sorted(set(assets)&references.keys())
    if not matching:continue
    reproduction=recipe.get('reproduction',{})
    candidates=reproduction.get('sourceCandidates',recipe.get('provenance',{}).get('sourceCandidates',[]))
    ref=str(path.relative_to(args.factory))
    factory_recipes.append({'id':recipe.get('id',path.stem),'source':str(path),
        'recipe_ref':ref, 'assets':matching,'declared_status':reproduction.get('status','not_declared'),
        'verified':reproduction.get('verified',False),'reason':reproduction.get('reason',''),
        'source_candidates':candidates,'qualification':'Declared family candidates are not exact selected counterparts.'})
    for asset in matching:factory_by_asset[asset].append(ref)
recipe_lookup={row['recipe_ref']:row for row in factory_recipes}
assets=[]
for asset in sorted(references):
    metadata=condition_media.get(asset,{})
    resolved=metadata.get('asset_id',asset)
    definition=A/'media/definitions'/(resolved+'.json')
    storage=A/'media/storage'/(resolved+'.json')
    registration={'resolved_asset_id':resolved,'definition':str(definition.relative_to(P)) if definition.is_file() else None,
                  'storage':str(storage.relative_to(P)) if storage.is_file() else None}
    if metadata.get('images_by_facing') or asset in static_images:
        registration.update(kind='authored_static_images',status='registered',source=static_images.get(asset,{}).get('source','catalog/condition_media.json#/'+pointer(asset)))
    elif resolved in inline:
        registration.update(kind='authored_particle_data',status='registered',source='catalog/action_media_assets.json#/'+pointer(resolved))
    elif definition.is_file() and storage.is_file():
        registration.update(kind='registered_media',status='registered')
    elif definition.is_file():
        registration.update(kind='sheet_definition',status='definition_present_storage_separate')
    else:
        registration.update(kind='unresolved_registration',status='not_registered_here')
    ids=imported_by_asset.get(resolved,[])
    provenance=class_maps.get(resolved,[])
    recipe_refs=sorted(set(factory_by_asset.get(asset,[])+factory_by_asset.get(resolved,[])))
    has_candidates=any(recipe_lookup[ref]['source_candidates'] for ref in recipe_refs)
    gaps=[]
    if ids: status='imported'
    elif provenance:
        status='captured_native_not_selected'
        gaps=['Select the exact captured source, original palette and clock in the existing native source index; qualify its production composition.']
    elif has_candidates:
        status='candidate_unqualified'
        gaps=['Resolve exact selected production source from recorded Factory candidates; family resemblance is not source identity.']
    elif registration['kind']=='authored_static_images':status='authored_static_images'
    elif registration['kind']=='authored_particle_data':
        status='authored_particle_data';gaps=['Retain original particle data; a native adapter requires its own explicit source mapping and qualification.']
    else:
        status='source_not_mapped';gaps=['No exact native counterpart is recorded by the inspected mappings; this does not mean the exported media is missing.']
    native={'status':status,'source_ids':ids,'exact_sources':provenance,'recipe_refs':recipe_refs}
    if ids:
        native['qualification']='Imported source presence only; consult native source requirements and current regression evidence.'
    assets.append({'asset_id':asset,'references':references[asset], 'registration':registration,'native':native,'gaps':gaps})

native_sources=[]
for id, record in selected.items():
    paths=record.get('preload_paths',[record.get('scene',record.get('script',''))])
    absent=[path for path in paths if not (P/path.removeprefix('res://')).is_file()]
    native_sources.append({'id':id,'kind':record['kind'],'media_ids':record.get('media_ids',[]),
        'phase':record.get('phase'),'original_source':record.get('source'),
        'selected_path':record.get('scene',record.get('script')),'missing_selected_paths':absent,
        'status':'source_file_missing' if absent else 'imported', 'requirements':record.get('requirements',[]),
        'qualification':record.get('qualification',''),'source':'native_effects/index.json#/sources/'+pointer(id)})
counts=collections.Counter(row['native']['status'] for row in assets)
reference_counts=collections.Counter(reference['kind'] for asset in assets for reference in asset['references'])
report={'scope':'Passive inventory of current authored media references and exact existing native intake/provenance. No new imports, source assignments, replay, rendered evidence or claim of catalog completion.',
    'inputs':{'authoring_root':str(A),'factory':str(args.factory),'class_source':str(args.class_source),'class_records':str(args.class_records),
        'factory_static_audit':str(args.factory/'research/lelu-channel-2026-10-13/source-audit/INDEX.md'),
        'condition_requirements':'generated/condition_coverage_catalog.json (produced separately by tools/condition_coverage.gd)'},
    'totals':{'authored_files':len(files),'assets':len(assets),'references':sum(len(row['references']) for row in assets),
        'authored_references':reference_counts['authored_consumer'],'registration_references':reference_counts['registration_metadata'],
        'native_status':dict(sorted(counts.items())),'imported_native_sources':len(native_sources),
        'missing_selected_files':sum(len(row['missing_selected_paths']) for row in native_sources),'factory_recipes':len(factory_recipes)},
    'assets':assets,'native_sources':native_sources,'factory_recipes':factory_recipes}
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report['totals']))
