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
        steps=None
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
            # One real missile brings the wounded fighter exactly to zero;
            # later missiles go to the healthy caster, not the dying patient.
            # Native eligibility requires get_normal_hp()==0, not merely DYING.
            roster=[{'role':'caster','side':'amber','creature':'creature.generic_caster','level':20,
                     'caster_level':20,'spells':[spell],'at':[3,6]},
                    {'role':'ally','side':'amber','premade':'fighter','at':[4,6],'damage':40},
                    {'role':'target','side':'blue','creature':'creature.generic_caster','level':20,
                     'caster_level':20,'spells':['spell.magic_missile'],'at':[9,6]}]
            steps=[{'do':'spell.magic_missile','by':'target','target':'ally','level':1,
                    'recipients':['ally','caster','caster']},
                   {'do':spell,'by':'caster','target':'ally'}]
            required=['spell.magic_missile',spell]
        elif spell in ('spell.branding_smite','spell.searing_smite','spell.ensnaring_strike'):
            roster[0]['items']=[{'id':'weapon.longsword','slot':'MELEE_MAIN'}]
            roster[2]={'role':'target','side':'blue','creature':'creature.knight','at':[4,7]}
            step['target']='target'
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
            # Its native creature owns a real learned-source innate reaction.
            # Frozen encounter behavior grants cannot install this reaction.
            roster[0]={'role':'caster','side':'amber','creature':'creature.spell.fire_myrmidon','at':[3,7]}
            roster[2]['spells']=['spell.dissonant_whispers']
            # The original single-recipient Psychic hit produces the real
            # reaction and positive Fire result. The older area/group trigger
            # consumes its resource without that result and remains a gap.
            step={'do':'spell.dissonant_whispers','by':'target','target':'caster','level':1}
            required=['spell.dissonant_whispers','reaction.spell.hellish_rebuke']
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
            'kind':'spell', 'subjects':subjects([spell]), 'actors':roster, 'steps':steps or [step], 'seed':2,
            'required_behaviors':required, 'purpose':'Current-engine baseline cast/reaction safety; visual/lifecycle qualification is separate.'}
        if spell=='spell.shield':scenario['required_conditions']=['condition.spell.shield']
        if spell=='spell.hellish_rebuke':scenario['required_applied_damage_types']=['Fire']
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
    recovering=actors();recovering[0]={'role':'caster','side':'amber','premade':'fighter','at':[3,7],'damage':20}
    recovering[2]['at']=[9,7];recovering[3]['at']=[9,8]
    return [
        {'id':'spell.flesh_to_stone/petrification_restoration',
         'title':'Petrification: ordinary movement, failed saves, stone and restoration', 'kind':'spell',
         'subjects':subjects(['spell.flesh_to_stone','spell.greater_restoration'], ['action.move'],
             ['condition.spell.flesh_to_stone.stages','condition.spell.flesh_to_stone.petrified']),
         'actors':[
             {'role':'caster','side':'amber','creature':'creature.generic_caster','level':20,
              'caster_level':20,'spells':['spell.flesh_to_stone'],'at':[3,7]},
             {'role':'target','side':'blue','creature':'creature.goblin','at':[4,7]},
             {'role':'restorer','side':'blue','creature':'creature.generic_caster','level':20,
              'caster_level':20,'spells':['spell.greater_restoration'],'at':[5,6]}],
         'seed':2,
         'steps':[{'do':'action.move','by':'target','target':[4,6]},
                  {'do':'spell.flesh_to_stone','by':'caster','target':'target'},
                  {'do':'wait_condition','target':'target','condition':'condition.spell.flesh_to_stone.petrified',
                   'while_condition':'condition.spell.flesh_to_stone.stages','max_turns':18},
                  {'do':'spell.greater_restoration','by':'restorer','target':'target'},
                  {'do':'action.move','by':'target','target':[4,7]}],
         'required_behaviors':['spell.flesh_to_stone','spell.greater_restoration'],
         'required_conditions':['condition.spell.flesh_to_stone.stages','condition.spell.flesh_to_stone.petrified'],
         'required_condition_ends':['condition.spell.flesh_to_stone.petrified']},
        {'id':'action.class.fighter.second_wind/healing','title':'Second Wind: wounded fighter and actual self-healing','kind':'action',
         'subjects':subjects(actions=['action.class.fighter.second_wind','action.move']),
         'actors':recovering,'seed':2,
         'steps':[{'do':'action.class.fighter.second_wind','by':'caster','target':'self'},
                  {'do':'action.move','by':'caster','target':[2,7]}],
         'required_behaviors':['action.class.fighter.second_wind'],'required_facts':['heal']},
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
         'required_behaviors':['action.environment.directional_door.open'],'required_facts':['movement']}, gallery_sorcerer(), equipped_weapon_study(), poison_weapon_contact_study()] + interaction_cohort() + traversal_and_utility_cohort() + survival_cohort() + perspective_and_reaction_cohort() + direct_character_cohort() + passive_handler_cohort() + [interaction_media_study(), vampiric_positive_study(), banishment_departure_study()] + native_persistent_studio_studies()


