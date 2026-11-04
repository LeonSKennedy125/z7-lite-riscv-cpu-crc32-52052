"""Input-bound execution receipts. Historical booleans are never current evidence."""
from __future__ import annotations
from contextlib import contextmanager
from contextvars import ContextVar
from datetime import datetime, timezone
from pathlib import Path
import hashlib, json, os, re, subprocess, sys, time, uuid, threading

ACTIVE = ContextVar('demo_evidence_attempt', default=None)
MARKERS = {'unit': r'^TEST_PASS CRC_MMIO\b', 'memory': r'^TEST_PASS MEMORY_64K\b',
           'simulate': r'^TEST_PASS CPU_7010_CRC\b', 'faults':r'^FIRMWARE_FAULT_CONTROLS_PASS\b',
           'project': r'^PROJECT_CREATED_7010_50MHZ\s*$',
           'implement': r'^IMPLEMENTATION_COMPLETE_7010_50MHZ\s*$',
           'firmware': r'^FIRMWARE_PASS\b', 'controls': r'^READER_CONTROLS_PASS\b',
           'hardware': r'^HARDWARE_CAPTURE_COMPLETE:', 'clean': r'^REBUILD_PASS clean\b',
           'baseline': r'^REBUILD_PASS baseline\b',
           'report_simulation': r'^REPORT_PASS simulation\b', 'report_hardware': r'^REPORT_PASS hardware\b'}
