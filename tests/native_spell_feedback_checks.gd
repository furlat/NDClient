extends SceneTree
## Recorded spell actions must use the already-authored sandbox hand/receiver
## treatment. This is data/compilation parity, not native framebuffer evidence.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Authoring=preload("res://presentation/authoring.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Feedback=preload("res://presentation/spell_feedback.gd")
const SandboxFeedback=preload("res://sandbox/actor_feedback.gd")
const Sandbox=preload("res://sandbox/world.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_SPELL_FEEDBACK_FAIL ",label)

func recording(path:String,sequence:int,spell:String,expected_hits:int)->void:
    var label=spell+" sequence "+str(sequence)
    var journal=Journal.new()
    var opened=journal.open(path,true,false)
    check(opened.ok,label+": actual journal admits")
    if not opened.ok:return
    var replayed=journal.replay(sequence-1)
    check(replayed.ok,label+": actual before-state reduces")
    if not replayed.ok:return
    var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path.path_join("%016d.json"%sequence)))
    check(decoded.ok,label+": actual operation admits")
    if not decoded.ok:return
    var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
    var cache:Dictionary={}
    var fact={"behavior_id":"spell."+spell}
    var raw=Authoring.spell(fact,cache)
    var original=raw.duplicate(true)
    var selected=NativeSpells.selection(fact.behavior_id,cache)
    var original_selection=selected.duplicate(true)
    var expected_colors:Array=[0x22062a,0x480a50,0x771266,0xab2a85,0xdc60ab] if spell=="magic_missile" else raw.damage.hitFlash.palette.colors.duplicate()
    var adapted=NativeSpells.recipe(fact,cache)
    check(adapted.cast.actionClip==raw.cast.actionClip and adapted.cast.releaseFrame==raw.cast.releaseFrame and adapted.cast.bodyPlaybackSpeed==raw.cast.bodyPlaybackSpeed,
        label+": visual treatment preserves the assigned casting animation and release")
    check(adapted.projectile==raw.projectile and adapted.cast.get("sourceSockets")==raw.cast.get("sourceSockets") and adapted.cast.get("sourceSocketsByRig")==raw.cast.get("sourceSocketsByRig"),
        label+": source sockets, route and delivery timing are unchanged")
    check(not adapted.cast.has("aura") and adapted.cast.effects.is_empty(),label+": rejected Effect1/Effect5 caster aura is absent")
    check(adapted.cast.weaponGlow.category=="Magic2" and adapted.cast.weaponGlow.palette.colors==expected_colors,
        label+": selected hand keeps its actual sheet and approved ordered ramp")
    check(adapted.damage.hitFlash.palette.colors==expected_colors,label+": Colour receiver uses the same ordered ramp as the hands")
    check(adapted.damage.hitFlash.palette.noiseSheet==raw.cast.weaponGlow.palette.noiseSheet,label+": Colour receiver inherits the existing hand material noise")
    if spell=="fire_bolt":check(selected.palette.ramp.is_empty() and expected_colors.size()==21,label+": empty native ramp retains all21 authored receiver colours, never the unordered export palette")
    var compiled=Compiler.compile(journal.state,packet,cache)
    check(compiled.ok,label+": production compiler accepts the recorded action")
    if not compiled.ok:return
    var cast_tracks:Array=[];var hits:Array=[];var native:Array=[]
    var source_events:Dictionary={}
    for lineage in packet.lineages:
        for event in lineage.events:
            if event.get("fact")!=null and event.fact.get("behavior_id")==fact.behavior_id:source_events[event.uuid]=event
    for group in compiled.value.groups:
        for track in group.actor_tracks:
            if source_events.has(track.source_event_uuid) and not track.get("effect_layers",[]).is_empty():cast_tracks.append(track)
        for component in group.components:
            if component.get("native_spell",false) and component.spell_id==spell:native.append(component)
            if component.kind=="material_flash" and component.get("native_hit",{}).get("spell_id")==spell:hits.append(component)
            if component.kind=="sprite_layer" and source_events.has(component.source_event_uuid):
                check(component.layer.category in ["Magic1","Magic2","Magic3"],label+": compiled sprite components contain only approved hand categories")
                check(component.layer.palette.colors==expected_colors,label+": compiled hand component uses the same ordered material ramp")
    check(cast_tracks.size()==1,label+": one authored cast remains shared by all actual deliveries")
    check(hits.size()==expected_hits,label+": receiver flashes still follow only actual applied damage")
    for hit in hits:
        check(hit.colors==expected_colors and hit.material.palette.colors==expected_colors,label+": actual receiving component uses the shared Colour material")
        check(hit.duration_ms==150 and hit.material.durationMs==150 and hit.material.holdMs==50 and hit.material.envelope=="hold_fade" and hit.material.blendMode=="screen",
            label+": Colour/full-native share the authored150ms envelope without timing inflation")
        check(hit.native_hit.finish_profile==selected.palette and hit.native_hit.definition.status=="available",
            label+": the full-material option retains the selected native source and finishing, not a palette substitute")
    if not cast_tracks.is_empty():
        var track:Dictionary=cast_tracks[0]
        check(track.effect_layers.size()==1 and track.effect_layers[0].category=="Magic2",label+": compiled body carries only its Magic2 hand layer")
        # Exercise the actual sandbox preparation function without entering its
        # SceneTree, creating contacts, or launching a backend/native renderer.
        var world=Sandbox.new()
        world.catalog_cache=cache
        world.recipe=raw
        world.library=Authoring.load_data("sandbox/projectiles.json",cache)
        world.selected_spell=world.library.spells.find(world.library.spells.filter(func(item):return item.id==spell)[0])
        world.staging_spec=selected.staging
        world.rigs=Authoring.load_data("catalog/rigs.json",cache)
        world.spell=load("res://authoring/sandbox/"+spell+".tres")
        var event:Dictionary=source_events[track.source_event_uuid]
        var caster:Dictionary=journal.state.actors[event.fact.source_entity_uuid]
        var target:Dictionary=journal.state.actors[event.fact.target_entity_uuid]
        world.timeline.state={"actors":{"caster":caster,"target":target}}
        var sandbox=SandboxFeedback.prepare(world)
        check(sandbox.layers==track.effect_layers,label+": actual sandbox and production resolve identical hand layers including source ranges")
        check(sandbox.colors==expected_colors and sandbox.flash.palette==adapted.damage.hitFlash.palette,label+": sandbox and production share identical receiving material data")
        for field in ["envelope","durationMs","holdMs","blendMode"]:
            check(sandbox.flash[field]==adapted.damage.hitFlash[field],label+": sandbox/production flash "+field+" agrees")
        # _ready normally parents this constructor-created popup. The data-only
        # fixture deliberately never enters the tree, so it owns its cleanup.
        world.context_menu.free()
        world.free()
    for phase in native:
        check(phase.cast_recipe==adapted.cast,label+": native placement consumes the same filtered cast recipe as its hand layers")
    check(raw==original and Authoring.spell(fact,cache)==original,label+": raw authored recipe/cache are unchanged")
    check(selected==original_selection,label+": shared Factory profile/staging are unchanged")
    observations.append({"journal":path,"sequence":sequence,"spell":spell,"hand_layers":cast_tracks[0].effect_layers.size() if not cast_tracks.is_empty() else 0,"colors":expected_colors,"damage_receivers":hits.size()})

