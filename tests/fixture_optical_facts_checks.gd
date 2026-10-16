extends SceneTree
const Media=preload("res://presentation/media_warmup.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr(label)
func _initialize()->void:
    var saved:Resource=ResourceLoader.load("res://generated/fixture_optical_facts.res","",ResourceLoader.CACHE_MODE_IGNORE)
    var assets:Dictionary=Catalog.read_file("assets.json",{})
    var animation:Dictionary=assets.animations["torch.flame"]
    var energies:Array=[];var saved_energies:Array=[];var heights:Array=[];var saved_heights:Array=[]
    for id in animation.frames:
        var source:Dictionary=assets.resources[id];var path:String=source.path
        var image:Image=Image.load_from_file(Catalog.media_path(path))
        var original:Dictionary=Media.fixture_facts(image)
        var baked:Dictionary=saved.frames[path]
        check(is_equal_approx(baked.energy,original.energy) and baked.emission_centroid==original.emission_centroid,"Saved original-frame optical moments match: "+path)
        var decoded:Dictionary={}
        Media._decode({"path":path,"absolute":Catalog.media_path(path),"fixture":true,"fixture_facts":baked},decoded)
        check(decoded.complete and decoded.energy==baked.energy and decoded.emission_centroid==baked.emission_centroid
            and decoded.image.get_data()==image.get_data(),"Baked worker path preserves exact original bytes and both fixture facts: "+path)
        energies.append(original.energy);saved_energies.append(baked.energy)
        heights.append((float(source.pivot[1])-original.emission_centroid.y)*float(source.scale)/64.0)
        saved_heights.append((float(source.pivot[1])-baked.emission_centroid.y)*float(source.scale)/64.0)
    var mean:float=energies.reduce(func(a,b):return a+b,0.0)/energies.size()
    var saved_mean:float=saved_energies.reduce(func(a,b):return a+b,0.0)/saved_energies.size()
    check(heights==saved_heights,"Every animated light height and resulting mean height remain exact")
    for i in energies.size():
        check(float(clampf(energies[i]/maxf(mean,.0000001),.85,1.15))==float(clampf(saved_energies[i]/maxf(saved_mean,.0000001),.85,1.15)),"Normalized fixture strength remains exact at frame "+str(i))
    var path:String=assets.resources[animation.frames[0]].path
    var fallback:Dictionary={}
    Media._decode({"path":"unbaked-optical-frame","absolute":Catalog.media_path(path),"fixture":true},fallback)
    check(fallback.complete and fallback.energy==energies[0] and fallback.emission_centroid==saved.frames[path].emission_centroid,"Unbaked fixture retains the original exact worker calculation")
    var report:Dictionary={"checks":checks,"failures":failures,"frames":energies.size()}
    FileAccess.open("res://generated/fixture_optical_facts_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