ERRORS = r'^(?:\s*Fatal:|\s*FATAL\b|\s*ERROR:|\s*TEST_FAIL\b|\s*DEMO_FAIL:)'

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def save(path, value):
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name('._'+uuid.uuid4().hex[:12]+'.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    os.replace(tmp, path)

def utc():
    return datetime.now(timezone.utc).isoformat()

def inputs(root, action='current'):
    root = Path(root)
    selected = [root/'run.py', root/'standalone.json', root/'release_manifest.json']
    for name in ('src', 'sim', 'constraints', 'scripts', 'firmware'):
        selected += [p for p in (root/name).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    selected += [root/'evidence'/n for n in ('source_manifest.json', 'toolchain.json', 'vectors.json')]
    selected += [root/'evidence/rules'/n for n in ('track_guide_2026.md','source.json')]
    if action not in ('firmware','project'):
        selected += list((root/'b/p/demo.srcs/sources_1/ip').rglob('*.xci'))
    files = {}
    for p in sorted(set(selected)):
        rel = p.relative_to(root).as_posix()
        if action == 'firmware' and (rel.startswith('firmware/out/') or rel in ('firmware/generated.h', 'evidence/vectors.json')):
            continue  # Firmware generation outputs are bound as artifacts instead.
        if p.is_file():
            files[rel] = sha(p)
    for rel in ('run.py','src/crc_mmio.sv','src/demo_top.sv','firmware/main.c','firmware/start.s',
                'firmware/link.ld','scripts/build.tcl','constraints/board_r11.xdc','evidence/source_manifest.json'):
        if rel not in files:
            raise RuntimeError('required input missing: '+rel)
    # Bind the actual executable files as well as the version policy and package receipt.
    declared=root/'evidence/tool_locations.json'
    declared_env=json.loads(declared.read_text(encoding='utf-8'))['environment'] if (root/'standalone.json').is_file() and declared.is_file() else {}
    gcc_bin=Path(os.environ.get('CRC_DEMO_GCC_BIN',declared_env.get('CRC_DEMO_GCC_BIN',str(root/'tools/gcc/bin'))))
    paths = {'python': Path(sys.executable),
             'vivado_launcher': Path(os.environ.get('CRC_DEMO_VIVADO_BIN','D:/XILINX/2026.1/Vivado/bin'))/'vivado.bat',
             'vivado_executable': Path(os.environ.get('CRC_DEMO_VIVADO_BIN','D:/XILINX/2026.1/Vivado/bin'))/'unwrapped/win64.o/vivado.exe',
             'gcc': gcc_bin/'riscv-none-elf-gcc.exe',
             'objdump': gcc_bin/'riscv-none-elf-objdump.exe',
             'nm':gcc_bin/'riscv-none-elf-nm.exe',
             'readelf':gcc_bin/'riscv-none-elf-readelf.exe'}
    tools = {k: {'path':str(p), 'sha256':sha(p) if p.is_file() else None} for k,p in paths.items()}
    payload = {'files':files, 'tools':tools, 'python_version':sys.version,
               'ip_configuration_source':'scripts/build.tcl; generated XCI files are project artifacts'}
    payload['sha256'] = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    return payload

def receipt_path(root, action):
    return Path(root)/'evidence'/(action+'_result.json')

def artifacts(root, action):
    fixed = {
        'firmware':['evidence/firmware.json','evidence/vectors.json','firmware/generated.h',
                    *['firmware/out/'+n for n in ('firmware.elf','firmware.dis','rom.bin','ram.bin','rom.coe','ram.coe','rom.hex','ram.hex','expected.hex','lengths.hex')]],
        'project':['evidence/ip_status.txt','b/p/demo.xpr'],
        'implement':['evidence/'+n for n in ('structure.txt','utilization.rpt','utilization_hierarchical.rpt',
                     'timing_summary.rpt','drc.rpt','methodology.rpt','clocks.rpt','demo.bit','demo.ltx','routed.dcp')],
        'clean':['evidence/clean_details.json'], 'baseline':['evidence/baseline_details.json'],
        'controls':['evidence/reader_controls.json'], 'faults':['evidence/firmware_faults.json'],
        'hardware':['evidence/hardware/capture_receipt.json',*[f'evidence/hardware/run_{i}.hex' for i in range(3)]],
        'report_simulation':['report/simulation/'+n for n in ('results.json','results.csv','index.html','cycles.svg')],
        'report_hardware':['report/hardware/'+n for n in ('results.json','results.csv','index.html','cycles.svg')]
    }.get(action, [])
    result = list(fixed)
    if action == 'simulate':
        captures = list((Path(root)/'b/p/demo.sim').rglob('mailbox_sim.hex'))
        if len(captures) != 1: raise RuntimeError('exactly one current simulation mailbox required')
        result += [captures[0].relative_to(root).as_posix()]
        result += [(captures[0].parent/f'mailbox_sim_run_{i}.hex').relative_to(root).as_posix() for i in range(3)]
    if action=='faults':
        model=json.loads((Path(root)/'evidence/firmware_faults.json').read_text(encoding='utf-8'))
        result += [c['capture'] for c in model['cases']]
        for c in model['cases']:result += [c['log'],c['log']+'.command.json']
    if action == 'project':
        configs = list((Path(root)/'b/p/demo.srcs/sources_1/ip').rglob('*.xci'))
        if len(configs) != 7: raise RuntimeError('seven generated IP configurations required')
        result += [p.relative_to(root).as_posix() for p in configs]
    if action == 'firmware':
        manifest=json.loads((Path(root)/'evidence/firmware.json').read_text(encoding='utf-8'))
        result += [manifest['compile_log'],manifest['compile_log']+'.command.json']
        result += ['firmware/out/'+n for n in ('audit.json','symbols.hex','nm.txt','readelf.txt')]
        result += [p.relative_to(root).as_posix() for p in (Path(root)/'firmware/out').glob('*.su')]
        for log in manifest['instruction_audit']['tool_logs']:result += [log,log+'.command.json']
    return result

def archive(root, path):
    path = Path(path)
    if path.exists():
        dst = Path(root)/'evidence/history'/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])/path.relative_to(root)
        dst.parent.mkdir(parents=True, exist_ok=True)
        path.rename(dst)

