"""Fresh source implementation; retain nested debug-hub synthesis logs."""
from pathlib import Path
import hashlib, threading, time, shutil
from .evidence import command, save, sha

def build():
    from run import ROOT, BIN, short_workspace, vivado
    stamp=str(time.time_ns()); started=time.time_ns()
    out=ROOT/'evidence/run_logs'/stamp; out.mkdir(parents=True)
    stop=threading.Event(); records={}
    with short_workspace() as mapped:
        def collect():
            source=mapped(ROOT/'b/p/demo.runs')
            for p in source.rglob('*'):
                try:
                    if not p.is_file() or p.suffix.lower() not in ('.log','.vds','.vdi','.tcl','.rpt','.xci','.xdc'):continue
                    st=p.stat()
                    if st.st_mtime_ns<started:continue
                    rel='b/p/demo.runs/'+p.relative_to(source).as_posix()
                    sig=(st.st_size,st.st_mtime_ns)
                    if records.get(rel,{}).get('signature')==sig:continue
                    dest=out/(hashlib.sha256(rel.encode()).hexdigest()[:16]+'_'+p.name)
                    shutil.copyfile(p,dest)
                    records[rel]={'capture':dest.relative_to(ROOT).as_posix(),'signature':sig}
                except OSError:continue
        def monitor():
            while not stop.is_set():
                collect(); stop.wait(1)
        worker=threading.Thread(target=monitor,daemon=True);worker.start()
        try:
            command([BIN/'vivado.bat','-mode','batch','-nojournal','-log',ROOT/'evidence'/f'implement_{stamp}.log',
                     '-source',mapped(ROOT/'scripts/build.tcl'),'-tclargs','implement'],mapped(ROOT/'b'),
                    ROOT/'evidence'/f'implement_{stamp}.console.log',timeout=2400)
        finally:
            stop.set();worker.join(timeout=30);collect()
            for item in records.values():
                item.pop('signature',None); item['sha256']=sha(ROOT/item['capture'])
            save(ROOT/'evidence/run_logs_index.json',{'started_ns':started,'files':records})
    vivado('audit_routed.tcl')
