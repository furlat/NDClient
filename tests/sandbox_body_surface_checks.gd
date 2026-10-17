extends "res://tests/sandbox_choreography_checks.gd"
## Selected native applications -> measured body films. No game state is created.
const Surface=preload("res://sandbox/body_surface.gd")
const Conditions=preload("res://presentation/conditions.gd")
const BodySurfaces=preload("res://presentation/body_surfaces.gd")
var saved_sources:Dictionary={}
var saved_later_sources:Dictionary={}
var folder="res://.captures/body-surface"

func picture(world:Node,label:String)->Image:
    var image:Image=world.get_viewport().get_texture().get_image()
    image.convert(Image.FORMAT_RGBA8)
    image.save_png(folder+"/"+label+".png")
    return image

func changed(a:Image,b:Image)->int:
    a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
    var left=a.get_data();var right=b.get_data();var count=0
    for at in range(0,left.size(),4):
        if left[at]!=right[at] or left[at+1]!=right[at+1] or left[at+2]!=right[at+2]:count+=1
    return count

func output_entries(world:Node,actor:String)->Array:
    # Lit sprites carry the body films on their own source material.
    return world.visual_actors[actor].entries.filter(func(entry):return entry.role!="shadow")

func resample(world:Node)->void:
    world._sample_frame(0.0)
    await frame();await frame()

