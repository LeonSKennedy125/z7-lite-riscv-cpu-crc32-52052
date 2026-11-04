from pathlib import Path
import hashlib,json,os,subprocess,sys,datetime as dt
R=Path(__file__).resolve().parent
BIT='717bd8cfddeecf7753c8adcff68e0ec0072c0b9ca283c28613c2ac0dd3788d5b'
LTX='facc5a5a95599c155598321dcd21d34b5d32f14b810fd7b6ef086fb8416ce6ba'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 import argparse
 p=argparse.ArgumentParser(description='ES1 runtime using preserved S05 R4 Tcl. No implicit hardware action.')
 p.add_argument('action',choices=['verify','preflight','capture'])
 p.add_argument('--vivado-bin',default='D:/XILINX/2026.1/Vivado/bin')
 p.add_argument('--identity',type=Path,help='Fresh physical identity JSON; see README')
 a=p.parse_args()
 assert sha(R/'demo.bit')==BIT and sha(R/'demo.ltx')==LTX,'Download hash mismatch'
 if a.action=='verify':print('RUNTIME_HASH_PASS');return
 # Use a new/free alias or verify an existing saved alias. Never remap an occupied drive.
 import ctypes
 record=R/'runtime_alias.json';mask=ctypes.windll.kernel32.GetLogicalDrives()
 letter=json.loads(record.read_text(encoding='utf-8'))['letter'] if record.exists() else next(x for x in 'VUTSRQPONMLKJIHGF' if not mask & (1<<(ord(x)-65)))
 if not mask & (1<<(ord(letter)-65)):subprocess.run(['subst.exe',letter+':',str(R)],cwd=R,check=True,capture_output=True)
 short=Path(letter+':/')
 assert (short/'run_board.py').is_file() and os.path.samefile(short/'run_board.py',R/'run_board.py'),'Alias maps to another directory; no remap performed'
 record.write_text(json.dumps({'letter':letter,'actual_target':str(R),'samefile_verified':True},indent=2)+'\n',encoding='utf-8')
 out=R/'captures'/dt.datetime.now().strftime('%Y%m%d_%H%M%S');out.mkdir(parents=True,exist_ok=False)
 tool_out=short/'captures'/out.name
 cfg={'out':str(tool_out),'attempt_id':out.name}
 if a.action=='capture':
  assert a.identity and a.identity.is_file(),'Fresh physical identity JSON required'
  identity=json.loads(a.identity.read_text(encoding='utf-8'))
  assert identity['pcb_revision']=='Z7-LITE_ES1' and identity['USB_serial']=='210241793374'
  assert identity['device_idcode']=='0x13722093' and identity['physical_verified'] is True
  assert identity['confirmed_for_this_capture'] is True and identity['power_and_JTAG_verified'] is True
  assert identity['device_did'] and identity['target'] and identity['observed_at']
  cfg.update(identity,baseline_verified=1,cfgbvs='VCCO',config_voltage='3.3',bit=str(short/'demo.bit'),ltx=str(short/'demo.ltx'),vio_instance='vio',vio_uuid='1BE27D511A4C50DC974F3E22D2C609B9')
 def tq(s):return '{'+str(s).replace('\\','/').replace('{','\\{').replace('}','\\}')+'}'
 pairs=' '.join(tq(k)+' '+tq(int(v) if isinstance(v,bool) else v) for k,v in cfg.items())
 entry=out/'entry.tcl';entry.write_text('source '+tq(short/'capture.tcl')+'\nset cfg [dict create '+pairs+']\ns05::execute '+a.action+' $cfg\n',encoding='utf-8')
 env=os.environ.copy();env.update(TEMP=str(tool_out),TMP=str(tool_out))
 command=[str(Path(a.vivado_bin)/'vivado.bat'),'-mode','batch','-nojournal','-log',str(tool_out/'vivado.log'),'-source',str(tool_out/'entry.tcl')]
 with (out/'stdout.log').open('wb') as stdout,(out/'stderr.log').open('wb') as stderr:
  p=subprocess.run(command,cwd=short,env=env,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
 (out/'tool_run.json').write_text(json.dumps({'command':command,'workdir':str(R),'exit_code':p.returncode,'bit_sha256':BIT,'ltx_sha256':LTX},indent=2)+'\n',encoding='utf-8')
 if p.returncode:raise SystemExit(p.returncode)
 if a.action=='capture':
  for i in range(3):
   x=out/f'run_{i}_scan_0.hex';y=out/f'run_{i}_scan_1.hex';assert x.read_bytes()==y.read_bytes(),'Unstable mailbox'
   subprocess.run([sys.executable,'-B','-X','utf8',str(R.parents[1]/'skill/scripts/verify_mailbox.py'),'--dump',str(x)],cwd=R,check=True)
  print('CAPTURE_CRC_PASS: three VIO auxiliary resets; six stable scans. Record actual PL_LED1/PL_LED2 observations separately; no LED inference.')
 print('OUTPUT',out)
if __name__=='__main__':main()
