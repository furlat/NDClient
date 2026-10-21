extends RefCounted
## One authoring-organized library. Record availability, art, render proof and approval are separate facts.
const CAPABILITIES=["Spells","Conditions","Actions","Characters","Environment","Surfaces","Items","Interactions","Rules"]
const INDEX="res://.runtime/studio-library/index.json"
const SERVER_IDS="res://authoring/server_ids.json"
const COVERAGE="res://build/presentation/coverage.json"
const ABILITIES="res://authoring/abilities.tres"
const EVIDENCE="res://generated/reports/studio-case-evidence.json"
const PACKAGE="res://assets/vfx/index.json"
const CATEGORY={"spell":"Spells","condition":"Conditions","action":"Actions","reaction":"Actions","trait":"Actions","class_feature":"Actions","feat":"Actions","creature":"Characters","environment_object":"Environment","boundary_structure":"Environment","connector":"Environment","battlefield":"Environment","spatial_effect":"Surfaces","residue":"Surfaces","decal":"Surfaces","item":"Items","interaction":"Interactions"}
const Journal=preload("res://sdk/journal.gd")

static func _read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path));return value if value is Dictionary else {}
static func category(kind:String)->String:return CATEGORY.get(kind,"Rules")
static func _label(id:String)->String:return id.get_slice("@",0).get_file().get_slice("/",0).split(".")[-1].replace("_"," ").capitalize()
static func _same_engine(expected:Dictionary,actual:Dictionary)->bool:
    for field in ["commit","protocol_version","player_schema_version","schema_digest"]:
        if expected.get(field)==null or actual.get(field)==null or expected[field]!=actual[field]:return false
    return true
## Playback eligibility follows the exact public wire contract. Commit identity
## remains a separate qualification fact; opening an original still uses the
## unchanged strict Journal admission and never updates its captured facts.
static func _same_wire(expected:Dictionary,actual:Dictionary)->bool:
    for field in ["protocol_version","player_schema_version","schema_digest"]:
        if expected.get(field)==null or actual.get(field)==null or expected[field]!=actual[field]:return false
    return true
static func _record(original:Dictionary,engine:Dictionary,expected:Dictionary,check_files:bool)->Dictionary:
    var result=original.duplicate();var kind:String=result.get("kind","interaction");result.capability=category(kind)
    result.label=result.get("title",result.get("label",result.id));result.interaction=str(result.get("family",kind.capitalize()));result.perspectives=[]
    for faction in result.get("journals",{}):
        var journal:String=result.journals[faction]
        if not check_files or FileAccess.file_exists(journal.path_join("0000000000000000.json")):result.perspectives.append({"id":faction,"label":str(faction).capitalize(),"journal":journal})
    result.perspectives.sort_custom(func(a,b):return a.id<b.id)
    var state:String=result.get("status","failed")
    result.capture_engine=result.get("engine",engine).duplicate(true)
    result.engine_status="current" if _same_engine(expected,result.capture_engine) else "historical_or_unverified"
    result.recording_status=state
    if not result.get("errors",[]).is_empty():state="failed"
    elif state=="recorded" and not _same_wire(expected,result.capture_engine):state="stale"
    elif state=="recorded" and result.perspectives.is_empty():state="missing_journal"
    result.scenario_status=state;result.ready=state=="recorded" and not result.perspectives.is_empty()
    result.interval=result.get("interval",{});result.descriptor=result.get("scenario","");result.qualification="studio_checked" if result.get("studio_checked",false) else "not_checked";result.checks=result.get("checks",0)
    return result

## Compare identities at browser open, not only when an offline receipt was
## originally joined. Source successors do not inherit predecessor output.
static func _witness(original:Dictionary,expected:Dictionary,package:String)->Dictionary:
    var value:Dictionary=original.duplicate(true)
    # Older joins called silent transport diagnostics playback. Keep their
    # original classification but do not count a zero-start/no-PCM row as output.
    if value.get("kind")=="audio_playback":
        var counters:Dictionary=value.get("counters",{})
        var pcm:bool=value.get("pcm_frames")!=null and float(value.pcm_frames)>0.0 and value.get("pcm_peak")!=null and float(value.pcm_peak)>0.0
        if value.get("status")=="no_playback_observed" or (counters.has("started") and int(counters.started)<=0 and not pcm):
            value.reported_kind=value.kind;value.kind="audio_transport"
            value.reported_status=value.get("status","");value.status="no_playback_observed"
    if value.get("kind")=="audio_transport":
        value.reported_qualifies=value.get("qualifies","")
        value.qualifies="Audio transport diagnostics only. This receipt does not qualify playback, audible output, mix or human approval."
    var version:String=str(value.get("factory_version","")) if value.get("factory_version")!=null else ""
    value.package_scope_at_join=value.get("package_scope","not_recorded")
    if not package.is_empty():
        value.package_scope="current_package" if version==package else "historical_package" if not version.is_empty() else "package_identity_not_recorded"
    value.compared_factory_version=package
    var engine:Variant=value.get("engine")
    if not engine is Dictionary or engine.is_empty():value.engine_scope="engine_identity_not_recorded"
    elif _same_engine(expected,engine):value.engine_scope="current_engine"
    elif ["commit","protocol_version","player_schema_version","schema_digest"].all(func(field):return engine.get(field)!=null):value.engine_scope="historical_engine"
    else:value.engine_scope="partial_engine_identity"
    return value

