#include "main.h"
#include "kernel_library.h"
#include <stdio.h>

#define CLK_MHZ  100

/*
 * ═══════════════════════════════════════════════════════════
 *  ROOFLINE PERFORMANCE ANALYSIS — GPGPU-4W16 @ 100 MHz
 *  3-core configuration
 * ═══════════════════════════════════════════════════════════
 */
/* ── OI sweep kernel: paste into roofline benchmark ── */

/* Base kernel with a placeholder for CONST R13,N at PC 5 */




/* ── Kernel analytics (from ISA instruction trace) ── */
typedef struct {
    const char *name;
    u32 useful_ops;
    u32 bytes_moved;
    u32 kernel_id;
} kernel_info_t;

static const kernel_info_t kernels[] = {
    { "matmul 16x16",  8192, 16896, KERNEL_MATMUL      },
    { "prefix scan",    196,  1032, KERNEL_PREFIX_SCAN  },
    { "stencil 1D",     128,   512, KERNEL_STENCIL      },
};
#define NUM_KERNELS 3

/* ── Peak ALU microkernel: 250 iters × 4 independent MUL/ADD, no memory ── */
static const u32 kern_peak_alu[] = {
    PACK(0x9301, 0x9402), PACK(0x9503, 0x9F01), PACK(0x9E00, 0x9DFA),
    PACK(0x5634, 0x3753), PACK(0x5845, 0x3935),
    PACK(0x3EEF, 0xA0ED), PACK(0xB8FA, 0xF000),
};
#define PEAK_ALU_OPS    64000   /* useful: 4 ops × 250 × 16 lanes × 4 warps */
#define PEAK_ALU_TOTAL  96000   /* +2 overhead ALU ops/iter (ADD counter, CMP) */
#define PEAK_ALU_SIZE   (sizeof(kern_peak_alu)/sizeof(u32))

/* ── Peak concurrent BW: 250 iters × LDC+STRC, 64 bytes/iter ── */
static const u32 kern_peak_conc[] = {
    PACK(0x9300, 0x9410), PACK(0x9F01, 0x9E00), PACK(0x9DFA, 0x0000),
    PACK(0xD630, 0xE046), PACK(0x3EEF, 0xA0ED), PACK(0xB8FC, 0xF000),
};
#define PEAK_CONC_BYTES 64000
#define PEAK_CONC_SIZE  (sizeof(kern_peak_conc)/sizeof(u32))

/* ── Peak sequential BW: 250 iters × LDR+STR per lane, 64 bytes/iter ── */
static const u32 kern_peak_seq[] = {
    PACK(0x3301, 0x9410), PACK(0x3441, 0x9F01), PACK(0x9E00, 0x9DFA),
    PACK(0x7630, 0x8046), PACK(0x3EEF, 0xA0ED), PACK(0xB8FC, 0xF000),
};
#define PEAK_SEQ_BYTES  64000
#define PEAK_SEQ_SIZE   (sizeof(kern_peak_seq)/sizeof(u32))

/* ── Matrix data ── */
#define MAT_A_BASE  0x000
#define MAT_B_BASE  0x100
#define MAT_C_BASE  0x200

#define DMEM0_AXI  0xC0000000u
#define DMEM1_AXI  0xC4000000u
#define DMEM2_AXI  0xC6000000u   /* verify against BD */

