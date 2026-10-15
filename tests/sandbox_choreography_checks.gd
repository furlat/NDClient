extends Node
## Native-render acceptance: editable fixture inputs -> complete visible spell staging.
## Local presentation only; these checks do not synthesize authoritative game events.
var failures:Array=[]
var checks:=0
var observations:Array=[]

func check(value:bool,message:String)->void:
    checks+=1
    if not value:failures.append(message);push_error(message)

func frame()->void:
    await get_tree().process_frame
    await RenderingServer.frame_post_draw

func advance(world:Node,until:float)->void:
    while world.elapsed<until:
        await get_tree().process_frame
        world.elapsed=minf(until,world.elapsed+1./60.)
        world._sample_frame(1./60.)
        await RenderingServer.frame_post_draw
    await frame()

func pause(world:Node)->void:
    world.playing=false;world.loop=false;world.set_process(false)

func select(world:Node,id:String)->void:
    for index in world.spells.size():
        if world.spells[index].spell_id==id:
            world.select_spell(index);pause(world);return
    check(false,'Missing requested sandbox fixture: '+id)

func capture(world:Node,name:String)->void:
    world.get_viewport().get_texture().get_image().save_png('res://.captures/choreography/'+name+'.png')

func core(handle:Dictionary,cue:Dictionary)->Node3D:
    return handle.root.get_node(cue.origin_path) if cue.has('origin_path') else handle.root

func body_material(world:Node,id:String)->ShaderMaterial:
    for entry in world.visual_actors[id].entries:
        if entry.role!='shadow':return entry.material
    return null

func reaction_seconds(world:Node)->float:
    var clip:Dictionary=world.rigs['neuroclient.modular'].clips.TakeDamage
    return float(clip.frames)/float(clip.fps)

func contact_feedback(world:Node,contact:Dictionary,label:String)->void:
    if world.staging_spec.has('light_color'):
        for source in world.source_lighting.effect_sources:
            check(source.color.is_equal_approx(Color(world.staging_spec.light_color)),label+': optical source uses authored spell hue')
    if world.recipe.get('damage')==null:
        check(world.playbacks[contact.target].clip!='TakeDamage',label+': non-damaging effect does not invent a hit')
        check(is_zero_approx(float(body_material(world,contact.target).get_shader_parameter('flash_strength'))),label+': non-damaging effect does not flash the body')
        return
    # When deliveries overlap, the newest contact owns each receiving pose.
    var newest:Dictionary=contact
    for candidate in world.cue_plan.contacts:
        if candidate.target==contact.target and candidate.time<=world.elapsed and candidate.time>=newest.time:newest=candidate
    var playback:Node=world.playbacks[contact.target]
    check(playback.clip=='TakeDamage',label+': '+contact.target+' reacts at contact')
    check(absf(playback.sample_seconds-(world.elapsed-newest.time))<.02,label+': newest arrival owns the receiving animation')
    var material=body_material(world,contact.target)
    check(float(material.get_shader_parameter('flash_strength'))>.5,label+': spell flash starts at contact')
    check(int(material.get_shader_parameter('flash_palette_count'))==world.feedback.colors.size(),label+': full spell palette reaches target')
    var bound:PackedVector3Array=material.get_shader_parameter('flash_palette')
    var expected=PackedVector3Array()
    for colour in world.feedback.colors:
        var value=int(colour)
        expected.append(Vector3((value>>16)&255,(value>>8)&255,value&255)/255.)
    check(bound.slice(0,expected.size())==expected,label+': receiving shader has the shared spell ramp')

