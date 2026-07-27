/*
 * main.h — GPU bringup header for MicroBlaze V / Genesys 2
 * 3-core configuration
 *
 * All addresses are byte-addressed from the MicroBlaze perspective.
 * GPU instruction and data words are 16-bit.
 * Timer assumes 100 MHz sys_clk (1 count = 10 ns).
 */

#ifndef main_h
#define main_h

#include "xil_io.h"
#include "xparameters.h"
#include <stdint.h>

/* ============================================================
 * TYPES
 * ============================================================ */
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;


/* ============================================================
 * INSTRUCTION MEMORY  (axi_bram_ctrl_1 → imem_partition)
 *
 * GPU instructions are 16-bit. The AXI BRAM controller is 32-bit wide,
 * so two GPU instructions are packed into each 32-bit AXI write.
 * MicroBlaze broadcasts each write to all warp banks simultaneously.
 *
 * Packing layout per 32-bit AXI word at IMEM_BASE + i*4:
 *   bits [15: 0] → GPU PC (2i)   — even instruction
 *   bits [31:16] → GPU PC (2i+1) — odd instruction
 *
 * PACK(even, odd): builds one 32-bit AXI word from two 16-bit GPU instructions.
 * ============================================================ */
#define IMEM_BASE           0xC2000000u
#define IMEM_AXI_WORDS      512             /* 32-bit AXI words per bank     */
#define IMEM_GPU_INSTRS     1024            /* 16-bit GPU instructions/bank  */

#define PACK(even, odd) ((u32)(((u32)(odd) << 16) | ((u32)(even) & 0xFFFF)))


/* ============================================================
 * DDR3 (via MIG AXI4 interface)
 *
 * MicroBlaze sees DDR3 as a byte-addressed memory region starting at
 * MIG's base address. The MIG is configured for 1 GB total capacity,
 * but for a soft processor like MicroBlaze V you'll typically only
 * exercise the first few MB. Accesses are uncached from MicroBlaze's
 * perspective unless caches are explicitly enabled and configured.
 *
 * Use Xil_In32/Xil_Out32 for word access. Word-aligned addresses only —
 * AXI BRAM/MIG interfaces will misbehave on unaligned 32-bit accesses.
 * ============================================================ */
#define DDR3_BASE           0x80000000u
#define DDR3_SIZE_BYTES     0x40000000u    /* 1 GB total                    */

static inline u32 ddr3_read32(u32 byte_offset) {
    return Xil_In32(DDR3_BASE + byte_offset);
}

static inline void ddr3_write32(u32 byte_offset, u32 val) {
    Xil_Out32(DDR3_BASE + byte_offset, val);
}


/* ============================================================
 * DATA MEMORY  (axi_bram_ctrl_0 → stock BMG port B)
 *
 * The GPU memory controller word-addresses DMEM in 16-bit units.
 * GPU address N maps to AXI byte offset N*2.
 *
 * One 128-bit BRAM line holds 8 consecutive 16-bit GPU words.
 * The memory controller selects the correct 16-bit slot within the
 * line using: lane_addr[2:0] → wen = 16'h0003 << (lsb * 2)
 * ============================================================ */
#define DMEM_BASE           0xC0000000u

static inline u16 dmem_read16(u32 gpu_addr)            { return Xil_In16(DMEM_BASE + gpu_addr * 2); }
static inline void dmem_write16(u32 gpu_addr, u16 val) { Xil_Out16(DMEM_BASE + gpu_addr * 2, val); }
static inline u32 dmem_read32(u32 gpu_addr)            { return Xil_In32(DMEM_BASE + gpu_addr * 2); }
static inline void dmem_write32(u32 gpu_addr, u32 val) { Xil_Out32(DMEM_BASE + gpu_addr * 2, val); }

/* Zero n_words consecutive 16-bit GPU words starting at gpu_addr.
 * Written in 32-bit chunks so n_words should be even; rounds up if odd. */
static inline void dmem_clear(u32 gpu_addr_start, int n_words) {
    int n32 = (n_words + 1) / 2;
    for (int i = 0; i < n32; i++)
        dmem_write32(gpu_addr_start + i * 2, 0x0);
}

