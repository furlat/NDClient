extends SceneTree
## Generated source documents and physical sprite/quarter results are immutable
## admitted operands. Worker caches fork only their own newly selected records.
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SOURCE_CATALOG_OWNER_FAIL ",label)
func expected_record(source:Dictionary,quarter:int,cache:Dictionary)->Dictionary:
    var index:Dictionary=Catalog.read_file("environment/index.json",cache)
    var library:Dictionary=Catalog.read_file(index.library[source.asset],cache)
    var sample:Dictionary=library.samples[int(source.samples[quarter])]
    var value:Dictionary=sample.surface.duplicate(true);var rect:Array=sample.colour.rect
    value.merge({"path":sample.colour.path,"rect":rect,"native_size":[rect[2],rect[3]],
        "pivot":source.contact_override[quarter] if source.has("contact_override") else sample.get("physical_source_contact_px",sample.get("pivot",source.pivot)),
        "scale":source.scale,"source_sample":source.samples[quarter],"frame":sample.frame_index})
    return value
func run()->void:
    var table:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Catalog.UNITY_SOURCES))
    var selected:String=""
    for id in table:
        if not table[id].has("records"):selected=id;break
    check(not selected.is_empty(),"Actual admitted physical sprite selected")
    var row:Dictionary={"source_sprite":selected,"asset":table[selected].asset,"kind":"library","orientation":"east"}
    var cache:Dictionary={"__actor_source_profile":{}}
    var initial:Dictionary=Catalog.imported_record(row,0,cache,0,0)
    var sequence:Array=Catalog.sequences(row,cache)
    check(cache.__actor_source_profile.generated_table_load_calls==2,"Cold source owner reads exactly the two generated tables")
    check(initial==expected_record(table[selected],0,cache),"Source record matches original authored selection exactly")
    check(not cache.has("unity_sources") and not cache.has("library_sequences"),"Runtime no longer uses dropped non-document aliases")
    var snapshot:Dictionary=Catalog.source_snapshot(cache)
    check(is_same(snapshot[Catalog.UNITY_SOURCES],cache[Catalog.UNITY_SOURCES]) and is_same(snapshot[Catalog.LIBRARY_SEQUENCES],cache[Catalog.LIBRARY_SEQUENCES]),"Snapshot borrows both actual admitted document references")
    check(snapshot[Catalog.IMPORTED_RECORDS].is_read_only() and snapshot[Catalog.IMPORTED_RECORDS].records.is_read_only(),"Published physical-record owner and outer map are sealed")
    var worker:Dictionary=snapshot.duplicate();worker.__actor_source_profile={}
    for repeat in 4:
        check(is_same(Catalog.imported_record(row,0,worker,0,0),initial),"Repeated worker selection reuses exact physical source ref")
        check(is_same(Catalog.sequences(row,worker),sequence),"Repeated worker selection reuses exact sequence ref")
    check(worker.__actor_source_profile.get("generated_table_load_calls",0)==0,"Warm worker performs zero generated JSON reads")
    var old_owner:Dictionary=snapshot[Catalog.IMPORTED_RECORDS]
    var first_new:Dictionary=Catalog.imported_record(row,1,worker,0,0)
    var forked:Dictionary=worker[Catalog.IMPORTED_RECORDS]
    check(not is_same(forked,old_owner) and not old_owner.records.has([selected,1]),"First new quarter forks the private worker map without mutating published owner")
    var second_new:Dictionary=Catalog.imported_record(row,2,worker,0,0)
    check(is_same(forked,worker[Catalog.IMPORTED_RECORDS]),"Further new selections use the same private fork without another whole-map copy")
    check(first_new==expected_record(table[selected],1,worker) and second_new==expected_record(table[selected],2,worker),"New source quarters retain exact authored operands")
    Catalog.adopt_snapshot(cache,Catalog.source_snapshot(worker))
    check(is_same(cache[Catalog.IMPORTED_RECORDS].records[[selected,0]],initial) and is_same(cache[Catalog.IMPORTED_RECORDS].records[[selected,1]],first_new),"Adoption keeps old and newly selected exact source references")
    var next:Dictionary=Catalog.source_snapshot(cache);next.__actor_source_profile={}
    for quarter in 3:Catalog.imported_record(row,quarter,next,0,0)
    Catalog.sequences(row,next)
    check(next.__actor_source_profile.get("generated_table_load_calls",0)==0 and next.__actor_source_profile.get("imported_record_builds",0)==0,"Next operation reads and reconstructs none of the already-admitted source operands")
    var reload:Dictionary=Catalog.source_snapshot(cache)
    reload[Catalog.UNITY_SOURCES]=table.duplicate(true)
    reload.erase(Catalog.IMPORTED_RECORDS)
    var replaced:Dictionary=Catalog.imported_record(row,0,reload,0,0)
    check(replaced==initial and not is_same(replaced,initial),"Explicit new table admission obtains a new physical record owner with exact old values")
    Catalog.adopt_snapshot(cache,Catalog.source_snapshot(reload))
    check(is_same(cache[Catalog.UNITY_SOURCES],snapshot[Catalog.UNITY_SOURCES]) and is_same(Catalog.imported_record(row,0,cache,0,0),initial),"Different source revision cannot overwrite retained source documents or records")
    var builds:int=0
    for quarter in 4:
        var actual:Dictionary=Catalog.imported_record(row,quarter,cache,0,0)
        check(actual==expected_record(table[selected],quarter,cache),"All quarter values match the original authored adapter")
        builds+=1
    var report:Dictionary={"checks":checks,"failures":failures,"cold_profile":cache.__actor_source_profile,
        "warm_profile":next.__actor_source_profile,"source":selected,"quarters":builds,
        "scope":"Actual generated document read counts and exact physical-source references through snapshot/fork/adopt/reload; no artwork, shader, actor UUID or mutable material cache."}
    FileAccess.open("res://generated/source_catalog_static_owner_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SOURCE_CATALOG_STATIC_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
