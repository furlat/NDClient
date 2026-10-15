extends RefCounted
## Browse the plan's case families using the existing qualified capture inventory.
const CAPABILITIES=["Move","Dash","Dodge","Disengage","Hide","Jump","Traverse window","Attack","Opportunity attack","Shove","Damage / life","Action economy","Conditions","Spell composition","Combined regression"]
const CASES={
    "gallery_sorcerer":["Spell composition","Large-map expedition","Sorcerer expedition · Lantern Gallery"],
    "movement-oa":["Opportunity attack","Movement interruption","Movement with opportunity attacks"],
    "walk":["Move","Cardinal route","Ordinary movement"],
    "walk_diagonal":["Move","Cardinal / diagonal","Diagonal route"],
    "elevation":["Move","Elevation / connectors","Raised support route"],
    "jump":["Jump","Takeoff / landing","Uninterrupted jump"],
    "oa_jump":["Jump","Opportunity attack","Jump with reaction"],
    "oa_jump_lethal":["Jump","Lethal interruption","Lethal reaction during jump"],
    "oa_jump_late_lethal":["Jump","Lethal interruption","Late lethal reaction"],
    "window":["Traverse window","Cleared aperture","Crossing both directions"],
    "window_break":["Traverse window","Blocked → cleared","Break window, then cross"],
    "melee":["Attack","Melee","Melee attack"],
    "ranged":["Attack","Ranged","Ranged attack"],
    "dying":["Damage / life","Dying / death saves","Damage → Dying → failed death saves → Dead"],
    "shove":["Shove","Push / refusal","Shove"],
    "dash":["Dash","Opportunity-attack interaction","Dash movement provoking an attack"],
    "dash_comparison":["Dash","Movement allowance comparison","Ordinary movement → Dash → equal-distance movement"],
    "dodge":["Dodge","Avoidance / expiry","Dodge, actual miss and expiry"],
    "disengage":["Disengage","Reaction suppression","Move without opportunity attack"],
    "hide":["Hide","Apply / move / attack","Hide and subsequent attack"],
    "hide_light":["Hide","Illumination / reveal","Torch: dim → bright → reveal"],
    "action_economy":["Action economy","Extra Attack / Action Surge","Four attacks across Action Surge"],
    "poisoned":["Conditions","Initialization / removal","Poisoned, then restored"],
    "prone":["Shove","Prone / stand","Initially prone, then stand"],
    "rage":["Conditions","Persistent material / movement","Frenzy and movement"],
    "invisibility":["Conditions","Perception","Invisibility → unseen movement → See Invisibility"],
    "condition_suppression":["Conditions","Suppression / restoration","Antimagic suppression lifecycle"],
    "condition_owners":["Conditions","Multiple owners","Shared paralysis, individual removal"],
    "magic_missile":["Spell composition","Repeated recipients","Magic Missile A → B → A"],
    "hold_person":["Spell composition","Persistent attached effect","Hold Person lifecycle"]}

static func read()->Array:
    var path="res://generated/studio_case_inventory.json"
    if not FileAccess.file_exists(path):return _spell_cases()
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var result:Array=[]
    for item in inventory.get("cases",[]):
        var descriptor_path:String=item.descriptor
        if not descriptor_path.begins_with("res://"):descriptor_path="res://"+descriptor_path
        if not FileAccess.file_exists(descriptor_path):continue
        var descriptor:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(descriptor_path))
        var kind:String=descriptor.get("case","")
        if kind.is_empty() and item.name=="movement-oa":kind="movement-oa"
        if not CASES.has(kind):continue
        var fields:Array=CASES[kind]
        var label:String=fields[2]
        var outcomes:Dictionary=item.get("attack_outcomes",{})
        if kind in ["melee","ranged"] and not outcomes.is_empty():label+=" · "+" / ".join(outcomes.keys())
        if kind=="shove":label+=" · "+("push" if item.get("facts",{}).get("forced_movement",0)>0 else "refused")
        var journal:String=item.journal
        var base=journal.get_base_dir()
        var perspectives:Array=[]
        if base.get_file() in ["amber","blue"]:
            var owner=base.get_base_dir()
            for audience in ["amber","blue"]:
                var candidate=owner.path_join(audience).path_join("journal")
                if FileAccess.file_exists(candidate.path_join("0000000000000000.json")):
                    perspectives.append({"id":audience,"label":audience.capitalize(),"journal":candidate})
        else:perspectives.append({"id":"recorded","label":"Recorded audience","journal":journal})
        if perspectives.is_empty():continue
        result.append({"id":item.name,"capability":fields[0],"interaction":fields[1],"label":label,
            "perspectives":perspectives,"interval":item.get("interval",{}),"descriptor":descriptor_path,
            "qualification":descriptor.get("qualification",""),"checks":item.get("checks",0)})
    result.append_array(_spell_cases())
    return result

static func _spell_cases()->Array:
    var path="res://generated/studio_spell_case_inventory.json"
    if not FileAccess.file_exists(path):return []
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var result:Array=[]
    for item in inventory.get("cases",[]):
        if not item.get("failures",[]).is_empty():continue
        var perspectives:Array=[]
        for perspective in item.get("perspectives",[]):
            if FileAccess.file_exists(str(perspective.journal).path_join("0000000000000000.json")):
                perspectives.append(perspective)
        if perspectives.is_empty():continue
        result.append({"id":item.id,"spell_id":item.spell_id,
            "capability":item.capability,"interaction":item.interaction,"label":item.label,
            "perspectives":perspectives,"interval":item.get("interval",{}),"descriptor":item.descriptor,
            "qualification":item.qualification,"checks":item.get("checks",0),"inventory":path})
    return result