/* ============================================================
 * AXI CDMA  (axi_cdma_0)
 *
 * Memory-to-memory DMA engine for bulk DMEM loading. Configured
 * for 128-bit data width (matches DMEM BRAM port A), 16-beat
 * bursts, no scatter gather.
 *
 * Typical use: pre-stage matrix data in DDR3 at boot, then
 * blast it into a DMEM workspace with one cdma_transfer() call.
 *
 * The CDMA is an AXI bus master — source and destination
 * addresses must be the same byte addresses MicroBlaze uses
 * (DDR3_BASE + offset for source, DMEM_BASE + offset for dest).
 *
 * Alignment: source and destination must be 16-byte aligned
 * (128-bit data width). All DMEM bases (0x000, 0x100, 0x200)
 * map to byte offsets 0x000, 0x200, 0x400 — all 16-byte aligned.
 *
 * Transfer size in bytes. A 16×16 matrix of 16-bit words = 512 bytes.
 * ============================================================ */
#define CDMA_BASE           0x44A00000u
#define CDMA_CR             (CDMA_BASE + 0x00)   /* control register       */
#define CDMA_SR             (CDMA_BASE + 0x04)   /* status register        */
#define CDMA_SA             (CDMA_BASE + 0x18)   /* source address         */
#define CDMA_DA             (CDMA_BASE + 0x20)   /* destination address    */
#define CDMA_BTT            (CDMA_BASE + 0x28)   /* bytes to transfer      */

/* Status register bits */
#define CDMA_SR_IDLE        (1u << 1)
#define CDMA_SR_DECERR      (1u << 6)
#define CDMA_SR_SLVERR      (1u << 5)

/* Control register bits */
#define CDMA_CR_RESET       (1u << 2)

static inline void cdma_reset(void) {
    Xil_Out32(CDMA_CR, CDMA_CR_RESET);
    while (Xil_In32(CDMA_CR) & CDMA_CR_RESET);
}

static inline int cdma_transfer(u32 src_addr, u32 dst_addr, u32 bytes) {
    Xil_Out32(CDMA_SA, src_addr);
    Xil_Out32(CDMA_DA, dst_addr);
    Xil_Out32(CDMA_BTT, bytes);              /* writing BTT starts xfer */
    while (!(Xil_In32(CDMA_SR) & CDMA_SR_IDLE));
    u32 sr = Xil_In32(CDMA_SR);
    return (sr & (CDMA_SR_DECERR | CDMA_SR_SLVERR)) ? -1 : 0;
}

/* ---- DMEM bulk helpers ---- */

/* GPU word address + workspace offset → AXI byte address */
#define DMEM_BYTE_ADDR(gpu_addr)  (DMEM_BASE + (u32)(gpu_addr) * 2)

/* Transfer a matrix from DDR3 into a DMEM workspace.
 * ddr3_offset: byte offset from DDR3_BASE where matrix is staged.
 * ws:          workspace word offset (WS_A=0x0000 or WS_B=0x4000).
 * mat_base:    matrix base within workspace (MAT_A_BASE, etc).
 * bytes:       transfer size (512 for 16×16 × 16-bit). */
static inline int cdma_load_matrix(u32 ddr3_offset, u32 ws, u32 mat_base, u32 bytes) {
    return cdma_transfer(DDR3_BASE + ddr3_offset,
                         DMEM_BYTE_ADDR(ws + mat_base),
                         bytes);
}

/* Zero a region of DMEM via CDMA. Requires a zeroed staging buffer
 * in DDR3. Stage once at boot with ddr3_clear_region(). */
#define DDR3_ZERO_BUF_OFFSET    0x00F00000u   /* 15 MB in, well past kernel lib */
#define DDR3_ZERO_BUF_SIZE      1024u         /* enough for any single matrix   */

static inline void ddr3_clear_region(void) {
    for (u32 i = 0; i < DDR3_ZERO_BUF_SIZE; i += 4)
        ddr3_write32(DDR3_ZERO_BUF_OFFSET + i, 0x00000000);
    fence();
}

/* Sentinel-fill (0xFFFF) a DMEM region via CDMA.
 * Same idea — stage a sentinel buffer in DDR3. */
#define DDR3_SENTINEL_BUF_OFFSET  0x00F01000u
#define DDR3_SENTINEL_BUF_SIZE    1024u

static inline void ddr3_sentinel_region(void) {
    for (u32 i = 0; i < DDR3_SENTINEL_BUF_SIZE; i += 4)
        ddr3_write32(DDR3_SENTINEL_BUF_OFFSET + i, 0xFFFFFFFF);
    fence();
}

