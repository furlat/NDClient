extends SceneTree
const Catalog = preload("res://source_catalog.gd")
const MapData = preload("res://map_data.gd")
var failures = 0
var checks = 0
var cache = {}
var paths = {}
func expect(value: bool, label: String) -> void:
    checks += 1
    if not value: failures += 1; push_error(label)
func inspect(record: Dictionary, label: String) -> void:
    expect(record.has("path") and record.has("pivot") and record.has("scale"),label+" has colour and contact")
    if record.is_empty(): return
    paths[record.path] = true
    if record.has("geometry"):
        paths[record.geometry_region.path] = true
        paths[record.normal.region.path] = true
    if record.has("hit_mask"): paths[record.hit_mask.path] = true
func _initialize() -> void:
    var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://generated/catalog.json")).entries
    for entry in catalog:
        if not entry.placeable: continue
        var row = MapData.placement(entry,"check",Vector2.ZERO,0)
        for q in range(4):
            inspect(Catalog.environment(row,q,cache),entry.id+" q"+str(q))
            if row.kind == "door": inspect(Catalog.door_frame(row,q,cache),entry.id+" frame")
        if entry.breakable:
            var duration = Catalog.break_duration(row,cache)
            expect(duration>0,entry.id+" has a declared clock")
            for q in range(4):
                inspect(Catalog.environment(row,q,cache,1,duration*0.5),entry.id+" playing")
                inspect(Catalog.environment(row,q,cache,2,duration),entry.id+" settled")
        if entry.kind=="library" and entry.asset in ["created.fixture.lever","created.weapon.cannon","created.weapon.arcane","generated-timber-stair-flight"]:
            var options=Catalog.sequences(row,cache)
            for n in range(options.size()):
                if not options[n].destruction: continue
                row.sequence=n
                var playing=Catalog.environment(row,0,cache,1,0.1)
                expect(playing.source_variant==options[n].axes.get("variant_name",""),entry.id+" retains selected destruction variant")
                var settled=Catalog.environment(row,0,cache,2,20)
                if options[n].axes.get("state","")=="destruction": expect(settled.source_state=="wreck",entry.id+" uses pitch-independent wreck")
    for path in paths: expect(FileAccess.file_exists(Catalog.media_path(path)),"Source exists: "+path)
    print("CATALOG_CHECKS ",checks," checks; ",paths.size()," unique paths; ",failures," failures")
    quit(1 if failures else 0)
