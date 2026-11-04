"""Review actual registered inputs, image contents, timing and resource equivalence."""
from pathlib import Path
import json,re,struct,subprocess,sys
from .evidence import save,sha,command

def timing(p):
    s=Path(p).read_text(encoding='utf-8',errors='replace')
    m=re.search(r'WNS\(ns\).*?\n\s*-+.*?\n\s*([-+\d.]+)\s+([-+\d.]+)\s+(\d+)\s+(\d+)\s+([-+\d.]+)\s+([-+\d.]+)\s+(\d+)\s+(\d+)\s+([-+\d.]+)\s+([-+\d.]+)',s,re.S)
    if not m:raise RuntimeError('timing summary fields missing')
    v=list(map(float,m.groups()))
    result=dict(zip(('WNS','TNS','setup_failed','setup_total','WHS','THS','hold_failed','hold_total','WPWS','TPWS'),v))
    if any(result[k]<0 for k in ('WNS','WHS','WPWS')) or any(result[k]!=0 for k in ('TNS','THS','TPWS','setup_failed','hold_failed')):raise RuntimeError('timing failed')
    for k in ('no_clock','constant_clock','unconstrained_internal_endpoints','multiple_clock','generated_clocks','loops','latch_loops'):
        if not re.search(r'checking '+k+r' \(0\)',s):raise RuntimeError('timing coverage incomplete '+k)
    return result

def resources(p):
    s=Path(p).read_text(encoding='utf-8')
    names=('Slice LUTs','Slice Registers','Block RAM Tile','DSPs')
    out={}
    for n in names:
        m=re.search(r'^\|\s*'+re.escape(n)+r'\s*\|\s*([\d.]+)\s*\|',s,re.M)
        if not m:raise RuntimeError('resource field missing '+n)
        out[n]=float(m[1])
    return out

def audit(root,candidate=None):
    root=Path(root);out=root/'evidence/dependencies';out.mkdir(exist_ok=True)
    manifest=json.loads((root/'release_manifest.json').read_text(encoding='utf-8'))
    changed=[n for n,h in manifest['files'].items() if sha(root/n)!=h]
    if changed:raise RuntimeError('packaged inputs changed '+str(changed))
    alias=json.loads((root/'evidence/drive_alias.json').read_text(encoding='utf-8'))['letter']+':'
    tool=Path(json.loads((root/'evidence/tool_locations.json').read_text())['environment']['CRC_DEMO_VIVADO_BIN']).parent.resolve()
    registered=[]
    for line in (out/'registered_files.tsv').read_text().splitlines()[1:]:
        name,kind,exists=line.split('\t')
        mapped=str(root)+name[2:] if name[:2].lower()==alias.lower() else name
        p=Path(mapped).resolve()
        if not (p.is_relative_to(root.resolve()) or p.is_relative_to(tool)):raise RuntimeError('external registered dependency '+name)
        if exists!='1':raise RuntimeError('missing registered dependency '+name)
        registered.append({'path':name,'class':kind})
    excluded=json.loads((root/'evidence/provenance/excluded_sources.json').read_text())['unused_core_files']
    for n in excluded:
        if (root/'src/core'/n).exists():raise RuntimeError('excluded source included '+n)
    mif=[]
    for module,image in [('DTCM','ram.bin'),('I_ROM','rom.bin')]:
        binary=(root/'data/frozen'/image).read_bytes()
        words=list(struct.unpack('<'+'I'*(len(binary)//4),binary))
        paths=list((root/'b/p').rglob(module+'.mif'))
        if not paths:raise RuntimeError('generated MIF missing '+module)
        for p in paths:
            actual=[int(x,2) for x in p.read_text().splitlines() if x.strip()]
            if actual!=words:raise RuntimeError('generated MIF differs '+str(p))
            mif.append({'path':p.relative_to(root).as_posix(),'sha256':sha(p),'words':len(words),'matches_frozen_image':True})
    # Explicit mode must win even with a real production XPR in an ancestor.
    code="import run; from scripts.verify import protection; assert run.STANDALONE and run.ACTIVE is None and run.WORKSPACE is None; p=protection(run.ROOT); assert p['status']=='NOT_APPLICABLE' and p['original_project_pass'] is None; print('EXPLICIT_STANDALONE_PASS');\ntry: run.snapshot()\nexcept RuntimeError: print('PRODUCTION_FALLBACK_REJECTED')\nelse: raise AssertionError('production fallback enabled')"
    command([sys.executable,'-B','-X','utf8','-c',code],root,out/'explicit_mode.console.log',timeout=30,marker=r'^PRODUCTION_FALLBACK_REJECTED$')
    current_timing=timing(root/'evidence/static/timing_summary.rpt')
    previous_timing=timing(root/'evidence/provenance/s03/timing_summary.rpt')
    current_resources=resources(root/'evidence/utilization.rpt')
    previous_resources=resources(root/'evidence/provenance/s03/utilization.rpt')
    if current_resources!=previous_resources:raise RuntimeError('resource usage changed '+str((current_resources,previous_resources)))
    structural=(root/'evidence/static/structural_summary.txt').read_text()
    for expected in ('DTCM_RAMB36=16','DTCM_ASYNC_CONTROL_SOURCES=0','DTCM_CONTROL_PINS_CHECKED=128'):
        if expected not in structural:raise RuntimeError('structure mismatch '+expected)
    result={'status':'PASS','registered_file_count':len(registered),'registered_files_sha256':sha(out/'registered_files.tsv'),
        'package_input_count':len(manifest['files']),'all_package_hashes_match':True,'excluded_unused_core_files':excluded,
        'explicit_standalone':True,'ancestor_projects_may_exist':True,'original_production_check':'NOT_APPLICABLE',
        'new_generated_alias':alias,'alias_samefile_checked':True,'old_Z_drive_consumed':alias.upper()=='Z:',
        'images_mif':mif,'s03_timing':previous_timing,'clean_timing':current_timing,
        's03_resources':previous_resources,'clean_resources':current_resources,'resources_equal':True,
        'bitstream_byte_equality_required':False,'board_measured':False,'other_machine_tested':False,
        'audit_scope':'Vivado registered/compile/include/COE inputs, generated MIF contents, package hashes, actual commands and explicit Python source-discovery rejection; not an OS filesystem trace'}
    save(out/'audit.json',result)
    return {'path':'evidence/dependencies/audit.json','sha256':sha(out/'audit.json'),'status':'PASS'}
