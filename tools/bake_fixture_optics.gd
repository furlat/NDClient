extends SceneTree
## Offline original-image measurements; no gameplay, shader or light changes.
const Media=preload("res://presentation/media_warmup.gd")
const Catalog=preload("res://source_catalog.gd")
const Facts=preload("res://presentation/fixture_optical_facts.gd")
func _initialize()->void:
    var assets:Dictionary=Catalog.read_file("assets.json",{})
    var animations:Array=OS.get_cmdline_user_args()
    if animations.is_empty():animations=["torch.flame"]
    var output=Facts.new()
    for name in animations:
        for frame in assets.animations[name].frames:
            var path:String=assets.resources[frame].path
            if output.frames.has(path):continue
            var image:Image=Image.load_from_file(Catalog.media_path(path))
            if image==null or image.is_empty():push_error("Cannot read original fixture: "+path);quit(1);return
            output.frames[path]=Media.fixture_facts(image)
    var error:int=ResourceSaver.save(output,"res://generated/fixture_optical_facts.res")
    print("FIXTURE_OPTICS_BAKED ",output.frames.size()," frames; ",error_string(error))
    quit(0 if error==OK else 1)
