extends "res://tests/studio_replay_native_checks.gd"
## Current recorded cohort through the real Studio, not archived wire fixtures.
const CaseLibrary=preload("res://studio/case_library.gd")
const COHORT=["action.move/ordinary","spell.haste/lifecycle","spell.fire_bolt/hit","spell.fireball/area",
    "action.hide/lifecycle","action.attack/death","interaction.door/entry","spell.shield/reaction"]

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    report_path="res://.runtime/schema16-studio-replay.json"
    DirAccess.make_dir_recursive_absolute("res://.captures/studio/replay-comparison")
    var records:Array=CaseLibrary.read();var wanted:Array=COHORT.duplicate()
    var all_spells:bool="--all-spells" in OS.get_cmdline_user_args()
    if all_spells:
        report_path="res://.runtime/schema16-all-spells-studio.json";wanted=[]
        var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CaseLibrary.SERVER_IDS))
        for id in inventory.ids.spell:wanted.append(id+"/baseline")
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only-case="):wanted=[argument.trim_prefix("--only-case=")]
    var selected:Array=[]
    for id in wanted:
        var matching:Array=records.filter(func(row):return row.id==id)
        check(matching.size()==1,"Exactly one current recording for "+id)
        if matching.size()!=1:continue
        check(matching[0].ready,id+": real recording ready: "+str(matching[0].get("reason","")))
        if matching[0].ready:selected.append(matching[0])
    if selected.is_empty():
        print(JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
    var recording_failures:Array=failures.duplicate();failures=[]
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    for record in selected:
        var directory:String=record.perspectives[0].journal
        if studio.active_directory!=directory:studio._load(directory)
        if not await settle(studio,0.0,directory):break
        check(studio.replay_diagnostics().panes.size()==1,record.id+": one rendered faction")
        verify_prefix(studio,record.id+" initial")
        if not all_spells:
            var duration:float=studio.index.presentation_end_ms
            for fraction in [.55,.9,.15]:
                studio._seek(duration*fraction)
                if not await settle(studio,duration*fraction):break
                verify_prefix(studio,record.id+" seek "+str(fraction))
                await save_capture(studio,record.id.replace("/","-")+"-"+str(int(fraction*100)))
            studio.select_perspective("blue")
            if not await settle(studio,-1.0,record.journals.blue):break
            verify_prefix(studio,record.id+" independent Blue journal")
            studio.select_perspective("amber")
            if not await settle(studio,-1.0,record.journals.amber):break
        await play_once(studio,record.id)
        if record.id=="action.class.cleric.preserve_life/recipients":
            var observed:Dictionary=evidence.back().get("observed_native",{})
            check(observed.values().filter(func(row):return row.evidence.get("outcome")=="cast").size()==1,"Preserve Life: one native source has a submitted draw witness")
            check(observed.values().filter(func(row):return row.evidence.get("outcome")=="heal").size()==2,"Preserve Life: both actual receiving results have submitted native draw witnesses")
        check(studio.world.presentation_errors.is_empty(),record.id+": no native presentation error")
        if not failures.is_empty():break
        print("SCHEMA16_STUDIO_CASE ",JSON.stringify({"id":record.id,"checks":checks,"failures":failures.size()}))
        if not all_spells:
            studio.loop_enabled=true;studio._play_study()
            if not await settle(studio):break
            var wrapped:bool=false;var previous:float=studio.world.timeline.display_ms
            var deadline:int=Time.get_ticks_msec()+30000
            while not wrapped and Time.get_ticks_msec()<deadline:
                await process_frame
                var now:float=studio.world.timeline.display_ms
                check(now<=studio.loop_end+.001,record.id+": loop never passes Out")
                if now<previous-.1:wrapped=true;verify_prefix(studio,record.id+" automatic loop")
                previous=now
            check(wrapped,record.id+": automatically loops through its real prefix")
            if not studio.world.timeline.paused:studio._toggle_play()
            studio.loop_enabled=false
            await save_capture(studio,record.id.replace("/","-"))
        if studio.world.publication_failed or not studio.world.presentation_errors.is_empty():break
    failures.append_array(recording_failures)
    await finish(studio)
