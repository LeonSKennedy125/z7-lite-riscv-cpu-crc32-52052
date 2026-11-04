"""Actual CPU firmware faults: suppress DONE or set ERROR on STATUS reads only."""
from pathlib import Path
import json,re,time
from .evidence import validate_receipt,save,sha
from .report import validate,ROOT

def main(vivado):
    for gate in ('firmware','simulate'):
        checked=validate_receipt(ROOT,gate)
        if checked['status']!='PASS':raise RuntimeError('current '+gate+' receipt required: '+str(checked))
    out=ROOT/'evidence/faults'/str(time.time_ns());out.mkdir(parents=True)
    cases=[]
    for model,number in [('timeout',1),('error',2)]:
        log=vivado('build.tcl','fault_'+model).with_suffix('.console.log')
        transcript=log.read_text(encoding='utf-8',errors='replace')
        marker=rf'^TEST_PASS CPU_FIRMWARE_FAULT model={number} errors={3-number} aborts={2-number} polls=\d+;'
        if not re.search(marker,transcript,re.M):raise RuntimeError('missing exact firmware fault terminal proof: '+model)
        if not re.search(r'^FAULT_CPU_ERROR_STORE ',transcript,re.M):raise RuntimeError('no actual CPU error-variable write')
        if model=='timeout' and not re.search(r'^FAULT_TIMEOUT_ABORT elapsed=',transcript,re.M):raise RuntimeError('no timeout abort')
        paths=list((ROOT/'b/p/demo.sim').rglob('mailbox_fault_'+model+'.hex'))
        if len(paths)!=1:raise RuntimeError('exactly one fault capture required: '+model)
        capture=out/(model+'.hex');capture.write_bytes(paths[0].read_bytes())
        words=[int(x,16) for x in capture.read_text().splitlines()]
        if len(words)!=104 or words[5]!=3-number:raise RuntimeError('unexpected firmware failure count')
        try:validate(words)
        except ValueError as exc:rejection=str(exc)
        else:raise RuntimeError('host accepted actual firmware fault capture as normal PASS')
        cases.append({'model':model,'status':'EXPECTED_FAULT_VERIFIED','firmware_errors':words[5],
                      'host_normal_result':'REJECTED','host_reason':rejection,
                      'capture':capture.relative_to(ROOT).as_posix(),'capture_sha256':sha(capture),
                      'log':log.relative_to(ROOT).as_posix(),'log_sha256':sha(log)})
        print('FIRMWARE_FAULT_VERIFIED',model,'errors',words[5],'host_rejected',rejection)
    for gate in ('firmware','simulate'):
        if validate_receipt(ROOT,gate)['status']!='PASS':raise RuntimeError('fault run changed normal inputs or artifacts: '+gate)
    save(ROOT/'evidence/firmware_faults.json',{'pass':True,'source':'simulation','scope':'expected injected faults; not normal DUT PASS',
         'firmware_modified':False,'golden_modified':False,'fault_model':'testbench STATUS read response only; original TICKS and timeout threshold',
         'cases':cases})
    print('FIRMWARE_FAULT_CONTROLS_PASS models=2 actual_cpu_branches=2 host_rejections=2')
