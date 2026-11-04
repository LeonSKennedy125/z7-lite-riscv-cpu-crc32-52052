"""Fail-closed mailbox reader controls, using an actual simulation capture."""
from pathlib import Path
import json
from .report import validate,ROOT

def main():
    from .evidence import validate_receipt
    if validate_receipt(ROOT,'simulate')['status']!='PASS':raise RuntimeError('current simulation receipt required before reader controls')
    paths=list((ROOT/'b/p/demo.sim').rglob('mailbox_sim.hex'))
    if len(paths)!=1:raise RuntimeError('real simulation capture required')
    words=[int(x,16) for x in paths[0].read_text().splitlines()]
    assert len(validate(words))==12
    variants={'truncated':words[:-1],'extra_word':words+[0]}
    for label,offset,value in [('bad_magic',0,0),('firmware_error',5,1),('wrong_clock',2,160000000),('last_crc_wrong',100,words[100]^1),('missing_cycles',101,0),('bad_case_id',96,0),('inconsistent_elapsed',103,words[102]+1)]:
        w=words.copy();w[offset]=value;variants[label]=w
    rejected=[]
    for label,w in variants.items():
        try:validate(w)
        except ValueError:rejected.append(label)
        else:raise AssertionError('reader accepted '+label)
    if validate_receipt(ROOT,'faults')['status']!='PASS':raise RuntimeError('current actual firmware fault evidence required')
    faults=json.loads((ROOT/'evidence/firmware_faults.json').read_text(encoding='utf-8'))
    real_rejected=[]
    for case in faults['cases']:
        actual=[int(x,16) for x in (ROOT/case['capture']).read_text().splitlines()]
        assert actual[5]!=0
        try:validate(actual)
        except ValueError:real_rejected.append(case['model'])
        else:raise AssertionError('reader accepted actual firmware fault '+case['model'])
    result={'pass':True,'positive_captures':1,'rejected':rejected,'actual_firmware_faults_rejected':real_rejected}
    (ROOT/'evidence/reader_controls.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('READER_CONTROLS_PASS',len(rejected),'actual_firmware_faults',len(real_rejected))
