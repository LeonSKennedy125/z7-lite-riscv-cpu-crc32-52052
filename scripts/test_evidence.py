"""S01 fault controls. Stub commands exercise evidence code, never claim DUT success."""
from pathlib import Path
import json,os,shutil,sys,time,uuid
from .evidence import attempt, command, inputs, save, sha, validate_receipt, receipt_path, artifacts
from .verify import protection,evaluate
ROOT=Path(__file__).resolve().parents[1]

def main():
    out=ROOT/'evidence/agent_steps/step_01'/('controls_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8])
    out.mkdir(parents=True)
    fixtures=ROOT/('s01t_'+uuid.uuid4().hex[:8]);fixtures.mkdir()
    cases=[]
    def fixture(label):
        root=fixtures/('c'+str(len(list(fixtures.iterdir()))));root.mkdir()
        for rel in ('run.py','src/crc_mmio.sv','src/demo_top.sv','firmware/main.c','firmware/start.s','firmware/link.ld','scripts/build.tcl'):
            p=root/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,p)
        for name in ('sim','constraints'):(root/name).mkdir(exist_ok=True)
        shutil.copy2(ROOT/'sim/tb_cpu.sv',root/'sim/tb_cpu.sv')
        shutil.copy2(ROOT/'constraints/board_r11.xdc',root/'constraints/board_r11.xdc')
        for name in ('evidence.py','verify.py','report.py','firmware.py','rebuild.py'):
            shutil.copy2(ROOT/'scripts'/name,root/'scripts'/name)
        save(root/'evidence/source_manifest.json',{'sources':[{'copy':'src/demo_top.sv','copy_sha256':sha(root/'src/demo_top.sv')}],'fixture':True})
        save(root/'evidence/toolchain.json',{'fixture':True})
        return root
    def execute(root, action, code, *, timeout=10, executable=None):
        log=root/'evidence'/('stub_'+str(time.time_ns())+'.log')
        error=None
        try:
            with attempt(root,action):
                command([executable or sys.executable,'-X','utf8','-c',code],root,log,timeout=timeout)
        except Exception as exc:error=str(exc)
        return error
    def positive(root,action='unit'):
        code="print('TEST_PASS CRC_MMIO fixture_only')"
        if action=='implement':
            names=artifacts(root,action)
            code="from pathlib import Path\n"+'\n'.join("p=Path("+repr(n)+");p.parent.mkdir(parents=True,exist_ok=True);p.write_text('S01_SYNTHETIC_FIXTURE_ONLY')" for n in names)+"\nprint('IMPLEMENTATION_COMPLETE_7010_50MHZ')"
        error=execute(root,action,code)
        assert error is None,error
        assert validate_receipt(root,action)['status']=='PASS'
    def record(label,root,expected,gate):
        verdict=validate_receipt(root,gate)
        assert verdict['status']==expected,(label,verdict)
        r=json.loads(receipt_path(root,gate).read_text())
        cases.append({'case':label,'expected':expected,'actual':verdict,'receipt':receipt_path(root,gate).relative_to(ROOT).as_posix(),
                      'receipt_sha256':sha(receipt_path(root,gate)),
                      'commands':r.get('commands',[]),'control_pass':True})
        print('CONTROL_PASS',label,expected)
    for label,code,kwargs in (
        ('old_pass_then_exit_7',"print('TEST_PASS CRC_MMIO fixture_only');raise SystemExit(7)",{}),
        ('old_pass_then_missing_marker',"print('tool finished without terminal proof')",{}),
        ('old_pass_then_commented_marker',"print('# puts TEST_PASS CRC_MMIO')",{}),
        ('old_pass_then_not_started','',{'executable':str(out/'missing_tool.exe')}),
        ('old_pass_then_timeout',"import time;time.sleep(3)",{'timeout':0.15}),
        ('zero_exit_stderr_error',"import sys;print('TEST_PASS CRC_MMIO fixture_only');print('ERROR: injected stderr failure',file=sys.stderr)",{}),
        ('inputs_change_during_tool',"from pathlib import Path; p=Path('src/crc_mmio.sv');p.write_bytes(p.read_bytes()+b'\\n// fault injection\\n');print('TEST_PASS CRC_MMIO fixture_only')",{}),
    ):
        root=fixture(label);positive(root)
        assert execute(root,'unit',code,**kwargs) is not None
        assert json.loads(receipt_path(root,'unit').read_text())['pass'] is False
        assert list((root/'evidence/history').rglob('unit_result.json'))
        record(label,root,'FAIL','unit')
    root=fixture('inputs_change_after_pass');positive(root)
    p=root/'src/crc_mmio.sv';p.write_bytes(p.read_bytes()+b'\n// changed input\n')
    record('inputs_change_after_pass',root,'PENDING_EXECUTION','unit')
    root=fixture('log_hash_changed');positive(root)
    r=json.loads(receipt_path(root,'unit').read_text());p=root/r['commands'][0]['log'];p.write_text('TEST_PASS CRC_MMIO tampered')
    record('log_hash_changed',root,'FAIL','unit')
    root=fixture('stderr_log_hash_changed');positive(root)
    r=json.loads(receipt_path(root,'unit').read_text());p=root/r['commands'][0]['stderr_log'];p.write_text('tampered stderr')
    record('stderr_log_hash_changed',root,'FAIL','unit')
    root=fixture('missing_implementation_report');positive(root,'implement')
    (root/'evidence/timing_summary.rpt').unlink()
    record('missing_implementation_report',root,'FAIL','implement')
    root=fixture('missing_report_after_old_pass');positive(root,'implement')
    assert execute(root,'implement',"print('IMPLEMENTATION_COMPLETE_7010_50MHZ')") is not None
    record('missing_report_after_old_pass',root,'FAIL','implement')
    root=fixture('legacy_boolean');save(receipt_path(root,'unit'),{'pass':True})
    record('legacy_boolean',root,'PENDING_EXECUTION','unit')
    root=fixture('standalone_export')
    p=protection(root)
    assert p['status']=='NOT_APPLICABLE' and p['original_project_checked'] is False and p['original_project_pass'] is None
    verdict=evaluate(root)
    assert verdict['status']=='PENDING_EXECUTION' and verdict['checks']['hardware']['status']=='PENDING_HARDWARE'
    save(root/'evidence/standalone_verdict.json',verdict)
    cases.append({'case':'standalone_export','control_pass':True,'protection':p,'overall':verdict['status'],'hardware':verdict['checks']['hardware']['status']})
    print('CONTROL_PASS standalone_export NOT_APPLICABLE')
    # Exercise the actual CLI and rebuild dispatch without starting Vivado.
    for gate in ('unit','clean'):
        root=fixture('cli_'+gate)
        if gate=='unit':positive(root)
        else:
            code="from pathlib import Path;Path('evidence/clean_details.json').write_text('{}');print('REBUILD_PASS clean fixture_only')"
            assert execute(root,gate,code) is None
        if gate=='unit':save(root/'evidence/build.lock',{'pid':os.getpid(),'purpose':'explicit CLI lock-conflict control; do not reach SUBST'})
        log=root/'evidence/actual_cli.log'
        previous=os.environ.get('CRC_DEMO_VIVADO_BIN')
        os.environ['CRC_DEMO_VIVADO_BIN']=str(root/'missing_vivado')
        try:
            try:command([sys.executable,'-X','utf8','run.py',gate],root,log,timeout=30)
            except RuntimeError:pass
            else:raise AssertionError('actual CLI unexpectedly passed')
        finally:
            if previous is None:os.environ.pop('CRC_DEMO_VIVADO_BIN',None)
            else:os.environ['CRC_DEMO_VIVADO_BIN']=previous
        assert json.loads(receipt_path(root,gate).read_text())['pass'] is False
        if gate=='unit':assert not (root/'evidence/drive_alias.json').exists(),'lock control reached SUBST unexpectedly'
        if gate=='clean':
            combined='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in root.rglob('*.console.log'))
            assert 'run toolchain first' in combined,combined
        record('actual_cli_'+gate+'_failure_invalidates_pass',root,'FAIL',gate)
    root=fixture('verify_missing_input')
    save(root/'evidence/verification_summary.json',{'status':'PASS','pass':True})
    (root/'constraints/board_r11.xdc').unlink()
    try:command([sys.executable,'-X','utf8','run.py','verify'],root,root/'evidence/actual_verify.log',timeout=30)
    except RuntimeError:pass
    else:raise AssertionError('verify accepted a missing required input')
    summary=json.loads((root/'evidence/verification_summary.json').read_text())
    assert summary['pass'] is False and summary['status']=='FAIL'
    cases.append({'case':'verify_missing_input_invalidates_summary','control_pass':True,'actual':summary,
                  'log':(root/'evidence/actual_verify.log').relative_to(ROOT).as_posix(),
                  'log_sha256':sha(root/'evidence/actual_verify.log')})
    print('CONTROL_PASS verify_missing_input_invalidates_summary FAIL')
    result={'status':'SELF_CHECK_PASS','scope':'evidence-checker fault injection only; all DUT markers/artifacts in child fixtures are synthetic',
            'case_count':len(cases),'cases':cases,'independent_acceptance':'PENDING','inputs':inputs(ROOT)}
    save(out/'result.json',result)
    save(ROOT/'evidence/agent_steps/step_01/controls_index.json',{'result':(out/'result.json').relative_to(ROOT).as_posix(),'sha256':sha(out/'result.json'),'case_count':len(cases)})
    print('S01_EVIDENCE_CONTROLS_PASS',len(cases),str(out.relative_to(ROOT)))

if __name__=='__main__':main()
