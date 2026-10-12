extends SceneTree
# Native camera math and the original authored flame samples; no GPU rendering.
const Journal=preload("res://sdk/journal.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
const Shadows=preload("res://presentation/canvas_shadows.gd")
const Catalog=preload("res://source_catalog.gd")
const Placement=preload("res://placement.gd")
var cache={}
var energies=[]
var heights=[]
var records=[]
var failures=[]
var checks=0
var changed_positions=0
var previous_choices={}
var extinction_checks=0
func check(ok: bool,label: String) -> void:
    checks+=1
    if not ok:failures.append(label);print("SHADOW_SOURCE_FAIL ",label)
var camera:Camera3D
var lighting=Lighting.new()
var shadows=Shadows.new()
func _initialize()->void:run.call_deferred()
func run()->void:
    lighting.fire_light_flicker=true
    root.size=Vector2i(1280,720)
    var stage=Node3D.new();root.add_child(stage)
    camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12
    camera.position=Vector3(12,12*Placement.HEIGHT_UNIT,12);camera.look_at(Vector3.ZERO);camera.current=true
    var cookie=Image.load_from_file(Lighting.DEFAULT_COOKIE)
    lighting.cookie=ImageTexture.create_from_image(cookie)
    shadows._cookie_images[lighting.cookie.get_rid()]=cookie
    var assets=Catalog.read_file("assets.json",cache)
    var total=0.0
    for frame in assets.animations["torch.flame"].frames:
        var resource:Dictionary=assets.resources[frame]
        var decoded=Image.load_from_file(Catalog.media_path(resource.path))
        var reduced=decoded.duplicate();reduced.srgb_to_linear();reduced.premultiply_alpha();reduced.convert(Image.FORMAT_RGBAF);reduced.resize(1,1,Image.INTERPOLATE_TRILINEAR)
        var amount=reduced.get_pixel(0,0).get_luminance();energies.append(amount);total+=amount
        var weight=0.0;var moment=Vector2.ZERO
        for y in decoded.get_height():
            for x in decoded.get_width():
                var colour=decoded.get_pixel(x,y)
                var value=colour.srgb_to_linear().get_luminance()*colour.a
                weight+=value;moment+=Vector2(x+.5,y+.5)*value
        var centroid=moment/weight
        heights.append((resource.pivot[1]-centroid.y)*resource.scale/64.0)
    for i in energies.size():energies[i]=clampf(energies[i]/(total/energies.size()),.85,1.15)
    var directory="res://.runtime/player-runs/20261012T190351.188770Z/journal"
    var journal=Journal.new();var opened=journal.open(ProjectSettings.globalize_path(directory),true,false)
    if not opened.ok:push_error(str(opened));quit(1);return
    var state={};var seen={}
    var names=DirAccess.get_files_at(directory);names.sort()
    for name in names:
        if name.length()!=21 or not name.ends_with(".json"):continue
        var kind="InitializationResponse" if state.is_empty() else "PlayerOperation"
        var decoded=journal.protocol.decode(kind,FileAccess.get_file_as_bytes(directory.path_join(name)))
        if not decoded.ok:failures.append(name+" decode");break
        var packet:Dictionary=journal.protocol.normalize(kind,decoded.value)
        var result=Reducer.reduce_initialization(packet.initialization,packet.content_additions) if state.is_empty() else Reducer.reduce_operation(state,packet)
        if not result.ok:failures.append(name+" reduction");break
        state=result.value
        var rows={}
        for actor in state.actors.values():
            if actor.last_visual_position==null:continue
            var key="%s,%s" % [actor.last_visual_position[0],actor.last_visual_position[1]]
            if not state.tiles.has(key):continue
            rows[actor.uuid]={"id":actor.uuid,"position":actor.last_visual_position,"base_height_steps":state.tiles[key].elevation_steps}
        lighting.sync(state)
        var signature=[]
        for source in lighting.sources:signature.append([source.item_uuid,source.position,source.outer])
        signature.append(rows)
        if seen.has(str(signature)):continue
        seen[str(signature)]=true
        for quarter in 4:
            camera.position=Basis(Vector3.UP,quarter*PI/2)*Vector3(12,12*Placement.HEIGHT_UNIT,12);camera.look_at(Vector3.ZERO)
            var selections={}
            var scores={}
            for frame in energies.size():
                var energy={};var height={};var mean_heights={}
                for source in lighting.sources:
                    if source.actor_uuid.is_empty() and state.objects.get(source.item_uuid,{}).get("item",{}).get("item_id")=="environment.wall_torch":
                        energy[source.item_uuid]=energies[frame];height[source.item_uuid]=heights[frame]
                        mean_heights[source.item_uuid]=heights.reduce(func(a,b):return a+b,0.0)/heights.size()
                lighting.sample(rows,energy,height)
                var before=lighting.sampled.duplicate(true)
                lighting.sample(rows,energy,height,mean_heights);lighting.project(camera)
                for source_id in before:
                    check(lighting.sampled[source_id].position==before[source_id].position and lighting.sampled[source_id].energy==before[source_id].energy,"Mean ranking never changes actual receiving position/brightness")
                shadows._prepare_sources(lighting.canvas_sources())
                for id in rows:
                    var row:Dictionary=rows[id]
                    var foot=camera.unproject_position(Placement.contact(row))
                    var selected=shadows._dominant(foot)
                    if not selections.has(id):selections[id]=[];scores[id]=[]
                    selections[id].append(shadows._sources[selected].id if selected>=0 else "")
                    var ranked=[]
                    for source in shadows._sources:
                        var uv=(foot-source.screen_position)/source.span+Vector2.ONE*.5
                        ranked.append({"id":source.id,"score":source.strength*Shadows._cookie_at(cookie,uv),"screen_position":[source.screen_position.x,source.screen_position.y],"energy":source.energy})
                    ranked.sort_custom(func(a,b):return a.score>b.score)
                    scores[id].append(ranked.slice(0,2))
            for id in selections:
                var unique={}
                for source in selections[id]:unique[source]=true
                check(unique.size()<=1,"Stationary actor %s sequence%s quarter%s keeps its casting source through all16 authored flame frames" % [id,packet.cursor.sequence,quarter])
                var identity=[id,quarter]
                var previous:Dictionary=previous_choices.get(identity,{})
                if not previous.is_empty() and previous.position!=rows[id].position and previous.source!=selections[id][0]:changed_positions+=1
                previous_choices[identity]={"position":rows[id].position,"source":selections[id][0]}
                if packet.cursor.sequence in [69,70,71]:
                    var foot=camera.unproject_position(Placement.contact(rows[id]))
                    var original=shadows._dominant(foot)
                    if original>=0:
                        var source_id=shadows._sources[original].id
                        var original_sources=lighting.canvas_sources().duplicate(true)
                        var changed=original_sources.duplicate(true)
                        for source in changed:
                            if source.id==source_id:source.enabled=false
                        shadows._prepare_sources(changed)
                        var replacement=shadows._dominant(foot)
                        check(replacement<0 or shadows._sources[replacement].id!=source_id,"Extinguishing selected source immediately removes its casting ownership")
                        shadows._prepare_sources(original_sources)
                        check(shadows._sources[shadows._dominant(foot)].id==source_id,"Re-enabling unchanged source restores deterministic selection")
                        changed=original_sources.duplicate(true)
                        for source in changed:
                            if source.id==source_id:
                                source.screen_position+=source.span*3.0
                                source.shadow_rank_position+=source.span*3.0
                        shadows._prepare_sources(changed)
                        replacement=shadows._dominant(foot)
                        check(replacement<0 or shadows._sources[replacement].id!=source_id,"Moving the selected native light beyond its footprint reranks immediately")
                        shadows._prepare_sources(original_sources)
                        extinction_checks+=1
                if unique.size()>1:
                    records.append({"sequence":packet.cursor.sequence,"actor":id,"position":rows[id].position,"quarter":quarter,"selected":selections[id],"scores":scores[id]})
    check(changed_positions>0,"Actual recorded actor movement changes casting ownership")
    check(extinction_checks>0,"Actual69–71 source fixtures cover extinction and moving-light transitions")
    var report={"checks":checks,"recorded_movement_source_changes":changed_positions,"extinction_movement_fixtures":extinction_checks,"snapshots":seen.size(),"flicker_switch_cases":records.size(),"frame_energies":energies,"frame_heights":heights,"cases":records,"failures":failures,"scope":"Original user journal subjective states held stationary while all16 exact authored flame frames vary, all4cameraquarters; native camera/production source and selection functions; no GPU assertion."}
    FileAccess.open("res://generated/shadow_source_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHADOW_SOURCE_CHECKS checks=",checks," snapshots=",seen.size()," flicker_switch_cases=",records.size()," failures=",failures)
    shadows.close();lighting.clear_pages();stage.free();quit(0 if failures.is_empty() else 1)
