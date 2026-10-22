extends RefCounted
## Offline authoring worklist. Absence is measured against real backend IDs and
## declared source slots, never against the set of animations we can draw today.
const Authoring=preload("res://presentation/authoring.gd")
const Requirements=preload("res://presentation/requirements.gd")
const Library=preload("res://studio/case_library.gd")
const SourceRoot=preload("res://presentation/source/source_root.gd")
const Effects=preload("res://presentation/effect_package.gd")
const BodySources=preload("res://presentation/body_sources.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const EventTrace=preload("res://presentation/event_trace.gd")
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

static func _slots(entry:Dictionary,value:Variant,pointer:String,cache:Dictionary={})->void:
    if value is Array:
        for i in value.size():_slots(entry,value[i],pointer+"/"+str(i),cache)
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
            elif key=="source_id" and value.has("assetId"):
                var source:String=pointer+"/source_id"
                var method:Dictionary=EventTrace.source_method(str(value[key]),cache)
                _require(entry,"Native source: "+str(value[key]),source,"unexercised",
                    "This media use selects the shared native source program. Its socket, source window and admission predicate do not establish occurrence or pixel evidence.",
                    "Inspect the actual recorded native component and its current input/readiness/output evidence.")
                var requirement:Dictionary=entry.requirements[-1]
                requirement.native_method=method;requirement.native_method.assignment_source=source
                requirement.authored_media=value.duplicate(true)
                requirement.availability=method.source_availability
                if method.source_availability=="missing":
                    requirement.status="missing";requirement.gap_kind="source"
                    requirement.reason="The explicit media source_id does not resolve to the installed native source table."
                    requirement.next_step="Restore the exact selected native source or author a compatible source assignment."
            elif key in ["assetIdsByCamera","successByCamera","failureByCamera"]:
                for i in 4:
                    _source(entry,value[key][i] if value[key] is Array and i<value[key].size() else null,pointer+"/"+key+"/"+str(i))
            elif key=="dissipationMask" or (key in ["back","front"] and (pointer.ends_with("/absenceEcho") or pointer.ends_with("/doorway"))):
                _source(entry,value[key],pointer+"/"+key)
            elif key in ["application","intact","destruction","removal"] and value[key] is Array and ":/construction_media/" in pointer:
                for i in value[key].size():_source(entry,value[key][i],pointer+"/"+key+"/"+str(i))
            elif key=="clip" and value.has("source_index") and value.has("role"):
                # Selected EffectUses have their exact source/method row below;
                # a Factory clip is not a body-animation clip or a second use.
                continue
            elif key in ["clip","bodyClip","actionClip","sourceSheet"]:
                var source=pointer+"/"+_pointer(key)
                if value[key]==null or str(value[key]).is_empty():
                    _require(entry,"Active source field is empty",source,"authoring_assignment","This active component has no clip or sheet selected.","Select its authored clip or source sheet.")
                else:
                    _require(entry,("Source sheet: " if key=="sourceSheet" else "Body clip: ")+str(value[key]),source,"unexercised","This active body/layer selection is authored; disabled siblings do not erase it.","Inspect the matching timeline component and its renderer/source coverage.")
            elif key=="effectAudioCue" and not str(value[key]).is_empty():
                _require(entry,"Effect audio cue: "+str(value[key]),pointer+"/"+key,"unexercised","The selected recipe assigns this cue at its effect anchor.","Inspect the cue's source and the recorded effect crossing; assignment alone is not audible proof.")
            elif key not in ["definitionRef","relationships","sourceSockets","sourceSocketsByRig","pointsByFacing"]:
                _slots(entry,value[key],pointer+"/"+_pointer(key),cache)

## Actual selected EffectUses, independent of the optional body recipe and
## historical related-spell metadata. This is method/source inspection only.
static func _native_uses(entry:Dictionary,uses:Array,source:String,owner:String)->void:
    for index in uses.size():
        var cue:Dictionary=uses[index]
        var pointer:String=str(cue.get("source",source+"/"+str(cue.get("source_index",index))))
        var clip:Dictionary=Effects.for_cue(cue,owner,str(cue.get("role","")))
        var requirement:Dictionary=Requirements.row("native_effect","Native "+str(cue.get("role","effect"))+" · "+str(cue.get("clip","")),pointer,
            "implemented","projected",[],"owner",
            "The selected use enters the shared native component/owner path. Source presence and a method declaration do not qualify actual inputs, pixels or artwork.")
        requirement.authored_use=cue.duplicate(true)
        requirement.renderer="res://presentation/native_spell_renderer.gd"
        requirement.required_channels=clip.get("inputs",[]).duplicate()
        requirement.source_kind=clip.get("source_kind","indexed_clip")
        requirement.availability="assigned" if not clip.is_empty() else "missing"
        if clip.is_empty():
            requirement.status="missing";requirement.gap_kind="source"
            requirement.reason="The selected native use does not resolve to an installed source."
            requirement.next_step="Restore the exact assigned source or choose a compatible delivered source."
        elif not cue.get("unbound_constructor_inputs",[]).is_empty():
            requirement.status="missing";requirement.gap_kind="unassessed"
            requirement.reason="The selected use explicitly withholds construction for: "+", ".join(cue.unbound_constructor_inputs)
            requirement.next_step="Inspect the declared operands and actual public input path; do not construct its review fixture."
        entry.requirements.append(requirement)

## Use the same admitted native selection and owner/event exclusions as Play.
## Inactive alternatives stay inspectable without becoming missing live effects.
static func _native_selection_uses(entry:Dictionary,selection:Dictionary,source:String,owner:String,variant:Dictionary={})->void:
    var owned:Array=NativeSpells.owned_cues(selection)
    var events:Array=NativeSpells.event_cues(selection).map(func(cue):return int(cue.source_index))
    for cue in selection.get("staging",{}).get("cues",[]):
        _native_uses(entry,[cue],source,owner)
        var requirement:Dictionary=entry.requirements[-1]
        var index:int=int(cue.get("source_index",0))
        # An inherited cue has the same editable source field in several
        # actual variant selections. Keep that provenance, but key this
        # inspection occurrence by its distinct selected variant context.
        requirement.id="native-selection:"+str(entry.id)+":"+source+"/"+str(index)
        var dispatch:String="event_candidate" if index in events else "result_projection_candidate"
        if index in selection.get("excluded_cue_indices",[]):dispatch="excluded_probe"
        elif index in owned:dispatch="delegated_owner"
        elif selection.get("explicit_event_cues",false) and index not in selection.get("event_cue_indices",[]):dispatch="not_selected_for_event"
        var inactive:bool=dispatch in ["excluded_probe","delegated_owner","not_selected_for_event"]
        if not variant.is_empty() and (variant.get("when",{}).is_empty() or not str(variant.get("dispatch_gap","")).is_empty()):
            dispatch="inventory_alternative";inactive=true
        requirement.dispatch=dispatch
        requirement.variant={"id":variant.get("id",""),"when":variant.get("when",{}).duplicate(true),
            "save_effect_id":variant.get("save_effect_id",""),"dispatch_gap":variant.get("dispatch_gap","")}
        requirement.owner_policy=selection.get("lifecycle",{}).duplicate(true)
        if inactive:
            requirement.implementation="not_applicable";requirement.status="explicit_none";requirement.gap_kind="explicit_none"
            requirement.reason="This selected source is inspectable but does not independently dispatch here: "+dispatch+". "+str(variant.get("dispatch_gap",""))
            requirement.next_step="Inspect its authored owner/delegation or exact variant predicate; no output or artwork approval is inferred."

static func _native_spell(entry:Dictionary,owner:String,source:String,cache:Dictionary)->void:
    var value:Dictionary=NativeSpells.source(owner,cache)
    if value.selection.is_empty():return
    _native_selection_uses(entry,value.selection,source+"::effects",owner)
    for index in value.variants.size():
        var variant:Dictionary=value.variants[index]
        _native_selection_uses(entry,variant.selection,source+"::variants/"+str(index)+"/effects",owner,variant)

static func _recipe(entry:Dictionary,value:Dictionary,path:String,cache:Dictionary)->void:
    if value.has("_resource_source") and str(value.get("_legacy_source","")).is_empty():
        # Raw built recipes have not gone through Authoring.action, which
        # normally supplies this known catalog pointer before field lookup.
        value=value.duplicate(false);value._legacy_source=path
    if value.get("disposition")=="state_only":
        _require(entry,"Explicit state-only presentation",path+"/disposition","explicit_none","The authoring explicitly selects no animation.","No VFX assignment is required by this recipe.")
        return
    var first_requirement:int=entry.requirements.size()
    _slots(entry,value,path,cache)
    for requirement in entry.requirements.slice(first_requirement):
        if requirement.has("native_method"):requirement.public_fact_selector=value.get("observedFact",{}).duplicate(true)
    for i in value.get("previewChildCueKinds",[]).size():
        _require(entry,"Child presentation: "+str(value.previewChildCueKinds[i]),path+"/previewChildCueKinds/"+str(i),"unexercised",
            "The recipe delegates this consequence to its actual child event; disabling the wrapper's body does not disable the child.",
            "Inspect that child event's own authored tracks and missing components.")
    if entry.requirements.is_empty():
        _require(entry,"Recipe assigned",path,"unexercised","This recipe has no external media selection; its body, material or child behavior still needs occurrence coverage.","Inspect its declared body/material/child behavior; source presence is not render proof.")
    if value.has("_resource_source"):
        entry.legacy_source=path
        entry.source=value._resource_source
        for requirement in entry.requirements.slice(first_requirement):
            requirement.legacy_source=requirement.source
            var relative:String=str(requirement.source).trim_prefix(path).trim_prefix("/")
            # Reuse the effective catalog's property mapping, including inherited
            # JSON fields that deliberately have no native override.
            requirement.source=Authoring.recipe_source(value,relative,cache)
            requirement.id=entry.id+":"+requirement.source
            if requirement.has("native_method"):requirement.native_method.assignment_source=requirement.source
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
        _slots(entry,values[id],source,cache)
        entries.append(entry)

## The existing typed root is also an inventory input. A declaration cannot
## disappear merely because its document was omitted by an earlier build.
## Preserve backend definitions/labels and inspect sources without loading each
## entry or constructing its Resource dependencies in the audit worker.
static func _declared_owners(expected:Dictionary,declared:Dictionary)->void:
    for kind in declared:
        for id in declared[kind]:
            if not expected.has(id):expected[id]={"id":id,"kind":kind,"label":id}

static func _missing_document(entry:Dictionary,selected_source:String,document_source:String)->void:
    var requirement:Dictionary=entry.requirements[-1]
    requirement.document_source=document_source
    if selected_source.is_empty():return
    entry.source=selected_source
    requirement.source=selected_source
    requirement.id=entry.id+":"+selected_source
    requirement.source_assignment=selected_source
    requirement.reason+=" The typed root selects this exact resource, but the current built documents do not supply that assignment. A declaration alone does not establish an enabled body, absent artwork or rendered output."

static func build(cache:Dictionary={})->Dictionary:
    var entries:Array=[]
    var abilities:SourceRoot=load(Library.ABILITIES)
    var declared:Dictionary=Library.declared(abilities)
    var coverage:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Library.COVERAGE)).get("coverage",{})
    var index=_read("catalog-index.json",cache)
    var conditions=_read("catalog/condition_recipes.json",cache)
    var snapshot:Dictionary={}
    if FileAccess.file_exists(SNAPSHOT):snapshot=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
    var expected={}
    for definition in snapshot.get("entries",[]):expected[definition.id]=definition
    _declared_owners(expected,declared)
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
    for id in bindings:
        if not expected.has(id):expected[id]={"id":id,"kind":"action","label":id}
    # These existing movement facts use Authoring.body's shared context instead
    # of per-command recipes. No second recipe or imaginary source is required.
    var motion={"action.move":"/walkClip","action.jump":"/jumpClip","action.traverse_connector":"/connectorProfiles"}
    var ids=expected.keys();ids.sort()
    for id in ids:
        var definition:Dictionary=expected[id]
        var kind:String=definition.kind
        var selected_source:String=declared.get(kind,{}).get(id,{}).get("source_path","")
        if conditions.has(id) and (kind=="condition" or not selected_source.is_empty() and selected_source==abilities.sections.get("conditions",{}).get(id,"")):
            continue # detailed lifecycle inventory owns actual typed condition aliases too
        var entry={"id":id,"label":definition.get("label",id),"group":"Spells" if kind=="spell" else ("Conditions" if kind=="condition" else "Actions"),
            "source":"","definition_ref":definition.get("definition_ref",{}),"requirements":[]}
        var selected_status:String=coverage.get(kind,{}).get(id,"")
        if selected_status in ["stand_in","partial","missing"]:
            _require(entry,"Authored source needs review: "+selected_status,Library.COVERAGE+"#/coverage/"+kind+"/"+_pointer(str(id)),"authoring_review",
                "Build source coverage classifies this entry as "+selected_status+". Its actual selected body/effect/delegation methods remain inspectable; this status alone is not an absent artwork or rendered-output claim.",
                "Review and complete this existing typed source; a stand-in is not an absent draft or approved art.")
            entry.requirements.back().source_assignment=selected_source
        if kind=="condition":
            entry.source="catalog/condition_recipes.json:/"+_pointer(id)
            _require(entry,"No condition presentation decision",entry.source,"authoring_review",
                "The backend catalog lists this condition identity, but this authoring catalog has no member presentation recipe. It may be a cause-only catalog label or have a spatial/item owner; an actual ConditionInstance is not established by catalog membership alone.",
                "Assign a condition recipe or document its existing visual owner/state-only disposition; do not create duplicate VFX blindly.")
        elif kind=="spell":
            var path:String=drafts.get(id,"spells/"+id+".json")
            entry.source=path+":/"
            var recipe=_read(path,cache)
            if recipe.is_empty():
                _require(entry,"No spell presentation assignment",entry.source,"authoring_review",
                    "This backend spell has no selected draft at this path. A delegated reaction/child effect may own its presentation.",
                    "Add its draft or explicitly connect the existing presentation owner, including any state-only decision.")
                _missing_document(entry,selected_source,path+":/")
            else:
                if selected_source.is_empty() and not drafts.has(id):
                    _require(entry,"Draft is not indexed","catalog-index.json:/drafts/"+_pointer(id),"authoring_assignment","The file exists but the authoring index does not select it.","Add the existing draft path to the authoring index.")
                if recipe.get("cast",{}).is_empty():_require(entry,"No cast assignment",path+":/cast","authoring_review","The draft contains no casting presentation decision.","Select the cast presentation or document its actual reaction/child owner.")
                _recipe(entry,recipe,path+":",cache)
            _native_spell(entry,str(id),selected_source if not selected_source.is_empty() else path,cache)
        elif motion.has(id):
            entry.source="catalog/movement_context.json:"+motion[id]
            _require(entry,"Shared movement presentation",entry.source,"unexercised","The production movement sampler uses this existing context.","Inspect the recorded movement/connector timeline; a separate action recipe is unnecessary.")
            var context=_read("catalog/movement_context.json",cache)
            var media_field="walkMedia" if id=="action.move" else ("jumpMedia" if id=="action.jump" else "")
            if not media_field.is_empty():_slots(entry,context.get(media_field,[]),"catalog/movement_context.json:/"+media_field,cache)
        else:
            var binding:Dictionary=bindings.get(id,{})
            var source_id:String=binding.get("source_recipe",id)
            entry.source=sources.get(source_id,str(binding.get("source","catalog/body_action_recipes.json:/"+_pointer(source_id))))
            if actions.has(source_id):_recipe(entry,actions[source_id],entry.source,cache)
            elif binding.get("effect_cues",[]).is_empty():
                _require(entry,"No action presentation assignment",entry.source,"authoring_review",
                    "The backend action has no direct recipe, selected body recipe or native effect use. Its children may have their own presentations.",
                    "Assign the action's presentation or explicitly declare its child/state-only behavior.")
                _missing_document(entry,selected_source,entry.source)
            _native_uses(entry,binding.get("effect_cues",[]),str(binding.get("source",entry.source)),str(id))
        entries.append(entry)
    var characters:SourceRoot=load("res://authoring/characters.tres")
    var body_index:Resource=BodySources.index(cache)
    for section in [["rigs","rig"],["characters","creature_rig"]]:
        for id in characters.sections.get(section[0],{}):
            var source:String=characters.sections[section[0]][id]
            var owner:Dictionary=_creature_rig_requirement(id,source,body_index,characters.sections.get("rigs",{})) if section[1]=="creature_rig" else Requirements.owner(section[1],id,source,{})
            entries.append({"id":section[1]+":"+id,"label":owner.label,"group":"Presentation owners · "+section[1].replace("_"," "),"source":source,"requirements":[owner]})
    _gear_owners(entries,characters,cache)
    # Existing context/world owners expose source slots even when no recording
    # has exercised them. Do not inventory sprite rigs or media storage twice.
    for key in index:
        if not str(key).ends_with("_context") and key not in ["interruptions","body_release_media","entity_lifecycle_media","item_attachments"]:continue
        var path:String=index[key]
        var entry={"id":"context:"+key,"label":str(key).replace("_"," ").capitalize(),"group":"Shared effects","source":path+":/","requirements":[]}
        var context:Dictionary=_read(path,cache)
        _slots(entry,context,path+":",cache)
        if key=="body_release_media":
            for release_id in context:
                var selected:Variant=context[release_id]
                if not selected is Dictionary or str(selected.get("residue_id","")).is_empty():continue
                var residue_id:String=str(selected.residue_id)
                var asset:Dictionary=Authoring.Catalog.residue_asset(cache,residue_id)
                var style:Dictionary=asset.get("region",{})
                var release_source:String=str(selected.get("source",path+":/"+str(release_id)))
                var release_requirement:Dictionary=Requirements.row("body_release","Region release · "+str(release_id),release_source,
                    "implemented" if not style.is_empty() else "missing","projected",["damage"],"recipient",
                    "Exact public release identity selects the existing region source and residue; actual receiving regions/after-values own admission. No rendered output or artwork approval is inferred.")
                release_requirement.authored_source=selected.duplicate(true)
                release_requirement.source_program={"asset_id":selected.get("asset_id",""),"residue_id":residue_id,
                    "primitive":style.get("primitive",""),"palette":style.get("palette",[]),
                    "renderer":"res://presentation/blood_renderer.gd","prepared":"not_examined","rendered":"not_witnessed"}
                entry.requirements.append(release_requirement)
        for field in ["nativeEffects","nativeImpactEffects"]:_native_uses(entry,context.get(field,[]),path+":/"+field,str(key))
        entry.requirements.append_array(Requirements.context(context,path+":",key))
        if not entry.requirements.is_empty():entries.append(entry)
    # The environment source's surfaces keep the old spatial media as delivered;
    # the build lists them with the objects, banks, wrecks, portals and devices.
    var environment:Dictionary=Authoring.Catalog.environment_index(cache)
    _residue_owners(entries,environment,cache)
    for id in environment.get("native_spatial_effects",{}):
        var config:Dictionary=environment.native_spatial_effects[id]
        for cue in config.get("persistent",{}).get("nativeEffects",[]):
            var pointer:String=str(cue.get("source",str(config.get("_resource_source",Requirements.environment_source(id)))+"::lasting"))
            var requirement:Dictionary=Requirements.row("native_effect","Native lasting field · "+str(cue.clip),pointer,
                "implemented","projected",["spatial_effect_state"],"spatial_effect",
                "The canonical GroundSurface lasting use is compiled by the existing native spatial-owner path. Actual public membership, current geometry and removal own its source clock; no rendered-output or artwork approval is inferred.")
            requirement.authored_use=cue.duplicate(true)
            requirement.renderer="res://presentation/native_persistent.gd::spatial_samples"
            entries.append({"id":"native_spatial:"+id+":"+str(cue.source_index),"label":id,
                "group":"World effects · spatial","source":pointer,"requirements":[requirement]})
    for id in environment.get("spatial_media",{}):
        var media:Dictionary=environment.spatial_media[id]
        var active:bool=media.get("native_world_media",false)
        var pointer:String=str(media.get("source",Requirements.environment_source(id)+"::legacy/spatial_media"))
        var entry={"id":"spatial_media:"+id,"label":id,"group":"World effects · spatial","source":pointer,"requirements":[]}
        _slots(entry,media,pointer,cache)
        var method:Dictionary=Requirements.owner(("portal" if media.get("kind")=="portal" else "world_animation") if active else "spatial_media",id,pointer,media)
        if active:method.authored_program=media.duplicate(true)
        entry.requirements.append(method)
        for trigger in media.get("contactMedia",{}):
            entry.requirements.append(Requirements.owner("contact_media",id+"/"+trigger,pointer+"/contactMedia/"+_pointer(trigger),media.contactMedia[trigger]))
        entries.append(entry)
    # Selected owners from the original passive presentation_inventory. Each
    # owner is a worklist entry even if it has no external sprite identity.
    for kind in ["world_animation","portal","device"]:
        for id in environment.get("inspection",{}).get(kind,{}):
            if environment.get("spatial_media",{}).get(id,{}).get("native_world_media",false) and kind in ["world_animation","portal"]:continue
            var source:String=Requirements.environment_source(id)
            var owner_row=Requirements.owner(kind,id,source,environment.inspection[kind][id])
            entries.append({"id":kind+":"+id,"label":owner_row.label,"group":"Presentation owners · "+kind.replace("_"," "),"source":source,"requirements":[owner_row]})
    for definition in [
        ["body_materials","body_material"],["action_materials","action_material"],["action_intakes","action_intake"],
        ["condition_media","condition_media"],["item_attachments","item_attachment"]]:
        if index.get(definition[0]) is String:_owners(entries,index[definition[0]],definition[1],cache)
    for field in ["banks","doors","traps","props","wrecks"]:
        var family:String="environment_"+{"banks":"bank","doors":"door","traps":"trap","props":"prop","wrecks":"wreck"}[field]
        for id in environment.get(field,{}):
            var value:Variant=environment[field][id]
            var source:String="authoring/environment/art/"+id+".tres" if field=="banks" else Requirements.environment_source(value.source_item_id if field=="wrecks" else id)
            var owner_row=Requirements.owner(family,id,source,value)
            var entry={"id":family+":"+id,"label":owner_row.label,"group":"Presentation owners · "+family.replace("_"," "),"source":source,"requirements":[owner_row]}
            _slots(entry,value,source,cache)
            entries.append(entry)
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

