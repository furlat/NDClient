extends RefCounted
## Passive capability inventory. Expected work exists independently of playback.
const Audit=preload("res://studio/authoring_audit.gd")
const Conditions=preload("res://presentation/condition_coverage.gd")
const CONTENT="res://generated/studio_content_catalog.json"
const MIGRATION="res://generated/native_migration_inventory.json"
const SCENARIOS="res://authoring/studio/scenarios.json"
const SPELL_CASES="res://generated/studio_spell_case_inventory.json"

static func _read(path:String,cache:Dictionary,errors:Array)->Dictionary:
    var key="study:"+path
    if cache.has(key):return cache[key]
    if not FileAccess.file_exists(path):
        errors.append("Study input missing: "+path);return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not value is Dictionary:
        errors.append("Study input is not an object: "+path);return {}
    cache[key]=value
    return value

static func _kind(entry:Dictionary)->String:
    var id:String=entry.id
    if id.begins_with("action.") or id.begins_with("reaction."):return "Action"
    if id.begins_with("spell."):return "Spell"
    if id.begins_with("condition."):return "Condition"
    return "Mechanic"

static func _entry(index:Dictionary,id:String,label:String,kind:String,source:String)->Dictionary:
    if not index.has(id):
        index[id]={"id":id,"label":label,"kind":kind,"source":source,"behavior_ids":[id] if kind in ["Action","Spell","Condition"] else [],
            "requirements":[],"scenarios":[]}
    return index[id]

static func _readable_label(entry:Dictionary)->String:
    var label:String=entry.label
    if label!=entry.id and not label.begins_with("action.") and not label.begins_with("condition.") and not label.begins_with("spell."):return label
    if entry.kind=="VFX":return label
    var parts=String(entry.id).split(".")
    var name=String(parts[-1]).replace("_"," ").capitalize()
    if parts.size()>3 and parts[1]=="class":name+=" · "+String(parts[2]).capitalize()
    return name

static func _requirements(entry:Dictionary,rows:Array)->void:
    var existing={}
    for row in entry.requirements:existing[row.id]=true
    for original in rows:
        if existing.has(original.id):continue
        var row:Dictionary=original.duplicate(true)
        row.label=row.get("label",str(row.get("phase",""))+" · "+str(row.get("mechanism",row.id)))
        row.rendered=false
        row.source=row.get("source",entry.source)
        row.reason=row.get("reason","")
        if not row.has("gap_kind"):
            if row.get("availability")=="missing":row.gap_kind="source"
            elif row.get("implementation")=="missing":row.gap_kind="renderer"
            elif row.get("status")=="explicit_none":row.gap_kind="explicit_none"
            else:row.gap_kind="unexercised"
        row.status=row.get("status","unexercised")
        entry.requirements.append(row);existing[row.id]=true

