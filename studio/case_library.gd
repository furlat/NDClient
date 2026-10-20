extends RefCounted
## One authoring-organized library. Record availability, art, render proof and approval are separate facts.
const CAPABILITIES=["Spells","Conditions","Actions","Characters","Environment","Surfaces","Items","Interactions","Rules"]
const INDEX="res://.runtime/studio-library/index.json"
const SERVER_IDS="res://authoring/server_ids.json"
const COVERAGE="res://build/presentation/coverage.json"
const ABILITIES="res://authoring/abilities.tres"
const CATEGORY={"spell":"Spells","condition":"Conditions","action":"Actions","reaction":"Actions","trait":"Actions","class_feature":"Actions","feat":"Actions","creature":"Characters","environment_object":"Environment","boundary_structure":"Environment","connector":"Environment","battlefield":"Environment","spatial_effect":"Surfaces","residue":"Surfaces","item":"Items","interaction":"Interactions"}
const REJECTED=["spell.aid","spell.bless","spell.false_life","spell.sacred_flame"]

static func _read(path:String)->Dictionary:
    if not FileAccess.file_exists(path):return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path));return value if value is Dictionary else {}
static func category(kind:String)->String:return CATEGORY.get(kind,"Rules")
static func _label(id:String)->String:return id.get_slice("@",0).get_file().get_slice("/",0).split(".")[-1].replace("_"," ").capitalize()
static func _same_engine(expected:Dictionary,actual:Dictionary)->bool:
    for field in ["commit","protocol_version","player_schema_version","schema_digest"]:
        if expected.get(field)!=actual.get(field):return false
    return true
static func _record(original:Dictionary,engine:Dictionary,expected:Dictionary,check_files:bool)->Dictionary:
    var result=original.duplicate();var kind:String=result.get("kind","interaction");result.capability=category(kind)
    result.label=result.get("title",result.get("label",result.id));result.interaction=str(result.get("family",kind.capitalize()));result.perspectives=[]
    for faction in result.get("journals",{}):
        var journal:String=result.journals[faction]
        if not check_files or FileAccess.file_exists(journal.path_join("0000000000000000.json")):result.perspectives.append({"id":faction,"label":str(faction).capitalize(),"journal":journal})
    result.perspectives.sort_custom(func(a,b):return a.id<b.id)
    var state:String=result.get("status","failed")
    if not _same_engine(expected,result.get("engine",engine)):state="stale"
    elif not result.get("errors",[]).is_empty():state="failed"
    elif state=="recorded" and result.perspectives.is_empty():state="missing_journal"
    result.scenario_status=state;result.ready=state=="recorded" and not result.perspectives.is_empty()
    result.interval=result.get("interval",{});result.descriptor=result.get("scenario","");result.qualification="studio_checked" if result.get("studio_checked",false) else "not_checked";result.checks=result.get("checks",0)
    return result

static func records(index:Dictionary,snapshot:Dictionary,check_files:bool=true)->Array:
    var result:Array=[]
    for row in index.get("cases",[]):result.append(_record(row,index.get("engine",{}),snapshot.get("header",{}),check_files))
    return result
static func read()->Array:
    return records(_read(INDEX),_read(SERVER_IDS))
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

static func build(snapshot:Dictionary,coverage:Dictionary,index:Dictionary,check_files:bool=true,source_inventory:Dictionary={})->Dictionary:
    var cases=records(index,snapshot,check_files);var entries:Array=[];var by_subject={};var by_key={};var categories={};var counts={}
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
            var provider="not_assessed";var approval="rejected" if id in REJECTED else "needs_review"
            for record in linked:
                var qualified:Dictionary=record.get("presentation",{}).get(str(id),{})
                if not qualified.is_empty():provider=qualified.get("status",provider)
                var reviews:Dictionary=record.get("visual_review",{})
                if reviews.has(id) and not id in REJECTED:approval=reviews[id]
            var art:String=coverage.get("coverage",coverage).get(kind,{}).get(id,"not_assessed")
            var entry={"key":key,"id":str(id),"kind":kind,"label":_label(str(id)),"category":category(kind),"group":_group(kind,str(id),definition),"definition":definition,"cases":linked,"source_status":art,"scenario_status":scenario,"presentation_status":provider,"approval_status":approval,"requirements":[],"scenarios":[]}
            var listed:bool=id in snapshot.get("ids",{}).get(kind,{})
            entry.inventory_origin="server_snapshot" if listed else "typed_source"
            entry.engine_inventory="listed" if listed else "not_listed"
            # Neither source presence nor catalogue membership proves that an
            # actual actor is offered this action by the current server.
            entry.runtime_availability="unknown"
            entry.source_path=source_inventory.get(kind,{}).get(id,{}).get("source_path","")
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
        entries.append(entry);by_key[key]=entry
        if not categories.has("Interactions"):categories.Interactions=[]
        categories.Interactions.append(entry)
    entries.sort_custom(func(a,b):return a.label.naturalnocasecmp_to(b.label)<0 if a.category==b.category and a.group==b.group else (a.group.naturalnocasecmp_to(b.group)<0 if a.category==b.category else CAPABILITIES.find(a.category)<CAPABILITIES.find(b.category)))
    return {"entries":entries,"by_key":by_key,"categories":categories,"records":cases,"counts":counts,"engine":index.get("engine",{}),"expected_engine":snapshot.get("header",{})}
static func catalog()->Dictionary:
    var root:Resource=load(ABILITIES)
    return build(_read(SERVER_IDS),_read(COVERAGE),_read(INDEX),true,declared(root) if root!=null else {})
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
