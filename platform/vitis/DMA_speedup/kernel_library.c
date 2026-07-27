#include "kernel_library.h"
#include "xil_printf.h"

// ============================================================
// GPU KERNEL MACHINE CODE
// Each 32-bit word contains two 16-bit instructions via PACK(even, odd)
// ============================================================

static const u32 kernel_matmul[] = {
    /* ===== SETUP ===== */
    /* PC  0, 1 */ PACK(0x9A10, 0x9B04),       /* CONST R10, 16      | CONST R11, 4              */
    /* PC  2, 3 */ PACK(0x5DAA, 0x3EDD),       /* MUL R13, R10, R10  | ADD R14, R13, R13         */
    /* PC  4, 5 */ PACK(0x9400, 0x9F01),       /* CONST R4, 0        | CONST R15, 1 (hoisted)    */
    /* ===== OUTER LOOP (PC 6) ===== */
    /* PC  6, 7 */ PACK(0x532B, 0x3334),       /* MUL R3, R2, R11    | ADD R3, R3, R4            */
    /* PC  8, 9 */ PACK(0x5C3A, 0x9600),       /* MUL R12, R3, R10   | CONST R6, 0 (accum)      */
    /* PC 10,11 */ PACK(0x9500, 0x39C5),       /* CONST R5, 0 (k)    | ADD R9, R12, R5           */
    /* ===== INNER LOOP (PC 11) ===== */
    /* PC 12,13 */ PACK(0x7790, 0x595A),       /* LDR R7, R9         | MUL R9, R5, R10           */
    /* PC 14,15 */ PACK(0x399D, 0xD890),       /* ADD R9, R9, R13    | LDC R8, R9  (concurrent!) */
    /* PC 16,17 */ PACK(0x5978, 0x3669),       /* MUL R9, R7, R8     | ADD R6, R6, R9            */
    /* PC 18,19 */ PACK(0x355F, 0xA05A),       /* ADD R5, R5, R15    | CMP R5, R10               */
    /* PC 20,21 */ PACK(0xB8F7, 0x593A),       /* BRn -9 (->PC 11)  | MUL R9, R3, R10           */
    /* ===== STORE RESULT ===== */
    /* PC 22,23 */ PACK(0x399E, 0xE096),       /* ADD R9, R9, R14    | STRC R9, R6 (concurrent!) */
    /* ===== OUTER LOOP CONTROL ===== */
    /* PC 24,25 */ PACK(0x344F, 0xA04B),       /* ADD R4, R4, R15    | CMP R4, R11               */
    /* PC 26,27 */ PACK(0xB8EC, INSTR_DONE),   /* BRn -20 (->PC 6)  | DONE                      */
};
#define KERNEL_MATMUL_SIZE (sizeof(kernel_matmul) / sizeof(u32))

