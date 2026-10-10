"""Offline normalization of the delivered, explicitly selected surface records.

Only these functions interpret supplier receipts. Published authoring contains
passive source data; the application never loads these receipts.
"""
from dataclasses import dataclass, field
import json
from pathlib import Path
import struct
from environment_layout import environment_media_path

GEOMETRY_FIELDS = {'kind','basis','sourceToLocal','vertices','triangles','uvs','faceIds','sourcePolygons','normal','offset','keysByFrame','contribution','colourShare','depthRange','encoding','pixelToRayOrigin','rayDirection','restTransforms'}
IDENTITY = [[1,0,0],[0,1,0],[0,0,1]]


def inverse_transpose(m):
    a,b,c=m[0][:3];d,e,f=m[1][:3];g,h,i=m[2][:3]
    det=a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)
    if abs(det)<1e-12: raise ValueError('Singular normal transform')
    return [[(e*i-f*h)/det,(f*g-d*i)/det,(d*h-e*g)/det],
            [(c*h-b*i)/det,(a*i-c*g)/det,(b*g-a*h)/det],
            [(b*f-c*e)/det,(c*d-a*f)/det,(a*e-b*d)/det]]


def geometry_fields(value):
    return {key: child for key,child in value.items() if key in GEOMETRY_FIELDS}


def receiving_mesh(value,calibration):
    if value.get('schema')!='registered-source-domain-receiving-mesh-v1':
        return geometry_fields(value)
    # Supplier tessellation: two triangles per original material pixel, with
    # the first triangle of every cell followed by the second of every cell.
    # Recover its exact corner UVs, preserving every vertex and open aperture.
    cells=value['source_pixel_cells_xy'];triangles=value['triangles']
    if len(triangles)!=2*len(cells):raise ValueError('Incomplete source-cell mesh')
    width,height=value['original_source_canvas'];uvs=[None]*len(value['vertices'])
    ids=[]
    for index,(x,y) in enumerate(cells):
        first=triangles[index];second=triangles[index+len(cells)]
        if first[0]!=second[0] or first[2]!=second[1]:raise ValueError('Invalid source-cell triangle pair')
        for vertex,corner in zip([*first,second[2]],[(x,y),(x+1,y),(x+1,y+1),(x,y+1)]):
            uv=[corner[0]/width,corner[1]/height]
            if uvs[vertex] is not None and uvs[vertex]!=uv:raise ValueError('Inconsistent source-cell UV')
            uvs[vertex]=uv
        ids.append(f'pixel:{x}:{y}')
    if any(uv is None for uv in uvs):raise ValueError('Unregistered source-cell vertex')
    return {**geometry_fields(value),'kind':'mesh','basis':calibration['basis'],
            'uvs':uvs,'faceIds':ids+ids}


