extends SceneTree
## A locked isometric camera must not rotate as its focus crosses the map.
const Placement=preload("res://placement.gd")
var failures:Array=[]
var checks:int=0

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label)

func _initialize()->void:
    var former_rotations:int=0
    for quarter in 4:
        var reference:Transform3D=Placement.camera_transform(Vector3.ZERO,quarter)
        var old_basis:Basis=reference.basis
        for i in 1000:
            var focus=Vector3(i*.073,sin(i*.01)*2,i*.039)
            var actual:Transform3D=Placement.camera_transform(focus,quarter)
            var former=Transform3D(Basis.IDENTITY,actual.origin).looking_at(focus)
            if former.basis!=old_basis:former_rotations+=1
            old_basis=former.basis
            check(actual.basis==reference.basis,"Panning cannot change quarter "+str(quarter)+" orientation")
            check(actual.origin==focus+reference.origin,"The original authored camera offset stays unchanged")
            check(actual.basis.is_equal_approx(former.basis),"Camera orientation remains the original look-at direction")
            check((-actual.basis.z).dot((focus-actual.origin).normalized())>.999999,"The camera still faces the requested focus")
    print("CAMERA_PAN_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"former_basis_changes":former_rotations}))
    quit(0 if failures.is_empty() else 1)
