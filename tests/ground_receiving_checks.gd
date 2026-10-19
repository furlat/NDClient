extends SceneTree
const Ground=preload("res://presentation/ground_receiving.gd")
const Catalog=preload("res://source_catalog.gd")
const Media=preload("res://presentation/environment_media.gd")
var checks=0
var failures=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("GROUND_RECEIVING_FAIL ",label)
func tile(x:int,y:int,height:float=0.0)->Dictionary:
    return {"id":str(x)+","+str(y),"position":[x,y],"base_height_steps":height,"kind":"terrain","material":"stone","layer":0}
func _initialize()->void:
    var row=tile(0,0)
    check(Ground.mask(row,{})==0,"Isolated floor retains every exposed return")
    for i in 4:
        var direction:Vector2=Ground.DIRECTIONS[i]
        check(Ground.mask(row,{direction:0.0})==1<<i,"Equal neighbour marks only its own interior face"+str(i))
        check(Ground.mask(row,{direction:2.0})==1<<i,"Higher neighbour shields its facing return"+str(i))
        check(Ground.mask(row,{direction:-2.0})==0,"Lower neighbour retains exposed raised return"+str(i))
    var water=tile(1,0);water.material="water"
    var support=Ground.heights([{"placement":row,"batch_rows":[row,water,tile(0,1)]}])
    check(Ground.mask(row,support)==2,"Transparent water does not turn a shoreline into a joined floor")
    var cache={}
    var selection:Dictionary=ResourceLoader.load("res://build/presentation/environment/receiving_normals.res").value.normals
    var desk={"id":"desk","kind":"prop","asset":"environment.furniture.writing_desk","position":[0,0],"base_height_steps":0,"orientation":"east","state":"default"}
    for quarter in 4:
        var source=Catalog._environment_source(desk,quarter,cache)
        var receiving=Catalog.environment(desk,quarter,cache)
        check(selection.has(source.normal.region.path) and receiving.normal.region.path==selection[source.normal.region.path].path,"Delivered selected desk normal used"+str(quarter))
        check(receiving.geometry==source.geometry and receiving.geometry_region==source.geometry_region and receiving.support==source.support and receiving.path==source.path and receiving.rect==source.rect,"Color, depth, support and registration stay original"+str(quarter))
    var paths=Media.row_paths(desk,cache)
    check(paths.has(Catalog.environment(desk,0,cache).normal.region.path),"Worker mandatory media closure includes selected receiving normal")
    print("GROUND_RECEIVING_CHECKS ",checks,"/",failures.size())
    quit(0 if failures.is_empty() else 1)
