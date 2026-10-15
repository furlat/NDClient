extends "res://tests/prepared_admission_checks.gd"
# Compare native range merging with the previous linear traversal, including
# object identity at exact ties. No artwork, gameplay or frame-time claim.

func before(a: Dictionary, b: Dictionary) -> bool:
    return Order.less(a.order_key,b.order_key) if a.order_key!=b.order_key else a.id<b.id

func old_linear(fixed: Array, moving: Array) -> Array:
    var result: Array=[]
    var fixed_index=0
    for actor in moving:
        while fixed_index<fixed.size() and before(fixed[fixed_index],actor):
            result.append(fixed[fixed_index]); fixed_index+=1
        result.append(actor)
    while fixed_index<fixed.size():
        result.append(fixed[fixed_index]); fixed_index+=1
    return result

func keyed(value: int, id: String, label: String = "") -> Dictionary:
    return {"id":id,"order_key":[1,value,0,0,2,0,0],"label":label}

func same_entries(a: Array, b: Array) -> bool:
    if a.size()!=b.size(): return false
    for i in range(a.size()):
        if not is_same(a[i],b[i]): return false
    return true

func compare(scene: Node, fixed: Array, moving: Array, label: String) -> void:
    fixed.sort_custom(before); moving.sort_custom(before)
    var expected=old_linear(fixed,moving)
    scene.static_order=fixed
    var actual: Array=scene._merge_draw_order(moving)
    check(same_entries(actual,expected),label+" exact old order and occurrence identity")
    check(same_entries(fixed,actual.filter(func(value):return value in fixed)),label+" unchanged static subsequence")
    check(actual.size()==fixed.size()+moving.size(),label+" no omitted or duplicated occurrence")

func original_keys(quarter: int, actors: bool) -> Array:
    var values: Array=[]
    for x in range(-2,3):
        for height in [-1,0,1]:
            for layer in ([0,1,5] if actors else [0]):
                var row={"position":[x,-x],"base_height_steps":height,"kind":"actor" if actors else "resource"}
                var role="shadow" if actors and layer==0 else "body"
                var id=("actor" if actors else "fixed")+"-%d-%d-%d"%[x,height,layer]
                values.append({"id":id,"order_key":Order.key(row,role,layer,quarter,false)})
    values.reverse()
    return values

func physical_rank(scene: Node, label: String) -> void:
    var moving: Array=scene.actor_entries.filter(func(value):return value.node.visible)
    moving.sort_custom(before)
    check(same_entries(scene.draw_order,old_linear(scene.static_order,moving)),label+" original painter sequence")
    var exact=true
    for i in range(scene.draw_order.size()):
        var value: Dictionary=scene.draw_order[i]
        var expected=i*8.0+(-scene.camera.global_basis.z).dot(value.node.global_position)
        if not is_equal_approx(value.node.sorting_offset,expected): exact=false
    check(exact,label+" native physical depth compensation")

