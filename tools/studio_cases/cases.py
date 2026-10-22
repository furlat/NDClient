"""Studio scenarios are roles, legal setup and ordered player commands.

Baseline casts exercise safety only. They do not claim the richer lifecycle,
outcome or visual coverage described by an explicitly choreographed study.
"""
from event_family_cases import event_family_studies
from projectile_variant_cases import projectile_variant_studies
from flame_blade_case import flame_blade_weapon_study
from production_review_cases import production_review_studies, repair_item_owner_requirements
from trap_cases import hardware_studies
from legacy_six_cases import legacy_six_studies


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


def spell_baseline_exclusions(inventory):
    """Native nonproduction definitions stay cataloged and explicitly named."""
    return [{'id': spell, 'visibility': row['visibility'], 'disposition': 'nonproduction_definition',
             'reason': 'Native descriptor visibility='+row['visibility']+'; outside production spell baselines. '
                       'Existing original captures remain unchanged and inspectable.'}
            for spell, row in sorted(inventory['ids']['spell'].items())
            if row.get('visibility') in ('developer', 'internal')]


def spell_baselines(inventory):
    result=[]
    for spell in sorted(inventory['ids']['spell']):
        if inventory['ids']['spell'][spell].get('visibility') in ('developer', 'internal'):
            continue
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
    cohort = [
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
         'required_behaviors':['action.environment.directional_door.open'],'required_facts':['movement']}, gallery_sorcerer(), equipped_weapon_study(), poison_weapon_contact_study(), poison_weapon_runtime_study(), water_create_dry_study(), *glyph_warding_trigger_studies(), power_word_heal_poison_study(), goodberry_consumption_study(), shillelagh_equipped_move_study(), flaming_sphere_lifecycle_study()] + interaction_cohort() + traversal_and_utility_cohort() + survival_cohort() + perspective_and_reaction_cohort() + direct_character_cohort() + passive_handler_cohort() + [interaction_media_study(), vampiric_positive_study(), banishment_departure_study()] + native_persistent_studio_studies() + option_identity_studies() + intrinsic_weapon_studies() + [flame_blade_weapon_study(subjects)] + coating_weapon_studies() + event_family_studies(actors, subjects) + projectile_variant_studies(actors, subjects) + production_review_studies(actors, subjects) + legacy_six_studies(subjects) + [skeleton_mark_lifecycle_study()] + coating_slot_lifecycle_studies() + class_held_lifecycle_studies() + elemental_body_lifecycle_studies() + [false_life_grant_study()] + [shield_ranged_lifecycle_study()] + action_dispatch_owner_studies() + myrmidon_body_lifecycle_studies() + [arcane_sword_granted_lifecycle_study()] + provisional_creature_body_studies()
    cohort += hardware_studies(subjects)
    return [repair_item_owner_requirements(case) for case in cohort]


def equipped_weapon_study(item_id='weapon.roster.ember_longsword', title='Ember Longsword',
                          target_creature='creature.ogre'):
    """Real intrinsic item, movement/contact, unequip and plain-item replacement."""
    inventory = subjects(actions=['action.move', 'action.attack'])
    inventory['item'] = [item_id, 'weapon.longsword']
    return {
        'id': item_id + '/equipped_use_retire_replace',
        'title': title + ': equipped movement, hit, removal and replacement',
        'kind': 'item', 'subjects': inventory, 'seed': 2,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [4, 6],
             'items': [{'id': item_id, 'slot': 'MELEE_MAIN'},
                       {'id': 'weapon.longsword', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': target_creature, 'at': [6, 6]}],
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
                   'The original item appearance, UUID and legal equipment transition remain authoritative; '
                   'this recording does not qualify native source poses or artistic acceptance.'}


def intrinsic_weapon_studies():
    """One ordinary legal lifecycle for each selected exact intrinsic item."""
    return [equipped_weapon_study(identity, title, 'creature.ogre_zombie') for identity, title in (
        ('weapon.roster.ember_greatsword', 'Ember Greatsword'),
        ('weapon.circus.flaming_scimitar', 'Flaming Scimitar'),
        ('weapon.roster.psychic_scimitar', 'Mindreaver Scimitar'),
        ('weapon.roster.psychic_greataxe', 'Mindcleaver Greataxe'),
        ('weapon.roster.psychic_trident', 'Thoughtpiercer Trident'),
        ('weapon.roster.psychic_longsword', 'Mindreaver Longsword'),
        ('weapon.roster.psychic_longsword_greater', 'Soulbreaker Longsword'),
        ('weapon.circus.soul_draining_morningstar', 'Soul-Draining Morningstar'),
        ('weapon.devotees_mace', "Devotee's Mace"),
        ('weapon.circus.longsword_plus_one', 'Longsword +1'),
        ('weapon.arcane_staff', 'Arcane Staff'))]


def coating_weapon_studies():
    return [coating_weapon_study(kind) for kind in
            ('fire', 'lightning', 'concentration_fire', 'timed_fire', 'assassin_poison')]


def flaming_sphere_lifecycle_study():
    """Ordinary summon controller, accepted native movement/Ram and retirement."""
    inventory = subjects(['spell.flaming_sphere'],
                         ['action.move', 'action.spell.flaming_sphere.ram', 'action.drop_concentration'],
                         ['condition.concentrating', 'condition.spell.flaming_sphere.aura'])
    inventory['creature'] = ['creature.spell.flaming_sphere']
    inventory['spatial_effect'] = ['spatial_effect.spell.flaming_sphere.aura']
    return {
        'id': 'spell.flaming_sphere/summon_move_ram_retire',
        'title': 'Flaming Sphere: held summon, autonomous move/Ram, aura and retirement',
        'kind': 'spell', 'seed': 2, 'subjects': inventory,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.flaming_sphere'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [9, 7]}],
        'steps': [
            {'do': 'spell.flaming_sphere', 'by': 'caster', 'target': [6, 7], 'level': 2, 'capture_choices': True},
            {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'end_turn', 'by': 'caster'}, {'do': 'end_turn', 'by': 'target'},
            {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'},
            {'do': 'action.move', 'by': 'caster', 'target': [3, 5]}],
        'required_behaviors': ['spell.flaming_sphere', 'action.spell.flaming_sphere.ram',
                               'action.move', 'action.drop_concentration'],
        'required_conditions': ['condition.concentrating'],
        'required_condition_ends': ['condition.concentrating'],
        'required_facts': ['movement', 'spatial_effect_state', 'damage'],
        'required_applied_damage_types': ['Fire'],
        'purpose': 'The frozen engine assigns this real sphere to its NativeAIController, '
                   'not the human audience. End-turn commands allow only its actual accepted '
                   'movement/Ram; actual end-turn aura, fire surfaces and retirement remain '
                   'native facts, never fabricated trail deposition or caster-issued Ram.'}


def shillelagh_equipped_move_study():
    """Exact enchanted staff through movement, release and genuine re-equipping."""
    inventory = subjects(['spell.shillelagh'], ['action.move', 'action.attack'],
                         ['condition.spell.shillelagh'])
    inventory['item'] = ['weapon.quarterstaff', 'weapon.longsword']
    attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}
    return {
        'id': 'spell.shillelagh/equipped_move_release_reequip_replace',
        'title': 'Shillelagh: held movement, release, same staff re-equip and replacement',
        'kind': 'spell', 'seed': 2, 'subjects': inventory,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.shillelagh'], 'at': [4, 6],
             'items': [{'id': 'weapon.quarterstaff', 'slot': 'MELEE_MAIN'},
                       {'id': 'weapon.longsword', 'placement': 'inventory'}]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre_zombie', 'at': [6, 6]}],
        'steps': [
            {'do': 'spell.shillelagh', 'by': 'caster', 'target': 'self',
             'variant': {'form': 'MELEE_MAIN'}, 'capture_choices': True},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 6]}, dict(attack),
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'equip', 'by': 'caster', 'item': 'weapon.quarterstaff', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 5]}, dict(attack),
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'equip', 'by': 'caster', 'item': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.move', 'by': 'caster', 'target': [5, 6]}, dict(attack)],
        'required_behaviors': ['spell.shillelagh', 'action.move', 'action.attack'],
        'required_conditions': ['condition.spell.shillelagh'],
        'required_condition_ends': ['condition.spell.shillelagh'],
        'required_facts': ['movement', 'attack'],
        'purpose': 'Original affected_item_uuid must identify the actual equipped Quarterstaff. '
                   'Movement and accepted attacks preserve their actual outcomes. Unequip must '
                   'really remove that UUID owner; re-equipping the same staff and replacing it '
                   'with a plain Longsword cannot manufacture a new enchantment.'}