func film_control(world:Node,actor:String,label:String,max_strength:float)->Dictionary:
    var samples=Surface.samples(world,world.elapsed)
    check(samples.size()==1,label+": one authored body surface is active")
    if samples.size()!=1:return {}
    var binding:Dictionary=world.body_surface_bindings[0]
    check(not binding.handle.root.visible,label+": source envelope mesh does not render")
    check(is_equal_approx(samples[0].body_surface_clock,float(binding.material.get_shader_parameter("support_clock"))),label+": film uses the current native clock")
    check(is_equal_approx(samples[0].body_surface_strength,float(binding.cue.body_surface.strength)*float(binding.material.get_shader_parameter("support_envelope"))),label+": native and authored envelopes are applied once")
    check(samples[0].body_surface_strength>0.0 and samples[0].body_surface_strength<=max_strength,label+": persistent film has the authored subtle strength")
    check(samples[0].body_surface_texture==binding.material.get_shader_parameter("noise_texture"),label+": selected source owns the noise texture")
    for pair in [["body_surface_primary","primary_color"],["body_surface_secondary","secondary_color"],["body_surface_tertiary","tertiary_color"]]:
        check(samples[0][pair[0]]==binding.material.get_shader_parameter(pair[1]),label+": source colour survives unchanged ("+pair[1]+")")
    var entries=output_entries(world,actor)
    check(not entries.is_empty(),label+": assembled recipient has receiving outputs")
    for entry in entries:
        check(entry.material.get_shader_parameter("body_surface_count")==1,label+": receiving output has exactly one active film")
        var textures:Array=entry.material.get_shader_parameter("body_surface_texture")
        check(textures.size()>0 and textures[0]==samples[0].body_surface_texture,label+": outfit shares the original native noise texture")
    var on=picture(world,label+"-film")
    var strength:float=binding.cue.body_surface.strength
    binding.cue.body_surface.strength=0.0;await resample(world)
    var off=picture(world,label+"-off")
    # Existing native-body output paints a white colour through the ORIGINAL
    # receiving alpha. This observes body coverage even where dark body pixels
    # happened to match the floor; source geometry and alpha are not replaced.
    var white_image=Image.create(1,1,false,Image.FORMAT_RGBA8);white_image.fill(Color.WHITE)
    var white=ImageTexture.create_from_image(white_image)
    var native_values:Array=[]
    var native_fields=["native_body_enabled","native_body_strength","native_body_surface","native_body_ramp_count"]
    for entry in entries:
        var values:Dictionary={}
        for field in native_fields:values[field]=entry.material.get_shader_parameter(field)
        native_values.append(values)
        entry.material.set_shader_parameter("native_body_enabled",true)
        entry.material.set_shader_parameter("native_body_strength",1.0)
        entry.material.set_shader_parameter("native_body_surface",white)
        entry.material.set_shader_parameter("native_body_ramp_count",0)
    await frame();await frame()
    var coverage=world.get_viewport().get_texture().get_image();coverage.convert(Image.FORMAT_RGBA8)
    var visible:Array=[]
    for entry in entries:visible.append(entry.node.visible);entry.node.hide()
    await frame();await frame()
    var absent=world.get_viewport().get_texture().get_image()
    absent.convert(Image.FORMAT_RGBA8)
    for index in entries.size():
        entries[index].node.visible=visible[index]
        for field in native_fields:entries[index].material.set_shader_parameter(field,native_values[index][field])
    var a=on.get_data();var b=off.get_data();var c=absent.get_data();var mask=coverage.get_data()
    var changed_pixels=0;var outside=0
    for at in range(0,a.size(),4):
        if a[at]==b[at] and a[at+1]==b[at+1] and a[at+2]==b[at+2]:continue
        changed_pixels+=1
        if mask[at]==c[at] and mask[at+1]==c[at+1] and mask[at+2]==c[at+2]:outside+=1
    check(changed_pixels>20,label+": film changes actual body pixels (%d)"%changed_pixels)
    check(outside==0,label+": every changed pixel belongs to the displayed recipient (%d outside)"%outside)
    binding.cue.body_surface.strength=strength;await resample(world)
    check(changed(on,world.get_viewport().get_texture().get_image())==0,label+": paused surface restores exactly")
    var bindings:Array=world.body_surface_bindings
    world.body_surface_bindings=[];await resample(world)
    check(changed(off,world.get_viewport().get_texture().get_image())==0,label+": removing the source clears cached body materials")
    world.body_surface_bindings=bindings;await resample(world)
    check(changed(on,world.get_viewport().get_texture().get_image())==0,label+": restoring the source restores its exact film")
    observations.append({"sample":label,"changed_body_pixels":changed_pixels,"outside_body_pixels":outside,"strength":samples[0].body_surface_strength,"native_clock":samples[0].body_surface_clock})
    # Alter only the film's measurement inputs. Lit sprites also read the
    # component depth/normal for their own receiving normal, so hold lighting on
    # the flat painted-plane normal while measuring; this isolates the film's
    # actual depth/normal use, as the former separate lighting pass did.
    var lighting_normals:Array=[]
    for entry in entries:
        lighting_normals.append(entry.material.get_shader_parameter("use_component_normals"))
        entry.material.set_shader_parameter("use_component_normals",false)
    await frame();await frame()
    var flat_lit_on=world.get_viewport().get_texture().get_image()
    for entry in entries:entry.material.set_shader_parameter("body_surface_enabled",false)
    await frame();await frame()
    var flat_lit_off=world.get_viewport().get_texture().get_image()
    for entry in entries:entry.material.set_shader_parameter("body_surface_enabled",true)
    for field in ["component_depth","component_normal"]:
        var flat_image=Image.create(1,1,false,Image.FORMAT_RGBA8)
        flat_image.fill(Color8(128,128,255,255) if field=="component_normal" else Color8(128,0,0,255))
        var flat=ImageTexture.create_from_image(flat_image);var originals:Array=[]
        for entry in entries:
            originals.append(entry.material.get_shader_parameter(field))
            entry.material.set_shader_parameter(field,flat)
        await frame();await frame()
        var flattened=world.get_viewport().get_texture().get_image()
        check(changed(flat_lit_on,flattened)>0,label+": film responds to actual "+field)
        for entry in entries:entry.material.set_shader_parameter("body_surface_enabled",false)
        await frame();await frame()
        check(changed(flat_lit_off,world.get_viewport().get_texture().get_image())==0,label+": measurement control preserves existing lighting with film off")
        for index in entries.size():
            entries[index].material.set_shader_parameter(field,originals[index])
            entries[index].material.set_shader_parameter("body_surface_enabled",true)
        await frame();await frame()
        check(changed(flat_lit_on,world.get_viewport().get_texture().get_image())==0,label+": geometry control restores exact film")
    for index in entries.size():entries[index].material.set_shader_parameter("use_component_normals",lighting_normals[index])
    await frame();await frame()
    check(changed(on,world.get_viewport().get_texture().get_image())==0,label+": receiving normals restore the exact lit film")
    return {"on":on,"off":off,"coverage":coverage,"absent":absent}