func run() -> void:
    var scene=Probe.new(); root.add_child(scene)
    compare(scene,[],[],"empty")
    compare(scene,[],[keyed(2,"a"),keyed(1,"b")],"actors only")
    compare(scene,[keyed(2,"a"),keyed(1,"b")],[],"statics only")
    compare(scene,[keyed(4,"s"),keyed(5,"s")],[keyed(-2,"a"),keyed(-1,"a")],"all actors before")
    compare(scene,[keyed(-2,"s"),keyed(-1,"s")],[keyed(4,"a"),keyed(5,"a")],"all actors after")
    compare(scene,[keyed(0,"s0"),keyed(2,"s2"),keyed(4,"s4")],[keyed(1,"a1"),keyed(3,"a3")],"interleaved")
    compare(scene,[keyed(0,"a"),keyed(0,"c"),keyed(0,"e")],[keyed(0,"b"),keyed(0,"d")],"equal numeric keys with distinct IDs")
    var fixed_ties=[keyed(0,"same","static1"),keyed(0,"same","static2")]
    var actor_ties=[keyed(0,"same","actor1"),keyed(0,"same","actor2")]
    compare(scene,fixed_ties,actor_ties,"exact full-key ties")
    check(scene._merge_draw_order(actor_ties).slice(0,2)==actor_ties,"Exact actor/static ties remain actor-first")
    var fixed=[keyed(0,"s0"),keyed(1,"hidden"),keyed(2,"s2")]
    compare(scene,fixed.filter(func(value):return value.id!="hidden"),[keyed(1,"actor")],"hidden static subsequence")
    for quarter in range(4):
        compare(scene,original_keys(quarter,false),original_keys(quarter,true),"q%d original negative/elevated actor and shadow layers"%quarter)
    # Actual production sorting still filters native visibility and applies
    # physical depth on both changed-order and unchanged-key jump paths.
    scene.static_order=[]; scene.static_complete_order=[]; scene.static_sort_nodes={}
    scene.camera.rotation_degrees=Vector3(-30,45,0)
    scene.wall_mode="solid"; scene.ground_is_background=false
    var static_a=entry(scene,"static-a",0)
    var static_b=entry(scene,"static-b",1)
    var hidden=entry(scene,"static-hidden",2); hidden.node.visible=false
    var actor=entry(scene,"actor-body",1); actor.placement.kind="actor"; actor.role="body"
    var shadow=entry(scene,"actor-shadow",1); shadow.placement.kind="actor"; shadow.role="shadow"
    scene.static_entries=[static_b,hidden,static_a]; scene.actor_entries=[actor,shadow]
    scene.static_order_dirty=true; scene.draw_order_dirty=true
    scene._sort_draws(); physical_rank(scene,"native initial")
    check(not hidden in scene.draw_order,"Hidden native static does not enter merged order")
    var logical: Array=actor.order_key.duplicate()
    var actor_offset: float=actor.node.sorting_offset
    actor.node.position.y+=1.25
    scene._sort_draws(); physical_rank(scene,"same-key actor lift")
    check(actor.order_key==logical and not is_equal_approx(actor.node.sorting_offset,actor_offset),"Unchanged logical actor key still updates its physical rank offset")
    logical=static_a.order_key.duplicate()
    var static_offset: float=static_a.node.sorting_offset
    static_a.node.position.y+=0.125
    scene.draw_order_dirty=true; scene._sort_draws(); physical_rank(scene,"same-key displaced static")
    check(static_a.order_key==logical and not is_equal_approx(static_a.node.sorting_offset,static_offset),"Dirty merge retains full static physical-position polling")
    hidden.node.visible=true; actor.node.visible=false
    scene.static_order_dirty=true; scene._sort_draws(); physical_rank(scene,"native visibility changed")
    check(hidden in scene.draw_order and not actor in scene.draw_order,"Native visibility changes replace the visible subsequences")
    # Walk continuously across and between the static objects in every view,
    # including actor/actor crossings, jumps and a hidden body becoming visible.
    # Every submitted native offset must equal the original full merge oracle.
    actor.node.visible=true
    for quarter in range(4):
        scene.quarter=quarter; scene.static_order_dirty=true
        scene.camera.transform=scene.Placement.camera_transform(Vector3.ZERO,quarter)
        for step in range(120):
            var x: float=-1.0+float(step)/30.0
            actor.placement.position=[x,0.25]
            shadow.placement.position=[2.0-x,0.25]
            actor.node.position=Vector3(x,sin(step*.1),0.25)
            shadow.node.position=Vector3(2.0-x,0,0.25)
            actor.node.visible=step<60 or step>=70
            scene._sort_draws()
            physical_rank(scene,"interpolated q%d step%d"%[quarter,step])
    var report={"checks":checks,"failures":failures,"scope":"Old linear-merge occurrence oracle for empty/extreme/interleaved/exact ties/hidden/layered four-view inputs; production native order and physical depth compensation with unchanged logical keys. Headless only, no pixel or speedup claim."}
    FileAccess.open("res://generated/draw_merge_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("DRAW_MERGE_CHECKS ",JSON.stringify(report))
    scene.queue_free(); await process_frame
    quit(0 if failures.is_empty() else 1)
