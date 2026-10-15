extends RefCounted
## Condition ownership follows disclosed instance UUIDs, never a visual name.
const NativePersistent=preload("res://presentation/native_persistent.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Palette=preload("res://presentation/palette.gd")
const AudioCues=preload("res://presentation/audio_cues.gd")
const MediaSamples=preload("res://presentation/condition_media_samples.gd")
const RegisteredMedia=preload("res://presentation/registered_media.gd")
const ConditionPose=preload("res://presentation/condition_pose.gd")
const BodySurfaces=preload("res://presentation/body_surfaces.gd")

static func observe(owners: Dictionary, actors: Dictionary, at_ms: float, initial: bool=false) -> void:
    for actor_id in actors:
        var actor: Dictionary=actors[actor_id]
        var live={}
        for condition in actor.get("conditions",[]):
            var id: String=condition.condition_uuid
            live[id]=true
            if not owners.has(id):
                owners[id]={"id":id,"actor_uuid":actor_id,"start_ms":at_ms,"initial":initial,"condition":condition,"end_ms":INF}
            else:
                owners[id].condition=condition
                owners[id].end_ms=INF
            owners[id].life_state=actor.get("life_state","alive")
        for owner in owners.values():
            if owner.actor_uuid!=actor_id:continue
            owner.life_state=actor.get("life_state","alive")
            if not live.has(owner.id) and is_inf(owner.end_ms):owner.end_ms=at_ms

static func recipe(condition: Dictionary, cache: Dictionary) -> Dictionary:
    return Authoring.load_data("catalog/condition_recipes.json",cache).get(condition.get("behavior_id"),{})

static func suppressed(condition: Dictionary) -> bool:
    var state:Variant=condition.get("state")
    return state!=null and not state.get("suppression_provider_uuids",[]).is_empty()

static func fade_ms(condition: Dictionary, cache: Dictionary) -> float:
    var selected=NativePersistent.Spells.condition(str(condition.get("behavior_id","")),cache)
    return _fade_ms(recipe(condition,cache),selected,NativePersistent.Spells.condition_phases(selected),cache)

static func _fade_ms(config:Dictionary,selected:Dictionary,phases:Array,cache:Dictionary)->float:
    var persistent:Dictionary=config.get("persistent",{})
    var fade=maxf(float(persistent.get("bodyRamp",{}).get("removalMs",0)),NativePersistent.phase_fade_ms(phases))
    var media: Dictionary=Authoring.load_data("catalog/condition_media.json",cache)
    for layer in persistent.get("layers",[]):
        if layer.get("assetId","") in selected.get("lifecycle",{}).get("replaces_media",[]):continue
        var metadata:Dictionary=media.get(layer.assetId,{})
        var duration=float(metadata.get("removal_fade_ms",200))
        if metadata.get("removal_asset_id")!=null:duration=MediaSamples.duration_ms(metadata.removal_asset_id,cache)
        fade=maxf(fade,duration)
    return fade

static func native_samples(owners:Dictionary,at_ms:float,cache:Dictionary)->Array:
    return samples(owners,at_ms,cache,{},true,true)

static func samples(owners: Dictionary, at_ms: float, cache: Dictionary, activities: Dictionary={}, select_layers_now: bool=true, native_only: bool=false) -> Array:
    var result: Array=[]
    for owner_id in owners.keys():
        var owner: Dictionary=owners[owner_id]
        var config=recipe(owner.condition,cache)
        var native_selection=NativePersistent.Spells.condition(str(owner.condition.behavior_id),cache)
        var native_phases=NativePersistent.Spells.condition_phases(native_selection)
        var fade=0.0 if is_inf(owner.end_ms) else _fade_ms(config,native_selection,native_phases,cache)
        if at_ms>=owner.end_ms+fade:owners.erase(owner_id);continue
        if (config.is_empty() or config.get("disposition")=="state_only") and native_selection.is_empty(): continue
        var persistent: Dictionary=config.get("persistent",{})
        var media: Dictionary=Authoring.load_data("catalog/condition_media.json",cache)
        if suppressed(owner.condition): continue
        var age=maxf(0,at_ms-owner.start_ms)
        var alpha=1.0 if is_inf(owner.end_ms) else clampf(1-(at_ms-owner.end_ms)/maxf(.001,fade),0,1)
        var common={"id":"condition:"+owner.id,"kind":"condition","condition_uuid":owner.id,"actor_uuid":owner.actor_uuid,
            "source":"catalog/condition_recipes.json:/"+str(owner.condition.behavior_id),"source_event_uuid":"",
            "status":"available","start_ms":owner.start_ms,"absolute_start_ms":owner.start_ms,"duration_ms":owner.end_ms-owner.start_ms,
            "age_ms":age,"initial":owner.initial,"alpha":alpha,"recipe":config,"condition":owner.condition,"sample_hz":32.0}
        common.removal_age_ms=null if is_inf(owner.end_ms) else maxf(0,at_ms-owner.end_ms)
        result.append(common)
        result.append_array(NativePersistent.phase_samples(common,native_phases))
        # Keep the common owner rows through the same recipe priority/removal
        # selection below; only audio and legacy layer construction are skipped.
        if native_only:continue
        var natives: Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
        for layer in persistent.get("layers",[]):
            if layer.get("assetId","") in native_selection.get("lifecycle",{}).get("replaces_media",[]):continue
            var row=common.duplicate();row.id+=":"+layer.id;row.layer=layer;row.attachment=layer.attachment
            row.trace_keys=["condition:"+owner.id+":layer:"+str(layer.id)]
            row.metadata=media.get(layer.assetId,{})
            row.life_state=owner.get("life_state","alive")
            row.removal_age_ms=null if is_inf(owner.end_ms) else maxf(0,at_ms-owner.end_ms)
            row.source_age_ms=age if owner.initial else age-layer.get("startOffsetMs",0)+layer.get("phaseOffsetMs",0)
            row.alpha*=layer.get("opacity",1.0)
            row.selection_alpha=row.alpha
            if not owner.initial and float(layer.get("fadeInMs",0))>0:row.alpha*=clampf(row.source_age_ms/float(layer.fadeInMs),0,1)
            var source_id=""
            for id in natives:
                if layer.assetId in natives[id].get("media_ids",[]): source_id=id;break
            if not source_id.is_empty():
                row.kind="native_effect";row.source_id=source_id;row.scale=row.metadata.get("scale",.5)
                row.loop=true;row.source_duration_ms=natives[source_id].duration*1000.0
            else:
                row.kind="registered_media"
                row.media=RegisteredMedia.resolve(row.metadata.get("asset_id",layer.assetId),cache)
                row.status=row.media.status
                row.media_samples=MediaSamples.sample(row,cache)
            result.append(row)
        var audio_binding:Dictionary=Authoring.load_data("audio/bindings.json",cache).get("conditions",{}).get(owner.condition.behavior_id,{})
        if audio_binding.has("persistent") and is_inf(owner.end_ms):
            var sound=AudioCues.resolve(audio_binding.persistent.cue,common.id,0,owner.start_ms,INF,
                {"actor_uuid":owner.actor_uuid,"assignment_enabled":audio_binding.persistent.get("enabled",true),"assignment_reason":audio_binding.persistent.get("reason","audio_assignment_disabled")},cache)
            sound.assignment_source="audio/bindings.json:/conditions/"+owner.condition.behavior_id+"/persistent"
            sound.timing_source=sound.assignment_source+"/timing";sound.timing_selector=audio_binding.persistent.timing
            sound.absolute_start_ms=sound.start_ms;sound.age_ms=maxf(0,at_ms-sound.start_ms)
            if sound.timing_selector!="condition.interval":sound.status="missing";sound.reason="authored_audio_timing_unavailable"
            result.append(sound)
    # Native preparation has no output to compose when these owners supply
    # only body/legacy effects. Expiry above still runs for every owner.
    if native_only and not result.any(func(sample):return sample.get("native_spell",false)):return []
    var selected_owners={}
    var selected_recipes={}
    var actors={}
    for sample in result:
        if sample.kind=="condition":actors[sample.actor_uuid]=true
    for id in actors:
        selected_recipes[id]={}
        for sample in select_recipes(id,result):
            selected_owners[sample.condition_uuid]=true
            selected_recipes[id][JSON.stringify(sample.recipe.definitionRef,"",false)]=true
    result=result.filter(func(sample):return sample.kind=="condition" or not sample.has("condition_uuid") or selected_owners.has(sample.condition_uuid) or (sample.get("layer",{}).get("markerGroup")!=null and selected_recipes.get(sample.actor_uuid,{}).has(JSON.stringify(sample.recipe.definitionRef,"",false))))
    if native_only:return result.filter(func(sample):return sample.get("native_spell",false))
    if not select_layers_now:return result
    var layers=select_layers(result.filter(func(sample):return sample.has("layer")),at_ms,activities)
    result=result.filter(func(sample):return not sample.has("layer"))
    # Selected rear/front registrations may share one original native source.
    # Merge their witnesses only after owner/predicate/marker selection.
    var native={}
    for layer in layers:
        var key=layer.actor_uuid+":"+layer.condition_uuid+":"+layer.get("source_id","")
        if layer.kind=="native_effect" and native.has(key):native[key].trace_keys.append_array(layer.trace_keys);continue
        if layer.kind=="native_effect":native[key]=layer
        result.append(layer)
    return result

static func media_samples(row:Dictionary,cache:Dictionary)->Array:
    return MediaSamples.sample(row,cache)

static func select_layers(layers: Array, at_ms: float, activities: Dictionary={}) -> Array:
    var eligible:Array=[]
    var actors={}
    for row in layers:
        var layer:Dictionary=row.layer
        var state:Dictionary=row.condition.state if row.condition.get("state")!=null else {}
        var allowed=true
        for fields in [["whenEnergyType","energy_type"],["whenAbility","enhanced_ability"],["whenMetamagicMode","metamagic_mode"],["whenSizeChange","size_change"]]:
            if layer.get(fields[0])!=null and layer[fields[0]]!=state.get(fields[1]):allowed=false;break
        if not allowed or activities.get(row.actor_uuid,"idle") not in layer.get("activeDuring",["idle","move","jump","forced_move","attack","cast","act","hit"]):continue
        if row.get("life_state","alive") not in layer.get("lifeStates",["alive","dying","stable","dead"]):continue
        if row.get("selection_alpha",row.alpha)<=0 or (not row.initial and row.age_ms<float(layer.get("startOffsetMs",0))):continue
        eligible.append(row);actors[row.actor_uuid]=true
    eligible.sort_custom(func(a,b):return a.layer.priority>b.layer.priority if a.layer.priority!=b.layer.priority else a.layer.id<b.layer.id)
    var result:Array=eligible.filter(func(row):return row.layer.get("markerGroup")==null)
    for actor in actors:
        var markers=eligible.filter(func(row):return row.actor_uuid==actor and row.layer.get("markerGroup")!=null)
        var active=markers.filter(func(row):return row.get("removal_age_ms")==null)
        if not active.is_empty():markers=active
        var groups={}
        for row in markers:
            var group:String=row.layer.markerGroup
            if not groups.has(group):groups[group]=[]
            groups[group].append(row)
        var order:Array=groups.keys()
        order.sort_custom(func(a,b):
            var left:int=groups[a].map(func(row):return row.layer.priority).max()
            var right:int=groups[b].map(func(row):return row.layer.priority).max()
            return left>right if left!=right else a<b)
        if order.is_empty():continue
        var chosen:Array=groups[order[int(maxf(0,at_ms)/1800.0)%order.size()]]
        var owner:String=chosen[0].condition_uuid
        for row in chosen:
            if str(row.condition_uuid)<owner:owner=row.condition_uuid
        var bundle={}
        for row in chosen:
            if row.condition_uuid==owner:bundle[row.layer.id]=row
        var ids:Array=bundle.keys();ids.sort()
        for id in ids:result.append(bundle[id])
    return result

static func paths(actor: Dictionary, cache: Dictionary) -> Dictionary:
    var result={}
    var resources=Authoring.load_data("catalog/resources.json",cache)
    var sources: Dictionary=Authoring.load_data("native_effects/index.json",cache).sources
    var media: Dictionary=Authoring.load_data("catalog/condition_media.json",cache)
    for condition in actor.get("conditions",[]):
        var persistent: Dictionary=recipe(condition,cache).get("persistent",{})
        var ramp: Dictionary=persistent.get("bodyRamp",{})
        if resources.has(ramp.get("texture")): result[resources[ramp.texture]]=true
        for layer in persistent.get("layers",[]):
            var native=false
            for source in sources.values():
                if layer.assetId in source.get("media_ids",[]): native=true;break
            if not native:
                var metadata:Dictionary=media.get(layer.assetId,{})
                result.merge(RegisteredMedia.resolve(metadata.get("asset_id",layer.assetId),cache).get("paths",{}))
                for field in ["application_asset_id","removal_asset_id"]:
                    if metadata.get(field)!=null:result.merge(RegisteredMedia.resolve(metadata[field],cache).get("paths",{}))
    return result

static func pose(actor: Dictionary, rig_id: String, cache: Dictionary) -> Dictionary:
    return ConditionPose.select(actor,rig_id,"idle",cache)

static func material(actor_id: String, samples: Array) -> Dictionary:
    var value={"tint":Vector3.ONE,"saturation":1.0,"brightness":1.0,"alpha":1.0,"outline":{},"ramp":{},"flash":{},"body_surfaces":BodySurfaces.compose(actor_id,samples),"time_ms":0.0}
    for sample in samples:
        if sample.get("actor_uuid")!=actor_id: continue
        if sample.kind=="material_flash":
            value.flash=sample;continue
    var has_color=false
    for sample in select_recipes(actor_id,samples):
        var persistent: Dictionary=sample.recipe.get("persistent",{})
        var color: Dictionary=persistent.get("bodyColor",{}) if persistent.get("bodyColor")!=null else {}
        if not has_color and not color.is_empty():
            value.tint=Vector3.ONE.lerp(Palette.rgb(int(color.get("tintRgb",0xffffff))),sample.alpha)
            value.saturation=lerpf(1,color.get("saturation",1),sample.alpha)
            value.brightness=lerpf(1,color.get("brightness",1),sample.alpha)
            has_color=true
        value.alpha*=lerpf(1,persistent.get("alphaMultiplier",1),sample.alpha)
        if value.outline.is_empty() and persistent.has("bodyOutline"):
            value.outline=persistent.bodyOutline;value.outline_age_ms=sample.age_ms;value.outline_initial=sample.initial;value.outline_alpha=sample.alpha
        if value.ramp.is_empty() and persistent.has("bodyRamp"):
            value.ramp=persistent.bodyRamp;value.time_ms=sample.age_ms;value.ramp_alpha=sample.alpha;value.ramp_initial=sample.initial
    return value

static func select_recipes(actor_id: String,samples: Array) -> Array:
    var distinct={}
    for sample in samples:
        if sample.get("actor_uuid")!=actor_id or sample.kind!="condition":continue
        var key=JSON.stringify(sample.recipe.get("definitionRef",{}),"",false)
        if not distinct.has(key) or sample.alpha>distinct[key].alpha:distinct[key]=sample
    var ordered: Array=distinct.values()
    ordered.sort_custom(func(a,b):
        var left: Dictionary=a.recipe.get("composition",{});var right: Dictionary=b.recipe.get("composition",{})
        return left.get("priority",0)>right.get("priority",0) if left.get("priority",0)!=right.get("priority",0) else a.source<b.source)
    var exclusive={};var count={};var result: Array=[]
    for sample in ordered:
        var composition: Dictionary=sample.recipe.get("composition",{})
        var group: String=composition.get("group","")
        var unique: Variant=composition.get("exclusiveGroup")
        if unique!=null and exclusive.has(unique):continue
        if count.get(group,0)>=composition.get("maxLayers",3):continue
        if unique!=null:exclusive[unique]=true
        count[group]=count.get(group,0)+1;result.append(sample)
    return result

static func bind(material: ShaderMaterial, value: Dictionary, textures: Dictionary, resources: Dictionary) -> void:
    bind_parameters(material,parameters(value,textures,resources))

static func bind_parameters(material:ShaderMaterial,values:Dictionary)->void:
    for field in values:material.set_shader_parameter(field,values[field])

static func parameters(value:Dictionary,textures:Dictionary,resources:Dictionary)->Dictionary:
    # One actor's layers consume these exact uniforms. Keep source/provenance
    # metadata outside the material key and project the shared operands once.
    var surfaces:Dictionary=value.get("body_surfaces",{})
    var result:Dictionary={"body_surface_enabled":false,"body_surface_count":0,"body_surface_texture":null} if surfaces.is_empty() else surfaces.parameters.duplicate()
    result.condition_tint=value.tint
    result.condition_saturation=value.saturation
    result.condition_brightness=value.brightness
    result.condition_alpha=value.alpha
    var flash: Dictionary=value.flash
    var treatment:Dictionary=flash.get("material",{})
    var strength=0.0 if flash.is_empty() else clampf(1-flash.age_ms/maxf(1,flash.duration_ms),0,1)
    if not flash.is_empty() and treatment.get("envelope","")=="hold_fade":
        var hold=float(treatment.get("holdMs",0.0))
        strength=1.0-smoothstep(hold,maxf(hold+.001,flash.duration_ms),flash.age_ms)
    result.flash_strength=strength
    var native_surface:Texture2D=flash.get("native_surface")
    result.native_body_enabled=native_surface!=null
    result.native_body_strength=strength if native_surface!=null else 0.0
    result.native_body_surface=native_surface
    var finishing:Dictionary=flash.get("native_finishing",{})
    result.native_body_ramp=flash.get("native_ramp")
    result.native_body_ramp_count=finishing.get("ramp",[]).size()
    var finishing_parameters:Dictionary=finishing.get("parameters",{})
    result.native_body_ramp_floor=finishing_parameters.get("ramp_floor",0.0)
    result.native_body_ramp_ceiling=finishing_parameters.get("ramp_ceiling",1.0)
    result.native_body_ramp_uses_luma=finishing_parameters.get("ramp_uses_luma",false)
    var flash_palette:Dictionary=treatment.get("palette",{})
    var noise:String=resources.get(flash_palette.get("noiseSheet"),"")
    result.flash_has_noise=not noise.is_empty() and textures.has(noise)
    if textures.has(noise):result.flash_noise=textures[noise]
    result.flash_gamma=float(flash_palette.get("gamma",1.0))
    result.flash_screen_blend=treatment.get("blendMode","")=="screen"
    result.flash_untinted=flash_palette.get("untinted",false)
    result.flash_frame=float(flash.get("age_ms",0.0))*.012
    var colors=PackedVector3Array()
    for color in flash.get("colors",[]): colors.append(Palette.rgb(int(color)))
    result.flash_palette_count=mini(32,colors.size());colors.resize(32)
    result.flash_palette=colors
    var ramp: Dictionary=value.ramp
    var path: String=resources.get(ramp.get("texture"),"")
    result.condition_film_enabled=ramp.get("mapping")=="flowing_film" and textures.has(path)
    if ramp.get("mapping")=="flowing_film" and textures.has(path):
        result.condition_film=textures[path]
        result.condition_film_frames=int(ramp.textureFrames)
        result.condition_film_frame=floori(value.time_ms/1000.0*ramp.get("textureFps",32))
        result.condition_film_gain=ramp.gain
        result.condition_film_weight=ramp.textureWeight
        result.condition_film_strength=value.get("ramp_alpha",1.0)*(1.0 if value.get("ramp_initial",false) else minf(1,value.time_ms/maxf(1,ramp.get("applicationMs",0))))
        var palette=PackedVector3Array()
        for color in ramp.colors: palette.append(Palette.rgb(int(color)))
        palette.resize(4);result.condition_film_palette=palette
    return result