// ============================================================
// PREFIX SCAN (exclusive, Hillis-Steele, 16 lanes)
//
// Each lane N contributes (N + 1) as its input. After the scan, lane N
// holds the exclusive prefix sum: sum of all lane inputs with id < N.
//
// Algorithm:
//   R3  = 0                          (DMEM base for partial sums)
//   R12 = LANE_ID + 1                (initial input for this lane)
//   R4  = running partial sum        (starts = R12)
//   Store R4 at DMEM[0..15]
//
//   for offset in {1, 2, 4, 8}:
//     if LANE_ID >= offset:          (BRzp guards the branch)
//       R7 = DMEM[LANE_ID - offset]
//       R4 = R4 + R7
//     SYNC
//     Store R4 to DMEM[0..15]
//
//   R13 = R4 - R12                   (subtract self to make exclusive)
//   Store R13 at DMEM[16..31]        (final exclusive prefix)
//
// Output: DMEM[16..31] = exclusive prefix sums of (1..16).
// Expected result: [0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91,
//                   105, 120]  (triangular numbers - 1 shifted by 1)
// ============================================================
static const u32 kernel_prefix_scan[] = {
    /* ===== INIT ===== */
    /* PC  0, 1 */ PACK(0x9300, 0x9501),       /* CONST R3, 0        | CONST R5, 1               */
    /* PC  2, 3 */ PACK(0x3C15, 0x34C0),       /* ADD R12, R1, R5    | ADD R4, R12, R0            */
    /* PC  4, 5 */ PACK(0x3831, 0x8084),       /* ADD R8, R3, R1     | STR R8, R4                 */
    /* ===== SCAN STEP: OFFSET 1 ===== */
    /* PC  6, 7 */ PACK(0x9501, 0xA015),       /* CONST R5, 1        | CMP R1, R5                 */
    /* PC  8, 9 */ PACK(0xB601, 0x4615),       /* BRzp +1            | SUB R6, R1, R5             */
    /* PC 10,11 */ PACK(0x7760, 0x3447),       /* LDR R7, R6         | ADD R4, R4, R7             */
    /* PC 12,13 */ PACK(0xC000, 0x3831),       /* SYNC               | ADD R8, R3, R1             */
    /* PC 14,15 */ PACK(0x8084, 0x9502),       /* STR R8, R4         | CONST R5, 2                */
    /* ===== SCAN STEP: OFFSET 2 ===== */
    /* PC 16,17 */ PACK(0xA015, 0xB601),       /* CMP R1, R5         | BRzp +1                    */
    /* PC 18,19 */ PACK(0x4615, 0x7760),       /* SUB R6, R1, R5     | LDR R7, R6                 */
    /* PC 20,21 */ PACK(0x3447, 0xC000),       /* ADD R4, R4, R7     | SYNC                       */
    /* PC 22,23 */ PACK(0x3831, 0x8084),       /* ADD R8, R3, R1     | STR R8, R4                 */
    /* PC 24,25 */ PACK(0x9504, 0xA015),       /* CONST R5, 4        | CMP R1, R5                 */
    /* ===== SCAN STEP: OFFSET 4 ===== */
    /* PC 26,27 */ PACK(0xB601, 0x4615),       /* BRzp +1            | SUB R6, R1, R5             */
    /* PC 28,29 */ PACK(0x7760, 0x3447),       /* LDR R7, R6         | ADD R4, R4, R7             */
    /* PC 30,31 */ PACK(0xC000, 0x3831),       /* SYNC               | ADD R8, R3, R1             */
    /* PC 32,33 */ PACK(0x8084, 0x9508),       /* STR R8, R4         | CONST R5, 8                */
    /* ===== SCAN STEP: OFFSET 8 ===== */
    /* PC 34,35 */ PACK(0xA015, 0xB601),       /* CMP R1, R5         | BRzp +1                    */
    /* PC 36,37 */ PACK(0x4615, 0x7760),       /* SUB R6, R1, R5     | LDR R7, R6                 */
    /* PC 38,39 */ PACK(0x3447, 0xC000),       /* ADD R4, R4, R7     | SYNC                       */
    /* PC 40,41 */ PACK(0x3831, 0x8084),       /* ADD R8, R3, R1     | STR R8, R4                 */
    /* ===== EXCLUSIVE SCAN ===== */
    /* PC 42,43 */ PACK(0x4D4C, 0x9310),       /* SUB R13, R4, R12   | CONST R3, 16               */
    /* PC 44,45 */ PACK(0x3831, 0x808D),       /* ADD R8, R3, R1     | STR R8, R13                 */
    /* ===== DONE ===== */
    /* PC 46,47 */ PACK(INSTR_DONE, INSTR_DONE),/* DONE              | DONE                       */
};

#define KERNEL_PREFIX_SCAN_SIZE (sizeof(kernel_prefix_scan) / sizeof(u32))