static inline int cdma_clear_matrix(u32 ws, u32 mat_base, u32 bytes) {
    return cdma_transfer(DDR3_BASE + DDR3_SENTINEL_BUF_OFFSET,
                         DMEM_BYTE_ADDR(ws + mat_base),
                         bytes);
}

/* ============================================================
 * GPU CONTROL GPIO  (axi_gpio_0)
 *
 * Channel 1 (offset 0x00): output — 10-bit control register
 *   Bit [0] — Core 0 GPU reset (active-high)
 *   Bit [1] — Session counter reset (active-high)
 *   Bit [2] — Core 0 DMEM address space select
 *   Bit [3] — Core 0 IMEM address space select
 *   Bit [4] — Core 1 GPU reset
 *   Bit [5] — Core 1 DMEM address space select
 *   Bit [6] — Core 1 IMEM address space select
 *   Bit [7] — Core 2 GPU reset
 *   Bit [8] — Core 2 DMEM address space select
 *   Bit [9] — Core 2 IMEM address space select
 *
 * Channel 2 (offset 0x08): input — 3-bit done status
 *   Bit [0] — Core 0 done
 *   Bit [1] — Core 1 done
 *   Bit [2] — Core 2 done
 * ============================================================ */
#define GPIO_BASE               0x40000000u
#define GPIO_CTRL_OUT           (GPIO_BASE + 0x00)
#define GPIO_DONE_IN            (GPIO_BASE + 0x08)

/* ---- Core 0 bits ---- */
#define GPU0_RESET_BIT          (1u << 0)
#define SESSION_CLK_RESET_BIT   (1u << 1)
#define DMEM0_SPACE_BIT         (1u << 2)
#define IMEM0_SPACE_BIT         (1u << 3)

/* ---- Core 1 bits ---- */
#define GPU1_RESET_BIT          (1u << 4)
#define DMEM1_SPACE_BIT         (1u << 5)
#define IMEM1_SPACE_BIT         (1u << 6)

/* ---- Core 2 bits ---- */
#define GPU2_RESET_BIT          (1u << 7)
#define DMEM2_SPACE_BIT         (1u << 8)
#define IMEM2_SPACE_BIT         (1u << 9)

/* ---- Backward-compatible aliases ---- */
#define GPU_RESET_BIT           GPU0_RESET_BIT
#define DMEM_SPACE_BIT          DMEM0_SPACE_BIT
#define IMEM_SPACE_BIT          IMEM0_SPACE_BIT

/* ---- Composite states ---- */
#define ALL_HOLD                (GPU0_RESET_BIT | GPU1_RESET_BIT | GPU2_RESET_BIT)
#define ALL_HOLD_CLK_HOLD       (ALL_HOLD | SESSION_CLK_RESET_BIT)
#define ALL_HOLD_CLK_RUN        (ALL_HOLD)
#define ALL_RUN_CLK_RUN         (0x0u)

/* Legacy aliases */
#define BOTH_HOLD               ALL_HOLD
#define BOTH_HOLD_CLK_HOLD      ALL_HOLD_CLK_HOLD
#define BOTH_HOLD_CLK_RUN       ALL_HOLD_CLK_RUN
#define BOTH_RUN_CLK_RUN        ALL_RUN_CLK_RUN

/* Module-level state */
static u32 ctrl_bits = ALL_HOLD_CLK_HOLD;

/* ---- Address space selection (core 0) ---- */
static inline void set_dmem_space(u32 space) {
    if (space) ctrl_bits |= DMEM0_SPACE_BIT;
    else       ctrl_bits &= ~DMEM0_SPACE_BIT;
}
static inline void set_imem_space(u32 space) {
    if (space) ctrl_bits |= IMEM0_SPACE_BIT;
    else       ctrl_bits &= ~IMEM0_SPACE_BIT;
}

/* ---- Address space selection (core 1) ---- */
static inline void set_dmem1_space(u32 space) {
    if (space) ctrl_bits |= DMEM1_SPACE_BIT;
    else       ctrl_bits &= ~DMEM1_SPACE_BIT;
}
static inline void set_imem1_space(u32 space) {
    if (space) ctrl_bits |= IMEM1_SPACE_BIT;
    else       ctrl_bits &= ~IMEM1_SPACE_BIT;
}

