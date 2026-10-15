extends "res://tests/native_atlas_staged_checks.gd"
## Door-sized owner counts, mathematical source bytes; the second side keeps
## the complete original planner. No recorded geometry or authored art is cut.
func make_side(source:Image,cap:bool,normals:bool)->Dictionary:
    var side:Dictionary=super.make_side(source,cap,normals)
    var rows:Array=side.floor.batch_rows.duplicate(true)
    var template:Dictionary=rows[0]
    for index in 844:
        var row:Dictionary=template.duplicate(true)
        row.id="retained-floor-"+str(index);row.position=[30+index%40,30+index/40]
        rows.append(row)
    publish_floor(side.floor,prepared_floor_packet(side.floor,[],[],rows))
    for index in range(1000,1296):
        var entry:Dictionary=single(side.world,side.texture,index,Vector2(128,128))
        entry.record.rect=[0,0,128,128]
        entry.node.position=Vector3(1000+index,1000,0)
        side.world.entries.append(entry)
    check(side.world.entries.size()==311,"Large fixture retains311 actual static output owners")
    return side

func run()->void:
    root.position=Vector2i(-16000,-16000);root.unfocusable=true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.captures/atlas-growth"))
    await staged_case(pair_source(),"large-private-output-growth",true,false,false,"",false,"plain_append")
    var report={"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"cases":cases,
        "scope":"311 static outputs/1156 initial receivers; private region/material/style preparation versus full first-draw byte oracle, no live timing claim."}
    FileAccess.open("res://generated/native_atlas_large_publication_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ATLAS_LARGE_PUBLICATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
