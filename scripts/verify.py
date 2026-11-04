"""Read-only gate evaluation; only the verification summary is written."""
from pathlib import Path
import json,re
from .evidence import inputs, save, sha, validate_receipt, archive
ROOT=Path(__file__).resolve().parents[1]

def protection(root):
    root=Path(root)
    standalone=__import__('os').environ.get('CRC_DEMO_STANDALONE')=='1' or (root/'standalone.json').is_file()
    active=None if standalone else next((p for p in root.parents if p.name=='cpu_repair_work_2026_1' and root==p/'board/z7_lite_7010_crc' and (p/'RISCV_5pipeline.xpr').exists()),None)
    try:
        manifest=root/'evidence/source_manifest.json'
        records=json.loads(manifest.read_text(encoding='utf-8'))['sources']
        if not records:raise ValueError('empty frozen source provenance manifest')
        bad=[r['copy'] for r in records if sha(root/r['copy'])!=r['copy_sha256']]
        if bad:raise ValueError('frozen source copy mismatch: '+str(bad))
        if active is None:
            return {'status':'NOT_APPLICABLE','original_project_checked':False,'original_project_pass':None,
                    'export_snapshot_status':'PASS','source_manifest_sha256':sha(manifest),
                    'explicit_standalone':standalone,'reason':'standalone mode; ancestor discovery and production-source fallback disabled; ancestors may still exist'}
        p=root/'evidence/protected_before.json'
        if not p.exists():return {'status':'PENDING_EXECUTION','reason':'original protection baseline missing'}
        before=json.loads(p.read_text(encoding='utf-8'))['files']; workspace=active.parent
        actual=set()
        for parent in (workspace,workspace/'cpu_repair_work',active):
            actual.update(p.relative_to(workspace).as_posix() for p in (parent/'RISCV_5pipeline.srcs').rglob('*') if p.is_file())
            if (parent/'RISCV_5pipeline.xpr').exists():actual.add((parent/'RISCV_5pipeline.xpr').relative_to(workspace).as_posix())
        changed=[n for n,h in before.items() if sha(workspace/n)!=h]
        if changed or actual!=set(before):raise ValueError('production protection mismatch: '+str(changed))
        return {'status':'PASS','checked':len(before),'baseline_sha256':sha(p),'original_project_checked':True}
    except (OSError,ValueError,KeyError,TypeError) as exc:return {'status':'FAIL','reason':str(exc)}

def implementation(root):
    s=(root/'evidence/structure.txt').read_text(encoding='utf-8')
    def num(k):
        m=re.search(r'\b'+k+r'=([-+\d.]+)',s)
        if not m:raise ValueError('missing structure field '+k)
        return float(m[1])
    if 'PART=xc7z010clg400-1' not in s:raise ValueError('wrong implementation part')
    if not (num('SETUP_SLACK')>=0 and num('HOLD_SLACK')>=0 and num('DTCM_DOA_REG')==1 and num('DTCM_RAMB36')==16 and num('RAMB36')+0.5*num('RAMB18')<=48):raise ValueError('implementation structure/timing gate failed')
    for name in ('timing_summary.rpt','drc.rpt'):
        text=(root/'evidence'/name).read_text(encoding='utf-8',errors='replace')
        if re.search(r'Timing constraints are not met|LUTLP-1|^ERROR:',text,re.M):raise ValueError('implementation report contains unresolved failure: '+name)

