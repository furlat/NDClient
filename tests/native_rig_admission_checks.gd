extends SceneTree
## Offline exact effective rig/clip operands, including authored native overrides.
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/body_sources.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Palette=preload("res://presentation/palette.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    var legacy:Dictionary={};var cache:Dictionary={}
    # The built rigs carry the legacy rig table's values (numbers as JSON floats),
    # without its prose (description, resource_source) and with the crouch
    # clips' part sheets under their part keys.
    var expected:Dictionary=_built_form(Catalog.read_file("catalog/rigs.json",legacy))
    var resource_paths:Dictionary=Catalog.read_file("catalog/resources.json",legacy)
    var index=Sources.index(cache)
    var actual:Dictionary=Authoring.rigs(cache)
    var loaded:Dictionary=cache[Sources.KEY].loaded
    check(expected.size()==44 and actual.size()>=expected.size(),"All forty-four effective authored rigs are admitted (the wired roster rigs join them)")
    check(is_same(actual,index.rigs),"Rig lookup borrows its existing admitted index reference")
    var clips:int=0;var sheets:int=0
    for id in expected:
        if not check_present(actual,id):continue
        var rig:Dictionary=actual[id].duplicate();rig.erase("generated_shadow")
        check(rig==expected[id],"Exact effective rig metadata: "+id)
        check(is_same(Authoring.rigs(cache)[id],actual[id]),"Repeated rig lookup retains its native reference: "+id)
        for clip in expected[id].clips:
            clips+=1
            check(actual[id].clips[clip]==expected[id].clips[clip],"Exact clip clock/loop/overrides/sheets: "+id+"/"+clip)
            check(actual[id].clips[clip].sheets==expected[id].clips[clip].sheets,"Exact passive source mappings: "+id+"/"+clip)
            sheets+=actual[id].clips[clip].sheets.size()
    for sheet in resource_paths:
        var built:String=index.sheets.get(_part_key(sheet),{}).get("default","")
        if built.begins_with("res://assets/art/media/"):built="/media/"+built.trim_prefix("res://assets/art/media/")
        check(built==resource_paths[sheet],"Exact existing source resource path: "+sheet)
    var root:Dictionary=actual[index.root_rig]
    for clip in ["CrouchIdle","CrouchRun"]:
        check(root.clips.get(clip,{}).get("loop",false)==true and int(root.clips.get(clip,{}).get("frames",0))==15,"Authored crouch clip retained: "+clip)
    var actor:Dictionary={"creature_content_ref":null}
    for clip in root.clips:
        check(is_same(Authoring.clip(actor,clip,cache),root.clips[clip]),"Clip lookup retains exact native source reference: "+clip)
    var effect:Dictionary={"category":"Magic2","palette":{"colors":[0xff1100]}}
    var selected:Dictionary=Palette.prepare(effect,root,"Attack5",cache)
    check(selected.has("palette_ranges"),"Existing casting palette source resolves from admitted source strings")
    check(is_same(cache[Sources.KEY].loaded,loaded),"Rig/clip/palette selectors admit no category Resource")
    check(not cache.has("catalog/rigs.json") and not cache.has("catalog/resources.json"),"Native rig and palette selection never reads legacy rig/resource JSON")
    var report:Dictionary={"checks":checks,"failures":failures,"rigs":actual.size(),"clips":clips,"sheet_references":sheets,"resource_paths":resource_paths.size(),
        "scope":"All forty-four effective rigs, complete clip metadata including native overrides/sheet strings, exact existing resource paths, shared refs and lookup-only category selection. No GPU/live claim."}
    FileAccess.open("res://generated/native_rig_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_RIG_ADMISSION ",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
static func _part_key(sheet:String)->String:
    return "/spritesheets/"+sheet.trim_prefix("/media/smallscale/modular/") if sheet.begins_with("/media/smallscale/modular/") else sheet
static func _built_form(rigs:Dictionary)->Dictionary:
    var result:Dictionary=JSON.parse_string(JSON.stringify(rigs,"",false,true))
    for rig in result.values():
        for clip in rig.clips.values():
            clip.erase("description");clip.erase("resource_source")
            var sheets:Dictionary={}
            for category in clip.sheets:sheets[category]=_part_key(clip.sheets[category])
            clip.sheets=sheets
    return result
func check_present(values:Dictionary,id:String)->bool:
    var present:bool=values.has(id)
    check(present,"Admitted rig exists: "+id)
    return present
