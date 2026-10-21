extends RefCounted
## Pure source-clock and placement mapping for an already scheduled component.
static func path(a:Vector3,b:Vector3,bend:Vector2,t:float)->Vector3:
    var forward=(b-a).normalized()
    var side=forward.cross(Vector3.UP).normalized()
    if side.is_zero_approx():side=Vector3.RIGHT
    return a.lerp(b,t)+(side*bend.x+Vector3.UP*bend.y)*sin(PI*t)

static func path_length(a:Vector3,b:Vector3,bend:Vector2)->float:
    var length=0.0
    var last=a
    for i in range(1,33):
        var next=path(a,b,bend,float(i)/32.)
        length+=last.distance_to(next);last=next
    return length

static func source_time(cue:Dictionary,time:float)->float:
    if cue.has("lifecycle"):
        # A spatial owner (Web's net) keeps its deployed pose until removal;
        # the package has no spatial lifecycle. Conditions play the package's.
        var lifecycle:Dictionary=cue.lifecycle
        var enter:float=lifecycle.get("enter_end_seconds",0)
        var hold:float=lifecycle.get("hold_start_seconds",enter)
        if time>=float(cue.get("owner_end_seconds",INF)):
            return minf(lifecycle.get("exit_end_seconds",hold),float(lifecycle.get("exit_start_seconds",hold))+time-float(cue.owner_end_seconds))
        if not cue.get("initial",false) and time<enter:return time
        return hold
    if cue.role=="flight":
        if time<cue.launch:
            return cue.source_launch*clampf((time-cue.begin)/maxf(.001,cue.launch-cue.begin),0,1)
        if time<cue.contact:
            return lerpf(cue.source_launch,cue.source_contact,(time-cue.launch)/maxf(.001,cue.contact-cue.launch))
        return cue.source_contact+time-cue.contact
    if cue.role=="strike":
        return cue.source_contact*clampf((time-cue.begin)/maxf(.001,cue.contact-cue.begin),0,1) if time<cue.contact else cue.source_contact+time-cue.contact
    return maxf(0,time-cue.begin)*float(cue.get("source_rate",1))

static func transform(cue:Dictionary,time:float,hand:Vector3,scale_multiplier:float)->Transform3D:
    var origin:Vector3=cue.from
    var direction:Vector3=cue.to-cue.from
    if cue.role=="cast":origin=hand if time<cue.launch else cue.from
    elif cue.role=="flight":
        var t=clampf((time-cue.launch)/maxf(.001,cue.contact-cue.launch),0,1)
        origin=hand if time<cue.launch else path(cue.from,cue.to,cue.bend,t)
        direction=path(cue.from,cue.to,cue.bend,minf(1,t+.002))-path(cue.from,cue.to,cue.bend,maxf(0,t-.002))
    elif cue.role in ["impact","strike"]:origin=cue.to
    elif cue.role=="area":origin=cue.ground
    elif cue.role=="attached":
        origin={"recipient_ground":cue.ground,"recipient_body":cue.to,"recipient_head":cue.to,"recipient_weapon":cue.to,
            "item":cue.to,"caster_ground":cue.get("caster_ground",cue.from),"caster_hand":hand,"caster_release":cue.from}[cue.attachment]
    if cue.get("orientation","")=="facing":direction.y=0
    var basis=Basis.IDENTITY
    var oriented:bool=cue.get("orientation","world" if cue.role in ["area","attached"] else "aim")!="world"
    if oriented and direction.length_squared()>.000001:
        basis=Basis.looking_at(direction.normalized(),Vector3.FORWARD if absf(direction.normalized().y)>.99 else Vector3.UP)
    var euler:Array=cue.get("rotation_degrees",[0,0,0])
    basis=basis*Basis.from_euler(Vector3(euler[0],euler[1],euler[2])*PI/180.)
    var offset:Array=cue.get("offset",[0,0,0])
    origin+=basis*Vector3(offset[0],offset[1],offset[2])
    var scale:float=cue.get("scale",.18)*scale_multiplier
    if cue.has("charge_scale_from") and time<cue.launch:
        var progress=clampf((time-cue.begin)/maxf(.001,cue.launch-cue.begin),0,1)
        scale*=lerpf(float(cue.charge_scale_from),1.0,smoothstep(0,1,progress))
    var axes:Array=cue.get("axis_scale",[1.0,1.0,1.0])
    return Transform3D(basis.scaled_local(Vector3(axes[0],axes[1],axes[2])*scale),origin)

## A staged node the effect lacks is reported at construction
## (EffectPackage.missing_paths) and skipped here.
static func _node(handle:Dictionary,path:Variant)->Node:
    return handle.root.get_node_or_null(NodePath(str(handle.get("path_aliases",{}).get(str(path),path))))

static func _hide(handle:Dictionary,paths:Array)->void:
    for path in paths:
        var node:Node=_node(handle,path)
        if node!=null:node.hide()

static func controls(handle:Dictionary,cue:Dictionary,time:float)->void:
    if cue.has("lifecycle"):time=source_time(cue,time)
    if cue.role=="flight" and cue.get("stop_emission_at_contact",false) and time>=cue.contact:
        for emitter in handle.emitters:emitter.emitting=false
        _hide(handle,cue.get("contact_hide",[]))
    if cue.has("emission_stop") and time>=cue.emission_stop:
        for emitter in handle.emitters:emitter.emitting=false
    if time>=float(cue.get("launch",INF)):_hide(handle,cue.get("release_hide",[]))
    var opacity=1.0-smoothstep(cue.end-float(cue.fade_out_seconds),cue.end,time) if cue.has("fade_out_seconds") else 1.0
    var keys:Array=cue.get("opacity_keys",[])
    if not keys.is_empty():
        var local_time=time-cue.begin
        var amount:float=keys[0][1]
        for index in range(1,keys.size()):
            var previous:Array=keys[index-1];var next:Array=keys[index]
            if local_time>=float(next[0]):amount=float(next[1]);continue
            amount=lerpf(float(previous[1]),float(next[1]),clampf((local_time-float(previous[0]))/maxf(.001,float(next[0])-float(previous[0])),0,1))
            break
        opacity*=amount
    # Some donors own alpha/emission in their ShaderMaterials. Bind their
    # actual controls, including light energy, instead of fading twice.
    handle.opacity=1.0 if cue.has("fade_bindings") else opacity
    for binding in handle.light_units.values():binding.node.light_energy=float(binding.energy)*handle.opacity
    for binding in cue.get("fade_bindings",[]):
        var faded:Node=_node(handle,binding.node)
        if faded!=null:faded.set_indexed(NodePath(binding.property),lerpf(float(binding.closed),float(binding.open),opacity))
    for binding in handle.opacity_bindings:
        binding.material.set_shader_parameter(binding.uniform,float(binding.native)*opacity)
    _hide(handle,cue.get("hide_nodes",[]))
    for path in cue.get("show_nodes",[]):
        var node:Node=_node(handle,path)
        if node is GeometryInstance3D:node.layers=int(handle.layer_mask);node.show()
    if (cue.has("fade_out_seconds") or cue.has("opacity_keys")) and not cue.has("fade_bindings") and handle.opacity_bindings.is_empty():
        var transparency:float=1.0-opacity
        for piece in handle.geometry:
            if piece.node.transparency!=transparency:piece.node.transparency=transparency
