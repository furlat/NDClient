extends RefCounted
## A selected native material projected onto the painted body's measured surface.
## Source handles own resources and clocks; this adapter owns no nodes or timer.

static func prepare(world:Node)->Array:
    var result:Array=[]
    var cues:Array=world.cue_plan.cues
    if world.phase_mode!="Sequence" and world.active_clips.has("isolated"):
        var clip:Dictionary=world.active_clips.isolated
        var cue:Dictionary=clip.get("placement",{}).duplicate(true)
        cue.merge({"id":"isolated","clip":clip,"begin":0.0,"end":world._isolated_seconds(clip),
            "target":world.staging_spec.get("recipient","target")},true)
        cues=[cue]
    for cue in cues:
        var spec:Dictionary=cue.get("body_surface",{})
        if spec.is_empty():continue
        var handle:Dictionary=world.handles[cue.id]
        var node:MeshInstance3D=handle.root.get_node_or_null(spec.node)
        if node==null:
            world.presentation_errors.append("Missing native body surface node: "+cue.clip.id+" / "+spec.node)
            continue
        var material:ShaderMaterial=node.get_active_material(int(spec.get("surface",0)))
        if material==null or material.get_shader_parameter("noise_texture")==null:
            world.presentation_errors.append("Missing native body surface material/noise: "+cue.clip.id)
            continue
        result.append({"cue":cue,"handle":handle,"material":material,"sample":{
            "id":"body-surface:"+cue.id,"kind":"body_surface","actor_uuid":cue.target,
            "composition":spec.get("composition",{}),
            "body_surface_texture":material.get_shader_parameter("noise_texture"),
            "body_surface_primary":material.get_shader_parameter("primary_color"),
            "body_surface_secondary":material.get_shader_parameter("secondary_color"),
            "body_surface_tertiary":material.get_shader_parameter("tertiary_color"),
            "body_surface_noise_scale":material.get_shader_parameter("noise_scale"),
            "body_surface_scroll":material.get_shader_parameter("noise_scroll"),
            "body_surface_twist":material.get_shader_parameter("noise_twist"),
            "body_surface_waviness":material.get_shader_parameter("waviness"),
            "body_surface_emission":material.get_shader_parameter("emission"),
            "body_surface_scale":float(spec.get("scale",1.0))}})
    return result

static func samples(world:Node,time:float)->Array:
    var result:Array=[]
    for binding in world.body_surface_bindings:
        var cue:Dictionary=binding.cue
        if time<cue.begin or time>=cue.end:continue
        var sample:Dictionary=binding.sample.duplicate()
        # FactorySource has already advanced and applied the authored opacity
        # once. Reading that final source value preserves both native and cue fades.
        sample.body_surface_strength=float(cue.body_surface.get("strength",1.0))*float(binding.material.get_shader_parameter("support_envelope"))
        sample.body_surface_clock=float(binding.material.get_shader_parameter("support_clock"))
        if sample.body_surface_strength>0.0:result.append(sample)
    return result