class Attempt:
    def __init__(self, root, action):
        self.root = Path(root); self.action = action
        self.path = receipt_path(root, action)
        archive(root, self.path)
        archive(root, self.root/'evidence/verification_summary.json')
        self.data = {'schema':2,'action':action,'run_id':uuid.uuid4().hex,'status':'RUNNING','pass':False,
                     'started_at':utc(),'started_ns':time.time_ns(),'commands':[], 'artifacts':{}}
        save(self.path, self.data)  # Invalidate before input collection or process launch can fail.
        save(self.root/'evidence/verification_summary.json', {'status':'INVALIDATED','pass':False,'reason':'new '+action+' attempt','run_id':self.data['run_id']})

    def start(self):
        self.data['inputs_start'] = inputs(self.root, self.action)
        save(self.path,self.data)

    def finish(self, error=None):
        try:
            self.data['inputs_end'] = inputs(self.root, self.action)
            if error: raise RuntimeError(str(error))
            if self.data['inputs_start'] != self.data['inputs_end']: raise RuntimeError('inputs changed during execution')
            cmds = self.data['commands']
            if not cmds or any(not c['started'] or c['exit_code'] != 0 or c['timed_out'] for c in cmds):
                raise RuntimeError('tool failed, did not start, or timed out')
            text = '\n'.join((self.root/c['log']).read_text(encoding='utf-8',errors='replace') for c in cmds)
            if not re.search(MARKERS[self.action],text,re.M): raise RuntimeError('required terminal marker missing')
            if re.search(ERRORS,text,re.M): raise RuntimeError('error marker in execution log')
            for rel in artifacts(self.root,self.action):
                p=self.root/rel
                if not p.is_file(): raise RuntimeError('required artifact missing: '+rel)
                reusable_config = self.action == 'project' and p.suffix in ('.xci','.xpr')
                if not reusable_config and p.stat().st_mtime_ns < self.data['started_ns']:
                    raise RuntimeError('artifact predates attempt: '+rel)
                self.data['artifacts'][rel]=sha(p)
            self.data.update(status='PASS', **{'pass':True})
        except BaseException as exc:
            self.data.update(status='FAIL', **{'pass':False}, reason=str(exc))
        self.data['finished_at']=utc(); save(self.path,self.data)
        if not error and self.data['status'] != 'PASS': raise RuntimeError(self.data['reason'])

@contextmanager
def attempt(root, action):
    run = Attempt(root, action); token = ACTIVE.set(run)
    try:
        run.start()
        yield run
    except BaseException as exc:
        run.finish(exc)
        raise
    else:
        run.finish()
    finally:
        ACTIVE.reset(token)

