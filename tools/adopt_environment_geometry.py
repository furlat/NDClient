"""Copy selected companions and adopt their data at existing authoring owners.

Offline, one-time intake. Colour registrations, clocks and identities are kept;
no supplier proof tree or runtime receipt interpreter is installed.
"""
import argparse
import json
from pathlib import Path
import shutil

from build_authoring import media_urls, read_index
from pydantic import TypeAdapter
from game.animation_types import AnimationData
from game.asset_types import ImageResourceSource
from game.environment_art import EnvironmentDocument
from game.world_binding_types import AssetDocument
from environment_geometry_common import Intake
from environment_geometry_devices import adopt_devices
from environment_geometry_library import adopt_library, ASSEMBLY_DOOR_STEMS, connect_assembly_authoring
from environment_layout import bank_folder

ROOT=Path(__file__).resolve().parents[1]
CATALOG=Path('/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog')
DELIVERY_NAME='environment-geometry-production-2026-10-09'


def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False)+'\n')


def active_frames(intake,row):
    for entry in row['receipt_selection']['effective']:
        selected,context=intake.read_ref(entry['reference'])
        document,_=intake.read_ref(str(context))
        if isinstance(selected,list): frames=selected
        elif 'frames_by_pose' in selected: frames=list(selected['frames_by_pose'].values())
        elif isinstance(selected.get('frames'),list): frames=selected['frames']
        elif 'views' in selected:frames=[dict(view,pose=pose,frame_index=0) for pose,view in selected['views'].items()]
        elif set(selected).issubset({'e','s','w','n'}): frames=list(selected.values())
        else: raise ValueError('Unrecognized effective frames '+entry['reference'])
        include=entry.get('frame_indices');exclude=entry.get('excluded_frame_indices',[])
        for frame in frames:
            if (include is None or frame['frame_index'] in include) and frame['frame_index'] not in exclude:
                yield frame,document,context


def bank_surfaces(intake,records,changes):
    index,_=intake.read_ref(str(intake.authoring/'environment/index.json'))
    total=0
    for row in records:
        if row['list']!='banks':continue
        identity=row['existing_id'];path=intake.authoring/index['banks'][identity]
        owner,_=intake.read_ref(str(path));owner=dict(owner)
        slots={pose:[None]*owner['frame_count'] for pose in owner['rows']}
        for frame,document,context in active_frames(intake,row):
            pose=frame['pose'];number=frame['frame_index']
            if slots[pose][number] is not None:raise ValueError(f'Duplicate active frame {identity} {pose} {number}')
            slots[pose][number]=intake.surface(frame,document,context,Path('environment')/bank_folder(identity)/'geometry')
            if not slots[pose][number].get('geometry'):raise ValueError(f'Missing adopted geometry {identity} {pose} {number}')
            total+=1
        if any(frame is None for frames in slots.values() for frame in frames):raise ValueError('Incomplete active frames '+identity)
        owner.pop('geometry_delivery',None);owner['surface_frames_by_pose']=slots
        changes[path]=owner
    return total


def resource_surfaces(intake,records,changes):
    path=intake.authoring/'assets.json';assets,_=intake.read_ref(str(path));assets=dict(assets);assets['resources']=dict(assets['resources'])
    count=0
    for row in records:
        if row['list']!='resources':continue
        identity=row['existing_id'];owner=dict(assets['resources'][identity]);surface={}
        for effective in row['receipt_selection']['effective']:
            data,context=intake.read_ref(effective['reference']);doc=data
            if 'delivery_frame' in data:
                doc,context=intake.read_ref(data['delivery'],context)
                selected=data['delivery_frame']
                matches=[f for f in doc['frames'] if f['pose']==selected['pose'] and f['frame_index']==selected['frame_index']]
                if len(matches)!=1:raise ValueError('Ambiguous resource frame '+identity)
                data={**matches[0],**{k:v for k,v in data.items() if k in ['qualification','physical_parent_resource_id','role']}}
            data={**data,'native_size':owner['native_size']}
            destination=Path(owner['path'].removeprefix('/media/')).parent/'geometry'/identity
            incoming=intake.surface(data,doc,context,destination)
            parent=data.get('physical_parent_resource_id') or data.get('receiver_inheritance',{}).get('physical_parent_resource_id')
            if parent:
                incoming['receiver']={'kind':'resource','resource_id':parent}
                incoming['roles']=[{'role':'surface_paint','source_label':data['role'],'selection':{'kind':'whole'},'receiver':incoming['receiver']}]
            elif data.get('role')=='emissive_translucent_flame_effect':
                incoming['roles']=[{'role':'emissive','source_label':data['role'],'selection':{'kind':'whole'}}]
            surface.update(incoming)
        owner.pop('geometry_delivery',None);owner.update(surface);assets['resources'][identity]=owner
        if surface.get('geometry') or surface.get('roles'):count+=1
    changes[path]=assets
    return count


