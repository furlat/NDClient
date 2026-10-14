extends SceneTree
const Conditions=preload("res://presentation/conditions.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Palette=preload("res://presentation/palette.gd")
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("CONDITION_SELECTION_FAIL ",label)
func owner(condition:Dictionary,initial:bool=false)->Dictionary:
    return {"id":condition.condition_uuid,"actor_uuid":"actor","condition":condition,"initial":initial,"start_ms":0.0,"end_ms":INF,"life_state":"alive"}
func run()->void:
    var path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):path=arg.trim_prefix("--oracle=")
    if path.is_empty():push_error("Pass explicit --oracle=<original-source generated fixture>");quit(2);return
    var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var cache={}
    check(not Conditions.suppressed({"state":null}),"Nullable condition state has no invented suppression")
    for case in oracle.cases:
        var rows:Array=[]
        for source in case.rows:
            var row:Dictionary=source.duplicate(true)
            row.actor_uuid="actor";row.condition_uuid=row.owner_uuid;row.initial=not row.application;row.life_state=case.life_state
            rows.append(row)
        var held=rows.duplicate(true)
        var actual=Conditions.select_layers(rows,case.time_ms,{"actor":case.activity})
        check(actual.map(func(row):return [row.condition_uuid,row.layer.id])==case.expected,"Original marker selector "+case.name)
        check(rows==held,"Selection retains immutable inputs "+case.name)
    var owners={}
    for id in ["condition.poisoned","condition.paralyzed","class_feature.barbarian.raging"]:
        var record=owner(oracle.conditions[id]);owners[record.id]=record
    var raw=Conditions.samples(owners.duplicate(true),600,cache,{},false)
    var material=Conditions.material("actor",raw)
    var chosen=Conditions.select_recipes("actor",raw).filter(func(row):return row.recipe.persistent.get("bodyColor")!=null)[0]
    var color:Dictionary=chosen.recipe.persistent.bodyColor
    check(material.tint.is_equal_approx(Palette.rgb(int(color.tintRgb))) and is_equal_approx(material.saturation,color.saturation) and is_equal_approx(material.brightness,color.brightness),"Highest selected original bodyColor alone wins while lower owners remain semantic")
    var base=owner(oracle.conditions["condition.poisoned"])
    var applied=Conditions.samples({base.id:base},0,cache).filter(func(row):return row.has("layer"))
    check(applied.size()==1 and applied[0].alpha==0,"Application marker participates before its visual fade starts")
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    for id in ["class_feature.sorcerer.elemental_affinity.resistance","class_feature.sorcerer.metamagic_active","condition.spell.enhance_ability","condition.spell.enlarge_reduce"]:
        if not recipes.has(id):continue
        for layer in recipes[id].persistent.layers:
            for pair in [["whenEnergyType","energy_type"],["whenAbility","enhanced_ability"],["whenMetamagicMode","metamagic_mode"],["whenSizeChange","size_change"]]:
                if layer.get(pair[0])==null:continue
                var row={"layer":layer,"condition":{"state":{pair[1]:layer[pair[0]]}},"actor_uuid":"actor","condition_uuid":"owner","initial":true,"age_ms":0,"alpha":1.0}
                check(Conditions.select_layers([row],0).size()==1,"Authored state selector matches "+layer.id)
                row.condition.state[pair[1]]="different"
                check(Conditions.select_layers([row],0).is_empty(),"Authored state selector rejects other value "+layer.id)
    var charm={"condition_uuid":"charm","behavior_id":"condition.charmed","state":{}}
    var start=owner(charm)
    var layers=recipes["condition.charmed"].persistent.layers
    var offset:float=layers.filter(func(row):return row.get("startOffsetMs",0)>0)[0].startOffsetMs
    check(Conditions.samples({start.id:start},offset-.01,cache).filter(func(row):return row.has("layer") and row.layer.get("startOffsetMs",0)>0).is_empty(),"Authored startOffset withholds sustain before its source start")
    var after=Conditions.samples({start.id:start},offset+50,cache).filter(func(row):return row.has("layer") and row.layer.get("startOffsetMs",0)>0)
    check(not after.is_empty() and after.all(func(row):return is_equal_approx(row.source_age_ms,50+row.layer.get("phaseOffsetMs",0))),"Application source age subtracts start offset and adds phase")
    start.initial=true
    var initial=Conditions.samples({start.id:start},50,cache).filter(func(row):return row.has("layer") and row.layer.get("startOffsetMs",0)>0)
    check(not initial.is_empty() and initial.all(func(row):return row.source_age_ms==50),"Already active source ignores application offsets")
    check(after.all(func(row):return row.status=="available"),"Exact condition_media alias resolves actual sustain registration")
    var rage=raw.filter(func(row):return row.kind=="native_effect")
    check(not rage.is_empty() and rage.all(func(row):return row.has("metadata") and row.scale==row.metadata.get("scale",.5)),"Native layer retains original metadata and registration scale")
    var deceased={base.id:owner(oracle.conditions["condition.poisoned"])}
    Conditions.observe(deceased,{"actor":{"life_state":"dead","conditions":[]}},600)
    check(Conditions.samples(deceased,601,cache).filter(func(row):return row.has("layer")).is_empty(),"Removal tails use current disclosed actor life state rather than stale living marker eligibility")
    var paired=[]
    for source in oracle.cases[0].rows:
        if source.condition.behavior_id!="condition.paralyzed":continue
        for identity in ["z-owner","a-owner"]:
            var row=source.duplicate(true);row.condition_uuid=identity;row.actor_uuid="actor";row.initial=true;paired.append(row)
    var paired_selection=Conditions.select_layers(paired,0)
    check(not paired_selection.is_empty() and paired_selection.all(func(row):return row.condition_uuid=="a-owner"),"Overlapping marker owners select one stable complete bundle")
    for row in paired:
        if row.condition_uuid=="a-owner":row.removal_age_ms=10
    check(Conditions.select_layers(paired,0).all(func(row):return row.condition_uuid=="z-owner"),"Live marker owner wins over lower-UUID fading owner without deleting semantic lifetime")
    var thumbnails=Thumbnails.new()
    var marker=raw.filter(func(row):return row.has("layer") and row.condition.behavior_id=="condition.paralyzed")[0]
    var preview_row={"id":"paralyzed-preview","kind":marker.kind,"status":marker.status,"component":marker,"selection_policy":"sampled","start_ms":0.0,"condition_owners":owners,"source_start_ms":0.0}
    var inactive_key=thumbnails.request(preview_row,1800,0)
    check(thumbnails.inactive.has(inactive_key) and thumbnails.pending.is_empty() and thumbnails.errors.is_empty(),"Inactive marker thumbnail is labeled without pending native work or source error")
    var active_key=thumbnails.request(preview_row,600,0)
    check(thumbnails.requested.has(active_key) and thumbnails.pending.size()==1 and thumbnails.pending[0].age_ms==600,"Active thumbnail queues the shared selected source clock")
    thumbnails.reset()
    check(thumbnails.pending.is_empty() and thumbnails.requested.is_empty() and thumbnails.inactive.is_empty(),"Thumbnail reset cancels all queued/inactive generation state")
    var charm_component=after[0]
    var charm_row={"id":"charm-preview","kind":charm_component.kind,"status":charm_component.status,"component":charm_component,"selection_policy":"sampled","start_ms":0.0,"condition_owners":{"charm":owner(charm)},"source_start_ms":0.0}
    thumbnails.request(charm_row,offset+50,0)
    check(thumbnails.pending.size()==1 and thumbnails.pending[0].age_ms==50+charm_component.layer.get("phaseOffsetMs",0),"Thumbnail source clock preserves authored application delay")
    thumbnails.close()
    var result={"checks":checks,"failures":failures,"original_source":oracle.source,"recordings":oracle.recordings,"scope":"Original marker operator and authored composition/state/clock policy; no native pixel claim"}
    FileAccess.open("res://generated/condition_selection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("CONDITION_SELECTION_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