static const u32 matrix_a[128] = {
    0x00010000,0x00030002,0x00050004,0x00070006,0x00090008,0x000B000A,0x000D000C,0x000F000E,
    0x00020001,0x00040003,0x00060005,0x00080007,0x000A0009,0x000C000B,0x000E000D,0x0010000F,
    0x00030002,0x00050004,0x00070006,0x00090008,0x000B000A,0x000D000C,0x000F000E,0x00110010,
    0x00040003,0x00060005,0x00080007,0x000A0009,0x000C000B,0x000E000D,0x0010000F,0x00120011,
    0x00050004,0x00070006,0x00090008,0x000B000A,0x000D000C,0x000F000E,0x00110010,0x00130012,
    0x00060005,0x00080007,0x000A0009,0x000C000B,0x000E000D,0x0010000F,0x00120011,0x00140013,
    0x00070006,0x00090008,0x000B000A,0x000D000C,0x000F000E,0x00110010,0x00130012,0x00150014,
    0x00080007,0x000A0009,0x000C000B,0x000E000D,0x0010000F,0x00120011,0x00140013,0x00160015,
    0x00090008,0x000B000A,0x000D000C,0x000F000E,0x00110010,0x00130012,0x00150014,0x00170016,
    0x000A0009,0x000C000B,0x000E000D,0x0010000F,0x00120011,0x00140013,0x00160015,0x00180017,
    0x000B000A,0x000D000C,0x000F000E,0x00110010,0x00130012,0x00150014,0x00170016,0x00190018,
    0x000C000B,0x000E000D,0x0010000F,0x00120011,0x00140013,0x00160015,0x00180017,0x001A0019,
    0x000D000C,0x000F000E,0x00110010,0x00130012,0x00150014,0x00170016,0x00190018,0x001B001A,
    0x000E000D,0x0010000F,0x00120011,0x00140013,0x00160015,0x00180017,0x001A0019,0x001C001B,
    0x000F000E,0x00110010,0x00130012,0x00150014,0x00170016,0x00190018,0x001B001A,0x001D001C,
    0x0010000F,0x00120011,0x00140013,0x00160015,0x00180017,0x001A0019,0x001C001B,0x001E001D,
};
static const u32 matrix_b[128] = {
    0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,0x00000000,
    0x00010000,0x00030002,0x00050004,0x00070006,0x00090008,0x000B000A,0x000D000C,0x000F000E,
    0x00020000,0x00060004,0x000A0008,0x000E000C,0x00120010,0x00160014,0x001A0018,0x001E001C,
    0x00030000,0x00090006,0x000F000C,0x00150012,0x001B0018,0x0021001E,0x00270024,0x002D002A,
    0x00040000,0x000C0008,0x00140010,0x001C0018,0x00240020,0x002C0028,0x00340030,0x003C0038,
    0x00050000,0x000F000A,0x00190014,0x0023001E,0x002D0028,0x00370032,0x0041003C,0x004B0046,
    0x00060000,0x0012000C,0x001E0018,0x002A0024,0x00360030,0x0042003C,0x004E0048,0x005A0054,
    0x00070000,0x0015000E,0x0023001C,0x0031002A,0x003F0038,0x004D0046,0x005B0054,0x00690062,
    0x00080000,0x00180010,0x00280020,0x00380030,0x00480040,0x00580050,0x00680060,0x00780070,
    0x00090000,0x001B0012,0x002D0024,0x003F0036,0x00510048,0x0063005A,0x0075006C,0x0087007E,
    0x000A0000,0x001E0014,0x00320028,0x0046003C,0x005A0050,0x006E0064,0x00820078,0x0096008C,
    0x000B0000,0x00210016,0x0037002C,0x004D0042,0x00630058,0x0079006E,0x008F0084,0x00A5009A,
    0x000C0000,0x00240018,0x003C0030,0x00540048,0x006C0060,0x00840078,0x009C0090,0x00B400A8,
    0x000D0000,0x0027001A,0x00410034,0x005B004E,0x00750068,0x008F0082,0x00A9009C,0x00C300B6,
    0x000E0000,0x002A001C,0x00460038,0x00620054,0x007E0070,0x009A008C,0x00B600A8,0x00D200C4,
    0x000F0000,0x002D001E,0x004B003C,0x0069005A,0x00870078,0x00A50096,0x00C300B4,0x00E100D2,
};

/* ── Helpers ── */

static void load_inline(const u32 *prog, int n) {
    for (int i = 0; i < n; i++)
        Xil_Out32(IMEM_BASE + i * 4, prog[i]);
    for (int i = n; i < IMEM_AXI_WORDS; i++)
        Xil_Out32(IMEM_BASE + i * 4, PACK(INSTR_DONE, INSTR_DONE));
    fence();
}

