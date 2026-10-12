extends SceneTree
const Characters = preload("res://presentation/characters.gd")
const EnvironmentMedia = preload("res://presentation/environment_media.gd")
const Media = preload("res://presentation/media_warmup.gd")
const Protocol = preload("res://sdk/protocol.gd")

func _initialize() -> void:
    var parsed = Protocol.parse_json(FileAccess.get_file_as_bytes("res://.runtime/player-runs/20261011T223103.996259Z/state.json"))
    if not parsed.ok: print(parsed); quit(1); return
    var state: Dictionary = parsed.value
    var cache = {}
    var paths = {}; var cpu_required = {}; var gpu_only = {}; var actors: Array = []
    var index: Dictionary = Characters._read("catalog-index.json",cache)
    var rigs: Dictionary = Characters._read(index.rigs,cache)
    for actor in state.actors.values():
        var rig: String = Characters.rig_id(actor,cache)
        var own = {}
        for weapon_set in ["melee","ranged"]:
            var variant: Dictionary = actor.duplicate()
            variant.visual_loadout = actor.visual_loadout.duplicate()
            variant.visual_loadout.active_weapon_set = weapon_set
            var result = Characters.sheet_paths(variant,rigs[rig].clips.keys(),cache)
            if not result.ok: print(result); quit(1); return
            own.merge(result.value); paths.merge(result.value)
            cpu_required.merge(result.cpu_required); gpu_only.merge(result.gpu_only)
        actors.append({"name":actor.name,"rig":rig,"clips":rigs[rig].clips.keys(),"unique_paths":own.size()})
    for path in cpu_required: gpu_only.erase(path)
    var environment = EnvironmentMedia.plan(state,[],cache)
    var current = Media.plan(state,[],cache)
    var report = {"scope":"Currently disclosed Crypt party only; complete existing authored clips and both disclosed equipped weapon sets. PNG header accounting is performed separately, no image decoding/GPU allocation.",
        "actors":actors,"all_character":paths.keys(),"colour":cpu_required.keys(),"geometry":gpu_only.keys(),"environment":environment.required.keys(),"current_character":current.required.keys()}
    FileAccess.open("res://generated/encounter_media_census.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENCOUNTER_MEDIA_CENSUS ",paths.size()," character sources; ",environment.required.size()," environment sources")
    quit()
