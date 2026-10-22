"""One owned recording process. Its parent selects the frozen engine environment."""
import argparse
import asyncio
import json
import os
from pathlib import Path

import adapter
from fear_witness import fear_extension_evidence
from field_witnesses import field_lifecycle_evidence, nimbus_contact_evidence
from prone_witness import prone_standing_evidence
from shield_witness import shield_lifecycle_evidence
from survival_witnesses import shove_lifecycle_evidence, stabilization_evidence


def initial_mechanism_evidence(out, perspectives, fixtures):
    """Read real per-seat initialization joins, never the setup's private owners."""
    rows, missing = [], []
    for faction in perspectives:
        packet = adapter.InitializationResponse.model_validate_json(
            (out/faction/'journal'/('0'*16+'.json')).read_bytes())
        state = adapter.reduce_initialization(packet.initialization, content_additions=packet.content_additions)
        if state.senses is None:
            missing.append(faction+': no current sensory disclosure')
            continue
        for fixture in fixtures:
            owners = [(identity, effect) for identity, effect in state.senses.spatial_effects.items()
                if effect.content_ref.content_id == fixture['content_id']
                and tuple(fixture['at']) in effect.positions]
            evidence = {'faction': faction, 'fixture': fixture['id'], 'content_id': fixture['content_id']}
            if len(owners) != 1:
                missing.append(faction+'/'+fixture['id']+': expected one current observed native owner')
            else:
                identity, effect = owners[0]
                body = state.objects.get(effect.anchor_item_uuid)
                observed = state.senses.objects.get(effect.anchor_item_uuid)
                evidence.update(spatial_effect_uuid=str(identity),
                    anchor_item_uuid=str(effect.anchor_item_uuid) if effect.anchor_item_uuid else None,
                    apparent_presence=effect.apparent_presence)
                if body is None or observed is None or not observed.visual or body.item.item_id != fixture['item_id']:
                    missing.append(faction+'/'+fixture['id']+': missing exact current hardware anchor')
                else:
                    evidence['item_id'] = body.item.item_id
            rows.append(evidence)
    return rows, missing


def fact_witness_evidence(out, perspective, scenario):
    """Exact completed public fact fields, never a reconstructed passive result."""
    requirements = scenario.get('required_fact_witnesses', ())
    if not requirements:
        return [], []
    journal = out/perspective/'journal'
    packet = adapter.InitializationResponse.model_validate_json((journal/('0'*16+'.json')).read_bytes())
    state = adapter.reduce_initialization(packet.initialization, content_additions=packet.content_additions)
    names = {actor['role']: adapter.actor_name(actor['side'], actor['role']) for actor in scenario['actors']}
    records = list(adapter.facts(journal))
    evidence, missing = [], []
    for requirement in requirements:
        role = requirement['actor_role']
        actors = [str(identity) for identity, actor in state.actors.items() if actor.name == names[role]]
        observed, matched = [], []
        for sequence, lineage, offset, node in records:
            fact = node['fact']
            if node.get('phase') != 'completion' or fact.get('kind') != requirement['kind']:
                continue
            if 'stage' in requirement and fact.get('stage') != requirement['stage']:
                continue
            if 'behavior_id' in requirement and fact.get('behavior_id') != requirement['behavior_id']:
                continue
            if len(actors) != 1 or str(fact.get(requirement['actor_field'])) != actors[0]:
                continue
            if not all(key in fact and fact[key] == value
                       for key, value in requirement.get('where', {}).items()):
                continue
            witness = fact.get(requirement['field'])
            if witness is None:
                continue
            row = {'sequence': sequence, 'lineage': lineage, 'occurrence': node['occurrence'],
                'event_offset': offset, 'actor_uuid': actors[0], 'actor_field': requirement['actor_field'], 'kind': fact['kind'],
                'stage': fact.get('stage'), 'field': requirement['field'], 'value': witness}
            observed.append(row)
            if 'equals' in requirement:
                matches = witness == requirement['equals']
            else:
                matches = all(witness.get(key) == value for key, value in requirement['when'].items())
            if matches:
                matched.append(row)
        evidence.append({'requirement': requirement, 'perspective': perspective, 'actor_uuids': actors, 'observed': observed, 'matched': matched})
        if not matched:
            missing.append(requirement['kind']+'.'+requirement['field']+' for '+role+' has no exact required completed witness')
    return evidence, missing


