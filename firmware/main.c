typedef unsigned int u32;
typedef unsigned char u8;
#include "generated.h"
#define REG(o) (*(volatile u32 *)(0x80200100u+(o)))
#define MB(i) (*(volatile u32 *)(0x80200200u+4u*(i)))
typedef u32 alias_u32 __attribute__((__may_alias__));
static u8 data[4096] __attribute__((aligned(4)));
static const u8 check_string[9]={'1','2','3','4','5','6','7','8','9'};
static u32 errors;
static u32 ticks(void) { return REG(0x18); }
static void barrier(void) { __asm__ volatile ("" ::: "memory"); }
__attribute__((noinline)) static u32 software_crc(const u8 *p,u32 n) {
    u32 c=0xffffffffu;
    while(n--) c=crc_table[(c^*p++)&255u]^(c>>8);
    return c^0xffffffffu;
}
__attribute__((noinline)) static u32 bitwise_crc(const u8 *p,u32 n) {
    u32 c=0xffffffffu;
    while(n--) { c^=*p++; for(u32 i=0;i<8;i++) c=(c>>1)^((0u-(c&1u))&0xedb88320u); }
    return c^0xffffffffu;
}
__attribute__((noinline)) static u32 hardware_crc(const u8 *p,u32 n) {
    REG(0)=2; REG(8)=n; REG(0)=1;
    /* Payload is four-byte aligned; full words avoid per-byte packing overhead. */
    while(n>=4) { REG(0x0c)=*(const alias_u32 *)p; p+=4;n-=4; }
    if(n) {
        u32 w=p[0];
        if(n>1)w|=(u32)p[1]<<8;
        if(n>2)w|=(u32)p[2]<<16;
        REG(0x0c)=w;
    }
    u32 start=ticks();
    while(!(REG(4)&2u)) {
        if((u32)(ticks()-start)>=(1u<<20)) { errors++;REG(0)=2;return 0; }
    }
    if(REG(4)&4u) errors++;
    return REG(0x10);
}
static void fill(u32 n) {
    u32 x=0x13579bdfu;
    for(u32 i=0;i<n;i++) { x^=x<<13;x^=x>>17;x^=x<<5;data[i]=(u8)x; }
}
static void boundaries(void) {
    volatile u32 *first=(volatile u32 *)0x80100000u;
    volatile u32 *last=(volatile u32 *)0x8010fffcu;
    volatile u32 *outside=(volatile u32 *)0x80110000u;
    u32 saved=*last;
    *first=0xa56c39e1u;*last=0x19375bd2u;
    if(*first!=0xa56c39e1u || *last!=0x19375bd2u)errors++;
    *outside=0xdeadbeefu;
    if(*outside!=0 || *first!=0xa56c39e1u)errors++;
    *((volatile u8 *)0x8010ffffu)=0x81;
    if(*last!=0x81375bd2u)errors++;
    *last=saved;
}
int main(void) {
    boundaries();
    for(u32 k=0;k<12;k++) {
        u32 n=lengths[k];fill(n);
        if(k==1)for(u32 j=0;j<9;j++)data[j]=check_string[j];
        u32 bit=bitwise_crc(data,n);
        barrier();u32 t0=ticks();u32 sw=software_crc(data,n);u32 sw_time=ticks()-t0;barrier();
        t0=ticks();u32 hw=hardware_crc(data,n);u32 hw_time=ticks()-t0;barrier();
        if(bit!=expected[k] || sw!=expected[k] || hw!=expected[k])errors++;
        u32 j=8+(k<<3);
        MB(j)=k;MB(j+1)=n;MB(j+2)=expected[k];MB(j+3)=sw;MB(j+4)=hw;
        MB(j+5)=sw_time;MB(j+6)=hw_time;MB(j+7)=REG(0x14);
    }
    fill(4096);data[17]^=1u;
    if(software_crc(data,4096)==expected[11] || hardware_crc(data,4096)==expected[11])errors++;
    data[17]^=1u;
    if(software_crc(data,4096)!=expected[11] || hardware_crc(data,4096)!=expected[11])errors++;
    MB(0)=0x43524331u;MB(1)=1;MB(2)=50000000;MB(3)=65536;
    MB(4)=12;MB(5)=errors;MB(6)=104;MB(7)=0x00000007u;
    REG(0x1c)=1;
    for(;;) __asm__ volatile ("nop");
}
