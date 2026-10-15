extends RefCounted
## World-space ParticleProcessMaterial normalizes display axes and evaluates
## several lengths in world units. Only convert those dimensions; emission
## positions and initial velocity already include EMISSION_TRANSFORM.
const LENGTH_FIELDS=["radial_velocity_min","radial_velocity_max","gravity",
    "linear_accel_min","linear_accel_max","radial_accel_min","radial_accel_max",
    "tangential_accel_min","tangential_accel_max"]

static func prepare(emitter:GPUParticles3D)->Dictionary:
    if emitter.local_coords or not emitter.process_material is ParticleProcessMaterial:return {}
    emitter.process_material=emitter.process_material.duplicate(true)
    var material:ParticleProcessMaterial=emitter.process_material
    var fields=LENGTH_FIELDS.duplicate()
    if not material.particle_flag_inherit_emitter_scale:
        fields.append_array(["scale_3d_min","scale_3d_max"] if material.use_scale_3d else ["scale_min","scale_max"])
    if not material.particle_flag_damping_as_friction:fields.append_array(["damping_min","damping_max"])
    # Godot 4.7's ordinary directional displacement bypasses emission scale.
    fields.append_array(["directional_velocity_min","directional_velocity_max"])
    var source={}
    for field in fields:source[field]=material.get(field)
    return {"emitter":emitter,"source":source}

static func restore(bindings:Array)->void:
    for binding in bindings:
        for field in binding.source:binding.emitter.process_material.set(field,binding.source[field])

static func apply(bindings:Array,scale:float)->void:
    for binding in bindings:
        for field in binding.source:
            # Source callbacks/AnimationPlayer have just authored their current
            # values. Keep those as the next sample's unconverted starting point.
            var value=binding.emitter.process_material.get(field)
            binding.source[field]=value
            binding.emitter.process_material.set(field,value*scale)
