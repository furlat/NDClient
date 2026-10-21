extends "res://tools/profile_studio.gd"
## One normal-clock Gallery run, then actual transport and drawn-lane checks.
## Captures/seeks are outside the performance interval inherited from the tool.
var checks:int=0
var checkpoint:Dictionary={"captures":[],"loop":{},"checks":0}
const CAPTURE_DIR="res://.captures/studio/checkpoint"

func check(value:bool,message:String)->void:
    checks+=1
    if not value:failures.append(message);print("STUDIO_CHECKPOINT_FAIL ",message)

func rendered()->void:
    await process_frame
    await RenderingServer.frame_post_draw

func followed_visible()->bool:
    return studio.tracks.followed_visible()

func transport_checks()->void:
    check(studio.follow_tracks and studio.follow_button.button_pressed,"Follow is visibly enabled by default")
    var following:Array=frames.filter(func(frame):return not frame.follow.source.is_empty())
    check(not following.is_empty(),"Normal playback follows actual recorded work")
    check(following.all(func(frame):return frame.follow.visible),"Followed animation lane stays inside the drawn timeline during normal playback")
    check(following.all(func(frame):return frame.follow.playhead_visible),"Horizontal Follow keeps the actual playback cursor inside the timeline")
    var offsets:Dictionary={}
    for record in following:offsets[roundi(record.follow.scroll_y)]=true
    check(offsets.size()>3,"Normal playback scrolls vertically through distinct actions")
    var horizontal:Dictionary={}
    for record in following:horizontal[roundi(record.follow.origin_ms)]=true
    check(horizontal.size()>3 and following.all(func(frame):return frame.follow.pixels_per_second>=200),"Normal playback follows a readable time window instead of shrinking the full recording to fit")
    var groups:Array=studio.index.groups
    var counts:Dictionary={}
    for wrapped in groups:
        for component in wrapped.group.components:
            if not component.get("native_spell",false):continue
            var spell:String=component.spell_id
            if spell not in ["spell.magic_missile","spell.scorching_ray","spell.fireball"]:continue
            if not counts.has(spell):counts[spell]={}
            var role:String=component.native_cue.role
            counts[spell][role]=int(counts[spell].get(role,0))+1
    var expected={"spell.magic_missile":{"cast":2,"flight":6,"impact":6},"spell.scorching_ray":{"cast":1,"flight":3,"impact":1},"spell.fireball":{"cast":1,"flight":1,"area":1}}
    check(counts==expected,"Compact tracks retain the recorded casts, missiles, rays, impacts and single Fireball area")
    checkpoint.native_roles=counts
    DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
    var selections:Array=[]
    var movement:Array=studio.index.rows.filter(func(row):return row.kind=="body" and row.get("track",{}).get("clip")=="Run" and row.end_ms-row.start_ms>100)
    if not movement.is_empty():selections.append({"name":"movement","row":movement[0]})
    for spell in ["spell.magic_missile","spell.scorching_ray","spell.fireball"]:
        var sources:Array=studio.index.rows.filter(func(row):return row.kind=="native_effect" and row.get("component",{}).get("spell_id")==spell and row.component.native_cue.role==("area" if spell=="spell.fireball" else "flight") and row.get("visible_here",true))
        check(not sources.is_empty(),"Actual recorded source available for "+spell)
        if not sources.is_empty():selections.append({"name":spell,"row":sources[0]})
    for selected in selections:
        var row:Dictionary=selected.row
        var target:float=lerpf(row.start_ms,row.end_ms,.3)
        studio._seek(target)
        if not await wait_ready():return
        await rendered();await rendered()
        check(absf(studio.world.timeline.display_ms-target)<.01,"Seek publishes the requested recorded moment: "+selected.name)
        check(followed_visible(),"Seek follows visible animation: "+selected.name)
        var context:Array=studio.tracks.context_labels(studio.tracks.published_layout)
        check(context.size()==2 and not str(context[0]).is_empty(),"Scrolled tracks retain their action and lane context: "+selected.name)
        if selected.name=="spell.fireball":
            var followed:Dictionary=studio.tracks.rows_by_id.get(studio.tracks.followed_row,{})
            check(followed.get("kind")=="native_effect" and followed.get("component",{}).get("native_cue",{}).get("role")=="area","Fireball follows its active area instead of incidental residue")
        var path:String=CAPTURE_DIR.path_join(selected.name+".png")
        root.get_texture().get_image().save_png(path)
        checkpoint.captures.append({"name":selected.name,"path":path,"time_ms":target,"context":context,"followed":studio.tracks.followed_row,"lane":studio.tracks.display_row_for.get(studio.tracks.followed_row,studio.tracks.followed_row),"visible_rows":studio.tracks.published_layout.visible_rows.map(func(item):return {"label":item.row.label,"kind":item.row.kind,"id":item.row.id})})
    if selections.size()<2:return
    var row:Dictionary=selections[1].row
    studio.loop_start=maxf(0,row.start_ms-200)
    studio.loop_end=minf(studio.index.presentation_end_ms,row.end_ms+250)
    studio.loop_enabled=true;studio.loop_button.set_pressed_no_signal(true)
    studio._seek(studio.loop_start)
    if not await wait_ready():return
    studio._toggle_play()
    var previous:float=studio.world.timeline.display_ms
    var deadline:int=Time.get_ticks_msec()+30000
    var wraps:int=0;var follow_during_preparation:int=0;var lost:Array=[]
    while Time.get_ticks_msec()<deadline and wraps<2:
        await rendered()
        var now:float=studio.world.timeline.display_ms
        if now<previous-.1:wraps+=1
        if studio.preparing_loop and not studio.tracks.followed_row.is_empty():
            follow_during_preparation+=1
            if not followed_visible() and lost.size()<5:lost.append(now)
        previous=now
    studio.world.timeline.paused=true
    studio.loop_enabled=false;studio._cancel_loop_preparation()
    check(wraps==2,"Normal loop playback wraps twice at Out")
    check(follow_during_preparation>0 and lost.is_empty(),"Preparing the next loop does not disable current playback's visible Follow")
    checkpoint.loop={"wraps":wraps,"follow_during_preparation_frames":follow_during_preparation,"lost_follow_times":lost}
    var original:String=studio.active_perspective
    var other:String=""
    for perspective in studio.case_bundle.get("perspectives",[]):
        if str(perspective.id)!=original:other=str(perspective.id);break
    if not other.is_empty():
        var original_time:float=studio.world.timeline.display_ms
        var anchor:Dictionary=studio._navigation_anchor(studio.index,original_time,studio.selected_row,studio.retained_view_anchor)
        studio.select_perspective(other)
        if not await wait_ready():return
        var mapped:float=studio.Recording.anchor_time(studio.index,anchor)
        check(studio.active_perspective==other and studio.world.timeline.paused,"On-demand faction selection publishes that audience and preserves pause")
        check(absf(studio.world.timeline.display_ms-mapped)<.01,"Faction selection preserves the corresponding recorded event position")
        check(is_same(studio.index.groups,studio.case_bundle.views[other].groups),"Selected faction owns its own original groups")
        studio.select_perspective(original)
        if not await wait_ready():return
        check(studio.active_perspective==original and absf(studio.world.timeline.display_ms-original_time)<.01,"Returning to the loaded faction restores the original recorded position")
        checkpoint.faction_switch={"original":original,"other":other,"original_ms":original_time,"mapped_ms":mapped,"returned_ms":studio.world.timeline.display_ms}

func finish()->void:
    if failures.is_empty():await transport_checks()
    checkpoint.checks=checks;checkpoint.failures=failures.duplicate();checkpoint.setup=setup
    FileAccess.open("res://.runtime/studio-checkpoint-native-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checkpoint,"  "))
    print("STUDIO_CHECKPOINT ",JSON.stringify({"checks":checks,"failures":failures,"setup":setup}))
    await super.finish()