/* ---- Address space selection (core 2) ---- */
static inline void set_dmem2_space(u32 space) {
    if (space) ctrl_bits |= DMEM2_SPACE_BIT;
    else       ctrl_bits &= ~DMEM2_SPACE_BIT;
}
static inline void set_imem2_space(u32 space) {
    if (space) ctrl_bits |= IMEM2_SPACE_BIT;
    else       ctrl_bits &= ~IMEM2_SPACE_BIT;
}

/* ---- Write current state to GPIO ---- */
static inline void gpio_flush(void) {
    Xil_Out32(GPIO_CTRL_OUT, ctrl_bits);
}

/* ---- Core 0 control ---- */
static inline void gpu0_hold(void) {
    ctrl_bits |= GPU0_RESET_BIT;
    gpio_flush();
}
static inline void gpu0_release(void) {
    ctrl_bits &= ~GPU0_RESET_BIT;
    gpio_flush();
}
static inline u32 gpu0_done(void) {
    return Xil_In32(GPIO_DONE_IN) & 0x1u;
}

/* ---- Core 1 control ---- */
static inline void gpu1_hold(void) {
    ctrl_bits |= GPU1_RESET_BIT;
    gpio_flush();
}
static inline void gpu1_release(void) {
    ctrl_bits &= ~GPU1_RESET_BIT;
    gpio_flush();
}
static inline u32 gpu1_done(void) {
    return (Xil_In32(GPIO_DONE_IN) >> 1) & 0x1u;
}

/* ---- Core 2 control ---- */
static inline void gpu2_hold(void) {
    ctrl_bits |= GPU2_RESET_BIT;
    gpio_flush();
}
static inline void gpu2_release(void) {
    ctrl_bits &= ~GPU2_RESET_BIT;
    gpio_flush();
}
static inline u32 gpu2_done(void) {
    return (Xil_In32(GPIO_DONE_IN) >> 2) & 0x1u;
}

/* ---- Session counter control ---- */
static inline void session_hold(void) {
    ctrl_bits |= SESSION_CLK_RESET_BIT;
    gpio_flush();
}
static inline void session_release(void) {
    ctrl_bits &= ~SESSION_CLK_RESET_BIT;
    gpio_flush();
}

/* ---- Convenience: all cores ---- */
static inline void gpu_hold_all(void) {
    ctrl_bits |= ALL_HOLD;
    gpio_flush();
}
static inline void gpu_release_all(void) {
    ctrl_bits &= ~ALL_HOLD;
    gpio_flush();
}
static inline u32 gpu_all_done(void) {
    return (Xil_In32(GPIO_DONE_IN) & 0x7u) == 0x7u;
}

/* ---- Legacy-compatible wrappers ---- */
static inline void gpu_hold(void) {
    ctrl_bits |= (ALL_HOLD | SESSION_CLK_RESET_BIT);
    gpio_flush();
}
static inline void gpu_release_run(void) {
    ctrl_bits &= ~(ALL_HOLD | SESSION_CLK_RESET_BIT);
    gpio_flush();
}
static inline void gpu_stop(void) {
    ctrl_bits |= (ALL_HOLD | SESSION_CLK_RESET_BIT);
    gpio_flush();
}
static inline void gpu_hold_keep_timer(void) {
    ctrl_bits |= ALL_HOLD;
    ctrl_bits &= ~SESSION_CLK_RESET_BIT;
    gpio_flush();
}
static inline u32 gpu_done(void) {
    return gpu_all_done();
}


/* ============================================================
 * GPU CYCLE COUNTERS  (axi_gpio_1)
 *
 * Two independent 32-bit input-only channels expose RTL cycle counters.
 * Both count in sys_clk ticks (100 MHz → 10 ns/tick).
 *
 * Channel 1 (offset 0x00): SESSION_CYCLES
 *   Total elapsed cycles since the most recent gpu_release_run().
 *   Held at 0 while SESSION_CLK_RESET_BIT is high; counts every cycle
 *   while it's low; freezes and clears back to 0 when the reset bit
 *   goes high again. Wraps after ~42.9 s at 100 MHz.
 *
 *   Use this for end-to-end timing that includes any host polling gap
 *   between GPU completion and the moment MicroBlaze reads the counter.
 *
 * Channel 2 (offset 0x08): GPU_ACTIVE_CYCLES
 *   Cycles the GPU spent actively executing the most recent shader —
 *   from GPU release to the cycle GPU_done went high. Latched on the
 *   rising edge of GPU_done and stable until the next run starts.
 *
 *   Use this for pure GPU runtime, independent of host overhead.
 *
 * Typical use:
 *   1. gpu_hold();
 *   2. ... load IMEM/DMEM ...
 *   3. gpu_release_run();
 *   4. while (!gpu_done()) { }
 *   5. u32 gpu_cycles = gpu_active_cycles();       // pure GPU time
 *   6. u32 wall_cycles = session_cycles();         // GPU + host polling
 *   7. gpu_stop();
 * ============================================================ */
