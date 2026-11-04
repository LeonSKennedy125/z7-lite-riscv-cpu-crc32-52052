"""Independent 7010 demo entry point. Never opens the production XPR for writing."""
from __future__ import annotations
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
from contextlib import contextmanager, nullcontext
from pathlib import Path
from scripts.evidence import attempt, command as evidence_command, MARKERS, archive, validate_receipt

ROOT = Path(__file__).resolve().parent
STANDALONE = os.environ.get('CRC_DEMO_STANDALONE')=='1' or (ROOT/'standalone.json').is_file()
ACTIVE = None if STANDALONE else next((p for p in ROOT.parents if p.name=='cpu_repair_work_2026_1' and ROOT==p/'board/z7_lite_7010_crc' and (p/'RISCV_5pipeline.xpr').exists()),None)
WORKSPACE = ACTIVE.parent if ACTIVE else None
BIN = Path(os.environ.get('CRC_DEMO_VIVADO_BIN','D:/XILINX/2026.1/Vivado/bin'))

@contextmanager
def short_workspace():
    """Reuse one stable alias: moving Vivado IP products between drive names locks them."""
    import ctypes
    record=ROOT/'evidence/drive_alias.json'
    mask=ctypes.windll.kernel32.GetLogicalDrives()
    letter=json.loads(record.read_text())['letter'] if record.exists() else next((x for x in ('YXWVUTSRQPONMLKJIHGFZ' if STANDALONE else 'ZYXWVUTSRQPONMLKJIHGF') if not mask & (1<<(ord(x)-65))),None)
    if not letter:raise RuntimeError('no free drive letter for a temporary Vivado path alias')
    drive=letter+':'
    if not mask & (1<<(ord(letter)-65)):
        subprocess.run(['subst.exe',drive,str(ROOT)],check=True,capture_output=True)
    mapped=Path(drive+'/')
    if not (mapped/'run.py').exists() or not os.path.samefile(mapped/'run.py',ROOT/'run.py'):
        raise RuntimeError('configured alias is occupied by a different target; no drive was removed')
    save(record,{'letter':letter,'actual_target':str(ROOT),'purpose':'stable SUBST alias for Vivado IP/debug-hub; files remain in this directory'})
    yield lambda p: mapped/Path(p).relative_to(ROOT)

