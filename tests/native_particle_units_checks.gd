extends SceneTree
const Units=preload("res://presentation/native_particle_units.gd")
var checks:int=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func _initialize()->void:
    var builtin=ParticleProcessMaterial.new()
    var expected:Array=Units.resource_fields().duplicate();expected.sort()
    for field in builtin.get_property_list():
        if not int(field.usage)&PROPERTY_USAGE_STORAGE:continue
        var modes:Array=[]
        if int(field.type)==TYPE_BOOL:modes=[true,false]
        elif int(field.type)==TYPE_INT and int(field.hint)==PROPERTY_HINT_ENUM:
            var index:int=0
            for choice in str(field.hint_string).split(","):
                modes.append(int(choice.get_slice(":",1)) if ":" in choice else index)
                index+=1
        else:continue
        var old:Variant=builtin.get(field.name)
        for enabled in modes:
            builtin.set(field.name,enabled)
            var actual:Array=[]
            for property in builtin.get_property_list():
                if int(property.type)==TYPE_OBJECT:actual.append(property.name)
            actual.sort()
            check(actual==expected,"Built-in resource fields unchanged by "+str(field.name)+"="+str(enabled))
        builtin.set(field.name,old)
    for prepared in [false,true]:
        for private_child in [false,true]:
            var donor=ParticleProcessMaterial.new()
            var texture=CurveTexture.new()
            texture.curve=Curve.new()
            texture.resource_local_to_scene=private_child
            texture.curve.resource_local_to_scene=private_child
            donor.scale_curve=texture
            donor.gravity=Vector3(0,-9,0)
            var a=GPUParticles3D.new();var b=GPUParticles3D.new()
            a.local_coords=false;b.local_coords=false
            a.process_material=donor;b.process_material=donor
            var first=Units.prepare(a,prepared)
            var second=Units.prepare(b,prepared)
            var shared_constant:bool=prepared and not private_child
            check(a.process_material!=donor and b.process_material!=donor and a.process_material!=b.process_material,"Emitter scalar shells remain independent")
            check(is_same(a.process_material.scale_curve,texture)==shared_constant,"Only prepared constant child remains shared")
            check(is_same(a.process_material.scale_curve,b.process_material.scale_curve)==shared_constant,"Private sibling child retains deep isolation")
            Units.apply([first],2.0)
            check(a.process_material.gravity==Vector3(0,-18,0) and b.process_material.gravity==Vector3(0,-9,0) and donor.gravity==Vector3(0,-9,0),"Scaling one emitter leaves peer and donor unchanged")
            Units.apply([second],3.0)
            check(a.process_material.gravity==Vector3(0,-18,0) and b.process_material.gravity==Vector3(0,-27,0),"Different occurrence scales remain independent")
            if not shared_constant:
                a.process_material.scale_curve.curve.add_point(Vector2(.5,.5))
                check(texture.curve.get_point_count()==0 and b.process_material.scale_curve.curve.get_point_count()==0,"Mutable nested curve leaves peer and donor unchanged")
            a.free();b.free()
    print("PARTICLE_UNITS_GUARD ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
