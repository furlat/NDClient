extends SceneTree
## Two unchanged original positive packets. This tests a missing reference;
## absent public selectors never become a guessed elemental presentation.
const Protocol=preload("res://sdk/protocol.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Actions=preload("res://presentation/native_action_authoring.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ROOT="res://tests/fixtures/schema16/condition-ownership/summon-dragon"
const SPELL="spell.summon_dragon"
const CONDITION="condition.spell.summon_dragon.shared_resistance"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("CONDITION_OWNER_REFERENCE_FAIL ",label)
func run()->void:
    var entry:Resource=load("res://authoring/abilities/spells/"+SPELL+".tres")
    check(entry.id==SPELL and CONDITION in entry.applies_conditions,"Typed reference includes the condition the real summon applies")
    check(Array(entry.applies_conditions).count(CONDITION)==1,"Actual shared-resistance reference is declared once")
    var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("recording.json")))
    check(metadata.ok and metadata.engine.commit=="211b71134ed15c89e62232587381f7e15a5961c3" and metadata.engine.player_schema_version==16,"Original capture metadata identifies the frozen schema16 run")
    check(CONDITION in metadata.summary.conditions,"Unchanged original recording summary independently names the positive membership")
    var selections:Array=Effects.conditions(CONDITION)
    check(selections.size()==5 and selections.all(func(selection):return selection.condition.owner_ids==[CONDITION] and selection.condition.when.has("damage_type")),"All five Factory variants declare this exact owner and require an actual damage_type selector")
    var count:int=0
    for seat in ["amber","blue"]:
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(ROOT.path_join(seat+".json"))
        var protocol:RefCounted=Protocol.new(Protocol.PRE_REVIEW_SCHEMA,Protocol.PRE_REVIEW_IDENTITY)
        var decoded:Dictionary=protocol.decode_recorded("PlayerOperation",raw)
        check(decoded.ok,seat+" original complete packet admits through its exact recorded protocol")
        if not decoded.ok:continue
        var packet:Dictionary=decoded.value
        check(packet.cursor.sequence==8,seat+" original packet cursor remains intact")
        var unchanged:PackedByteArray=var_to_bytes(packet)
        for original in packet.lineages:
            var lineage:Dictionary=Occurrences.group(original)
            var casts:Array=lineage.events.filter(func(node):return node.get("fact")!=null and node.fact.get("behavior_id")==SPELL and not node.canceled)
            if casts.is_empty():continue
            check(casts.size()==1,seat+" original lineage contains one actual summon cast")
            var cast:Dictionary=casts[0];var graph:Dictionary={"nodes":{}}
            for node in lineage.events:graph.nodes[node.lineage_id]=node
            for node in lineage.events:
                if node.canceled or node.get("fact")==null or node.fact.kind!="actor_change":continue
                for actor in node.fact.actors:
                    for row in actor.rows:
                        if row.field!="condition" or row.get("member")==null or row.member.behavior_id!=CONDITION:continue
                        count+=1
                        check(Actions.descendant(node,cast,graph),seat+" exact native parent lineage links the positive membership to this summon")
                        check(actor.actor_uuid==cast.fact.source_entity_uuid,seat+" actual caster receives the shared condition")
                        check(row.condition_uuid==row.member.condition_uuid and row.member.state.condition_uuid==row.condition_uuid,seat+" actual public membership identity is preserved")
                        check(row.member.state.get("energy_type")==null and not row.member.state.has("damage_type"),seat+" original public state does not disclose an elemental selector")
                        check(Persistent.lifecycles(row.member).is_empty(),seat+" absent selector cannot select an elemental Factory lifecycle")
                        check(entry.owner_ids.is_empty(),seat+" reference correction does not invent a cast/condition source handover")
                        evidence.append({"seat":seat,"sequence":packet.cursor.sequence,"cast_occurrence":cast.id,"cast_lineage":cast.lineage_id,
                            "membership_occurrence":node.id,"membership_lineage":node.lineage_id,"native_parent_occurrence":node.parent_event,
                            "condition_uuid":row.condition_uuid,"actor_uuid":actor.actor_uuid,"variant_selected":false})
        check(var_to_bytes(packet)==unchanged,seat+" inspection preserves every original wire value")
    check(count==2,"Both independent original journals positively disclose the referenced condition")
    print("CONDITION_OWNER_REFERENCES ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Exact positive source/condition reference and absent-selector nonselection only; no elemental variant, Factory source completeness, pixels or visual approval is claimed."}))
    quit(0 if failures.is_empty() else 1)
