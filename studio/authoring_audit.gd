extends RefCounted
## Offline authoring worklist. Absence is measured against real backend IDs and
## declared source slots, never against the set of animations we can draw today.
const Authoring=preload("res://presentation/authoring.gd")
const Requirements=preload("res://presentation/requirements.gd")
const SNAPSHOT="res://generated/studio_content_catalog.json"

static func _pointer(key:String)->String:
    return key.replace("~","~0").replace("/","~1")

static func _read(path:String,cache:Dictionary)->Dictionary:
    if Authoring.AbilityDocuments.owns(path):return Authoring.load_data(path,cache) if Authoring.AbilityDocuments.exists(path) else {}
    var root:String=ProjectSettings.get_setting("source_data/authoring_root")
    return Authoring.load_data(path,cache) if FileAccess.file_exists(root.path_join(path)) else {}

static func _require(entry:Dictionary,label:String,pointer:String,gap:String,reason:String,next_step:String)->void:
    entry.requirements.append({"id":entry.id+":"+pointer,"label":label,"source":pointer,
        "status":"missing" if gap in ["authoring_assignment","authoring_review"] else gap,
        "gap_kind":gap,"reason":reason,"next_step":next_step,"rendered":false})

static func _source(entry:Dictionary,value:Variant,pointer:String)->void:
    if value==null or str(value).is_empty():
        _require(entry,"Source assignment is empty",pointer,"authoring_assignment","An active authored source slot has no media identity.","Assign its source in this JSON field, or explicitly disable the component.")
    else:
        _require(entry,str(value),pointer,"unexercised","A source identity is assigned. Native mapping and renderer support are audited separately.","Inspect this source in the Native migration and Renderer gaps filters.")

static func _slots(entry:Dictionary,value:Variant,pointer:String)->void:
    if value is Array:
        for i in value.size():_slots(entry,value[i],pointer+"/"+str(i))
    elif value is Dictionary:
        if value.get("enabled",true)==false or value.get("hidden",false):
            _require(entry,"Explicitly disabled",pointer,"explicit_none","The JSON disables or hides this component.","Enable and assign it only if this capability should use it.")
            return
        for key in value:
            # These fields are source identities, not labels or condition IDs.
            if str(key).to_lower().replace("_","").ends_with("assetid"):
                _source(entry,value[key],pointer+"/"+_pointer(key))
                if value.has("whenConditions"):
                    entry.requirements[-1].when_conditions=value.whenConditions.duplicate()
                    entry.requirements[-1].unless_conditions=value.get("unlessConditions",[]).duplicate()
                    entry.requirements[-1].role=value.get("role","")
                    entry.requirements[-1].asset_id=value[key]
            elif key in ["assetIdsByCamera","successByCamera","failureByCamera"]:
                for i in 4:
                    _source(entry,value[key][i] if value[key] is Array and i<value[key].size() else null,pointer+"/"+key+"/"+str(i))
            elif key=="dissipationMask" or (key in ["back","front"] and (pointer.ends_with("/absenceEcho") or pointer.ends_with("/doorway"))):
                _source(entry,value[key],pointer+"/"+key)
            elif key in ["application","intact","destruction","removal"] and value[key] is Array and ":/construction_media/" in pointer:
                for i in value[key].size():_source(entry,value[key][i],pointer+"/"+key+"/"+str(i))
            elif key in ["clip","bodyClip","actionClip","sourceSheet"]:
                var source=pointer+"/"+_pointer(key)
                if value[key]==null or str(value[key]).is_empty():
                    _require(entry,"Active source field is empty",source,"authoring_assignment","This active component has no clip or sheet selected.","Select its authored clip or source sheet.")
                else:
                    _require(entry,("Source sheet: " if key=="sourceSheet" else "Body clip: ")+str(value[key]),source,"unexercised","This active body/layer selection is authored; disabled siblings do not erase it.","Inspect the matching timeline component and its renderer/source coverage.")
            elif key=="effectAudioCue" and not str(value[key]).is_empty():
                _require(entry,"Effect audio cue: "+str(value[key]),pointer+"/"+key,"unexercised","The selected recipe assigns this cue at its effect anchor.","Inspect the cue's source and the recorded effect crossing; assignment alone is not audible proof.")
            elif key not in ["definitionRef","relationships","sourceSockets","sourceSocketsByRig","pointsByFacing"]:
                _slots(entry,value[key],pointer+"/"+_pointer(key))