def command(args, cwd, log, timeout=3600, marker=None):
    log=Path(log); log.parent.mkdir(parents=True,exist_ok=True)
    active=ACTIVE.get(); root=active.root if active else log.parent
    stderr_log=log.with_suffix(log.suffix+'.stderr.log')
    record={'argv':[str(a) for a in args], 'cwd':str(cwd), 'started_at':utc(),
            'started':False,'exit_code':None,'timed_out':False,'timeout_seconds':timeout,
            'log':log.relative_to(root).as_posix(),'stderr_log':stderr_log.relative_to(root).as_posix(),
            'stdio_policy':'distinct stdout/stderr PIPE streams drained to separate files; stdin DEVNULL; stderr appended after exit and retained separately'}
    if active:
        active.data['commands'].append(record); save(active.path,active.data)
    env=os.environ.copy();env['PYTHONUTF8']='1'
    stderr_merged=False
    def merge_stderr():
        nonlocal stderr_merged
        if not stderr_merged and stderr_log.exists():
            content=stderr_log.read_text(encoding='utf-8',errors='replace')
            if content:
                with log.open('a',encoding='utf-8') as stream:
                    stream.write('\nSTDERR_CAPTURE_BEGIN\n'+content+'\nSTDERR_CAPTURE_END\n')
            stderr_merged=True
    try:
        with log.open('x',encoding='utf-8') as f, stderr_log.open('x',encoding='utf-8') as ferr:
            f.write('COMMAND '+json.dumps(record['argv'])+'\n');f.flush()
            proc=subprocess.Popen(record['argv'],cwd=cwd,env=env,stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE,stderr=subprocess.PIPE,bufsize=0,
                                  creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            record['started']=True
            # Regular-file standard handles can corrupt Vivado2026.1 Tcl channels
            # on this Windows host. Give the tool independent pipes and preserve
            # each raw stream in its own file without changing error detection.
            pump_errors=[]
            def pump(pipe,destination):
                try:
                    while data:=pipe.read(65536):
                        destination.buffer.write(data);destination.buffer.flush()
                except BaseException as exc:pump_errors.append(str(exc))
                finally:pipe.close()
            pumps=[threading.Thread(target=pump,args=pair) for pair in ((proc.stdout,f),(proc.stderr,ferr))]
            for worker in pumps:worker.start()
            try: record['exit_code']=proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                record['timed_out']=True
                if os.name=='nt':
                    subprocess.run(['taskkill.exe','/PID',str(proc.pid),'/T','/F'],stdout=f,stderr=ferr,
                                   creationflags=subprocess.CREATE_NO_WINDOW,timeout=30)
                else: proc.kill()
                proc.wait(timeout=30);record['exit_code']=proc.returncode
                raise RuntimeError('tool timeout')
            finally:
                for worker in pumps:worker.join(timeout=30)
            if pump_errors or any(worker.is_alive() for worker in pumps):raise RuntimeError('stdout/stderr capture failed: '+str(pump_errors))
            if record['exit_code'] != 0: raise RuntimeError('tool exit '+str(record['exit_code']))
        merge_stderr()
        transcript=log.read_text(encoding='utf-8',errors='replace')
        if marker and not re.search(marker,transcript,re.M): raise RuntimeError('required terminal marker missing')
        if re.search(ERRORS,transcript,re.M): raise RuntimeError('error marker in execution log')
    except BaseException as exc:
        merge_stderr()
        record['error']=str(exc)
        if log.exists():
            with log.open('a',encoding='utf-8') as f:f.write('\nCHECKER_ERROR '+str(exc)+'\n')
        raise
    finally:
        merge_stderr()
        record['finished_at']=utc();record['log_sha256']=sha(log) if log.exists() else None
        record['stderr_log_sha256']=sha(stderr_log) if stderr_log.exists() else None
        if active: save(active.path,active.data)
        save(log.with_suffix(log.suffix+'.command.json'),record)
        print('COMMAND_EXIT',record['exit_code'],'LOG',str(log))
    return log

def validate_receipt(root, action):
    """Return a classified gate; never upgrade a legacy receipt to current PASS."""
    root=Path(root);p=receipt_path(root,action)
    if not p.exists(): return {'status':'PENDING_EXECUTION','reason':'not executed with the current evidence protocol'}
    try:
        r=json.loads(p.read_text(encoding='utf-8'))
        if r.get('schema') != 2:
            return {'status':'PENDING_EXECUTION','reason':'historical receipt lacks input/command/log binding','historical_receipt':p.relative_to(root).as_posix()}
        if r.get('action')!=action or r.get('status')!='PASS' or r.get('pass') is not True: raise ValueError('attempt is '+str(r.get('status'))+': '+str(r.get('reason','unfinished')))
        if r.get('inputs_start') != r.get('inputs_end') or r.get('inputs_end') != inputs(root,action):
            return {'status':'PENDING_EXECUTION','reason':'input mismatch; previous evidence is historical'}
        commands=r['commands']
        if not commands: raise ValueError('no actual commands')
        texts=[]
        for c in commands:
            if not c['started'] or c['exit_code']!=0 or c['timed_out'] or c.get('error'): raise ValueError('unsuccessful tool invocation')
            log=(root/c['log']).resolve()
            if not log.is_relative_to(root.resolve()) or sha(log)!=c['log_sha256']: raise ValueError('log missing or hash mismatch')
            if c.get('stderr_log'):
                stderr=(root/c['stderr_log']).resolve()
                if not stderr.is_relative_to(root.resolve()) or sha(stderr)!=c['stderr_log_sha256']:
                    raise ValueError('stderr log missing or hash mismatch')
            texts.append(log.read_text(encoding='utf-8',errors='replace'))
        transcript='\n'.join(texts)
        if not re.search(MARKERS[action],transcript,re.M) or re.search(ERRORS,transcript,re.M): raise ValueError('terminal proof missing or error in log')
        required=artifacts(root,action)
        for rel in required:
            if r['artifacts'].get(rel) != sha(root/rel): raise ValueError('artifact missing or changed: '+rel)
        for rel,h in r['artifacts'].items():
            target=(root/rel).resolve()
            if not target.is_relative_to(root.resolve()) or sha(target)!=h: raise ValueError('artifact hash mismatch: '+rel)
        return {'status':'PASS','receipt':p.relative_to(root).as_posix(),'receipt_sha256':sha(p),'inputs_sha256':r['inputs_end']['sha256']}
    except (OSError,ValueError,KeyError,TypeError,RuntimeError) as exc:
        return {'status':'FAIL','reason':str(exc)}