static func _evidence_fields(owner:Dictionary,witnesses:Array)->void:
    owner.witnesses=witnesses
    owner.output_witnesses=witnesses.filter(func(value):return value.get("kind") in ["native_replay","audio_playback"])
    owner.reader_witnesses=witnesses.filter(func(value):return value.get("kind")=="recording_reader")
    owner.command_witnesses=witnesses.filter(func(value):return value.get("kind")=="issued_command")
    owner.audio_witnesses=witnesses.filter(func(value):return value.get("kind") in ["audio_playback","audio_transport"])
    owner.matching_package_output_witnesses=owner.output_witnesses.filter(func(value):return value.get("package_scope")=="current_package")
    owner.current_output_witnesses=owner.matching_package_output_witnesses.filter(func(value):return value.get("engine_scope")=="current_engine")
    owner.historical_output_witnesses=owner.output_witnesses.filter(func(value):return value.get("package_scope")!="current_package" or value.get("engine_scope")!="current_engine")

static func records(index:Dictionary,snapshot:Dictionary,check_files:bool=true,evidence:Dictionary={},package:String="")->Array:
    var result:Array=[]
    for row in index.get("cases",[]):
        var record=_record(row,index.get("engine",{}),snapshot.get("header",{}),check_files)
        var witnesses:Array=[]
        for original in evidence.get("cases",{}).get(record.id,[]):witnesses.append(_witness(original,snapshot.get("header",{}),package))
        _evidence_fields(record,witnesses)
        record.evidence_status="evidence_available" if not record.output_witnesses.is_empty() else "not_assessed"
        result.append(record)
    return result
static func read()->Array:
    return records(_read(INDEX),_read(SERVER_IDS),true,_read(EVIDENCE),str(_read(PACKAGE).get("version","")))

## An explicitly selected failed scenario may retain a useful real prefix.
## Admit its initialization only here; the ordinary reader still owns every
## subsequent packet/error. This never changes ready/status/qualification.
static func failed_prefix(record:Dictionary)->Dictionary:
    if record.get("ready",false) or record.get("scenario_status") not in ["failed","stale"]:
        return {"available":false,"perspectives":[],"errors":[]}
    var perspectives:Array=[];var errors:Array=[]
    var candidates:Array=record.get("perspectives",[]).duplicate()
    for faction in record.get("journals",{}):
        if not candidates.any(func(perspective):return str(perspective.id)==str(faction)):
            candidates.append({"id":str(faction),"label":str(faction).capitalize(),"journal":record.journals[faction]})
    for perspective in candidates:
        var path:String=str(perspective.journal).path_join("0000000000000000.json")
        if not FileAccess.file_exists(path):
            errors.append(str(perspective.id)+": Initialization is unavailable: "+path);continue
        # The ordinary offline journal admits this exact stored producer
        # contract. Unknown/old-wire identities still fail without conversion.
        var journal:RefCounted=Journal.new()
        var opened:Dictionary=journal.open(str(perspective.journal),true,false)
        if not opened.ok:
            errors.append(str(perspective.id)+": "+str(opened.error));continue
        var decoded:Dictionary=journal.decode_record(0,FileAccess.get_file_as_bytes(path))
        if not decoded.ok:
            errors.append(str(perspective.id)+": "+str(decoded.error));continue
        if int(decoded.value.cursor.sequence)!=0:
            errors.append(str(perspective.id)+": Initialization cursor is not zero");continue
        perspectives.append(perspective)
    return {"available":not perspectives.is_empty(),"perspectives":perspectives,"errors":errors}
static func _group(kind:String,id:String,definition:Variant)->String:
    var row:Dictionary=definition if definition is Dictionary else {}
    if kind=="spell":return "Level %d · %s"%[int(row.get("level",0)),str(row.get("school","Other")).capitalize()]
    return str(row.get("family",kind.replace("_"," "))).replace("_"," ").capitalize()
## The root lists source-owned capabilities without loading every entry. Class
## grants can have typed sources while absent from the exported ID snapshot.
static func source_kind(section:String,id:String)->String:
    var kind:String=id.get_slice(".",0)
    return "condition" if section=="conditions" and not CATEGORY.has(kind) else kind