static func _recipe(entry:Dictionary,value:Dictionary,path:String,cache:Dictionary)->void:
    if value.get("disposition")=="state_only":
        _require(entry,"Explicit state-only presentation",path+"/disposition","explicit_none","The authoring explicitly selects no animation.","No VFX assignment is required by this recipe.")
        return
    _slots(entry,value,path)
    for i in value.get("previewChildCueKinds",[]).size():
        _require(entry,"Child presentation: "+str(value.previewChildCueKinds[i]),path+"/previewChildCueKinds/"+str(i),"unexercised",
            "The recipe delegates this consequence to its actual child event; disabling the wrapper's body does not disable the child.",
            "Inspect that child event's own authored tracks and missing components.")
    if entry.requirements.is_empty():
        _require(entry,"Recipe assigned",path,"unexercised","This recipe has no external media selection; its body, material or child behavior still needs occurrence coverage.","Inspect its declared body/material/child behavior; source presence is not render proof.")
    if value.has("_resource_source"):
        entry.legacy_source=path
        entry.source=value._resource_source
        for requirement in entry.requirements:
            requirement.legacy_source=requirement.source
            var relative:String=str(requirement.source).trim_prefix(path).trim_prefix("/")
            # Reuse the effective catalog's property mapping, including inherited
            # JSON fields that deliberately have no native override.
            requirement.source=Authoring.recipe_source(value,relative,cache)
            requirement.id=entry.id+":"+requirement.source
    entry.requirements.append_array(Requirements.recipe(value,path,[],cache))

static func _owners(entries:Array,path:String,family:String,cache:Dictionary,subfield:String="")->void:
    var values:Variant=_read(path,cache)
    if not subfield.is_empty():values=values.get(subfield,{})
    if not values is Dictionary:return
    for id in values:
        var source=path+":/"+(subfield+"/" if not subfield.is_empty() else "")+_pointer(id)
        var expected=Requirements.owner(family,str(id),source,values[id])
        var entry={"id":family+":"+str(id),"label":expected.label,"group":"Presentation owners · "+family.replace("_"," "),"source":source,"requirements":[expected]}
        # The operation remains visible even without an assetId/clip leaf.
        _slots(entry,values[id],source)
        entries.append(entry)

