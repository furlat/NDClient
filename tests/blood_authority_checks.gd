extends SceneTree
## Real SDK damage -> shared compiler -> passive Studio requirements.
## Variants are presentation-boundary checks, never authored server recordings.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Recording=preload("res://studio/recording.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("BLOOD_AUTHORITY_FAIL ",label)

func damage_node(packet:Dictionary,identity:String="")->Dictionary:
    for lineage in packet.lineages:
        for node in lineage.events:
            var fact:Dictionary=node.fact if node.get("fact")!=null else {}
            if identity.is_empty():
                if fact.get("kind")=="damage" and fact.get("stage")=="applied" and fact.get("body_release")!=null and fact.body_release.release_id=="body.blood":return node
            elif node.uuid==identity:return node
    return {}

func verify(before:Dictionary,packet:Dictionary,identity:String,cache:Dictionary,label:String,air:bool,residue:bool)->void:
    var held_before=before.duplicate(true);var held_packet=packet.duplicate(true)
    var result=Compiler.compile(before,packet,cache)
    check(result.ok,label+": public presentation compile succeeds")
    if not result.ok:return
    var blood:Array=[];var ground:Array=[];var requirements:Array=[];var audio:Array=[]
    for group in result.value.groups:
        for component in group.components:
            if component.source_event_uuid!=identity:continue
            if str(component.get("source_id","")).begins_with("blood.") or component.kind=="residue_deposit":
                blood.append(component)
                if component.kind=="residue_deposit":ground.append(component)
            if component.kind=="audio" and component.get("cue_id")=="physical_impact":audio.append(component)
        for event in group.events:
            if event.event_uuid==identity:
                for requirement in event.components:
                    if requirement.kind=="residue_deposit":requirements.append(requirement)
    check(blood.size()==(1 if air else 0),label+": blood requires explicit ordinary blood release")
    check(ground.size()==(1 if residue else 0),label+": ground renderer requires disclosed receiving regions")
    check(requirements.size()==(1 if residue else 0),label+": ground presentation exists only for disclosed residue regions")
    var node=damage_node(packet,identity)
    if not node.canceled and node.fact.get("applied_damage",0)>0:
        check(audio.size()==1,label+": physical contact audio is independent from blood authorization")
    if air and blood.size()==1 and not residue:
        check(blood[0].attachment=="impact" and blood[0].residue_deposition==false,label+": finite air response makes no residue claim")
        check(blood[0].body_release==node.fact.body_release,label+": exact disclosed release retained without geometry substitution")
        var expected=Compiler.Authoring.load_data("native_effects/responses.json",cache)
        check(blood[0].source_id==expected.damage_types.get(str(node.fact.body_release.primary_damage_type),expected.default),label+": source follows release primary damage type")
    if residue and requirements.size()==1:
        var requirement:Dictionary=requirements[0]
        check(requirement.status=="playing" and not requirement.trace_track_id.is_empty(),label+": actual deposit has one executable track")
        check(ground[0].body_release==node.fact.body_release,label+": executable deposit preserves admitted tiles, ellipses and elevation")
        check(requirement.timing.resolved and ground[0].duration_ms>0,label+": finite landing clock is resolved; persistence follows actual tile state")
    check(before==held_before and packet==held_packet,label+": compiler preserves caller snapshots")
    evidence.append({"case":label,"air_components":blood.size(),"ground_components":ground.size(),"residue_tracks":requirements.size()})

func run()->void:
    var directory="";var output="res://generated/blood_authority_checks.json";var sequence=9
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
        elif argument.begins_with("--sequence="):sequence=argument.trim_prefix("--sequence=").to_int()
        elif argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    if directory.is_empty() or sequence<1:
        print("Usage: --recording=<real SDK journal> --sequence=<operation with body.blood> [--output=<report>]");quit(2);return
    var journal=Journal.new()
    var opened=journal.open(directory,true,false)
    check(opened.ok,"Actual current-protocol journal opens")
    if not opened.ok:quit(1);return
    var replayed=journal.replay(sequence-1)
    check(replayed.ok,"Public journal admits the exact operation-before prefix")
    if not replayed.ok:quit(1);return
    var raw=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
    var decoded=journal.protocol.decode("PlayerOperation",raw)
    check(decoded.ok,"Actual raw operation passes strict SDK admission")
    if not decoded.ok:quit(1);return
    var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
    var node=damage_node(packet)
    check(not node.is_empty(),"Actual operation contains an explicit ordinary blood release")
    if node.is_empty():quit(1);return
    var identity:String=node.uuid;var release:Dictionary=node.fact.body_release
    check(not release.regions.is_empty(),"Actual operation provides deposited receiving regions")
    var positions:Array=[]
    for region in release.regions:positions.append_array(region.positions)
    check(positions.size()>9,"Real region exceeds the removed generic three-by-three deposit support")
    var cache={}
    verify(journal.state,packet,identity,cache,"original recorded release",true,true)
    for mode in ["null release","omitted release","empty receiving regions","bone release","corrosive release","dread release","zero applied damage","canceled damage"]:
        var variant=packet.duplicate(true);var changed=damage_node(variant,identity)
        match mode:
            "null release":changed.fact.body_release=null
            "omitted release":changed.fact.erase("body_release")
            "empty receiving regions":changed.fact.body_release.regions=[];changed.fact.body_release.deposited_position=null
            "bone release":changed.fact.body_release.release_id="body.bone"
            "corrosive release":changed.fact.body_release.release_id="body.corrosive_blood"
            "dread release":changed.fact.body_release.release_id="body.dread_blood"
            "zero applied damage":changed.fact.applied_damage=0
            "canceled damage":changed.canceled=true
        verify(journal.state,variant,identity,cache,mode,mode=="empty receiving regions",false)
    var index=Recording.read(directory)
    check(index.ok,"Studio reads the same real journal")
    if index.ok:
        var rows:Array=index.rows.filter(func(row):return row.kind=="residue_deposit" and row.get("source_event_uuid")==identity)
        check(rows.size()==1,"Studio exposes actual landing track under damage occurrence")
        if rows.size()==1:
            check(rows[0].component.kind=="residue_deposit" and rows[0].component.duration_ms>0,"Studio retains the finite authored landing clock")
            check(rows[0].component.body_release==release,"Studio inspector retains exact authoritative receiving geometry")
        check(not index.rows.any(func(row):return row.get("component",{}).get("source_id","").begins_with("blood.deposit")),"Studio has no fabricated ground blood track")
    var report={"checks":checks,"failures":failures,"recording":directory,"sequence":sequence,"event_uuid":identity,"authoritative_receiving_tiles":positions.size(),"evidence":evidence,"invocation":Array(OS.get_cmdline_user_args()),"scope":"Real raw Hide damage plus explicitly labeled passive boundary variants. Public compiler and Studio index only; native appearance is qualified separately by studio_blood_residue_checks."}
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BLOOD_AUTHORITY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