static func build(cache:Dictionary={},records:Array=[])->Dictionary:
    var errors:Array=[]
    var index={}
    var snapshot=_read(CONTENT,cache,errors)
    for n in snapshot.get("entries",[]).size():
        var definition:Dictionary=snapshot.entries[n]
        var kind:String={"action":"Action","reaction":"Action","spell":"Spell","condition":"Condition"}.get(definition.kind,"Mechanic")
        var entry=_entry(index,definition.id,definition.get("label",definition.id),kind,CONTENT+":/entries/"+str(n))
        entry.definition_ref=definition.get("definition_ref",{}).duplicate(true)
    var authored=Audit.build(cache)
    for original in authored.entries:
        var entry=_entry(index,original.id,original.label,_kind(original),original.source)
        entry.source=original.source
        _requirements(entry,original.requirements)
    var conditions=Conditions.build(cache)
    for original in conditions.entries:
        var entry=_entry(index,original.id,original.label,"Condition",original.source)
        # A legacy condition recipe may reuse an actual spell identity (False
        # Life). Keep its backend family while retaining both sets of sources.
        if entry.kind not in ["Action","Spell"]:
            entry.label=original.label;entry.source=original.source;entry.kind="Condition"
        entry.condition_source=original.source
        if original.id not in entry.behavior_ids:entry.behavior_ids.append(original.id)
        if original.has("indicator_assignments"):entry.indicator_assignments=original.indicator_assignments.duplicate(true)
        _requirements(entry,original.requirements)
    var migration=_read(MIGRATION,cache,errors)
    for n in migration.get("assets",[]).size():
        var asset:Dictionary=migration.assets[n]
        var entry=_entry(index,asset.asset_id,asset.asset_id,"VFX",MIGRATION+":/assets/"+str(n))
        var native:Dictionary=asset.get("native",{})
        entry.native=native.duplicate(true)
        entry.registration=asset.get("registration",{}).duplicate(true)
        var rows:Array=[]
        for ref in asset.get("references",[]):
            var enabled:bool=ref.get("enabled",true)
            var native_status:String=native.get("status","source_not_mapped")
            rows.append({"id":asset.asset_id+":"+str(ref.source),"label":str(ref.source),"source":ref.source,
                "status":"unexercised" if enabled else "explicit_none",
                "gap_kind":("unexercised" if native_status=="imported" else "native_migration") if enabled else "explicit_none",
                "reason":"Source assignment and native availability are separate from rendered evidence.",
                "native_status":native_status,"native_source_ids":native.get("source_ids",[]).duplicate(),
                "reference_kind":ref.get("kind",""),"gaps":asset.get("gaps",[]).duplicate(),"rendered":false})
        _requirements(entry,rows)
    var studies=_read(SCENARIOS,cache,errors)
    for n in studies.get("capabilities",[]).size():
        var definition:Dictionary=studies.capabilities[n]
        var entry=_entry(index,definition.id,definition.label,definition.get("kind","Mechanic"),definition.get("source",SCENARIOS+":/capabilities/"+str(n)))
        entry.label=definition.label
        for id in definition.get("behavior_ids",[]):
            if id not in entry.behavior_ids:entry.behavior_ids.append(id)
    var recorded={}
    for record in records:recorded[record.id]=record
    var counts={"capabilities":0,"actions":0,"spells":0,"conditions":0,"vfx":0,"mechanics":0,
        "scenarios":0,"recorded_scenarios":0,"partial_scenarios":0,"study_needed":0}
    var seen_scenarios={}
    var scenario_inputs:Array=[]
    for n in studies.get("scenarios",[]).size():
        var row:Dictionary=studies.scenarios[n].duplicate()
        row.source=SCENARIOS+":/scenarios/"+str(n)
        scenario_inputs.append(row)
    var spell_cases=_read(SPELL_CASES,cache,errors)
    for n in spell_cases.get("cases",[]).size():
        var record:Dictionary=spell_cases.cases[n]
        var source=SPELL_CASES+":/cases/"+str(n)
        scenario_inputs.append({"id":record.id,"code":record.spell_id,"label":record.label+" · "+record.interaction,
            "capability_ids":["spell."+record.spell_id],"source":source,
            "purpose":record.qualification,"setup":"Normal encounter spell grants; independent Amber and Blue public SDK recordings.",
            "sequence":record.get("sequence",[]),"participants":["caster","recipient"],
            "expectations":[{"id":record.id+":authority","label":"Preserve the recorded spell, recipient and owner outcomes",
                "phase":"Recorded sequence","participants":["caster","recipient"],"rule_sources":[source],
                "authority":"server","description":"The original event IDs, damage/heal after-values, and condition/spatial lifetimes remain inspectable. This case is not evidence for every variant or artistic approval.","source":source}],
            "recordings":[{"case_id":record.id,"evidence":"recorded","gaps":[],"reference":record.descriptor}],
            "coverage":{"recording":"recorded","native_render":"not_assessed_by_this_catalog","audio":"not_assessed_by_this_catalog"}})
    for original in scenario_inputs:
        if seen_scenarios.has(original.id):
            errors.append("Duplicate study scenario: "+str(original.id));continue
        seen_scenarios[original.id]=true
        var scenario:Dictionary=original.duplicate(true)
        scenario.source=original.source
        scenario.recordings=[]
        var available_recorded=false;var available_partial=false
        for reference in original.get("recordings",[]):
            var row:Dictionary=reference.duplicate(true)
            row.available=recorded.has(row.case_id)
            row.ready=false
            if row.available:
                row.record=recorded[row.case_id]
                row.ready=bool(row.record.get("ready",false))
                row.scenario_status=row.record.get("scenario_status","not_assessed")
                available_recorded=available_recorded or (row.ready and row.get("evidence")=="recorded")
                available_partial=available_partial or (row.ready and row.get("evidence")=="partial")
            scenario.recordings.append(row)
        counts.scenarios+=1
        counts.recorded_scenarios+=int(available_recorded)
        counts.partial_scenarios+=int(available_partial)
        for id in scenario.get("capability_ids",[]):
            if not index.has(id):
                errors.append("Study scenario "+str(scenario.id)+" names undeclared capability "+str(id));continue
            index[id].scenarios.append(scenario)
    var capabilities:Array=index.values()
    for entry in capabilities:entry.label=_readable_label(entry)
    capabilities.sort_custom(func(a,b):
        if a.kind!=b.kind:return str(a.kind)<str(b.kind)
        if a.scenarios.is_empty()!=b.scenarios.is_empty():return not a.scenarios.is_empty()
        return str(a.label).nocasecmp_to(str(b.label))<0 if a.label!=b.label else str(a.id)<str(b.id))
    for entry in capabilities:
        counts.capabilities+=1
        var key:String={"Action":"actions","Spell":"spells","Condition":"conditions","VFX":"vfx","Mechanic":"mechanics"}.get(entry.kind,"mechanics")
        counts[key]+=1
        counts.study_needed+=int(entry.scenarios.is_empty())
    return {"capabilities":capabilities,"counts":counts,"errors":errors,
        "scope":"Current backend capabilities, authored requirements, condition owners and passive VFX inventory. Authored study sequences and available recordings are separate; source presence never proves rendered completion."}

## Join this existing passive inventory into the one Library worker result.
## No recording alias, extra capability or output qualification is created.
static func _source_resource(pointer:String)->String:
    return pointer.get_slice("::",0) if pointer.begins_with("res://") else ""

static func join_library(library:Dictionary,studies:Dictionary)->void:
    var authored:Dictionary={};var resource_owners:Dictionary={}
    for entry in studies.get("capabilities",[]):
        if entry.kind=="VFX":continue
        authored[entry.id]=entry
        var resource:String=_source_resource(str(entry.get("source","")))
        if not resource.is_empty():
            if not resource_owners.has(resource):resource_owners[resource]=[]
            resource_owners[resource].append(entry)
    for entry in library.get("entries",[]):
        var source:Dictionary=authored.get(entry.id,{})
        entry.requirements=[]
        var owners:Array=[source] if not source.is_empty() else []
        owners.append_array(resource_owners.get(_source_resource(str(entry.get("source_path",""))),[]))
        var seen:Dictionary={}
        for owner in owners:
            for requirement in owner.get("requirements",[]):
                if seen.has(requirement.id):continue
                seen[requirement.id]=true;entry.requirements.append(requirement.duplicate(true))
        # A shared source Resource does not establish shared behavior/outcomes.
        entry.scenarios=source.get("scenarios",[]).duplicate(true)
    library.study_errors=studies.get("errors",[]).duplicate()
    library.study_scope=studies.get("scope","")
