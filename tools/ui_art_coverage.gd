extends SceneTree
## Offline catalog-wide image evidence. This is not a runtime presentation catalog.
const Common=preload("res://tools/presentation_build/common.gd")
const AbilityBuild=preload("res://tools/presentation_build/abilities.gd")
const CharacterBuild=preload("res://tools/presentation_build/characters.gd")
const UI=preload("res://presentation/ui_catalog.gd")
const ICON_KINDS=["spell","condition","action","reaction","class_feature","trait","feat","item"]
static func image_record(image:Resource,built:Dictionary)->Dictionary:
    if image==null:return {"status":"missing","art":"missing","path":"","exists":false,"built_matches":built.is_empty()}
    var path:String="res://assets/"+image.path
    var exists:bool=FileAccess.file_exists(path)
    var generic_assignment:bool=image.source.contains("icon:ui.filter-") or image.source.ends_with("icon:condition.generic") or image.reuses.begins_with("ui.filter-") or image.reuses=="condition.generic"
    var art:String="missing" if not exists or image.status=="missing" else "placeholder" if generic_assignment else "shared" if not image.reuses.is_empty() else "assigned"
    var selected:Dictionary=UI._image(built)
    var dimensions:Array=[]
    if exists:
        var source=FileAccess.open(path,FileAccess.READ);var bytes:PackedByteArray=source.get_buffer(24);source.close()
        if bytes.size()==24 and bytes[0]==137 and bytes[1]==80:
            dimensions=[(int(bytes[16])<<24)|(int(bytes[17])<<16)|(int(bytes[18])<<8)|int(bytes[19]),(int(bytes[20])<<24)|(int(bytes[21])<<16)|(int(bytes[22])<<8)|int(bytes[23])]
    return {"status":image.status,"art":art,"path":path,"exists":exists,"size":dimensions,"reuses":image.reuses,"source":image.source,
        "built_matches":selected.get("path","")==path and selected.get("rect",[])==([image.rect.position.x,image.rect.position.y,image.rect.size.x,image.rect.size.y] if image.rect.has_area() else [])}

static func inventory(abilities:Dictionary,characters:Dictionary,ids:Dictionary,maps:Dictionary)->Dictionary:
    var result:Dictionary={"icons":{},"portraits":{},"player_portraits":{},"summary":{"icons":{},"portraits":{}},"errors":[]}
    for kind in ICON_KINDS:
        var entries:Dictionary=(characters.get("gear",{}) if kind=="item" else abilities.get("spells",{}) if kind=="spell" else abilities.get("conditions",{}) if kind=="condition" else abilities.get("actions",{})).duplicate()
        if kind!="item":
            for section in ["spells","conditions","actions"]:
                for id in abilities.get(section,{}):
                    if str(id).get_slice(".",0)!=kind:continue
                    # Lifecycle sources can be the only typed owner of a
                    # class feature. Match the existing builder/browser owner
                    # rule, including their preference for a canonical action.
                    var owner:String="spells" if kind=="spell" else "conditions" if kind=="condition" else "actions"
                    if section!=owner and abilities.get(owner,{}).has(id):continue
                    entries[id]=abilities[section][id]
        var rows:Dictionary={};var counts:Dictionary={"total":0,"server_ids":0,"typed_only":0,"assigned":0,"shared":0,"placeholder":0,"missing":0,"built_mismatch":0,"stand_in":0}
        var members:Dictionary=ids.get(kind,{}).duplicate()
        for id in entries:
            if str(id).get_slice(".",0)==kind:members[id]=true
        for id in members:
            var entry:Resource=entries.get(id)
            var image:Resource=entry.icon if entry!=null else null
            var row:Dictionary=image_record(image,maps.icons.get(id,{}));row.authoring=entry.resource_path if entry!=null else "";row.owner_status=entry.status if entry!=null else "missing"
            row.availability="server_id" if ids.get(kind,{}).has(id) else "typed_only"
            counts.server_ids+=int(row.availability=="server_id");counts.typed_only+=int(row.availability=="typed_only")
            rows[id]=row;counts.total+=1;counts[row.art]+=1;counts.stand_in+=int(row.status=="stand_in");counts.built_mismatch+=int(not row.built_matches)
            if not row.exists:result.errors.append("No image for "+kind+":"+id)
            if not row.built_matches:result.errors.append("Built image differs from its typed owner: "+kind+":"+id)
        result.icons[kind]=rows;result.summary.icons[kind]=counts
    var banks:Dictionary={}
    for bank in characters.get("portraits",{}).values():
        for id in bank.portraits:banks[id]=bank.portraits[id]
    var counts:Dictionary={"total":0,"assigned":0,"shared":0,"placeholder":0,"missing":0,"built_mismatch":0,"body_stand_in":0,"portrait_stand_in":0}
    for id in ids.get("creature",{}):
        var entry:Resource=characters.get("characters",{}).get(id)
        var key:String=entry.portrait if entry!=null else ""
        var row:Dictionary=image_record(banks.get(key),maps.portraits.get(key,{}));row.portrait=key;row.authoring=entry.resource_path if entry!=null else "";row.body_status=entry.status if entry!=null else "missing";row.binding_status=entry.portrait_status if entry!=null else "missing"
        row.built_matches=row.built_matches and maps.creature_portraits.get(id,"")==key
        result.portraits[id]=row;counts.total+=1;counts[row.art]+=1;counts.built_mismatch+=int(not row.built_matches);counts.body_stand_in+=int(row.body_status=="stand_in");counts.portrait_stand_in+=int(row.binding_status=="stand_in")
        if not row.exists:result.errors.append("No portrait for creature:"+id)
        if not row.built_matches:result.errors.append("Built portrait differs from its typed owner: "+id)
    result.summary.portraits=counts
    var player:Resource=characters.get("portraits",{}).get("player")
    if player!=null:
        for id in player.portraits:result.player_portraits[id]=image_record(player.portraits[id],maps.portraits.get(id,{}))
        result.player_aliases=player.aliases
    return result

func _initialize()->void:run.call_deferred()
func run()->void:
    var write_icons:bool=false;var output:String="res://generated/reports/ui-art-coverage.json"
    for argument in OS.get_cmdline_user_args():
        if argument=="--write-icons":write_icons=true
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    var report:Dictionary=Common.report()
    var abilities:Dictionary=Common.load_root("res://authoring/abilities.tres",report)
    var characters:Dictionary=Common.load_root("res://authoring/characters.tres",report)
    if write_icons:
        # The ordinary builders' own functions; no alternative merge algorithm.
        var file=FileAccess.open("res://build/presentation/abilities/icons.json",FileAccess.WRITE)
        file.store_string(JSON.stringify({"domain":"abilities","root":"res://assets/","icons":AbilityBuild.icons(abilities.entries)},"  "));file.close()
        CharacterBuild._icons({"report":report},characters.entries,"res://build/presentation/characters")
    var result:Dictionary=inventory(abilities.entries,characters.entries,Common.server_ids().get("ids",{}),UI.icon_maps())
    result.engine=Common.server_ids().get("header",{});result.errors.append_array(report.errors)
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  ",true))
    print("UI_ART_COVERAGE ",JSON.stringify({"summary":result.summary,"errors":result.errors,"output":output}))
    quit(0 if result.errors.is_empty() else 1)