/*
 * 1D Stencil: out[i] = in[i-1] + in[i] + in[i+1]
 * 
 * Memory layout:
 *   0x000-0x00F: Input array (16 words)
 *   0x010-0x01F: Output array (16 words)
 * 
 * Boundary handling: clamp (use in[0] for left of 0, in[15] for right of 15)
 *
 * R0  = 0 (hardwired)
 * R1  = lane_id (hardwired, 0-15)
 * R3  = input base (0)
 * R4  = output base (16)
 * R5  = constant 1
 * R6  = addr of in[lane_id]
 * R7  = addr scratch
 * R8  = in[i] (center)
 * R9  = in[i-1] (left)
 * R10 = in[i+1] (right)
 * R11 = result
 * R12 = constant 15
 */

static const u32 kernel_stencil[] = {
    /* ===== SETUP ===== */
    /* PC  0, 1 */ PACK(0x9300, 0x9410),       /* CONST R3, 0        | CONST R4, 16              */
    /* PC  2, 3 */ PACK(0x9C0F, 0x9501),       /* CONST R12, 15      | CONST R5, 1               */
    /* ===== LOAD CENTER AND LEFT ===== */
    /* PC  4, 5 */ PACK(0x3631, 0x7860),       /* ADD R6, R3, R1     | LDR R8, R6                */
    /* PC  6, 7 */ PACK(0x4765, 0x7970),       /* SUB R7, R6, R5     | LDR R9, R7                */
    /* ===== FIX LANE 0 ===== */
    /* PC  8, 9 */ PACK(0xA010, 0xB402),       /* CMP R1, R0         | BRz +2                    */
    /* PC 10,11 */ PACK(0xBE02, 0x3980),       /* BRnzp +2           | ADD R9, R8, R0             */
    /* PC 12,13 */ PACK(0xC000, 0x3765),       /* SYNC               | ADD R7, R6, R5             */
    /* ===== LOAD RIGHT ===== */
    /* PC 14,15 */ PACK(0x7A70, 0xA01C),       /* LDR R10, R7        | CMP R1, R12               */
    /* ===== FIX LANE 15 ===== */
    /* PC 16,17 */ PACK(0xB402, 0xBE02),       /* BRz +2             | BRnzp +2                  */
    /* PC 18,19 */ PACK(0x3A80, 0xC000),       /* ADD R10, R8, R0    | SYNC                      */
    /* ===== COMPUTE AND STORE ===== */
    /* PC 20,21 */ PACK(0x3B98, 0x3BBA),       /* ADD R11, R9, R8    | ADD R11, R11, R10          */
    /* PC 22,23 */ PACK(0x3741, 0x807B),       /* ADD R7, R4, R1     | STR R7, R11                */
    /* ===== DONE ===== */
    /* PC 24,25 */ PACK(INSTR_DONE, INSTR_DONE),/* DONE              | DONE                      */
};

#define KERNEL_STENCIL_SIZE (sizeof(kernel_stencil) / sizeof(u32))

typedef struct {
    u32 id;
    const u32 *code;
    u32 size_words;
} kernel_def_t;

static const kernel_def_t kernel_defs[] = {
    { KERNEL_MATMUL,       kernel_matmul,       KERNEL_MATMUL_SIZE       },
    { KERNEL_PREFIX_SCAN,  kernel_prefix_scan,  KERNEL_PREFIX_SCAN_SIZE  },   /* NEW */
    { KERNEL_STENCIL,  kernel_stencil,  KERNEL_STENCIL_SIZE  },
};

#define NUM_KERNELS (sizeof(kernel_defs) / sizeof(kernel_defs[0]))

// ============================================================
// RUNTIME
// ============================================================

