extends SceneTree
const Placement = preload("res://placement.gd")
# Small reference using the original exhaustive constraints. This checks the
# spatial optimization against the established ordering, including negative Z.
func exhaustive(entries: Array, q: int) -> Dictionary:
    var lowest = 0.0
    for e in entries: lowest = minf(lowest,e.placement.base_height_steps)
    var background = []
    var local = []
    for i in range(entries.size()):
        if entries[i].role=="terrain" and entries[i].placement.base_height_steps==lowest: background.append(i)
        else: local.append(i)
    var keys = entries.map(func(e): return Placement.key(e,q))
    var edges = {}
    var incoming = {}
    for i in local:
        edges[i] = []
        incoming[i] = 0
    for i in local:
        for j in local:
            if i!=j and Placement.before(entries[i],entries[j]):
                edges[i].append(j)
                incoming[j] += 1
    var less = func(a,b): return Placement.key_less(keys[a],keys[b])
    background.sort_custom(less)
    var order = background
    var ready = local.filter(func(i): return incoming[i]==0)
    while not ready.is_empty():
        ready.sort_custom(less)
        var i = ready.pop_front()
        order.append(i)
        for j in edges[i]:
            incoming[j] -= 1
            if incoming[j]==0: ready.append(j)
    var unresolved = []
    for i in local:
        if incoming[i]>0: unresolved.append(entries[i].id)
    return {"order":order,"unresolved":unresolved}
func _initialize() -> void:
    var failures = 0
    seed(7023)
    for sample in range(12):
        var entries = []
        for i in range(70):
            var p = Vector2(randi_range(-4,4),randi_range(-4,4))
            var h = randi_range(-2,2)
            var role = ["terrain","body","wall","covering","shadow"][i%5]
            var id = "piece_%s" % i
            entries.append({"id":id,"role":role,"layer":i%3,"placement":{"id":id,"position":[p.x,p.y],"base_height_steps":h},"screen_rect":Rect2(Placement.project(p,h,0)-Vector2(128,208),Vector2(256,256))})
        for q in range(4):
            for e in entries: e.screen_rect.position = Placement.project(Vector2(e.placement.position[0],e.placement.position[1]),e.placement.base_height_steps,q)-Vector2(128,208)
            if Placement.compose(entries,q)!=exhaustive(entries,q):
                failures += 1
                push_error("Composition changed: sample%s q%s" % [sample,q])
    var entries=[]
    for row in [
        {"id":"floor","kind":"terrain","position":[0,0],"base_height_steps":0},
        {"id":"deck","kind":"terrain","position":[0,0],"base_height_steps":2},
        {"id":"box","kind":"prop","position":[0,0],"base_height_steps":0},
        {"id":"wall","kind":"wall","position":[1,0],"base_height_steps":0,"building_id":"house"},
        {"id":"roof","kind":"library","position":[1,0],"base_height_steps":2,"building_id":"house","roof":true},
        {"id":"actor","kind":"actor","position":[2,0],"base_height_steps":0}]:
        entries.append({"id":row.id,"placement":row,"role":"terrain" if row.kind=="terrain" else "body","layer":0,"screen_rect":Rect2()})
    var general_cache={};var exploration_cache={}
    for step in range(30):
        var actor: Dictionary=entries[-1].placement
        actor.position=[2-step*0.1,0]
        actor.base_height_steps=0 if step<10 else (2 if step<20 else -2)
        for entry in entries:entry.screen_rect=Rect2(Placement.project(Vector2(entry.placement.position[0],entry.placement.position[1]),entry.placement.base_height_steps,0)-Vector2(128,208),Vector2(256,256))
        if Placement.compose(entries,0,general_cache)!=exhaustive(entries,0):
            failures+=1;push_error("Persistent composition cache changed at step "+str(step))
        var result=Placement.compose_exploration(entries,0,exploration_cache)
        if result.order.size()!=entries.size():failures+=1;push_error("Missing exploration entry")
        for a in range(entries.size()):
            for b in range(entries.size()):
                if a!=b and Placement.before(entries[a],entries[b]) and result.order.find(a)>=result.order.find(b):
                    failures+=1;push_error("Exploration lost support relation "+entries[a].id+" -> "+entries[b].id)
    # Exercise the caller's partial application through a full-sort fallback.
    # The covering must precede the actor; the actor goes under the upper floor.
    entries=[]
    for row in [{"id":"A","kind":"terrain","position":[0,0],"base_height_steps":2},
        {"id":"B","kind":"covering","position":[1,0],"base_height_steps":0},
        {"id":"moving","kind":"actor","position":[2,0],"base_height_steps":0}]:
        entries.append({"id":row.id,"placement":row,"role":"body" if row.kind=="actor" else row.kind,"layer":0,"screen_rect":Rect2(-256,-256,512,512)})
    exploration_cache={}
    var applied: Array=[]
    for x in [2,0,2]:
        entries[-1].placement.position=[x,0]
        var result=Placement.compose_exploration(entries,0,exploration_cache)
        if result.has("changed_start"):
            for rank in range(result.changed_start,result.changed_end):applied[rank]=result.order[rank]
        else:applied=result.order.duplicate()
        if applied!=result.order:
            failures+=1;push_error("Partial application retained stale order after fallback")
    print("COMPOSITION_EQUIVALENCE 48 scenes + persistent movement/elevation/fallback caches; ",failures," failures")
    quit(1 if failures else 0)
