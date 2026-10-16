extends RefCounted
## One private native parent for a prepared static packet. Children retain
## this handle; it owns no child references. No SceneTree node crosses threads.
var rid:RID
var adopted:bool=false
var draws:int=0

func retain_draw()->void:draws+=1

func release_draw()->int:
    draws-=1
    if draws>0 or not rid.is_valid():return 0
    RenderingServer.free_rid(rid);rid=RID()
    return 1

func _init()->void:
    rid=RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_visible(rid,false)

func adopt(parent:RID)->void:
    if adopted:return
    RenderingServer.canvas_item_set_parent(rid,parent)
    RenderingServer.canvas_item_set_visible(rid,true)
    adopted=true

func _notification(what:int)->void:
    if what==NOTIFICATION_PREDELETE and rid.is_valid():RenderingServer.free_rid(rid)