@dataclass
class Intake:
    root: Path
    catalog: Path
    delivery: Path
    copies: dict = field(default_factory=dict)
    destinations: dict = field(default_factory=dict)
    documents: dict = field(default_factory=dict)
    installed: dict = field(default_factory=dict)

    @property
    def authoring(self): return self.root/'authoring'

    def source(self, reference, context=None):
        raw=reference.split('#',1)[0]
        path=Path(raw)
        if path.is_absolute(): return path
        if raw.startswith((self.delivery.name+'/', 'a-original/', 'b-animated-versions/', 'c-new-props/', 'provenance/')):
            return self.catalog/path
        return (context.parent if context else self.delivery)/path

    def read_ref(self, reference, context=None):
        path=self.source(str(reference),context)
        if path not in self.documents: self.documents[path]=json.loads(path.read_text())
        value=self.documents[path]
        fragment=str(reference).partition('#')[2]
        for key in fragment.strip('/').split('/') if fragment else []:
            key=key.replace('~1','/').replace('~0','~')
            value=value[int(key)] if isinstance(value,list) else value[key]
        return value,path

    def existing_media(self, source):
        if source.startswith('/media/'): return source
        path=Path(source)
        if path.is_relative_to(self.root/'.media'): return '/media/'+str(path.relative_to(self.root/'.media'))
        candidate=self.installed.get(str(path).casefold())
        if candidate: return candidate
        resolved=self.source(source)
        candidate=self.installed.get(str(resolved).casefold())
        if candidate: return candidate
        target=environment_media_path(str(resolved))
        if not (self.root/'.media'/target).is_file(): raise ValueError('Uninstalled existing colour '+source)
        return '/media/'+str(target)

    def media(self, source, destination):
        source=Path(source)
        if source in self.copies: return self.copies[source]
        if not source.is_file(): raise ValueError('Missing companion '+str(source))
        target=Path(destination)/source.name
        url='/media/'+str(target)
        if url in self.destinations and self.destinations[url]!=source:
            target=Path(destination)/source.parent.name/source.name
            url='/media/'+str(target)
        if url in self.destinations and self.destinations[url]!=source:
            raise ValueError('Ambiguous companion destination '+url)
        self.destinations[url]=source;self.copies[source]=url
        return url

    def region(self, value, context, destination, size=None):
        if isinstance(value,str): value={'path':value}
        source=self.source(value['path'],context)
        rect=value.get('rect')
        if rect is None:
            with source.open('rb') as stream: header=stream.read(24)
            if header[:8]!=b'\x89PNG\r\n\x1a\n':
                if size is None:raise ValueError('Unspecified non-PNG region '+str(source))
                width,height=size
                if source.stat().st_size!=width*height:raise ValueError('Raw support byte count differs from native cell '+str(source))
            else:width,height=struct.unpack('>II',header[16:24])
            rect=[0,0,width,height]
        return {'path':self.media(source,destination),'rect':rect}

    def surface(self, frame, doc, context, destination):
        return surface(self,frame,doc,context,destination)


def sampling(region,colour_size):
    return {'scale':[region['rect'][2]/colour_size[0],region['rect'][3]/colour_size[1]],
            'offset':[0,0],'rounding':'floor','pixel_center':[.5,.5]}


