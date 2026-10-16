extends RefCounted
## Offline adapter for the already selected client delivery. Runtime never calls
## this file. It preserves the approved JSON selection while admitting Resources.
const Authoring=preload("res://presentation/authoring.gd")
const Feedback=preload("res://presentation/spell_feedback.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
const Definition=preload("res://presentation/resources/native_spell.gd")
const AssetMetadata=preload("res://presentation/resources/asset_metadata.gd")
const Index=preload("res://presentation/resources/native_presentation_catalog.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Requirements=preload("res://presentation/requirements.gd")

static func select(behavior_id:String,cache:Dictionary)->Dictionary:
    var entry:Dictionary=Authoring.load_data("native_effects/index.json",cache).get("spells",{}).get(behavior_id,{})
    if entry.is_empty():return {}
    var manifest:Dictionary=Authoring.load_data(entry.manifest,cache)
    var authored:Dictionary=Authoring.load_data(entry.staging,cache).spells[entry.id]
    var nested:bool=authored.has("staging")
    var original:Dictionary=authored.staging if nested else authored
    # Offline targets, probe attacks and finite demo holds are not game facts.
    var staging:Dictionary={}
    for field in ["cues","bends","light_color","light_color_source","decorative_light_multiplier","feedback_palette"]:
        if original.has(field):staging[field]=original[field].duplicate(true) if original[field] is Array or original[field] is Dictionary else original[field]
    for i in staging.get("cues",[]).size():staging.cues[i].source_index=i
    for spell in manifest.spells:
        if spell.id==entry.id:
            return {"id":entry.id,"clips":spell.clips,"palette":spell.get("palette",{}),
                "source_bounds":entry.get("source_bounds",{}),"lifecycle":entry.get("lifecycle",{}),
                "delivery":entry.get("delivery",{"scope":"single"}),
                "event_cue_indices":entry.get("event_cue_indices",[]).map(func(value):return int(value)),"explicit_event_cues":entry.has("event_cue_indices"),
                "excluded_cue_indices":entry.get("excluded_cue_indices",[]).map(func(value):return int(value)),
                "staging":staging,"source":entry.staging+":/spells/"+entry.id+("/staging" if nested else "")}
    return {}


static func definition(behavior_id:String,cache:Dictionary)->Resource:
    var selected:Dictionary=select(behavior_id,cache).duplicate(true)
    var result=Definition.new()
    result.selection=selected
    var raw:Dictionary=Authoring.spell({"behavior_id":behavior_id},cache)
    if not raw.is_empty():
        var treatment=Feedback.prepare(raw,selected.palette,selected.staging,Authoring.load_data("sandbox/feedback.json",cache))
        result.recipe=raw.duplicate(true)
        result.recipe.cast=treatment.cast
        if result.recipe.get("damage")!=null and not treatment.flash.is_empty():result.recipe.damage.hitFlash=treatment.flash
    selected.clip_by_id={}
    for clip in selected.clips:
        clip.prepared_components={}
        for component in clip.components:
            var spec:Dictionary=Variants.component_spec(component,clip)
            var path:String=Variants.path_for(spec) if Variants.supported(spec) else ""
            spec=spec.duplicate(false)
            if not path.is_empty():spec.prepared_variant_path=path
            clip.prepared_components[component.id]=spec
        selected.clip_by_id[clip.id]=clip
    var material:Dictionary=Authoring.load_data("sandbox/body_materials.json",cache).spells.get(selected.id,{})
    result.hit={"spell_id":selected.id,"definition":material,"finish_profile":selected.palette}
    if material.get("status")=="available" and selected.clip_by_id.has(material.clip):result.hit.clip=selected.clip_by_id[material.clip]
    result.requirement_source="spells/"+behavior_id+".json:"
    result.requirements=Requirements.recipe(result.recipe,result.requirement_source,["spell"],cache)
    return result

static func import_all()->Dictionary:
    var cache:Dictionary={}
    var source:Dictionary=Authoring.load_data("native_effects/index.json",cache)
    var index=Index.new()
    var schema:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Requirements.SCHEMA))
    for kind in schema["$defs"].PlayerNode.properties.fact.anyOf[0].discriminator.mapping:
        index.fact_requirements[kind]=Requirements.fact(kind)
    var revision:String=str(int(Time.get_unix_time_from_system()*1000000))
    index.revision=revision
    var directory:String="res://.derived/native-spells/"+revision
    DirAccess.make_dir_recursive_absolute(directory)
    var rows:Array=[];var assets:Array=[];var failures:Array=[]
    for behavior_id in source.spells:
        var entry:Dictionary=source.spells[behavior_id]
        var resource:Resource=definition(behavior_id,cache)
        var path:String=directory.path_join(str(entry.id)+".res")
        for clip in resource.selection.clips:
            clip.source_identity=path+":"+str(clip.id)
            clip.source_resource_paths=Factory.resource_paths(clip)
        var missing:Array=[]
        for clip in resource.selection.clips:
            for spec in clip.prepared_components.values():
                if spec.has("prepared_variant_path") and not FileAccess.file_exists(spec.prepared_variant_path):missing.append(spec.prepared_variant_path)
        if not missing.is_empty():failures.append({"spell":behavior_id,"missing_variants":missing});continue
        var error:Error=ResourceSaver.save(resource,path)
        if error!=OK:failures.append({"spell":behavior_id,"save_error":error});continue
        index.spells[behavior_id]=path
        var lifecycle:Dictionary=entry.get("lifecycle",{})
        if lifecycle.get("owner_kind","")=="condition":
            for id in lifecycle.get("owner_ids",[]):
                if not index.conditions.has(id):index.conditions[id]=behavior_id
        rows.append({"spell":behavior_id,"resource":path,"bytes":FileAccess.open(path,FileAccess.READ).get_length()})
    # Preserve each complete admitted asset, not a blood-specific projection or
    # a runtime JSON fallback. Exact comparison belongs to this offline tool.
    var metadata:Dictionary=Authoring.load_data("catalog/action_media_assets.json",cache)
    for asset_id in metadata:
        var resource=AssetMetadata.new();resource.asset_id=asset_id;resource.value=metadata[asset_id]
        var path:String=directory.path_join("asset."+asset_id+".res")
        var error:Error=ResourceSaver.save(resource,path)
        if error!=OK:failures.append({"asset":asset_id,"save_error":error});continue
        var saved:Resource=load(path)
        if saved==null or saved.asset_id!=asset_id or saved.value!=metadata[asset_id]:
            failures.append({"asset":asset_id,"error":"Native asset operands differ from admitted source"});continue
        index.asset_metadata[asset_id]=path
        assets.append({"asset":asset_id,"resource":path,"bytes":FileAccess.open(path,FileAccess.READ).get_length()})
    if failures.is_empty():
        var index_path:String=directory.path_join("index.res")
        var error:Error=ResourceSaver.save(index,index_path)
        if error==OK:
            var staged:String=Sources.CURRENT+".next"
            var marker=FileAccess.open(staged,FileAccess.WRITE)
            if marker==null:error=FileAccess.get_open_error()
            else:
                marker.store_string(index_path);marker.close()
                error=DirAccess.rename_absolute(staged,Sources.CURRENT)
        if error!=OK:failures.append({"index_publish_error":error})
    return {"spells":rows,"assets":assets,"failures":failures,"revision":revision,"scope":"Offline exact approved client spell and passive asset admission; metadata only, no artwork, scene construction or simulation."}
