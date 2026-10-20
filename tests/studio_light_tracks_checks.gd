extends SceneTree
const Fixtures=preload("res://tests/recording_fixtures.gd")
## Actual optical source commits + native resolver + actor motion -> Studio lanes.
const Recording=preload("res://studio/recording.gd")
const LightTracks=preload("res://studio/light_tracks.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
var checks=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("STUDIO_LIGHT_TRACKS_FAIL ",label)

func run()->void:
    for audience in ["amber","blue"]:
        var index=Fixtures.read("hide-light",audience)
        check(index.ok,audience+" actual schema16 torch recording admits")
        if not index.ok:continue
        var lights=index.rows.filter(func(row):return row.kind=="light")
        check(not lights.is_empty(),audience+" exposes its actual native light tracks")
        var times=[0.0,index.presentation_end_ms];var switches=0;var motions=0;var redacted=0
        var rows={}
        for row in lights:
            check(not rows.has(row.optical_source_id),audience+" each actual emitter has one source lane")
            rows[row.optical_source_id]=row
            check(row.render_method.node=="PointLight2D" and row.coverage.rendered=="not_witnessed",audience+" native mechanism is explicit without a fabricated render witness")
            for key in row.light_keys:
                if key.at_ms not in times:times.append(key.at_ms)
                if not key.enabled:switches+=1;continue
                check(not key.observed.has("affected_tiles"),audience+" timeline does not duplicate footprint maps per property key")
                check(key.source.actor_uuid==str(key.observed.anchor_entity_uuid) if key.observed.anchor_entity_uuid!=null else key.source.actor_uuid.is_empty(),audience+" source actor identity is exactly the admitted optical anchor")
                if key.observed.anchor_entity_uuid==null:
                    redacted+=1;check(key.actor_name.is_empty(),audience+" undisclosed light owner never gains an inferred name")
            for track in row.motion_tracks:
                if not track.get("motion",false):continue
                var at:float=track.start_ms+track.duration_ms*.5
                if at not in times:times.append(at)
                motions+=1
        times.sort()
        for at in times:
            var playback=Recording.restore(index,at)
            var state:Dictionary=playback.state
            var native=Lighting.new();native.sync(state)
            native.light_strength=1.0;native.fire_light_flicker=false
            var actors={}
            var samples=playback.actor_samples()
            for id in state.actors:
                var actor:Dictionary=state.actors[id]
                if actor.get("last_visual_position")==null:continue
                var pos:Array=actor.last_visual_position
                var tile:Dictionary=playback.presentation_state().tiles.get("%d,%d"%pos,{})
                if not tile.has("elevation_steps"):continue
                actors[id]={"position":pos,"base_height_steps":tile.elevation_steps,"visual_height":0.0}
                var body:Dictionary=samples.get(id,{})
                if body.has("position"):
                    actors[id].position=body.position;actors[id].base_height_steps=body.base_height_steps
                    actors[id].visual_height=float(body.get("lift_pixels",0))*(128.0/float(index.cache["catalog/rig.json"].TILE_W))/64.0
            native.sample(actors)
            var actual={}
            for source in native.sources:actual[source.item_uuid]=source
            for row in lights:
                var shown=LightTracks.sample(row,at,{"light_strength":1.0,"fire_light_flicker":false})
                check(shown.enabled==actual.has(row.optical_source_id),audience+" step switch exactly matches admitted native source membership at "+str(at))
                if not shown.enabled:continue
                var source:Dictionary=actual[row.optical_source_id]
                var expected:Dictionary=native.sampled[row.optical_source_id]
                check(shown.height_status=="resolved" and shown.position.distance_to(expected.position)<.000001,audience+" carried light position/height follows production motion at "+str(at))
                check(shown.energy==expected.energy,audience+" energy is the existing native value")
                check(shown.outer_radius_cells==source.outer and shown.bright_radius_cells==source.bright and shown.very_bright_radius_cells==source.very,audience+" range conversion matches native light")
                check(shown.color==Lighting.TORCH_COLOUR,audience+" actual torch uses its existing native authored color")
                check(shown.temporal_interpolation=="step",audience+" no unsupported switch fade is manufactured")
                var reduced=LightTracks.sample(row,at,{"light_strength":.5,"fire_light_flicker":false})
                check(reduced.energy==shown.energy*.5,audience+" display strength uses the native multiplier")
        check(switches>0,audience+" actual recording exercises light source removal")
        check(motions>0,audience+" actual recording links actor movement to its emitter")
        evidence.append({"audience":audience,"sources":lights.size(),"switches_off":switches,"motion_intervals":motions,"redacted_keys":redacted,"sample_times":times.size()})
        # Projection contract for the protocol's optional optical anchors. Keep
        # the real known actors but supply no disclosed anchor in this input;
        # inspection must not recover the private owner by proximity or item ID.
        var optical_only:Dictionary=index.initialization.state.duplicate(true)
        for observed in optical_only.light_sources.values():observed.anchor_entity_uuid=null;observed.anchor_item_uuid=null
        var private_history={}
        LightTracks.observe(private_history,optical_only,0.0,"",0,index.cache)
        check(not private_history.is_empty(),audience+" optical-only projection input retains real source geometry")
        for held in private_history.values():
            check(held.keys[0].source.actor_uuid.is_empty() and held.keys[0].actor_name.is_empty(),audience+" optical-only projection cannot infer a known nearby actor")
    var report={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Actual Hide/light faction journals; admitted optical switches, privacy, native source energy/color/ranges and continuous actor-following position. No GPU framebuffer claim; registered fixture curves require existing prepared media."}
    FileAccess.open("res://generated/studio_light_tracks_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_LIGHT_TRACKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
