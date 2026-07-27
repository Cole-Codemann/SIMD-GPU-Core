#ifndef KERNEL_LIBRARY_H
#define KERNEL_LIBRARY_H

#include "main.h"

// Memory layout as OFFSETS from DDR3_BASE
#define KERNEL_TABLE_OFFSET   0x01000000
#define KERNEL_CODE_OFFSET    0x01001000

// Kernel IDs
#define KERNEL_MATMUL         0
#define KERNEL_PREFIX_SCAN    1 
#define KERNEL_STENCIL        2 

void kernel_library_init(void);
int load_kernel_to_gpu(uint32_t kernel_id);
void dump_kernel_table(void);
int load_kernel_direct(uint32_t kernel_id);

#endif