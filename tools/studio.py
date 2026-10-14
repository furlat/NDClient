"""Open the offline Studio on an existing real SDK journal; never starts a server."""
import argparse
from pathlib import Path
import subprocess


def windows(path: Path) -> str:
    return subprocess.check_output(['wslpath','-w',str(path.resolve())],text=True).strip()


def main():
    project=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recording',type=Path,required=True)
    parser.add_argument('--godot',type=Path,default=project.parent/'Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')
    parser.add_argument('--size',choices=['1280x720','1280x800','1920x1080'],default='1280x720')
    args=parser.parse_args()
    if not (args.recording/'0000000000000000.json').is_file():parser.error('Recording must contain the original initialization packet')
    command=[str(args.godot),'--path',windows(project),'--resolution',args.size,'res://studio.tscn','--','--recording='+windows(args.recording)]
    raise SystemExit(subprocess.call(command,cwd=project))


if __name__=='__main__':main()
