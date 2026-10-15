extends Node
## Real render/input regressions reported during native spell inspection.
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
        world.elapsed=minf(until,world.elapsed+1./60.)
        world._sample_frame(1./60.)
        await frame()
    await frame()
func start(world:Node,id:String)->void:
    for i in world.spells.size():
        if world.spells[i].spell_id==id:world.select_spell(i);break
    world.loop=false;world.playing=false;world.set_process(false)
func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute('res://.captures/sandbox-regressions')
    start(world,'fire_bolt')
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(700,500)
    var before:Vector3=world.get_node('Target').position
    world._unhandled_input(click)
    check(world.get_node('Target').position==before,'Ordinary inspection click does not teleport target')
    world.place_marker('Target',Vector3(2,.5,0));world.placement_mode=true
    world._unhandled_input(click)
    check(is_equal_approx(world.get_node('Target').position.y,.5),'Explicit placement preserves target elevation')
    world.placement_mode=false;world.place_marker('Target',before)
    for q in 4:
        world.rotate_view(q-world.quarter);start(world,'fire_bolt')
        await advance(world,world.preparation_begin-.02)
        check(not world.handles.cast.root.visible,'Preparation respects authored starting frame')
        await advance(world,world.release-.08)
        var visual=world.visual_actors.caster
        var direction=world.ComponentRenderer._facing(world,visual.row)
        var f=int(world.playbacks.caster.sample_seconds*world.rigs[visual.row.rig].clips.Attack5.fps)
        var socket=world.recipe.cast.sourceSockets.preparation[direction][f]
        var entry=visual.entries[0];var mesh=entry.node.mesh
        var local=mesh.center_offset+Vector3((socket.x/128.-.5)*mesh.size.x,(.5-socket.y/128.)*mesh.size.y,0)
        var expected=world.camera.unproject_position(entry.node.global_transform*local)
        var actual=world.camera.unproject_position(world.handles.cast.root.global_position)
        check(expected.distance_to(actual)<.1,'Preparation anchored to actual displayed hand, view%d'%q)
        world.get_viewport().get_texture().get_image().save_png('res://.captures/sandbox-regressions/fire-bolt-q%d.png'%q)
        var fx=world.effect_layer.viewport.get_texture().get_image()
        var visible=0;var center=Vector2.ZERO
        for y in range(0,fx.get_height(),2):
            for x in range(0,fx.get_width(),2):
                if fx.get_pixel(x,y).a>.08:visible+=1;center+=Vector2(x,y)
        check(visible>5,'Native preparation actually visible, view%d'%q)
        if visible>0:
            center/=visible
            check(center.distance_to(expected)<50,'Visible preparation remains around hand, view%d'%q)
        observations.append({'view':q,'hand':str(expected),'effect_center':str(center),'pixels':visible})
        await advance(world,world.release+.01)
        check(not world.handles.cast.root.visible and world.handles.travel.root.visible,'Release transfers preparation to projectile')
    world.rotate_view(-world.quarter)
    start(world,'chill_touch')
    var hand=world.handles.impact.components.effect.get_node('Donor/punch/Skeleton3D/demonhand')
    check(hand.get_active_material(0) is ShaderMaterial,'Chill restores spectral source material')
    var anim=world.handles.impact.players[0].get_animation('punch_down_faster')
    check(anim.get_track_count()>30,'Chill restores source visual lifecycle tracks')
    await advance(world,world.arrival-.01)
    world.get_viewport().get_texture().get_image().save_png('res://.captures/sandbox-regressions/chill-emergence.png')
    check(world.handles.impact.root.visible and world.elapsed<world.arrival,'Target-local source begins before contact')
    var suppressed:Array=[]
    for piece in world.handles.impact.geometry:
        if piece.node!=hand and piece.node.visible:suppressed.append(piece.node);piece.node.hide()
    await frame()
    var hand_image=world.effect_layer.viewport.get_texture().get_image()
    hand_image.save_png('res://.captures/sandbox-regressions/chill-hand-only.png')
    var hand_pixels=0
    for y in hand_image.get_height():
        for x in hand_image.get_width():
            var pixel=hand_image.get_pixel(x,y)
            if pixel.a>.1 and pixel.g>.15:hand_pixels+=1
    check(hand_pixels>30,'Actual spectral hand renders before contact, without its flash or particles')
    observations.append({'spell':'chill_touch','hand_pixels':hand_pixels,'world_seconds':world.elapsed,'source_seconds':world.handles.impact.age})
    for node in suppressed:node.show()
    check(world.handles.impact.root.basis.get_scale().x<.04,'Chill uses authored source units')
    await advance(world,world.arrival+.1)
    world.get_viewport().get_texture().get_image().save_png('res://.captures/sandbox-regressions/chill-contact.png')
    var particles=world.effect_layer.viewport.get_texture().get_image()
    var far_pixels=0
    var target=world.camera.unproject_position(world.source_end)
    for y in range(0,particles.get_height(),2):
        for x in range(0,particles.get_width(),2):
            if particles.get_pixel(x,y).a>.08 and Vector2(x,y).distance_to(target)>120:far_pixels+=1
    check(far_pixels<5,'Chill contact has no unscaled screen-filling flare')
    start(world,'acid_splash')
    var palette=world.effect_layer.output.material
    check(palette!=null and palette.get_shader_parameter('rgb_block_pixels')==1.0,'Shared spell colour with pixelation disabled')
    for phase in ['cast','travel','impact']:
        var until:float={'cast':world.release-.08,'travel':world.release+.15,'impact':world.arrival+.15}[phase]
        await advance(world,until)
        check(world.effect_layer.output.material==palette,'All stages share the selected spell colour pass')
        world.get_viewport().get_texture().get_image().save_png('res://.captures/sandbox-regressions/acid-'+phase+'.png')
    var direction=(world.source_end-world.source_start).normalized()
    check(world.handles.travel.root.basis.x.normalized().dot(direction)>.999,'Acid native +X travels toward target')
    # Recast with an outstanding post-draw particle callback.
    world.restart();world.elapsed=world.release+.05;world._sample_frame(1./60.);world.restart();await frame()
    check(world.presentation_errors.is_empty(),'No presentation errors')
    var report={'checks':checks,'failures':failures,'observations':observations}
    FileAccess.open('res://.runtime/sandbox-regression-checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
    print('SANDBOX_REGRESSIONS ',JSON.stringify(report))
    get_tree().quit(0 if failures.is_empty() else 1)
