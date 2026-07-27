#include "main.h"
#include "kernel_library.h"
#include <stdio.h>

#define MAT_A_BASE  0x000
#define MAT_B_BASE  0x100
#define MAT_C_BASE  0x200

#define DMEM0_BASE  0xC0000000u
#define DMEM1_BASE  0xC4000000u
#define DMEM2_BASE  0xC6000000u   /* verify against BD address map */

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

static const u32 matrix_b[128] = {
    0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
    0x00010000, 0x00030002, 0x00050004, 0x00070006, 0x00090008, 0x000B000A, 0x000D000C, 0x000F000E,
    0x00020000, 0x00060004, 0x000A0008, 0x000E000C, 0x00120010, 0x00160014, 0x001A0018, 0x001E001C,
    0x00030000, 0x00090006, 0x000F000C, 0x00150012, 0x001B0018, 0x0021001E, 0x00270024, 0x002D002A,
    0x00040000, 0x000C0008, 0x00140010, 0x001C0018, 0x00240020, 0x002C0028, 0x00340030, 0x003C0038,
    0x00050000, 0x000F000A, 0x00190014, 0x0023001E, 0x002D0028, 0x00370032, 0x0041003C, 0x004B0046,
    0x00060000, 0x0012000C, 0x001E0018, 0x002A0024, 0x00360030, 0x0042003C, 0x004E0048, 0x005A0054,
    0x00070000, 0x0015000E, 0x0023001C, 0x0031002A, 0x003F0038, 0x004D0046, 0x005B0054, 0x00690062,
    0x00080000, 0x00180010, 0x00280020, 0x00380030, 0x00480040, 0x00580050, 0x00680060, 0x00780070,
    0x00090000, 0x001B0012, 0x002D0024, 0x003F0036, 0x00510048, 0x0063005A, 0x0075006C, 0x0087007E,
    0x000A0000, 0x001E0014, 0x00320028, 0x0046003C, 0x005A0050, 0x006E0064, 0x00820078, 0x0096008C,
    0x000B0000, 0x00210016, 0x0037002C, 0x004D0042, 0x00630058, 0x0079006E, 0x008F0084, 0x00A5009A,
    0x000C0000, 0x00240018, 0x003C0030, 0x00540048, 0x006C0060, 0x00840078, 0x009C0090, 0x00B400A8,
    0x000D0000, 0x0027001A, 0x00410034, 0x005B004E, 0x00750068, 0x008F0082, 0x00A9009C, 0x00C300B6,
    0x000E0000, 0x002A001C, 0x00460038, 0x00620054, 0x007E0070, 0x009A008C, 0x00B600A8, 0x00D200C4,
    0x000F0000, 0x002D001E, 0x004B003C, 0x0069005A, 0x00870078, 0x00A50096, 0x00C300B4, 0x00E100D2,
};

static inline void dmem0_write32(u32 addr, u32 val) { Xil_Out32(DMEM0_BASE + addr * 2, val); }
static inline u16  dmem0_read16(u32 addr)           { return Xil_In16(DMEM0_BASE + addr * 2); }
static inline void dmem1_write32(u32 addr, u32 val) { Xil_Out32(DMEM1_BASE + addr * 2, val); }
static inline u16  dmem1_read16(u32 addr)           { return Xil_In16(DMEM1_BASE + addr * 2); }
static inline void dmem2_write32(u32 addr, u32 val) { Xil_Out32(DMEM2_BASE + addr * 2, val); }
static inline u16  dmem2_read16(u32 addr)           { return Xil_In16(DMEM2_BASE + addr * 2); }

static u16 compute_expected(int i, int j) {
    u32 sum = 0;
    for (int k = 0; k < 16; k++)
        sum += (u32)((i + k) & 0xFFFF) * (u32)((k * j) & 0xFFFF);
    return (u16)(sum & 0xFFFF);
}

static int verify(u16 (*r16)(u32)) {
    int errors = 0;
    for (int i = 0; i < 16; i++)
        for (int j = 0; j < 16; j++)
            if (r16(MAT_C_BASE + i * 16 + j) != compute_expected(i, j))
                errors++;
    return errors;
}

