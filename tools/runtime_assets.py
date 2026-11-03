"""Audit exact resource references plus the game's dynamic asset naming contracts.

Default: write a plan. --apply: move unused images/native art and their import cache
to the archive outside this project, preserving relative paths and verifying hashes.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply', action='store_true')
parser.add_argument('--archive', type=Path, default=Path('D:/Temp/TheProducers-runtime-art-archive-20261026'))
parser.add_argument('--report-dir', type=Path, default=Path('D:/EP45/ndlp/Producers/QA-latest'))
args = parser.parse_args()
archive = args.archive.resolve()
report_dir = args.report_dir.resolve()
report_dir.mkdir(parents=True,exist_ok=True)
keep = set()
for pattern in ('*.gd','*.tscn','*.tres','project.godot'):
    for p in project.rglob(pattern):
        if '.godot' in p.parts or '.qa' in p.parts: continue
        text = p.read_text(encoding='utf-8-sig')
        keep.update(re.findall(r'res://(assets/[A-Za-z0-9_./#-]+\.(?:png|jpg|jpeg|gif|webp|svg))',text))
for group in ('npc','vip'):
    for folder in (project/'assets'/group).iterdir():
        if not folder.is_dir(): continue
        keep.add(f'assets/{group}/{folder.name}/portrait-v2-2x2.png')
        keep.add(f'assets/{group}/{folder.name}/'+(f'{folder.name}-6x4.png' if group=='vip' else 'sheet-6x4.png'))
for room in ('recording','office','lounge','meeting','cafeteria','storage'):
    for layer in ('back','front'): keep.add(f'assets/lots/rooms/{room}-16x9-{layer}.png')
for layer in ('far','mid','trees'): keep.add(f'assets/lots/backgrounds/city-{layer}-16x9.png')
for instrument in ('guitar','drums','electone','saxophone','organ','mic','bass'):
    keep.add(f'assets/instruments/{instrument}-6frames.png')
art = (project/'scripts/autoload/art.gd').read_text(encoding='utf-8')
chats = json.loads(re.search(r'const CHATS := (\[.*?\])',art).group(1))
for chat in chats: keep.add(f'assets/chatmusic/chat-{chat}-6frames.png')
for cursor in ('arrow','hand','text'): keep.add(f'assets/ui/pixel/cursor-{cursor}-2x.png')
for action in ('jobs','hire','studio','library','shop','floor','column','options'):
    keep.add(f'assets/ui/pixel/icon-{action}.png')
missing = sorted(p for p in keep if not (project/p).is_file())
if missing: raise RuntimeError('Missing required runtime assets: '+str(missing))
images = {'.png','.jpg','.jpeg','.gif','.webp','.svg','.aseprite','.ase'}
candidates = [p for p in (project/'assets').rglob('*') if p.is_file() and p.suffix.lower() in images and p.relative_to(project).as_posix() not in keep]
plan = []
for p in candidates:
    paths=[p]
    sidecar=Path(str(p)+'.import')
    if sidecar.is_file():
        paths.append(sidecar)
        for dest in re.findall(r'res://(\.godot/imported/[^"\]]+)',sidecar.read_text(encoding='utf-8')):
            cache=project/dest
            if cache.is_file(): paths.append(cache)
            md5=cache.with_suffix('.md5')
            if md5.is_file(): paths.append(md5)
    for source in paths:
        resolved=source.resolve()
        assert resolved.is_relative_to(project.resolve()), resolved
        plan.append({'path':source.relative_to(project).as_posix(),'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
plan=list({p['path']:p for p in plan}.values())
summary={'runtime_images_kept':len(keep),'unused_image_or_native_sources':len(candidates),'files_with_import_cache':len(plan),'bytes_removed':sum(p['bytes'] for p in plan),'archive':str(archive),'keep':sorted(keep),'archive_files':plan}
(report_dir/'runtime-asset-plan.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k not in ['keep','archive_files']},indent=2))
if args.apply:
    assert not archive.resolve().is_relative_to(project.resolve()), archive
    # Validate every destination before moving any files, keeping older archives intact.
    for item in plan:
        target = archive/item['path']
        assert target.resolve().is_relative_to(archive), target
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest() == item['sha256'], target
    for item in plan:
        source=project/item['path']
        target=archive/item['path']
        assert source.resolve().is_relative_to(project.resolve())
        assert target.resolve().is_relative_to(archive.resolve())
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists():
            assert hashlib.sha256(target.read_bytes()).hexdigest()==item['sha256'],target
            source.unlink()
        else: shutil.move(str(source),str(target))
        assert hashlib.sha256(target.read_bytes()).hexdigest()==item['sha256'],target
    (report_dir/'runtime-asset-cleanup.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Archived unused images, editable sources and stale import caches; required runtime images retained.')
