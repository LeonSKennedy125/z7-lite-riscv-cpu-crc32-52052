"""S04 allowlisted candidate, archive extraction, fresh independent validation."""
from pathlib import Path
import json, os, re, shutil, sys, time, uuid, zipfile
from .evidence import save, sha, command, validate_receipt

ROOT=Path(__file__).resolve().parents[1]

def listing():
    names=(ROOT/'scripts/release_files.txt').read_text(encoding='ascii').splitlines()
    if len(names)!=len(set(names)):raise RuntimeError('duplicate release entry')
    required={'sim/tb_cpu.sv','sim/tb_cpu_faults.sv','sim/tb_crc.sv','sim/tb_memory.sv','src/core/cpu_memory_map.vh','src/core/riscv_define.vh','firmware/main.c','firmware/start.s','firmware/link.ld','scripts/rtl_files.txt'}
    if not required.issubset(names):raise RuntimeError('mandatory release inputs omitted: '+str(sorted(required-set(names))))
    for n in names:
        p=Path(n)
        if not n or p.is_absolute() or '..' in p.parts:raise RuntimeError('unsafe release path '+n)
        if any(not re.fullmatch(r'[a-z0-9_.-]+|README.md|SKILL.md',part) for part in p.parts):raise RuntimeError('release naming violation '+n)
        src=(ROOT/p).resolve()
        if not src.is_relative_to(ROOT) or not src.is_file():raise RuntimeError('missing or linked external input '+n)
    return names

def package():
    tag=time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:6]
    candidate=ROOT/'delivery'/('source_candidate_'+tag)
    candidate.mkdir(parents=True)
    for n in listing():
        dst=candidate/n; dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/n,dst)
    provenance=json.loads((candidate/'evidence/source_manifest.json').read_text(encoding='utf-8'))
    omitted=[r for r in provenance['sources'] if not (candidate/r['copy']).is_file()]
    provenance['sources']=[r for r in provenance['sources'] if (candidate/r['copy']).is_file()]
    provenance['release_note']='Subset of original 46-entry provenance; excluded originals recorded in evidence/provenance/full_source_manifest.json. No included CPU RTL bytes changed.'
    provenance['excluded_unused_copies']=[r['copy'] for r in omitted]
    save(candidate/'evidence/source_manifest.json',provenance)
    save(candidate/'standalone.json',{'mode':'standalone','ancestor_discovery':False,'production_fallback':False,'schema':1})
    files={p.relative_to(candidate).as_posix():sha(p) for p in sorted(candidate.rglob('*')) if p.is_file()}
    save(candidate/'release_manifest.json',{'schema':1,'scope':'S04 source candidate; no generated projects, DCPs, caches, tools or current PASS receipts',
         'files':files,'manifest_self_excluded':True,'source_selection':'scripts/release_files.txt',
         'licensing_status':'PENDING_S07; no license grant inferred for AMD-generated connectivity or vendor documents'})
    archive=candidate.with_suffix('.zip')
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(candidate.rglob('*')):
            if p.is_file():z.write(p,p.relative_to(candidate).as_posix())
    return candidate,archive

def verify_package(root,exact=False):
    root=Path(root); manifest=json.loads((root/'release_manifest.json').read_text(encoding='utf-8'))
    for n,h in manifest['files'].items():
        p=(root/n).resolve()
        if not p.is_relative_to(root.resolve()) or sha(p)!=h:raise RuntimeError('package hash mismatch '+n)
    if exact:
        actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
        if actual!=set(manifest['files'])|{'release_manifest.json'}:raise RuntimeError('unexpected initial extracted file')
    return manifest

def clean():
    candidate,archive=package()
    fresh=ROOT/'clean_builds'/candidate.name.removeprefix('source_candidate_')
    fresh.mkdir(parents=True)
    with zipfile.ZipFile(archive) as z:
        for n in z.namelist():
            if not (fresh/n).resolve().is_relative_to(fresh.resolve()):raise RuntimeError('unsafe archive')
        z.extractall(fresh)
    manifest=verify_package(fresh,exact=True)
    gcc=Path(os.environ.get('CRC_DEMO_GCC_BIN',str(ROOT/'tools/gcc/bin'))).resolve()
    env={'CRC_DEMO_STANDALONE':'1','CRC_DEMO_GCC_BIN':str(gcc),
         'CRC_DEMO_VIVADO_BIN':os.environ.get('CRC_DEMO_VIVADO_BIN','D:/XILINX/2026.1/Vivado/bin'),
         'PYTHONDONTWRITEBYTECODE':'1','TEMP':str(fresh/'runtime_tmp'),'TMP':str(fresh/'runtime_tmp')}
    (fresh/'runtime_tmp').mkdir()
    for k,v in env.items():os.environ[k]=v
    save(fresh/'evidence/tool_locations.json',{'environment':env,'python':sys.executable,
         'design_inputs':'extracted package and newly generated outputs only',
         'runtime_inputs':'declared Python/GCC/Vivado installations, Windows runtime and existing license configuration',
         'external_gcc_installation_read_only':True})
    details={'schema':1,'path':fresh.relative_to(ROOT).as_posix(),'candidate':candidate.relative_to(ROOT).as_posix(),
             'archive':archive.relative_to(ROOT).as_posix(),'archive_sha256':sha(archive),
             'initial_files':len(manifest['files'])+1,'initial_package_exact':True,'consumed_old_dcp':False,
             'explicit_standalone':True,'ancestor_projects_may_exist':True,'other_machine_tested':False,
             'environment':env,'actions':[]}
    save(ROOT/'evidence/clean_details.json',details)
    actions=['firmware','project','unit','memory','simulate','faults','controls','implement','project','report']
    for i,action in enumerate(actions):
        log=fresh/'evidence'/f'clean_{i:02d}_{action}.console.log'
        command([sys.executable,'-B','-X','utf8','run.py',action],fresh,log,timeout=3000)
        gate='report_simulation' if action=='report' else action
        verdict=validate_receipt(fresh,gate)
        if verdict['status']!='PASS':raise RuntimeError('child gate invalid '+str(verdict))
        details['actions'].append({'action':gate,'receipt':verdict,'log':log.relative_to(fresh).as_posix()})
        save(ROOT/'evidence/clean_details.json',details)
    images={n:sha(fresh/'firmware/out'/n)==sha(fresh/'data/frozen'/n)
            for n in ('rom.bin','ram.bin','rom.coe','ram.coe','rom.hex','ram.hex','expected.hex','lengths.hex','symbols.hex')}
    if not all(images.values()):raise RuntimeError('fresh firmware differs from S03 frozen images')
    verify_package(fresh)
    from .dependency_audit import audit
    dependency=audit(fresh,candidate)
    details.update(firmware_images_identical=images,simulation_reset_runs=3,dependency_audit=dependency,
                   frozen_included_sources_identical=True,completed_at=time.time())
    for gate in ('firmware','project','unit','memory','simulate','faults','controls','implement','report_simulation'):
        if validate_receipt(fresh,gate)['status']!='PASS':raise RuntimeError('final child gate stale '+gate)
    save(ROOT/'evidence/clean_details.json',details)
    print('REBUILD_PASS clean',fresh)

if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='package':print(*(str(p) for p in package()),sep='\n')
    else:clean()
