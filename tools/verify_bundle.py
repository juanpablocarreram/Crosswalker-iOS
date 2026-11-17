"""Verify that Xcode actually packaged every imported resource and registered font."""
from pathlib import Path
import sys, json, subprocess, plistlib, hashlib
ROOT=Path(__file__).resolve().parents[1]
app=Path(sys.argv[1])
lock=json.loads((ROOT/'Documentation/android-source-lock.json').read_text())
assets=json.loads(subprocess.check_output(['xcrun','assetutil','--info',str(app/'Assets.car')]))
names={a.get('Name') for a in assets}
images=0;copied=0
for entry in lock['resources']:
    local=ROOT/entry['target']
    if entry['kind']=='image':
        assert local.stem in names, f'Missing compiled image: {local.stem}'
        images+=1
    else:
        packaged=app/local.name
        assert packaged.is_file(),packaged
        assert hashlib.sha256(packaged.read_bytes()).hexdigest()==entry['targetSHA256'],packaged
        copied+=1
plist=plistlib.loads((app/'Info.plist').read_bytes())
fonts=plist['UIAppFonts']
assert set(fonts)=={'jersey_10.ttf','jersey_25.ttf','pixelify_sans.ttf','silkscreen.ttf','silkscreen_bold.ttf'}
for font in fonts: assert (app/font).is_file(),font
for sound in ['ack']+[f'blip_{i}' for i in range(6)]: assert (app/(sound+'.wav')).is_file(),sound
assert (app/'PrivacyInfo.xcprivacy').is_file()
result={'sourceCommit':lock['commit'],'compiledImageNamesVerified':images,'packagedResourceHashesVerified':copied,'registeredFonts':fonts,'minimumOS':plist['MinimumOSVersion'],'generatedToneFilesVerified':7}
(ROOT/'Documentation/bundle-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
