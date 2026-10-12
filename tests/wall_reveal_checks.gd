extends SceneTree
const Reveal = preload("res://presentation/wall_reveal.gd")
const Placement = preload("res://placement.gd")
var failures: Array = []
var checks = 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func _initialize() -> void:
    var wall = {"id":"east","position":[0,0],"boundaries":["east"],"base_height_steps":0,"top_height_steps":2}
    var cases = [
        [[0,0],0,true,"interior"], [[-1,-1],0,true,"behind"],
        [[-2,-2],0,false,"only touches top"], [[0,0],2,false,"at top"],
        [[0,0],1,true,"upper interior"], [[1,0],1,false,"in front"],
        [[0,1],0,false,"side"], [[0,-1],0,true,"diagonally covered neighbor"]]
    # Rotate the complete fixture against the camera, independently of the
    # production selection; the same projected physical relation must hold.
    for quarter in range(4):
        var member = wall.duplicate(true)
        member.boundaries = [["east","south","west","north"][quarter]]
        for sample in cases:
            var p = Placement.rotate_grid(Vector2(sample[0][0],sample[0][1]),posmod(4-quarter,4))
            var tile = {"position":[p.x,p.y],"elevation_steps":sample[1]}
            check(Reveal.occludes(member,tile,quarter)==sample[2],"q%d %s" % [quarter,sample[3]])
        member.base_height_steps=2; member.top_height_steps=4
        check(not Reveal.occludes(member,{"position":[0,0],"elevation_steps":0},quarter),"q%d elevated span clear of own floor"%quarter)
        var lower = Placement.rotate_grid(Vector2(-2,-2),posmod(4-quarter,4))
        check(Reveal.occludes(member,{"position":[lower.x,lower.y],"elevation_steps":0},quarter),"q%d elevated wall projects over lower rearward support"%quarter)
    for quarter in range(4):
        for direction in ["east","north","west","south"]:
            var member = wall.duplicate(true); member.boundaries=[direction]
            var facing = Placement.rotate_grid(Placement.DIRECTIONS[direction],quarter)
            check(Reveal.occludes(member,{"position":[0,0],"elevation_steps":0},quarter)==(facing.x+facing.y>0),"q%d %s rear policy"%[quarter,direction])
    var second = wall.duplicate(true); second.id="south"; second.boundaries=["south"]
    var corner=wall.duplicate(true); corner.wall_members=[wall,second]
    var before=corner.duplicate(true)
    check(Reveal.variants(corner,{"east":true},"solid")=={"joined":1.0},"solid joined")
    check(Reveal.variants(corner,{"east":true},"translucent")=={"east":.28,"south":1.0},"mixed translucent members")
    check(Reveal.variants(corner,{"east":true},"hidden")=={"east":0.0,"south":1.0},"mixed hidden members")
    check(Reveal.variants(corner,{"east":true,"south":true},"translucent")=={"joined":.28},"same-alpha corner retained")
    check(Reveal.variants(corner,{"east":true,"south":true},"hidden")=={"joined":0.0},"whole hidden corner")
    check(corner==before,"source identity and members untouched")
    var report={"checks":checks,"failures":failures}
    var f=FileAccess.open("res://generated/wall_reveal_checks.json",FileAccess.WRITE); f.store_string(JSON.stringify(report,"  ")); f.close()
    print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
