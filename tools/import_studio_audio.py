"""Install the finite licensed temporary audio selection.

Sources/clip members are reviewed data in authoring/audio/sources.json. Only
selected original bytes enter ignored assets/audio; downloaded packs stay local.
Requires ffprobe and ffmpeg for actual stream metadata and complete decoding.
Selected FLACs may be wrapped in PCM WAV with identical decoded samples for the
native loader. A 7z source uses tar/libarchive, available in native Windows.
"""
import argparse
from array import array
from io import BytesIO
import json
from pathlib import Path
import subprocess
from urllib.request import urlretrieve
import wave
from zipfile import ZipFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--archive-extractor', default='tar', help='tar/libarchive for selected 7z members')
    args = parser.parse_args()
    root = args.project.resolve()
    manifest = json.loads((root/'authoring/audio/sources.json').read_text())
    cache = root/'.runtime/audio-intake'; cache.mkdir(parents=True, exist_ok=True)
    rows = {}
    waveforms = {}
    archives = {}
    for key, source in manifest['sources'].items():
        path = cache/(key+Path(source['download']).suffix)
        if not path.exists(): urlretrieve(source['download'], path)
        archives[key] = path
        if source.get('license_member'):
            with ZipFile(path) as archive:
                license_text = archive.read(source['license_member']).decode('utf-8-sig')
            if 'CC0' not in license_text: raise ValueError('Expected source license missing: '+key)
            license_dir = root/'authoring/audio/licenses'; license_dir.mkdir(exist_ok=True)
            (license_dir/(key+'.txt')).write_text(license_text)
    for key, clip in manifest['clips'].items():
        target = root/clip['path'].removeprefix('res://')
        if not target.is_relative_to(root/'assets/audio'): raise ValueError('Audio destination escaped selection')
        source = archives[clip['source']]
        if 'member' in clip:
            if source.suffix=='.zip':
                with ZipFile(source) as archive: data = archive.read(clip['member'])
            else:
                data=subprocess.check_output([args.archive_extractor,'-xOf',source.name,clip['member']],cwd=cache)
        else: data = source.read_bytes()
        pcm_equal=False
        if clip.get('pcm_wav'):
            codec=clip['pcm_wav']
            if codec not in ['pcm_s16le','pcm_s24le']: raise ValueError('Unsupported PCM wrapper: '+key)
            original_data=data
            source_info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=sample_rate,channels','-of','json','pipe:0'],input=data))['streams'][0]
            raw=subprocess.check_output(['ffmpeg','-v','error','-nostdin','-i','pipe:0','-c:a',codec,'-f','s24le' if codec=='pcm_s24le' else 's16le','pipe:1'],input=data)
            # Classic PCM header: native load_from_file rejects WAVE_EXTENSIBLE.
            buffer=BytesIO()
            with wave.open(buffer,'wb') as wrapped_file:
                wrapped_file.setnchannels(int(source_info['channels']))
                wrapped_file.setsampwidth(3 if codec=='pcm_s24le' else 2)
                wrapped_file.setframerate(int(source_info['sample_rate']))
                wrapped_file.writeframes(raw)
            data=buffer.getvalue()
            if len(data)%2:
                data+=b'\0'
                data=data[:4]+(len(data)-8).to_bytes(4,'little')+data[8:]
            original=subprocess.check_output(['ffmpeg','-v','error','-nostdin','-i','pipe:0','-f','f32le','-'],input=original_data)
            wrapped=subprocess.check_output(['ffmpeg','-v','error','-nostdin','-i','pipe:0','-f','f32le','-'],input=data)
            if original!=wrapped: raise ValueError('PCM wrapper changes source samples: '+key)
            pcm_equal=True
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes()!=data: raise ValueError('Existing selected audio differs: '+str(target))
        target.write_bytes(data)
        info = json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries',
            'format=duration:stream=codec_name,sample_rate,channels','-of','json',str(target)],text=True))
        duration = float(info['format']['duration'])
        if duration<=0 or not info['streams']: raise ValueError('Empty audio: '+key)
        decoded=subprocess.check_output(['ffmpeg','-v','error','-nostdin','-i',str(target),'-f','f32le','-acodec','pcm_f32le','-'])
        samples=array('f');samples.frombytes(decoded)
        # Max absolute decoded channel amplitude per interval; keep the source
        # channel count/rate, and never rewrite/resample the original asset.
        bins=128
        peaks=[round(max((abs(value) for value in samples[i*len(samples)//bins:(i+1)*len(samples)//bins]),default=0),6) for i in range(bins)]
        waveforms[clip['path']]={'duration_s':duration,'peaks':peaks,'channels':int(info['streams'][0]['channels']),
            'sample_rate':int(info['streams'][0]['sample_rate']),'channel_sample_count':len(samples),'method':'maximum_absolute_original_channel_pcm_per_interval'}
        rows[key] = {'path':clip['path'],'bytes':len(data),'duration_seconds':duration,
            'stream':info['streams'][0],'source':clip['source'],'original_bytes':not pcm_equal,'pcm_equal_to_source':pcm_equal,'complete_decode':True}
    cues = json.loads((root/'authoring/audio/cues.json').read_text())
    by_path = {row['path']:row for row in rows.values()}
    for key, cue in cues['cues'].items():
        if len(cue['clips'])!=len(cue['clip_durations_s']): raise ValueError('Missing per-clip duration: '+key)
        for path, duration in zip(cue['clips'],cue['clip_durations_s']):
            if path not in by_path or duration!=by_path[path]['duration_seconds']:
                raise ValueError('Cue differs from original stream metadata: '+key)
        if cue['loop'] and not 0<=cue['loop_start_s']<cue['loop_end_s']<=min(cue['clip_durations_s']):
            raise ValueError('Loop interval outside source: '+key)
    report = {'clips':rows,'total_bytes':sum(row['bytes'] for row in rows.values()),
        'cues':len(cues['cues']),'missing_cues':cues['missing_cues'],
        'scope':'Original selected audio or explicitly declared lossless PCM WAV wrappers, complete decoding and cue-duration validation; no resampling, synthesized tones, loudness processing or runtime playback claim.'}
    output = root/'generated/studio_audio_intake.json'
    output.write_text(json.dumps(report,indent=2)+'\n')
    (root/'authoring/audio/waveforms.json').write_text(json.dumps({'clips':waveforms},indent=2)+'\n')
    print(json.dumps({'clips':len(rows),'bytes':report['total_bytes'],'report':str(output)}))


if __name__=='__main__': main()
