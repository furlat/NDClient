extends SceneTree
# Real recorded object after-values projected through live world/source adapters.
const World = preload("res://presentation/world.gd")
const Catalog = preload("res://source_catalog.gd")
var checks=0
var failures=[]
var before={}
var after={}
var cache={}
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("WORLD_AUTHORITY_FAIL ",label)
func collect(value:Variant)->void:
    if value is Dictionary:
        if value.get("item") is Dictionary and value.has("placement"):
            var item:Dictionary=value.item
            if item.get("integrity")=="destroyed":after[item.item_uuid]=value
            elif not before.has(item.item_uuid):before[item.item_uuid]=value
        for nested in value.values():collect(nested)
    elif value is Array:
        for nested in value:collect(nested)
func _initialize()->void:
    var recording=""
    var args=OS.get_cmdline_user_args()
    for i in args.size()-1:
        if args[i]=="--recording":recording=args[i+1]
    if recording.is_empty():push_error("Pass --recording with the actual destruction journal prefix.");quit(1);return
    var files=DirAccess.get_files_at(recording);files.sort()
    for filename in files:
        if filename.ends_with(".json"):collect(JSON.parse_string(FileAccess.get_file_as_string(recording.path_join(filename))))
    check(after.size()==5,"Actual recorded prefix contains the five destroyed objects")
    var supported=0
    var rows=[]
    for id in after:
        var object:Dictionary=after[id]
        var snapshot=object.duplicate(true)
        var state={"tiles":{},"objects":{id:object}}
        var result=World.rows(state,cache)
        check(result.rows.size()==1,"Known object remains represented: "+object.item.name)
        if result.rows.is_empty():continue
        var row:Dictionary=result.rows[0]
        if row.kind in ["prop","wall","door"]:
            supported+=1;rows.append(row)
            check(row.get("destroyed",false),"Authoritative destruction selects endpoint: "+object.item.name)
            var bank_id=Catalog.bank_for(row,true,cache)
            check(not bank_id.is_empty(),"Existing authored destruction bank: "+object.item.name)
            for quarter in 4:
                var bank=Catalog.bank_data(bank_id,cache)
                var source=Catalog.environment(row,quarter,cache)
                check(source.get("bank")==bank_id and source.frame==int(bank.frame_count)-1,"Actual destroyed source endpoint q%d: %s"%[quarter,object.item.name])
            var retained={};var sparse={}
            if before.has(id):
                var old={"tiles":{},"objects":{id:before[id]}}
                World.cached_rows(old,cache,retained);World.update_rows(old,cache,sparse,{"full":true})
            check(World.cached_rows(state,cache,retained)==result,"Cached after-value matches canonical adapter: "+object.item.name)
            check(World.update_rows(state,cache,sparse,{"objects":{id:true}})==result,"Sparse after-value matches canonical adapter: "+object.item.name)
        check(object==snapshot,"Source selection leaves recorded object unchanged: "+object.item.name)
    check(supported==4,"Both walls, door and table use existing authored destruction sources")
    var wall:Dictionary=rows.filter(func(row):return row.kind=="wall")[0]
    var a=wall.duplicate(true);var b=wall.duplicate(true)
    a.id="junction-a";a.orientation="east";a.boundaries=["east"];a.erase("destroyed")
    b.id="junction-b";b.orientation="north";b.boundaries=["north"]
    var joined=World.join_walls([a,b],Catalog.environment_world(cache))
    check(joined.size()==2 and not joined[0].has("wall_members"),"One broken edge cannot erase or destroy the adjacent intact wall through corner assembly")
    var report={"checks":checks,"failures":failures,"recording":recording.get_file(),"scope":"Actual five recorded destruction after-values; existing sources for four (two walls, door, table), cached/sparse projection, four source views, source immutability and mixed-state corner separation. Source metadata only, no rendered-pixel proof. Torch remnant authoring and spatial trap-state projection remain explicit separate gaps."}
    FileAccess.open("res://generated/world_authority_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