def equipped_weapon_study():
    """Real intrinsic item, movement/contact, unequip and plain-item replacement."""
    inventory = subjects(actions=['action.move', 'action.attack'])
    inventory['item'] = ['weapon.roster.ember_longsword', 'weapon.longsword']
    return {
        'id': 'weapon.roster.ember_longsword/equipped_use_retire_replace',
        'title': 'Ember Longsword: equipped movement, hit, removal and replacement',
        'kind': 'item', 'subjects': inventory, 'seed': 2,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [4, 6],
             'items': [{'id': 'weapon.roster.ember_longsword', 'slot': 'MELEE_MAIN'},
                       {'id': 'weapon.longsword', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre', 'at': [6, 6]}],
        'steps': [
            {'do': 'action.move', 'by': 'caster', 'target': [5, 6]},
            {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'equip', 'by': 'caster', 'item': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}],
        'required_behaviors': ['action.move', 'action.attack'],
        'required_facts': ['movement', 'attack', 'damage'],
        'purpose': 'Exact intrinsic Gear ownership and one finite accepted weapon contact. '
                   'The sustain stays visibly blocked until Factory regenerates receiver includes; '
                   'this original never asserts art approval or fabricates an effect membership.'}


def poison_weapon_contact_study():
    """One carried dose, exact held-weapon contacts and ordinary round expiry."""
    inventory = subjects(actions=['action.attack', 'action.item.weapon_coat.apply'],
                         conditions=['condition.consumable.weapon_coat.basic_poison'])
    inventory['item'] = ['weapon.longsword', 'consumable.weapon_coat.basic_poison']
    attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}
    return {
        'id': 'consumable.weapon_coat.basic_poison/equipped_hit_expiry_hit',
        'title': 'Basic Poison: coat held longsword, contact, expiry and later contact',
        'kind': 'item', 'subjects': inventory, 'seed': 2,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'premade': 'fighter', 'at': [5, 6],
             'items': [{'id': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
                       {'id': 'consumable.weapon_coat.basic_poison', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre', 'at': [6, 6]}],
        'steps': [dict(attack), {'do': 'end_turn', 'by': 'caster'},
                  {'do': 'action.item.weapon_coat.apply', 'by': 'caster',
                   'target': 'self', 'item': 'consumable.weapon_coat.basic_poison',
                   'name': 'Coat Main Hand', 'capture_choices': True},
                  {'do': 'end_turn', 'by': 'caster'}, dict(attack),
                  {'do': 'end_turn', 'by': 'caster'}, dict(attack)]
                 + [{'do': 'end_turn'} for _ in range(20)]
                 + [dict(attack), {'do': 'end_turn', 'by': 'caster'}, dict(attack),
                    {'do': 'end_turn', 'by': 'caster'}, dict(attack)],
        'required_behaviors': ['action.attack', 'action.item.weapon_coat.apply'],
        'required_facts': ['attack', 'damage'],
        'purpose': 'Actual AttackFact.item_effects on the same equipped longsword before, during and after '
                   'the authored ten-round item-coating lifetime. No Poisoned condition or successful '
                   'poison saving-throw outcome is required for the contact membership.'}


def gallery_sorcerer():
    """The real large-map expedition, spell contacts and Shield reaction.

    A fixed authored route makes this repeatable without changing server state.
    Both original seat journals are consumed by production Studio and tests.
    """
    actors=[{'role':'caster','side':'amber','premade':'sorcerer','at':[23,6],
             'behaviors':['reaction.spell.shield']},
            {'role':'arcanist','side':'blue','creature':'creature.generic_caster','level':20,
             'caster_level':20,'spells':['spell.magic_missile'],'at':[30,6]}]
    actors += [{'role':'sentry_'+str(i),'side':'blue','premade':'fighter','at':point}
               for i,point in enumerate([[34,6],[38,10],[42,10],[43,6]],1)]
    def cast(behavior,**values):return {'do':behavior,'by':'caster',**values}
    steps=[
        cast('action.environment.directional_door.open',target={'object':'Lantern gallery door'}),
        cast('action.move',target=[26,6]),
        {'do':'spell.magic_missile','by':'arcanist','target':'caster','recipients':['caster']*3},
        cast('spell.ray_of_frost',target='arcanist',capture_choices=True),
        cast('action.move',target=[30,5]),cast('end_turn'),
        cast('spell.scorching_ray',target='sentry_1',recipients=['sentry_1']*3),
        cast('action.move',target=[32,6]),cast('end_turn'),
        cast('spell.acid_splash',target='sentry_2'),
        cast('action.move',target=[36,7]),cast('end_turn'),
        cast('spell.fireball',target=[42,10]),
        cast('action.move',target=[41,6]),cast('end_turn'),
        cast('spell.magic_missile',target='sentry_4',recipients=['sentry_4']*3),cast('end_turn'),
        cast('spell.chill_touch',target='sentry_4'),
        cast('action.move',target=[46,6]),cast('end_turn'),
        cast('action.move',target=[46,12]),cast('action.dash'),
        cast('action.move',target=[46,18]),cast('end_turn')]
    spells=['spell.'+name for name in ['ray_of_frost','scorching_ray','acid_splash','fireball','magic_missile','chill_touch']]
    return {'id':'interaction.gallery/sorcerer','title':'Lantern Gallery: door, expedition, six spells and Shield',
        'kind':'interaction','subjects':subjects(spells,['action.move','action.dash','action.environment.directional_door.open'],['condition.spell.shield']),
        'battlefield':'battlefield.lantern_gallery','actors':actors,'seed':3,'steps':steps,
        'required_behaviors':spells,'required_conditions':['condition.spell.shield'],
        'required_condition_ends':['condition.spell.shield']}


def interaction_cohort():
    """Legal multi-phase studies beyond a cast-only spell baseline.

    Setup declares ordinary visible actors; application and removal below must
    be produced by SDK commands. Required outcomes are checked against original
    packets by worker.py, independently of renderer/art coverage.
    """
    def fighter(role, side, at, **extra):
        return {'role':role, 'side':side, 'premade':'fighter', 'at':at, **extra}
    def mage(role, side, at, spells=(), **extra):
        return {'role':role, 'side':side, 'creature':'creature.generic_caster',
                'level':20, 'caster_level':20, 'spells':list(spells), 'at':at, **extra}
    def command(behavior, by='caster', target=None, **extra):
        return {'do':behavior, 'by':by, **({'target':target} if target is not None else {}), **extra}
    def study(identity, title, roster, steps, *, spells=(), actions=(), conditions=(),
              facts=(), ends=(), seed=3, **extra):
        return {'id':identity, 'title':title, 'kind':'spell' if spells else 'action',
                'subjects':subjects(spells,actions,conditions), 'actors':roster, 'steps':steps,
                'seed':seed, 'required_behaviors':list(spells)+list(actions),
                'required_conditions':list(conditions), 'required_condition_ends':list(ends),
                'required_facts':list(facts), **extra}
    adjacent=[fighter('caster','amber',[4,6]),fighter('target','blue',[5,6])]
    distant=[fighter('caster','amber',[3,7]),fighter('target','blue',[14,7])]
    rows=[
        study('action.dash/budget_then_reset','Dash: ordinary spending, added allowance, departure and next-turn reset',
              distant,[command('action.move',target=[5,7]),command('action.dash',target='self'),
                       command('action.move',target=[10,7]),command('end_turn'),
                       command('action.move',target=[11,7])],
              actions=['action.move','action.dash'],conditions=['condition.dashing'],ends=['condition.dashing']),
        study('action.disengage/departure','Disengage: apply, leave real threat, expire and walk normally',
              adjacent,[command('action.disengage',target='self'),command('action.move',target=[3,6]),
                        command('end_turn'),command('action.move',target=[3,7])],
              actions=['action.disengage','action.move'],conditions=['condition.disengaging'],ends=['condition.disengaging']),
        study('action.dodge/attack_then_expire','Dodge: actual incoming attack, expiry and ordinary movement',
              adjacent,[command('action.dodge',target='self'),command('action.attack','target','caster',weapon_slot='MELEE_MAIN'),
                        command('end_turn','target'),command('action.move',target=[4,7])],
              actions=['action.dodge','action.attack','action.move'],conditions=['condition.dodging'],ends=['condition.dodging'],facts=['attack']),
        study('action.jump/land_and_walk','Jump: actual launch, landing and subsequent walking',
              distant,[command('action.jump',target=[5,7]),command('action.move',target=[6,7])],
              actions=['action.jump','action.move'],facts=['movement']),
        study('condition.prone/drop_stand_walk','Prone: voluntarily lie down, stand at real cost, resume walking',
              distant,[command('action.core.drop_prone',target='self'),command('action.core.stand_up',target='self'),
                       command('action.move',target=[4,7])],
              actions=['action.core.drop_prone','action.core.stand_up','action.move'],conditions=['condition.prone'],ends=['condition.prone']),
        study('action.shove/forced_departure','Shove: real contest, forced displacement and recipient movement',
              adjacent,[command('action.shove',target='target'),command('action.move','target',[6,7])],
              actions=['action.shove','action.move'],facts=['shove','forced_movement']),
        study('action.help_attack/consume_assistance','Help Attack: helper selects enemy and ally, actual assisted attack consumes owner',
              [fighter('caster','amber',[4,6]),fighter('ally','amber',[4,7]),fighter('target','blue',[5,6])],
              [command('action.help_attack',target='target',recipients=['target','ally']),
               command('action.attack','ally','target',weapon_slot='MELEE_MAIN')],
              actions=['action.help_attack','action.attack'],facts=['attack']),
        study('action.class.fighter.action_surge/extra_attacks','Action Surge: two attacks, extra action, two further attacks',
              [fighter('caster','amber',[4,6]),mage('target','blue',[5,6])],
              [command('action.attack',target='target',weapon_slot='MELEE_MAIN'),
               command('action.feature.extra_attack',target='target',weapon_slot='MELEE_MAIN'),
               command('action.class.fighter.action_surge',target='self'),
               command('action.attack',target='target',weapon_slot='MELEE_MAIN'),
               command('action.feature.extra_attack',target='target',weapon_slot='MELEE_MAIN')],
              actions=['action.attack','action.feature.extra_attack','action.class.fighter.action_surge'],facts=['attack','damage']),
        study('action.class.barbarian.reckless_attack/reciprocal','Reckless Attack: setup, own attack, enemy response and expiry',
              [{'role':'caster','side':'amber','premade':'barbarian','at':[4,6]},fighter('target','blue',[5,6])],
              [command('action.class.barbarian.reckless_attack',target='self'),
               command('action.attack',target='target',weapon_slot='MELEE_MAIN'),
               command('action.attack','target','caster',weapon_slot='MELEE_MAIN'),
               command('end_turn','target'),command('action.move',target=[3,6])],
              actions=['action.class.barbarian.reckless_attack','action.attack','action.move'],
              conditions=['class_feature.barbarian.reckless_attacking'],ends=['class_feature.barbarian.reckless_attacking']),
        study('action.class.paladin.lay_on_hands/heal_ally','Lay on Hands: actual wounded ally healing and movement',
              [{'role':'caster','side':'amber','premade':'paladin','at':[4,6]},
               fighter('ally','amber',[4,7],damage=20),fighter('target','blue',[12,6])],
              [command('action.class.paladin.lay_on_hands',target='ally'),command('action.move','ally',[5,7])],
              actions=['action.class.paladin.lay_on_hands','action.move'],facts=['heal']),
        study('action.class.paladin.sacred_weapon/expiry','Sacred Weapon: exact held item, attack and natural expiration',
              [{'role':'caster','side':'amber','premade':'paladin','at':[4,6]},mage('target','blue',[5,6])],
              [command('action.class.paladin.sacred_weapon',target='self',track=True,track_condition='condition.class.paladin.sacred_weapon'),
               command('end_turn'),command('action.attack',target='target',weapon_slot='MELEE_MAIN'),
               {'do':'end_tracked','prefer_turns':True,'max_turns':30}],
              actions=['action.class.paladin.sacred_weapon','action.attack'],conditions=['condition.class.paladin.sacred_weapon'],
              ends=['condition.class.paladin.sacred_weapon'],facts=['attack']),
        study('spell.invisibility/attack_breaks','Invisibility: visible idle, vanish, move, attack and genuine reveal',
              [mage('caster','amber',[3,7],['spell.invisibility','spell.fire_bolt']),fighter('target','blue',[9,7])],
              [command('spell.invisibility',target='self'),command('action.move',target=[4,7]),
               command('end_turn'),command('spell.fire_bolt',target='target')],
              spells=['spell.invisibility','spell.fire_bolt'],actions=['action.move'],
              conditions=['condition.spell.invisibility'],ends=['condition.spell.invisibility']),
        study('spell.greater_invisibility/failed_stealth_reveals','Greater Invisibility: movement, attack, actual failed Stealth reveal',
              [mage('caster','amber',[3,7],['spell.greater_invisibility','spell.fire_bolt']),fighter('target','blue',[9,7])],
              [command('spell.greater_invisibility',target='self'),command('action.move',target=[4,7]),
               command('end_turn'),command('spell.fire_bolt',target='target'),command('action.move',target=[4,8])],
              spells=['spell.greater_invisibility','spell.fire_bolt'],actions=['action.move'],
              conditions=['condition.spell.greater_invisibility'],ends=['condition.spell.greater_invisibility']),
        study('spell.shield_of_faith/defend_then_remove','Shield of Faith: recipient application, real attack, concentration removal',
              [mage('caster','amber',[3,6],['spell.shield_of_faith']),fighter('ally','amber',[4,6]),fighter('target','blue',[5,6])],
              [command('spell.shield_of_faith',target='ally'),command('action.attack','target','ally',weapon_slot='MELEE_MAIN'),
               command('action.drop_concentration',target='self'),command('action.move','ally',[4,7])],
              spells=['spell.shield_of_faith'],actions=['action.attack','action.drop_concentration','action.move'],
              conditions=['condition.spell.shield_of_faith'],ends=['condition.spell.shield_of_faith'],facts=['attack']),
        study('spell.blur/defend_then_remove','Blur: actual incoming attack, held movement and restored body',
              [mage('caster','amber',[4,6],['spell.blur']),fighter('target','blue',[5,6])],
              [command('spell.blur',target='self'),command('action.attack','target','caster',weapon_slot='MELEE_MAIN'),
               command('action.move',target=[3,6]),command('action.drop_concentration',target='self')],
              spells=['spell.blur'],actions=['action.attack','action.move','action.drop_concentration'],
              conditions=['condition.spell.blur'],ends=['condition.spell.blur'],facts=['attack']),
        study('spell.slow/movement_and_restore','Slow: actual application, reduced movement, concentration end and restored movement',
              [mage('caster','amber',[3,7],['spell.slow']),mage('target','blue',[9,7],level=1)],
              [command('spell.slow',target=[9,7],affect='target'),command('action.move','target',[10,7]),
               command('action.drop_concentration',target='self'),command('action.move','target',[10,8])],
              spells=['spell.slow'],actions=['action.move','action.drop_concentration'],conditions=['condition.spell.slow'],ends=['condition.spell.slow'],seed=2),
        study('spell.hold_person/agency_restoration','Hold Person: actual paralysis, skipped recipient turn, concentration end, movement restored',
              [mage('caster','amber',[3,7],['spell.hold_person']),mage('target','blue',[9,7],level=1)],
              [command('spell.hold_person',target='target'),command('end_turn'),
               command('action.drop_concentration',target='self'),command('action.move','target',[10,7])],
              spells=['spell.hold_person'],actions=['action.drop_concentration','action.move'],
              conditions=['condition.spell.hold_person'],ends=['condition.spell.hold_person'],seed=4),
        study('spell.magic_weapon/wield_attack_remove','Magic Weapon: actual held weapon, recipient attack, removal and normal attack',
              [mage('caster','amber',[3,6],['spell.magic_weapon']),fighter('ally','amber',[4,6]),mage('target','blue',[5,6])],
              [command('spell.magic_weapon',target='ally'),command('action.attack','ally','target',weapon_slot='MELEE_MAIN'),
               command('action.drop_concentration',target='self'),command('action.attack','ally','target',weapon_slot='MELEE_MAIN')],
              spells=['spell.magic_weapon'],actions=['action.attack','action.drop_concentration'],
              conditions=['condition.spell.magic_weapon'],ends=['condition.spell.magic_weapon'],facts=['attack']),
        study('spell.sleep/shake_awake','Sleep: ordinary actor, real spell sleep, adjacent ally wakes and moves',
              [mage('caster','amber',[3,7],['spell.sleep']),{'role':'target','side':'blue','creature':'creature.goblin','at':[8,7]},
               fighter('helper','blue',[9,7])],
              [command('spell.sleep',target=[8,7],affect='target'),command('action.shake_awake','helper','target'),
               command('action.move','target',[8,8])],
              spells=['spell.sleep'],actions=['action.shake_awake','action.move'],conditions=['condition.spell.sleep'],ends=['condition.spell.sleep']),
    ]
    for spell in ('spell.magic_missile','spell.scorching_ray'):
        rows.append(study(spell+'/split_recipients',spell.removeprefix('spell.').replace('_',' ').title()+': three actual deliveries across two recipients',
                    [mage('caster','amber',[3,7],[spell]),fighter('target','blue',[9,7]),fighter('second_target','blue',[9,8])],
                    [command(spell,target='target',recipients=['target','second_target','target'])],spells=[spell],facts=['damage']))
    rows.append(study('spell.chain_lightning/three_recipients',
                'Chain Lightning: primary contact and two independently selected branches',
                [mage('caster','amber',[3,7],['spell.chain_lightning']),
                 mage('target','blue',[8,7]),mage('second_target','blue',[9,9]),mage('third_target','blue',[11,6])],
                [command('spell.chain_lightning',target='target',
                         recipients=['target','second_target','third_target'],level=6,capture_choices=True)],
                spells=['spell.chain_lightning'],facts=['saving_throw','damage'],seed=3,
                purpose='One legal level6 cast from ordinary visible actors. Select the primary and two distinct nearby secondaries through Preview; inspect native application propagation rather than infer sequential hops from recipient order.'))
    for change in ('enlarge','reduce'):
        rows.append(study('spell.enlarge_reduce/'+change+'_lifecycle',change.title()+': actual size owner, movement, attack and restoration',
                    [mage('caster','amber',[3,6],['spell.enlarge_reduce']),fighter('ally','amber',[4,6]),mage('target','blue',[5,6])],
                    [command('spell.enlarge_reduce',target='ally',variant={'form':change}),command('action.move','ally',[4,7]),
                     command('action.attack','ally','target',weapon_slot='MELEE_MAIN'),
                     command('action.drop_concentration',target='self'),command('action.move','ally',[4,8])],
                    spells=['spell.enlarge_reduce'],actions=['action.move','action.attack','action.drop_concentration'],
                    conditions=['condition.spell.enlarge_reduce'],ends=['condition.spell.enlarge_reduce']))
    for affinity in ('resistance','immunity','vulnerability'):
        rows.append(study('combat.fire/'+affinity,'Fire damage: actual '+affinity+' outcome and recipient response',
                    [mage('caster','amber',[3,7],['spell.fireball']),fighter('target','blue',[9,7],affinities=[(affinity,'fire')])],
                    [command('spell.fireball',target=[9,7])],spells=['spell.fireball'],facts=['damage']))
    return rows


def traversal_and_utility_cohort():
    """Ordinary authored maps and public traversal/item commands, no map edits."""
    def fighter(at, **extra):return {'role':'caster','side':'amber','premade':'fighter','at':at,**extra}
    enemy={'role':'target','side':'blue','premade':'fighter','at':[14,7]}
    def command(behavior,target=None,**extra):return {'do':behavior,'by':'caster',**({'target':target} if target is not None else {}),**extra}
    def study(identity,title,at,steps,actions,*,battlefield='battlefield.open_floor_bright',facts=(),actor=None,spells=()):
        return {'id':identity,'title':title,'kind':'interaction','seed':3,'battlefield':battlefield,
                'subjects':subjects(spells,actions),'actors':[actor or fighter(at),dict(enemy)],'steps':steps,
                'required_behaviors':list(spells)+list(actions),'required_facts':list(facts)}
    return [
        study('movement.stairs/ascent_descent','Stairs: real progressive supports, ascent and descent',[5,4],
              [command('action.move',[8,4]),command('end_turn'),command('action.move',[5,4])],
              ['action.move'],battlefield='battlefield.elevation_proving_ground',facts=['movement']),
        study('movement.ramp/descent_ascent','Ramp: real height transition in both directions',[5,10],
              [command('action.move',[8,10]),command('end_turn'),command('action.move',[5,10])],
              ['action.move'],battlefield='battlefield.elevation_proving_ground',facts=['movement']),
        study('movement.connector/ladder_return','Ladder: actual connector, elevated endpoint and return',[1,12],
              [command('action.traverse_connector',[2,12]),command('end_turn'),command('action.traverse_connector',[1,12])],
              ['action.traverse_connector'],battlefield='battlefield.elevation_proving_ground'),
        study('movement.connector/rope_return','Rope: actual action cost, elevated endpoint and later return',[3,12],
              [command('action.traverse_connector',[4,12]),command('end_turn'),command('action.traverse_connector',[3,12])],
              ['action.traverse_connector'],battlefield='battlefield.elevation_proving_ground'),
        study('movement.window/cleared_both_directions','Window: enter actual empty aperture, cross and return',[4,6],
              [command('action.traverse_connector',[5,6]),command('end_turn'),command('action.traverse_connector',[4,6])],
              ['action.traverse_connector'],battlefield='battlefield.window_proving_ground'),
        study('movement.window/destroy_insert_cross','Window: actual grille destruction, retained frame and traversal',[4,8],
              [command('spell.fire_bolt',{'object':'Window grille G8'}),command('action.traverse_connector',[5,8])],
              ['action.traverse_connector'],battlefield='battlefield.window_proving_ground',facts=['object_destroyed'],
              actor={'role':'caster','side':'amber','creature':'creature.generic_caster','level':20,'caster_level':20,
                     'spells':['spell.fire_bolt'],'at':[4,8]},spells=['spell.fire_bolt']),
        study('interaction.storage/open_loot_close','Storage: actual chest opening, loot transfer and closing',[4,7],
              [command('action.environment.storage_chest.open',{'object':'Validation Field Cache'}),
               command('action.environment.storage_chest.loot_all',{'object':'Validation Field Cache'}),
               command('action.environment.storage_chest.close',{'object':'Validation Field Cache'})],
              ['action.environment.storage_chest.open','action.environment.storage_chest.loot_all','action.environment.storage_chest.close'],
              battlefield='battlefield.field_cache_bright'),
        study('interaction.torch/carried_lifecycle','Carried torch: extinguish, move, ignite and extinguish',[3,7],
              [command('action.item.torch.extinguish'),command('action.move',[4,7]),command('action.item.torch.ignite'),
               command('action.item.torch.extinguish')],
              ['action.item.torch.extinguish','action.item.torch.ignite','action.move'],battlefield='battlefield.open_floor_dark'),
    ]


def survival_cohort():
    """Living wounded actors receive actual in-record damage before treatment."""
    def mage(role,side,at,spells):
        return {'role':role,'side':side,'creature':'creature.generic_caster','level':20,
                'caster_level':20,'spells':spells,'at':at}
    def command(behavior,by,target=None,**extra):
        return {'do':behavior,'by':by,**({'target':target} if target is not None else {}),**extra}
    def study(identity,title,spells,steps,level):
        return {'id':identity,'title':title,'kind':'interaction','seed':2,
                'subjects':subjects(spells,['action.move']),
                'actors':[mage('caster','amber',[3,6],spells[:-1]),
                          {'role':'patient','side':'amber','premade':'fighter','at':[4,6],'damage':40 if level==1 else 43},
                          mage('target','blue',[9,6],['spell.magic_missile'])],
                'steps':[command('spell.magic_missile','target','patient',level=level,recipients=['patient']*(level+2))]+steps,
                'required_behaviors':spells+['action.move'],'required_facts':['damage','life','heal']}
    return [
        study('survival.stabilize/heal_and_walk','Living fighter: real damage, dying, Spare the Dying, healing and walking',
              ['spell.spare_the_dying','spell.cure_wounds','spell.magic_missile'],
              [command('spell.spare_the_dying','caster','patient'),command('end_turn','caster'),
               command('spell.cure_wounds','caster','patient'),command('action.move','patient',[4,7])],1),
        study('survival.revive/death_revivify_walk','Living fighter: real lethal damage, Revivify and restored movement',
              ['spell.revivify','spell.cure_wounds','spell.magic_missile'],
              [command('spell.revivify','caster','patient'),command('end_turn','caster'),
               command('spell.cure_wounds','caster','patient'),command('action.move','patient',[4,7])],3),
    ]


def perspective_and_reaction_cohort():
    """Matched real threat departures and two independently recorded observers."""
    def fighter(role,side,at):return {'role':role,'side':side,'premade':'fighter','at':at}
    def mage(role,side,at,spells,level=20):
        return {'role':role,'side':side,'creature':'creature.generic_caster','level':level,
                'caster_level':20,'spells':spells,'at':at}
    def command(behavior,by='caster',target=None,**extra):
        return {'do':behavior,'by':by,**({'target':target} if target is not None else {}),**extra}
    def study(identity,title,roster,steps,*,spells=(),actions=(),conditions=(),ends=(),facts=(),seed=3,**extra):
        return {'id':identity,'title':title,'kind':'interaction','seed':seed,'actors':roster,'steps':steps,
                'subjects':subjects(spells,actions,conditions),'required_behaviors':list(spells)+list(actions),
                'required_conditions':list(conditions),'required_condition_ends':list(ends),'required_facts':list(facts),**extra}
    adjacent=[fighter('caster','amber',[4,6]),fighter('target','blue',[5,6])]
    return [
        study('reaction.opportunity_attack/walk_resume','Opportunity attack: real walking departure, reaction, damage and surviving route',
              adjacent,[command('action.move',target=[3,6])],actions=['action.move'],facts=['attack','damage','movement']),
        study('reaction.opportunity_attack/jump_resume','Opportunity attack: real jump interrupted by nonlethal hit and resumed landing',
              adjacent,[command('action.jump',target=[2,6])],actions=['action.jump'],facts=['attack','damage','movement']),
        study('reaction.opportunity_attack/airborne_lethal','Opportunity attack: real later airborne death stops uncommitted jump',
              [mage('caster','amber',[4,6],[],level=1),{'role':'target','side':'blue','premade':'barbarian','at':[5,7]}],
              [command('action.jump',target=[7,6])],actions=['action.jump'],facts=['attack','damage','life'],seed=5),
        study('spell.invisibility/observer_counter','Invisibility: vanish, unseen movement, actual See Invisibility, observed movement, restoration',
              [mage('caster','amber',[3,7],['spell.invisibility']),mage('target','blue',[9,7],['spell.see_invisibility'])],
              [command('spell.invisibility',target='self'),command('action.move',target=[4,7]),
               command('spell.see_invisibility','target','self'),command('action.move',target=[5,7]),
               command('action.drop_concentration',target='self')],
              spells=['spell.invisibility','spell.see_invisibility'],actions=['action.move','action.drop_concentration'],
              conditions=['condition.spell.invisibility','condition.spell.see_invisibility'],ends=['condition.spell.invisibility']),
        study('spell.greater_invisibility/concentration_removal','Greater Invisibility: ordinary movement, held owner and actual concentration removal',
              [mage('caster','amber',[3,7],['spell.greater_invisibility']),fighter('target','blue',[9,7])],
              [command('spell.greater_invisibility',target='self'),command('action.move',target=[4,7]),
               command('action.drop_concentration',target='self'),command('action.move',target=[4,8])],
              spells=['spell.greater_invisibility'],actions=['action.move','action.drop_concentration'],
              conditions=['condition.spell.greater_invisibility'],ends=['condition.spell.greater_invisibility']),
        study('condition.prone/grease_auto_stand','Grease: actual failed save, prone owner, turn-start standing and movement',
              [mage('caster','amber',[3,7],['spell.grease']),mage('target','blue',[9,7],[],level=1)],
              [command('spell.grease',target=[9,7]),command('action.move','target',[11,7])],
              spells=['spell.grease'],actions=['action.move'],conditions=['condition.prone'],ends=['condition.prone'],seed=2),
        study('conditions.hold/independent_owners','Paralysis: two actual spell owners, first removal retains second, final restoration',
              [mage('caster','amber',[3,7],['spell.hold_person']),mage('ally','amber',[3,8],['spell.hold_monster']),
               mage('target','blue',[9,7],[],level=1)],
              [command('spell.hold_person',target='target'),command('spell.hold_monster','ally','target'),
               command('action.drop_concentration',target='self'),command('action.drop_concentration','ally','self')],
              spells=['spell.hold_person','spell.hold_monster'],actions=['action.drop_concentration'],
              conditions=['condition.spell.hold_person','condition.spell.hold_monster'],
              ends=['condition.spell.hold_person','condition.spell.hold_monster'],seed=4),
    ]


def direct_character_cohort():
    """Existing lawful native character builds in the ordinary AI skirmish.

    This engine entry point exposes only the actual `party` seat. These cases
    provide class-action evidence, never independent two-faction qualification.
    """
    prefix='action.class.cleric.divine_intervention.'
    def command(behavior,target='self',**extra):return {'do':behavior,'by':'caster','target':target,**extra}
    def study(key,title,steps,actions,facts=()):
        return {'id':prefix+key+'/direct_character','title':title,'kind':'action','seed':2,
                **({'required_applied_damage_types':['Radiant']} if key=='sunder_heretical' else {}),
                'subjects':subjects(actions=[prefix+key]+actions),
                'actors':[{'role':'caster','side':'party'}],
                'player_builds_source':'tools/studio_cases/scenarios/cleric_level10_builds.json',
                'purpose':'Real level10 class grant and native AI skirmish; one actual party perspective only.',
                'steps':steps,'required_behaviors':[prefix+key]+actions,'required_facts':list(facts)}
    arm=study('arm_thy_servant','Divine Intervention: actual permanent mace, unequip, equip and Healing Incense',
        [command(prefix+'arm_thy_servant'),command('unequip',slot='MELEE_MAIN'),
         command('equip',slot='MELEE_MAIN',item='weapon.devotees_mace'),
         command('action.item.devotees_mace.healing_incense')],['action.item.devotees_mace.healing_incense'])
    arm['subjects']['item']=['weapon.devotees_mace']
    return [
        study('sunder_heretical','Divine Intervention: actual level10 Sunder, radiant recipient damage and death',
              [command(prefix+'sunder_heretical')],[],['damage','life']),
        arm,
        study('golden_generosity','Divine Intervention: actual reward chest, loot transfer and close',
              [command(prefix+'golden_generosity'),
               command('action.environment.storage_chest.loot_all',{'object':'Golden Generosity'}),
               command('action.environment.storage_chest.close',{'object':'Golden Generosity'})],
              ['action.environment.storage_chest.loot_all','action.environment.storage_chest.close']),
        study('opulent_revival','Divine Intervention: approach actual enemies, incoming damage and Opulent Revival healing',
              [command('action.move',[13,10]),command('end_turn'),command(prefix+'opulent_revival')],
              ['action.move'],['damage','heal']),
    ]


def passive_handler_cohort():
    """Real class-owned handlers emit their own native child result lineages."""
    blessed=subjects(['spell.fireball','spell.healing_word'])
    blessed['class_feature']=['class_feature.cleric.blessed_healer']
    destroyed=subjects(actions=['action.class.cleric.turn_undead'])
    destroyed['class_feature']=['class_feature.cleric.destroy_undead']
    destroyed['creature']=['creature.zombie']
    return [
        {'id':'class_feature.cleric.blessed_healer/actual_self_heal',
         'title':'Blessed Healer: actual source and ally wounds, allied spell heal and emitted self-heal',
         'kind':'interaction','seed':2,'subjects':blessed,
         'actors':[{'role':'caster','side':'party'},{'role':'ally','side':'party'}],
         'player_builds_source':'tools/studio_cases/scenarios/blessed_healer_party_builds.json',
         'steps':[{'do':'spell.fireball','by':'caster','target':[9,11],'item':'spell_item.scroll_fireball'},
                  {'do':'spell.healing_word','by':'caster','target':'ally'}],
         'required_behaviors':['spell.fireball','spell.healing_word','class_feature.cleric.blessed_healer'],
         'required_facts':['damage','heal']},
        {'id':'class_feature.cleric.destroy_undead/committed_turning_result',
         'title':'Destroy Undead: actual Turn Undead application and emitted radiant damage',
         'kind':'interaction','seed':2,'subjects':destroyed,
         'actors':[{'role':'caster','side':'amber','premade':'cleric','at':[3,7]},
                   {'role':'target','side':'blue','creature':'creature.zombie','at':[7,7]}],
         'steps':[{'do':'action.class.cleric.turn_undead','by':'caster','target':'self'}],
         'required_behaviors':['action.class.cleric.turn_undead','class_feature.cleric.destroy_undead'],
         'required_applied_damage_types':['Radiant'],'required_facts':['saving_throw','damage']},
    ]



def interaction_media_study():
    """Legal native input controls; initial Poisoned is not an application claim."""
    return {'id': 'interaction.media_inputs/stride_unarmed_potion_ranged',
     'title': 'Actual stride contacts, unarmed strike, potion and ranged weapon',
     'kind': 'interaction',
     'seed': 2,
     'subjects': {'spell': ['spell.protection_from_poison'],
                  'action': ['action.move', 'action.attack', 'action.item.potion_healing.drink'],
                  'condition': ['condition.poisoned', 'condition.spell.protection_from_poison'],
                  'creature': ['creature.knight'],
                  'environment_object': [],
                  'spatial_effect': [],
                  'residue': [],
                  'item': ['weapon.shortbow', 'consumable.healing_potion']},
     'actors': [{'role': 'caster',
                 'side': 'amber',
                 'premade': 'fighter',
                 'damage': 8,
                 'at': [2, 4],
                 'items': [{'id': 'weapon.shortbow', 'slot': 'RANGED_MAIN'},
                           {'id': 'consumable.healing_potion', 'heal_amount': 7}],
                 'conditions': ['condition.poisoned']},
                {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [7, 5]},
                {'role': 'restorer',
                 'side': 'amber',
                 'creature': 'creature.generic_caster',
                 'level': 20,
                 'caster_level': 20,
                 'spells': ['spell.protection_from_poison'],
                 'at': [5, 5]}],
     'steps': [{'do': 'action.move', 'by': 'caster', 'target': [6, 5]},
               {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
               {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'name': 'Unarmed', 'capture_choices': True},
               {'do': 'end_turn', 'by': 'caster'},
               {'do': 'action.item.potion_healing.drink', 'by': 'caster', 'target': 'self'},
               {'do': 'end_turn', 'by': 'caster'},
               {'do': 'action.attack',
                'by': 'caster',
                'target': 'target',
                'weapon_slot': 'RANGED_MAIN',
                'capture_choices': True},
               {'do': 'spell.protection_from_poison', 'by': 'restorer', 'target': 'caster'}],
     'required_behaviors': ['action.move',
                            'action.attack',
                            'action.item.potion_healing.drink',
                            'spell.protection_from_poison'],
     'required_condition_ends': ['condition.poisoned']}


def vampiric_positive_study():
    """Lawful initial wounds; native first/repeat healing and concentration end."""
    roster=actors(['spell.vampiric_touch'])
    roster[0]['damage']=40
    return {'id':'spell.vampiric_touch/positive_healing_lifecycle',
        'title':'Vampiric Touch: wounded caster, initial/repeat strike healing and restoration',
        'kind':'spell','seed':2,'actors':roster,
        'subjects':subjects(['spell.vampiric_touch'],
            ['action.move','action.spell.vampiric_touch.strike','action.drop_concentration'],
            ['condition.spell.vampiric_touch']),
        'steps':[{'do':'action.move','by':'caster','target':[3,6]},
                 {'do':'spell.vampiric_touch','by':'caster','target':'target','level':3},
                 {'do':'action.move','by':'caster','target':[3,7]},
                 {'do':'end_turn','by':'caster'},
                 {'do':'action.spell.vampiric_touch.strike','by':'caster','target':'target','capture_choices':True},
                 {'do':'action.drop_concentration','by':'caster','target':'self'},
                 {'do':'action.move','by':'caster','target':[2,7]}],
        'required_behaviors':['spell.vampiric_touch','action.spell.vampiric_touch.strike','action.move','action.drop_concentration'],
        'required_conditions':['condition.spell.vampiric_touch'],
        'required_condition_ends':['condition.spell.vampiric_touch'],
        'required_facts':['spell','damage','heal','movement'],
        'purpose':'Original two-seat facts qualify actual positive self-healing separately from zero-heal baseline. No damage-to-healing arithmetic or fabricated result; starting wounds are setup, not an in-record damage claim.'}


def native_persistent_studio_studies():
    """Real UUID application/authoritative end for the native Studio families.

    These are legal player commands, not lifetime overrides. Shield of Faith's
    existing defend_then_remove study already supplies its full lifecycle.
    """
    result=[]
    for name in ('bane','guidance','light','resistance','mage_armor','sanctuary','command'):
        spell='spell.'+name
        roster=actors([spell])
        roster[1]['at']=[4,7]
        roster[2]['at']=[9,7]
        roster[3]['at']=[9,8]
        condition='condition.spell.'+name+('.grovel' if name=='command' else '')
        recipient='target' if name in ('bane','command') else 'self' if name=='mage_armor' else 'ally'
        steps=[{'do':spell,'by':'caster','target':recipient,'track':True,'track_condition':condition}]
        required=[spell,'action.move']
        if name=='command':
            steps += [{'do':'action.move','by':'caster','target':[3,8]},
                      {'do':'end_tracked','prefer_turns':True,'max_turns':16},
                      {'do':'tail_walk','by':'target','offset':[-1,0]}]
        else:
            steps.append({'do':'hold_walk','offset':[0,2]})
            if name=='mage_armor':
                roster[0]['items']=[{'id':'armor.chain_mail','placement':'inventory'}]
                steps.append({'do':'equip','by':'caster','slot':'Body','item':'armor.chain_mail'})
            elif name=='sanctuary':
                roster[1]['caster_level']=20
                roster[1]['spells']=['spell.fire_bolt']
                steps.append({'do':'spell.fire_bolt','by':'ally','target':'target'})
                required.append('spell.fire_bolt')
            else:
                steps.append({'do':'end_tracked','strategy':'concentration'})
                required.append('action.drop_concentration')
            steps.append({'do':'tail_walk','by':'caster' if recipient=='self' else recipient,'offset':[1,0]})
        result.append({'id':spell+'/studio_uuid_lifecycle',
            'title':name.replace('_',' ').title()+': actual owner application, held action and authoritative end',
            'kind':'spell','seed':2,'actors':roster,'steps':steps,
            'subjects':subjects([spell],['action.move'],[condition]),
            'required_behaviors':required,'required_conditions':[condition],
            'required_condition_ends':[condition],
            'purpose':'Current native Studio lifecycle input: retain original faction streams and exact UUID removal; no synthetic expiration or cast-only substitute.'})
    roster=actors()
    roster[2]['at']=[9,7];roster[3]['at']=[9,8]
    roster[0]['behaviors']=['reaction.spell.shield']
    roster[2]['caster_level']=20;roster[2]['spells']=['spell.magic_missile']
    result.append({'id':'spell.shield/studio_uuid_lifecycle',
        'title':'Shield: actual missile interception, next-turn expiration and restored movement',
        'kind':'spell','seed':2,'actors':roster,
        'subjects':subjects(['spell.shield','spell.magic_missile'],['action.move'],['condition.spell.shield']),
        'steps':[{'do':'spell.magic_missile','by':'target','target':'caster','recipients':['caster']*3,
                  'track':True,'track_condition':'condition.spell.shield'},
                 {'do':'end_tracked','prefer_turns':True,'max_turns':12},
                 {'do':'tail_walk','by':'caster','offset':[-1,0]}],
        'required_behaviors':['action.move'],'required_conditions':['condition.spell.shield'],
        'required_condition_ends':['condition.spell.shield']})
    roster=actors(['spell.web'])
    roster[2]['at']=[9,7];roster[3]['at']=[9,8]
    result.append({'id':'spell.web/studio_uuid_lifecycle',
        'title':'Web: actual area and restrained owners, turn exposure and concentration end',
        'kind':'spell','seed':2,'actors':roster,
        'subjects':subjects(['spell.web'],['action.move','action.drop_concentration'],['condition.spell.web.restrained']),
        'steps':[{'do':'spell.web','by':'caster','target':[9,7]},
                 {'do':'action.move','by':'caster','target':[3,6]},
                 {'do':'end_turn','by':'caster'},
                 {'do':'action.drop_concentration','by':'caster','target':'self'},
                 {'do':'action.move','by':'target','target':[8,7]}],
        'required_behaviors':['spell.web','action.move','action.drop_concentration'],
        'required_conditions':['condition.spell.web.restrained'],
        'required_condition_ends':['condition.spell.web.restrained']})
    return result


def banishment_departure_study():
    """Actual departure, live held owner and authoritative concentration return."""
    roster=actors(['spell.banishment'])
    return {'id':'spell.banishment/departure_and_return',
        'title':'Banishment: original idle departure, held caster movement, return and restored target movement',
        'kind':'spell','seed':2,'actors':roster,
        'subjects':subjects(['spell.banishment'],['action.move','action.drop_concentration'],['condition.spell.banishment']),
        'steps':[{'do':'spell.banishment','by':'caster','target':'target','level':4,
                  'track':True,'track_condition':'condition.spell.banishment'},
                 {'do':'action.move','by':'caster','target':[3,6]},
                 {'do':'end_tracked','strategy':'concentration'},
                 {'do':'tail_walk','by':'target','offset':[1,0]}],
        'required_behaviors':['spell.banishment','action.move','action.drop_concentration'],
        'required_conditions':['condition.spell.banishment'],
        'required_condition_ends':['condition.spell.banishment'],
        'required_facts':['spell','movement'],
        'purpose':'Actual two-seat departure/return input for immutable pre-admission pose/outfit capture. The absent actor is never moved or made visible by the recorder; concentration ends through an offered action, then the returned target moves legally. No departure shader/rendering qualification is claimed.'}