def goodberry_consumption_study():
    """Actual created items, use costs, positive/blocked healing and restoration."""
    inventory = subjects(['spell.goodberry', 'spell.chill_touch'],
                         ['action.spell.goodberry.eat', 'action.move'],
                         ['condition.spell.goodberry.batch', 'condition.spell.chill_touch'])
    inventory['item'] = ['consumable.goodberry']
    eat = {'do': 'action.spell.goodberry.eat', 'by': 'caster', 'target': 'self',
           'item': 'consumable.goodberry', 'capture_choices': True}
    return {
        'id': 'spell.goodberry/create_eat_blocked_restore',
        'title': 'Goodberry: created items, eat, blocked healing and restoration',
        'kind': 'spell', 'seed': 2, 'subjects': inventory,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.goodberry'],
             'damage': 20, 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.chill_touch'], 'at': [9, 7]}],
        'steps': [
            {'do': 'spell.goodberry', 'by': 'caster', 'target': 'self', 'level': 1}, dict(eat),
            {'do': 'spell.chill_touch', 'by': 'target', 'target': 'caster'},
            {'do': 'wait_condition', 'target': 'caster', 'condition': 'condition.spell.chill_touch', 'max_turns': 0},
            dict(eat), {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'end_turn', 'by': 'caster'}, {'do': 'end_turn', 'by': 'target'},
            dict(eat), {'do': 'action.move', 'by': 'caster', 'target': [3, 5]}],
        'required_behaviors': ['spell.goodberry', 'spell.chill_touch', 'action.spell.goodberry.eat', 'action.move'],
        'required_conditions': ['condition.spell.goodberry.batch', 'condition.spell.chill_touch'],
        'required_condition_ends': ['condition.spell.chill_touch'],
        'required_facts': ['item_charge', 'heal', 'damage', 'movement'],
        'purpose': 'Exact generated inventory items are selected through real offered item-use actions. '
                   'Every consumed charge and actual positive/blocked healing result is retained. '
                   'Chill Touch must actually apply and expire; neither healing admission nor '
                   'private peer charge state is inferred from a request or fixture default.'}


def power_word_heal_poison_study():
    """Preserve real attack/save attempts, then cure an observed Poisoned member."""
    condition = 'condition.spell.ray_of_sickness.poison'
    return {
        'id': 'spell.power_word_heal/ray_poisoned_restore_move',
        'title': 'Power Word Heal: actual Ray poison, cure and restored movement',
        'kind': 'spell', 'seed': 2,
        'subjects': subjects(['spell.ray_of_sickness', 'spell.power_word_heal'],
                             ['action.move'], [condition]),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.ray_of_sickness'], 'at': [3, 7]},
            {'role': 'healer', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.power_word_heal'], 'at': [3, 8]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [8, 7]}],
        'steps': [
            {'do': 'spell.ray_of_sickness', 'by': 'caster', 'target': 'target', 'level': 1},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'spell.ray_of_sickness', 'by': 'caster', 'target': 'target', 'level': 1},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'spell.ray_of_sickness', 'by': 'caster', 'target': 'target', 'level': 1},
            {'do': 'wait_condition', 'target': 'target', 'condition': condition, 'max_turns': 0},
            {'do': 'spell.power_word_heal', 'by': 'healer', 'target': 'target', 'capture_choices': True},
            {'do': 'action.move', 'by': 'target', 'target': [9, 7]}],
        'required_behaviors': ['spell.ray_of_sickness', 'spell.power_word_heal', 'action.move'],
        'required_conditions': [condition], 'required_condition_ends': [condition],
        'required_facts': ['saving_throw', 'damage', 'heal', 'movement'],
        'purpose': 'Fixed legal attack/save sequence, preserving every Miss/save/failure. '
                   'A real observed Poisoned member must exist before the healer is asked '
                   'to cure it. Exact native removal ancestry, rather than request success '
                   'or positive Poison damage, proves Power Word Heal restoration.'}


def glyph_warding_trigger_study():
    """Keep a real glyph unoccupied, then enter its footprint as an enemy."""
    inventory = subjects(['spell.glyph_of_warding'], ['action.move'],
                         ['condition.spell.glyph_of_warding'])
    inventory['spatial_effect'] = ['spatial_effect.spell.glyph_of_warding']
    return {
        'id': 'spell.glyph_of_warding/arm_move_enter_trigger',
        'title': 'Glyph: placement, held movement, hostile entry and actual payload',
        'kind': 'spell', 'seed': 2, 'subjects': inventory,
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.glyph_of_warding'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [9, 7]}],
        'steps': [
            {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'spell.glyph_of_warding', 'by': 'caster', 'target': [6, 7],
             'level': 3, 'variant': {'form': 'fire'}, 'capture_choices': True},
            {'do': 'action.move', 'by': 'caster', 'target': [3, 5]},
            {'do': 'action.move', 'by': 'target', 'target': [9, 6]},
            {'do': 'action.move', 'by': 'target', 'target': [8, 7]},
            {'do': 'action.move', 'by': 'target', 'target': [9, 7]}],
        'required_behaviors': ['spell.glyph_of_warding', 'action.move'],
        'required_conditions': ['condition.spell.glyph_of_warding'],
        'required_condition_ends': ['condition.spell.glyph_of_warding'],
        'required_facts': ['movement', 'spatial_effect_state', 'saving_throw', 'damage'],
        'required_applied_damage_types': ['Fire'],
        'purpose': 'Actual ordinary hostile entry after a separately published held interval. '
                   'The legal request selects Fire, but native armed/payload inputs are not '
                   'manufactured from the request or from the name of the spell.'}


def glyph_warding_trigger_studies():
    """The same legal hostile entry with each actual offered elemental form."""
    result = []
    for form in ('acid', 'cold', 'fire', 'lightning', 'thunder'):
        case = glyph_warding_trigger_study()
        if form != 'fire':
            case['id'] = 'spell.glyph_of_warding/'+form+'_observed_contact'
        case['title'] = 'Glyph '+form.title()+': placement, held movement and actual contact'
        case['steps'][1]['variant']['form'] = form
        case['required_applied_damage_types'] = [form.title()]
        case['purpose'] = ('Actual ordinary hostile entry after a separately published held interval. '
            'The legal request selects '+form.title()+', but no armed or payload state is '
            'manufactured from that request. Qualification requires the original positive '
            +form.title()+' result and retains any genuine failed outcome.')
        result.append(case)
    return result


def water_create_dry_study():
    """Actual offered forms and the resulting same-owner water removal."""
    return {
        'id': 'spell.create_or_destroy_water/create_move_dry',
        'title': 'Water: create, enter, actual Dry removal and movement after',
        'kind': 'spell', 'seed': 2,
        'subjects': subjects(['spell.create_or_destroy_water'], ['action.move']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.create_or_destroy_water'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
             'level': 20, 'at': [6, 7]}],
        'steps': [
            {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'spell.create_or_destroy_water', 'by': 'caster', 'target': [6, 7],
             'level': 1, 'variant': {'form': 'create'}, 'capture_choices': True},
            {'do': 'action.move', 'by': 'target', 'target': [6, 6]},
            {'do': 'spell.create_or_destroy_water', 'by': 'caster', 'target': [6, 7],
             'level': 1, 'variant': {'form': 'destroy'}, 'capture_choices': True},
            {'do': 'action.move', 'by': 'target', 'target': [7, 6]}],
        'required_behaviors': ['spell.create_or_destroy_water', 'action.move'],
        'required_facts': ['movement', 'spatial_effect_state'],
        'purpose': 'Legal public create/destroy facets and actual disclosed DRY spatial transition. '
                   'The request does not manufacture a SpellFact form or prove removal by itself; '
                   'original same-owner removed positions must supply that evidence.'}