static func declared(root:Resource)->Dictionary:
    var inventory:Dictionary={}
    var domain:String=str(root.get("domain"))
    var domains:Dictionary={"characters":{"characters":"creature","gear":"item"},
        "environment":{"objects":"environment_object","surfaces":"spatial_effect","connectors":"connector","battlefields":"battlefield"}}
    if domains.has(domain):
        for section in domains[domain]:
            for id in root.sections.get(section,{}):
                var kind:String=str(domains[domain][section])
                if section=="surfaces" and str(id).begins_with("residue."):kind="residue"
                elif section=="surfaces" and str(id).begins_with("created.decal."):kind="decal"
                if not inventory.has(kind):inventory[kind]={}
                inventory[kind][id]={"source_path":root.sections[section][id]}
        return inventory
    for section in ["spells","conditions","actions"]:
        for id in root.sections.get(section,{}):
            var kind:String=source_kind(section,str(id))
            var owner:String={"spell":"spells","condition":"conditions"}.get(kind,"actions")
            # Retained aliases must not replace a current capability's own
            # source, e.g. conditions/spell.false_life vs the actual spell.
            if owner!=section and root.sections.get(owner,{}).has(id):continue
            if not inventory.has(kind):inventory[kind]={}
            inventory[kind][id]={"source_path":root.sections[section][id]}
    return inventory

static func build(snapshot:Dictionary,coverage:Dictionary,index:Dictionary,check_files:bool=true,source_inventory:Dictionary={},evidence:Dictionary={},package:String="")->Dictionary:
    var cases=records(index,snapshot,check_files,evidence,package);var entries:Array=[];var by_subject={};var by_key={};var categories={};var counts={}
    for record in cases:
        for kind in record.get("subjects",{}):
            for id in record.subjects[kind]:
                var key=kind+":"+str(id)
                if not by_subject.has(key):by_subject[key]=[]
                by_subject[key].append(record)
    var inventory:Dictionary=snapshot.get("ids",{}).duplicate()
    for kind in source_inventory:
        var values:Variant=inventory.get(kind,{})
        var merged:Dictionary=values.duplicate() if values is Dictionary else {}
        if values is Array:
            for id in values:merged[id]={}
        for id in source_inventory[kind]:
            if not merged.has(id):merged[id]={}
        inventory[kind]=merged
    for kind in inventory:
        var values:Variant=inventory[kind]
        for id in values:
            var key=kind+":"+str(id);var definition:Variant=values[id] if values is Dictionary else {};var linked:Array=by_subject.get(key,[]);var scenario="missing"
            if linked.any(func(row):return row.ready):scenario="recorded"
            elif not linked.is_empty():scenario=linked[0].scenario_status
            # Current human direction: the complete artwork inventory awaits
            # review. Old capture metadata remains in its original record;
            # it cannot approve or reject the current source assignments.
            var provider="not_assessed";var approval="needs_review"
            for record in linked:
                var qualified:Dictionary=record.get("presentation",{}).get(str(id),{})
                if not qualified.is_empty():provider=qualified.get("status",provider)
            var witnesses:Array=[];var output_witnesses:Array=[]
            for record in linked:witnesses.append_array(record.witnesses);output_witnesses.append_array(record.output_witnesses)
            if provider=="not_assessed" and not output_witnesses.is_empty():provider="evidence_available"
            var art:String=coverage.get("coverage",coverage).get(kind,{}).get(id,"not_assessed")
            var entry={"key":key,"id":str(id),"kind":kind,"label":_label(str(id)),"category":category(kind),"group":_group(kind,str(id),definition),"definition":definition,"cases":linked,"source_status":art,"scenario_status":scenario,"presentation_status":provider,"approval_status":approval,"requirements":[],"scenarios":[]}
            var listed:bool=id in snapshot.get("ids",{}).get(kind,{})
            entry.inventory_origin="server_snapshot" if listed else "typed_source"
            entry.engine_inventory="listed" if listed else "not_listed"
            # Neither source presence nor catalogue membership proves that an
            # actual actor is offered this action by the current server.
            entry.runtime_availability="unknown"
            entry.source_path=source_inventory.get(kind,{}).get(id,{}).get("source_path","")
            _evidence_fields(entry,witnesses)
            entries.append(entry);by_key[key]=entry
            if not categories.has(entry.category):categories[entry.category]=[]
            categories[entry.category].append(entry)
            if not counts.has(kind):counts[kind]=0
            counts[kind]+=1
    # Interactions are scenario capabilities rather than additional server IDs.
    for record in cases:
        if record.get("kind")!="interaction":continue
        var key="interaction:"+record.id
        if by_key.has(key):continue
        var entry={"key":key,"id":record.id,"kind":"interaction","label":record.label,"category":"Interactions","group":record.interaction,"definition":{},"cases":[record],"source_status":"not_assessed","scenario_status":record.scenario_status,"presentation_status":"not_assessed","approval_status":"needs_review","requirements":[],"scenarios":[]}
        _evidence_fields(entry,record.witnesses);entry.presentation_status=record.evidence_status
        entries.append(entry);by_key[key]=entry
        if not categories.has("Interactions"):categories.Interactions=[]
        categories.Interactions.append(entry)
    entries.sort_custom(func(a,b):return a.label.naturalnocasecmp_to(b.label)<0 if a.category==b.category and a.group==b.group else (a.group.naturalnocasecmp_to(b.group)<0 if a.category==b.category else CAPABILITIES.find(a.category)<CAPABILITIES.find(b.category)))
    return {"entries":entries,"by_key":by_key,"categories":categories,"records":cases,"counts":counts,"engine":index.get("engine",{}),"expected_engine":snapshot.get("header",{}),"factory_version":package,"evidence_scope":evidence.get("scope","No saved native/audio evidence join is available.")}