static void load_matmul_to(u32 base) {
    for (int i = 0; i < 128; i++) {
        Xil_Out32(base + (MAT_A_BASE + i * 2) * 2, matrix_a[i]);
        Xil_Out32(base + (MAT_B_BASE + i * 2) * 2, matrix_b[i]);
        Xil_Out32(base + (MAT_C_BASE + i * 2) * 2, 0);
    }
    fence();
}

static void load_stencil_data(void) {
    for (int i = 0; i < 16; i += 2)
        dmem_write32(i, ((u32)(i + 1) << 16) | (u32)i);
    dmem_clear(16, 16);
    fence();
}

/* Run on core 0 only, return gpu_active_cycles */
static u32 run_core0(void) {
    gpu0_release();
    fence();
    while (!gpu0_done());
    u32 c = gpu_active_cycles();
    gpu0_hold();
    fence();
    return c;
}

static u16 expected_matmul(int i, int j) {
    u32 s = 0;
    for (int k = 0; k < 16; k++)
        s += (u32)((i+k)&0xFFFF) * (u32)((k*j)&0xFFFF);
    return (u16)(s & 0xFFFF);
}

static int verify_matmul_at(u32 base) {
    int err = 0;
    for (int i = 0; i < 16; i++)
        for (int j = 0; j < 16; j++)
            if (Xil_In16(base + (MAT_C_BASE + i*16 + j) * 2) != expected_matmul(i, j))
                err++;
    return err;
}

static int verify_prefix(void) {
    static const u16 exp[] = {0,1,3,6,10,15,21,28,36,45,55,66,78,91,105,120};
    int err = 0;
    for (int i = 0; i < 16; i++)
        if (dmem_read16(16 + i) != exp[i]) err++;
    return err;
}

static int verify_stencil(void) {
    int err = 0;
    for (int i = 0; i < 16; i++) {
        u16 l = (i > 0) ? (u16)(i-1) : 0;
        u16 r = (i < 15) ? (u16)(i+1) : 15;
        if (dmem_read16(16 + i) != (l + (u16)i + r)) err++;
    }
    return err;
}
static const u32 kern_oi_sweep_base[] = {
    PACK(0x9300, 0x9403),  /* PC 0,1: CONST R3,0  | CONST R4,3           */
    PACK(0x9501, 0x9710),  /* PC 2,3: CONST R5,1  | CONST R7,16          */
    PACK(0x9E00, 0x9D01),  /* PC 4,5: CONST R14,0 | CONST R13,1 ← PATCH */
    PACK(0xD630, 0x3860),  /* PC 6,7: LDC R6,R3   | ADD R8,R6,R0        */
    PACK(0x5664, 0x5884),  /* PC 8,9: MUL R6,R6,R4| MUL R8,R8,R4        */
    PACK(0x3665, 0x3885),  /* PC10,11: ADD R6,R6,R5| ADD R8,R8,R5        */
    PACK(0x3EE5, 0xA0ED),  /* PC12,13: ADD R14,+1 | CMP R14,R13          */
    PACK(0xB8FA, 0x3668),  /* PC14,15: BRn -6     | ADD R6,R6,R8         */
    PACK(0xE076, 0xF000),  /* PC16,17: STRC R7,R6 | DONE                 */
};
#define OI_SWEEP_SIZE (sizeof(kern_oi_sweep_base) / sizeof(u32))

/*
 * Analytics:
 *   Useful ops per iteration: 4 (2 MUL + 2 ADD) × 16 lanes × 4 warps = 256
 *   Total bytes: (LDC + STRC) × 4 warps = 64 × 4 = 256 bytes
 *   OI = 256 × N / 256 = N ops/byte
 */