void kernel_library_init(void) {
    u32 table_offset = KERNEL_TABLE_OFFSET;
    u32 code_offset = KERNEL_CODE_OFFSET;
    u32 code_word_offset = 0;

    // Write table header
    ddr3_write32(table_offset + 0, 0x4750554B);  // magic "GPUK"
    ddr3_write32(table_offset + 4, NUM_KERNELS);

    // Write table entries and kernel code
    u32 entry_offset = table_offset + 8;

    for (u32 i = 0; i < NUM_KERNELS; i++) {
        // Write table entry
        ddr3_write32(entry_offset + 0, kernel_defs[i].id);
        ddr3_write32(entry_offset + 4, code_word_offset);
        ddr3_write32(entry_offset + 8, kernel_defs[i].size_words);
        entry_offset += 12;

        // Write kernel code to DDR
        for (u32 j = 0; j < kernel_defs[i].size_words; j++) {
            ddr3_write32(code_offset + (code_word_offset + j) * 4,
                         kernel_defs[i].code[j]);
        }

        code_word_offset += kernel_defs[i].size_words;
    }

    fence();

    xil_printf("Kernel library initialized: %d kernels, %d words total\r\n",
               NUM_KERNELS, code_word_offset);
}

int load_kernel_to_gpu(u32 kernel_id) {
    u32 table_offset = KERNEL_TABLE_OFFSET;
    u32 num_kernels = ddr3_read32(table_offset + 4);
    u32 entry_offset = table_offset + 8;

    for (u32 i = 0; i < num_kernels; i++) {
        u32 id = ddr3_read32(entry_offset + 0);

        if (id == kernel_id) {
            u32 code_word_offset = ddr3_read32(entry_offset + 4);
            u32 size_words = ddr3_read32(entry_offset + 8);

            // Copy from DDR to IMEM using Xil_Out32 (matches imem_write pattern)
            for (u32 j = 0; j < size_words; j++) {
                u32 instr = ddr3_read32(KERNEL_CODE_OFFSET + (code_word_offset + j) * 4);
                Xil_Out32(IMEM_BASE + j * 4, instr);
            }

            fence();

            //xil_printf("Loaded kernel %d (%d words) to IMEM\r\n",
            //           kernel_id, size_words);

            return (int)size_words;
        }

        entry_offset += 12;
    }

    //xil_printf("ERROR: Kernel %d not found\r\n", kernel_id);
    return -1;
}

void dump_kernel_table(void) {
    u32 table_offset = KERNEL_TABLE_OFFSET;
    u32 magic = ddr3_read32(table_offset + 0);
    u32 num_kernels = ddr3_read32(table_offset + 4);

    //xil_printf("\r\n=== Kernel Table ===\r\n");
    //xil_printf("Magic: 0x%08X %s\r\n", magic,
    //           (magic == 0x4750554B) ? "(OK)" : "(BAD)");
    //xil_printf("Num kernels: %d\r\n\r\n", num_kernels);

    u32 entry_offset = table_offset + 8;

    for (u32 i = 0; i < num_kernels; i++) {
        u32 id = ddr3_read32(entry_offset + 0);
        u32 offset = ddr3_read32(entry_offset + 4);
        u32 size = ddr3_read32(entry_offset + 8);

        //xil_printf("Kernel %d: offset=%d, size=%d words\r\n", id, offset, size);
        //xil_printf("  First 4 instructions:\r\n");

        for (u32 j = 0; j < 4 && j < size; j++) {
            u32 instr = ddr3_read32(KERNEL_CODE_OFFSET + (offset + j) * 4);
            //xil_printf("    [%2d] 0x%08X\r\n", j, instr);
        }

        entry_offset += 12;
    }
    //xil_printf("====================\r\n\r\n");
}

int load_kernel_direct(u32 kernel_id) {
    for (u32 i = 0; i < NUM_KERNELS; i++) {
        if (kernel_defs[i].id == kernel_id) {
            const u32 *src = kernel_defs[i].code;
            u32 n = kernel_defs[i].size_words;
            for (u32 j = 0; j < n; j++)
                Xil_Out32(IMEM_BASE + j * 4, src[j]);
            fence();
            return (int)n;
        }
    }
    return -1;
}