extends RefCounted
## World-space ParticleProcessMaterial normalizes display axes and evaluates
## several lengths in world units. Only convert those dimensions; emission
## positions and initial velocity already include EMISSION_TRANSFORM.
const LENGTH_FIELDS=["radial_velocity_min","radial_velocity_max","gravity",
    "linear_accel_min","linear_accel_max","radial_accel_min","radial_accel_max",
    "tangential_accel_min","tangential_accel_max"]
static var _resource_fields:Array=[]
static var _resource_fields_ready:bool=false

static func resource_fields()->Array:
    if not _resource_fields_ready:
        var builtin=ParticleProcessMaterial.new()
        for field in builtin.get_property_list():
            # Inspector visibility/storage usage can vary with material flags.
            # The built-in class's object property names do not.
            if int(field.type)==TYPE_OBJECT:_resource_fields.append(field.name)
        _resource_fields.make_read_only()
        _resource_fields_ready=true
    return _resource_fields

static func prepare(emitter:GPUParticles3D,prepared:bool=false)->Dictionary:
    if emitter.local_coords or not emitter.process_material is ParticleProcessMaterial:return {}
    var shallow:bool=prepared and emitter.process_material.get_script()==null
    if shallow:
        # Only prepared graphs carry the existing local-to-scene mutability
        # audit. Raw donor flags do not certify that their children are constant.
        for field in resource_fields():
            var child:Variant=emitter.process_material.get(field)
            if child is Resource and child.resource_local_to_scene:
                var immutable:bool=child is Script or child is CompressedTexture2D or (child is Shader and not child is VisualShader)
                if not immutable:
                    shallow=false
                    break
    emitter.process_material=emitter.process_material.duplicate(not shallow)
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
