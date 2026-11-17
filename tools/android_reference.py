"""Resolve only the explicitly selected Android branch; never read the ADO checkout."""
from pathlib import Path
import subprocess, hashlib
ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'https://github.com/Diego-Alberto-A/ADO.git'
BRANCH = 'experiment/nuevos-assets'
COMMIT = '37d3fe9e08fae3589538ec78e2f4a5cca4403df5'
SOURCE = ROOT / '.reference-source'
def prepare():
    if not (SOURCE / 'app/src/main/java/com/example/crosswalker/game/Simulation.kt').exists():
        archive = subprocess.check_output(['git','-C',str(ROOT.parent/'ADO'),'archive',COMMIT,'app','assets','gradle','build.gradle.kts','settings.gradle.kts','gradle.properties','README.md','tools'])
        SOURCE.mkdir(exist_ok=True)
        subprocess.run(['tar','-xf','-','-C',str(SOURCE)],input=archive,check=True)
    tree = subprocess.check_output(['git','-C',str(ROOT.parent/'ADO'),'ls-tree','-r','-z',COMMIT])
    for entry in tree.split(b'\0'):
        if not entry: continue
        metadata, path = entry.split(b'\t',1)
        local = SOURCE / path.decode()
        if not local.is_file(): continue
        content = local.read_bytes()
        actual = hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
        assert actual == metadata.split()[2].decode(), f'Pinned Android source modified: {local}'
    original = subprocess.check_output(['git','-C',str(ROOT.parent/'ADO'),'show',COMMIT+':app/src/main/java/com/example/crosswalker/game/Simulation.kt'])
    assert (SOURCE/'app/src/main/java/com/example/crosswalker/game/Simulation.kt').read_bytes() == original
    return SOURCE

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
if __name__ == '__main__':
    prepare()
    print(f'{REPOSITORY} [{BRANCH}] {COMMIT}\n{SOURCE}')