static void run_oi_sweep(void) {
    static const u32 n_values[] = { 1, 2, 4, 8, 16, 32, 64 };
    int num_points = sizeof(n_values) / sizeof(n_values[0]);

    xil_printf("\r\n== OI SWEEP (variable compute intensity) ==\r\n\r\n");
    xil_printf("  N | OI    | Cycles | MIOPS | MB/s | Ceiling hit\r\n");
    xil_printf("----+-------+--------+-------+------+------------\r\n");

    u32 kern_buf[OI_SWEEP_SIZE];

    for (int p = 0; p < num_points; p++) {
        u32 n = n_values[p];
        u32 useful_ops = 256 * n;
        u32 bytes = 256;

        /* Copy base kernel and patch CONST R13,N */
        for (int i = 0; i < (int)OI_SWEEP_SIZE; i++)
            kern_buf[i] = kern_oi_sweep_base[i];
        kern_buf[2] = PACK(0x9E00, 0x9D00 | (n & 0xFF));

        /* Load kernel */
        gpu_hold(); fence();
        for (int i = 0; i < (int)OI_SWEEP_SIZE; i++)
            Xil_Out32(IMEM_BASE + i * 4, kern_buf[i]);
        for (int i = (int)OI_SWEEP_SIZE; i < IMEM_AXI_WORDS; i++)
            Xil_Out32(IMEM_BASE + i * 4, PACK(INSTR_DONE, INSTR_DONE));
        fence();

        /* Preload DMEM so LDC has data */
        for (int i = 0; i < 16; i += 2)
            dmem_write32(i, ((u32)(i + 1) << 16) | (u32)i);
        fence();

        /* Run */
        u32 cyc = run_core0();

        u32 miops = (u32)((u64)useful_ops * CLK_MHZ / cyc);
        u32 mb_s  = (u32)((u64)bytes * CLK_MHZ / cyc);
        u32 oi_x1k = useful_ops * 1000 / bytes;

        /* Determine which ceiling */
        const char *ceiling;
        if (miops > 1064 * 90 / 100) //1064 is peak useful MIOPS
            ceiling = "COMPUTE";
        else
            ceiling = "Memory";

        xil_printf("%3u | %2u.%03u | %6u | %5u | %4u | %s\r\n",
                   n, oi_x1k / 1000, oi_x1k % 1000,
                   cyc, miops, mb_s, ceiling);
    }
}
/* ═══════ MAIN ═══════ */

