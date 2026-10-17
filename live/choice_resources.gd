extends RefCounted
## Warms the native spell resources of the currently disclosed choices.
## Live-only: an action's resources are prepared before any target or outcome
## exists. It owns no renderer instance and draws from the caller's account.
const Catalog=preload("res://source_catalog.gd")
const Choices=preload("res://sdk/choices.gd")
const NativeAuthoring=preload("res://presentation/native_spell_authoring.gd")
const NativeSpells=preload("res://presentation/native_spell_renderer.gd")

var _choice_ids:Array=[]
var _choice_job:Dictionary={}
var _choice_resource_cache:Dictionary={}
var choice_preparation:Dictionary={"ready":true,"behaviors":[],"pending":0,"errors":[]}

func request(choices:Dictionary,cache:Dictionary)->void:
    var ids:Array=[]
    for action in Choices.all_actions(choices):
        var id:String=action.get("behavior_id","")
        if not id.is_empty() and id not in ids:ids.append(id)
    ids.sort()
    if ids==_choice_ids:return
    _choice_ids=ids
    if _choice_job.is_empty() or int(_choice_job.get("task",-1))<0:_start(cache)

func _start(cache:Dictionary)->void:
    # Only immutable authoring/metadata crosses this worker boundary. It never
    # receives actor coordinates, constructs nodes, or simulates an outcome.
    _choice_job={"ids":_choice_ids.duplicate(),"cache":Catalog.source_snapshot(cache),"clips":[],"cursor":0,"task":-1}
    _choice_job.task=WorkerThreadPool.add_task(_resolve.bind(_choice_job),false,"Disclosed native spell resources")
    choice_preparation={"ready":false,"behaviors":_choice_ids.duplicate(),"pending":_choice_ids.size(),"errors":[]}

static func _resolve(job:Dictionary)->void:
    var seen:Dictionary={}
    for id in job.ids:
        var selected:Dictionary=NativeAuthoring.selection(id,job.cache)
        for clip in selected.get("clips",[]):
            if not seen.has(clip.id):job.clips.append(clip);seen[clip.id]=true

func prepare(cache:Dictionary,budget:Dictionary)->void:
    if _choice_job.is_empty():return
    if _choice_job.task>=0:
        if not WorkerThreadPool.is_task_completed(_choice_job.task):return
        WorkerThreadPool.wait_for_task_completion(_choice_job.task);_choice_job.task=-1
        if _choice_job.ids!=_choice_ids:_start(cache);return
        Catalog.adopt_snapshot(cache,_choice_job.cache)
    if budget.frame!=Engine.get_process_frames():
        budget.frame=Engine.get_process_frames();budget.used_usec=0
    while _choice_job.cursor<_choice_job.clips.size() and budget.used_usec<budget.limit_usec:
        var started:int=Time.get_ticks_usec()
        var result=NativeSpells.Factory.prepare([_choice_job.clips[_choice_job.cursor]],_choice_resource_cache)
        budget.used_usec+=Time.get_ticks_usec()-started
        for error in result.errors:
            if error not in choice_preparation.errors:choice_preparation.errors.append(error)
        if not result.ready and result.errors.is_empty():break
        _choice_job.cursor+=1
    choice_preparation.pending=_choice_job.clips.size()-_choice_job.cursor
    choice_preparation.ready=choice_preparation.pending==0 and choice_preparation.errors.is_empty()

func _notification(what:int)->void:
    if what==NOTIFICATION_PREDELETE and not _choice_job.is_empty() and _choice_job.get("task",-1)>=0:
        WorkerThreadPool.wait_for_task_completion(_choice_job.task)