def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def save(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def read_source(p):
    b = Path(p).read_bytes()
    try: return b.decode('utf-8-sig')
    except UnicodeDecodeError: return b.decode('gb18030')

def protected_files():
    if WORKSPACE is None:return
    for parent in [WORKSPACE, WORKSPACE/'cpu_repair_work', ACTIVE]:
        for folder in ['RISCV_5pipeline.srcs']:
            for p in sorted((parent/folder).rglob('*')):
                if p.is_file(): yield p
        p=parent/'RISCV_5pipeline.xpr'
        if p.exists(): yield p

def init():
    if WORKSPACE is None:
        check_protection();return
    manifest=ROOT/'evidence/protected_before.json'
    if manifest.exists():
        check_protection()
        return
    files={str(p.relative_to(WORKSPACE)).replace('\\','/'):sha(p) for p in protected_files()}
    save(manifest, {'scope':'three production source trees and XPRs; no caches', 'files':files})
    print('PROTECTED_FILES',len(files))

def check_protection():
    if WORKSPACE is None:
        records=json.loads((ROOT/'evidence/source_manifest.json').read_text())['sources']
        bad=[r['copy'] for r in records if sha(ROOT/r['copy'])!=r['copy_sha256']]
        if bad:raise RuntimeError('exported frozen sources changed: '+str(bad))
        save(ROOT/'evidence/protected_after.json',{'applicable':False,'pass':None,'export_snapshot_pass':True,'status':'NOT_APPLICABLE','explicit_standalone':STANDALONE,'reason':'standalone mode; ancestor discovery and production-source fallback disabled; ancestor existence is not tested'})
        print('EXPORT_SNAPSHOT_PASS; original workspace protection not applicable');return
    before=json.loads((ROOT/'evidence/protected_before.json').read_text(encoding='utf-8'))['files']
    changed=[n for n,h in before.items() if not (WORKSPACE/n).exists() or sha(WORKSPACE/n)!=h]
    added=sorted(set(str(p.relative_to(WORKSPACE)).replace('\\','/') for p in protected_files())-set(before))
    save(ROOT/'evidence/protected_after.json',{'checked':len(before),'changed':changed,'added':added,'pass':not changed and not added})
    if changed or added: raise RuntimeError('PRODUCTION_PROTECTION_FAIL: '+str(changed+added))
    print('PRODUCTION_PROTECTION_PASS',len(before))

def command(args, cwd, log):
    return evidence_command(args,cwd,log)

def vivado(script, *args):
    target=ROOT/'b';target.mkdir(exist_ok=True)
    stamp=time.strftime('%Y%m%d_%H%M%S')+'_'+str(time.time_ns())[-9:]
    log=ROOT/'evidence'/f'{Path(script).stem}_{stamp}.log'
    with short_workspace() as mapped:
        command([BIN/'vivado.bat','-mode','batch','-nojournal','-log',log,
                 '-source',mapped(ROOT/'scripts'/script),'-tclargs',*args],mapped(target),log.with_suffix('.console.log'))
    return log

@contextmanager
def generated_workspace_lock():
    """Serialize CLI builds and refuse a generated project open in a GUI."""
    lock=ROOT/'evidence/build.lock';lock.parent.mkdir(parents=True,exist_ok=True)
    with lock.open('x',encoding='utf-8') as f:
        json.dump({'pid':os.getpid(),'root':str(ROOT)},f)
    try:
        query="$ErrorActionPreference='Stop'; $sessions=@(Get-Process | Where-Object { $_.ProcessName -eq 'vivado' } | Select-Object Id,MainWindowTitle,Path); ConvertTo-Json -InputObject $sessions -Compress"
        r=subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command',query],capture_output=True,text=True,
                         creationflags=subprocess.CREATE_NO_WINDOW,timeout=30)
        if r.returncode:raise RuntimeError('cannot check Vivado GUI occupancy')
        sessions=json.loads(r.stdout) if r.stdout.strip() else []
        if isinstance(sessions,dict):sessions=[sessions]
        save(ROOT/'evidence/vivado_occupancy.json',{'sessions':sessions,'checked_at':time.time(),'root':str(ROOT)})
        aliases=[str(ROOT).replace('\\','/').lower()]
        alias_record=ROOT/'evidence/drive_alias.json'
        if alias_record.exists():aliases.append(json.loads(alias_record.read_text())['letter'].lower()+':/')
        for session in sessions:
            title=session.get('MainWindowTitle','').replace('\\','/').lower()
            if any(a in title for a in aliases):raise RuntimeError('demo generated project is open in Vivado GUI; close that project before rebuilding')
        yield
    finally:
        lock.unlink()

