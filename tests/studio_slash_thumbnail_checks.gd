extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## A real authored attack must preview the same native path/phase as its source.
const Recording=preload("res://studio/recording.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Preview=preload("res://presentation/native_effect_preview.gd")
const Components=preload("res://presentation/components.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("SLASH_THUMBNAIL_FAIL ",label)
func fitted(source:Image)->Image:
    var output=source.duplicate()
    var used=output.get_used_rect()
    if used.has_area():output=output.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO,output.get_size())))
    var factor=minf(1.0,128.0/maxi(output.get_width(),output.get_height()))
    if factor<1:output.resize(maxi(1,roundi(output.get_width()*factor)),maxi(1,roundi(output.get_height()*factor)),Image.INTERPOLATE_NEAREST)
    return output
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(640,480)
    # The ordinary melee hit intentionally has no native slash: authoring
    # selects it for critical hits and extra attacks. This unchanged fighter
    # journal contains both real qualified outcomes with an equipped sword.
    var attacks:Array=Fixtures.fact_rows("action-surge","attack")
    check(attacks.any(func(row):return row.fact.attack_outcome=="Crit" and row.fact.attack_source_kind=="equipped"),"Original fighter journal contains an actual equipped critical attack")
    check(attacks.any(func(row):return row.fact.behavior_id=="action.feature.extra_attack" and row.fact.attack_source_kind=="equipped"),"Original fighter journal contains an actual equipped extra attack")
    var index=Fixtures.read("action-surge")
    check(index.ok,"Actual equipped melee attack journal independently admits")
    if not index.ok:finish();return
    var qualified:Dictionary={}
    for attack in attacks:
        if attack.fact.attack_source_kind=="equipped" and (attack.fact.attack_outcome=="Crit" or attack.fact.behavior_id=="action.feature.extra_attack"):
            # fact_rows reads unchanged JSON through Godot's JSON parser, whose
            # numeric values are floats. Native occurrence identities are exact
            # integers; "59.0" must not be compared with the compiler's "59".
            qualified[str(int(attack.node.occurrence))]=attack
    var rows=index.rows.filter(func(row):return row.kind=="native_effect" and row.component.get("source_id")=="class.martial.slash" and row.status=="available" and qualified.has(row.component.source_event_uuid))
    check(not rows.is_empty(),"Real equipped critical/extra attack owns an authored native slash")
    if rows.is_empty():finish();return
    var row:Dictionary=rows[0];var component:Dictionary=row.component
    var source:Dictionary=qualified[component.source_event_uuid]
    check(source.fact.source_entity_uuid==component.actor_uuid and source.fact.source_item_uuid!=null and (source.fact.attack_outcome=="Crit" or source.fact.behavior_id=="action.feature.extra_attack"),"Native slash belongs to the actual authored critical/extra-attack selector and equipped item")
    var retained=var_to_bytes([component,row.actor])
    var rigs:Dictionary=Thumbnails.Catalog.read_file("catalog/rigs.json",index.cache)
    var cycle:Array=Thumbnails.Catalog.read_file("catalog/rig.json",index.cache).FACING_CYCLE
    var pose:Dictionary=component.weapon_pose;var track:Dictionary=component.source_track
    var delta=Vector2(track.target_position[0]-track.from_position[0],track.target_position[1]-track.from_position[1])
    var base_facing:String=cycle[posmod(roundi((atan2(delta.y,delta.x)+PI/4)/(TAU/8))+cycle.find("E"),8)] if not delta.is_zero_approx() else row.actor.facing
    var thumb=Thumbnails.new();thumb.host=root;thumb.cache=Thumbnails.Catalog.source_snapshot(index.cache)
    for quarter in 4:
        var facing:String=cycle[posmod(cycle.find(base_facing)+quarter*2,8)]
        var context={"weapon_path":pose.pointsByFacing[facing],"weapon_path_fps":rigs[row.actor.rig].clips[pose.clip].fps,
            "weapon_contact_seconds":component.weapon_contact_seconds,"weapon_scale_x":row.actor.scale_x}
        for fraction in [.30,.55]:
            var at=lerpf(row.start_ms,row.end_ms,fraction)
            var age=(at-row.start_ms)*component.native_age_rate/1000.0
            var key=thumb.request(row,at,quarter,false)
            check(not thumb.errors.has(key),"Actual slash request has its admitted path and clock q"+str(quarter))
            if DisplayServer.get_name()=="headless":continue
            var reference=Preview.new();root.add_child(reference)
            check(reference.configure(component.source_id,index.cache,Components.effect_seed(component),component.palette).is_empty(),"Independent native source constructs with authored palette")
            var basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+quarter*PI/2,0))
            var deadline=Time.get_ticks_msec()+15000
            var ready=false
            while Time.get_ticks_msec()<deadline:
                thumb.poll()
                var sampled=reference.sample(age,basis,Vector3.ZERO,1.0,[],context)
                ready=sampled.ready
                if (thumb.textures.has(key) or thumb.errors.has(key)) and ready:break
                await process_frame
            check(thumb.errors.is_empty() and thumb.textures.has(key) and ready,"Actual slash swatch and measured native reference both finish q"+str(quarter))
            if thumb.textures.has(key) and ready:
                var expected=fitted(reference.texture().get_image())
                var actual=thumb.textures[key].get_image()
                check(actual.get_used_rect().has_area(),"Actual source slash has visible native pixels q"+str(quarter))
                check(actual.get_size()==expected.get_size() and actual.get_format()==expected.get_format() and actual.get_data()==expected.get_data(),"Thumbnail is exact native measured-path source at authored age q"+str(quarter))
                evidence.append({"quarter":quarter,"facing":facing,"display_ms":at,"native_age_seconds":age,"native_age_rate":component.native_age_rate,"path_points":context.weapon_path.size(),"size":[actual.get_width(),actual.get_height()]})
            reference.close();reference.queue_free();await process_frame
    var missing=row.duplicate(true);missing.id+="-missing-pose";missing.component.weapon_pose.pointsByFacing={}
    var rejected=thumb.request(missing,lerpf(row.start_ms,row.end_ms,.4),0,false)
    check(thumb.errors.get(rejected,"").begins_with("Native Strike has no measured weapon path"),"Missing authored pose is an explicit source error, never an invented smear")
    check(not thumb.textures.has(rejected) and not thumb.requested.has(rejected),"Rejected pose has no ready swatch or queued native owner")
    check(var_to_bytes([component,row.actor])==retained,"Quarter/source sampling preserves admitted actor and measured pose data")
    thumb.close();await process_frame
    finish()
func finish()->void:
    var report={"checks":checks,"failures":failures,"evidence":evidence,"native":DisplayServer.get_name()!="headless",
        "scope":"Actual equipped attack, four authored facings and two source ages; thumbnail pixels versus independently supplied measured-path native source. No new martial effect or artwork."}
    FileAccess.open("res://generated/studio_slash_thumbnail_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SLASH_THUMBNAIL ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