def validate_staged(intake,changes):
    def read(path):return changes[path] if path in changes else intake.read_ref(str(path))[0]
    def section(location):
        filename,_,fragment=location.partition('#');value=read(intake.authoring/filename)
        for key in fragment.strip('/').split('/') if fragment else []:value=value[key]
        return value
    def assemble(filename):
        return {key:({identity:section(path) for identity,path in location.items()} if isinstance(location,dict) else section(location))
                for key,location in read(intake.authoring/filename).items()}
    environment=assemble('environment/index.json')
    EnvironmentDocument.model_validate(environment)
    AssetDocument.model_validate(changes[intake.authoring/'assets.json'])
    catalog=assemble('catalog-index.json')
    TypeAdapter(AnimationData).validate_json(json.dumps(catalog))
    for value in changes.values():
        for url in media_urls(value):
            if url not in intake.destinations and not (intake.root/'.media'/url.removeprefix('/media/')).is_file():
                raise ValueError('Uninstalled adopted media '+url)
    schemas={'environment':EnvironmentDocument.model_json_schema(mode='serialization'),
             'assets':AssetDocument.model_json_schema(mode='serialization'),
             'animation':TypeAdapter(AnimationData).json_schema(mode='serialization'),
             'ui-resources':TypeAdapter(dict[str,ImageResourceSource]).json_schema(mode='serialization')}
    for name,schema in schemas.items():
        schema['$schema']='https://json-schema.org/draft/2020-12/schema'
        changes[intake.authoring/'schemas'/f'{name}.schema.json']=schema


def prepare(root,catalog,apply=False):
    intake=Intake(root,catalog,catalog/DELIVERY_NAME)
    for line in (root/'.runtime/environment-assets/files.jsonl').read_text().splitlines():
        row=json.loads(line);intake.installed[row['source'].casefold()]='/media/'+row['payload'].removeprefix('.media/')
    records,_=intake.read_ref(str(intake.delivery/'DELIVERY_INDEX.json'));records=records['records']
    changes={}
    frames=bank_surfaces(intake,records,changes)
    resources=resource_surfaces(intake,records,changes)
    report={'bank_frames':frames,'resources_with_geometry_or_roles':resources}
    adopt_devices(intake,records,changes)
    library=adopt_library(intake,records,changes)
    environment_index_path=intake.authoring/'environment/index.json'
    environment_index=dict(intake.read_ref(str(environment_index_path))[0])
    environment_index['library']={identity:'environment/library/'+identity+'.json' for identity in library}
    changes[environment_index_path]=environment_index
    for identity,value in library.items():changes[intake.authoring/environment_index['library'][identity]]=value
    report.update(library_families=len(library),library_samples=sum(len(value['samples']) for value in library.values()))
    validate_staged(intake,changes)
    report.update(new_media_files=len(intake.copies),new_media_bytes=sum(p.stat().st_size for p in intake.copies),authoring_files=len(changes),written=apply)
    if apply:
        marker=root/'.runtime/environment-geometry/adoption.json'
        if marker.exists():raise ValueError('This adoption already completed; edit current authoring directly.')
        for url in intake.copies.values():
            if (root/'.media'/url.removeprefix('/media/')).exists():raise ValueError('Refusing to overwrite existing companion '+url)
        for source,url in intake.copies.items():
            target=root/'.media'/url.removeprefix('/media/')
            if target.exists():raise ValueError('Refusing to overwrite existing media '+str(target))
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
        for path,value in changes.items():write(path,value)
        write(root/'.runtime/environment-geometry/adoption.json',report)
    return report


def prepare_assemblies(root, apply=False):
    """Connect delivered mounts without entering completed media intake."""
    authoring = root / 'authoring'
    index = json.loads((authoring / 'environment/index.json').read_text())
    environment = read_index(authoring, 'environment/index.json')
    records = {}
    for stem in ASSEMBLY_DOOR_STEMS:
        identity = 'environment.door.' + stem.replace('-', '_')
        record_path = environment['doors'][identity]['authoring_record']
        records[identity] = json.loads((authoring / record_path).read_text())['record']
    timber = json.loads((authoring / 'environment/source-records/interiors/generated-timber-stair-flight.json').read_text())['record']
    amendments = connect_assembly_authoring(environment, records, timber)
    changes = {}
    for section, owners in amendments.items():
        for identity, value in owners.items():
            if value != environment[section][identity]:
                changes[authoring / index[section][identity]] = value
        environment[section].update(owners)
    EnvironmentDocument.model_validate(environment)
    schema = EnvironmentDocument.model_json_schema(mode='serialization')
    schema['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
    schema_path = authoring / 'schemas/environment.schema.json'
    if json.loads(schema_path.read_text()) != schema:
        changes[schema_path] = schema
    if apply:
        for path, value in changes.items():
            if path == schema_path:
                path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')
            else:
                write(path, value)
    return {'banks': len(amendments['banks']), 'doors': len(amendments['doors']),
            'library_families': len(amendments['library']), 'changed_files': len(changes),
            'written': apply}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--catalog',type=Path,default=CATALOG)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--assembly-only', action='store_true')
    args=parser.parse_args()
    result = (prepare_assemblies(args.root, args.apply) if args.assembly_only
              else prepare(args.root,args.catalog,args.apply))
    print(json.dumps(result,indent=2))