func source_feedback(world:Node)->void:
    if world.spell.spell_id!='chill_touch':return
    var hand:MeshInstance3D=world.handles.values()[0].root.get_node('effect/Donor/punch/Skeleton3D/demonhand')
    var native:ShaderMaterial=hand.get_active_material(0)
    var gradient:GradientTexture1D=native.get_shader_parameter('Color1DGradient')
    var expected:Array=[]
    for value in gradient.gradient.colors:expected.append(value.to_html(false).hex_to_int())
    check(world.feedback.colors==expected,'Chill Touch: feedback derives from the native hand after original necrotic treatment')
    for colour in gradient.gradient.colors:
        check(colour.g>colour.r and colour.g>colour.b,'Chill Touch: original green source treatment survives recovered material binding')
    check(hand.get_parent().get_parent().scale.is_equal_approx(Vector3.ONE*6.),'Chill Touch: native punch scale is preserved without the previous 1.2 enlargement')
    for entry in world.visual_actors.caster.entries:
        if entry.actor_layer.get('effect',{}).is_empty() or not entry.node.visible:continue
        var bound:PackedVector3Array=entry.material.get_shader_parameter('effect_palette')
        var authored=PackedVector3Array()
        for value in expected:authored.append(Vector3((value>>16)&255,(value>>8)&255,value&255)/255.)
        check(bound.slice(0,authored.size())==authored,'Chill Touch: displayed hand magic uses the same authored necrotic treatment')

func restored(world:Node,label:String)->void:
    for id in ['target','target2']:
        check(world.playbacks[id].clip=='Idle',label+': '+id+' returns to Idle')
        check(is_zero_approx(float(body_material(world,id).get_shader_parameter('flash_strength'))),label+': '+id+' restores its base material')

func cut_pixels(before:Image,after:Image)->int:
    var count=0
    for y in range(0,before.get_height(),2):
        for x in range(0,before.get_width(),2):
            var a=before.get_pixel(x,y);var b=after.get_pixel(x,y)
            var difference=absf(a.a-b.a)+absf(a.r*a.a-b.r*b.a)+absf(a.g*a.a-b.g*b.a)+absf(a.b*a.a-b.b*b.a)
            if difference>.12:count+=1
    return count

func ending_evidence(world:Node,cue:Dictionary,label:String)->void:
    # Hide only the expiring source at the same paused time. Any large difference
    # is real visible geometry/particles about to be cut, not a moving background.
    var handle:Dictionary=world.handles[cue.id]
    var before=world.effect_layer.viewport.get_texture().get_image()
    handle.root.hide();await frame()
    var after=world.effect_layer.viewport.get_texture().get_image()
    var removed=cut_pixels(before,after)
    handle.root.show();await frame()
    before.save_png('res://.captures/choreography/'+label+'-before-retire.png')
    observations.append({'ending':label,'source_seconds':handle.age,'removed_pixel_samples':removed})
    check(removed<=64,label+': native tail is visually spent before retirement (%d sampled pixels)'%removed)

func finish_sequence(world:Node,id:String,first_contact:Dictionary)->void:
    var moments:Array=[]
    var contacts:Array=world.cue_plan.contacts
    for index in contacts.size():
        var epsilon=.015
        if index+1<contacts.size():epsilon=minf(epsilon,maxf(.0001,(contacts[index+1].time-contacts[index].time)*.25))
        moments.append({'time':float(contacts[index].time)+epsilon,'kind':'contact','contact':contacts[index]})
    for cue in world.cue_plan.cues:
        if cue.end>world.elapsed+.02:moments.append({'time':cue.end-.02,'kind':'tail','cue':cue})
        if cue.end+.001<world.duration:moments.append({'time':cue.end+.001,'kind':'retired','cue':cue})
    var recovery=float(contacts.back().time)+reaction_seconds(world)+.02 if not contacts.is_empty() and world.recipe.get('damage')!=null else world.elapsed+.02
    check(recovery<world.duration,id+': receiving animation fits inside the clip')
    moments.append({'time':minf(recovery,world.duration-.01),'kind':'restored'})
    moments.append({'time':minf(world.duration-.05,float(first_contact.time)+.5),'kind':'capture'})
    moments.sort_custom(func(a,b):return a.time<b.time)
    for moment in moments:
        if moment.time<world.elapsed-.00001:continue
        await advance(world,moment.time)
        if moment.kind=='contact':
            contact_feedback(world,moment.contact,id+' contact%d'%moment.contact.index)
            if moment.contact==first_contact:capture(world,id+'-contact')
        elif moment.kind=='tail':
            var cue:Dictionary=moment.cue
            var handle:Dictionary=world.handles[cue.id]
            check(handle.root.visible,id+': '+cue.role+' keeps its tail until authored completion')
            if cue.get('stop_emission_at_contact',false) or cue.has('emission_stop'):
                check(handle.emitters.all(func(p):return not p.emitting),id+': expired source has stopped emitting')
            var probe=(id=='fire_bolt' and cue.role=='impact') or (id=='sleep' and cue.role=='area') or (id=='produce_flame' and cue.role=='flight') or (id in ['fireball','poison_spray'] and cue.role=='cast')
            if probe:await ending_evidence(world,cue,id+'-'+cue.role)
        elif moment.kind=='retired':check(not world.handles[moment.cue.id].root.visible,id+': completed '+moment.cue.role+' leaves no stale output')
        elif moment.kind=='restored':restored(world,id)
        elif moment.kind=='capture':capture(world,id+'-tail')
    await advance(world,world.duration)
    restored(world,id+' end')
    check(world.handles.values().all(func(h):return not h.root.visible),id+': no native source survives clip end')
    # This is an iteration fixture: a 42/45-second GPU trail allocation must not
    # become a 42/45-second clip with an empty ending.
    check(world.duration<8.0,id+': default clip has no long empty allocation tail (%.2fs)'%world.duration)
    var texture_count=world.textures.size()
    var loop_count:int=world.loop_count
    world.loop=true;world.playing=true;world._process(.01);pause(world)
    check(world.elapsed==0 and world.loop_count==loop_count+1,id+': complete staging loops to its beginning')
    check(world.textures.size()==texture_count,id+': looping performs no new actor texture loads')
    restored(world,id+' loop')

