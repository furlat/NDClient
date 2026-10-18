extends SceneTree
## The Studio playing the lifecycle cases in real time, as a player sees them:
## frames of each lasting condition's recipient while it is held (two frames
## 0.5 s apart), while it walks with it on (two frames 0.5 s apart), during its
## removal and after it. Saves crops around the recipient and the difference of
## each pair (does the sustain move?). Waits for the Studio's own startup
## warm-up before playing. No effect is constructed by this script.
##   -- [--case=<inventory id>]... [--captures=res://.captures/condition-frames]
const Studio=preload("res://studio/studio.gd")
const NativeStartup=preload("res://presentation/native_source_startup.gd")
const Placement=preload("res://placement.gd")
const CROP:=Vector2i(360,360)
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("CONDITION_FRAMES_FAIL ",label)

func settle(studio:Control)->bool:
    var deadline=Time.get_ticks_msec()+120000
    while (studio.index.is_empty() or studio.loader!=null or studio.seeker!=null or studio.installing or studio.requested_seek>=0) and Time.get_ticks_msec()<deadline:
        await process_frame
    return not studio.index.is_empty() and studio.loader==null and studio.seeker==null and not studio.installing and studio.requested_seek<0

static func difference(a:Image,b:Image)->float:
    var x:PackedByteArray=a.get_data();var y:PackedByteArray=b.get_data();var total:=0
    for at in x.size():total+=absi(x[at]-y[at])
    return float(total)/maxf(1.0,x.size())

## The published Studio time of a lifecycle role, or -1.
static func role_ms(item:Dictionary,role:String)->float:
    for event in item.get("lifecycle",[]):
        if event.role==role:return float(event.published_ms.get("amber",-1.0))
    return -1.0

## A pair's frames share one crop (placed on the recipient at the pair's
## first frame), so their difference shows what moved, not the crop.
func crop(studio:Control,world:Node,actor_id:String,origin:Variant=null)->Dictionary:
    var frame:Image=studio.viewport.get_texture().get_image();frame.convert(Image.FORMAT_RGBA8)
    if origin==null:
        var visual:Dictionary=world.visual_actors.get(actor_id,{})
        var center:Vector2=Vector2(frame.get_size())*0.5
        if not visual.is_empty():center=world.camera.unproject_position(Placement.contact(visual.row)+Vector3.UP*0.6)
        origin=(Vector2i(center)-CROP/2).clamp(Vector2i.ZERO,frame.get_size()-CROP)
    return {"image":frame.get_region(Rect2i(origin,CROP)),"origin":origin}

func capture(studio:Control,item:Dictionary,captures:String)->Dictionary:
    var directory:String=item.perspectives[0].journal
    studio._load(directory)
    check(await settle(studio),item.id+": installs")
    var world:Node=studio.world
    # The Studio warms every source of the recording before playing it.
    var deadline:int=Time.get_ticks_msec()+120000
    while Time.get_ticks_msec()<deadline and NativeStartup.status({"plan":world.native_startup_plan}).background_pending>0:
        world._step_native_startup(true);await process_frame
    var applied:float=role_ms(item,"applied");var moving:float=role_ms(item,"move_start");var ended:float=role_ms(item,"ended");var tail:float=role_ms(item,"tail_start")
    var recipient:String=""
    for condition in item.get("conditions",[]):
        if condition.fact.condition.behavior_id==item.tracked_condition:recipient=str(condition.fact.target_entity_uuid)
    # Held: past the application (the longest is Aid's 1.1 s) when the
    # condition lasts long enough, else as late as it allows.
    var still:float=moving if moving>applied else ended if ended>=0 else applied+1800.0
    var held:float=clampf(still-applied-600.0,300.0,1200.0)
    var shots:Dictionary={"hold_a":applied+held,"hold_b":applied+held+500.0}
    if moving>applied and moving+900.0<ended:shots.walk_a=moving+400.0;shots.walk_b=moving+900.0
    if ended>=0:shots.removal=ended+100.0
    if tail>=0:shots.after=tail+300.0
    var images:Dictionary={};var origins:Dictionary={}
    studio.loop_enabled=false;studio._play_study()
    check(await settle(studio),item.id+": restarts")
    deadline=Time.get_ticks_msec()+60000
    while not world.timeline.paused and Time.get_ticks_msec()<deadline:
        await process_frame
        for name in shots:
            if images.has(name) or world.timeline.display_ms<shots[name]:continue
            var cropped:Dictionary=crop(studio,world,recipient,origins.get(name.get_slice("_",0)))
            images[name]=cropped.image;origins[name.get_slice("_",0)]=cropped.origin
    var result:Dictionary={"case":item.id,"condition":item.tracked_condition,"shots":shots,"motion":{}}
    for pair in [["hold_a","hold_b"],["walk_a","walk_b"]]:
        if images.has(pair[0]) and images.has(pair[1]):result.motion[pair[0].trim_suffix("_a")]=difference(images[pair[0]],images[pair[1]])
    if not captures.is_empty():
        var names:Array=images.keys()
        var sheet:=Image.create_empty(CROP.x*names.size(),CROP.y,false,Image.FORMAT_RGBA8)
        for at in names.size():sheet.blit_rect(images[names[at]],Rect2i(Vector2i.ZERO,CROP),Vector2i(at*CROP.x,0))
        sheet.save_png(ProjectSettings.globalize_path(captures.path_join(item.id+".png")))
        result.order=names
    print("CONDITION_FRAMES ",JSON.stringify(result))
    return result

func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(1600,900)
    var wanted:Array=[];var captures:String="res://.captures/condition-frames"
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--case="):wanted.append(argument.trim_prefix("--case="))
        if argument.begins_with("--captures="):captures=argument.trim_prefix("--captures=")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
    var inventory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://generated/studio_spell_case_inventory.json"))
    var studio=Studio.new();root.add_child(studio);studio.loop_enabled=false
    await settle(studio)
    var results:Array=[]
    for item in inventory.cases:
        if str(item.get("tracked_condition","")).is_empty() or role_ms(item,"applied")<0:continue
        if not wanted.is_empty() and item.id not in wanted:continue
        results.append(await capture(studio,item,captures))
    FileAccess.open("res://.runtime/condition-lifecycle-frames.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results},"  "))
    print("CONDITION_FRAMES_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    studio.queue_free()
    for frame in 4:await process_frame
    quit(0 if failures.is_empty() else 1)