static func build(cache:Dictionary={})->Dictionary:
    var entries:Array=[]
    var index=_read("catalog-index.json",cache)
    var conditions=_read("catalog/condition_recipes.json",cache)
    var snapshot:Dictionary={}
    if FileAccess.file_exists(SNAPSHOT):snapshot=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
    var expected={}
    for definition in snapshot.get("entries",[]):expected[definition.id]=definition
    var drafts:Dictionary=index.get("drafts",{})
    for id in drafts:
        if not expected.has(id):expected[id]={"id":id,"kind":"spell","label":id}
    var actions={};var sources={}
    for file in ["body_action_recipes","attack_recipes","shove_recipes"]:
        var path:String=index.get(file,"catalog/"+file+".json")
        var recipes=_read(path,cache)
        for id in recipes:
            actions[id]=recipes[id];sources[id]=path+":/"+_pointer(id)
            if not expected.has(id):expected[id]={"id":id,"kind":"action","label":id}
    var bindings=_read("catalog/body_action_bindings.json",cache)
    var deliveries=_read("catalog/action_deliveries.json",cache)
    for id in bindings:
        if not expected.has(id):expected[id]={"id":id,"kind":"action","label":id}
    # These existing movement facts use Authoring.body's shared context instead
    # of per-command recipes. No second recipe or imaginary source is required.
    var motion={"action.move":"/walkClip","action.jump":"/jumpClip","action.traverse_connector":"/connectorProfiles"}
    var ids=expected.keys();ids.sort()
    for id in ids:
        var definition:Dictionary=expected[id]
        var kind:String=definition.kind
        if kind=="condition" and conditions.has(id):continue # detailed lifecycle inventory owns these
        var entry={"id":id,"label":definition.get("label",id),"group":"Spells" if kind=="spell" else ("Conditions" if kind=="condition" else "Actions"),
            "source":"","definition_ref":definition.get("definition_ref",{}),"requirements":[]}
        if kind=="condition":
            entry.source="catalog/condition_recipes.json:/"+_pointer(id)
            _require(entry,"No condition presentation decision",entry.source,"authoring_review",
                "The backend defines this condition, but this authoring catalog has no recipe for its identity. A spatial/item owner may already provide its visual.",
                "Assign a condition recipe or document its existing visual owner/state-only disposition; do not create duplicate VFX blindly.")
        elif kind=="spell" or drafts.has(id) or deliveries.has(id):
            var spell_id:String=deliveries.get(id,id)
            var path:String=drafts.get(id,drafts.get(spell_id,"spells/"+spell_id+".json"))
            entry.source=path+":/"
            var recipe=_read(path,cache)
            if recipe.is_empty():
                _require(entry,"No spell presentation assignment",entry.source,"authoring_review",
                    "This backend spell has no selected draft at this path. A delegated reaction/child effect may own its presentation.",
                    "Add its draft or explicitly connect the existing presentation owner, including any state-only decision.")
            else:
                if not drafts.has(id) and not drafts.has(spell_id):
                    _require(entry,"Draft is not indexed","catalog-index.json:/drafts/"+_pointer(id),"authoring_assignment","The file exists but the authoring index does not select it.","Add the existing draft path to the authoring index.")
                if recipe.get("cast",{}).is_empty():_require(entry,"No cast assignment",path+":/cast","authoring_review","The draft contains no casting presentation decision.","Select the cast presentation or document its actual reaction/child owner.")
                _recipe(entry,recipe,path+":",cache)
        elif motion.has(id):
            entry.source="catalog/movement_context.json:"+motion[id]
            _require(entry,"Shared movement presentation",entry.source,"unexercised","The production movement sampler uses this existing context.","Inspect the recorded movement/connector timeline; a separate action recipe is unnecessary.")
            var context=_read("catalog/movement_context.json",cache)
            var media_field="walkMedia" if id=="action.move" else ("jumpMedia" if id=="action.jump" else "")
            if not media_field.is_empty():_slots(entry,context.get(media_field,[]),"catalog/movement_context.json:/"+media_field)
        else:
            var source_id:String=bindings.get(id,{}).get("source_recipe",id)
            entry.source=sources.get(source_id,"catalog/body_action_recipes.json:/"+_pointer(source_id))
            if actions.has(source_id):_recipe(entry,actions[source_id],entry.source,cache)
            else:
                _require(entry,"No action presentation assignment",entry.source,"authoring_review",
                    "The backend action has no direct recipe or selected source recipe. Its children may have their own presentations.",
                    "Assign the action's presentation or explicitly declare its child/state-only behavior.")
        entries.append(entry)
    # Existing context/world owners expose source slots even when no recording
    # has exercised them. Do not inventory sprite rigs or media storage twice.
    for key in index:
        if not str(key).ends_with("_context") and key not in ["interruptions","body_release_media","entity_lifecycle_media","item_attachments"]:continue
        var path:String=index[key]
        var entry={"id":"context:"+key,"label":str(key).replace("_"," ").capitalize(),"group":"Shared effects","source":path+":/","requirements":[]}
        _slots(entry,_read(path,cache),path+":")
        entry.requirements.append_array(Requirements.context(_read(path,cache),path+":",key))
        if not entry.requirements.is_empty():entries.append(entry)
    var world=_read("world.json",cache)
    for field in ["spatial_media","concentration_media","construction_media","deposit_media"]:
        for id in world.get(field,{}):
            var pointer="world.json:/"+field+"/"+_pointer(id)
            var entry={"id":field+":"+id,"label":id,"group":"World effects · "+field.replace("_media",""),"source":pointer,"requirements":[]}
            _slots(entry,world[field][id],pointer)
            entry.requirements.append(Requirements.owner(field,id,pointer,world[field][id]))
            if field=="spatial_media":
                for trigger in world[field][id].get("contactMedia",{}):
                    entry.requirements.append(Requirements.owner("contact_media",id+"/"+trigger,pointer+"/contactMedia/"+_pointer(trigger),world[field][id].contactMedia[trigger]))
            entries.append(entry)
    # Selected owners from the original passive presentation_inventory. Each
    # owner is a worklist entry even if it has no external sprite identity.
    for definition in [
        ["world_animations","world_animation"],["devices","device"],["device_wrecks","device_wreck"],
        ["portals","portal"],
        ["body_materials","body_material"],["action_materials","action_material"],["action_intakes","action_intake"],
        ["condition_media","condition_media"],["item_attachments","item_attachment"]]:
        if index.get(definition[0]) is String:_owners(entries,index[definition[0]],definition[1],cache)
    for field in ["banks","doors","traps","props","wrecks"]:
        _owners(entries,"environment/index.json","environment_"+{"banks":"bank","doors":"door","traps":"trap","props":"prop","wrecks":"wreck"}[field],cache,field)
    for field in ["treatments","spatial_effects","residue_wall_faces","residue_particles","residue_ground","residue_surfaces","liquid_surfaces","lighting"]:
        _owners(entries,"world.json","world_"+field,cache,field)
    for key in ["forced_movement_profile","shove_feedback","number_style","badge_style","dart_style","bolt_style","action_playback_rates","relocation_actions"]:
        if not index.get(key) is String:continue
        var path:String=index[key]
        var expected_operation=Requirements.row(key,str(key).replace("_"," ").capitalize(),path+":/","unassessed","missing",[],"owner","Selected presentation policy or parameter owner; source-to-consumer coverage is separate from media availability.")
        entries.append({"id":"policy:"+key,"label":expected_operation.label,"group":"Presentation policies","source":path+":/","requirements":[expected_operation]})
    for expectation in Requirements.facts(cache):
        entries.append({"id":expectation.kind,"label":expectation.label,"group":"Received fact owners","source":expectation.source,"requirements":[expectation]})
    if snapshot.is_empty():
        entries.push_front({"id":"backend_catalog","label":"Backend definition inventory unavailable","group":"Audit inputs","source":SNAPSHOT,"requirements":[{
            "id":"backend_catalog","label":"Cannot enumerate absent recipes","source":SNAPSHOT,"status":"missing","gap_kind":"authoring_review",
            "reason":"The backend catalog snapshot is absent; only existing authored owners could be inspected.","next_step":"Run tools/studio_content_catalog.py in the engine environment.","rendered":false}]})
    var totals={"entries":entries.size(),"backend_definitions":snapshot.get("entries",[]).size(),"authoring_assignment":0,"authoring_review":0,"unexercised":0,"explicit_none":0}
    for entry in entries:
        for requirement in entry.requirements:totals[requirement.gap_kind]=totals.get(requirement.gap_kind,0)+1
    return {"entries":entries,"totals":totals,"scope":"Current schema facts, backend IDs, selected presentation owners, active authored operations and source slots. Inspection gaps, unassessed owners, renderer gaps and source availability are separate. Empty optional phases are not automatically missing. No rendering qualification, new VFX or imports."}