func held_registration(world:Node,id:String)->void:
    var hand:Vector3=world._preparation_point()
    var release:Dictionary=world.socket_samples.get('release',{})
    check(release.get('supported',false),id+': release uses admitted surface of cast pose ('+str(release.get('reason','missing'))+')')
    check(release.get('clip','')==world.recipe.cast.actionClip and release.get('frame',-1)==int(world.recipe.cast.releaseFrame),id+': release depth comes from its authored future frame')
    for cue in world.cue_plan.cues:
        if cue.role=='flight' and world.elapsed>=cue.begin and world.elapsed<cue.launch:
            var handle:Dictionary=world.handles[cue.id]
            check(handle.root.visible and core(handle,cue).global_position.distance_to(hand)<.001,id+': native projectile core charges at displayed hand')

func moved_hand_layers(world:Node)->void:
    select(world,'fire_bolt')
    var previous:Vector3=world.get_node('Target').position
    world.place_marker('Target',world.get_node('Caster').position+Vector3(0,0,3));pause(world)
    await advance(world,world.release-.06)
    var body_uv:Vector4=body_material(world,'caster').get_shader_parameter('frame_uv')
    var effects=0
    for entry in world.visual_actors.caster.entries:
        if entry.actor_layer.get('effect',{}).is_empty() or not entry.node.visible:continue
        var effect_uv:Vector4=entry.material.get_shader_parameter('frame_uv')
        check(is_equal_approx(effect_uv.x,body_uv.x) and is_equal_approx(effect_uv.y,body_uv.y),'Moved target: hand magic uses the same pose/facing as the body')
        effects+=1
    check(effects>0,'Moved target: authored hand layers remain visible')
    held_registration(world,'Moved target')
    capture(world,'fire-bolt-repositioned')
    world.place_marker('Target',previous);pause(world)

func multiple_recipients(world:Node,split:bool,speed:float)->void:
    select(world,'magic_missile')
    world.split_targets=split;world.flight_speed=speed;world.restart();pause(world)
    var contacts:Array=world.cue_plan.contacts
    check(contacts.size()==3,'Magic Missile schedules three deliveries')
    var by_delivery={}
    for contact in contacts:by_delivery[int(contact.index)]=contact.target
    check(by_delivery=={0:'target',1:'target2' if split else 'target',2:'target'},'Magic Missile preserves recipients independently of arrival order')
    for index in range(1,contacts.size()):check(contacts[index-1].time<=contacts[index].time,'Magic Missile processes arrivals chronologically')
    var last_time=-1.0
    for index in contacts.size():
        var contact:Dictionary=contacts[index]
        var epsilon=.015
        if index+1<contacts.size():epsilon=minf(epsilon,maxf(.0001,(contacts[index+1].time-contact.time)*.25))
        await advance(world,contact.time+epsilon)
        contact_feedback(world,contact,'Magic Missile '+('split' if split else 'slow same target')+' arrival%d'%contact.index)
        check(world.elapsed>=last_time,'Recipient checks never seek backwards')
        last_time=world.elapsed
        capture(world,'magic-missile-'+('split' if split else 'slow')+'-arrival%d'%contact.index)
    await advance(world,contacts.back().time+reaction_seconds(world)+.02)
    restored(world,'Magic Missile all recipients')
    world.split_targets=false

