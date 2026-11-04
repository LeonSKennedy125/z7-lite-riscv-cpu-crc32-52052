from pathlib import Path
import csv,hashlib,html,json
from .firmware import vectors
ROOT=Path(__file__).resolve().parents[1]

def validate(words):
    if len(words)!=104:raise ValueError('mailbox must contain exactly 104 words')
    if words[:8]!=[0x43524331,1,50000000,65536,12,0,104,7]:raise ValueError('invalid mailbox header or firmware failure')
    rows=[]
    for v in vectors():
        i=v['id'];r=words[8+8*i:16+8*i]
        if r[:5]!=[i,v['length'],v['crc'],v['crc'],v['crc']]:raise ValueError(f'independent zlib reference mismatch case {i}')
        if not (0<r[5]<10000000 and 0<r[6]<10000000 and 0<=r[7]<=r[6]):raise ValueError(f'invalid cycle measurements {i}')
        rows.append(dict(case=i,bytes=r[1],reference_crc=f'{r[2]:08x}',software_crc=f'{r[3]:08x}',hardware_crc=f'{r[4]:08x}',
                         software_cycles=r[5],hardware_total_cycles=r[6],engine_session_cycles=r[7],
                         speedup=r[5]/r[6],software_us=r[5]/50,hardware_total_us=r[6]/50))
    return rows

def main(source='simulation'):
    from .evidence import validate_receipt
    gate='hardware' if source=='hardware' else 'simulate'
    checked=validate_receipt(ROOT,gate)
    if checked['status']!='PASS':raise RuntimeError('current '+gate+' evidence required: '+str(checked))
    out=ROOT/'report'/source;out.mkdir(parents=True,exist_ok=True)
    if source=='hardware':
        if validate_receipt(ROOT,'implement')['status']!='PASS':raise RuntimeError('current implementation evidence required')
        receipt_path=ROOT/'evidence/hardware/capture_receipt.json'
        if not receipt_path.exists():raise RuntimeError('actual Hardware Manager capture receipt required; simulation cannot be relabelled as hardware')
        receipt=json.loads(receipt_path.read_text(encoding='utf-8'))
        if receipt['source']!='Vivado2026.1 Hardware Manager' or receipt['pcb_revision_supplied']!='R11':raise RuntimeError('invalid hardware provenance')
        for file,key in [('demo.bit','bit_sha256'),('demo.ltx','ltx_sha256')]:
            if hashlib.sha256((ROOT/'evidence'/file).read_bytes()).hexdigest()!=receipt[key]:raise RuntimeError('hardware capture is for a different bitstream/probe set')
        log=ROOT/receipt['log']
        if hashlib.sha256(log.read_bytes()).hexdigest()!=receipt['log_sha256']:raise RuntimeError('hardware capture log changed')
        files=[ROOT/f'evidence/hardware/run_{i}.hex' for i in range(3)]
        for f in files:
            if hashlib.sha256(f.read_bytes()).hexdigest()!=receipt['captures'][f.name]:raise RuntimeError('hardware capture data changed')
    else:
        base=list((ROOT/'b/p/demo.sim').rglob('mailbox_sim.hex'))
        if len(base)!=1:raise RuntimeError('exactly one current simulation mailbox required')
        files=[base[0].parent/f'mailbox_sim_run_{i}.hex' for i in range(3)]
        if any(not f.is_file() for f in files):raise RuntimeError('three actual simulation reset captures required')
    reports=[]
    for f in files:
        words=[int(s,16) for s in f.read_text().splitlines() if s.strip()]
        reports.append(validate(words))
    rows=reports[0]
    result={'source':source,'board_measured':source=='hardware','runs':len(files),'pass':True,'rows':rows,
            'per_run_rows':reports,
            'inputs':[{'path':f.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in files],
            'timing_definition':'50MHz raw ticks; hardware_total includes abort/config/start, CPU feed, polling and RESULT read; engine_session includes feed gaps'}
    (out/'results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    with (out/'results.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    title='真实板级实测' if source=='hardware' else 'XSim行为仿真结果（尚非上板实测）'
    table=''.join('<tr>'+''.join(f'<td>{html.escape(str(r[k]))}</td>' for k in ['case','bytes','reference_crc','software_cycles','hardware_total_cycles','speedup'])+'</tr>' for r in rows)
    width=800;bars=[];maxval=max(max(r['software_cycles'],r['hardware_total_cycles']) for r in rows)
    for i,r in enumerate(rows):
        y=32+i*35
        bars.append(f'<text x="0" y="{y+12}">{r["bytes"]} B</text><rect x="75" y="{y}" width="{r["software_cycles"]*650/maxval:.2f}" height="12" fill="#396cba"/><rect x="75" y="{y+13}" width="{r["hardware_total_cycles"]*650/maxval:.2f}" height="12" fill="#e68a35"/>')
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="800" height="470"><text x="0" y="16">Blue: table CRC software; orange: hardware full call; unit: CPU cycles</text>'+''.join(bars)+'</svg>'
    (out/'cycles.svg').write_text(svg,encoding='utf-8')
    page=f'<!doctype html><meta charset="utf-8"><title>CRC32结果</title><style>body{{font:16px sans-serif;max-width:1000px;margin:32px auto}}td,th{{padding:6px;border:1px solid #ccc}}table{{border-collapse:collapse}}.label{{background:#fff0c8;padding:16px}}</style><h1>自研RISC-V＋CRC32</h1><p class="label">{title}；64KiB RAM，50MHz；{len(files)}次结果核对通过。</p><p>主要软件基线为256项查表CRC；加速比包含数据搬运。CRC用于差错检测。</p>{svg}<table><tr><th>测试</th><th>字节</th><th>CRC</th><th>软件周期</th><th>硬件完整调用周期</th><th>加速比</th></tr>{table}</table>'
    (out/'index.html').write_text(page,encoding='utf-8')
    print('REPORT_PASS',source,'rows',len(rows),'runs',len(files))
