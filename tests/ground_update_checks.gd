extends "res://tests/ground_visibility_checks.gd"
# Named disclosed-tile after-values through the production world sync. Every
# retained batch is compared to independent original single draws in old order.
func _initialize()->void:run.call_deferred()
func run()->void:
    if DisplayServer.get_name()=="headless":quit(2);return
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(480,360)
    var scene=Probe.new();root.add_child(scene)
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=1
    scene.add_child(environment)
    scene.timeline.state={"tiles":{},"objects":{},"actors":{},"audience":{"controlled":[]},"senses":{"visible":[],"objects":{}}}
    for quarter in range(4):
        scene.quarter=quarter;scene.position_camera()
        var tiles={}
        for y in range(-1,2):
            for x in range(-1,2):
                var id="%d,%d"%[x,y]
                tiles[id]={"tile_uuid":id,"position":[x,y],"elevation_steps":0,"surface":{"base_material":"stone"}}
        var retained_id=-1
        for change in ["initial","two additions","first representative removal","elevation change","restore and reorder","remove and readd"]:
            if change=="two additions":
                for position in [[2,0],[-2,0]]:
                    var id="%d,%d"%position
                    tiles[id]={"tile_uuid":id,"position":position,"elevation_steps":0,"surface":{"base_material":"stone"}}
            elif change=="first representative removal":
                tiles.erase(scene.ground_groups.stone.entries[0].batch_rows[0].id)
            elif change=="elevation change":
                var id:String=tiles.keys()[0]
                tiles[id]=tiles[id].duplicate(true);tiles[id].elevation_steps=1
            elif change=="restore and reorder":
                var reordered={};var keys=tiles.keys();keys.reverse()
                for id in keys:
                    var tile:Dictionary=tiles[id].duplicate(true);tile.elevation_steps=0;reordered[id]=tile
                tiles=reordered
            elif change=="remove and readd":
                var id:String=tiles.keys()[0]
                var same:Dictionary=tiles[id]
                tiles.erase(id);tiles[id]=same
            scene.timeline.state.tiles=tiles.duplicate()
            scene.timeline.state.senses.visible=tiles.values().filter(func(tile):return tile.position[0]<=0).map(func(tile):return tile.position)
            scene.timeline.world_revision+=1;scene.timeline.revision+=1
            var before:Dictionary=scene.timeline.state.duplicate(true)
            scene._sync_world();scene._sync_scenery(true);scene._sort_draws()
            var batch:Dictionary=scene.ground_groups.stone.entries[0]
            if change=="initial":retained_id=batch.node.get_instance_id()
            check(batch.node.get_instance_id()==retained_id,"q%d %s retains native floor draw identity"%[quarter,change])
            check(batch.node.multimesh.visible_instance_count==batch.batch_rows.size(),"Only active disclosed rows are drawn")
            check(batch.placement.id==batch.batch_rows[0].id,"Original sorted representative survives removal/reorder")
            check(batch.ground_indices.size()==batch.batch_rows.size() and range(batch.batch_rows.size()).all(func(i):return batch.ground_indices.get(batch.batch_rows[i].id)==i),"Sparse visibility index follows exact current native instance order")
            var originals: Array=scene.static_entries.duplicate()
            var actual=await capture()
            batch.node.visible=false
            var singles=[]
            var reference_rows: Array=scene.WorldRows.rows(scene.timeline.state,scene.catalog_cache).rows.filter(func(row):return row.kind=="terrain" and row.base_height_steps==0)
            reference_rows.sort_custom(func(a,b):return scene.Placement.project(Vector2(a.position[0],a.position[1]),0,quarter).y < scene.Placement.project(Vector2(b.position[0],b.position[1]),0,quarter).y)
            check(reference_rows==batch.batch_rows,"Full original Y-only order and tie input are unchanged")
            for row in reference_rows:
                var first=scene.static_entries.size();scene._environment_row(row.duplicate(true))
                for i in range(first,scene.static_entries.size()):
                    var entry:Dictionary=scene.static_entries[i]
                    if entry.role=="shadow":entry.node.visible=false
                    else:
                        entry.material.set_shader_parameter("current_visibility",1.0 if scene.scenery_visibility.has(row.id) else 0.0)
                        singles.append(entry)
            for i in range(singles.size()):scene._apply_draw_rank(singles[i],i,-scene.camera.global_basis.z)
            var upper=originals.filter(func(entry):return entry!=batch and entry.node.visible)
            upper.sort_custom(scene._entry_before)
            for i in range(upper.size()):scene._apply_draw_rank(upper[i],singles.size()+i,-scene.camera.global_basis.z)
            var expected=await capture()
            var difference=diff(actual,expected)
            check(difference==0,"q%d %s original source-over pixels (%d differences)"%[quarter,change,difference])
            check(scene.timeline.state==before,"Renderer preserves exact canonical after-values")
            evidence.append({"quarter":quarter,"change":change,"different_pixels":difference,"active":batch.batch_rows.size(),"capacity":batch.node.multimesh.instance_count})
            for entry in scene.static_entries:
                if not originals.has(entry):entry.node.queue_free()
            scene.static_entries=originals;scene.entries=originals.duplicate();scene.scenery_index_dirty=true;scene.static_order_dirty=true
            batch.node.visible=true
            await process_frame
    var report={"checks":checks,"failures":failures,"cases":evidence,"scope":"Original material single draw retained across2tile disclosure, representative removal, elevation and reorder; original single-sprite pixel oracle all4quarters, mixed native sight."}
    var file=FileAccess.open("res://generated/ground_update_checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
    print("GROUND_UPDATE_CHECKS ",JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