func reported_regressions(world:Node)->void:
    for id in ['fireball','poison_spray']:
        select(world,id)
        var cast:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=='cast')[0]
        var handle:Dictionary=world.handles[cast.id]
        await advance(world,world.release+.21)
        check(handle.root.visible,id+': released preparation retains its native particle tail')
        if id=='fireball':
            check(not handle.root.get_node('formation/Source/Donor/FireTorch_AC8').visible,'Fireball: held mesh hands off at release')
        else:
            check(handle.root.get_node('formation/Source/Donor/AnimationPlayer').current_animation=='End','Poison: preparation uses native End animation')
        check(handle.emitters.filter(func(e):return e.layers!=0 and e.visible).all(func(e):return not e.emitting),id+': preparation has stopped emission after release')
    for view in 4:
        world.rotate_view(view-world.quarter)
        for id in ['eldritch_blast','guiding_bolt','ice_knife','produce_flame']:
            select(world,id)
            var flight:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=='flight')[0]
            var handle:Dictionary=world.handles[flight.id]
            await advance(world,world.release-.001)
            var held:Vector3=core(handle,flight).global_position
            if id=='eldritch_blast':
                var cast:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=='cast')[0]
                check(cast.begin>=world.preparation_begin,'Eldritch: preparation waits for its authored hand frame')
                check(core(world.handles[cast.id],cast).global_position.distance_to(held)<.001,'Eldritch view%d: actual cast Flare and flight MBall meet'%view)
            await advance(world,world.release)
            check(core(handle,flight).global_position.distance_to(world.source_start)<.001,id+' view%d: actual core meets the release socket'%view)
            check(world.camera.unproject_position(core(handle,flight).global_position).distance_to(world.camera.unproject_position(held))<3.0,id+' view%d: no visible launch-position jump'%view)
            if id=='ice_knife' or id=='produce_flame':
                var mesh:MeshInstance3D=core(handle,flight)
                var dimensions:Vector3=(mesh.global_transform*mesh.get_aabb()).size
                check(dimensions.length()<.8,id+': charged core is less than one tile, not a two-tile lance')
            if id=='produce_flame':
                check(world.cue_plan.cues.filter(func(c):return c.role in ['flight','cast']).size()==1,'Produce Flame: one instance owns formation and flight, without a second hand flame')
            await advance(world,lerpf(world.release,world.arrival,.5))
            if id=='guiding_bolt':
                var trail:MeshInstance3D=handle.root.get_node('travel/Donor/Trail2_dynamic')
                check(trail.mesh.get_surface_count()>0,'Guiding view%d: native trail has travel history'%view)
                if trail.mesh.get_surface_count()>0:
                    var points:PackedVector3Array=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
                    var widest=0.0
                    for i in range(0,points.size()-1,2):
                        widest=maxf(widest,world.camera.unproject_position(trail.to_global(points[i])).distance_to(world.camera.unproject_position(trail.to_global(points[i+1]))))
                    check(widest>2.0,'Guiding view%d: ribbon retains visible width instead of turning edge-on'%view)
            if id=='ice_knife':
                check(world.source_lighting.effect_sources.any(func(s):return s.id.ends_with('FlightLight') and s.visible and s.energy>0),'Ice Knife: source-wrapper blue light follows the flying knife')
                await advance(world,world.arrival)
                var cast:Dictionary=world.cue_plan.cues.filter(func(c):return c.role=='cast')[0]
                check(cast.end<world.arrival and not world.handles[cast.id].root.visible,'Ice Knife: bounded hand preparation finishes before impact')
    world.rotate_view(-world.quarter)

