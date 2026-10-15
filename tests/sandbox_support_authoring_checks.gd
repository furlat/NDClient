extends SceneTree
## Native support source geometry/attachment checks. Pixel appearance is qualified separately.
const Source=preload('res://sandbox/factory_source.gd')
const Choreography=preload('res://sandbox/choreography.gd')
var passed:=0
var failures:Array=[]
var observations:Array=[]
func check(ok:bool,label:String)->void:
    if ok:passed+=1
    else:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
    var batch=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/sandbox/batches/support.json')).spells
    var library=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/sandbox/projectiles.json'))
    var parent=Node3D.new();root.add_child(parent)
    for id in batch:
        var spec:Dictionary=batch[id]
        var matches=library.spells.filter(func(value):return value.id==id)
        check(matches.size()==1,id+': existing actual native source capability')
        if matches.size()!=1:continue
        var current:Dictionary=matches[0]
        check(float(spec.staging.decorative_light_multiplier)==(1.0 if id=='light' else 0.0),id+': luminous intent is explicit')
        for selected in spec.select_clips:
            var clips=current.clips.filter(func(value):return value.id==selected)
            check(clips.size()==1,selected+': native phase exists')
            if clips.size()!=1:continue
            var clip:Dictionary=clips[0].duplicate(true)
            clip.merge(spec.clip_overrides[selected],true)
            var handle:Dictionary=Source.make(parent,clip)
            check(handle.error.is_empty(),selected+': actual edited source constructs')
            if not handle.error.is_empty():Source.close(handle);continue
            var placement:Dictionary=clip.placement.duplicate(true)
            placement.merge({'from':Vector3(-2,.7,0),'to':Vector3(2,.7,0),'ground':Vector3(2,0,0),'caster_ground':Vector3(-2,0,0)},true)
            handle.root.transform=Choreography.transform(placement,0,Vector3(-2,.7,0),1.0)
            Source.sample(handle,.4,0)
            if id in ['aid','bless']:
                var mesh:MeshInstance3D=handle.root.get_node('effect/Donor/Mesh')
                var box: AABB=mesh.get_aabb()
                var bottom:Vector3=mesh.global_transform*Vector3(0,box.position.y,0)
                check(absf(bottom.y)<.0001,selected+': actual native envelope bottom rests on floor')
                observations.append({'spell':id,'phase':selected,'native_bottom_y':bottom.y})
                check(float(placement.opacity_keys.back()[1])<.25,selected+': quiet hold is explicitly authored')
                if placement.has('body_surface'):
                    var surface:Dictionary=placement.body_surface
                    var material:ShaderMaterial=handle.root.get_node(surface.node).get_active_material(int(surface.surface))
                    check(material.get_shader_parameter('noise_texture') is Texture2D,selected+': body sustain uses the actual native noise texture')
                    for field in ['primary_color','secondary_color','tertiary_color']:
                        check(material.get_shader_parameter(field) is Color,selected+': body sustain retains native '+field)
                    check(is_equal_approx(float(material.get_shader_parameter('support_envelope')),.49),selected+': original Bless sustain envelope remains .49')
                    var first_clock:float=material.get_shader_parameter('support_clock')
                    Source.sample(handle,.8,0)
                    check(not is_equal_approx(float(material.get_shader_parameter('support_clock')),first_clock),selected+': original native sustain clock animates the body pattern')
            if id in ['cure_wounds','healing_word']:
                var donor:Node3D=handle.root.get_node('effect/Donor')
                check(donor.global_position.distance_to(placement.to)<.0001,selected+': burst origin is the torso socket with no stacked export lift')
                if id=='healing_word':
                    check(handle.root.get_node('effect/Donor/verticalflash').global_position.distance_to(placement.to)<.0001,selected+': principal pulse is centered on torso')
            if id in ['guidance','thaumaturgy']:
                var mesh:MeshInstance3D=handle.root.get_node('effect/Donor/MeshInstance3D')
                check(mesh.mesh is SphereMesh,selected+': native source material occupies real3D geometry')
                var size=mesh.get_aabb().size
                check(size.x>0 and size.y>0 and size.z>0,selected+': geometry has volume from every cardinal view')
                check(not bool(mesh.material_override.get_shader_parameter('billboard')),selected+': native shader follows geometry instead of camera billboard')
                check('streaks1_count' in mesh.material_override.shader.code,selected+': actual source streak shader is retained')
            if id=='light':
                var light:OmniLight3D=handle.root.get_node('effect/Donor/Light')
                var orb:Node3D=handle.root.get_node('effect/Donor/Glow')
                check(light.global_position.distance_to(orb.global_position)<.0001,selected+': visible orb and actual light share their physical center')
                check(is_equal_approx(light.global_position.y,1.41),selected+': actual optical source retains authored head height')
                check(is_equal_approx(light.omni_range,8.0),selected+': source length converts to8worldcells exactly once')
                check(is_equal_approx(light.light_energy,3.0),selected+': real native emitter has calibrated source energy')
                check(placement.fade_bindings.size()==3,selected+': existing geometry/energy close bindings remain')
            if id=='shield_of_faith':
                var mesh:Node3D=handle.root.get_node('effect/Donor/shield_effect')
                check(is_equal_approx(mesh.global_position.y,.4875),selected+': native shield sits at waist height')
                Source.sample(handle,2.1,0)
                for name in ['external_base_ring','verticalflash2','muzzle2']:
                    check(handle.root.get_node('effect/Donor/'+name).layers==0,selected+': source animation cannot restore excluded wind/burst '+name)
            Source.close(handle)
    var strike:Dictionary=batch.true_strike.staging
    var blessing:Array=batch.bless.staging.cues
    var application:Dictionary=blessing.filter(func(cue):return not cue.has('body_surface'))[0]
    var body_sustain:Dictionary=blessing.filter(func(cue):return cue.has('body_surface'))[0]
    check(is_equal_approx(float(application.source_end),2.0) and is_equal_approx(float(body_sustain.delay_seconds),1.5),'Bless: native application hands off to body sustain over the original 1.5-2s interval')
    check(is_equal_approx(float(body_sustain.opacity_keys[1][1])*.49,.1225),'Bless: authored body-film maximum remains subtle without changing native material emission')
    check(Vector3(strike.target_position[0],strike.target_position[1],strike.target_position[2]).distance_to(Vector3(-2,0,0))<=1.0,'True Strike: follow-up recipient is in melee reach')
    var recipe=JSON.parse_string(FileAccess.get_file_as_string('res://authoring/spells/spell.true_strike.json'))
    var action:Dictionary=strike.body_actions[0]
    var poses:Array=recipe.childAttack.poses.filter(func(pose):return pose.get('weaponCategory','')=='Melee3' and pose.clip==action.clip)
    check(poses.size()==1 and not poses[0].layers.is_empty(),'True Strike: follow-up uses real Melee3 child-attack effect-layer authoring')
    check(float(action.after_release)<60.0/144.0,'True Strike: follow-up begins while native hand aura still emits')
    check(not recipe.cast.enabled,'True Strike: disabled cast is retained; the explicit later body action owns the attack')
    var report={'passed':passed,'failed':failures.size(),'failures':failures,'observations':observations,'scope':'Actual native source construction, real geometry/optical anchors, phase registration and explicit offline follow-up authoring. Native framebuffer appearance requires the separate GPU suite.'}
    FileAccess.open('res://.runtime/sandbox-support-authoring-checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_SUPPORT_AUTHORING_CHECKS ',JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
