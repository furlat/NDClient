extends SceneTree
## Passive blood/body operands, lazy worker admission and retained ownership.
## The retired13-asset directory is not a current runtime owner. Blood belongs
## to the environment; actual sheet metadata belongs to typed body sources.
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Bodies=preload("res://presentation/body_sources.gd")
const Catalog=preload("res://source_catalog.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("NATIVE_ASSET_ADMISSION_FAIL ",label)
static func worker_source(job:Dictionary)->void:
    job.main_thread=Thread.is_main_thread()
    job.layer=Bodies.prepare_layer(job.path,job.cache)
    job.clip=Bodies.prepare_clip(job.layer,"Attack1",job.cache)
func authored_descriptor(layer:Resource,clip:Resource,part:Resource,action:String,label:String)->void:
    var art:Resource=part.actions[action]
    check(layer.category==part.id and not clip.descriptors.is_empty(),label+" exact typed part identity and descriptors")
    for slot in clip.descriptors:
        var value:Dictionary=clip.descriptors[slot]
        check(value.path=="res://assets/"+art.path,label+" authored original colour path: "+slot)
        for profile in ["original","gentle","reference"]:
            check(value.normal_paths[profile]=="res://assets/"+art.surface.normals[profile],label+" exact authored normal profile: "+slot+"/"+profile)
            check(value.companions.has(value.normal_paths[profile]),label+" selected profile is an admitted companion: "+slot+"/"+profile)
        for pair in [["depth",art.surface.depth],["normal",art.surface.normals.original],["support",art.surface.masks.support],["normal_valid",art.surface.masks.normal_valid]]:
            check(value.geometry.files[pair[0]]==pair[1],label+" exact independent authored geometry operand: "+slot+"/"+pair[0])
        check(value.geometry.depth_range==Array(art.surface.depth_limits),label+" full-precision authored depth limits: "+slot)
        check(value.geometry.optical_camera.origin==[art.surface.camera_origin.x,art.surface.camera_origin.y] \
            and value.geometry.optical_camera.elevation_degrees==art.camera_elevation_degrees,label+" authored camera registration: "+slot)
        check(layer.clips[action][slot].companions==value.companions,label+" thin source discovery retains exact companion values: "+slot)
func run()->void:
    var empty:Dictionary={}
    check(Catalog.prepared_residue_asset(empty).is_empty() and Bodies.prepared_layer("unadmitted",empty)==null and empty.is_empty(),"Sampling-only metadata lookup cannot admit an index, resource or cache entry")
    var cache:Dictionary={};var native:Dictionary=Sources.admission(cache)
    var index:Resource=Bodies.index(cache)
    check(index!=null and not index.layers.is_empty() and cache[Bodies.KEY].loaded.is_empty() and native.loaded.is_empty(),"Typed indexes name sources without loading selected body/spell Resources")
    if index==null:return finish(0.0,0)
    var before:int=Time.get_ticks_usec()
    var blood:Dictionary=Catalog.residue_asset(cache)
    var cold_ms:float=(Time.get_ticks_usec()-before)/1000.0
    var source:Resource=load("res://authoring/environment/surfaces/residue.blood.tres")
    var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+source.region_particles))
    var measured:Dictionary=blood.duplicate(false);measured.erase("retained_deposit")
    check(not blood.is_empty() and measured==expected,"Blood region metadata exactly equals its independent authored measured source")
    var retained_profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+source.deposit_profile))
    var deposit:Dictionary=blood.get("retained_deposit",{})
    var ellipse:Dictionary=retained_profile.liquid_surfaces.ellipse.duplicate(true);ellipse.angle=float(ellipse.get("angle",0.0))
    check(deposit.get("profile")==source.deposit_profile and deposit.get("ellipse")==ellipse \
        and deposit.get("radius_cells")==int(retained_profile.deposit_media.radiusCells),"Retained empty-ellipse deposits add their independently authored original liquid ellipse and radius")
    check(blood.get("assetId")=="particles.region.blood","Exact imported blood asset identity is preserved")
    check(is_same(blood,Catalog.prepared_residue_asset(cache)),"Prepared blood lookup borrows the admitted environment value")
    check(not cache.has("catalog/action_media_assets.json") and native.loaded.is_empty(),"Blood admission reads neither the retired asset JSON nor a native spell Resource")
    var selected_path:String=Bodies.layer_path(index.root_rig,"Melee2",cache)
    var selected:Resource=Bodies.prepare_layer(selected_path,cache)
    check(selected!=null and cache[Bodies.KEY].loaded.size()==1,"One selected category admits only its own thin typed Resource")
    if selected==null:return finish(cold_ms,0)
    var part:Resource=load("res://authoring/characters/parts/Melee2.tres")
    var colour:String="res://assets/"+part.actions.Attack1.path
    check(is_same(Bodies.prepared_layer(selected_path,cache),selected) and Bodies.descriptor(colour,"weapon",cache).is_empty(),"Sampling borrows the category but cannot admit its heavy clip")
    var first:Resource=Bodies.prepare_clip(selected,"Attack1",cache)
    check(first!=null and cache[Bodies.KEY].loaded.size()==2,"A selected clip admits exactly its own passive metadata Resource")
    if first==null:return finish(cold_ms,0)
    authored_descriptor(selected,first,part,"Attack1","Main selected source")
    var descriptor:Dictionary=Bodies.descriptor(colour,"weapon",cache)
    check(is_same(descriptor,first.descriptors.weapon),"Sampling borrows the exact admitted descriptor")
    var earlier:Dictionary=Catalog.source_snapshot(cache)
    var loaded_before:Dictionary=cache[Bodies.KEY].loaded
    var job:Dictionary={"cache":Catalog.source_snapshot(cache),"path":Bodies.layer_path(index.root_rig,"Chest3",cache)}
    var task:int=WorkerThreadPool.add_task(worker_source.bind(job),false,"Actual passive body metadata admission")
    while not WorkerThreadPool.is_task_completed(task):await process_frame
    WorkerThreadPool.wait_for_task_completion(task)
    check(not job.main_thread and job.layer!=null and job.clip!=null,"Actual worker prepares its selected typed category/clip without a scene or texture")
    check(is_same(cache[Bodies.KEY].loaded,loaded_before) and loaded_before.size()==2,"Worker replaces only its private loaded shell")
    check(is_same(Catalog.prepared_residue_asset(job.cache),blood) and is_same(job.cache[Bodies.KEY].index,index),"Worker snapshot shares exact original blood and admitted body-index owners")
    check(job.cache[Bodies.KEY].loaded.size()==4 and job.cache[Bodies.KEY].loaded.is_read_only(),"Worker's two new passive Resources join its immutable private admission")
    if job.layer!=null and job.clip!=null:
        authored_descriptor(job.layer,job.clip,load("res://authoring/characters/parts/Chest3.tres"),"Attack1","Worker selected source")
    var other:Resource=Bodies.prepare_clip(selected,"Attack2",cache)
    check(other!=null and cache[Bodies.KEY].loaded.size()==3 and not job.cache[Bodies.KEY].loaded.has(selected.clip_sources.Attack2),"Main and worker can independently prepare different clip sources")
    Catalog.adopt_snapshot(cache,Catalog.source_snapshot(job.cache))
    check(cache[Bodies.KEY].loaded.size()==5 and is_same(Bodies.prepared_layer(job.path,cache),job.layer) \
        and is_same(Bodies.prepare_clip(job.layer,"Attack1",cache),job.clip),"Publication retains the worker's exact two prepared Resources")
    check(is_same(Bodies.prepare_clip(selected,"Attack1",cache),first) and is_same(Bodies.prepare_clip(selected,"Attack2",cache),other) \
        and is_same(Catalog.prepared_residue_asset(cache),blood),"Publication preserves independently prepared main and blood sources")
    check(is_same(earlier[Bodies.KEY].loaded,loaded_before) and earlier[Bodies.KEY].loaded.size()==2,"Earlier replay snapshot remains unchanged after both admissions/publication")
    var fireball:Resource=Sources.find("spell.fireball",cache)
    check(fireball!=null and cache[Sources.CACHE_KEY].loaded.size()==1 and cache[Bodies.KEY].loaded.size()==5,"Spell and body/environment metadata have disjoint native admission keys")
    var retained:Dictionary=Catalog.source_snapshot(cache)
    Catalog.invalidate_source_indexes()
    var replacement:Dictionary={};var offered:Dictionary=Catalog.source_snapshot(replacement)
    check(not is_same(offered[Bodies.KEY].index,index),"Explicit fresh admission creates a different physical index owner")
    Catalog.adopt_snapshot(retained,offered)
    check(is_same(retained[Bodies.KEY].index,index) and is_same(Bodies.prepared_layer(selected_path,retained),selected) \
        and is_same(Catalog.prepared_residue_asset(retained),blood),"Later publication cannot replace a retained replay's body or blood source owner")
    var absent:Dictionary=Bodies.equipment({"item_id":"unregistered.asset","visual_variant_id":null},"weapon",replacement)
    check(not absent.ok and absent.error.kind=="authoring" and not absent.error.message.is_empty(),"A genuinely missing selected typed source returns the explicit ordinary authoring error")
    check(Bodies.layer_path(index.root_rig,"unregistered.asset",replacement).is_empty() and Sources.find("unregistered.asset",replacement)==null,"Unknown metadata identity never guesses another category or spell")
    finish(cold_ms,cache[Bodies.KEY].loaded.size())
func finish(cold_ms:float,loaded:int)->void:
    var report:Dictionary={"checks":checks,"failures":failures,"cold_selected_blood_ms":cold_ms,"selected_body_resources":loaded,
        "scope":"Current authored blood operands and independently selected typed body/category/clip operands; lookup-only sampling, lazy admission, real worker COW, disjoint spell keys and retained revisions. Retired thirteen-asset directory count is not a current asset contract. No GPU/live timing claim."}
    FileAccess.open("res://generated/native_asset_admission_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_ASSET_ADMISSION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
