extends SceneTree
## Offline source/case inventory for report_factory_integration_coverage.py.
## Runtime discovery still reads only root path maps, never this full export.
const Library=preload("res://studio/case_library.gd")
const Build=preload("res://tools/presentation_build/abilities.gd")
const Fields=preload("res://tools/presentation_build/ability_fields.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
    var catalog:Dictionary=Library.catalog()
    var output={"generated_utc":Time.get_datetime_string_from_system(true),"engine":catalog.engine,"expected_engine":catalog.expected_engine,
        "counts":catalog.counts,"entries":[],"typed":{}}
    for entry in catalog.entries:
        var row=entry.duplicate()
        row.erase("definition");row.erase("cases")
        row.cases=[]
        for case in entry.cases:
            row.cases.append({"id":case.id,"status":case.scenario_status,"ready":case.ready,"reason":case.get("reason",""),
                "subjects":case.get("subjects",{}),"studio_checked":case.get("studio_checked",false),
                "errors":case.get("errors",[]),"journals":case.get("journals",{}),"moments":case.get("moments",[])})
        output.entries.append(row)
    var root:Resource=load("res://authoring/abilities.tres")
    for section in ["spells","conditions","actions"]:
        output.typed[section]={}
        for id in root.sections.get(section,{}):
            var path:String=root.sections[section][id]
            var e:Resource=load(path)
            var row={"source":path,"status":e.status,"notes":e.notes,"icon":{}}
            if e.icon!=null:row.icon={"path":e.icon.path,"status":e.icon.status,"reuses":e.icon.reuses,"source":e.icon.source}
            if section=="conditions":
                row.merge({"play_package_lifecycle":e.play_package_lifecycle,"owner_spell":e.owner_spell,"surface":e.surface,
                    "has_look":e.look!=null,"appearance_layers":e.appearance_layers,"has_layers":not e.layers.is_empty(),"has_poses":not e.poses.is_empty(),"disposition":e.disposition})
            else:
                row.effects=[]
                for i in e.effects.size():row.effects.append(Build.action_cue(e.effects[i],i))
                row.body={"clip":e.body.clip,"markers":e.body.markers} if e.body!=null else {}
                if section=="spells":
                    row.merge({"native_staging":e.native_staging,"owner_kind":e.owner_kind,"owner_ids":Array(e.owner_ids),"owner_cues":Array(e.owner_cues),
                        "event_cues":Array(e.event_cues),"explicit_event_cues":e.explicit_event_cues,"excluded_cues":Array(e.excluded_cues),"variants":[]})
                    for variant in e.variants:
                        var cues=[]
                        for i in variant.effects.size():cues.append(Build.action_cue(variant.effects[i],i))
                        row.variants.append({"id":variant.id,"effects":cues})
                else:row.merge({"kind":e.kind,"plays":e.plays,"disposition":e.disposition,"effect_sources":Array(e.effect_sources),"applies_conditions":Array(e.applies_conditions),"legacy_media_count":e.unported.get("media",[]).size()})
            output.typed[section][id]=Fields.plain(row)
    var file=FileAccess.open("res://.runtime/factory-catalog-join-input.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(output,"  "));file.close()
    print(JSON.stringify({"entries":output.entries.size(),"typed_spells":output.typed.spells.size(),"typed_conditions":output.typed.conditions.size(),"typed_actions":output.typed.actions.size()}))
    quit()
