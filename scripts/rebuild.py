"""Compatibility entry; clean builds consume the actual allowlisted archive."""
def main(mode='clean'):
    if mode!='clean':raise ValueError('resource baseline is outside submission step S04')
    from pathlib import Path
    import os
    root=Path(__file__).resolve().parents[1]
    if not (Path(os.environ.get('CRC_DEMO_GCC_BIN',str(root/'tools/gcc/bin')))/'riscv-none-elf-gcc.exe').is_file():
        raise RuntimeError('run toolchain first')
    from .release import clean
    clean()