static void load_matrices(void (*w32)(u32, u32)) {
    for (int i = 0; i < 128; i++) {
        w32(MAT_A_BASE + i * 2, matrix_a[i]);
        w32(MAT_B_BASE + i * 2, matrix_b[i]);
        w32(MAT_C_BASE + i * 2, 0xFFFFFFFF);
    }
    fence();
}

int main(void) {
    xil_printf("\r\n=== Triple-Core Step-by-Step Diagnostic ===\r\n\r\n");

    /* ---- STEP 1: Hold everything ---- */
    gpu_hold();
    fence();
    xil_printf("[1] All cores held, timer held.\r\n");
    xil_printf("    GPIO out: 0x%03X\r\n", ctrl_bits);
    xil_printf("    Done: c0=%u c1=%u c2=%u\r\n\r\n",
               gpu0_done(), gpu1_done(), gpu2_done());

    /* ---- STEP 2: DMEM0 write/read ---- */
    xil_printf("[2] Testing DMEM0 (0x%08X)...\r\n", DMEM0_BASE);
    dmem0_write32(0, 0xCAFE1234);
    fence();
    u32 d0 = Xil_In32(DMEM0_BASE);
    xil_printf("    Wrote 0xCAFE1234, read back 0x%08X: %s\r\n\r\n",
               d0, (d0 == 0xCAFE1234) ? "OK" : "FAIL");

    /* ---- STEP 3: DMEM1 write/read ---- */
    xil_printf("[3] Testing DMEM1 (0x%08X)...\r\n", DMEM1_BASE);
    dmem1_write32(0, 0xBEEF5678);
    fence();
    u32 d1 = Xil_In32(DMEM1_BASE);
    xil_printf("    Wrote 0xBEEF5678, read back 0x%08X: %s\r\n",
               d1, (d1 == 0xBEEF5678) ? "OK" : "FAIL");
    u32 d0_check = Xil_In32(DMEM0_BASE);
    xil_printf("    DMEM0 still 0x%08X: %s\r\n\r\n",
               d0_check, (d0_check == 0xCAFE1234) ? "OK (independent)" : "FAIL (aliased!)");

    /* ---- STEP 4: DMEM2 write/read ---- */
    xil_printf("[4] Testing DMEM2 (0x%08X)...\r\n", DMEM2_BASE);
    dmem2_write32(0, 0xDEAD9ABC);
    fence();
    u32 d2 = Xil_In32(DMEM2_BASE);
    xil_printf("    Wrote 0xDEAD9ABC, read back 0x%08X: %s\r\n",
               d2, (d2 == 0xDEAD9ABC) ? "OK" : "FAIL");
    d0_check = Xil_In32(DMEM0_BASE);
    u32 d1_check = Xil_In32(DMEM1_BASE);
    xil_printf("    DMEM0 still 0x%08X: %s\r\n",
               d0_check, (d0_check == 0xCAFE1234) ? "OK" : "FAIL (aliased!)");
    xil_printf("    DMEM1 still 0x%08X: %s\r\n\r\n",
               d1_check, (d1_check == 0xBEEF5678) ? "OK" : "FAIL (aliased!)");

    /* ---- STEP 5: Load IMEM ---- */
    xil_printf("[5] Loading matmul kernel to IMEM...\r\n");
    kernel_library_init();
    load_kernel_direct(KERNEL_MATMUL);
    fence();
    u32 imem_check = Xil_In32(IMEM_BASE);
    xil_printf("    IMEM[0] = 0x%08X (expect 0x%08X): %s\r\n\r\n",
               imem_check, PACK(0x9A10, 0x9B04),
               (imem_check == PACK(0x9A10, 0x9B04)) ? "OK" : "MISMATCH");

    /* ---- STEP 6: Run core 0 only ---- */
    xil_printf("[6] Loading DMEM0, releasing core 0 only...\r\n");
    load_matrices(dmem0_write32);

    gpu0_release();
    fence();
    int done = 0;
    for (int p = 0; p < 10000000; p++) {
        if (gpu0_done()) { done = 1; break; }
    }
    gpu0_hold();
    fence();

    xil_printf("    Core 0: %s\r\n", done ? "DONE" : "TIMEOUT");
    if (done) {
        int err = verify(dmem0_read16);
        xil_printf("    Verify: %s (%d/256)\r\n", err ? "FAIL" : "PASS", 256 - err);
        xil_printf("    C[0][0]=0x%04X (expect 0x%04X)\r\n\r\n",
                   dmem0_read16(MAT_C_BASE), compute_expected(0, 0));
    }

    /* ---- STEP 7: Run core 1 only ---- */
    xil_printf("[7] Loading DMEM1, releasing core 1 only...\r\n");
    load_matrices(dmem1_write32);

    gpu1_release();
    fence();
    done = 0;
    for (int p = 0; p < 10000000; p++) {
        if (gpu1_done()) { done = 1; break; }
    }
    gpu1_hold();
    fence();

    xil_printf("    Core 1: %s\r\n", done ? "DONE" : "TIMEOUT");
    if (done) {
        int err = verify(dmem1_read16);
        xil_printf("    Verify: %s (%d/256)\r\n", err ? "FAIL" : "PASS", 256 - err);
        xil_printf("    C[0][0]=0x%04X (expect 0x%04X)\r\n\r\n",
                   dmem1_read16(MAT_C_BASE), compute_expected(0, 0));
    }

    /* ---- STEP 8: Run core 2 only ---- */
    xil_printf("[8] Loading DMEM2, releasing core 2 only...\r\n");
    load_matrices(dmem2_write32);

    gpu2_release();
    fence();
    done = 0;
    for (int p = 0; p < 10000000; p++) {
        if (gpu2_done()) { done = 1; break; }
    }
    gpu2_hold();
    fence();

    xil_printf("    Core 2: %s\r\n", done ? "DONE" : "TIMEOUT");
    if (done) {
        int err = verify(dmem2_read16);
        xil_printf("    Verify: %s (%d/256)\r\n", err ? "FAIL" : "PASS", 256 - err);
        xil_printf("    C[0][0]=0x%04X (expect 0x%04X)\r\n\r\n",
                   dmem2_read16(MAT_C_BASE), compute_expected(0, 0));
    }

    /* ---- STEP 9: Reload all, run simultaneously ---- */
    xil_printf("[9] Reloading all DMEMs...\r\n");
    load_matrices(dmem0_write32);
    load_matrices(dmem1_write32);
    load_matrices(dmem2_write32);

    xil_printf("    Releasing all 3 cores...\r\n");
    gpu_release_all();
    fence();
    xil_printf("    GPIO out: 0x%03X\r\n", ctrl_bits);

    int d0_ok = 0, d1_ok = 0, d2_ok = 0;
    for (int p = 0; p < 10000000; p++) {
        if (!d0_ok && gpu0_done()) d0_ok = 1;
        if (!d1_ok && gpu1_done()) d1_ok = 1;
        if (!d2_ok && gpu2_done()) d2_ok = 1;
        if (d0_ok && d1_ok && d2_ok) break;
    }
    gpu_hold_all();
    fence();

    xil_printf("    Core 0: %s\r\n", d0_ok ? "DONE" : "TIMEOUT");
    xil_printf("    Core 1: %s\r\n", d1_ok ? "DONE" : "TIMEOUT");
    xil_printf("    Core 2: %s\r\n", d2_ok ? "DONE" : "TIMEOUT");

    if (d0_ok && d1_ok && d2_ok) {
        int e0 = verify(dmem0_read16);
        int e1 = verify(dmem1_read16);
        int e2 = verify(dmem2_read16);
        xil_printf("    Core 0 verify: %s (%d/256)\r\n", e0 ? "FAIL" : "PASS", 256 - e0);
        xil_printf("    Core 1 verify: %s (%d/256)\r\n", e1 ? "FAIL" : "PASS", 256 - e1);
        xil_printf("    Core 2 verify: %s (%d/256)\r\n", e2 ? "FAIL" : "PASS", 256 - e2);
        if (!e0 && !e1 && !e2)
            xil_printf("\r\n*** TRIPLE-CORE TEST PASSED ***\r\n");
    }

    while (1);
    return 0;
}