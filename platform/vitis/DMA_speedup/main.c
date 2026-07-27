#include "main.h"
#include <stdio.h>

static const u32 matrix_a[128] = {
    0x00010000, 0x00030002, 0x00050004, 0x00070006, 0x00090008, 0x000B000A, 0x000D000C, 0x000F000E,
    0x00020001, 0x00040003, 0x00060005, 0x00080007, 0x000A0009, 0x000C000B, 0x000E000D, 0x0010000F,
    0x00030002, 0x00050004, 0x00070006, 0x00090008, 0x000B000A, 0x000D000C, 0x000F000E, 0x00110010,
    0x00040003, 0x00060005, 0x00080007, 0x000A0009, 0x000C000B, 0x000E000D, 0x0010000F, 0x00120011,
    0x00050004, 0x00070006, 0x00090008, 0x000B000A, 0x000D000C, 0x000F000E, 0x00110010, 0x00130012,
    0x00060005, 0x00080007, 0x000A0009, 0x000C000B, 0x000E000D, 0x0010000F, 0x00120011, 0x00140013,
    0x00070006, 0x00090008, 0x000B000A, 0x000D000C, 0x000F000E, 0x00110010, 0x00130012, 0x00150014,
    0x00080007, 0x000A0009, 0x000C000B, 0x000E000D, 0x0010000F, 0x00120011, 0x00140013, 0x00160015,
    0x00090008, 0x000B000A, 0x000D000C, 0x000F000E, 0x00110010, 0x00130012, 0x00150014, 0x00170016,
    0x000A0009, 0x000C000B, 0x000E000D, 0x0010000F, 0x00120011, 0x00140013, 0x00160015, 0x00180017,
    0x000B000A, 0x000D000C, 0x000F000E, 0x00110010, 0x00130012, 0x00150014, 0x00170016, 0x00190018,
    0x000C000B, 0x000E000D, 0x0010000F, 0x00120011, 0x00140013, 0x00160015, 0x00180017, 0x001A0019,
    0x000D000C, 0x000F000E, 0x00110010, 0x00130012, 0x00150014, 0x00170016, 0x00190018, 0x001B001A,
    0x000E000D, 0x0010000F, 0x00120011, 0x00140013, 0x00160015, 0x00180017, 0x001A0019, 0x001C001B,
    0x000F000E, 0x00110010, 0x00130012, 0x00150014, 0x00170016, 0x00190018, 0x001B001A, 0x001D001C,
    0x0010000F, 0x00120011, 0x00140013, 0x00160015, 0x00180017, 0x001A0019, 0x001C001B, 0x001E001D,
};

#define MAT_A_BASE  0x000
#define MAT_BYTES   512
#define N_WORDS_32  128

int main(void) {
    xil_printf("\r\n=== CDMA Timing Test ===\r\n\r\n");

    gpu_hold();
    fence();
    cdma_reset();

    /* Stage matrix A in DDR3 */
    for (int i = 0; i < 128; i++)
        ddr3_write32(i * 4, matrix_a[i]);
    fence();

    /* Start session counter (GPU stays held) */
    gpu_hold_keep_timer();
    fence();

    /* ================================================================
     * TEST 1: CPU store loop baseline
     * Clean measurement — no other bus master active.
     * ================================================================ */
    fence();
    u32 cpu_t0 = session_cycles();
    for (int i = 0; i < N_WORDS_32; i++)
        dmem_write32(MAT_A_BASE + i * 2, matrix_a[i]);
    fence();  /* ensure all writes complete before reading timer */
    u32 cpu_t1 = session_cycles();

    /* ================================================================
     * TEST 2: CDMA setup cost (SA + DA writes only, no transfer)
     * Measures the AXI register write overhead in isolation.
     * No CDMA bus activity — interconnect is quiet.
     * ================================================================ */
    fence();
    u32 setup_t0 = session_cycles();
    Xil_Out32(CDMA_SA, DDR3_BASE + 0x0000);
    Xil_Out32(CDMA_DA, DMEM_BASE + MAT_A_BASE * 2);
    fence();  /* ensure register writes complete */
    u32 setup_t1 = session_cycles();

    /* ================================================================
     * TEST 3: CDMA trigger + transfer (BTT write through poll-idle)
     * SA and DA are already set from test 2.
     * Measured in isolation: setup is done, bus is quiet at start.
     *
     * NOTE: includes one poll cycle of overhead (~10-20 cycles).
     * This is the real CPU-blocking cost — the CPU cannot do other
     * work until the poll returns, so it's the right metric.
     * ================================================================ */
    fence();
    u32 xfer_t0 = session_cycles();
    Xil_Out32(CDMA_BTT, MAT_BYTES);  /* starts transfer */
    while (!(Xil_In32(CDMA_SR) & CDMA_SR_IDLE));
    u32 xfer_t1 = session_cycles();

    u32 sr = Xil_In32(CDMA_SR);

    /* ================================================================
     * TEST 4: CDMA total (setup + trigger + transfer + poll)
     * Fresh transfer, all 3 register writes + DMA + poll.
     * This is the apples-to-apples comparison with CPU store loop.
     * ================================================================ */
    fence();
    u32 total_t0 = session_cycles();
    Xil_Out32(CDMA_SA, DDR3_BASE + 0x0000);
    Xil_Out32(CDMA_DA, DMEM_BASE + MAT_A_BASE * 2);
    Xil_Out32(CDMA_BTT, MAT_BYTES);
    while (!(Xil_In32(CDMA_SR) & CDMA_SR_IDLE));
    u32 total_t1 = session_cycles();

    /* ================================================================
     * TEST 5: Verify CDMA wrote correct data
     * ================================================================ */
    int errors = 0;
    for (int i = 0; i < N_WORDS_32; i++)
        if (dmem_read32(MAT_A_BASE + i * 2) != matrix_a[i]) errors++;

    /* ================================================================
     * REPORT
     * ================================================================ */
    u32 cpu_time   = cpu_t1 - cpu_t0;
    u32 setup_time = setup_t1 - setup_t0;
    u32 xfer_time  = xfer_t1 - xfer_t0;
    u32 cdma_total = total_t1 - total_t0;

    xil_printf("CPU store loop (512 bytes, 128 x Xil_Out32):\r\n");
    xil_printf("  %u cycles\r\n\r\n", cpu_time);

    xil_printf("CDMA breakdown (512 bytes):\r\n");
    xil_printf("  Setup (SA + DA writes):     %u cycles\r\n", setup_time);
    xil_printf("  Trigger + transfer + poll:  %u cycles\r\n", xfer_time);
    xil_printf("  Sum:                        %u cycles\r\n", setup_time + xfer_time);
    xil_printf("  Total (single measurement): %u cycles\r\n", cdma_total);
    xil_printf("  Status: 0x%08X %s\r\n", sr,
               (sr & (CDMA_SR_DECERR | CDMA_SR_SLVERR)) ? "ERROR" : "OK");
    xil_printf("  Verify: %s (%d/128)\r\n\r\n", errors ? "FAIL" : "PASS", 128 - errors);

    xil_printf("Speedup: %u.%ux\r\n",
               cpu_time / cdma_total,
               ((cpu_time * 10) / cdma_total) % 10);

    xil_printf("\r\nNOTE: Transfer time includes up to ~20 cycles of\r\n");
    xil_printf("poll overhead (one Xil_In32 round-trip). This is the\r\n");
    xil_printf("real CPU-blocking cost — the metric that matters for\r\n");
    xil_printf("double-buffer overlap calculations.\r\n");

    gpu_stop();
    xil_printf("\r\n=== Done ===\r\n");
    while (1);
    return 0;
}