func spell_check(world:Node,spell_id:String,max_strength:float)->void:
    for quarter in 4:
        world.rotate_view(quarter-world.quarter);select(world,spell_id)
        var applications:Array=world.cue_plan.cues.filter(func(cue):return not cue.has("body_surface"))
        var sustains:Array=world.cue_plan.cues.filter(func(cue):return cue.has("body_surface"))
        check(applications.size()==1 and sustains.size()==1,spell_id+": distinct native burst and surface sustain are authored")
        if applications.size()!=1 or sustains.size()!=1:return
        var application:Dictionary=applications[0]
        var sustain:Dictionary=sustains[0]
        var label="%s-q%d"%[spell_id,quarter]
        await advance(world,maxf(0.0,application.begin-.02))
        check(Surface.samples(world,world.elapsed).is_empty(),label+": no film before application")
        check(not world.handles[application.id].root.visible,label+": no early native application")
        picture(world,label+"-before")
        await advance(world,application.begin+.3)
        check(world.handles[application.id].root.visible,label+": native application is visible before sustain")
        check(Surface.samples(world,world.elapsed).is_empty(),label+": film does not replace the native burst")
        picture(world,label+"-application")
        check(sustain.begin>=application.begin and sustain.begin<application.end,label+": authored application and sustain overlap for crossfade")
        await advance(world,lerpf(sustain.begin,application.end,.5))
        check(world.handles[application.id].root.visible,label+": native application remains during crossfade")
        check(Surface.samples(world,world.elapsed).size()==1,label+": surface starts inside the authored handoff")
        picture(world,label+"-handoff")
        await advance(world,sustain.begin+1.0)
        check(not world.handles[application.id].root.visible,label+": application retires after its crossfade")
        var frames:Array=output_entries(world,sustain.target).map(func(entry):return entry.material.get_shader_parameter("frame_uv"))
        await film_control(world,sustain.target,label+"-idle-a",max_strength)
        saved_sources[spell_id]=Surface.samples(world,world.elapsed)[0].duplicate()
        await advance(world,sustain.begin+1.6)
        check(frames!=output_entries(world,sustain.target).map(func(entry):return entry.material.get_shader_parameter("frame_uv")),label+": film qualification includes distinct actual Idle source frames")
        await film_control(world,sustain.target,label+"-idle-b",max_strength)
        saved_later_sources[spell_id]=Surface.samples(world,world.elapsed)[0].duplicate()
        check(world.source_lighting.effect_sources.all(func(source):return is_zero_approx(float(source.energy))),label+": body film emits no room light")
        await advance(world,world.duration)
        check(Surface.samples(world,world.elapsed).is_empty(),label+": finite preview ends without inventing a persistent game condition")
        for entry in output_entries(world,sustain.target):check(not entry.material.get_shader_parameter("body_surface_enabled"),label+": expiry clears the receiving film")
        world.restart();pause(world)
        check(Surface.samples(world,world.elapsed).is_empty(),label+": recast starts without the retired film")
        if quarter==0:
            # Exercise the actual sandbox loop branch, not only its restart helper.
            await advance(world,sustain.begin+1.0)
            var loops:int=world.loop_count
            world.elapsed=world.duration-.001;world.playing=true;world.loop=true
            world._process(.01);pause(world)
            check(world.loop_count==loops+1 and is_zero_approx(world.elapsed),spell_id+": actual loop returns to the beginning")
            check(Surface.samples(world,world.elapsed).is_empty(),spell_id+": actual loop clears the old surface")
            for entry in output_entries(world,sustain.target):check(not entry.material.get_shader_parameter("body_surface_enabled"),spell_id+": loop resets retained output material")
            await advance(world,application.begin+.3)
            check(world.handles[application.id].root.visible and Surface.samples(world,world.elapsed).is_empty(),spell_id+": loop plays the native burst again before film")
    select(world,spell_id)
    for index in world.source_clips.size():
        if world.source_clips[index].phase=="sustain":world.select_phase(index+1);pause(world);break
    await advance(world,1.0)
    var isolated_samples:Array=Surface.samples(world,world.elapsed)
    check(isolated_samples.size()==1,spell_id+": isolated sustain has one surface")
    if isolated_samples.size()==1:await film_control(world,isolated_samples[0].actor_uuid,spell_id+"-isolated",max_strength)
    select(world,"shield");await frame();await frame()
    for id in world.visual_actors:
        for entry in output_entries(world,id):check(not entry.material.get_shader_parameter("body_surface_enabled"),spell_id+": switching spells clears previous body film")