def snapshot():
    """Freeze exactly the production RTL and generated BD connectivity, with checked transformations."""
    import difflib
    if ACTIVE is None:raise RuntimeError('standalone export already contains frozen sources; no production project to snapshot')
    source=ACTIVE/'RISCV_5pipeline.srcs/sources_1'
    dest=ROOT/'src/core';dest.mkdir(parents=True,exist_ok=True)
    if (ROOT/'evidence/source_manifest.json').exists():
        data=json.loads((ROOT/'evidence/source_manifest.json').read_text())
        for f in data['sources']:
            if sha(WORKSPACE/f['source'])!=f['source_sha256']:raise RuntimeError('SOURCE_CHANGED '+f['source'])
        print('FROZEN_SOURCE_MANIFEST_REUSED');return
    records=[];diffs=[]
    def copy(p,name,transform=lambda s:s):
        original=read_source(p);new=transform(original)
        out=dest/name
        expected=new.encode('utf-8')
        if out.exists() and out.read_bytes()!=expected:
            # Repair only this generator's known Windows text-mode newline expansion.
            if out.read_bytes()!=new.replace('\n','\r\n').encode('utf-8'):
                raise RuntimeError('refuse to overwrite differing snapshot '+str(out))
            out.write_bytes(expected)
        if not out.exists():out.write_bytes(expected)
        records.append({'source':p.relative_to(WORKSPACE).as_posix(),'source_sha256':sha(p),
                        'copy':out.relative_to(ROOT).as_posix(),'copy_sha256':sha(out)})
        if new!=original:diffs.extend(difflib.unified_diff(original.splitlines(True),new.splitlines(True),fromfile=str(p.relative_to(WORKSPACE)),tofile=out.relative_to(ROOT).as_posix()))
    def patch(s,name):
        s=s.replace('"RISCV_DEFINE.vh"','"riscv_define.vh"').replace('"CPU_MEMORY_MAP.vh"','"cpu_memory_map.vh"')
        if name=='CPU_MEMORY_MAP.vh':
            assert s.count("32'h8013ffff")==1;s=s.replace("32'h8013ffff","32'h8010ffff")
        if name=='MEM_DTCM.v':
            assert 'wire [15:0]addr;' in s and 'ram_offset[17:2]' in s
            s=s.replace('wire [15:0]addr;','wire [13:0]addr;').replace('ram_offset[17:2]','ram_offset[15:2]').replace("16'b0;","14'b0;")
        if name=='Store.v':
            needle='MEM_Addr == `CPU_MMIO_COUNTER);';assert s.count(needle)==1
            s=s.replace(needle,"MEM_Addr == `CPU_MMIO_COUNTER ||\n                       (MEM_Addr >= 32'h80200100 && MEM_Addr <= 32'h802003ff));")
        return s
    for p in sorted(list((source/'new').iterdir())+list((source/'imports').rglob('*'))):
        if p.suffix.lower() in ['.v','.sv','.vh']:
            copy(p,p.name.lower(),lambda s,n=p.name:patch(s,n))
    bd=json.loads((source/'bd/design_1/design_1.bd').read_text(encoding='utf-8-sig'))['design']
    def structural(s):
        for name,c in bd['components'].items():
            if ':module_ref:' in c['vlnv']:
                target=c['vlnv'].split(':')[2]
                s=re.sub(r'\b'+re.escape(c['xci_name'])+r'\b',target,s)
        s=re.sub(r'  design_1_ila_0_0 ila_0\s*\(.*?\);','',s,flags=re.S)
        for a,b in [('design_1_clk_wiz_0_0','clk50'),('design_1_proc_sys_reset_0_0','rstip'),('design_1_util_vector_logic_0_0','invip'),('design_1_util_vector_logic_1_0','orip')]:s=s.replace(a,b)
        s=re.sub(r'\(\*.*?\*\)','',s,flags=re.S)
        s=s.replace('module design_1','module demo_cpu',1)
        s=s.replace('    zero);','    zero,\n    demo_restart);',1)
        s=s.replace('  input zero;','  input zero;\n  input demo_restart;',1)
        assert '.aux_reset_in(1\'b1)' in s
        s=s.replace(".aux_reset_in(1'b1)",'.aux_reset_in(~demo_restart)')
        return s
    copy(ACTIVE/'RISCV_5pipeline.gen/sources_1/bd/design_1/synth/design_1.v','demo_cpu.v',structural)
    save(ROOT/'evidence/source_manifest.json',{'method':'frozen current RTL + Vivado2026.1 generated structural BD connectivity; module-ref wrappers replaced by their underlying RTL modules','sources':records,'board_part':'xc7z010clg400-1','ram_bytes':65536,'cpu_hz':50000000})
    (ROOT/'evidence/source_changes.diff').write_text(''.join(diffs),encoding='utf-8')
    print('SNAPSHOT_CREATED',len(records))

def recreate_generated_project():
    src=ROOT/'b/p';dst=ROOT/'b'/('previous_p_'+time.strftime('%Y%m%d_%H%M%S'))
    if src.exists():
        if not src.resolve().is_relative_to(ROOT) or not dst.resolve().is_relative_to(ROOT):raise RuntimeError('unsafe generated project move')
        if src.is_symlink() or (hasattr(src,'is_junction') and src.is_junction()):raise RuntimeError('generated project is a link')
        src.rename(dst)
        save(ROOT/'evidence/generated_project_recreation.json',{'preserved_old_generated_project':dst.relative_to(ROOT).as_posix(),'reason':'stable short alias and source-only IP regeneration; production sources untouched'})
    vivado('build.tcl','project')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['init','snapshot','preflight','toolchain','firmware','project','recreate','unit','memory','simulate','faults','implement','clean','baseline','controls','hardware','report','verify'])
    parser.add_argument('--source',choices=['simulation','hardware'],default='simulation')
    parser.add_argument('--pcb-revision',default='')
    args=parser.parse_args()
    if (ROOT/'migration/current.json').is_file() and (args.action=='hardware' or (args.action=='report' and args.source=='hardware')):
        raise RuntimeError('Use relocated S05 R1 evidence/agent_steps/step_05/rework_r1/s05.py; legacy hardware entry is blocked before tool execution')
    action='report_'+args.source if args.action=='report' else 'project' if args.action=='recreate' else args.action
    managed=action in MARKERS
    build_action=args.action in ['project','recreate','unit','memory','simulate','faults','implement','clean','baseline']
    if not managed:
        archive(ROOT,ROOT/'evidence/verification_summary.json')
        save(ROOT/'evidence/verification_summary.json',{'status':'INVALIDATED','pass':False,'reason':'starting '+args.action})
    with attempt(ROOT,action) if managed else nullcontext():
        init()
        with generated_workspace_lock() if build_action else nullcontext():
            dispatch(args)

