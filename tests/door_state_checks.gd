extends SceneTree
# Real disclosed before/after objects plus named authored-selector cases.
# No simulated command or movement claim: this boundary owns visible sources.
const WorldRows = preload("res://presentation/world.gd")
const Catalog = preload("res://source_catalog.gd")
const Media = preload("res://presentation/environment_media.gd")
var checks = 0
var failures: Array = []
var cache = {}

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label); print("DOOR_STATE_FAIL ",label)

func _initialize() -> void: run.call_deferred()

func row_for(object: Dictionary) -> Dictionary:
    return WorldRows.rows({"tiles":{},"objects":{object.item.item_uuid:object}},cache).rows[0]

func run() -> void:
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/gallery_door_states.json"))
    var before: Dictionary = fixture.before
    var after: Dictionary = fixture.after
    check(not before.is_empty() and not after.is_empty(),"Actual recorded Gallery passage before and after destruction are available")
    if before.is_empty() or after.is_empty(): finish(); return
    check(after.item.integrity=="destroyed" and after.item.destruction_outcome=="clear"
        and after.item.boundary_structure.blocked_channels.is_empty() and not after.item.is_open,
        "Real broken passage is walkable because destruction cleared its blocker, not because it is open")
    var original_after = after.duplicate(true)
    var cases = [{"label":"actual destroyed closed passage","object":after,"state":"closed","outcome":"clear","destroyed":true}]
    for state in ["closed","open.inward","open.outward"]:
        var intact: Dictionary=before.duplicate(true)
        intact.item.is_open=state!="closed"
        intact.item.door_swing="inward" if state=="open.inward" else "outward"
        cases.append({"label":"intact "+state,"object":intact,"state":state,"destroyed":false})
        for outcome in ["clear","jammed"]:
            var broken: Dictionary=after.duplicate(true)
            # The backend's retained pre-destruction pose selects the bank even
            # when ordinary live door flags no longer describe that pose.
            broken.item.remnant_state.door_open=intact.item.is_open
            broken.item.remnant_state.door_swing=intact.item.door_swing
            broken.item.destruction_outcome=outcome
            cases.append({"label":"destroyed "+state+" "+outcome,"object":broken,"state":state,"outcome":outcome,"destroyed":true})
    # Seed with the intact closed selector: destroyed closed must not reuse it.
    Media.row_paths(row_for(before),cache)
    for item in cases:
        var row = row_for(item.object)
        var owner = Catalog.owner_for(row,cache)
        var bank_id: String = owner.destructions[item.state+"."+item.outcome] if item.destroyed else owner.openings["inward" if item.state=="open.inward" else "outward"]
        var bank = Catalog.bank_data(bank_id,cache)
        var expected_frame: int=int(bank.frame_count)-1 if item.destroyed or item.state!="closed" else 0
        var paths = Media.row_paths(row,cache)
        for quarter in 4:
            var record = Catalog.environment(row,quarter,cache)
            var pose = Catalog.pose_for(bank,row.orientation,quarter)
            var region: Dictionary=bank.frames_by_pose[pose][expected_frame]
            var expected_path: String=bank.get("leaf_path",region.path)
            check(record.get("bank")==bank_id and record.frame==expected_frame and record.path==expected_path,
                item.label+" q%d displays the independently selected authored bank endpoint" % quarter)
            check(paths.has(expected_path),item.label+" q%d prepares its actual source despite retained media cache" % quarter)
            var surface: Dictionary=bank.surface_frames_by_pose[pose][expected_frame]
            if surface.has("normal"):
                var expected = Catalog.receiving_normal(surface,cache)
                check(paths.has(expected.normal.region.path),item.label+" q%d prepares its matching existing normal" % quarter)
            check(not Catalog.door_frame(row,quarter,cache).is_empty(),item.label+" q%d retains the original separate doorway frame" % quarter)
            if item.destroyed:
                check(not record.has("door_partition") and record.hidden==bank.get("clear_at_end",false),
                    item.label+" q%d uses the authored wreck visibility without a duplicate intact leaf" % quarter)
                var beginning = Catalog.environment(row,quarter,cache,1,0.0)
                check(beginning.bank==bank_id and beginning.frame==0 and not beginning.hidden,
                    item.label+" q%d explicit destruction playback can still select its initial sample" % quarter)
    check(after==original_after,"Rendering and preparation do not mutate the server object")
    finish()

func finish() -> void:
    var report={"checks":checks,"failures":failures,"scope":"Actual Gallery destruction after-value and authored closed/open/clear/jammed endpoint selection in all four views; retained media closure and original frame. This is source projection validation, not live command or smooth-animation coverage."}
    FileAccess.open("res://generated/door_state_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