## Inspect the admitted body binding, not merely the editable Resource path.
## Effect-owned and absent mappings keep their separate unresolved owner rows.
static func _creature_rig_requirement(id:String,source:String,selected:Resource,rig_sources:Dictionary)->Dictionary:
    var result:Dictionary=Requirements.owner("creature_rig",id,source,{})
    if selected==null or selected.effect_owned_creatures.has(id):return result
    var rig:String=selected.root_rig if id=="creature.player.humanoid_body" else str(selected.creature_rigs.get(id,""))
    var rig_source:String=str(rig_sources.get(rig,""))
    if rig.is_empty() or not selected.rigs.has(rig) or rig_source.is_empty():return result
    result.inspection="projected";result.gap_kind="unexercised";result.status="unexercised"
    result.reason="The admitted character binding selects this exact existing rig through the shared body selector. This is source inspection only; per-occurrence pose/loadout, readiness, rendered output and artwork remain unqualified."
    result.next_step="Qualify this exact rig binding and its selected body sources on an actual recorded occurrence."
    result.availability="assigned"
    result.authored_program={"creature_id":id,"rig":rig,"rig_source":rig_source}
    result.render_method={"selector":"res://presentation/characters.gd::rig_id",
        "renderer":"res://presentation/characters.gd::structure","surface":"actual disclosed actor and visual loadout",
        "source_index":str(ProjectSettings.get_setting("source_data/body_source_index",BodySources.INDEX)),
        "runtime_binding":"not_examined","prepared":"not_examined","rendered":"not_witnessed","artwork":"unreviewed"}
    return result