def dispatch(args):
    if args.action=='snapshot':snapshot()
    elif args.action=='recreate':recreate_generated_project()
    elif args.action=='preflight':vivado('preflight.tcl')
    elif args.action=='toolchain':
        from scripts.firmware import install_toolchain
        install_toolchain()
    elif args.action=='firmware':
        command([sys.executable,'-X','utf8','-c','from scripts.firmware import build; build()'],ROOT,
                ROOT/'evidence'/('firmware_'+str(time.time_ns())+'.console.log'))
    elif args.action=='implement':
        from scripts.implementation import build
        build()
    elif args.action=='project':
        # First reopen settles Vivado-generated XCI UI metadata before test binding.
        vivado('build.tcl','project')
        vivado('build.tcl','project')
    elif args.action in ['unit','memory','simulate']:vivado('build.tcl',args.action)
    elif args.action=='faults':
        command([sys.executable,'-X','utf8','-c','from scripts.faults import main; from run import vivado; main(vivado)'],ROOT,
                ROOT/'evidence'/('faults_'+str(time.time_ns())+'.console.log'))
    elif args.action=='hardware':
        if validate_receipt(ROOT,'implement')['status']!='PASS':raise RuntimeError('current implementation receipt required before programming')
        log=vivado('hardware.tcl',args.pcb_revision)
        transcript=log.with_suffix('.console.log').read_text(encoding='utf-8',errors='replace')
        if 'HARDWARE_CAPTURE_COMPLETE:' not in transcript or len(re.findall(r'^HARDWARE_CAPTURE run=',transcript,re.M))!=3:
            raise RuntimeError('hardware capture terminal proof missing')
        save(ROOT/'evidence/hardware/capture_receipt.json',{'source':'Vivado2026.1 Hardware Manager','pcb_revision_supplied':args.pcb_revision,
             'bit_sha256':sha(ROOT/'evidence/demo.bit'),'ltx_sha256':sha(ROOT/'evidence/demo.ltx'),
             'log':log.with_suffix('.console.log').relative_to(ROOT).as_posix(),'log_sha256':sha(log.with_suffix('.console.log')),
             'captures':{f'run_{i}.hex':sha(ROOT/f'evidence/hardware/run_{i}.hex') for i in range(3)}})
    elif args.action in ['clean','baseline']:
        command([sys.executable,'-X','utf8','-c',"from scripts.rebuild import main; main("+repr(args.action)+")"],ROOT,
                ROOT/'evidence'/(args.action+'_'+str(time.time_ns())+'.console.log'))
    elif args.action=='controls':
        command([sys.executable,'-X','utf8','-c','from scripts.test_report import main; main()'],ROOT,
                ROOT/'evidence'/('controls_'+str(time.time_ns())+'.console.log'))
    elif args.action=='report':
        command([sys.executable,'-X','utf8','-c',"from scripts.report import main; main("+repr(args.source)+")"],ROOT,
                ROOT/'evidence'/('report_'+args.source+'_'+str(time.time_ns())+'.console.log'))
    elif args.action=='verify':
        from scripts.verify import main as verify
        verify()
    check_protection()

if __name__=='__main__':
    try:main()
    except Exception as e:
        import traceback
        traceback.print_exc()
        print('DEMO_FAIL:',e,file=sys.stderr);sys.exit(1)
