extends RefCounted
const Playback = preload("res://animation/playback.gd")
const DESTRUCTION_SCENE = preload("res://generated/destruction_animation.tscn")

static func track(animation: Animation, property: String, keys: Array, discrete: bool = false) -> void:
    var index = animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(index, NodePath(".:" + property))
    animation.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE if discrete else Animation.UPDATE_CONTINUOUS)
    for key in keys:
        animation.track_insert_key(index, key[0], key[1])

static func animation(name: String, duration: float, loop: bool, phase: int = 0) -> Animation:
    var result = Animation.new()
    result.length = maxf(duration, 0.001)
    result.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
    track(result, "clip", [[0.0, name]], true)
    track(result, "phase", [[0.0, phase]], true)
    track(result, "sample_seconds", [[0.0, 0.0], [result.length, result.length]])
    return result

static func transition(graph: AnimationNodeStateMachine, source: String, destination: String, at_end: bool = false) -> void:
    var edge = AnimationNodeStateMachineTransition.new()
    edge.xfade_time = 0.0
    edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END if at_end else AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
    edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if at_end else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
    graph.add_transition(source, destination, edge)

static func make(parent: Node, animations: Dictionary, hub: String, returns: Array[String], sampled: bool = false) -> Node:
    var library = AnimationLibrary.new()
    var graph = AnimationNodeStateMachine.new()
    var i = 0
    for name in animations:
        library.add_animation(name, animations[name])
        var node = AnimationNodeAnimation.new()
        node.animation = name
        if sampled:
            graph.add_node(name, seek_node(name), Vector2(220 * (i % 4), 120 * (i / 4)))
        else: graph.add_node(name, node, Vector2(220 * (i % 4), 120 * (i / 4)))
        i += 1
    for name in animations:
        if name != hub:
            transition(graph, hub, name)
            transition(graph, name, hub, name in returns and not sampled)
    var host = instantiate(parent,library,graph,hub)
    host.set_meta("sampling",sampled)
    return host

static func instantiate(parent: Node, library: AnimationLibrary, graph: AnimationNodeStateMachine, hub: String) -> Node:
    var host = Playback.new()
    host.name = "Playback"
    parent.add_child(host)
    var player = AnimationPlayer.new()
    player.name = "AnimationPlayer"
    host.add_child(player)
    player.add_animation_library("",library)
    var tree = AnimationTree.new()
    tree.name = "AnimationTree"
    host.add_child(tree)
    tree.anim_player = NodePath("../AnimationPlayer")
    tree.tree_root = graph
    tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    tree.active = true
    var state: AnimationNodeStateMachinePlayback = tree.get("parameters/playback")
    state.start(hub)
    tree.advance(0.0)
    tree.advance(0.0)
    host.set_meta("tree", tree)
    host.set_meta("state", state)
    return host

static func character_loops(rig: Dictionary, clip: String) -> bool:
    if rig.clips.get(clip,{}).has("loop"): return bool(rig.clips[clip].loop)
    if rig.get("rest_pose_anchors",{}).has(clip):return false
    var loop=clip in ["Idle","Idle2","Idle4","Run"]
    for context in rig.get("body_contexts", []):
        var body: Dictionary = context.body
        if not body.actor.enabled or body.actor.clip!=clip:continue
        if context.role=="death":return false
        if body.get("playback")=="loop":loop=true
    return loop

static func build_character(parent: Node, rig: Dictionary, sampled: bool = false) -> Node:
    var animations = {}
    var returns: Array[String] = []
    var holds: Array = rig.get("rest_pose_anchors", {}).keys()
    for context in rig.get("body_contexts", []):
        if context.body.actor.enabled and context.role=="death" and context.body.actor.clip not in holds:holds.append(context.body.actor.clip)
    for name in rig.clips:
        var source: Dictionary = rig.clips[name]
        var loop = character_loops(rig,name)
        animations[name] = animation(name, float(source.frames) / float(source.fps), loop)
        if not loop and name not in holds:
            returns.append(name)
    var host = make(parent, animations, "Idle", returns, sampled)
    host.set_meta("clips", rig.clips)
    return host

static func build_destruction(parent: Node, duration: float) -> Node:
    var animations = {"Intact": animation("Intact", 1.0, true),
        "Breaking": animation("Breaking", duration, false, 1), "Settled": animation("Settled", 1.0, true, 2)}
    var host = make(parent, animations, "Intact", [])
    var graph: AnimationNodeStateMachine = host.get_meta("tree").tree_root
    graph.remove_transition("Breaking", "Intact")
    transition(graph, "Breaking", "Settled", true)
    return host

static func activate(host: Node, hub: String) -> Node:
    var tree: AnimationTree = host.get_node("AnimationTree")
    var state: AnimationNodeStateMachinePlayback = tree.get("parameters/playback")
    host.set_meta("tree",tree)
    host.set_meta("state",state)
    tree.active = true
    state.start(hub)
    tree.advance(0.0)
    tree.advance(0.0)
    return host

