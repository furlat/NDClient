"""Studio scenarios are roles, legal setup and ordered player commands.

Baseline casts exercise safety only. They do not claim the richer lifecycle,
outcome or visual coverage described by an explicitly choreographed study.
"""


def subjects(spells=(), actions=(), conditions=()):
    return {'spell':list(spells), 'action':list(actions), 'condition':list(conditions),
        'creature':[], 'environment_object':[], 'spatial_effect':[], 'residue':[], 'item':[]}


def actors(spells=()):
    return [
        {'role':'caster', 'side':'amber', 'creature':'creature.generic_caster', 'level':20,
         'caster_level':20, 'spells':list(spells), 'at':[3,7]},
        {'role':'ally', 'side':'amber', 'creature':'creature.generic_caster', 'level':20, 'at':[3,8]},
        {'role':'target', 'side':'blue', 'creature':'creature.generic_caster', 'level':20, 'at':[4,7]},
        {'role':'second_target', 'side':'blue', 'creature':'creature.generic_caster', 'level':20, 'at':[4,8]}]


def spell_baselines(inventory):
    result=[]
    for spell in sorted(inventory['ids']['spell']):
        roster=actors([spell])
        step={'do':spell, 'by':'caster', 'target':'first_legal', 'aim':[6,7]}
        required=[spell]
        if spell=='spell.acid_flask':
            roster[0]['spells']=[];roster[0]['items']=['consumable.acid_flask']
            step['aim']=[4,7]
        elif spell=='spell.animal_friendship':
            roster[2]={'role':'target','side':'blue','creature':'creature.wolf','at':[4,7]}
        elif spell=='spell.revivify':
            roster[1]={'role':'ally','side':'amber','premade':'fighter','at':[3,8],'damage':999}
            step['target']='ally'
        elif spell=='spell.spare_the_dying':
            roster[1]={'role':'ally','side':'amber','premade':'fighter','at':[3,8],'damage':44}
            step['target']='ally'
        elif spell=='spell.shillelagh':
            roster[0]['items']=[{'id':'weapon.quarterstaff','slot':'MELEE_MAIN'}]
        elif spell in ('spell.arcane_sword','spell.dimension_door','spell.telekinesis'):
            step['then']=[5,7] if spell=='spell.arcane_sword' else [6,7]
        elif spell=='spell.divine_smite':
            roster[0]={'role':'caster','side':'amber','premade':'paladin','at':[3,7]}
            roster[2]={'role':'target','side':'blue','creature':'creature.goblin','at':[4,7],'conditions':['condition.prone']}
            step={'do':'action.attack','by':'caster','target':'target'}
            required=['reaction.class_feature.paladin.divine_smite']
        elif spell=='spell.hellish_rebuke':
            roster[0]={'role':'caster','side':'amber','creature':'creature.spell.fire_myrmidon','at':[3,7]}
            roster[2]['spells']=['spell.magic_missile']
            step={'do':'spell.magic_missile','by':'target','target':'caster','recipients':['caster']*3}
            required=['reaction.spell.hellish_rebuke']
        if spell in ('spell.magic_missile','spell.scorching_ray'):
            step['recipients']=['target']*3
        if spell in ('spell.shield','spell.counterspell'):
            roster[0]['spells']=[]
            roster[0]['behaviors']=['reaction.spell.shield' if spell=='spell.shield' else 'reaction.spell.counterspell']
            trigger='spell.magic_missile' if spell=='spell.shield' else 'spell.fire_bolt'
            roster[2]['spells']=[trigger]
            step={'do':trigger, 'by':'target', 'target':'caster', 'recipients':['caster']*3 if spell=='spell.shield' else []}
            required=[] if spell=='spell.shield' else ['reaction.spell.counterspell']
        scenario={'id':spell+'/baseline', 'title':spell.removeprefix('spell.').replace('_',' ').title()+': legal baseline',
            'kind':'spell', 'subjects':subjects([spell]), 'actors':roster, 'steps':[step], 'seed':2,
            'required_behaviors':required, 'purpose':'Current-engine baseline cast/reaction safety; visual/lifecycle qualification is separate.'}
        if spell=='spell.shield':scenario['required_conditions']=['condition.spell.shield']
        result.append(scenario)
    return result


