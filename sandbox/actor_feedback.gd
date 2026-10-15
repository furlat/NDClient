extends RefCounted
const Components=preload("res://presentation/components.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Authoring=preload("res://presentation/authoring.gd")
const SpellFeedback=preload("res://presentation/spell_feedback.gd")

static func prepare(world:Node)->Dictionary:
    var policy=Authoring.load_data("sandbox/feedback.json",world.catalog_cache)
    var profile:Dictionary=world.library.spells[world.selected_spell].get("palette",{})
    var treatment=SpellFeedback.prepare(world.recipe,profile,world.staging_spec,policy)
    var layers=Components.cast_layers(treatment.cast,world.timeline.state.actors.caster,world.catalog_cache)
    if not world.recipe.cast.get("enabled",true):layers=[]
    var colors:Array=treatment.colors
    var flash:Dictionary=treatment.flash
    var track=Tracks.body("caster","neuroclient.modular",world.recipe.cast.actionClip,world.rigs["neuroclient.modular"].clips[world.recipe.cast.actionClip],world.recipe.cast.bodyPlaybackSpeed,1)
    track.start_ms=world.spell.lead_in_seconds*1000
    track.occurrence="sandbox-cast"
    track.from_position=world.timeline.state.actors.caster.last_visual_position
    track.target_position=world.timeline.state.actors.target.last_visual_position
    var actions:Array=[]
    for spec in world.staging_spec.get("body_actions",[]):
        var body=Tracks.body(spec.actor,"neuroclient.modular",spec.clip,world.rigs["neuroclient.modular"].clips[spec.clip],float(spec.get("speed",1.0)),1)
        body.start_ms=(world.release+float(spec.after_release))*1000.0
        body.occurrence="sandbox-body-"+spec.id
        body.from_position=world.timeline.state.actors[spec.actor].last_visual_position
        body.target_position=world.timeline.state.actors[spec.target].last_visual_position
        var action_layers:Array=[]
        if spec.get("child_attack",false):
            for pose in world.recipe.get("childAttack",{}).get("poses",[]):
                if pose.clip==spec.clip and not pose.has("weaponCategory"):
                    action_layers=Components.cast_layers({"actionClip":spec.clip,"effects":pose.layers},world.timeline.state.actors[spec.actor],world.catalog_cache)
                    break
        var hit=body.start_ms+float(spec.get("contact_frame",0))/float(world.rigs[body.rig].clips[body.clip].fps)/float(spec.get("speed",1.0))*1000.0
        actions.append({"spec":spec,"track":body,"layers":action_layers,"contact_ms":hit})
    return {"layers":layers,"track":track,"colors":colors,"flash":flash,"actions":actions}

static func contacts(world:Node)->Array:
    if world.phase_mode=="Sequence":return world.cue_plan.contacts
    if world.recipe.get("damage")==null:return []
    var clip:Dictionary=world.active_clips.get("isolated",{})
    for cue in world.staging_spec.cues:
        if cue.clip!=clip.get("id"):continue
        if cue.role in ["impact","area","strike","attached"]:
            var at=float(cue.get("source_contact",0.0)) if cue.role=="strike" else 0.0
            return [{"index":0,"target":world.staging_spec.get("recipient","target"),"time":at/float(cue.get("source_rate",1.0))}]
    return []

static func samples(world:Node,time:float)->Array:
    var result:Array=[]
    var prepared:Dictionary=world.feedback
    var track:Dictionary=prepared.track
    var casting=world.phase_mode=="Sequence" or world.active_clips.get("isolated",{}).get("phase")=="cast"
    if world.phase_mode!="Sequence":
        track=track.duplicate();track.start_ms=0.0
    if casting and time*1000>=track.start_ms and time*1000<track.start_ms+track.duration_ms:
        for i in prepared.layers.size():
            result.append({"id":"sandbox-hand-%d"%i,"kind":"sprite_layer","actor_uuid":"caster",
                "layer":prepared.layers[i],"clip":track.clip,"rig":track.rig,"source_track":track,
                "age_ms":time*1000-track.start_ms,"start_ms":track.start_ms,"duration_ms":track.duration_ms,"status":"available"})
    if world.phase_mode=="Sequence":
        for action in prepared.get("actions",[]):
            var body:Dictionary=action.track
            if time*1000<body.start_ms or time*1000>=body.start_ms+body.duration_ms:continue
            for i in action.layers.size():
                result.append({"id":"%s-layer-%d"%[body.occurrence,i],"kind":"sprite_layer","actor_uuid":action.spec.actor,
                    "layer":action.layers[i],"clip":body.clip,"rig":body.rig,"source_track":body,
                    "age_ms":time*1000-body.start_ms,"start_ms":body.start_ms,"duration_ms":body.duration_ms,"status":"available"})
    if world.recipe.get("damage")==null or not world.spell_hit_flash:return result
    for contact in contacts(world):
        var age=time-contact.time
        var flash:Dictionary=prepared.flash
        if not flash.get("enabled",true):continue
        var duration:float=float(flash.get("durationMs",150))
        if age>=0 and age*1000<duration:
            result.append({"id":"sandbox-flash-%d"%contact.index,"kind":"material_flash",
                "actor_uuid":contact.target,"age_ms":age*1000,"duration_ms":duration,
                "colors":prepared.colors,"material":flash,"attachment":"body","status":"available"})
    return result

static func reactions(world:Node,time:float)->void:
    if world.recipe.get("damage")==null:return
    var clip:Dictionary=world.rigs["neuroclient.modular"].clips.TakeDamage
    var seconds=float(clip.frames)/float(clip.fps)
    for contact in contacts(world):
        var age=time-contact.time
        if age>=0 and age<seconds:
            world.displayed_samples[contact.target]={"clip":"TakeDamage","source_seconds":age,
                "occurrence":"sandbox-hit-%d"%contact.index}

static func actions(world:Node,time:float)->void:
    if world.phase_mode!="Sequence":return
    for action in world.feedback.get("actions",[]):
        var track:Dictionary=action.track
        var age=time-track.start_ms/1000.0
        if age>=0.0 and age<track.duration_ms/1000.0:
            world.displayed_samples[action.spec.actor]={"clip":track.clip,"source_seconds":age*float(action.spec.get("speed",1.0)),
                "occurrence":track.occurrence,"from_position":track.from_position,"target_position":track.target_position}
        if not action.spec.has("reaction"):continue
        var reaction:Dictionary=world.rigs[track.rig].clips[action.spec.reaction]
        var reaction_age=time-action.contact_ms/1000.0
        if reaction_age>=0.0 and reaction_age<float(reaction.frames)/float(reaction.fps):
            world.displayed_samples[action.spec.target]={"clip":action.spec.reaction,"source_seconds":reaction_age,"occurrence":track.occurrence+"-contact"}