static func character(parent: Node, rig: Dictionary, sampled: bool = false, templates: Array = []) -> Node:
    # Libraries/graphs are immutable shared resources; playback parameters and
    # property tracks are resolved independently by every actor's native tree.
    for cached in templates:
        if cached.rig == rig and cached.sampled == sampled:
            var host = instantiate(parent,cached.library,cached.graph,"Idle")
            host.set_meta("clips",rig.clips)
            host.set_meta("sampling",sampled)
            return host
    var host = build_character(parent,rig,sampled)
    templates.append({"rig":rig,"sampled":sampled,
        "library":host.get_node("AnimationPlayer").get_animation_library(""),
        "graph":host.get_meta("tree").tree_root})
    return host

static func seek_node(name: String) -> AnimationNodeBlendTree:
    var blend = AnimationNodeBlendTree.new()
    var clip = AnimationNodeAnimation.new()
    clip.animation = name
    blend.add_node("clip",clip)
    blend.add_node("seek",AnimationNodeTimeSeek.new())
    blend.connect_node("seek",0,"clip")
    blend.connect_node("output",0,"seek")
    return blend

static func destruction(parent: Node, duration: float) -> Node:
    var host = DESTRUCTION_SCENE.instantiate()
    parent.add_child(host)
    var player: AnimationPlayer = host.get_node("AnimationPlayer")
    var library: AnimationLibrary = player.get_animation_library("").duplicate(true)
    library.remove_animation("Breaking")
    library.add_animation("Breaking",animation("Breaking",duration,false,1))
    player.remove_animation_library("")
    player.add_animation_library("",library)
    return activate(host,"Intact")

static func advance(host: Node, delta: float) -> void:
    host.get_meta("tree").advance(delta)

static func save_scene(host: Node, path: String) -> void:
    var metadata = {}
    for key in host.get_meta_list():
        metadata[key] = host.get_meta(key)
        host.remove_meta(key)
    var previous_name = host.name
    host.name = "AnimationPlayback"
    for child in host.get_children(): child.owner = host
    var scene = PackedScene.new()
    scene.pack(host)
    ResourceSaver.save(scene,path)
    host.name = previous_name
    for key in metadata: host.set_meta(key,metadata[key])

static func request(host: Node, clip: String) -> void:
    var state: AnimationNodeStateMachinePlayback = host.get_meta("state")
    if state.get_current_node() != clip:
        state.travel(clip)
        host.get_meta("tree").advance(0.0)
        host.get_meta("tree").advance(0.0)

static func _enable_sampling(host: Node) -> void:
    var tree: AnimationTree = host.get_meta("tree")
    # Legacy automatic hosts may share their graph. Sampling changes topology,
    # so detach this host before converting it; siblings keep automatic returns.
    var graph: AnimationNodeStateMachine = tree.tree_root.duplicate(true)
    tree.tree_root = graph
    host.set_meta("state",tree.get("parameters/playback"))
    var player: AnimationPlayer = host.get_node("AnimationPlayer")
    for name in player.get_animation_list():
        graph.replace_node(name,seek_node(name))
    # The causal timeline decides when a displayed action ends. An automatic
    # return here would erase a held impact/death frame or resume an OA jump.
    for i in range(graph.get_transition_count()):
        var edge = graph.get_transition(i)
        edge.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
        edge.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
    host.set_meta("sampling", true)

static func sample(host: Node, clip: String, source_seconds: float, occurrence_key: String) -> Dictionary:
    var player: AnimationPlayer = host.get_node("AnimationPlayer")
    if not player.has_animation(clip):
        return {"ok":false, "error":{"kind":"authoring", "message":"Rig has no clip " + clip, "retryable":false}}
    if not is_finite(source_seconds) or source_seconds < 0.0:
        return {"ok":false, "error":{"kind":"presentation", "message":"Invalid source animation time", "retryable":false}}
    if not host.get_meta("sampling", false): _enable_sampling(host)
    var tree: AnimationTree = host.get_meta("tree")
    var state: AnimationNodeStateMachinePlayback = host.get_meta("state")
    if host.get_meta("occurrence", "") != occurrence_key or state.get_current_node() != clip:
        state.start("Idle")
        tree.advance(0.0)
        tree.advance(0.0)
        if clip != "Idle": state.travel(clip)
        tree.advance(0.0)
        tree.advance(0.0)
        host.set_meta("occurrence", occurrence_key)
    var animation_source = player.get_animation(clip)
    var time = fposmod(source_seconds, animation_source.length) if animation_source.loop_mode != Animation.LOOP_NONE else minf(source_seconds, animation_source.length)
    tree.set("parameters/" + clip + "/seek/seek_request", time)
    tree.advance(0.0)
    return {"ok":true, "value":{"clip":host.clip, "source_seconds":host.sample_seconds}}