## Shared source-browser rows for the existing item index. These describe
## source methods, not an invented item occurrence or rendered thumbnail.
static func _gear_owners(entries:Array,characters:SourceRoot,cache:Dictionary)->void:
    var selected:Resource=BodySources.index(cache)
    if selected==null:return
    var ids:Dictionary={}
    for field in [selected.ground_equipment,selected.item_effects,selected.item_impact_effects]:
        for id in field:ids[id]=true
    for id in ids:
        var source:String=str(characters.sections.get("gear",{}).get(id,""))
        var entry:Dictionary={"id":"item_sources:"+str(id),"label":str(id),"group":"Items","source":source,"requirements":[]}
        var ground:Dictionary=selected.ground_equipment.get(id,{})
        for variant in ground.get("variants",{}):
            var look:Dictionary=ground.variants[variant]
            var pointer:String=str(look.source)
            var requirement:Dictionary=Requirements.row("ground_equipment","Dropped look · "+("base" if str(variant).is_empty() else str(variant)),pointer,
                "implemented","projected",[],"world_object",
                "The actual world object's item id/current visual variant selects this unchanged source cell and authored registration through the existing scenery renderer. Source assignment does not qualify readiness, optical parity, pixels or artwork.")
            requirement.authority_source="WorldSnapshot.objects[].item + placement"
            requirement.availability="assigned"
            requirement.authored_program=look.duplicate(true)
            requirement.render_method={"renderer":"res://presentation/environment_source.gd::describe",
                "selector":"res://presentation/body_sources.gd::ground","shader":"res://environment.gdshader",
                "surface":"actual world object","source_encoding":"original component byte-depth / RGB normals when supplied",
                "normal_profile":"original","native_actor_occlusion":"not_qualified","artwork":"unreviewed"}
            entry.requirements.append(requirement)
        if not str(ground.get("family","")).is_empty():
            var requirement:Dictionary=Requirements.row("ground_equipment_family","Dropped look · explicit family",source+"::family",
                "implemented","projected",[],"world_object",
                "An own exact variant wins. Only its absence permits the explicitly authored family with that same actual variant; unknown variants never inherit a base look.")
            requirement.availability="assigned"
            requirement.authored_program={"family":ground.family,"selector":"own_exact_variant_then_explicit_family_same_variant"}
            entry.requirements.append(requirement)
        _native_uses(entry,selected.item_effects.get(id,[]),source+"::effects",str(id))
        _native_uses(entry,selected.item_impact_effects.get(id,[]),source+"::impact_effects",str(id))
        if not entry.requirements.is_empty():entries.append(entry)

