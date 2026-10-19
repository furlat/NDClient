extends SceneTree
## Offline input snapshot for typed spell/lifecycle handover migration.
const Common=preload("res://tools/presentation_build/common.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var report:Dictionary=Common.report();var source:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var result:Dictionary={"spells":{},"conditions":{},"errors":report.errors}
    for id in source.entries.spells:
        var entry:Resource=source.entries.spells[id]
        var row:Dictionary={"source":entry.resource_path,"delivery":entry.delivery,"summons":Array(entry.summons),"applies_conditions":Array(entry.applies_conditions),"applies_surfaces":Array(entry.applies_surfaces),"owner_kind":entry.owner_kind,"owner_ids":Array(entry.owner_ids),"owner_cues":Array(entry.owner_cues),"excluded_cues":Array(entry.excluded_cues),"event_cues":Array(entry.event_cues),"explicit_event_cues":entry.explicit_event_cues,"native_staging":entry.native_staging,"status":entry.status,"notes":entry.notes,"effects":[]}
        for effect in entry.effects:row.effects.append({"clip":effect.clip,"role":effect.role,"attachment":effect.attachment,"at":effect.at,"lifecycle":effect.lifecycle,"extra":effect.extra})
        result.spells[id]=row
    for id in source.entries.conditions:
        var entry:Resource=source.entries.conditions[id]
        result.conditions[id]={"source":entry.resource_path,"play_package_lifecycle":entry.play_package_lifecycle,"owner_spell":entry.owner_spell,"status":entry.status,"notes":entry.notes}
    FileAccess.open("res://.runtime/condition-handover-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  ",true))
    print(JSON.stringify({"spells":result.spells.size(),"conditions":result.conditions.size(),"errors":report.errors}));quit(0 if report.errors.is_empty() else 1)