async def record(args):
    scenario=json.loads(args.scenario.read_text())
    args.out.mkdir(parents=True, exist_ok=True)
    config=adapter.configuration(scenario, scenario.get('seed',2), args.out)
    async def drive(url):
        return await adapter.drive(config,url,args.out,scenario['steps'],scenario)
    result=await adapter.hosted(args.engine,config,args.out,drive,timeout=args.timeout,
                               initial_mechanisms=scenario.get('initial_mechanisms',()))
    perspectives=[credential.seat_id for credential in config.credentials]
    missing_initializations=[perspective for perspective in perspectives
        if not (args.out/perspective/'journal'/('0'*16+'.json')).is_file()]
    if missing_initializations and not result['ok']:
        # A failed setup/connection may never publish initialization. Keep its
        # actual failure and partial originals instead of masking it in a reader.
        if not result.get('failure'):
            result['failure']='; '.join(str(row['reason']) for row in result.get('gaps',[]))
        result.update(missing_initializations=missing_initializations, perspectives=perspectives,
            engine=adapter.engine_identity(args.engine),
            sdk=json.loads(os.environ.get('NDCLIENT_STUDIO_SDK_PROVENANCE','{}')))
        (args.out/'recording.json').write_text(json.dumps(result,indent=1,default=str)+'\n')
        return result
    if scenario.get('initial_mechanisms'):
        anchors, missing_anchors = initial_mechanism_evidence(args.out, perspectives, scenario['initial_mechanisms'])
        result['initial_mechanisms'] = anchors
        if missing_anchors and result['ok']:
            result.update(ok=False, failure='; '.join(missing_anchors))
    summary=adapter.journal_summary(args.out/perspectives[0]/'journal')
    missing=set(scenario.get('required_behaviors',()))-summary['behaviors'].keys()
    if missing and result['ok']:
        result['ok']=False
        result['failure']='Required actual spell/action occurrence absent: '+', '.join(sorted(missing))
    for field,observed in (('required_facts',summary['facts']),('required_conditions',summary['conditions']),('required_condition_ends',summary['ended_conditions']),('required_item_effects',summary['item_effects']),('required_item_effect_ends',summary['ended_item_effects'])):
        missing=set(scenario.get(field,()))-set(observed)
        if missing and result['ok']:
            result.update(ok=False,failure=field+' absent from actual journal: '+', '.join(sorted(missing)))
    if not result['ok'] and not result.get('failure'):
        result['failure']='; '.join(str(row['reason']) for row in result.get('gaps',[]))
    positive_damage_types=summary['positive_applied_damage_types']
    missing=set(scenario.get('required_applied_damage_types',()))-set(positive_damage_types)
    if missing and result['ok']:
        result.update(ok=False,failure='Required positive applied damage types absent: '+', '.join(sorted(missing)))
    witnesses, missing_witnesses = [], []
    witness_groups = {}
    for requirement in scenario.get('required_fact_witnesses', ()):
        perspective = requirement.get('perspective', perspectives[0])
        if perspective not in perspectives:
            error = 'Required fact witness perspective '+repr(perspective)+' was not published: '+', '.join(perspectives)
            witnesses.append({'requirement': requirement, 'perspective': perspective,
                'actor_uuids': [], 'observed': [], 'matched': [], 'error': error})
            missing_witnesses.append(error)
            continue
        witness_groups.setdefault(perspective, []).append(requirement)
    for perspective, requirements in witness_groups.items():
        observed, missing = fact_witness_evidence(args.out, perspective,
            {**scenario, 'required_fact_witnesses': requirements})
        witnesses.extend(observed)
        missing_witnesses.extend(missing)
    result['fact_witnesses'] = witnesses
    if missing_witnesses and result['ok']:
        result.update(ok=False, failure='; '.join(missing_witnesses))
    if scenario.get('require_nimbus_contact'):
        result['nimbus_contact'], missing = nimbus_contact_evidence(args.out, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    if scenario.get('required_field_lifecycle'):
        result['field_lifecycle'], missing = field_lifecycle_evidence(args.out, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    if scenario.get('required_survival_lifecycle'):
        check = shove_lifecycle_evidence if scenario['required_survival_lifecycle'] == 'shove' else stabilization_evidence
        result['survival_lifecycle'], missing = check(args.out, perspectives, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    if scenario.get('require_shield_lifecycle'):
        result['shield_lifecycle'], missing = shield_lifecycle_evidence(args.out, perspectives, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    if scenario.get('require_prone_standing'):
        result['prone_standing'], missing = prone_standing_evidence(args.out, perspectives, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    if scenario.get('require_fear_extension'):
        result['fear_extension'], missing = fear_extension_evidence(args.out, perspectives, scenario)
        if missing and result['ok']:
            result.update(ok=False, failure='; '.join(missing))
    moments=[]
    for faction in perspectives:
        moments.extend(dict(row,faction=faction) for row in adapter.moments(args.out/faction/'journal'))
    result.update(summary=summary, moments=moments, perspectives=perspectives, positive_applied_damage_types=positive_damage_types, engine=adapter.engine_identity(args.engine),
                  sdk=json.loads(os.environ.get('NDCLIENT_STUDIO_SDK_PROVENANCE','{}')))
    (args.out/'recording.json').write_text(json.dumps(result,indent=1,default=str)+'\n')
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,required=True)
    parser.add_argument('--scenario',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--timeout',type=int,default=240)
    args=parser.parse_args()
    try:
        result=asyncio.run(asyncio.wait_for(record(args),args.timeout))
    except Exception as error:
        result={'ok':False,'failure':f'{type(error).__name__}: {error}',
                'sdk':json.loads(os.environ.get('NDCLIENT_STUDIO_SDK_PROVENANCE','{}'))}
        args.out.mkdir(parents=True,exist_ok=True)
        (args.out/'recording.json').write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps({'ok':result['ok'],'reason':result.get('failure'),'out':str(args.out)}),flush=True)
    raise SystemExit(0 if result['ok'] else 1)


if __name__=='__main__':main()
