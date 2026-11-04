"""Strict RV32I/Zicsr encoding and memory/ABI checks on the actual linked ELF."""
import json,re,struct,time
from .evidence import command,sha

def instruction(w):
    op=w&127; f3=(w>>12)&7; f7=w>>25
    legal=(w&3)==3 and (
        op in (0x17,0x37,0x6f) or
        op==0x67 and f3==0 or
        op==3 and f3 in (0,1,2,4,5) or
        op==0x23 and f3 in (0,1,2) or
        op==0x63 and f3 in (0,1,4,5,6,7) or
        op==0x13 and (f3 not in (1,5) or f3==1 and f7==0 or f3==5 and f7 in (0,32)) or
        op==0x33 and (f7==0 or f7==32 and f3 in (0,5)) or
        op==0x73 and (f3 in (1,2,3,5,6,7) or w in (0x73,0x100073,0x30200073)))
    if not legal:raise RuntimeError(f'unsupported RV32I/Zicsr encoding {w:08x}')
    regs=[]
    if op not in (0x23,0x63):regs.append((w>>7)&31)
    if op not in (0x17,0x37,0x6f) and not (op==0x73 and f3>=5):regs.append((w>>15)&31)
    if op in (0x23,0x33,0x63):regs.append((w>>20)&31)
    if 3 in regs:raise RuntimeError('GP/small-data register dependency')

def audit(gcc,out,sections,dump):
    root=out.parents[1];elf=out/'firmware.elf';blob=elf.read_bytes()
    if struct.unpack_from('<HH',blob,16)!=(2,243) or struct.unpack_from('<I',blob,36)[0]!=0:
        raise RuntimeError('expected executable RISC-V ILP32 soft-float ELF without RVC/RVE flags')
    count=0
    for s in sections:
        if s['flags']&2 and s['size']:
            if s['flags']&1 and s['type']!=8:raise RuntimeError('initialized writable allocation: '+s['name'])
            if s['flags']&4:
                if s['address']%4 or s['size']%4:raise RuntimeError('unaligned executable section')
                for i in range(0,s['size'],4):instruction(int.from_bytes(s['data'][i:i+4],'little'));count+=1
    logs={};tool_logs=[]
    for tool,args in [('nm',['-n',str(elf)]),('readelf',['-h','-A','-l','-r',str(elf)])]:
        log=root/'evidence'/('firmware_'+tool+'_'+str(time.time_ns())+'.log')
        command([gcc.with_name('riscv-none-elf-'+tool+'.exe'),*args],root,log)
        logs[tool]=log.read_text(encoding='utf-8')
        (out/(tool+'.txt')).write_text(logs[tool],encoding='utf-8')
        tool_logs.append(log.relative_to(root).as_posix())
    symbols={m[2]:int(m[1],16) for m in re.finditer(r'^([0-9a-fA-F]+)\s+\w\s+(\S+)\s*$',logs['nm'],re.M)}
    lo,hi,top,err=[symbols[k] for k in ('__bss_start','__bss_end','__stack_top','errors')]
    if not (0x80100000<=lo<=err<hi<=top-4096 and top==0x80110000 and (lo|hi|top)%4==0):
        raise RuntimeError('BSS/stack boundary violation')
    arch=re.search(r'Tag_RISCV_arch:\s*"([^"]+)"',logs['readelf'])
    if not arch or not re.fullmatch(r'rv32i[0-9p]+_zicsr[0-9p]+',arch[1]):raise RuntimeError('ELF architecture attribute mismatch')
    if not re.search(r'There are no relocations',logs['readelf']):raise RuntimeError('unexpected linked relocations')
    frames=[]
    for file in sorted(out.glob('*.su')):
        for line in file.read_text().splitlines():
            fields=line.split('\t')
            if len(fields)!=3 or fields[2]!='static':raise RuntimeError('unbounded stack usage: '+line)
            frames.append({'function':fields[0],'bytes':int(fields[1])})
    if not frames or sum(x['bytes'] for x in frames)>4096:raise RuntimeError('stack reserve exceeded')
    (out/'symbols.hex').write_text(''.join(f'{v:08x}\n' for v in (lo,hi,err,top)),encoding='ascii')
    result={'pass':True,'isa':arch[1],'abi':'ILP32','executable_words':count,'gp_dependency':False,
            'relocations':0,'writable_initialized_bytes':0,'bss_start':lo,'bss_end':hi,
            'errors_address':err,'stack_top':top,'stack_reserved_bytes':4096,
            'static_frames':frames,'conservative_static_frame_sum':sum(x['bytes'] for x in frames),
            'stack_analysis_scope':'current nonrecursive firmware call graph; sum of all static frames',
            'tool_logs':tool_logs,'tools':{k:sha(gcc.with_name('riscv-none-elf-'+k+'.exe')) for k in ('nm','readelf')}}
    (out/'audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    return result