func bind_layers(world:Node,actor:String,layers:Array)->Array:
    var value:Dictionary=Conditions.material(actor,layers)
    for entry in output_entries(world,actor):
        BodySurfaces.bind(entry.material,value.body_surfaces)
    await frame();await frame()
    return value.body_surfaces.get("layers",[])

func stack_check(world:Node)->void:
    # Real source samples on a local material fixture; no canonical conditions or
    # gameplay lifetimes are manufactured by this composition control.
    select(world,"bless")
    var sustain:Dictionary=world.cue_plan.cues.filter(func(cue):return cue.has("body_surface"))[0]
    await advance(world,sustain.begin+1.0)
    var actor:String=sustain.target
    var control:Dictionary=await film_control(world,actor,"stack-bless-baseline",.125)
    var a:Dictionary=saved_sources.false_life.duplicate();a.actor_uuid=actor
    var b:Dictionary=Surface.samples(world,world.elapsed)[0].duplicate()
    check(a.id!=b.id and a.body_surface_primary!=b.body_surface_primary,"Stack uses the distinct authored False Life and Bless sources")
    await bind_layers(world,actor,[a])
    var only_a=picture(world,"stack-false-life")
    await bind_layers(world,actor,[b])
    var only_b=picture(world,"stack-bless")
    check(changed(control.on,only_b)==0,"Binding one Bless layer preserves the production single-film pixels")
    # Renderer capacity is explicit and deterministic; this does not cap or
    # select canonical conditions. All rows here are local composition controls.
    var many:Array=[]
    for index in BodySurfaces.CAPACITY+2:
        var sample:Dictionary=a.duplicate();sample.id="capacity-%02d"%index
        sample.composition={"priority":index};many.append(sample)
    var capacity:Dictionary=BodySurfaces.compose(actor,many)
    check(capacity.layers.size()==BodySurfaces.CAPACITY and capacity.missing.size()==2,"Renderer overflow is reported rather than silently overwritten")
    check(capacity.missing.map(func(row):return row.id)==["capacity-00","capacity-01"],"Capacity reports the exact lower-priority omitted sources")
    var reversed:Array=many.duplicate();reversed.reverse()
    var reverse_capacity:Dictionary=BodySurfaces.compose(actor,reversed)
    check(capacity.layers.map(func(row):return row.id)==reverse_capacity.layers.map(func(row):return row.id),"Capacity selection is deterministic under input reordering")
    check(capacity.missing==reverse_capacity.missing,"Overflow diagnostics are stable under input reordering")
    check(BodySurfaces.compose("unrelated",many).is_empty(),"An unrelated actor receives no films")
    var inactive:Dictionary=a.duplicate();inactive.body_surface_strength=0.0
    check(BodySurfaces.compose(actor,[inactive]).is_empty(),"Zero-strength sources leave no active renderer layer")
    var ordered:Array=await bind_layers(world,actor,[a,b])
    var both=picture(world,"stack-both")
    check(ordered.size()==2,"Shared collector retains both active surface sources")
    check(changed(both,only_a)>20 and changed(both,only_b)>20,"Combined film includes visible contributions from both sources")
    for entry in output_entries(world,actor):
        check(entry.material.get_shader_parameter("body_surface_count")==2,"Every outfit output receives both layers")
        var clocks:PackedFloat32Array=entry.material.get_shader_parameter("body_surface_clock")
        var textures:Array=entry.material.get_shader_parameter("body_surface_texture")
        for index in ordered.size():
            check(is_equal_approx(clocks[index],ordered[index].body_surface_clock),"Stack keeps each native material clock")
            check(textures[index]==ordered[index].body_surface_texture,"Stack keeps each native noise texture")
    # Later values came from independently sampled actual native materials, not
    # a new clock invented by this test. Keep body pose fixed to isolate motion.
    for pair in [[a,b,"false_life"],[b,a,"bless"]]:
        var later:Dictionary=saved_later_sources[pair[2]].duplicate();later.actor_uuid=actor
        check(not is_equal_approx(later.body_surface_clock,pair[0].body_surface_clock),pair[2]+": source material advances its own native clock")
        await bind_layers(world,actor,[later,pair[1]])
        check(changed(both,world.get_viewport().get_texture().get_image())>0,pair[2]+": its independent native animation remains visible in the stack")
        await bind_layers(world,actor,[a,b])
        check(changed(both,world.get_viewport().get_texture().get_image())==0,pair[2]+": restoring that source clock restores exact stack pixels")
    # A full-strength native-body texture is an explicit shader-order control,
    # not a fabricated damage event or a new authored hit effect.
    var hit_image=Image.create(1,1,false,Image.FORMAT_RGBA8);hit_image.fill(Color(.8,.2,.1,1))
    var hit=ImageTexture.create_from_image(hit_image);var hit_previous:Array=[]
    var hit_fields=["native_body_enabled","native_body_strength","native_body_surface","native_body_ramp_count"]
    var actor_entries=output_entries(world,actor)
    for entry in actor_entries:
        var previous:Dictionary={}
        for field in hit_fields:previous[field]=entry.material.get_shader_parameter(field)
        hit_previous.append(previous)
        entry.material.set_shader_parameter("native_body_enabled",true)
        entry.material.set_shader_parameter("native_body_strength",1.0)
        entry.material.set_shader_parameter("native_body_surface",hit)
        entry.material.set_shader_parameter("native_body_ramp_count",0)
    await frame();await frame()
    var hit_with_films=world.get_viewport().get_texture().get_image()
    await bind_layers(world,actor,[])
    check(changed(hit_with_films,world.get_viewport().get_texture().get_image())==0,"Full-strength native body hit colour remains above all persistent films")
    for index in actor_entries.size():
        for field in hit_fields:actor_entries[index].material.set_shader_parameter(field,hit_previous[index][field])
    await bind_layers(world,actor,[a,b])
    check(changed(both,world.get_viewport().get_texture().get_image())==0,"Retiring the hit texture restores both persistent films")
    await bind_layers(world,actor,[b,a])
    check(changed(both,world.get_viewport().get_texture().get_image())==0,"Input array order cannot reorder stable authored composition")
    await bind_layers(world,actor,[b])
    check(changed(only_b,world.get_viewport().get_texture().get_image())==0,"Removing False Life restores exact Bless pixels")
    await bind_layers(world,actor,[a,b]);await bind_layers(world,actor,[a])
    check(changed(only_a,world.get_viewport().get_texture().get_image())==0,"Removing Bless restores exact False Life pixels")
    await bind_layers(world,actor,[])
    check(changed(control.off,world.get_viewport().get_texture().get_image())==0,"Removing all stacked sources restores the original body")
    var composed=both.get_data();var original=control.off.get_data()
    var mask=control.coverage.get_data();var absent=control.absent.get_data();var outside=0
    for at in range(0,composed.size(),4):
        if composed[at]==original[at] and composed[at+1]==original[at+1] and composed[at+2]==original[at+2]:continue
        if mask[at]==absent[at] and mask[at+1]==absent[at+1] and mask[at+2]==absent[at+2]:outside+=1
    check(outside==0,"Stacked films stay inside actual painted body coverage")
    observations.append({"sample":"stack","layers":ordered.map(func(layer):return layer.id),"outside_body_pixels":outside,"difference_from_false_life":changed(both,only_a),"difference_from_bless":changed(both,only_b)})
    await resample(world)

func run(world:Node)->void:
    DirAccess.make_dir_recursive_absolute(folder)
    await spell_check(world,"false_life",.15)
    await spell_check(world,"bless",.125)
    await stack_check(world)
    check(world.presentation_errors.is_empty(),"Body material/source geometry has no missing resources")
    FileAccess.open("res://.runtime/sandbox-body-surface-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations},"  "))
    print("SANDBOX_BODY_SURFACE ",checks," checks / ",failures.size()," failures")
    get_tree().quit(0 if failures.is_empty() else 1)