#define GPU_CTR_BASE            0x40010000u
#define SESSION_CYCLES_REG      (GPU_CTR_BASE + 0x00)
#define GPU_ACTIVE_CYCLES_REG   (GPU_CTR_BASE + 0x08)

static inline u32 session_cycles(void)     { return Xil_In32(SESSION_CYCLES_REG); }
static inline u32 gpu_active_cycles(void)  { return Xil_In32(GPU_ACTIVE_CYCLES_REG); }

/* Cycle → wall-time conversion at 100 MHz. */
#define TICKS_PER_US        100u
#define TICKS_PER_MS        100000u

static inline u32 cycles_to_us(u32 cycles) { return cycles / TICKS_PER_US; }
static inline u32 cycles_to_ms(u32 cycles) { return cycles / TICKS_PER_MS; }


/* ============================================================
 * AXI TIMER  (axi_timer_0)
 *
 * Timer 0 and Timer 1 cascaded into a single 64-bit up-counter.
 * At 100 MHz: 1 count = 10 ns. 64-bit overflow ~ 5800 years.
 *
 * Registers:
 *   TCSR0 — control/status, Timer 0
 *   TLR0  — load register: write 0x0 then pulse LOAD to reset counter
 *   TCR0  — live low  32 bits of 64-bit count
 *   TCSR1 — control/status, Timer 1 (high word in cascade)
 *   TCR1  — live high 32 bits of 64-bit count
 *
 * TCSR0 control bits:
 *   [11] CASC — cascade Timer0+Timer1 as 64-bit counter
 *   [ 7] ENT  — enable (run) the timer
 *   [ 5] LOAD — pulse high to latch TLR0 into the counter
 *   [ 1] UDT  — 1 = count up
 * ============================================================ */
#define TIMER_BASE          0x41C00000u
#define TCSR0               (TIMER_BASE + 0x00)
#define TLR0                (TIMER_BASE + 0x04)
#define TCR0                (TIMER_BASE + 0x08)
#define TCSR1               (TIMER_BASE + 0x10)
#define TCR1                (TIMER_BASE + 0x18)

#define TMR_CASC            (1u << 11)
#define TMR_ENT             (1u << 7)
#define TMR_LOAD            (1u << 5)
#define TMR_UDT             (1u << 1)
#define TMR_CFG             (TMR_CASC | TMR_UDT)   /* base config: cascade + up */
#define TMR_ENALL           (1u << 10)

static inline void timer_init(void) {
    Xil_Out32(TCSR0, 0x0);
    Xil_Out32(TCSR1, 0x0);
    fence();
    Xil_Out32(TCSR0, TMR_ENALL);
    fence();
}

#define timer_snapshot() Xil_In32(TCR0)

/* ============================================================
 * GPU DIMENSIONS & COMMON INSTRUCTIONS
 * ============================================================ */
#define NUM_WARPS           4
#define LANES_PER_WARP      16
#define TOTAL_LANES         (NUM_WARPS * LANES_PER_WARP)   /* 64 */

#define INSTR_NOP           0x0000u
#define INSTR_DONE          0xF000u
#define INSTR_SYNC          0xC000

/* ============================================================
 * IMEM ACCESS
 *
 * Write a shader program to IMEM. prog[] is an array of packed 32-bit
 * words built with PACK(). Remaining slots are filled with DONE pairs
 * so any overrun halts cleanly.
 * ============================================================ */
static inline void imem_write(const u32 *prog, int n_words) {
    for (int i = 0; i < n_words; i++)
        Xil_Out32(IMEM_BASE + i * 4, prog[i]);
    for (int i = n_words; i < IMEM_AXI_WORDS; i++)
        Xil_Out32(IMEM_BASE + i * 4, PACK(INSTR_DONE, INSTR_DONE));
    fence();
}


/* ============================================================
 * UTILITY
 * ============================================================ */

/* Software busy-wait. Not calibrated — use the timer for measurements. */
static inline void delay(volatile int n) {
    while (n-- > 0);
}

#endif  /* main_h */