func flash_toggle(world:Node)->void:
    select(world,'fire_bolt')
    check(world.spell_hit_flash and world.hit_flash_button.button_pressed,'Spell hit flash defaults on')
    await advance(world,world.arrival+.01)
    var time:float=world.elapsed
    var source_age:float=world.playbacks.target.sample_seconds
    check(float(body_material(world,'target').get_shader_parameter('flash_strength'))>.5,'Receiver has spell flash before toggling')
    capture(world,'spell-hit-flash-on')
    world.hit_flash_button.button_pressed=false
    check(not world.spell_hit_flash and is_zero_approx(float(body_material(world,'target').get_shader_parameter('flash_strength'))),'Actual UI toggle immediately removes only the receiving flash')
    check(world.playbacks.target.clip=='TakeDamage' and is_equal_approx(world.playbacks.target.sample_seconds,source_age),'Disabling flash preserves TakeDamage and its current frame')
    check(is_equal_approx(world.elapsed,time),'Flash toggle does not restart or advance playback')
    await frame()
    capture(world,'spell-hit-flash-off')
    world.hit_flash_button.button_pressed=true
    check(float(body_material(world,'target').get_shader_parameter('flash_strength'))>.5,'Re-enabling restores the current contact flash')

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute('res://.captures/choreography')
    check(world.library.spells.filter(func(s):return not s.has('batch')).size()==14,'Original fourteen capabilities remain grouped by spell')
    for index in world.spells.size():
        if world.library.spells[index].has("batch"):continue
        world.select_spell(index);pause(world)
        var id:String=world.spell.spell_id
        var original:Dictionary=world.cue_plan.duplicate(true)
        var release:float=world.release
        world.flight_speed*=.5;world.restart();pause(world)
        check(is_equal_approx(world.release,release),id+': flight speed preserves cast release')
        var slow:Dictionary=world.cue_plan.duplicate(true)
        for i in original.cues.size():
            if original.cues[i].role=='cast':check(is_equal_approx(original.cues[i].end,slow.cues[i].end),id+': flight speed preserves preparation source clock')
        if not world.staging_spec.get('target_local',false):check(slow.contacts[0].time>original.contacts[0].time,id+': independent flight speed changes arrival')
        world.flight_speed*=2;world.restart();pause(world)
        await advance(world,maxf(world.spell.lead_in_seconds+.02,world.release-.06))
        var magic=0
        for entry in world.visual_actors.caster.entries:
            if not entry.actor_layer.get('effect',{}).is_empty() and entry.node.visible:magic+=1
        check(magic>0,id+': actual authored character magic layers visible')
        source_feedback(world)
        held_registration(world,id)
        capture(world,id+'-charge')
        var ages={}
        var instances={}
        for key in world.handles:
            ages[key]=world.handles[key].age
            instances[key]=world.handles[key].root.get_instance_id()
        for quarter in 4:
            world.rotate_view(1)
            held_registration(world,id+' view%d'%world.quarter)
            for key in ages:
                check(world.handles[key].root.get_instance_id()==instances[key],id+': rotation retains source instances')
                check(is_equal_approx(world.handles[key].age,ages[key]),id+': rotation preserves native source time')
        await advance(world,world.release+.04)
        var overlap=0
        for cue in world.cue_plan.cues:
            if cue.role=='cast' and world.handles[cue.id].root.visible:overlap+=1
        if original.cues.any(func(c):return c.role=='cast'):check(overlap>0,id+': preparation tail overlaps release')
        var contact:Dictionary=world.cue_plan.contacts[0]
        observations.append({'spell':id,'release':world.release,'contacts':world.cue_plan.contacts.duplicate(true),'duration':world.duration,'cues':world.cue_plan.cues.size(),'magic_layers':magic})
        await finish_sequence(world,id,contact)
        check(world.presentation_errors.is_empty(),id+': renderer has no missing media')
    await moved_hand_layers(world)
    await multiple_recipients(world,true,8.0)
    await multiple_recipients(world,false,1.0)
    await reported_regressions(world)
    await flash_toggle(world)
    check(world.presentation_errors.is_empty(),'No missing actor or effect media')
    var report={'checks':checks,'failures':failures,'observations':observations}
    FileAccess.open('res://.runtime/sandbox-choreography-checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_CHOREOGRAPHY ',JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
