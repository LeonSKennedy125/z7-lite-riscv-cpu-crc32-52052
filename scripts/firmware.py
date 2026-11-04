from pathlib import Path
import hashlib,json,os,re,shutil,struct,subprocess,time,zipfile,zlib

ROOT=Path(__file__).resolve().parents[1]
VERSION='15.2.0-1'
ASSET=f'xpack-riscv-none-elf-gcc-{VERSION}-win32-x64.zip'
DIGEST='85ef714dacd273b1dadf4af4892774520ac01915bfa6da816a56e7e41591e09e'
URL=f'https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v{VERSION}/{ASSET}'

def gcc_bin():
    return Path(os.environ.get('CRC_DEMO_GCC_BIN',str(ROOT/'tools/gcc/bin'))).resolve()

def install_toolchain():
    if os.environ.get('CRC_DEMO_GCC_BIN'):
        exe=gcc_bin()/'riscv-none-elf-gcc.exe'
        version=subprocess.check_output([str(exe),'--version'],text=True).splitlines()[0]
        if '15.2.0' not in version:raise RuntimeError('GCC15.2.0 required')
        print('DECLARED_TOOLCHAIN',version);return
    target=ROOT/'tools/gcc'
    exe=target/'bin/riscv-none-elf-gcc.exe'
    if exe.exists():
        print(subprocess.check_output([str(exe),'--version'],text=True).splitlines()[0]);return
    archive=ROOT/'tools'/ASSET;archive.parent.mkdir(parents=True,exist_ok=True)
    if not archive.exists():
        subprocess.run(['curl.exe','--fail','--location','--retry','2','--output',str(archive)+'.part',URL],check=True)
        Path(str(archive)+'.part').rename(archive)
    actual=hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual!=DIGEST:raise RuntimeError('toolchain archive SHA256 mismatch')
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            parts=Path(info.filename).parts[1:]
            if not parts:continue
            if '..' in parts:raise RuntimeError('unsafe toolchain archive path')
            out=target.joinpath(*parts)
            if info.is_dir():out.mkdir(parents=True,exist_ok=True)
            else:
                out.parent.mkdir(parents=True,exist_ok=True)
                with z.open(info) as src,out.open('wb') as dst:shutil.copyfileobj(src,dst)
    version=subprocess.check_output([str(exe),'--version'],text=True).splitlines()[0]
    data={'requested_package':'15.2.0-1.1','actual_package':VERSION,'reason':'requested tag returned HTTP404; user explicitly approved official 15.2.0-1','url':URL,'sha256':actual,'version_output':version}
    (ROOT/'evidence/toolchain.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print('TOOLCHAIN_VERIFIED',version)

def pattern(n):
    x=0x13579bdf;data=bytearray()
    for _ in range(n):
        x^=(x<<13)&0xffffffff;x^=x>>17;x^=(x<<5)&0xffffffff;x&=0xffffffff
        data.append(x&255)
    return bytes(data)

def vectors():
    data=[b'',b'123456789']+[pattern(n) for n in [1,2,3,4,7,16,64,256,1024,4096]]
    return [{'id':i,'length':len(b),'kind':'check_string' if i==1 else 'xorshift32','crc':zlib.crc32(b),'data_sha256':hashlib.sha256(b).hexdigest()} for i,b in enumerate(data)]

def generated_header():
    table=[]
    for i in range(256):
        v=i
        for _ in range(8):v=(v>>1)^(0xedb88320 if v&1 else 0)
        table.append(v)
    v=vectors();dest=ROOT/'firmware/generated.h'
    for name,key in [('expected','crc'),('lengths','length')]:
        (ROOT/f'firmware/out/{name}.hex').write_text('\n'.join(f'{x[key]:08x}' for x in v)+'\n',encoding='ascii')
    text='/* Independent host zlib reference; never generated from DUT. */\n'
    text+='static const u32 crc_table[256]={\n'+',\n'.join(','.join(f'0x{x:08x}u' for x in table[i:i+8]) for i in range(0,256,8))+'\n};\n'
    text+='static const u32 lengths[12]={'+','.join(str(x['length'])+'u' for x in v)+'};\n'
    text+='static const u32 expected[12]={'+','.join(f"0x{x['crc']:08x}u" for x in v)+'};\n'
    dest.write_text(text,encoding='utf-8')
    (ROOT/'evidence/vectors.json').write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')

def sections(elf):
    b=elf.read_bytes()
    if b[:7]!=b'\x7fELF\x01\x01\x01':raise RuntimeError('expected ELF32 little endian')
    shoff=struct.unpack_from('<I',b,32)[0];size,count,stridx=struct.unpack_from('<HHH',b,46)
    headers=[struct.unpack_from('<IIIIIIIIII',b,shoff+i*size) for i in range(count)]
    shstr=headers[stridx];names=b[shstr[4]:shstr[4]+shstr[5]]
    result=[]
    for h in headers:
        n=names[h[0]:].split(b'\0',1)[0].decode()
        result.append({'name':n,'type':h[1],'flags':h[2],'address':h[3],'size':h[5],'data':b[h[4]:h[4]+h[5]] if h[1]!=8 else b''})
    return result

def coe(p,b):
    words=struct.unpack('<'+'I'*(len(b)//4),b)
    p.write_text('memory_initialization_radix=16;\nmemory_initialization_vector=\n'+',\n'.join(f'{x:08x}' for x in words)+';\n',encoding='ascii')

def build(gcc_override=None):
    gcc=Path(gcc_override) if gcc_override else gcc_bin()/'riscv-none-elf-gcc.exe'
    if not gcc.exists():raise RuntimeError('run toolchain first')
    out=ROOT/'firmware/out';out.mkdir(parents=True,exist_ok=True)
    generated_header()
    args=[str(gcc),'-march=rv32i_zicsr','-mabi=ilp32','-msmall-data-limit=0','-mno-relax','-Os','-g',
          '-ffreestanding','-fno-builtin','-fno-pic','-fno-pie','-fno-stack-protector','-fno-tree-loop-distribute-patterns','-fstack-usage',
          '-nostdlib','-Wl,--no-relax','-Wl,--build-id=none','-Wl,-Map='+str(out/'firmware.map'),
          '-T',str(ROOT/'firmware/link.ld'),'-x','assembler-with-cpp',str(ROOT/'firmware/start.s'),'-x','none',str(ROOT/'firmware/main.c'),'-o',str(out/'firmware.elf')]
    from .evidence import command,sha
    compile_log=ROOT/'evidence'/('firmware_compile_'+str(time.time_ns())+'.log')
    command(args,ROOT,compile_log)
    dump=subprocess.check_output([str(gcc.with_name('riscv-none-elf-objdump.exe')),'-d',str(out/'firmware.elf')],text=True)
    (out/'firmware.dis').write_text(dump,encoding='utf-8')
    rom=bytearray(16384);ram=bytearray(65536);sec=sections(out/'firmware.elf');used=[]
    for s in sec:
        if not s['flags']&2 or not s['size']:continue
        a=s['address'];n=s['size']
        if s['name'] in ['.data','.sdata'] and n:raise RuntimeError('writable initialized data is forbidden')
        if 0x80000000<=a and a+n<=0x80004000:buf=rom;base=0x80000000
        elif 0x80100000<=a and a+n<=0x80110000:buf=ram;base=0x80100000
        else:raise RuntimeError('ELF allocation outside memories: '+s['name'])
        if s['type']!=8:buf[a-base:a-base+n]=s['data']
        if s['flags']&4:
            for i in range(0,n,4):
                w=int.from_bytes(s['data'][i:i+4],'little');op=w&127
                if w&3!=3 or op not in [3,0x13,0x17,0x23,0x33,0x37,0x63,0x67,0x6f,0x73] or (op==0x33 and (w>>25)==1):
                    raise RuntimeError(f'unsupported executable word {a+i:08x}: {w:08x}')
        used.append({k:s[k] for k in ['name','address','size','type','flags']})
    for name,b in [('rom',rom),('ram',ram)]:
        (out/(name+'.bin')).write_bytes(b);coe(out/(name+'.coe'),b)
        (out/(name+'.hex')).write_text('\n'.join(f'{int.from_bytes(b[i:i+4],"little"):08x}' for i in range(0,len(b),4))+'\n',encoding='ascii')
    from .firmware_audit import audit
    audit_result=audit(gcc,out,sec,dump)
    manifest={'gcc_version':subprocess.check_output([str(gcc),'--version'],text=True).splitlines()[0],
              'command':args,'compile_log':compile_log.relative_to(ROOT).as_posix(),'compile_log_sha256':sha(compile_log),
              'gcc_sha256':sha(gcc),'objdump_sha256':sha(gcc.with_name('riscv-none-elf-objdump.exe')),
              'sections':used,'rom_bytes':16384,'ram_bytes':65536,
              'images':{name:hashlib.sha256((out/name).read_bytes()).hexdigest() for name in ['firmware.elf','rom.bin','ram.bin','rom.coe','ram.coe']},'instruction_audit':audit_result}
    (ROOT/'evidence/firmware.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('FIRMWARE_PASS',[(x['name'],x['size']) for x in used])
