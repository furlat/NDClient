extends SceneTree
# Native layout of an unchanged real Gallery snapshot. No new gameplay facts.
const ActorHUD=preload("res://ui/actor_hud.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const UI=preload("res://presentation/ui_catalog.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);push_error(label)
func settle()->void:
    await process_frame
    await process_frame
    await process_frame
    await process_frame
func _initialize()->void:run.call_deferred()
func run()->void:
    var source=Fixtures.journal("gallery")
    var target="res://.runtime/actor-hud-layout/"+str(Time.get_ticks_usec())
    DirAccess.make_dir_recursive_absolute(target)
    FileAccess.open(target.path_join("0000000000000000.json"),FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(source.path_join("0000000000000000.json")))
    var journal=Journal.new()
    var opened=journal.open(target,true,false)
    check(opened.ok,"Actual recorded initialization selects its SDK schema")
    if not opened.ok:quit(2);return
    for index in range(10):
        var raw=FileAccess.get_file_as_bytes(source.path_join("%016d.json"%index))
        var decoded=journal.protocol.decode("InitializationResponse" if index==0 else "PlayerOperation",raw)
        check(decoded.ok,"Original Gallery packet parses")
        if not decoded.ok:quit(2);return
        var admitted=journal._consume_admitted(decoded.value,raw)
        check(admitted.ok,"Original Gallery packet reduces without editing facts")
        if not admitted.ok:quit(2);return
    var state=journal.state
    var original=state.duplicate(true)
    var hud=ActorHUD.new()
    root.add_child(hud)
    var cache={}
    hud.sync(state,state.actors[state.observer_uuid],state.observer_uuid,cache)
    await settle()
    check(hud.initiative_buttons.size()==6,"Actual Gallery snapshot supplies six disclosed initiative portraits")
    var party_portrait: Button=hud.party_buttons[state.observer_uuid]
    var turn_portrait: Button=hud.initiative_buttons[state.observer_uuid]
    check(party_portrait.size.x-4==48 and party_portrait.size.y-25==64,"Party keeps Pygame's48x64 artwork with a separate HP baseline")
    check(turn_portrait.size.x-4==36 and turn_portrait.size.y-9==48,"Initiative keeps Pygame's smaller36x48 artwork and HP strip")
    var evidence:Array=[]
    for width in [1280,960,720,622]:
        root.size=Vector2i(width,720)
        for log_open in [false,true]:
            var log_rect=Rect2(width-378,18,360,616) if log_open else Rect2()
            for targeting in [false,true]:
                var target_rect=Rect2(width*.5-94,500,188,28) if targeting else Rect2()
                hud.layout_in(Vector2(width,720),574,log_rect,target_rect)
                await settle()
                var bounds=Rect2(0,0,width,720)
                var label="width%s log%s target%s"%[width,log_open,targeting]
                check(hud.party.position.x==20,label+" party stays on the left regardless of log visibility")
                for bank in [hud.initiative,hud.party,hud.economy]:
                    check(bounds.encloses(bank.get_global_rect()),label+" bank stays inside viewport")
                    if log_open:check(not bank.get_global_rect().intersects(log_rect),label+" bank stays outside combat log")
                    if targeting:check(not bank.get_global_rect().intersects(target_rect),label+" bank stays outside Confirm/Cancel")
                    for child in bank.get_children():
                        check(bank.get_global_rect().encloses(child.get_global_rect()),label+" every native control fits its bank")
                check(not hud.initiative.get_global_rect().intersects(hud.party.get_global_rect()),label+" wrapped initiative clears party")
                check(not hud.party.get_global_rect().intersects(hud.economy.get_global_rect()),label+" party clears resources")
                check(not hud.initiative.get_global_rect().intersects(hud.economy.get_global_rect()),label+" initiative clears resources")
                if width==1280:
                    check(absf(hud.initiative.position.y-12)<1 and hud.initiative.size.y<=67,"Normal wide initiative remains one top row")
                    check(absf(hud.initiative.get_rect().get_center().x-width*.5)<1,"Normal wide initiative keeps its centered placement")
                    check(absf(hud.economy.position.y-540)<1,"Normal wide resource row keeps its existing height above the bar")
                evidence.append({"width":width,"log":log_open,"targeting":targeting,"initiative":str(hud.initiative.get_rect()),"party":str(hud.party.get_rect()),"economy":str(hud.economy.get_rect())})
    # Named display-boundary fixture: a real resource row carries an admitted
    # grant above its usual capacity. This does not simulate an engine grant.
    var granted=state.duplicate(true)
    var sheet: Dictionary=UI.sheet(granted,state.observer_uuid)
    var action_resource: Dictionary=sheet.resources.filter(func(resource):return resource.key=="actions")[0]
    action_resource.current=3; action_resource.maximum=1
    hud.sync(granted,granted.actors[state.observer_uuid],state.observer_uuid,cache)
    check(hud.resource_buttons.actions.text=="◆◆◆","Granted actions above base capacity retain every current pip")
    action_resource.current=12
    hud.sync(granted,granted.actors[state.observer_uuid],state.observer_uuid,cache)
    check(hud.resource_buttons.actions.text=="◆ 12/1","Large grants use exact numeric current/base capacity")
    check(hud.resource_buttons.actions.tooltip_text==action_resource.label+": 12 / 1","Grant tooltip retains exact admitted amount")
    check(state==original,"Responsive presentation does not modify original actor/resource facts")
    UI.close_images(cache)
    var report={"checks":checks,"failures":failures,"geometry":evidence}
    FileAccess.open("res://generated/actor_hud_layout_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