int main(void) {
    xil_printf("\r\n");
    xil_printf("================================================================\r\n");
    xil_printf("  ROOFLINE PERFORMANCE ANALYSIS — GPGPU-4W16 @ 100 MHz\r\n");
    xil_printf("  3-core configuration\r\n");
    xil_printf("================================================================\r\n\r\n");

    gpu_hold();
    fence();
    kernel_library_init();
    set_dmem_space(0); set_dmem1_space(0); set_dmem2_space(0);
    fence();

    /* ════════════════════════════════════════════════════════
     * PHASE 1: PER-CORE PEAK MEASUREMENTS
     * ════════════════════════════════════════════════════════ */
    xil_printf("== PHASE 1: PER-CORE CEILINGS ==\r\n\r\n");

    /* Peak ALU */
    gpu_hold(); fence();
    load_inline(kern_peak_alu, PEAK_ALU_SIZE);
    u32 cyc_alu = run_core0();

    /* MIOPS = ops * CLK_MHZ / cycles */
    u32 peak_useful_miops = (u32)((u64)PEAK_ALU_OPS   * CLK_MHZ / cyc_alu);
    u32 peak_total_miops  = (u32)((u64)PEAK_ALU_TOTAL * CLK_MHZ / cyc_alu);

    xil_printf("Peak ALU (useful):  %u cycles -> %u MIOPS\r\n", cyc_alu, peak_useful_miops);
    xil_printf("Peak ALU (total):   %u cycles -> %u MIOPS\r\n", cyc_alu, peak_total_miops);
    xil_printf("Theoretical:        1600 MIOPS (16 ops/cyc @ 100 MHz)\r\n\r\n");

    /* Peak concurrent BW */
    gpu_hold(); fence();
    load_inline(kern_peak_conc, PEAK_CONC_SIZE);
    for (int i = 0; i < 16; i += 2) dmem_write32(i, 0xAAAA5555);
    fence();
    u32 cyc_conc = run_core0();

    /* MB/s = bytes * CLK_MHZ / cycles */
    u32 conc_bw = (u32)((u64)PEAK_CONC_BYTES * CLK_MHZ / cyc_conc);
    xil_printf("Peak conc. BW:      %u cycles -> %u MB/s\r\n", cyc_conc, conc_bw);

    /* Peak sequential BW */
    gpu_hold(); fence();
    load_inline(kern_peak_seq, PEAK_SEQ_SIZE);
    u32 cyc_seq = run_core0();

    u32 seq_bw = (u32)((u64)PEAK_SEQ_BYTES * CLK_MHZ / cyc_seq);
    xil_printf("Peak seq. BW:       %u cycles -> %u MB/s\r\n", cyc_seq, seq_bw);

    /* Ridge points: MIOPS / (MB/s) = ops/byte */
    u32 ridge_conc_x100 = (conc_bw > 0) ? (u32)((u64)peak_useful_miops * 100 / conc_bw) : 0;
    u32 ridge_seq_x100  = (seq_bw > 0)  ? (u32)((u64)peak_useful_miops * 100 / seq_bw)  : 0;

    xil_printf("\r\nRidge points:\r\n");
    xil_printf("  Concurrent: %u.%02u ops/byte\r\n", ridge_conc_x100/100, ridge_conc_x100%100);
    xil_printf("  Sequential: %u.%02u ops/byte\r\n\r\n", ridge_seq_x100/100, ridge_seq_x100%100);

    /* ════════════════════════════════════════════════════════
     * PHASE 2: PER-CORE KERNEL MEASUREMENTS
     * ════════════════════════════════════════════════════════ */
    xil_printf("== PHASE 2: PER-CORE KERNEL ANALYSIS ==\r\n\r\n");
    xil_printf("Kernel          | Ops   | Bytes | OI    | Cycles | MIOPS | MB/s | Verify\r\n");
    xil_printf("----------------+-------+-------+-------+--------+-------+------+-------\r\n");

    for (int k = 0; k < NUM_KERNELS; k++) {
        const kernel_info_t *ki = &kernels[k];

        gpu_hold(); fence();
        load_kernel_direct(ki->kernel_id);
        fence();
        if (ki->kernel_id == KERNEL_MATMUL)      load_matmul_to(DMEM0_AXI);
        else if (ki->kernel_id == KERNEL_STENCIL) load_stencil_data();

        u32 cyc = run_core0();

        int err = 0;
        if (ki->kernel_id == KERNEL_MATMUL)       err = verify_matmul_at(DMEM0_AXI);
        else if (ki->kernel_id == KERNEL_PREFIX_SCAN) err = verify_prefix();
        else if (ki->kernel_id == KERNEL_STENCIL) err = verify_stencil();

        u32 miops  = (u32)((u64)ki->useful_ops  * CLK_MHZ / cyc);
        u32 mb_s   = (u32)((u64)ki->bytes_moved * CLK_MHZ / cyc);
        u32 oi_x1k = (u32)((u64)ki->useful_ops  * 1000 / ki->bytes_moved);

        xil_printf("%-16s| %5u | %5u | %u.%03u | %6u | %5u | %4u | %s\r\n",
                   ki->name, ki->useful_ops, ki->bytes_moved,
                   oi_x1k/1000, oi_x1k%1000, cyc, miops, mb_s,
                   err ? "FAIL" : "PASS");
    }

    /* ════════════════════════════════════════════════════════
     * PHASE 3: MULTI-CORE SCALING
     * ════════════════════════════════════════════════════════ */
    xil_printf("\r\n== PHASE 3: MULTI-CORE SCALING (matmul) ==\r\n\r\n");

    static const u32 dmem_bases[] = { DMEM0_AXI, DMEM1_AXI, DMEM2_AXI };

    xil_printf("Cores | Cycles | Total ops | MIOPS | Scaling\r\n");
    xil_printf("------+--------+-----------+-------+--------\r\n");

    u32 baseline_miops = 0;

    for (int nc = 1; nc <= 3; nc++) {
        gpu_hold(); fence();
        load_kernel_direct(KERNEL_MATMUL);
        for (int c = 0; c < nc; c++)
            load_matmul_to(dmem_bases[c]);
        fence();

        /* Release exactly nc cores + timer in one GPIO write */
        u32 release_mask = SESSION_CLK_RESET_BIT;
        if (nc >= 1) release_mask |= GPU0_RESET_BIT;
        if (nc >= 2) release_mask |= GPU1_RESET_BIT;
        if (nc >= 3) release_mask |= GPU2_RESET_BIT;
        ctrl_bits &= ~release_mask;
        gpio_flush();
        fence();

        /* Poll only the cores we released */
        for (;;) {
            int all = 1;
            if (nc >= 1 && !gpu0_done()) all = 0;
            if (nc >= 2 && !gpu1_done()) all = 0;
            if (nc >= 3 && !gpu2_done()) all = 0;
            if (all) break;
        }

        u32 active  = gpu_active_cycles();  /* core 0 compute time */
        u32 session = session_cycles();
        gpu_stop(); fence();

        /* Verify all cores */
        int ok = 1;
        for (int c = 0; c < nc; c++)
            if (verify_matmul_at(dmem_bases[c])) ok = 0;

        u32 total_ops = (u32)nc * 8192;
        u32 miops = (u32)((u64)total_ops * CLK_MHZ / session);
        if (nc == 1) baseline_miops = miops;

        u32 scale_x100 = (baseline_miops > 0) ? miops * 100 / baseline_miops : 0;

        xil_printf("  %u   | %6u | %9u | %5u | %u.%02ux %s\r\n",
                   nc, session, total_ops, miops,
                   scale_x100/100, scale_x100%100,
                   ok ? "" : "VERIFY FAIL"); 
    }

    /* ════════════════════════════════════════════════════════
     * SUMMARY — data for roofline plot
     * ════════════════════════════════════════════════════════ */
    xil_printf("\r\n== ROOFLINE PLOT DATA ==\r\n\r\n");
    xil_printf("# Per-core ceilings\r\n");
    xil_printf("peak_compute_miops = %u\r\n", peak_useful_miops);
    xil_printf("peak_conc_bw_mbs   = %u\r\n", conc_bw);
    xil_printf("peak_seq_bw_mbs    = %u\r\n", seq_bw);
    xil_printf("ridge_conc         = %u.%02u\r\n", ridge_conc_x100/100, ridge_conc_x100%100);
    xil_printf("ridge_seq          = %u.%02u\r\n\r\n", ridge_seq_x100/100, ridge_seq_x100%100);

    xil_printf("# Kernel data: name, OI (ops/byte), MIOPS\r\n");
    for (int k = 0; k < NUM_KERNELS; k++) {
        const kernel_info_t *ki = &kernels[k];
        gpu_hold(); fence();
        load_kernel_direct(ki->kernel_id);
        if (ki->kernel_id == KERNEL_MATMUL)      load_matmul_to(DMEM0_AXI);
        else if (ki->kernel_id == KERNEL_STENCIL) load_stencil_data();
        u32 cyc = run_core0();
        u32 miops = (u32)((u64)ki->useful_ops * CLK_MHZ / cyc);
        u32 oi_x1k = (u32)((u64)ki->useful_ops * 1000 / ki->bytes_moved);
        xil_printf("%s, %u.%03u, %u\r\n", ki->name, oi_x1k/1000, oi_x1k%1000, miops);
    }

    xil_printf("\r\n*** ROOFLINE ANALYSIS COMPLETE ***\r\n");

    run_oi_sweep();
    
    while (1);
    return 0;
}