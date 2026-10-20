extends RefCounted
## Test-owned source snapshots; no production assignment or Factory mutation.
const Build=preload("res://tools/presentation_build/abilities.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Recording=preload("res://studio/recording.gd")
const ID="spatial_effect.spell.plant_growth"
const CLIPS=["bg3-36/plant-growth/plant_growth_native","bg3-36/plant-growth/plant_growth_partial_burn_native"]
const WEB="res://tests/fixtures/schema16/native-persistent-studio/web"
const BURN="res://tests/fixtures/schema16/spatial-transitions/plant-growth-fireball"

static func source_cache(clip:String=CLIPS[0])->Dictionary:
    var path:String="res://authoring/abilities/conditions/"+ID+".tres"
    var entry:Resource=load(path).duplicate(true)
    entry.effects[0].clip=clip
    var built:Dictionary=Build.documents({"conditions":{ID:entry}},{"conditions":{ID:path}})
    var cache:Dictionary={}
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate()
    recipes.merge(built.docs["catalog/condition_recipes.json"],true)
    cache["catalog/condition_recipes.json"]=recipes
    return cache

static func read(directory:String,seat:String,cache:Dictionary={})->Dictionary:
    return Recording.read(directory.path_join(seat),{},{},cache)

static func changes(index:Dictionary)->Array:
    var result:Array=[]
    for entry in index.groups:
        for commit in entry.group.commits:
            for row in commit.get("spatial_rows",[]):
                result.append({"row":row,"at_ms":float(entry.start_ms)+float(commit.at_ms),
                    "sequence":entry.group.operation_sequence,"commit":commit})
    return result