## Current retained residue assignments use ordinary source inspection, with
## owner/receiving evidence still supplied only by actual replay rows.
static func _residue_owners(entries:Array,environment:Dictionary,cache:Dictionary)->void:
    for id in environment.get("floor_residue_sources",{}):
        var profile:Dictionary=environment.floor_residue_sources[id]
        var pointer:String=str(profile.source)
        var requirement:Dictionary=Requirements.row("floor_residue","Retained floor motifs",pointer,
            "implemented","projected",[],"tile_residue",
            "Actual tile residue membership and currently observed same-height neighbors own this source's coverage. The original atlas is sampled by the shared environment material; no source presence is promoted to output evidence.")
        requirement.availability="assigned"
        requirement.authority_source="WorldSnapshot.tiles[].residues"
        requirement.authored_program=profile.duplicate(true)
        requirement.render_method={"renderer":"res://presentation/environment_source.gd::_floor_motif_parameters",
            "shader":"res://environment.gdshader::floor_motif_sample","surface":"actual supported residue tile","artwork":"unreviewed"}
        entries.append({"id":"floor_residue:"+str(id),"label":str(id),"group":"World effects · residues","source":pointer,"requirements":[requirement]})
    for id in environment.get("wall_residue_sources",{}):
        var profile:Dictionary=environment.wall_residue_sources[id]
        var pointer:String=str(profile.source)
        var requirement:Dictionary=Requirements.row("wall_residue","Retained wall motifs",pointer,
            "implemented","projected",[],"world_object",
            "Only actual observed marked object faces and exact authored source-image/frame UV registrations admit this RGB treatment. Missing registration leaves that source untreated; no tile stain creates an object mark.")
        requirement.availability="assigned"
        requirement.authority_source="WorldSnapshot.objects[].item.surface_residues[].faces + current sensory visibility"
        requirement.authored_program=profile.duplicate(true)
        requirement.render_method={"renderer":"res://presentation/environment_source.gd::_wall_motif_parameters",
            "shader":"res://environment.gdshader::wall_motif_colour","surface":"actual registered marked boundary face",
            "source_gate":"exact source_image_id","alpha_depth_normals":"original_source","artwork":"unreviewed"}
        entries.append({"id":"wall_residue:"+str(id),"label":str(id),"group":"World effects · residues","source":pointer,"requirements":[requirement]})
    for id in environment.get("residue_sources",{}):
        var source:Dictionary=environment.residue_sources[id]
        var asset:Dictionary=Authoring.Catalog.residue_asset(cache,str(id))
        var region:Dictionary=asset.get("region",{})
        var deposit:Dictionary=asset.get("retained_deposit",{})
        var pointer:String=str(source.source)
        var requirement:Dictionary=Requirements.row("retained_residue","Retained region source",pointer,
            "implemented","projected",[],"tile_residue",
            "The current actual residue after-value selects this prepared region source through the existing field atlas. Source-owned local pools additionally require matching real deposit metadata; no body release or flight is inferred.")
        requirement.availability="assigned"
        requirement.authority_source="WorldSnapshot.tiles[].residues[].contributions"
        requirement.source_program={"asset_id":source.get("asset_id",""),"residue_id":str(id),
            "primitive":region.get("primitive",""),"palette":region.palette.duplicate(true) if region.get("palette")!=null else [],
            "retained_deposit":deposit.duplicate(true),"renderer":"res://presentation/blood_renderer.gd",
            "prepared":"not_examined","rendered":"not_witnessed","artwork":"unreviewed"}
        if not deposit.is_empty():requirement.deposit_source=str(deposit.get("source",""))
        entries.append({"id":"retained_residue:"+str(id),"label":str(id),"group":"World effects · residues","source":pointer,"requirements":[requirement]})