def first_cohort():
    caster=actors(['spell.fire_bolt','spell.fireball','spell.haste'])
    caster[2]['at']=[9,7];caster[3]['at']=[9,8]
    flyers=actors(['spell.fly']);flyers[0]['items']=[{'id':'apparel.cloak','slot':'Cloak'}]
    flyers[2]['at']=[9,7];flyers[3]['at']=[9,8]
    walkers=actors();walkers[2]['at']=[9,7];walkers[3]['at']=[9,8]
    hidden=actors(['spell.fire_bolt']);hidden[0]['behaviors']=['action.hide']
    hidden[2]['at']=[9,7];hidden[3]['at']=[9,8]
    hidden[2]['items']=[{'id':'equipment.portable_torch','ignite':True}]
    combat=[{'role':'caster','side':'amber','premade':'fighter','at':[3,7]},
            {'role':'ally','side':'amber','creature':'creature.knight','at':[3,8]},
            {'role':'target','side':'blue','creature':'creature.goblin','damage':6,'at':[4,7]},
            {'role':'second_target','side':'blue','creature':'creature.goblin','at':[9,8]}]
    doors=[{'role':'caster','side':'amber','premade':'fighter','at':[6,6]},
           {'role':'ally','side':'amber','premade':'sorcerer','at':[5,6]},
           {'role':'target','side':'blue','creature':'creature.goblin','at':[16,6]},
           {'role':'second_target','side':'blue','creature':'creature.goblin','at':[18,6]}]
    shield=actors();shield[0]['behaviors']=['reaction.spell.shield'];shield[2]['spells']=['spell.magic_missile']
    raging=actors();raging[0]={'role':'caster','side':'amber','premade':'barbarian','at':[3,7]}
    raging[2]={'role':'target','side':'blue','creature':'creature.knight','at':[5,7]};raging[3]['at']=[9,8]
    healers=actors();healers[0]={'role':'caster','side':'amber','premade':'cleric','at':[3,7]}
    healers[1]={'role':'ally','side':'amber','creature':'creature.knight','at':[4,7],'damage':38}
    healers[2]={'role':'target','side':'blue','creature':'creature.knight','at':[9,7]}
    healers[3]={'role':'second_target','side':'amber','creature':'creature.knight','at':[4,8],'damage':39}
    return [
        {'id':'action.class.cleric.preserve_life/recipients','title':'Preserve Life: one invocation and actual recipient healing','kind':'action',
         'subjects':subjects(actions=['action.class.cleric.preserve_life']), 'actors':healers,'seed':2,
         'steps':[{'do':'action.class.cleric.preserve_life','by':'caster','target':'self'}],
         'required_behaviors':['action.class.cleric.preserve_life'],'required_facts':['heal']},
        {'id':'action.class.barbarian.frenzy/lifecycle','title':'Frenzy: real Rage owner, movement, attack and removal','kind':'action',
         'subjects':subjects(actions=['action.class.barbarian.frenzy','action.move','action.attack','action.class.barbarian.end_rage'],
                             conditions=['class_feature.barbarian.raging','class_feature.barbarian.frenzied']),
         'actors':raging,'seed':2,
         'steps':[{'do':'action.class.barbarian.frenzy','by':'caster','target':'self','track':True,'track_condition':'class_feature.barbarian.raging'},
                  {'do':'hold_walk','offset':[1,0]}, {'do':'action.attack','by':'caster','target':'target'},
                  {'do':'end_turn','by':'caster'}, {'do':'action.class.barbarian.end_rage','by':'caster','target':'self'}],
         'required_behaviors':['action.class.barbarian.frenzy','action.class.barbarian.end_rage'],
         'required_conditions':['class_feature.barbarian.raging','class_feature.barbarian.frenzied'],
         'required_condition_ends':['class_feature.barbarian.raging','class_feature.barbarian.frenzied']},
        {'id':'action.move/ordinary', 'title':'Movement: idle, route, stop', 'kind':'action',
         'subjects':subjects(actions=['action.move']), 'actors':walkers, 'seed':2,
         'steps':[{'do':'action.move','by':'caster','target':[2,7]}]},
        {'id':'spell.haste/lifecycle', 'title':'Haste: apply, move, concentration ends, restored', 'kind':'spell',
         'subjects':subjects(['spell.haste'], ['action.move','action.drop_concentration'], ['condition.spell.haste']),
         'actors':caster, 'seed':2,
         'steps':[{'do':'spell.haste','by':'caster','target':'self','track':True,'track_condition':'condition.spell.haste'},
                  {'do':'hold_walk','offset':[-1,0]}, {'do':'end_tracked','strategy':'concentration'},
                  {'do':'end_turn','by':'caster'}, {'do':'tail_walk','offset':[0,-1]}]},
        {'id':'spell.fly/lifecycle', 'title':'Fly: wings, movement, equipment, removal and restoration', 'kind':'spell',
         'subjects':subjects(['spell.fly'], ['action.move','action.drop_concentration'], ['condition.spell.fly']),
         'actors':flyers, 'seed':2,
         'steps':[{'do':'spell.fly','by':'caster','target':'self','track':True,'track_condition':'condition.spell.fly'},
                  {'do':'hold_walk','offset':[-1,0]}, {'do':'unequip','by':'caster','slot':'Cloak'},
                  {'do':'end_turn','by':'caster'}, {'do':'equip','by':'caster','slot':'Cloak','item':'apparel.cloak'},
                  {'do':'hold_walk','offset':[0,-1]}, {'do':'end_tracked','strategy':'concentration'},
                  {'do':'tail_walk','offset':[1,0]}],
         'required_behaviors':['spell.fly'], 'required_conditions':['condition.spell.fly'],
         'required_condition_ends':['condition.spell.fly']},
        {'id':'spell.fire_bolt/hit', 'title':'Fire Bolt: cast and actual recipient damage', 'kind':'spell',
         'subjects':subjects(['spell.fire_bolt']), 'actors':caster, 'seed':2,
         'steps':[{'do':'spell.fire_bolt','by':'caster','target':'target'}], 'required_behaviors':['spell.fire_bolt']},
        {'id':'spell.fireball/area', 'title':'Fireball: release, area and recipient outcomes', 'kind':'spell',
         'subjects':subjects(['spell.fireball']), 'actors':caster, 'seed':2,
         'steps':[{'do':'spell.fireball','by':'caster','target':[6,7]}], 'required_behaviors':['spell.fireball']},
        {'id':'action.hide/lifecycle','title':'Hide: crouch, movement, attack reveals','kind':'action',
         'subjects':subjects(['spell.fire_bolt'],['action.hide','action.move'],['condition.hidden']),
         'actors':hidden,'battlefield':'battlefield.open_floor_dark','seed':2,
         'steps':[{'do':'action.hide','by':'caster','target':'self'},
                  {'do':'action.move','by':'caster','target':[2,7]},
                  {'do':'end_turn','by':'caster'},
                  {'do':'spell.fire_bolt','by':'caster','target':'target'}],
         'required_behaviors':['action.hide','spell.fire_bolt'],'required_conditions':['condition.hidden'],
         'required_condition_ends':['condition.hidden']},
        {'id':'action.attack/death','title':'Attack: hit, damage, hurt and death','kind':'action',
         'subjects':subjects(actions=['action.attack']),'actors':combat,'seed':2,
         'steps':[{'do':'action.attack','by':'caster','target':'target'}],
         'required_behaviors':['action.attack'],'required_facts':['attack','damage','life']},
        {'id':'spell.shield/reaction','title':'Shield reaction: actual Magic Missile interruption','kind':'spell',
         'subjects':subjects(['spell.shield','spell.magic_missile'],conditions=['condition.spell.shield']),
         'actors':shield,'seed':2,
         'steps':[{'do':'spell.magic_missile','by':'target','target':'caster','recipients':['caster']*3}],
         'required_behaviors':['spell.magic_missile'],'required_conditions':['condition.spell.shield']},
        {'id':'interaction.door/entry','title':'Door: approach, open, cross into the room','kind':'interaction',
         'subjects':subjects(actions=['action.move','action.environment.directional_door.open']),
         'actors':doors,'battlefield':'battlefield.lantern_crypt','seed':2,
         'steps':[{'do':'action.move','by':'caster','target':[7,6]},
                  {'do':'action.environment.directional_door.open','by':'caster','target':{'object':'Crypt passage'}},
                  {'do':'action.move','by':'caster','target':[10,6]},
                  {'do':'end_turn','by':'caster'},
                  {'do':'action.move','by':'caster','target':[11,6]},
                  {'do':'action.environment.directional_door.open','by':'caster','target':{'object':'Burial hall'}},
                  {'do':'action.move','by':'caster','target':[13,6]}],
         'required_behaviors':['action.environment.directional_door.open'],'required_facts':['movement']}]