func pure_edges()->void:
    var cache:Dictionary={}
    var fact={"behavior_id":"spell.fire_bolt"}
    var raw=Authoring.spell(fact,cache)
    var policy=Authoring.load_data("sandbox/feedback.json",cache)
    var before=raw.duplicate(true)
    var explicit=Feedback.prepare(raw,{"ramp":["010203","040506"]},{"feedback_palette":{"colors":["112233","445566"]}},policy)
    check(explicit.colors==[0x112233,0x445566] and explicit.cast.weaponGlow.palette.colors==explicit.colors,
        "Explicit feedback ramp retains precedence over the native finishing ramp")
    var disabled=raw.duplicate(true);disabled.cast.enabled=false
    var no_cast=Feedback.prepare(disabled,{}, {},policy)
    check(no_cast.cast.enabled==false and not no_cast.flash.palette.has("noiseSheet"),"Disabled casting does not invent an inherited hand layer")
    check(raw==before,"Pure treatment does not mutate source or sibling recipes")
    var unmigrated={"behavior_id":"spell.bless"}
    check(NativeSpells.selection(unmigrated.behavior_id,cache).is_empty() and NativeSpells.recipe(unmigrated,cache)==Authoring.spell(unmigrated,cache),
        "Unmigrated spells retain their original production authoring")

func run()->void:
    pure_edges()
    recording("res://.runtime/compact-magic-missile-20261013/amber/journal",29,"fire_bolt",1)
    recording("res://.runtime/studio-cases/magic_missile-seed3/amber/journal",2,"magic_missile",0)
    recording("res://.runtime/gallery-route/journal",22,"magic_missile",3)
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Shared authored filtering/ramp/envelope; real recorded compilation and actual sandbox preparation parity. No native pixel or artistic acceptance claim."}
    FileAccess.open("res://.runtime/native-spell-feedback-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SPELL_FEEDBACK ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
