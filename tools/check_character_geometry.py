"""Numeric intake proof for the exact native outfit and bounded swap sources."""
import json
from pathlib import Path
import numpy as np
from PIL import Image


def main():
    project = Path(__file__).resolve().parents[1]
    root = Path('/mnt/c/Users/tommaso/Documents/assets/fantasy-unified-catalog/modular-character-geometry-2026-10-11/full-components')
    media = Path('/home/tommaso/Dev/NDClient/.media')
    catalog = json.loads((project / 'generated/character_geometry.json').read_text())['records']
    cases = json.loads((project / 'generated/character_geometry_cases.json').read_text())
    checks, failures, sheets, samples = 0, [], [], []

    def check(condition, message):
        nonlocal checks
        checks += 1
        if not condition:
            failures.append(message)

    for source_path in cases['sources']:
        record = catalog[source_path]
        parent = (root / record['reference']).parent
        rgba = np.asarray(Image.open(media / source_path.removeprefix('/media/')).convert('RGBA'))
        depth = np.asarray(Image.open(parent / 'depth.png').convert('RGBA'))
        normal = np.asarray(Image.open(parent / 'normals.png').convert('RGBA'))
        raw = np.asarray(Image.open(parent / 'raw-support.png'))
        valid = np.asarray(Image.open(parent / 'normal-valid.png'))
        with np.load(parent / 'geometry.npz') as geometry:
            visible = rgba[..., 3] > 0
            supported = visible & (raw > 0) & (valid > 0)
            check(rgba.shape == depth.shape == normal.shape == (1024,1920,4), f'{source_path}: native frame registration')
            check(np.isin(raw,[0,255]).all() and np.isin(valid,[0,255]).all(), f'{source_path}: binary masks')
            check(np.array_equal(raw>0,geometry['raw_support']) and np.array_equal(valid>0,geometry['normal_valid']), f'{source_path}: PNG/float validity agreement')
            check(not ((valid>0)&(raw==0)).any(), f'{source_path}: valid subset of support')
            check(np.array_equal(depth[...,3],raw) and np.array_equal(normal[...,3],raw), f'{source_path}: geometry alpha remains support, not source alpha')
            check(np.array_equal(depth[...,0],depth[...,1]) and np.array_equal(depth[...,0],depth[...,2]), f'{source_path}: depth equal RGB')
            lo, hi = record['depth_range']
            decoded = lo+(depth[...,0].astype(float)-32)*(hi-lo)/192
            normals = normal[...,:3].astype(float)*2/255-1
            normals /= np.maximum(np.linalg.norm(normals,axis=-1,keepdims=True),1e-12)
            compare = (raw>0)&(valid>0)
            check(np.isfinite(geometry['camera_depth'][compare]).all() and np.isfinite(geometry['camera_normals'][compare]).all(), f'{source_path}: valid finite surface')
            maximum_depth = float(np.max(np.abs(decoded[compare]-geometry['camera_depth'][compare]),initial=0))
            maximum_normal = float(np.max(np.linalg.norm(normals[compare]-geometry['camera_normals'][compare],axis=-1),initial=0))
            check(maximum_depth <= (hi-lo)/192*.5001, f'{source_path}: depth numeric tolerance {maximum_depth}')
            check(maximum_normal < .014, f'{source_path}: linear normal decode {maximum_normal}')
            if record['category']=='NakedBody3':
                check(not geometry['solid_valid'].any() and supported.any(), f'{source_path}: translucent optical validity is not solid geometry')
            for frame in (0,6,10):
                for facing in range(8):
                    ys, xs = np.where(supported[facing*128:(facing+1)*128,frame*128:(frame+1)*128])
                    if len(xs):
                        i = len(xs)//2; x,y = int(xs[i]+frame*128), int(ys[i]+facing*128)
                        samples.append({'path':source_path,'pixel':[x,y], 'normal':normals[y,x].tolist(), 'depth':float(decoded[y,x])})
            ys, xs = np.where(visible & ~supported)
            if len(xs):
                i = len(xs)//2
                samples.append({'path':source_path,'pixel':[int(xs[i]),int(ys[i])], 'supported':False})
            sheets.append({'source':source_path,'supported':int(supported.sum()),'unsupported':int((visible&~supported).sum()),
                'maximum_depth_error':maximum_depth,'maximum_normal_error':maximum_normal})
    report = {'checks':checks,'failures':failures,'sheets':sheets,
        'scope':'Actual captured fighter/sorcerer Idle/Run/Attack1 plus declared source-only armor/shield/translucent-body swaps; all pixels checked. No physical-depth ordering claim.'}
    (project/'generated/character_geometry_numeric.json').write_text(json.dumps(report,indent=2)+'\n')
    (project/'generated/character_geometry_samples.json').write_text(json.dumps(samples,separators=(',',':'))+'\n')
    print(json.dumps({'checks':checks,'failures':failures,'sheets':len(sheets),'native_sample_pixels':len(samples)}))
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
