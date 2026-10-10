"""Adopt original clean component bodies for Goblin/Demon material controls.

Keeps existing source URL/rig IDs and original combined/effect/shadow PNGs.
Only generated obsolete masks for these two families are retired.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import io
import json
from pathlib import Path
import zipfile

from PIL import Image
from pydantic import TypeAdapter
from game.animation_types import AnimationData
from game.sprite_components import SheetComponents
from build_authoring import read_catalog
from author_character_components import write_json

ROOT=Path(__file__).resolve().parents[1]
PACKS=('orcs-and-goblins','demons')


def prepare(root, workers):
    path=root/'authoring/characters/sheet-components.json'
    document=json.loads(path.read_text())
    evidence=json.loads((root/'.runtime/character-components/source-evidence.json').read_text())
    rows={r['payload']:r for r in map(json.loads,(root/'.runtime/character-assets/files.jsonl').read_text().splitlines())}
    urls=[u for u in document if any('/'+p+'/Combined/' in u for p in PACKS)]
    archives={p:zipfile.ZipFile(p) for p in {rows['.media/'+u.removeprefix('/media/')]['source'] for u in urls}}
    catalog=read_catalog(root/'authoring')
    clocks={}
    for rig in catalog['rigs'].values():
        for clip in rig['clips'].values():
            for resource in clip['sheets'].values():
                url=catalog['resources'][resource]
                clocks.setdefault(url,{'frames':clip['frames'],'fps':clip['fps']})
    def one(url):
        row=rows['.media/'+url.removeprefix('/media/')]
        source=evidence[url]['source_body'];raw=archives[row['source']].read(source)
        with Image.open(io.BytesIO(raw)) as image:size=image.size
        if size != (row['width'],row['height']):raise ValueError('Unregistered body counterpart: '+url)
        source_layers=dict(document[url]['source_layers']);effect=source_layers.get('accent');has_accent=False
        for role,layer in source_layers.items():
            with Image.open(root/'.media'/layer.removeprefix('/media/')) as image:
                if image.size!=size:raise ValueError('Unregistered source '+role+': '+url)
                if role=='accent':has_accent=image.convert('RGBA').getchannel('A').getbbox() is not None
        relative=Path(url.removeprefix('/media/smallscale/authored/'));target=Path('.media/smallscale/authored')/relative.parts[0]/'Bodies'/Path(*relative.parts[2:])
        (root/target).parent.mkdir(parents=True,exist_ok=True)
        if (root/target).exists():
            if (root/target).read_bytes()!=raw:raise ValueError('Existing body differs: '+str(target))
        else:(root/target).write_bytes(raw)
        body_url='/media/'+str(target).removeprefix('.media/');source_layers['body']=body_url
        result={'composition':{'kind':'source_interaction','has_accent':has_accent},'source_layers':source_layers}
        SheetComponents.model_validate(result)
        # Native Smallscale pack cells are 128x128, in eight facing rows.
        if size[1]!=1024 or size[0]%128:raise ValueError('Unexpected native sheet grid: '+url)
        preview={'url':url,'pack':relative.parts[0],'character':relative.parts[2],'action':relative.parts[-1].removesuffix('.png'),'width':size[0],'height':size[1],'cell':128,'frames':size[0]//128,'fps':clocks.get(url,{}).get('fps'),'hasAccent':has_accent}
        return url,result,body_url,preview,len(raw)
    previews=[];old_masks=set();added_bytes=0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for i,(url,row,body,preview,size) in enumerate(pool.map(one,urls),1):
            old=document[url]
            for field in ('selection','accent_material_mask'):
                mask=old.get(field,{}).get('mask',{})
                if mask:old_masks.add(mask['path'])
            document[url]=row;document[body]={'selection':{'kind':'whole','role':'body'}}
            previews.append(preview);added_bytes+=size
            if i%200==0:print(f'{i}/{len(urls)} source-layer sets connected',flush=True)
    for archive in archives.values():archive.close()
    catalog['sheet_components']=document
    TypeAdapter(AnimationData).validate_json(json.dumps(catalog))
    write_json(path,dict(sorted(document.items())))
    schema=TypeAdapter(AnimationData).json_schema(mode='serialization');schema['$schema']='https://json-schema.org/draft/2020-12/schema'
    write_json(root/'authoring/schemas/animation.schema.json',schema)
    write_json(root/'.runtime/character-components/controls/index.json',previews)
    retired=0
    # These are only our generated masks, not original artwork; retain any still referenced.
    serialized=json.dumps(document)
    for url in old_masks:
        if url in serialized:continue
        mask=root/'.media'/url.removeprefix('/media/')
        if not any(part in ('Component masks','Material masks') for part in mask.parts):raise ValueError('Refusing non-generated mask retirement: '+url)
        if mask.exists():mask.unlink();retired+=1
    print(json.dumps({'sheets':len(previews),'characters':len({(p['pack'],p['character']) for p in previews}),'active_effects':sum(p['hasAccent'] for p in previews),'body_source_MiB':round(added_bytes/1024**2,2),'retired_generated_masks':retired}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--workers',type=int,default=4);args=parser.parse_args();prepare(args.root,args.workers)
