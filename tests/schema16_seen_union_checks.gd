extends SceneTree
## Canonical seen union is byte-identical to the Python and prior client codecs.
const Cells=preload("res://sdk/fold_cells.gd")
const Audience=preload("res://sdk/audience.gd")
const StrictJSON=preload("res://sdk/strict_json.gd")
var passed=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);print("FAIL "+label)
func _initialize()->void:call_deferred("run")
func sample(prior:Dictionary,added:Array,label:String,expected:Dictionary={})->void:
    var held=prior.duplicate(true);var supplied=added.duplicate(true)
    var reference=Cells.mask(Audience.points_union(Cells.mask_points(prior),added))
    var actual=Cells.union_points(prior,added)
    check(actual==reference,label+" exact prior codec including normalized bounds and padded base64")
    if not expected.is_empty():check(actual==expected,label+" exact frozen Python mask")
    check(prior==held and added==supplied,label+" leaves retained mask and caller additions unchanged")
    if int(actual.width)>0:
        var data=Cells.bytes(actual.bits);var used=int(actual.width)*int(actual.height)%8
        check(used==0 or (int(data[-1])>>used)==0,label+" zero unused tail bits")
    else:check(actual==Cells.EMPTY,label+" unique empty representation")
    var chained=Cells.union_points(actual,[[int(actual.x0)-1,int(actual.y0)-1]])
    check(actual==reference and chained!=actual,label+" later expansion preserves held result")
    actual.bits=""
    check(prior==held,label+" returned dictionary is detached from prior")
func run()->void:
    var parsed=StrictJSON.new().parse(FileAccess.get_file_as_string("res://tests/fixtures/schema16/seen-union.json"))
    check(parsed.ok,"Frozen Python vectors parse with full int64 coordinates")
    if parsed.ok:
        check(parsed.value.engine=="211b71134ed15c89e62232587381f7e15a5961c3","Codec vectors use current frozen engine")
        check(parsed.value.cases.size()==26,"All pinned Python vectors are present")
        for row in parsed.value.cases:sample(row.prior,row.added,row.name,row.expected)
    # Every source/destination byte alignment occurs across these tight sparse
    # boxes, with unsorted duplicates, inside additions and all expansion sides.
    var cases=0
    for width in range(1,10):
        for height in range(1,18):
            var x0=-13+width;var y0=5-height
            var prior=Cells.mask([[x0,y0],[x0+width-1,y0+height-1],[x0+width/2,y0+height/2]])
            for added in [[],[[x0,y0]],[[x0+width/2,y0+height/2],[x0,y0],[x0,y0]],
                    [[x0-1,y0]],[[x0,y0-1]],[[x0+width,y0]],[[x0,y0+height]],
                    [[x0-3,y0+height+2],[x0+width+4,y0-2],[x0-3,y0+height+2]]]:
                sample(prior,added,"differential "+str(cases));cases+=1
    print(JSON.stringify({"passed":passed,"failures":failures,"python_vectors":26,"differential_cases":cases,
        "scope":"Exact canonical union, negative/shifted/disjoint bounds, byte/column boundaries, empty/duplicates, int64 coordinates and detached retained values; no timing threshold or live latency claim"}))
    quit(0 if failures.is_empty() else 1)
