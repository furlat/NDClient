extends SceneTree
# Existing authored rigs in -> exact drawable/preloaded source closure out.
const Characters=preload("res://presentation/characters.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
var checks := 0
var failures: Array=[]
func check(value: bool,label: String) -> void:
    checks+=1
    if not value: failures.append(label);print("CREATURE_GEOMETRY_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var cache={}
    var index: Dictionary=Characters._read("catalog-index.json",cache)
    var rigs: Dictionary=Characters._read(index.rigs,cache)
    var owners: Dictionary=Characters._read(index.creature_rigs,cache)
    var delivered: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Geometry.CREATURE_TABLE))
    var supported_rigs={}
    var original_rigs: Dictionary=rigs.duplicate(true)
    var partitions := 0
    for path in delivered.records:
        var source: Dictionary=delivered.records[path]
        var selected=Geometry.display_path(path,"body",cache)
        check(Geometry.record(selected,"body",cache)==source,"Companions follow exact selected body "+path)
        check(Geometry.record(selected,"effect",cache).is_empty() and Geometry.record(selected,"shadow",cache).is_empty(),"No body geometry assigned to effects/shadow "+path)
        var demand=Geometry.source_paths(selected,"body",cache)
        check(demand.ok and demand.value.size()==6,"Depth/masks/three profiles form one packet "+path)
        if source.has("colour_path"):
            partitions+=1
            check(selected!=path and not demand.value.has(selected),"Animal body alpha is the separately loaded delivered partition "+path)
        for alias in source.registered_aliases: supported_rigs[alias.rig]=true
    for creature in owners:
        var id: String=owners[creature]
        if not supported_rigs.has(id): continue
        var rig: Dictionary=rigs[id]
        var result=Characters.sheet_paths({"creature_content_ref":creature},rig.clips.keys(),cache)
        check(result.ok,"Existing creature source selection resolves "+creature)
        if not result.ok: continue
        check(not result.cpu_required.is_empty(),"Registered body sources retained "+creature)
        for path in result.cpu_required:
            var packet=Geometry.record(path,"body",cache)
            check(not packet.is_empty(),"Generated creature uses body only, no baked shadow "+path)
            if packet.is_empty(): continue
            check(packet.cell_size==[rig.cell_width,rig.cell_height],"Native cell dimensions retained "+path)
            var pivot_y: float=rig.cell_height-rig.origin_y_from_ground
            check(is_equal_approx(packet.optical_ground_pixels,(packet.optical_camera.origin[1]-pivot_y)/cos(deg_to_rad(packet.optical_camera.elevation_degrees))),"Optical ground uses original painted contact "+path)
            var profiles=Geometry.normal_paths(path,"body",cache)
            check(profiles.value.values().all(func(p):return result.value.has(p) and result.gpu_only.has(p) and not result.cpu_required.has(p)),"Normal profiles use existing asynchronous GPU-only demand "+path)
    check(supported_rigs.size()==42,"Only the existing 42 registered rigs gain delivered companions")
    check(delivered.records.size()==1438 and partitions==98,"Full delivery indexed; 98 native animal body partitions")
    check(rigs==original_rigs,"No new gameplay clips/timing/placement written into rigs")
    check(Geometry.record("/media/not-delivered.png","body",cache).is_empty(),"Unknown body keeps flat receiving fallback")
    var report={"checks":checks,"failures":failures,"registered_rigs":supported_rigs.keys(),"sources":delivered.records.size(),"animal_partitions":partitions,"scope":"Exact current authored source selection and asynchronous demand closure; no gameplay outcome or pixel-render claim."}
    FileAccess.open("res://generated/creature_geometry_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CREATURE_GEOMETRY_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