def coating_weapon_study(kind):
    """One real item member, motion/contact and its actual retirement policy."""
    case = poison_weapon_contact_study()
    item = 'consumable.weapon_coat.' + kind
    condition = 'condition.consumable.weapon_coat.' + kind
    case['id'] = item + '/equipped_runtime'
    case['title'] = kind.replace('_', ' ').title() + ': held coat, movement, contact and retirement'
    case['subjects'] = subjects(actions=['action.item.weapon_coat.apply', 'action.move', 'action.attack'],
                                conditions=[condition])
    case['subjects']['item'] = ['weapon.longsword', 'weapon.scimitar', item]
    case['actors'][0]['items'] = [
        {'id': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
        {'id': 'weapon.scimitar', 'placement': 'inventory'},
        {'id': item, 'placement': 'inventory'}]
    case['actors'][1]['creature'] = 'creature.ogre_zombie'
    attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}
    apply = {'do': 'action.item.weapon_coat.apply', 'by': 'caster', 'target': 'self',
             'item': item, 'name': 'Coat Main Hand', 'capture_choices': True}
    steps = [apply, {'do': 'action.move', 'by': 'caster', 'target': [5, 5]},
             {'do': 'end_turn', 'by': 'caster'}, dict(attack),
             {'do': 'end_turn', 'by': 'caster'}, dict(attack)]
    if kind == 'concentration_fire':
        steps.append({'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'})
        case['subjects']['action'].append('action.drop_concentration')
    elif kind in ('timed_fire', 'assassin_poison'):
        steps += [{'do': 'end_turn'} for _ in range(6 if kind == 'timed_fire' else 20)]
    elif kind == 'lightning':
        # Different native condition names can coexist. Record that fact;
        # the delivered single direct-material owner cannot compose them.
        extra_item = 'consumable.weapon_coat.fire'
        case['actors'][0]['items'].append({'id': extra_item, 'placement': 'inventory'})
        case['subjects']['item'].append(extra_item)
        case['subjects']['condition'].append('condition.consumable.weapon_coat.fire')
        steps += [{'do': 'end_turn', 'by': 'caster'},
                  {'do': 'action.item.weapon_coat.apply', 'by': 'caster', 'target': 'self',
                   'item': extra_item, 'name': 'Coat Main Hand'}, dict(attack)]
    steps += [{'do': 'end_turn', 'by': 'caster'}, dict(attack),
              {'do': 'end_turn', 'by': 'caster'}, {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
              {'do': 'end_turn', 'by': 'caster'},
              {'do': 'equip', 'by': 'caster', 'item': 'weapon.scimitar', 'slot': 'MELEE_MAIN'},
              {'do': 'end_turn', 'by': 'caster'}, dict(attack)]
    case['steps'] = steps
    case['required_behaviors'] = list(case['subjects']['action'])
    case['required_facts'] = ['actor_change', 'movement', 'attack', 'damage']
    case['purpose'] = ('Exact public coating membership on the actual longsword; only natural expiry, '
                       'legal concentration removal or optical item replacement retires its treatment. '
                       'The Ogre Zombie target has actual Poison immunity; Poisoned or positive poison '
                       'damage is not claimed. Concurrent Fire/Lightning is evidence of the source '
                       'composition gap, never permission to overwrite the first direct owner.')
    return case


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


def option_identity_studies():
    """Only forms exposed by the frozen public action facets, plus real saves."""
    result = []
    for ability in ('charisma', 'constitution', 'dexterity', 'intelligence', 'wisdom'):
        result.append({
            'id': 'spell.enhance_ability/' + ability + '_lifecycle',
            'title': 'Enhance Ability: ' + ability.title() + ', movement and removal',
            'kind': 'spell', 'seed': 2,
            'subjects': subjects(['spell.enhance_ability'], ['action.move', 'action.drop_concentration'],
                                 ['condition.spell.enhance_ability']),
            'actors': [
                {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
                 'level': 20, 'caster_level': 20, 'spells': ['spell.enhance_ability'], 'at': [3, 7]},
                {'role': 'ally', 'side': 'amber', 'creature': 'creature.generic_caster',
                 'level': 20, 'at': [3, 8]},
                {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
                 'level': 20, 'at': [9, 7]}],
            'steps': [
                {'do': 'spell.enhance_ability', 'by': 'caster', 'target': 'ally',
                 'variant': {'ability': ability}, 'level': 2, 'capture_choices': True,
                 'track': True, 'track_condition': 'condition.spell.enhance_ability'},
                {'do': 'hold_walk', 'offset': [-1, 0]},
                {'do': 'end_tracked', 'strategy': 'concentration'},
                {'do': 'tail_walk', 'by': 'ally', 'offset': [0, -1]}],
            'required_behaviors': ['spell.enhance_ability', 'action.move', 'action.drop_concentration'],
            'required_conditions': ['condition.spell.enhance_ability'],
            'required_condition_ends': ['condition.spell.enhance_ability'],
            'purpose': 'Exact offered ability facet, actual recipient membership/movement, '
                       'legal concentration removal and restored movement; no new graphics approval.'})
    result.append({
        'id': 'spell.dissonant_whispers/deva_saving_throws',
        'title': 'Dissonant Whispers: actual saves against a Wisdom-proficient Deva',
        'kind': 'spell', 'seed': 2,
        'subjects': subjects(['spell.dissonant_whispers']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 3, 'caster_level': 3, 'spells': ['spell.dissonant_whispers'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.spell.deva', 'at': [6, 7]}],
        'steps': [
            {'do': 'spell.dissonant_whispers', 'by': 'caster', 'target': 'target', 'level': 1,
             'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'spell.dissonant_whispers', 'by': 'caster', 'target': 'target', 'level': 1}],
        'required_behaviors': ['spell.dissonant_whispers'],
        'required_facts': ['saving_throw', 'damage'],
        'purpose': 'Two fixed ordinary casts against the authored Wisdom-proficient Deva. '
                   'Only actual saving-throw facts establish a saved branch; no rolled outcome is forced.'})
    result.append({
        'id': 'spell.dissonant_whispers/modular_cleric_saves',
        'title': 'Dissonant Whispers: actual saves and Resistance on a modular Cleric',
        'kind': 'spell', 'seed': 2, 'first': 'blue',
        'subjects': subjects(['spell.dissonant_whispers', 'spell.resistance']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 3, 'caster_level': 3, 'spells': ['spell.dissonant_whispers'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'premade': 'cleric', 'at': [6, 7]}],
        'steps': [step for _ in range(3) for step in (
            {'do': 'spell.resistance', 'by': 'target', 'target': 'self'},
            {'do': 'spell.dissonant_whispers', 'by': 'caster', 'target': 'target', 'level': 1,
             'capture_choices': True})],
        'required_behaviors': ['spell.dissonant_whispers', 'spell.resistance'],
        'required_facts': ['saving_throw', 'damage'],
        'purpose': 'Fixed lawful casts against a real Wisdom-proficient Life Cleric with actual Resistance. '
                   'The target uses the existing modular body with authored optical ground; '
                   'successful-save evidence comes only from unchanged original facts.'})
    return result


def poison_weapon_runtime_study():
    """The same finite coat survives actual movement and item-slot transitions."""
    case = poison_weapon_contact_study()
    case['id'] = 'consumable.weapon_coat.basic_poison/move_reequip_replace_expire'
    case['title'] = 'Basic Poison: movement, same-sword re-equip, replacement and expiry'
    case['subjects']['action'] += ['action.move']
    case['subjects']['item'] += ['weapon.scimitar']
    case['actors'][0]['items'].append({'id': 'weapon.scimitar', 'placement': 'inventory'})
    attack = {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'}
    case['steps'] = [
        {'do': 'action.item.weapon_coat.apply', 'by': 'caster', 'target': 'self',
         'item': 'consumable.weapon_coat.basic_poison', 'name': 'Coat Main Hand', 'capture_choices': True},
        {'do': 'action.move', 'by': 'caster', 'target': [5, 5]},
        {'do': 'end_turn', 'by': 'caster'}, dict(attack),
        {'do': 'end_turn', 'by': 'caster'}, dict(attack),
        {'do': 'end_turn', 'by': 'caster'}, {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
        {'do': 'end_turn', 'by': 'caster'},
        {'do': 'equip', 'by': 'caster', 'item': 'weapon.longsword', 'slot': 'MELEE_MAIN'},
        {'do': 'action.move', 'by': 'caster', 'target': [5, 6]},
        {'do': 'end_turn', 'by': 'caster'}, dict(attack),
        {'do': 'end_turn', 'by': 'caster'}, {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_MAIN'},
        {'do': 'end_turn', 'by': 'caster'},
        {'do': 'equip', 'by': 'caster', 'item': 'weapon.scimitar', 'slot': 'MELEE_MAIN'},
        {'do': 'end_turn', 'by': 'caster'}, dict(attack)
    ] + [{'do': 'end_turn'} for _ in range(20)] + [dict(attack)]
    case['required_behaviors'] += ['action.move']
    case['required_facts'] += ['movement', 'actor_change']
    case['purpose'] = ('One actual item-coating UUID across movement and unequip/re-equip of the same longsword; '
                       'a different uncoated weapon is equipped and used before the original coat expires '
                       'through ordinary turns. No membership, expiry or native graphics is fabricated.')
    return case


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


def skeleton_mark_lifecycle_study():
    """Native archer intrinsic, exact recipient mark and public concentration end."""
    action = 'action.creature.skeleton_archer.mark_target'
    marked = 'trait.skeleton_archer_marked'
    inventory = subjects(actions=[action, 'action.move', 'action.drop_concentration'],
                         conditions=[marked, 'condition.concentrating'])
    inventory['creature'] = ['creature.skeleton_archer']
    return {
        'id': action+'/recipient_move_concentration_end',
        'title': 'Skeleton Archer Mark: actual recipient movement and concentration removal',
        'kind': 'action', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
        'subjects': inventory,
        'actors': [{'role': 'caster', 'side': 'amber', 'creature': 'creature.skeleton_archer', 'at': [3, 7]},
                   {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [6, 7]}],
        'steps': [{'do': action, 'by': 'caster', 'target': 'target', 'track': True,
                   'track_condition': marked, 'capture_choices': True},
                  {'do': 'action.move', 'by': 'target', 'target': [6, 8]},
                  {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'},
                  {'do': 'action.move', 'by': 'target', 'target': [7, 8]}],
        'required_behaviors': [action, 'action.move', 'action.drop_concentration'],
        'required_conditions': [marked, 'condition.concentrating'],
        'required_condition_ends': [marked, 'condition.concentrating'],
        'required_facts': ['movement'],
        'purpose': 'Actual Skeleton Archer intrinsic action, visible hostile target within60ft and source-linked concentration. '
                   'Preserve native action choices/Preview, exact recipient Marked member UUID, held recipient movement and genuine concentration-linked removal. '
                   'No action/condition grant, setup injection, save/RNG retry or renderer claim. Existing Driver.turn_of follows each actual published input actor.'}


def coating_slot_lifecycle_studies():
    """Repeat the actual9f ranged/offhand inputs without injecting memberships."""
    return [{'id': 'action.item.ember_quiver/ranged_main_membership_expiry',
      'title': 'Ember Quiver: actual ranged-main bow, held membership, re-equip and expiry',
      'kind': 'item',
      'subjects': {'spell': [],
                   'action': ['action.item.ember_quiver', 'action.attack', 'action.move'],
                   'condition': ['condition.consumable.weapon_coat.timed_fire'],
                   'creature': ['creature.knight'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': ['gear.ember_quiver', 'weapon.shortbow']},
      'seed': 2,
      'actors': [{'role': 'caster',
                  'side': 'amber',
                  'premade': 'fighter',
                  'at': [3, 7],
                  'items': [{'id': 'weapon.shortbow', 'slot': 'RANGED_MAIN'},
                            {'id': 'gear.ember_quiver', 'slot': 'Backpack'}]},
                 {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [8, 7]}],
      'steps': [{'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'RANGED_MAIN'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.item.ember_quiver',
                 'by': 'caster',
                 'target': 'self',
                 'item': 'gear.ember_quiver',
                 'capture_choices': True,
                 'track': True,
                 'track_item_effect': 'condition.consumable.weapon_coat.timed_fire'},
                {'do': 'hold_walk', 'offset': [0, -1]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'RANGED_MAIN'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'unequip', 'by': 'caster', 'slot': 'RANGED_MAIN'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'equip', 'by': 'caster', 'item': 'weapon.shortbow', 'slot': 'RANGED_MAIN'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'RANGED_MAIN'},
                {'do': 'end_tracked', 'strategy': 'turns', 'max_turns': 40},
                {'do': 'tail_walk', 'by': 'caster', 'offset': [1, 0]}],
      'required_behaviors': ['action.item.ember_quiver', 'action.attack', 'action.move'],
      'required_facts': ['attack', 'movement'],
      'required_item_effects': ['condition.consumable.weapon_coat.timed_fire'],
      'required_item_effect_ends': ['condition.consumable.weapon_coat.timed_fire'],
      'purpose': 'The actual equipped Ember Quiver applies its native ten-round TimedFire item effect to the '
                 'declared RANGED_MAIN bow. The initial ordinary ranged attack selects the real active ranged '
                 'set; neither a hit nor positive Fire damage is assumed. The same actual item can become '
                 'unequipped/re-equipped while the original effect ages, then ordinary turns must publish its '
                 'real removal. Both original human-seat journals remain authoritative; no condition, source '
                 'UUID, holder, expiry or graphics result is injected.'},
     {'id': 'consumable.weapon_coat.basic_poison/melee_off_membership_expiry',
      'title': 'Basic Poison: actual offhand item membership, re-equip and expiry',
      'kind': 'item',
      'subjects': {'spell': [],
                   'action': ['action.item.weapon_coat.apply', 'action.attack', 'action.move'],
                   'condition': ['condition.consumable.weapon_coat.basic_poison'],
                   'creature': ['creature.ogre_zombie'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': ['weapon.shortsword', 'weapon.scimitar', 'consumable.weapon_coat.basic_poison']},
      'seed': 2,
      'actors': [{'role': 'caster',
                  'side': 'amber',
                  'premade': 'fighter',
                  'at': [5, 6],
                  'items': [{'id': 'weapon.shortsword', 'slot': 'MELEE_MAIN'},
                            {'id': 'weapon.scimitar', 'slot': 'MELEE_OFF'},
                            {'id': 'consumable.weapon_coat.basic_poison', 'placement': 'inventory'}]},
                 {'role': 'target', 'side': 'blue', 'creature': 'creature.ogre_zombie', 'at': [6, 6]}],
      'steps': [{'do': 'action.item.weapon_coat.apply',
                 'by': 'caster',
                 'target': 'self',
                 'item': 'consumable.weapon_coat.basic_poison',
                 'name': 'Coat Off Hand',
                 'capture_choices': True,
                 'track': True,
                 'track_item_effect': 'condition.consumable.weapon_coat.basic_poison'},
                {'do': 'hold_walk', 'offset': [0, -1]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_OFF'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'unequip', 'by': 'caster', 'slot': 'MELEE_OFF'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'equip', 'by': 'caster', 'item': 'weapon.scimitar', 'slot': 'MELEE_OFF'},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN'},
                {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_OFF'},
                {'do': 'end_tracked', 'strategy': 'turns', 'max_turns': 40},
                {'do': 'tail_walk', 'by': 'caster', 'offset': [0, 1]}],
      'required_behaviors': ['action.item.weapon_coat.apply', 'action.attack', 'action.move'],
      'required_facts': ['attack', 'movement'],
      'required_item_effects': ['condition.consumable.weapon_coat.basic_poison'],
      'required_item_effect_ends': ['condition.consumable.weapon_coat.basic_poison'],
      'purpose': "Select the actual consumable's offered Coat Off Hand action with a real light scimitar in "
                 'MELEE_OFF and a real light shortsword in MELEE_MAIN. Main and offhand attacks use ordinary '
                 "action/bonus-action budgets, with no forced Hit/Crit. Ogre Zombie's Poison immunity is "
                 'retained; Poisoned or positive Poison damage is not a prerequisite. Exact item-effect '
                 'membership survives the ordinary same-item unequip/re-equip and must end through real native '
                 'turns. No actor condition, artificial socket, effect UUID, packet, expiry or rendered '
                 'acceptance is manufactured.'}]


def class_held_lifecycle_studies():
    """Repeat actual paid class-owner originals through the existing saved profile."""
    return [{'id': 'action.class.sorcerer.distant_spell/held_move_actual_spell_consumption',
      'title': 'Distant Spell: real pending member, held movement and spell consumption',
      'kind': 'action',
      'seed': 2,
      'subjects': {'spell': ['spell.fire_bolt'],
                   'action': ['action.class.sorcerer.distant_spell', 'action.move'],
                   'condition': ['class_feature.sorcerer.metamagic_active'],
                   'creature': [],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'party'}, {'role': 'ally', 'side': 'party'}],
      'player_builds_source': 'tools/studio_cases/scenarios/legacy_sorcerer14_fighter17.json',
      'steps': [{'do': 'action.class.sorcerer.distant_spell',
                 'by': 'caster',
                 'target': 'self',
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 10]},
                {'do': 'spell.fire_bolt', 'by': 'caster', 'target': 'Goblin 1', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 9]}],
      'required_behaviors': ['action.class.sorcerer.distant_spell', 'action.move', 'spell.fire_bolt'],
      'required_conditions': ['class_feature.sorcerer.metamagic_active'],
      'required_condition_ends': ['class_feature.sorcerer.metamagic_active'],
      'required_facts': ['movement'],
      'purpose': 'The existing saved Sorcerer14 progression legitimately selected Quickened/Twinned at level3 '
                 'and Distant at level10. Select its actual distant action, retain its real public '
                 'metamagic_mode=distant member while moving, then consume it through the ordinary offered Fire '
                 'Bolt. No successful hit or damage is required, and actual outside-encounter transitions remain '
                 'ordinary native facts. Exact application and end of the pending class member are hard '
                 'prerequisites; no fake mode, feature/condition grant, spell target, state override, RNG retry '
                 'or rendered acceptance is supplied.'},
     {'id': 'action.class.sorcerer.elemental_affinity.resistance/held_move_native_replacement',
      'title': 'Elemental Affinity: actual Fire member, movement and genuine replacement',
      'kind': 'action',
      'seed': 2,
      'subjects': {'spell': [],
                   'action': ['action.class.sorcerer.elemental_affinity.resistance', 'action.move'],
                   'condition': ['class_feature.sorcerer.elemental_affinity.resistance'],
                   'creature': [],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'party'}, {'role': 'ally', 'side': 'party'}],
      'player_builds_source': 'tools/studio_cases/scenarios/legacy_sorcerer14_fighter17.json',
      'steps': [{'do': 'action.class.sorcerer.elemental_affinity.resistance',
                 'by': 'caster',
                 'target': 'self',
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 10]},
                {'do': 'action.class.sorcerer.elemental_affinity.resistance',
                 'by': 'caster',
                 'target': 'self',
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [8, 10]}],
      'required_behaviors': ['action.class.sorcerer.elemental_affinity.resistance', 'action.move'],
      'required_conditions': ['class_feature.sorcerer.elemental_affinity.resistance'],
      'required_condition_ends': ['class_feature.sorcerer.elemental_affinity.resistance'],
      'required_facts': ['movement'],
      'purpose': 'The existing saved Sorcerer14 character legally chose red Draconic ancestry and owns the '
                 'native Affinity action and sorcery points. Each ordinary self activation spends one real '
                 'point. The second activation removes the first exact resistance UUID and creates another real '
                 'member; it does not pretend the one-hour/600-round owner expired or require 1200 end-turn '
                 'commands. Frozen source publishes damage_type=Fire for this profile. Preserve the actual '
                 'state/UUIDs and old-owner removal plus held motion; the second real owner remains active at '
                 'the original endpoint. No feature/condition grant, damage consequence, roll retry or '
                 'body/output acceptance is supplied.'},
     {'id': 'action.class.sorcerer.quickened_spell/held_move_actual_spell_consumption',
      'title': 'Quickened Spell: real pending member, held movement and spell consumption',
      'kind': 'action',
      'seed': 2,
      'subjects': {'spell': ['spell.fire_bolt'],
                   'action': ['action.class.sorcerer.quickened_spell', 'action.move'],
                   'condition': ['class_feature.sorcerer.metamagic_active'],
                   'creature': [],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'party'}, {'role': 'ally', 'side': 'party'}],
      'player_builds_source': 'tools/studio_cases/scenarios/legacy_sorcerer14_fighter17.json',
      'steps': [{'do': 'action.class.sorcerer.quickened_spell',
                 'by': 'caster',
                 'target': 'self',
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 10]},
                {'do': 'spell.fire_bolt', 'by': 'caster', 'target': 'Goblin 1', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 9]}],
      'required_behaviors': ['action.class.sorcerer.quickened_spell', 'action.move', 'spell.fire_bolt'],
      'required_conditions': ['class_feature.sorcerer.metamagic_active'],
      'required_condition_ends': ['class_feature.sorcerer.metamagic_active'],
      'required_facts': ['movement'],
      'purpose': 'The existing saved Sorcerer14 progression legitimately selected Quickened/Twinned at level3 '
                 'and Distant at level10. Select its actual quickened action, retain its real public '
                 'metamagic_mode=quickened member while moving, then consume it through the ordinary offered '
                 'Fire Bolt. No successful hit or damage is required, and actual outside-encounter transitions '
                 'remain ordinary native facts. Exact application and end of the pending class member are hard '
                 'prerequisites; no fake mode, feature/condition grant, spell target, state override, RNG retry '
                 'or rendered acceptance is supplied.'},
     {'id': 'action.class.sorcerer.twinned_spell/held_move_actual_spell_consumption',
      'title': 'Twinned Spell: real pending member, held movement and spell consumption',
      'kind': 'action',
      'seed': 2,
      'subjects': {'spell': ['spell.fire_bolt'],
                   'action': ['action.class.sorcerer.twinned_spell', 'action.move'],
                   'condition': ['class_feature.sorcerer.metamagic_active'],
                   'creature': [],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'party'}, {'role': 'ally', 'side': 'party'}],
      'player_builds_source': 'tools/studio_cases/scenarios/legacy_sorcerer14_fighter17.json',
      'steps': [{'do': 'action.class.sorcerer.twinned_spell',
                 'by': 'caster',
                 'target': 'self',
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 10]},
                {'do': 'spell.fire_bolt',
                 'by': 'caster',
                 'target': 'Goblin 1',
                 'capture_choices': True,
                 'recipients': ['Goblin 1', 'Goblin 2']},
                {'do': 'action.move', 'by': 'caster', 'target': [9, 9]}],
      'required_behaviors': ['action.class.sorcerer.twinned_spell', 'action.move', 'spell.fire_bolt'],
      'required_conditions': ['class_feature.sorcerer.metamagic_active'],
      'required_condition_ends': ['class_feature.sorcerer.metamagic_active'],
      'required_facts': ['movement'],
      'purpose': 'The existing saved Sorcerer14 progression legitimately selected Quickened/Twinned at level3 '
                 'and Distant at level10. Select its actual twinned action, retain its real public '
                 'metamagic_mode=twinned member while moving, then consume it through the ordinary offered Fire '
                 'Bolt. Both named living Goblins must be offered by actual Preview; no duplicated or invented '
                 'recipient is submitted. No successful hit or damage is required, and actual outside-encounter '
                 'transitions remain ordinary native facts. Exact application and end of the pending class '
                 'member are hard prerequisites; no fake mode, feature/condition grant, spell target, state '
                 'override, RNG retry or rendered acceptance is supplied.'}]


def elemental_body_lifecycle_studies():
    """Repeat the four real intrinsic-body/death originals without granting powers."""
    return [{'id': 'creature.spell.air_elemental/own_body_native_intrinsics_death',
      'title': 'Air Elemental: real own body, two native intrinsics and ordinary death',
      'kind': 'creature',
      'seed': 2,
      'battlefield': 'battlefield.open_floor_bright',
      'subjects': {'spell': ['spell.magic_missile', 'spell.power_word_kill'],
                   'action': ['action.move',
                              'action.attack',
                              'action.air_elemental.gushing_air',
                              'action.air_elemental.primordial_gales',
                              'action.disengage'],
                   'condition': [],
                   'creature': ['creature.spell.air_elemental', 'creature.generic_caster'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'amber', 'creature': 'creature.spell.air_elemental', 'at': [3, 6]},
                 {'role': 'target',
                  'side': 'blue',
                  'creature': 'creature.generic_caster',
                  'level': 20,
                  'caster_level': 20,
                  'spells': ['spell.magic_missile', 'spell.power_word_kill'],
                  'at': [4, 5]}],
      'steps': [{'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
                {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack',
                 'by': 'caster',
                 'target': 'target',
                 'weapon_slot': 'MELEE_MAIN',
                 'capture_choices': True,
                 'optional': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.air_elemental.gushing_air',
                 'by': 'caster',
                 'target': 'target',
                 'capture_choices': True,
                 'recipients': ['target', 'target']},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.air_elemental.primordial_gales',
                 'by': 'caster',
                 'target': [3, 6],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 5,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 6,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.power_word_kill',
                 'by': 'target',
                 'target': 'caster',
                 'level': 9,
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'target', 'target': [5, 4]}],
      'required_behaviors': ['action.move',
                             'action.air_elemental.gushing_air',
                             'action.air_elemental.primordial_gales',
                             'spell.magic_missile',
                             'spell.power_word_kill',
                             'action.disengage'],
      'required_facts': ['movement', 'attack', 'damage', 'saving_throw', 'life'],
      'purpose': 'The frozen native creature factory intrinsically installs both selected elemental actions and '
                 'its bound natural attack; this setup grants none of those powers. Actual intrinsic Disengage '
                 'prevents an extra opportunity hit; two ordinary moves restore the same real origin before '
                 'actual action choices/Preview. The normal bound Attack is optional only if actual public '
                 'discovery exposes a legal adjacent target; no reach/socket/target is invented (Fire Slam has '
                 'native4ft reach). Both actual intrinsic actions are mandatory and saves/contacts/riders remain '
                 'native outcomes. A real level20 opposing caster then spends actual L5/L6 Magic Missile slots '
                 'on this actor followed by actual L9 Power Word Kill: no initial HP editing, forced hit/save, '
                 'fabricated removal or spell-shaped elemental action. Native elemental max-HP '
                 'bonuses90/126/102/114 with no hit dice and the two real 1d4+1 volleys (15 darts,30–75 total '
                 'Force) provide a bounded legitimate death path, with every refusal retained. The final '
                 'opponent move publishes the ordinary post-death prefix. Both original seat journals remain '
                 'independent; source art/scale/geometry/facing/native output and all artwork acceptance remain '
                 'separate.'},
     {'id': 'creature.spell.earth_elemental/own_body_native_intrinsics_death',
      'title': 'Earth Elemental: real own body, two native intrinsics and ordinary death',
      'kind': 'creature',
      'seed': 2,
      'battlefield': 'battlefield.open_floor_bright',
      'subjects': {'spell': ['spell.magic_missile', 'spell.power_word_kill'],
                   'action': ['action.move',
                              'action.attack',
                              'action.earth_elemental.soil_clogged_slam',
                              'action.earth_elemental.seismic_strike',
                              'action.disengage'],
                   'condition': [],
                   'creature': ['creature.spell.earth_elemental', 'creature.generic_caster'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'amber', 'creature': 'creature.spell.earth_elemental', 'at': [3, 6]},
                 {'role': 'target',
                  'side': 'blue',
                  'creature': 'creature.generic_caster',
                  'level': 20,
                  'caster_level': 20,
                  'spells': ['spell.magic_missile', 'spell.power_word_kill'],
                  'at': [4, 5]}],
      'steps': [{'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
                {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack',
                 'by': 'caster',
                 'target': 'target',
                 'weapon_slot': 'MELEE_MAIN',
                 'capture_choices': True,
                 'optional': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.earth_elemental.soil_clogged_slam',
                 'by': 'caster',
                 'target': [4, 5],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.earth_elemental.seismic_strike',
                 'by': 'caster',
                 'target': [3, 6],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 5,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 6,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.power_word_kill',
                 'by': 'target',
                 'target': 'caster',
                 'level': 9,
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'target', 'target': [5, 4]}],
      'required_behaviors': ['action.move',
                             'action.earth_elemental.soil_clogged_slam',
                             'action.earth_elemental.seismic_strike',
                             'spell.magic_missile',
                             'spell.power_word_kill',
                             'action.disengage'],
      'required_facts': ['movement', 'attack', 'damage', 'saving_throw', 'life'],
      'purpose': 'The frozen native creature factory intrinsically installs both selected elemental actions and '
                 'its bound natural attack; this setup grants none of those powers. Actual intrinsic Disengage '
                 'prevents an extra opportunity hit; two ordinary moves restore the same real origin before '
                 'actual action choices/Preview. The normal bound Attack is optional only if actual public '
                 'discovery exposes a legal adjacent target; no reach/socket/target is invented (Fire Slam has '
                 'native4ft reach). Both actual intrinsic actions are mandatory and saves/contacts/riders remain '
                 'native outcomes. A real level20 opposing caster then spends actual L5/L6 Magic Missile slots '
                 'on this actor followed by actual L9 Power Word Kill: no initial HP editing, forced hit/save, '
                 'fabricated removal or spell-shaped elemental action. Native elemental max-HP '
                 'bonuses90/126/102/114 with no hit dice and the two real 1d4+1 volleys (15 darts,30–75 total '
                 'Force) provide a bounded legitimate death path, with every refusal retained. The final '
                 'opponent move publishes the ordinary post-death prefix. Both original seat journals remain '
                 'independent; source art/scale/geometry/facing/native output and all artwork acceptance remain '
                 'separate.'},
     {'id': 'creature.spell.fire_elemental/own_body_native_intrinsics_death',
      'title': 'Fire Elemental: real own body, two native intrinsics and ordinary death',
      'kind': 'creature',
      'seed': 2,
      'battlefield': 'battlefield.open_floor_bright',
      'subjects': {'spell': ['spell.magic_missile', 'spell.power_word_kill'],
                   'action': ['action.move',
                              'action.attack',
                              'action.fire_elemental.smouldering_touch',
                              'action.fire_elemental.cinderous_swipe',
                              'action.disengage'],
                   'condition': [],
                   'creature': ['creature.spell.fire_elemental', 'creature.generic_caster'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'amber', 'creature': 'creature.spell.fire_elemental', 'at': [3, 6]},
                 {'role': 'target',
                  'side': 'blue',
                  'creature': 'creature.generic_caster',
                  'level': 20,
                  'caster_level': 20,
                  'spells': ['spell.magic_missile', 'spell.power_word_kill'],
                  'at': [4, 5]}],
      'steps': [{'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
                {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack',
                 'by': 'caster',
                 'target': 'target',
                 'weapon_slot': 'MELEE_MAIN',
                 'capture_choices': True,
                 'optional': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.fire_elemental.smouldering_touch',
                 'by': 'caster',
                 'target': [4, 5],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.fire_elemental.cinderous_swipe',
                 'by': 'caster',
                 'target': [4, 5],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 5,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 6,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.power_word_kill',
                 'by': 'target',
                 'target': 'caster',
                 'level': 9,
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'target', 'target': [5, 4]}],
      'required_behaviors': ['action.move',
                             'action.fire_elemental.smouldering_touch',
                             'action.fire_elemental.cinderous_swipe',
                             'spell.magic_missile',
                             'spell.power_word_kill',
                             'action.disengage'],
      'required_facts': ['movement', 'attack', 'damage', 'saving_throw', 'life'],
      'purpose': 'The frozen native creature factory intrinsically installs both selected elemental actions and '
                 'its bound natural attack; this setup grants none of those powers. Actual intrinsic Disengage '
                 'prevents an extra opportunity hit; two ordinary moves restore the same real origin before '
                 'actual action choices/Preview. The normal bound Attack is optional only if actual public '
                 'discovery exposes a legal adjacent target; no reach/socket/target is invented (Fire Slam has '
                 'native4ft reach). Both actual intrinsic actions are mandatory and saves/contacts/riders remain '
                 'native outcomes. A real level20 opposing caster then spends actual L5/L6 Magic Missile slots '
                 'on this actor followed by actual L9 Power Word Kill: no initial HP editing, forced hit/save, '
                 'fabricated removal or spell-shaped elemental action. Native elemental max-HP '
                 'bonuses90/126/102/114 with no hit dice and the two real 1d4+1 volleys (15 darts,30–75 total '
                 'Force) provide a bounded legitimate death path, with every refusal retained. The final '
                 'opponent move publishes the ordinary post-death prefix. Both original seat journals remain '
                 'independent; source art/scale/geometry/facing/native output and all artwork acceptance remain '
                 'separate.'},
     {'id': 'creature.spell.water_elemental/own_body_native_intrinsics_death',
      'title': 'Water Elemental: real own body, two native intrinsics and ordinary death',
      'kind': 'creature',
      'seed': 2,
      'battlefield': 'battlefield.open_floor_bright',
      'subjects': {'spell': ['spell.magic_missile', 'spell.power_word_kill'],
                   'action': ['action.move',
                              'action.attack',
                              'action.water_elemental.slam',
                              'action.water_elemental.winters_breath',
                              'action.disengage'],
                   'condition': [],
                   'creature': ['creature.spell.water_elemental', 'creature.generic_caster'],
                   'environment_object': [],
                   'spatial_effect': [],
                   'residue': [],
                   'item': []},
      'actors': [{'role': 'caster', 'side': 'amber', 'creature': 'creature.spell.water_elemental', 'at': [3, 6]},
                 {'role': 'target',
                  'side': 'blue',
                  'creature': 'creature.generic_caster',
                  'level': 20,
                  'caster_level': 20,
                  'spells': ['spell.magic_missile', 'spell.power_word_kill'],
                  'at': [4, 5]}],
      'steps': [{'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
                {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.attack',
                 'by': 'caster',
                 'target': 'target',
                 'weapon_slot': 'MELEE_MAIN',
                 'capture_choices': True,
                 'optional': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.water_elemental.slam', 'by': 'caster', 'target': [4, 5], 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'action.water_elemental.winters_breath',
                 'by': 'caster',
                 'target': [4, 5],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'caster'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 5,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.magic_missile',
                 'by': 'target',
                 'target': 'caster',
                 'level': 6,
                 'recipients': ['caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster', 'caster'],
                 'capture_choices': True},
                {'do': 'end_turn', 'by': 'target'},
                {'do': 'spell.power_word_kill',
                 'by': 'target',
                 'target': 'caster',
                 'level': 9,
                 'capture_choices': True},
                {'do': 'action.move', 'by': 'target', 'target': [5, 4]}],
      'required_behaviors': ['action.move',
                             'action.water_elemental.slam',
                             'action.water_elemental.winters_breath',
                             'spell.magic_missile',
                             'spell.power_word_kill',
                             'action.disengage'],
      'required_facts': ['movement', 'attack', 'damage', 'saving_throw', 'life'],
      'purpose': 'The frozen native creature factory intrinsically installs both selected elemental actions and '
                 'its bound natural attack; this setup grants none of those powers. Actual intrinsic Disengage '
                 'prevents an extra opportunity hit; two ordinary moves restore the same real origin before '
                 'actual action choices/Preview. The normal bound Attack is optional only if actual public '
                 'discovery exposes a legal adjacent target; no reach/socket/target is invented (Fire Slam has '
                 'native4ft reach). Both actual intrinsic actions are mandatory and saves/contacts/riders remain '
                 'native outcomes. A real level20 opposing caster then spends actual L5/L6 Magic Missile slots '
                 'on this actor followed by actual L9 Power Word Kill: no initial HP editing, forced hit/save, '
                 'fabricated removal or spell-shaped elemental action. Native elemental max-HP '
                 'bonuses90/126/102/114 with no hit dice and the two real 1d4+1 volleys (15 darts,30–75 total '
                 'Force) provide a bounded legitimate death path, with every refusal retained. The final '
                 'opponent move publishes the ordinary post-death prefix. Both original seat journals remain '
                 'independent; source art/scale/geometry/facing/native output and all artwork acceptance remain '
                 'separate.'}]


def false_life_grant_study():
    """Actual distinct grant ownership and real ordinary damage depletion."""
    return {'id': 'spell.false_life/grant_move_deplete',
     'title': 'False Life: actual grant UUID, movement, depletion and source return',
     'kind': 'spell',
     'seed': 2,
     'battlefield': 'battlefield.open_floor_bright',
     'subjects': {'spell': ['spell.false_life', 'spell.magic_missile'],
                  'action': ['action.move'],
                  'condition': [],
                  'creature': ['creature.generic_caster'],
                  'environment_object': [],
                  'spatial_effect': [],
                  'residue': [],
                  'item': []},
     'actors': [{'role': 'caster',
                 'side': 'amber',
                 'premade': 'sorcerer',
                 'caster_level': 5,
                 'spells': ['spell.false_life'],
                 'at': [3, 7]},
                {'role': 'target',
                 'side': 'blue',
                 'creature': 'creature.generic_caster',
                 'level': 20,
                 'caster_level': 20,
                 'spells': ['spell.magic_missile'],
                 'at': [8, 7]}],
     'steps': [{'do': 'spell.false_life',
                'by': 'caster',
                'target': 'self',
                'level': 1,
                'capture_choices': True},
               {'do': 'action.move', 'by': 'caster', 'target': [3, 11]},
               {'do': 'end_turn', 'by': 'caster'},
               {'do': 'spell.magic_missile',
                'by': 'target',
                'target': 'caster',
                'level': 3,
                'recipients': ['caster', 'caster', 'caster', 'caster', 'caster'],
                'capture_choices': True},
               {'do': 'end_turn', 'by': 'target'},
               {'do': 'action.move', 'by': 'caster', 'target': [3, 14]}],
     'required_behaviors': ['spell.false_life', 'spell.magic_missile', 'action.move'],
     'required_facts': ['temporary_hit_points', 'movement', 'damage'],
     'required_applied_damage_types': ['Force'],
     'required_fact_witnesses': [{'kind': 'temporary_hit_points',
                                  'actor_role': 'caster',
                                  'actor_field': 'entity_uuid',
                                  'field': 'grant',
                                  'when': {'source_id': 'spell.false_life'}}],
     'required_grant_sources': [{'source_id': 'spell.false_life',
                                 'phases': ['application', 'sustain', 'removal'],
                                 'retired': True}],
     'purpose': 'A real level1 False Life cast creates the public temporary_hp_grant; no ConditionRow is '
                'requested or invented. Frozen9f rolls1d4+4 (5–8); opposing real Magic Missile level3 '
                'produces five1d4+1 Force darts (10–25), exhausting that actual pool without forced rolls '
                'or HP edits. The Amber actor is the existing level5 Sorcerer premade, whose real learned '
                'progression has no Shield reaction; the same public RosterSpellGrant supplies False Life '
                'with existing native slots. The opposing native caster20 is unchanged. Native HP/action '
                'budgets are unmodified. Four ordinary5ft steps after application expose held source age; '
                'the final three steps expose the real removal return. Actors begin25ft apart and movement '
                'stays away from melee reach. Driver.turn_of owns actual turns; all native '
                'discovery/Preview refusals stay failures. required_grant_sources is optional replay output '
                'evidence, not injected state or a recorder-generated rendered claim. Both original seat '
                'journals, actual UUID/source/recipient and postdraw lifecycle evidence stay independent; '
                'all artwork remains unreviewed. The preserved first generic-caster attempt autoaccepted '
                'its real Shield and blocked all missiles; it remains a failed original, not a backend '
                'defect or reason to disable reactions.'}


def shield_ranged_lifecycle_study():
    """One fixed Fighter attack exchange; an absent Shield witness stays failed."""
    return {'id': 'spell.shield/ranged_attack_lifecycle',
     'title': 'Shield: real Fighter ranged Attack and Extra Attack, next-turn end and walk',
     'kind': 'spell',
     'seed': 2,
     'subjects': {'spell': ['spell.shield'],
                  'action': ['action.attack', 'action.feature.extra_attack', 'action.move'],
                  'condition': ['condition.spell.shield'],
                  'creature': [],
                  'environment_object': [],
                  'spatial_effect': [],
                  'residue': [],
                  'item': []},
     'actors': [{'role': 'caster', 'side': 'amber', 'premade': 'spellblade', 'at': [4, 6]},
                {'role': 'archer', 'side': 'blue', 'premade': 'fighter', 'at': [9, 6]}],
     'steps': [{'do': 'action.attack',
                'by': 'archer',
                'target': 'caster',
                'weapon_slot': 'RANGED_MAIN',
                'track': True,
                'track_condition': 'condition.spell.shield',
                'capture_choices': True},
               {'do': 'action.feature.extra_attack',
                'by': 'archer',
                'target': 'caster',
                'weapon_slot': 'RANGED_MAIN',
                'track': True,
                'track_condition': 'condition.spell.shield',
                'capture_choices': True},
               {'do': 'end_tracked', 'prefer_turns': True, 'max_turns': 4},
               {'do': 'tail_walk', 'by': 'caster', 'offset': [-1, 0]}],
     'required_behaviors': ['action.attack',
                            'action.feature.extra_attack',
                            'reaction.spell.shield',
                            'action.move'],
     'required_facts': ['attack', 'actor_change', 'movement'],
     'required_conditions': ['condition.spell.shield'],
     'required_condition_ends': ['condition.spell.shield'],
     'purpose': 'One fixed, ordinary level5 Fighter Attack exchange against the original native Spellblade: '
                'offered longbow Attack followed by its earned RANGED_MAIN Extra Attack in the same actual '
                'turn, regardless of either result. The first preserved single-attack original naturally '
                'missed AC18 and remains failed. Original seed2, both actors, native equipment/stats/Shield '
                'source and spell slots are unchanged. A genuine own-UUID ranged Shield interception, '
                'next-turn expiration and restored walk remain required; neither attack is conditional and '
                'there is no repeat-until-outcome, seed search, grant/stat edit or forced roll. If neither '
                'native attack supplies the required reaction, the complete fixed exchange remains a failed '
                'original.'}


def action_dispatch_owner_studies():
    """Real Attack dispatch and retained-quarry reapplication, one legal cohort.

    The commands select no dice result and create no presentation-only facts.
    In particular, the old quarry dies through a different actor's Magic
    Missile while its original caster retains the same concentration owner.
    """
    result = [{
        'id': 'action.monster.shield_bash/native_held_shield_attempts',
        'title': 'Shield Bash: native Gateplate shield and two legal attempts',
        'kind': 'action', 'seed': 2,
        'subjects': subjects(actions=['action.monster.shield_bash']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.enemy_gateplate', 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [4, 7]}],
        'steps': [
            {'do': 'action.monster.shield_bash', 'by': 'caster', 'target': 'target', 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'}, {'do': 'end_turn', 'by': 'target'},
            {'do': 'action.monster.shield_bash', 'by': 'caster', 'target': 'target', 'capture_choices': True}],
        'required_behaviors': ['action.monster.shield_bash'], 'required_facts': ['attack'],
        'purpose': 'Native Gateplate owns the real declared ShieldBash behavior and its actual equipped shield. '
                   'Both AttackFact outcomes remain the native rolled outcomes; no Hit/Miss or contact is fabricated.'}, {
        'id': 'spell.spiritual_weapon/autonomous_strike_attempts',
        'title': 'Spiritual Weapon: summon and actual autonomous initiative attempts',
        'kind': 'spell', 'seed': 2,
        'subjects': subjects(['spell.spiritual_weapon'], ['action.spell.spiritual_weapon.strike']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.spiritual_weapon'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.knight', 'at': [6, 7]}],
        'steps': [
            {'do': 'spell.spiritual_weapon', 'by': 'caster', 'target': [5, 7], 'level': 2, 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'}, {'do': 'end_turn', 'by': 'target'},
            {'do': 'end_turn', 'by': 'caster'}, {'do': 'end_turn', 'by': 'target'}],
        'required_behaviors': ['spell.spiritual_weapon', 'action.spell.spiritual_weapon.strike'],
        'required_facts': ['attack'],
        'purpose': 'Only real initiative/AI controls the spawned autonomous effect-body creature. '
                   'No caster-owned sprite swing, synthetic strike, chosen dice result or manual summoned-actor command is inserted.'}]
    for name in ('hex', 'hunters_mark'):
        spell = 'spell.' + name
        action = 'action.spell.' + name + '.reapply'
        result.append({
            'id': spell + '/retained_root_quarry_reapply',
            'title': name.replace('_', ' ').title() + ': original sustain, real defeat and new quarry',
            'kind': 'spell', 'seed': 2,
            'subjects': subjects([spell, 'spell.magic_missile'], [action, 'action.drop_concentration'],
                                 ['condition.concentrating', spell.replace('spell.', 'condition.spell.') + '.quarry']),
            'actors': [
                {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
                 'level': 20, 'caster_level': 20, 'spells': [spell], 'at': [3, 7]},
                {'role': 'ally', 'side': 'amber', 'creature': 'creature.generic_caster',
                 'level': 20, 'caster_level': 20, 'spells': ['spell.magic_missile'], 'at': [3, 8]},
                {'role': 'target', 'side': 'blue', 'creature': 'creature.goblin', 'damage': 6, 'at': [4, 7]},
                {'role': 'second_target', 'side': 'blue', 'creature': 'creature.knight', 'at': [5, 7]}],
            'steps': [
                {'do': spell, 'by': 'caster', 'target': 'target', 'level': 1, 'capture_choices': True},
                {'do': 'spell.magic_missile', 'by': 'ally', 'target': 'target',
                 'recipients': ['target', 'second_target', 'second_target'], 'level': 1},
                {'do': action, 'by': 'caster', 'target': 'second_target', 'capture_choices': True},
                {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
                {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'}],
            'required_behaviors': [spell, 'spell.magic_missile', action, 'action.drop_concentration'],
            'required_conditions': ['condition.concentrating', spell.replace('spell.', 'condition.spell.') + '.quarry'],
            'required_condition_ends': ['condition.concentrating'],
            'required_facts': ['damage'],
            'purpose': 'A real separate allied caster defeats the wounded original quarry without replacing '
                       'the original marker concentration. The legal reapply action creates only the new '
                       'recipient member; the original sustain UUID/age must be retained. Source packets, '
                       'publication cuts, retirement and any failed legal admission remain unchanged.'})
    return result


def myrmidon_body_lifecycle_studies():
    """Four native equipped families; source setup grants none of their actions."""
    specs = (
        ('air', 'electrified_flail', [('raging_vortex', [3, 11])]),
        ('earth', 'grounded_thunder', [('sludgy_sling', [3, 6]), ('burrow', [2, 6]), ('muck_to_metal', 'self')]),
        ('fire', 'scorching_strike', [('cinderous_swipe', [4, 5]), ('immolation', 'self')]),
        ('water', 'hiemal_strike', [('explosive_icicle', [4, 5]), ('healing_vapours', [3, 6])]),
    )
    result = []
    for element, strike, techniques in specs:
        creature = 'creature.spell.' + element + '_myrmidon'
        prefix = 'action.' + element + '_myrmidon.'
        strike = prefix + strike
        spells = ['spell.magic_missile', 'spell.power_word_kill']
        actions = ['action.disengage', 'action.move', 'action.attack', strike]
        actions += [prefix + name for name, _ in techniques]
        if element == 'earth':
            actions.append(prefix + 'landing')
        inventory = subjects(spells, actions)
        inventory['creature'] = [creature, 'creature.generic_caster']
        steps = [
            {'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
            {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
            {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'spell.magic_missile', 'by': 'cleaner', 'target': 'caster', 'level': 1,
             'recipients': ['caster'] * 3, 'capture_choices': True},
            {'do': 'end_turn', 'by': 'cleaner'},
            {'do': 'action.attack', 'by': 'caster', 'target': 'target', 'weapon_slot': 'MELEE_MAIN',
             'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': strike, 'by': 'caster', 'target': 'second_target', 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
        ]
        for name, target in techniques:
            steps += [{'do': prefix + name, 'by': 'caster', 'target': target, 'capture_choices': True},
                      {'do': 'end_turn', 'by': 'caster'}]
        for level in (5, 6):
            steps += [{'do': 'spell.magic_missile', 'by': 'cleaner', 'target': 'caster', 'level': level,
                       'recipients': ['caster'] * (level + 2), 'capture_choices': True},
                      {'do': 'end_turn', 'by': 'cleaner'}]
        steps += [
            {'do': 'spell.power_word_kill', 'by': 'cleaner', 'target': 'caster', 'level': 9,
             'capture_choices': True},
            {'do': 'action.move', 'by': 'cleaner', 'target': [10, 5]},
        ]
        result.append({
            'id': creature + '/equipped_body_native_intrinsics_death',
            'title': element.title() + ' Myrmidon: own equipped body, native techniques, hurt and death',
            'kind': 'creature', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
            'subjects': inventory,
            'actors': [
                {'role': 'caster', 'side': 'amber', 'creature': creature, 'at': [3, 6]},
                {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster', 'level': 20, 'at': [4, 5]},
                {'role': 'second_target', 'side': 'blue', 'creature': 'creature.generic_caster', 'level': 20, 'at': [4, 7]},
                {'role': 'cleaner', 'side': 'blue', 'creature': 'creature.generic_caster',
                 'level': 20, 'caster_level': 20, 'spells': spells, 'at': [10, 6]},
            ],
            'steps': steps,
            'required_behaviors': actions + spells,
            'required_facts': ['movement', 'attack', 'damage', 'life'],
            'purpose': 'The actual creature factory supplies this own equipped family and every intrinsic. '
                       'Disengage and two real moves precede a genuine incoming Magic Missile hurt, the actual '
                       'bound main-hand attack, the exact strike and each native technique. Separate real '
                       'recipients keep attack roles distinct; both owner and cleanup caster stand outside the chosen '
                       'Vortex. Water heals only after actual injury. Earth Burrow keeps its native PortalTransfer '
                       'and Landing child. Actual fixed L5/L6 volleys then L9 Power Word Kill provide an ordinary '
                       'death path from native max HP117/127/123/127; no HP, hit, save, rider, item or clock '
                       'is fabricated. Both factions retain original packets and any legal-admission failure. '
                       'Native body output, gameplay scale, light/shadow acceptance and human art/audio review '
                       'remain separate from capture.'})
    return result


def arcane_sword_granted_lifecycle_study():
    """Actual initial declaration, granted command/repeats and owner retirement."""
    return {
        'id': 'spell.arcane_sword/independent_anchor_move_repeat_end',
        'title': 'Arcane Sword: actual independent anchor, move, two repeats and retirement',
        'kind': 'spell', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
        'subjects': subjects(['spell.arcane_sword'], ['action.spell.arcane_sword.move',
            'action.spell.arcane_sword.strike', 'action.drop_concentration']),
        'actors': [
            {'role': 'caster', 'side': 'amber', 'creature': 'creature.generic_caster',
             'level': 20, 'caster_level': 20, 'spells': ['spell.arcane_sword'], 'at': [3, 7]},
            {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster', 'level': 20, 'at': [6, 7]},
        ],
        'steps': [
            {'do': 'spell.arcane_sword', 'by': 'caster', 'target': 'target', 'then': [5, 7], 'level': 7, 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.spell.arcane_sword.strike', 'by': 'caster', 'target': 'target', 'then': [5, 7], 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.spell.arcane_sword.move', 'by': 'caster', 'target': [5, 6], 'capture_choices': True},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'action.spell.arcane_sword.strike', 'by': 'caster', 'target': 'target', 'then': [5, 6], 'capture_choices': True},
            {'do': 'action.drop_concentration', 'by': 'caster', 'target': 'self'},
        ],
        'required_behaviors': ['spell.arcane_sword', 'action.spell.arcane_sword.move',
            'action.spell.arcane_sword.strike', 'action.drop_concentration'],
        'required_conditions': ['condition.concentrating', 'condition.spell.arcane_sword'],
        'required_condition_ends': ['condition.concentrating', 'condition.spell.arcane_sword'],
        'purpose': 'One real caster chooses an independent initial point and actual later granted Move. '
                   'Two predetermined repeat attempts use ordinary separate turns and unchosen native results. '
                   'The ordinary level20 Generic Caster retains native160HP/equipment and can survive the first two '
                   'maximum critical sword results; no attack, save, HP, grant or coordinate is manufactured. '
                   'Original public fact kind, accepted source/target coordinates, condition UUIDs, outcomes '
                   'and retirement are preserved. The recorded command points are evidence of offered choices '
                   'and omissions only, never rendering operands. Missing actual public anchor remains a gap.'}



def provisional_creature_body_studies():
    """Four native roster families; no grants, edited stats or selected outcomes.

    These originals can qualify current substitute-body decisions. They do not
    activate selected native dragon banks or supply authentic mouth geometry.
    The one Cambion Charm Person prerequisite remains a real save: a refusal
    is preserved, never retried with another seed or forced condition.
    """
    specs = (
        ('cambion', 'action.cambion.draining_kiss', [], ()),
        ('deva', 'action.deva.concussive_smash', [('action.attack', 'target')], (5, 6)),
        ('djinni', 'action.djinni.sweetplum_gales', [('action.attack', 'target')], (5, 6, 7, 2)),
        ('draconic_spirit', 'action.draconic_spirit.breath', [('action.attack', 'target')], ()),
    )
    result = []
    for form, intrinsic, earlier, cleanup_levels in specs:
        creature = 'creature.spell.' + form
        spells = ['spell.magic_missile', 'spell.power_word_kill']
        actions = ['action.disengage', 'action.move', intrinsic]
        actions += [identity for identity, _ in earlier]
        if form == 'cambion':
            spells += ['spell.charm_person']
        inventory = subjects(spells, actions)
        inventory['creature'] = [creature, 'creature.generic_caster']
        if form == 'djinni':
            inventory['spatial_effect'] = ['spatial_effect.summon.sweetplum_gales']
        steps = [
            {'do': 'action.disengage', 'by': 'caster', 'target': 'self', 'capture_choices': True},
            {'do': 'action.move', 'by': 'caster', 'target': [2, 6]},
            {'do': 'action.move', 'by': 'caster', 'target': [3, 6]},
            {'do': 'end_turn', 'by': 'caster'},
            {'do': 'spell.magic_missile', 'by': 'cleaner', 'target': 'caster', 'level': 1,
             'recipients': ['caster'] * 3, 'capture_choices': True},
            {'do': 'end_turn', 'by': 'cleaner'},
        ]
        for identity, recipient in earlier:
            steps += [{'do': identity, 'by': 'caster', 'target': recipient,
                       'weapon_slot': 'MELEE_MAIN', 'capture_choices': True},
                      {'do': 'end_turn', 'by': 'caster'}]
        if form == 'cambion':
            steps += [{'do': 'spell.charm_person', 'by': 'caster', 'target': 'target', 'capture_choices': True},
                      {'do': 'end_turn', 'by': 'caster'}]
        target = [4, 5] if form in ('djinni', 'draconic_spirit') else 'target'
        steps += [{'do': intrinsic, 'by': 'caster', 'target': target, 'capture_choices': True},
                  {'do': 'end_turn', 'by': 'caster'}]
        for level in cleanup_levels:
            steps += [{'do': 'spell.magic_missile', 'by': 'cleaner', 'target': 'caster', 'level': level,
                       'recipients': ['caster'] * (level + 2), 'capture_choices': True},
                      {'do': 'end_turn', 'by': 'cleaner'}]
        steps += [{'do': 'spell.power_word_kill', 'by': 'cleaner', 'target': 'caster', 'level': 9,
                   'capture_choices': True},
                  {'do': 'action.move', 'by': 'cleaner', 'target': [10, 5]}]
        caster = {'role': 'caster', 'side': 'amber', 'creature': creature, 'at': [3, 6]}
        target_actor = {'role': 'target', 'side': 'blue', 'creature': 'creature.generic_caster',
                        'level': 20, 'at': [4, 5]}
        required_facts = ['movement', 'damage', 'life']
        if earlier:
            required_facts += ['attack']
        scenario = {
            'id': creature + '/current_stand_in_intrinsic_retirement',
            'title': form.replace('_', ' ').title() + ': current substitute, real intrinsic and retirement',
            'kind': 'creature', 'seed': 2, 'battlefield': 'battlefield.open_floor_bright',
            'subjects': inventory,
            'actors': [caster, target_actor,
                {'role': 'cleaner', 'side': 'blue', 'creature': 'creature.generic_caster',
                 'level': 20, 'caster_level': 20, 'spells': ['spell.magic_missile', 'spell.power_word_kill'],
                 'at': [10, 6]}],
            'steps': steps,
            'required_behaviors': actions + spells,
            'required_facts': required_facts,
            'purpose': 'Existing native roster factory supplies the actual family, equipped/natural weapon, '
                       'intrinsic actions, spellcasting and unedited creature HP. No action/condition grant, '
                       'private position, selected save/Hit/Crit or source timing is inserted. Real movement '
                       'and L1 injury precede the intrinsic; fixed real missile slots then ordinary Power Word '
                       'Kill provide retirement from pinned native HP82/136/161/20. Actual failures and both '
                       'seat journals are retained. The current substitute-body gesture is separate from '
                       'authentic final artwork, optical mouth, native grounded/airborne bank activation, '
                       'receiving/output qualification and all human art/audio review.'}
        scenario['purpose'] += {
            'cambion': ' The actual Humanoid Generic Caster recipient has native160HP; Charm Person chooses a real save, and Kiss maximum55 cannot defeat it before its completed consequence.',
            'deva': ' The actual Generic Caster recipient has native160HP; the first bound-Mace maximum critical is80 (2d6+8d8+4), so the later intrinsic remains legal. That second actual attack may naturally defeat the recipient.',
            'djinni': ' The actual Generic Caster recipient has native160HP; the first bound-Scimitar maximum critical is58 (2d6+4d10+6), so the later Gales still has its real recipient.',
            'draconic_spirit': ' The actual Generic Caster recipient has native160HP; default Rend maximum critical is18 (2d6+6), so the paid Breath still has its real recipient.'}[form]
        if form == 'cambion':
            scenario['required_conditions'] = ['condition.charmed']
            scenario['required_condition_ends'] = ['condition.charmed']
        result.append(scenario)
    return result
