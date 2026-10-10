"""Readable destinations for the agreed asset copies; preserve source subfolders."""
from pathlib import Path

from vfx_layout import ordinary_path
from environment_layout import environment_media_path


def named_path(family, row):
    if family == 'character-assets':
        member = row['member'].lstrip('/')
        if row['family'] == 'A':
            member = member.split('StreamingAssets/Spritesheets/', 1)[1]
            return Path('smallscale/modular') / member
        pack_names = {
            'animals': 'animals', 'barbarian': 'barbarians', 'character': 'characters',
            'enemy': 'enemies', 'undead': 'undead', 'hdz': 'zombies-hd',
            'top': 'zombies-top-down', 'orcs_goblins': 'orcs-and-goblins',
            'demons': 'demons', 'dinosaurs': 'dinosaurs',
        }
        if '/Spritesheets/' in member:
            member = member.split('/Spritesheets/', 1)[1]
        else:
            member = member.removeprefix('Spritesheets/')
        member = member.removeprefix('2D Orcs and Goblins - TopDown - V1.0/')
        return Path('smallscale/authored') / pack_names[row['pack']] / member
    if family == 'environment-assets':
        return environment_media_path(row['source'])
    if family == 'ui-assets':
        if row['role'] == 'smooth48':
            return Path('ui/icons/smooth48') / (row['key'] + '.png')
        if row['role'] == 'preview':
            return Path('ui/portraits/192x256') / row['bank'] / (row['key'] + '.png')
        raise ValueError('Unselected UI role: ' + row['role'])
    if family == 'vfx-assets':
        return ordinary_path(row)
    raise ValueError('Unknown asset family: ' + family)


def write_asset(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.copying')
    temporary.write_bytes(data)
    temporary.replace(path)
