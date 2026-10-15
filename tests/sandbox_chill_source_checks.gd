extends SceneTree
## Material/lifecycle qualification of the actual imported source; no GPU pixel claims.
const Source=preload('res://sandbox/factory_source.gd')
var passed=0
var failures:Array=[]
func check(value:bool,label:String)->void:
    if value:passed+=1
    else:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var library=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/sandbox/projectiles.json'))
    var clip:Dictionary={}
    for spell in library.spells:
        if spell.id=='chill_touch':clip=spell.clips[0]
    check(not clip.is_empty(),'Chill Touch selects its real native source')
    if clip.is_empty():finish();return
    var parent=Node3D.new();root.add_child(parent)
    var handle=Source.make(parent,clip.duplicate(true))
    check(handle.error.is_empty(),'Native source and recovered hand/animation construct')
    if not handle.error.is_empty():Source.close(handle);finish();return
    var component=handle.components.effect
    var donor:Node3D=component.subject
    var hand:MeshInstance3D=donor.get_node('punch/Skeleton3D/demonhand')
    var material:ShaderMaterial=hand.get_active_material(0)
    var gradient:GradientTexture1D=material.get_shader_parameter('Color1DGradient')
    var native_colours:Array=[]
    for colour in gradient.gradient.colors:native_colours.append(colour.to_html(false))
    check(native_colours==['041402','53e036','69e051'],'Recovered hand material receives original Factory necrotic transform')
    var staging=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/sandbox/staging.json')).spells.chill_touch
    check(staging.feedback_palette.colors==native_colours,'Hand magic and recipient feedback share the actual native treatment')
    check(staging.target_local and staging.cues[0].scale==.06,'Presentation remains target-local at the reduced authored scale')
    check(donor.rotation.is_zero_approx(),'Source adapter does not duplicate the authored staging rotation')
    check(donor.get_node('punch').scale.is_equal_approx(Vector3.ONE*6.),'Source adapter preserves native hand scale')
    check(donor.get_node('portal').layers!=0,'Requested portal remains admitted as the explicit restored source layer')
    for name in ['debirs_mini_FINAL','debirs_mini_A','SmCrackaura1998','Decal','muzzle2start','muzzle2end']:
        check(donor.get_node(name).layers==0,'Original Chill donor-layer exclusion remains explicit: '+name)
    var puff:GPUParticles3D=donor.get_node('portaldustring2')
    var original_scale=Vector2(puff.process_material.scale_min,puff.process_material.scale_max)
    Source.sample(handle,2.,0.)
    check(component.tick==288 and puff.layers!=0,'Native smoke survives the removed 236-tick export cutoff')
    for name in ['debirs_mini_FINAL','debirs_mini_A','SmCrackaura1998','Decal','muzzle2start','muzzle2end']:
        check(donor.get_node(name).layers==0,'Native animation cannot re-enable excluded donor layer: '+name)
    check(Vector2(puff.process_material.scale_min,puff.process_material.scale_max)==original_scale,'Source sampling does not enlarge the puff')
    check(absf(handle.native_animation_end-7.93333339691162)<.00001,'Complete recovered source animation remains available')
    # The cached donor resource must not be mutated by a recoloured occurrence.
    var second=Source.make(parent,clip.duplicate(true))
    var other:MeshInstance3D=second.components.effect.subject.get_node('punch/Skeleton3D/demonhand')
    var other_material:ShaderMaterial=other.get_active_material(0)
    check(not is_same(material,other_material),'Each occurrence owns its material instance')
    check(other_material.get_shader_parameter('Color1DGradient').gradient.colors==gradient.gradient.colors,'Second occurrence receives one identical recolouring, not accumulated hue transforms')
    Source.close(second);Source.close(handle)
    finish()
func finish()->void:
    var report={'passed':passed,'failed':failures.size(),'failures':failures,'scope':'Actual source construction, original necrotic material, complete lifecycle and instance isolation. Rendered scale/appearance require native captures.'}
    FileAccess.open('res://.runtime/sandbox-chill-source-checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_CHILL_SOURCE_CHECKS ',JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
