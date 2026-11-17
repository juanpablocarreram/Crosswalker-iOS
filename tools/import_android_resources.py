"""Import the pinned experiment/nuevos-assets resources, with auditable hashes."""
from pathlib import Path
import subprocess, shutil, json, zipfile, wave, struct, math, os
from android_reference import ROOT, COMMIT, BRANCH, REPOSITORY, prepare, sha
source=prepare(); game=source/'assets/game'; resources=ROOT/'Crosswalker/Resources'
manifest=[]
def record(original,target,kind):
    manifest.append({'source':str(original.relative_to(source)),'target':str(target.relative_to(ROOT)),'kind':kind,'sourceSHA256':sha(original),'targetSHA256':sha(target)})
for image in sorted((game/'res/drawable-nodpi').iterdir()):
    if image.suffix not in {'.png','.webp'}: continue
    dest=ROOT/'Crosswalker/Assets.xcassets'/(image.stem+'.imageset');dest.mkdir(exist_ok=True)
    target=dest/(image.stem+'.png')
    if image.suffix=='.png': shutil.copyfile(image,target)
    else: subprocess.run(['sips','-s','format','png',str(image),'--out',str(target)],check=True,capture_output=True)
    (dest/'Contents.json').write_text(json.dumps({'images':[{'filename':target.name,'idiom':'universal'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
    record(image,target,'image')
for original in sorted((game/'res/font').glob('*.ttf'))+sorted((game/'files/licenses').iterdir())+[game/'files/campaign.json']:
    if not original.is_file(): continue
    target=resources/original.name;shutil.copyfile(original,target);record(original,target,'copy')
shutil.copyfile(game/'files/campaign.json',ROOT/'CrosswalkerTests/Fixtures/campaign.json')
# Use an installed FFmpeg executable; Android Studio's bundled distribution is a fallback.
ffmpeg=shutil.which('ffmpeg')
if not ffmpeg:
    jar=Path('/Applications/Android Studio.app/Contents/plugins/android/lib/ffmpeg-7.1.1-1.5.12-macosx-arm64.jar')
    tools=ROOT/'.reference-build/audio';tools.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(jar) as archive:
        for entry in archive.namelist():
            if '/macosx-arm64/' in entry and not entry.endswith('/'):
                out=tools/Path(entry).name;out.write_bytes(archive.read(entry));out.chmod(0o755)
    ffmpeg=str(tools/'ffmpeg')
for original in sorted((game/'res/raw').iterdir()):
    target=resources/(original.stem+'.wav' if original.suffix=='.ogg' else original.name)
    if original.suffix=='.ogg':
        subprocess.run([ffmpeg,'-v','error','-y','-i',str(original),'-c:a','pcm_s16le',str(target)],check=True)
        # Compare independently decoded PCM, preserving source sample rate/channel count.
        pcm=lambda p: subprocess.check_output([ffmpeg,'-v','error','-i',str(p),'-f','s16le','-c:a','pcm_s16le','-'])
        assert pcm(original)==pcm(target),original
    else: shutil.copyfile(original,target)
    record(original,target,'ogg-to-lossless-pcm' if original.suffix=='.ogg' else 'copy')
# ToneGenerator ACK, and per-speaker DTMF voices retained by Dialogue.kt.
for name,freqs,duration,sounding in [('ack',(1200,),180,100)]+[(f'blip_{i}',freqs,18,18) for i,freqs in enumerate([(697,1209),(770,1209),(852,1209),(852,1477),(941,1336),(770,1336)])]:
    rate=48000
    with wave.open(str(resources/(name+'.wav')),'wb') as wav:
        wav.setparams((1,2,rate,0,'NONE','not compressed'))
        wav.writeframes(b''.join(struct.pack('<h',round(32767*0.35*sum(math.sin(2*math.pi*f*i/rate) for f in freqs)/len(freqs))) if i < rate*sounding//1000 else b'\x00\x00' for i in range(rate*duration//1000)))
engine=source/'app/src/main/java/com/example/crosswalker/game/Simulation.kt'
provenance={'repository':REPOSITORY,'branch':BRANCH,'commit':COMMIT,'remoteFreshnessVerified':False,'engineSHA256':sha(engine),'resources':manifest}
(ROOT/'Documentation').mkdir(exist_ok=True)
(ROOT/'Documentation/android-source-lock.json').write_text(json.dumps(provenance,indent=2,ensure_ascii=False)+'\n')
print(f'Imported {len(manifest)} resources from {BRANCH}@{COMMIT}; OGG decoded PCM verified.')