def surface(intake,frame,doc,context,destination):
    """Normalize one selected frame/view; never infer frame or pose from filenames."""
    out={};pose=frame.get('pose',frame.get('source_view',frame.get('calibration_pose')))
    colour=frame.get('selected_colour',frame.get('source_colour',frame.get('colour',{})))
    colour_size=doc.get('colour_cell',frame.get('native_canvas',frame.get('native_size')))
    if isinstance(colour,dict) and colour.get('rect'): colour_size=colour['rect'][2:]
    geom_context=context
    calibration=None
    geometry=frame.get('geometry_calibration') or frame.get('geometry') or frame.get('reused_channels',{}).get('geometry') or frame.get('channels',{}).get('geometry')
    if isinstance(geometry,str): calibration,geom_context=intake.read_ref(geometry,context)
    elif isinstance(geometry,dict) and 'kind' in geometry: calibration=geometry
    elif pose in doc.get('calibration_by_pose',{}): calibration=doc['calibration_by_pose'][pose]
    if calibration is None and 'kind' in doc: calibration=doc
    if calibration is not None:
        if 'kind' not in calibration and all(key in calibration for key in ('depthRange','pixelToRayOrigin','rayDirection')):
            calibration={**calibration,'kind':'ray_depth','encoding':'rg16be_oct8_rgba8'}
        if 'kind' not in calibration: raise ValueError('Non-geometry calibration '+str(geom_context)+' keys='+str(list(calibration)))
        out['geometry']=geometry_fields(calibration)
        region=frame.get('geometry_region_native') or frame.get('geometry_region')
        if region is None and isinstance(frame.get('geometry'),dict) and 'path' in frame['geometry']: region=frame['geometry']
        if region is None and calibration.get('path'): region={'path':calibration['path'],'rect':calibration.get('source_rect')}
        if out['geometry']['kind']=='ray_depth':
            if region is None: raise ValueError('No paired geometry region '+str(context))
            reg=intake.region(region,geom_context if calibration.get('path') and not frame.get('geometry_region_native') else context,destination)
            out['geometry_region']=reg
            colour_size=colour_size or calibration.get('native_size') or reg['rect'][2:]
            mapping=sampling(reg,colour_size)
            crop=frame.get('colour_to_geometry_native')
            if crop and 'translation_before_native_lookup' in crop:
                mapping={**mapping,'scale':[1,1],'offset':crop['translation_before_native_lookup']}
            out['geometry_sampling']=mapping
            # Export-time source-to-packet transforms are already baked into BA.
            matrix=calibration.get('normalToLocal') or inverse_transpose(calibration['sourceToLocal'])
            out['normal']={'region':reg,'encoding':'oct8_ba','sampling':mapping,'normalToLocal':matrix}
        receiver=frame.get('surfaceGeometry') or calibration.get('surfaceGeometry')
        if receiver:
            value,_=intake.read_ref(receiver,geom_context) if isinstance(receiver,str) else (receiver,geom_context)
            out['receiving_geometry']=receiving_mesh(value,calibration)
        if calibration.get('qualification'): out['qualification']=calibration['qualification']
    colour_size=colour_size or doc.get('native_cell')
    if colour_size is None: raise ValueError('Missing original colour dimensions '+str(context))
    roles=[]
    def mask(value,labels=None,ctx=context):
        region=intake.region(value,ctx,destination,doc.get('native_cell') or out.get('geometry_region',{}).get('rect',[])[2:] or colour_size)
        mapped=sampling(region,colour_size)
        crop=frame.get('colour_to_geometry_native')
        if crop and 'translation_before_native_lookup' in crop and region['rect'][2:]==out.get('geometry_region',{}).get('rect',[])[2:]:
            mapped={**mapped,'scale':[1,1],'offset':crop['translation_before_native_lookup']}
        return {'region':region,'sampling':mapped,'encoding':'r8uint','channel':'r', 'labels':labels or {},'storage':'png' if region['path'].endswith('.png') else 'raw'}
    support=frame.get('support_region_native') or frame.get('support_region') or frame.get('support') or frame.get('channels',{}).get('support')
    calibration_support=support is None and calibration is not None
    if calibration_support: support=calibration.get('support') or calibration.get('materialDomain')
    if support:
        codes=doc.get('support_codes',doc.get('support_encoding',{}))
        support_context=geom_context if calibration_support else context
        if calibration_support and not calibration.get('support') and calibration.get('path'):
            support_context=intake.source(calibration['path'],geom_context)
        out['support']=mask(support,codes,support_context)
    shadow=frame.get('mask') if 'source_selector' in frame or 'source_body_mask' in frame else None
    if shadow:
        roles.append({'role':'ground_shadow','selection':{'kind':'mask','mask':mask(shadow),'values':[255]},'receiver':{'kind':'support','height_steps':0}})
    shadow_doc=frame.get('shadow_separation',doc.get('shadow_separation',{}))
    selector=frame.get('source_selector') or (shadow_doc.get('selector') if isinstance(shadow_doc,dict) else None)
    if not shadow and isinstance(selector,dict) and 'rgb_min_inclusive' in selector:
        roles.append({'role':'ground_shadow','selection':{'kind':'source_rgba','bounds':{
            'minimum':selector['rgb_min_inclusive']+[selector['alpha_min_inclusive']],
            'maximum':selector['rgb_max_inclusive']+[selector['alpha_max_inclusive']]}},'receiver':{'kind':'support','height_steps':0}})
    for key,role in [('source_body_mask','solid'),('effect_only_region','translucent'),('source_effect_presence_region','translucent'),('unmixed_material_receiver_region','solid')]:
        if frame.get(key): roles.append({'role':role,'source_label':key,'selection':{'kind':'mask','mask':mask(frame[key]),'values':[255]}})
    for label,value in frame.get('role_masks',{}).items():
        role={'solid_fragment':'solid','translucent_dust_effect':'translucent','ground_cast_shadow':'ground_shadow','material_ground_contact_return':'ground_contact','emissive_boundary_or_flame':'emissive','portal_interior_visibility_matte':'occlusion','water_surface_effect':'translucent'}.get(label)
        if role is None: raise ValueError('Unmapped role '+label+' at '+str(context))
        entry={'role':role,'source_label':label,'selection':{'kind':'mask','mask':mask(value),'values':[255]}}
        if role in ['ground_shadow','ground_contact']: entry['receiver']={'kind':'support','height_steps':0}
        roles.append(entry)
    if frame.get('role_mask'):
        labels=doc['roles'];record=mask(frame['role_mask'],labels)
        for code,label in labels.items():
            role_labels={
                'physical visible material-patch receiver, inferred coarse face':'solid',
                'physical authored source surface':'solid',
                'source physical visible member':'solid',
                'Physical actual source member/face receiving depth and source-guided normal':'solid',
                'Own actual hatch rim/lid/hinge/pit-lining visible receiver; selected layer alpha remains authoritative':'solid',
                'Actual own source physical member UV/XY; original-seeded inferred receiving geometry':'solid',
                'actual physical source fork mechanism including opaque tight-contact recess':'solid',
                'actual generated physical source component receiving geometry':'solid',
                'non-solid translucent dust opacity/density receiving envelope':'translucent',
                'non-solid H0 water/chemical pool surface receiver':'translucent',
                'non-solid green chemical visual receiving envelope':'translucent',
                'Actual source water non-solid visual receiving surface; no collision volume':'translucent',
                'source non-solid water/flame/steam visual receiver':'translucent',
                'translucent demo-vapor visual receiver; no solid/collider claim':'translucent',
                'source cast-ground shadow H0':'ground_shadow',
                'Authored source ground/contact shadow H0 non-solid receiver':'ground_shadow',
                'actual named source shadow/contact H0 receiver':'ground_shadow',
                'actual source shadow/contact visual layer; ground receiving, not object solid':'ground_shadow',
                'source authored ember/coals emissive visual receiver':'emissive',
                'source authored ember/coals non-solid visual receiver':'emissive',
                'captive emissive core, actual source surface receiving geometry retained':'emissive',
                'Authored torch flame visual receiving; preserve exact fire palette and alpha, no solid/collider claim':'emissive',
                'Source pit-darkness interior/aperture visibility matte; non-solid visual receiver, not a cap/floor/collider':'occlusion',
                'pit-darkness aperture/interior-occlusion visual receiver; not a solid cap/floor':'occlusion',
            }
            if label not in role_labels:raise ValueError('Unmapped role-mask label '+label+' at '+str(context))
            role=role_labels[label]
            roles.append({'role':role,'source_label':label,'selection':{'kind':'mask','mask':record,'values':[int(code)]}})
    for label,role_geometry in frame.get('role_geometry',{}).items():
        if label!='ground_shadow':raise ValueError('Unknown role geometry '+label)
        child={'geometry_region_native':role_geometry['geometry_region'],
               'geometry_calibration':role_geometry['geometry_calibration'],
               'native_size':colour_size,'colour_to_geometry_native':frame.get('colour_to_geometry_native')}
        sample=surface(intake,child,{},context,destination)
        roles.append({'role':'ground_shadow','source_label':label,
                      'selection':{'kind':'mask','mask':mask(role_geometry['role_mask']),'values':[role_geometry['role_code']]},
                      'receiver':{'kind':'support','height_steps':role_geometry['H_steps']},'surface':sample})
    channels=frame.get('channels',{})
    if channels.get('component_owner'):
        labels={str(index):f'spike/socket component {index}' for index in range(1,10)} if frame.get('resource_id','').startswith('spikes.') else {}
        out['component_owner']=mask(channels['component_owner'],labels)
    if channels.get('surface_roles'):
        identity=frame.get('resource_id',doc.get('resource_id',''))
        if identity.startswith('spikes.'):
            labels={'1':'socket','2':'spike'}
        elif identity=='torch.body' or 'shaft_axis_source_x' in channels.get('fit',{}):labels={'1':'shaft','2':'head'}
        elif identity.startswith('torch.wall') or 'inferred_wall_plane_camera_local' in channels.get('fit',{}):labels={'3':'wall stem','4':'wall head'}
        else:raise ValueError('Unmapped supplied surface labels '+str(context))
        record=mask(channels['surface_roles'],labels)
        for code,label in labels.items():roles.append({'role':'solid','source_label':label,'selection':{'kind':'mask','mask':record,'values':[int(code)]}})
    if roles:out['roles']=roles
    qualification=frame.get('qualification') or doc.get('geometry_qualification') or doc.get('qualification')
    if qualification:out['qualification']=qualification
    if isinstance(out.get('qualification'),list):
        out['qualification']='\n'.join(out['qualification'])
    return out