def evaluate(root=ROOT):
    root=Path(root);checks={};snapshot=inputs(root)
    for name in ('firmware','project','unit','memory','simulate','faults','controls','implement','clean','report_simulation'):
        checks[name]=validate_receipt(root,name)
    checks['production_protection']=protection(root)
    for action in ('project','implement','report_simulation','clean'):
        if checks[action]['status']!='PASS':continue
        try:
            if action=='project':
                text=(root/'evidence/ip_status.txt').read_text(encoding='utf-8')
                if re.search(r'\|\s*(?:Locked|Upgrade required)\b',text,re.I):raise ValueError('IP status is locked or requires upgrade')
            elif action=='implement':implementation(root)
            elif action=='clean':
                details=json.loads((root/'evidence/clean_details.json').read_text(encoding='utf-8'))
                fresh=(root/details['path']).resolve()
                if not fresh.is_relative_to(root.resolve()):raise ValueError('clean build path outside demo')
                if details.get('consumed_old_dcp') is not False or not all(details['firmware_images_identical'].values()):raise ValueError('clean build provenance failed')
                for name in ('firmware','unit','memory','simulate','implement'):
                    if validate_receipt(fresh,name)['status']!='PASS':raise ValueError('clean child '+name+' lacks valid evidence')
                implementation(fresh)
            else:
                from .report import validate
                r=json.loads((root/'report/simulation/results.json').read_text(encoding='utf-8'))
                if r['source']!='simulation' or r['board_measured'] is not False:raise ValueError('simulation source mislabeled')
                for item in r['inputs']:
                    p=root/item['path']
                    if sha(p)!=item['sha256']:raise ValueError('mailbox hash changed')
                    if validate([int(x,16) for x in p.read_text().splitlines() if x.strip()])!=r['rows']:raise ValueError('report disagrees with mailbox')
        except (OSError,ValueError,KeyError,TypeError,RuntimeError) as exc:checks[action]={'status':'FAIL','reason':str(exc)}
    if not (root/'evidence/hardware_result.json').exists() and not (root/'report/hardware/results.json').exists():
        checks['hardware']={'status':'PENDING_HARDWARE','reason':'no real board capture; board connection/PCB confirmation and three physical reruns remain pending'}
    else:
        checks['hardware']=validate_receipt(root,'hardware')
        checks['report_hardware']=validate_receipt(root,'report_hardware')
        if checks['hardware']['status']=='PASS':
            try:
                from .report import validate
                r=json.loads((root/'evidence/hardware/capture_receipt.json').read_text(encoding='utf-8'))
                if r['source']!='Vivado2026.1 Hardware Manager' or r['pcb_revision_supplied']!='R11':raise ValueError('hardware provenance mismatch')
                for n in ('bit','ltx'):
                    if sha(root/('evidence/demo.'+n))!=r[n+'_sha256']:raise ValueError('programmed artifact mismatch')
                if sha(root/r['log'])!=r['log_sha256']:raise ValueError('hardware capture log mismatch')
                for i in range(3):
                    p=root/f'evidence/hardware/run_{i}.hex'
                    if sha(p)!=r['captures'][p.name]:raise ValueError('hardware capture changed')
                    validate([int(x,16) for x in p.read_text().splitlines() if x.strip()])
            except (OSError,ValueError,KeyError,TypeError) as exc:checks['hardware']={'status':'FAIL','reason':str(exc)}
    failures=[n for n,c in checks.items() if c['status']=='FAIL']
    pending=[n for n,c in checks.items() if c['status']=='PENDING_EXECUTION']
    hardware=[n for n,c in checks.items() if c['status']=='PENDING_HARDWARE']
    if inputs(root)!=snapshot:failures.append('inputs_changed_during_verify')
    status='FAIL' if failures else 'PENDING_EXECUTION' if pending else 'PENDING_HARDWARE' if hardware else 'PASS'
    return {'schema':2,'status':status,'pass':status=='PASS','checks':checks,'failures':failures,
            'pending_execution':pending,'pending_hardware':hardware,'inputs':snapshot,
            'exit_codes':{'PASS':0,'FAIL':1,'PENDING_HARDWARE':2,'PENDING_EXECUTION':3},
            'claim':'S01 establishes evidence integrity only. Functional, implementation, reproduction and hardware gates require their own current runs.'}

def main():
    archive(ROOT,ROOT/'evidence/verification_summary.json')
    save(ROOT/'evidence/verification_summary.json',{'status':'RUNNING','pass':False,'reason':'verification started'})
    try:result=evaluate()
    except Exception as exc:
        result={'schema':2,'status':'FAIL','pass':False,'reason':str(exc),'exit_codes':{'FAIL':1}}
    save(ROOT/'evidence/verification_summary.json',result)
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(result['exit_codes'][result['status']])