static func catalog()->Dictionary:
    var sources:Dictionary={}
    for path in [ABILITIES,"res://authoring/characters.tres","res://authoring/environment.tres"]:
        var root:Resource=load(path)
        if root==null:continue
        var listed:Dictionary=declared(root)
        for kind in listed:
            if not sources.has(kind):sources[kind]={}
            sources[kind].merge(listed[kind],false)
    return build(_read(SERVER_IDS),_read(COVERAGE),_read(INDEX),true,sources,_read(EVIDENCE),str(_read(PACKAGE).get("version","")))

static func matches(entry:Dictionary,query:String,category_name:String="",status:String="")->bool:
    if not category_name.is_empty() and entry.category!=category_name:return false
    if not query.strip_edges().is_empty():
        var text=entry.id+" "+entry.label+" "+entry.group
        for record in entry.cases:text+=" "+record.id+" "+record.label+" "+str(record.get("reason",""))
        if not query.strip_edges().to_lower() in text.to_lower():return false
    match status:
        "recorded":return entry.scenario_status=="recorded"
        "missing_recording":return entry.scenario_status=="missing"
        "recording_failure":return not entry.scenario_status in ["recorded","missing"]
        "evidence":return not entry.get("output_witnesses",[]).is_empty()
        "unwitnessed":return entry.get("output_witnesses",[]).is_empty()
        "current_evidence":return not entry.get("current_output_witnesses",[]).is_empty()
        "package_evidence":return not entry.get("matching_package_output_witnesses",[]).is_empty()
        "historical_evidence":return not entry.get("historical_output_witnesses",[]).is_empty()
        "reader_evidence":return not entry.get("reader_witnesses",[]).is_empty()
        "command_evidence":return not entry.get("command_witnesses",[]).is_empty()
        "audio_evidence":return not entry.get("audio_witnesses",[]).is_empty()
        "needs_review":return entry.approval_status=="needs_review"
        "rejected":return entry.approval_status=="rejected"
        "source_gap":return not entry.source_status in ["ready","available","internal","explicit_none","state_only"]
    return true
static func scenario(record:Dictionary)->Dictionary:
    return {"id":record.id,"label":record.label,"expectations":record.get("expectations",[]),"moments":record.get("moments",[]),"recordings":[{"available":record.ready,"record":record}]}

static func resolve_moments(index:Dictionary,moments:Array,perspective_id:String="")->Array:
    # Occurrences are native packet-local facts. A hidden or absent fact is
    # unavailable in this view; it must never jump to an unrelated event.
    var observed={};var result:Array=[]
    for row in index.get("rows",[]):
        if row.get("kind")!="event":continue
        var event:Dictionary=row.event
        var key="%d:%d"%[int(event.sequence),int(event.event_uuid)]
        observed[key]=row
        for version in event.get("versions",[]):
            observed["%d:%d"%[int(event.sequence),int(version.occurrence)]]=row
    for original in moments:
        if not perspective_id.is_empty() and str(original.get("faction","amber"))!=perspective_id:continue
        var moment:Dictionary=original.duplicate()
        var key="%d:%d"%[int(moment.get("sequence",-1)),int(moment.get("occurrence",-1))]
        var row:Dictionary=observed.get(key,{})
        var lineage=str(int(moment.lineage)) if moment.has("lineage") else ""
        moment.available=not row.is_empty() and (lineage.is_empty() or lineage==str(row.event.lineage_uuid))
        if moment.available:
            moment.at_ms=row.start_ms;moment.row_id=row.id
        else:moment.reason="Not observed in this recorded faction"
        result.append(moment)
    return result
