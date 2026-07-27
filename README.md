# Tri-Core GPU SoC With Microblaze-V Host 
An educational custom 3-core parallel processor in SystemVerilog, controlled by MicroBlaze V host and placed on Kintex-7 board.

## Introduction
The purpose of this project was to further my own understanding of parallel processors and familiarize myself with new tools in FPGA design, such as block diagram to instantiate hard IPs like the MicroBlaze V, DMA Engines, DDR3 Memory, AXI controllers, etc. Additionally to practice the development of firmware to the host controller in charge of writing to the parallel processors data and instruction memory, and controlling when it starts and stops.

For someone trying to learn how a GPU works, I recommend starting with tiny_gpu and smol_gpu, both great resources which inspired me to begin my design on my parallel processor, which grew through many iterations before becoming what it is now. I will omit from a basic introduction to GPU architecture, instead diving into my design in particular, but to the interested person I suggest the two resources mentioned before: tiny_gpu and smol_gpu.
## Getting Started

### Clone
git clone https://github.com/Cole-Codemann/SIMT-GPU-Core.git

### Simulation (Single Core)
1. Create new Vivado project
2. Add all files from `rtl/src/`
3. Add testbench from `rtl/tb/` (use `GPU_top_tb.sv` for full core verification)
4. Run behavioral simulation

### Hardware Build
1. Create new Vivado project targeting `xc7k325tffg900-2`
2. Import block design from `platform/vivado/GPU_Design.bd`
3. Add constraints from `platform/vivado/*.xdc`
4. Set `top.sv` as top module
5. Generate HDL wrapper
6. Run synthesis → implementation → generate bitstream
7. Export hardware (.xsa) to Vitis for firmware development

## Requirements
- **Vivado 2025.2**
- **Vitis 2025.2** (for MicroBlaze firmware)
- **Digilent Genesys 2** (Kintex-7) for hardware deployment

Developed and tested on 2025.2 only. Older versions may not support MicroBlaze V. If you encounter issues, please open an issue.

## Quick Specs Summary
| Spec | Value |
|------|-------|
| Cores | 3 |
| Warps per Core | 4 |
| Lanes per Warp | 16 |
| Total Lanes | 192 |
| Word Size | 16-bit |
| Instruction Size | 16-bit |
| Registers per Lane | 16 (R0-R15) |
| Address spaces per Core | 2 |
| IMEM per Address space | 4 KB |
| DMEM per Address space | 32 KB |
| Target Clock | 100 MHz |
| Target Board | Digilent Genesys 2 (Kintex-7) |
| Pipeline Depth | 5-stage (F → D → E → E2 → WB) |
| Hazard Handling | Scoreboard + 2-level data forwarding |
| Branch Penalty | 1 cycle |

## Results at a Glance
| Metric |	Value |
|------|-----|
| 16×16 Matrix Multiply | 6,286 cycles / core |
| Multi-core Scaling (3 cores) | 2.83× (94.3% efficiency) |
| Peak ALU Throughput | 1,596 MIOPS (99.8% of theoretical) |
| Memory BW (concurrent) | 709 MB/s |
| Memory BW (sequential) | 172 MB/s |
All three benchmark kernels are memory-bound. Detailed analysis is in the Performance and Roofline sections.

## Terminology Note
Before diving in, there are many different sources out there that call different components of the GPU different names, with NVIDIA being one of the more popular. I will define what each terminology means to me, as taken from some sources, but for those more familiar with NVIDIA terminology here is a quick comparison table. One thing to note is that although I use the term lane instead of thread, I still use SIMT (Single Instruction, Multiple Thread) due to it's prevalence and recent increase of usage over the old term SIMD (Single Instruction, Multiple Data).
| My Design | NVIDIA Equivalent |
|------|-------|
| Lane | Thread |
| Warps | Warp |
| Core | Streaming Multiprocessor (SM) |

### High Level - Parallel architecture at many levels
There are many layers of parallelization at play in a GPU design, and the terminology between threads, warps, and cores lack universal meaning between companies/architectures, so I will explain how each of these are defined in my design and how each provides a level of parallel abstraction. 

If we were to focus on the "smallest" processing component, we would have a **lane**. A lane is primarily composed at 16 registers that are, for the most part, unique to it.

A lane, however, has no "autonomy"; 16 lanes are controlled by a single **warp**, with the warp being a traditional SIMT (Single Instruction, Multiple Threads). A warp takes in a single instruction, determines which lanes should be running it, then performs the operation on each of the active lanes at the same time. Lets say for example an instruction goes to the warp telling it multiply Register 4 by Register 5, and place the result in Register 6. The warp will apply this operation to each of its 16 lanes, regardless of their values in each of the three registers. This is the basis of SIMT processing. Below is an example of one of these processors running 16 lanes, the design is heavily inspired by RISC-V 5 stage processor with some custom changes to match the architecture closer.

![Diagram](./images/warp.drawio.png)

Each warp executes a 5-stage pipeline: FETCH → DECODE → EXE → EXE2 → WB. The first three stages are standard: fetch the instruction, decode control signals and read registers, execute in the ALU. The EXE2 stage exists to break what would otherwise be the critical timing path: the ALU output (purely combinational across 16 parallel lanes, including 16 multipliers) feeds through a writeback mux and NZP flag derivation before reaching the register file write port. At 100 MHz on Kintex-7, this path does not close in a single cycle. EXE2 registers the ALU result, and WB writes it back, splitting the path into two short stages rather than one long one. To keep the pipeline fed despite this depth, the warp implements both scoreboarding and two-level data forwarding. The scoreboard tracks in-flight destination registers and NZP flag updates, stalling decode when a source operand isn't ready yet. Data forwarding from both EXE2 and WB back to decode resolves most dependencies without stalling, with back-to-back dependencies stalling only one clock cycle, a latency that warp scheduling can typically hide.

While each warp acts as a stand-alone processor in most control aspects, there are some resources they have to share, this is due to the fact that four warps coexist in a single core. Most importantly, these warps share a common ALU, meaning all additions, subtractions, multiplications, etc. need to be scheduled since only one warp has access to it at a time (This is one of the larger differences between my current design and "realer" GPU's who have many different computational resources that are shared such as FPUs, MACs, etc... See section "Future Work" for how this is a goal to implement. In addition to the ALU, all the warps share a memory controller, which stands between the warps and the DMEM bank, scheduling and performing all reads and writes for the warps. The inclusion of the warps allow for maximized usage of the more bottlenecked and/or hardware intensive blocks while allowing each warp to step through their other instructions in parallel, increasing throughput substantially. Below is a simplified representation of how each component interfaces between eachother.

![Diagram](./images/singlecore.drawio.png)

Finally, we take another step backwards; All together, the 4 warps, memory controller, ALU, and warp scheduled make up a single **core**. Each core is directed towards it's own data memory and instruction memory, which in this case is designed as a ping-pong buffer, which will be talked about later. The Kintex-7 board is capable of containing three unique cores, each with their own address spaces to work out of. The host, a MicroBlaze V processor, can directly control the reset signal of each core and monitor their "done" signals. Additionally, the MicroBlaze V works with a DMA Engine to transfer data memory between their DMEM space and the DDR3 memory, allowing for high speed operational interface. Below we can again see a simplified demonstration of how these three cores are all maintained by the single host and DMA

![Diagram](./images/3core.drawio.png)

### ISA
Each instruction is passed into IMEM and given to every warp in the core. In order to focus my time on overall architecture/ Further SoC integration, I chose a relatively simple 16-bit word, 16 bit instruction set, seen below:


| Opcode | Mnemonic | Encoding | Description |
|--------|----------|----------|-------------|
| `0000` | NOP | `0000 xxxx xxxx xxxx` | No operation |
| `0011` | ADD | `0011 rd rs rt` | rd = rs + rt |
| `0100` | SUB | `0100 rd rs rt` | rd = rs − rt |
| `0101` | MUL | `0101 rd rs rt` | rd = rs × rt |
| `0111` | LDR | `0111 rd rs xxxx` | rd = mem[rs] |
| `1000` | STR | `1000 xxxx rs rt` | mem[rs] = rt |
| `1001` | CONST | `1001 rd imm[7:0]` | rd = zero_extend(imm) |
| `1010` | CMP | `1010 xxxx rs rt` | NZP flags = flags(rs − rt) |
| `1011` | BRnzp | `1011 nzp[2:0] x imm[7:0]` | Conditional branch by ±imm |
| `1100` | SYNC | `1100 xxxx xxxx xxxx` | Pop divergence mask stack |
| `1101` | LDC | `1101 rd rs xxxx` | rd = mem[base+lane] (concurrent) |
| `1110` | STRC | `1110 xxxx rs rt` | mem[base+lane] = rt (concurrent) |
| `1111` | DONE | `1111 xxxx xxxx xxxx` | Warp execution complete |

**Encoding fields:**
- `op[15:12]` - Opcode
- `rd[11:8]` - Destination register
- `rs[7:4]` - Source register 1
- `rt[3:0]` - Source register 2
- `imm[7:0]` - 8-bit immediate (for CONST, BRnzp)
- `nzp[2:0]` - Branch condition flags (negative/zero/positive)

The DMEM address space seen by the core is 14 bits wide. The concurrent instructions require that lane 0's address be aligned to a 16-word boundary; lane N then accesses base+N, where the low 4 address bits are derived from the lane ID. This constraint lets the memory controller service all 16 lanes in exactly 2 BRAM cycles (one for lanes 0–7, one for lanes 8–15) instead of up to 16 sequential accesses.  
There are three special registers in each lane:  
R0 = Always 0  
R1 = Lane ID  
R2 = Warp ID  

Utilizing the Lane and Warp ID is the key to having a single program address a range of address space across various warps and lanes.

All arithmetic operations are applied to every valid lane within the warp. However, with relatively simple masking applied through the software, operations done on any arbitrary number of lanes is easy to accomplish.

## Divergence
Whereas a classic CPU has a straightforward idea of branching, and changing PC depending on conditional tests, a SIMT processor has more complication to it, due to the simple question "what if some lanes meet the condition to branch, but others don't?". There are many unique approaches to this problem, I decided to implement my own slightly modified design involving NZP flags, stacked masks, and conditional branching. 

The CMP, BRnzp, and SYNC instruction carry all the weight of controlling the flow of the warp and divergence. The CMP instruction subtracts one register from another and sets the n - negative, z - zero, and p - postive flag depending on the result, calculated unique for each lane. The BRnzp instruction allows the programmer to determine which flags to look for when deciding when to branch, for example if nzp = '100' in the instruction, then only the lanes with their negative flag set will branch, applying a mask to all other lanes. The destination of the branch is equal to the current PC plus the signed 8-wide immediate passed into the instruction. When a mask is applied to a warp, that particular mask also gets pushed into a LIFO stack. The overall mask applied to the warp will be the OR'ed result of the entire mask stack, allowing for nested branches. When a SYNC instruction is called, it simply pops the top mask off the stack. Below is an example of nested masks and SYNC call:

![Diagram](./images/Warp-Divergence.drawio.png)

Some nuances for this design include the choice to not add the mask stack when an unconditional branch has all lanes taking the branch, typically done by allowing a branch of the n, z, or p flags are set: nzp = '111'. This allows for programmers to jump around their instruction count freely using unconditional branching (essentially, a jump instruction) without fear of overflowing the mask stack. Additionally, a programmer is able to apply a mask without jumping to a new PC at all, by setting the lower 8 bits of the BRnzp instruction to all 0's, the processor never adds to it's PC and steps forward normally, with the new mask applied.

## Memory Controller

All four warps in a core share a single memory controller that arbitrates access to DMEM. When a warp issues a load or store, it holds the request signal high until the controller acknowledges it and enqueues the operation into a FIFO. The warp's pipeline stalls until the controller signals completion. For loads, this also delivers the read data back into the pipeline.

The controller supports two access modes:

Sequential (LDR/STR): The controller iterates through each unmasked lane one at a time, issuing a separate BRAM access per lane. In the worst case this is 16 serial memory operations for a single instruction, and it was the dominant bottleneck in early benchmarking.

Concurrent (LDC/STRC): All 16 lanes are serviced in exactly 2 BRAM cycles by exploiting the 128-bit (8-word) port width; One cycle for lanes 0–7, one for lanes 8–15. The constraint is that lane 0's address must be aligned to a 16-word boundary, with lane N accessing base+N. This maps naturally to vector loads and column/row accesses in matrix operations. Measured bandwidth improved roughly 4× over sequential access for well-ordered patterns (709 MB/s concurrent vs. 172 MB/s sequential).

## ALU Controller
The ALU controller is responsible for ensuring fair and clear usage of the ALU lanes, a single block of hardware in our case. The controller maintains fine-course warp scheduling with round-robin arbitration. This hands off access between the warps by clock cycle depending on when they need to perform a computation, and doesn't allow for a single warp to run consecutively when another is waiting for access. 

## MicroBlaze V and SoC Implementation
The MicroBlaze V (MBV) acts as the host of the system, and is communicated to via the Vitis suite, allowing for direct writing to the host without needing to reprogram the full FPGA. The MBV is capable of directly writing to and from the Data and Instruction memory spaces of the GPU via AXI interface that connects it. The process of directly reading and writing, especially on the large address space that holds the data memory, is very slow for the MBV to do directly, which is why the DMA was created and is primarily responsible.

Currently, on initialization, the MBV loads the DDR3 space with instruction sets corresponding to commonly used program; in my case, I have three operations loaded and used as my primary benchmark measures. The MBV holds the addresses and size of these instructions and can pass them to the DMA to load into the instruction space of any of the cores. Similarly, the DMA is controlled by the MBV to read and write to the data memory space of each of the GPU cores in order to maintain high core utilization. 

Each core memory space is built as a ping-pong buffer by diving the total address space in two. The GPU core does not have control of which address space it is reading and writing to, as this is something fully controlled by the host. This allows the same instruction set in the GPU to be able to run two times in a immediate succession, each targeting a different data memory space, while the host collects the data from the finished operation and prepares the space again for the next, maximizing core utilization.

Currently, the addition of the two additional cores on top of the first has had a near 0% slowdown on core utilization, with the DMA able to successfully service all 3 DMEM spaces and sustain their buffers on my benchmark consecutive 16x16 matrix multiplication operations.

## Example: Programming the GPU from MicroBlaze

Instructions are 16-bit, packed two-per-32-bit word via `PACK(even_PC, odd_PC)`. MicroBlaze writes packed words to IMEM, loads data into DMEM, then releases the GPU and polls for completion.

### Minimal Example

```
PC 0: CONST R3, 5       ; R3 = 5 (all lanes)          → 0x9305
PC 1: CONST R4, 3       ; R4 = 3 (all lanes)          → 0x9403
PC 2: ADD   R5, R3, R4  ; R5 = 8 (all lanes)          → 0x3534
PC 3: STR   R0, R5      ; mem[0] = R5 = 8             → 0x8005
PC 4: DONE              ;                              → 0xF000
```
```c
#include "main.h"

static const u32 program[] = {
    PACK(0x9305, 0x9403),
    PACK(0x3534, 0x8005),
    PACK(INSTR_DONE, INSTR_DONE),
};

int main(void) {
    gpu_hold();
    imem_write(program, 3);
    gpu_release_run();
    while (!gpu_done());
    xil_printf("Result: %d\r\n", dmem_read16(0));  // 8
    gpu_stop();
    while (1);
}
```

### Practical Example: Running a Matrix Multiply

```c
#include "main.h"
#include "kernel_library.h"

int main(void) {
    gpu_hold();
    kernel_library_init();
    load_kernel_direct(KERNEL_MATMUL);

    // Bulk-copy input matrices from DDR3 (pre-staged) into DMEM via CDMA
    cdma_reset();
    cdma_transfer(DDR3_BASE + DDR3_MAT_A_OFFSET, DMEM_BYTE_ADDR(MAT_A_BASE), MAT_BYTES);
    cdma_transfer(DDR3_BASE + DDR3_MAT_B_OFFSET, DMEM_BYTE_ADDR(MAT_B_BASE), MAT_BYTES);
    dmem_clear(MAT_C_BASE, 256);
    fence();

    gpu_release_run();
    while (!gpu_done());

    u32 cycles = gpu_active_cycles();
    gpu_stop();

    xil_printf("Done in %d cycles, C[0][0] = %d\r\n",
               cycles, dmem_read16(MAT_C_BASE));
    while (1);
}
```

**Pattern:** hold → load kernel → load data → release → poll → read results → stop.

A more complete program involving multiple cores, alternating address spaces, and repeated operations can be found in the repo.

## Project structure
```
SIMD-GPU-Core/  
├── README.md  
│  
├── rtl/                    # Everything needed to simulate single-core  
│   ├── src/  
│   │   └── *.sv  
│   └── tb/                   
│       └── *_tb.sv          
│
└── platform/               # For programming board + multicore setup  
    ├── vivado/  
    │   ├── GPU_Design.bd  
    │   ├── GPU_Design_wrapper.v  
    │   └── *.xdc  
    └── vitis/  
        ├── Example program  
        │   ├── main.c  
        │   ├── main.h  
        │   ├── kernel_library.c  
        │   └── kernel_library.h  
        └── More programs...     
```

## Simulation
Because this project was designed and built with a board in mind (the Kintex-7), high level simulations were not made and instead tested on the board itself. There are however, multiple test benches for the individual modules provided in the files, at the highest level simulating a full core running a matrix multiplication algorithm. Note: Vivado simulation is required, SystemVerilog usage is not compatible on iVerilog.

For those who do have access to an Kintex-7 board I highly encourage running the full programs onto the MicroBlaze. For those who do not, I hope the simulation of a single core running a matrix multiplcation is interesting enough to sate you. 

### Performance
Here are some tangible results of common parallel workloads, when ran on one of my cores.

| Kernel | Description | GPU Cycles |
|--------|-------------|------------|
| 16×16 Matrix Multiply | 4 warps each compute 4 rows of result | 6,286 |
| Exclusive Prefix Scan | Hillis-Steele across 16 lanes | 354 |
| 1D 3-Point Stencil | Clamped boundary, 16 elements | 197 |

Multi-core scaling was measured by running the same matmul kernel across 1–3 cores simultaneously and comparing total session time:

| Cores | Cycles | Total Ops | Scaling |
|-------|--------|-----------|---------|
| 1 | 6,489 | 8,192 | 1.00× |
| 2 | 6,697 | 16,384 | 1.93× |
| 3 | 6,881 | 24,576 | 2.83× |

The near-linear scaling comes from each core having its own DMEM and the CDMA being fast enough to keep all three fed without contention.

### Roofline Analysis
I performed some roofline analysis to see the limits of my processor design. A Roofline model plots a kernel's throughput against its operational intensity (OI) — the ratio of compute operations to bytes of memory moved. Two ceilings define the upper bound: a flat compute ceiling (how fast the ALU can work) and a sloped memory bandwidth ceiling (how fast data moves in and out). Where they intersect is the ridge point; kernels below the ridge are memory-bound, kernels above are compute-bound. The three benchmark kernels and several synthetic probes are plotted against both bandwidth ceilings below.

![Diagram](./images/roofline_graph.png)

Ceilings were measured empirically on hardware:

| Metric | Value |
|--------|-------|
| Compute ceiling (useful ops) | 1,064 MIOPS/core |
| Compute ceiling (total, incl. overhead) | 1,596 MIOPS/core |
| Theoretical max | 1,600 MIOPS (16 ops/cycle @ 100 MHz) |
| Memory BW (concurrent) | 709 MB/s |
| Memory BW (sequential) | 172 MB/s |
True Memory BW depends on operation composition of concurrent versus sequential memory accesses.

All three benchmark kernels fall below the concurrent ridge point, making them memory-bound:

| Kernel | Ops/Byte (OI) | MIOPS | MB/s | Bottleneck |
|--------|---------------|-------|------|------------|
| 16×16 Matrix Multiply | 0.484 | 130 | 268 | Memory |
| Exclusive Prefix Scan | 0.189 | 55 | 291 | Memory |
| 1D Stencil | 0.250 | 64 | 259 | Memory |

This is expected, with a single shared ALU and wide 128-bit concurrent memory access, the compute ceiling is high relative to what these kernels demand, but they can't move data fast enough to reach it. The concurrent memory instructions (LDC/STRC) were a direct response to early benchmarking, improving memory throughput roughly 4× over sequential access for well-ordered patterns.

### Educational: Interesting Timing Problems
For educational reasons, I wanted to talk briefly about two of the more interesting examples of timing problems I ran into during the development of this project, read only if interested:

When building the mask stack to determine divergence, particularly for nested loops, my output mask value was originally a combinational circuit taken from OR'ing each lane in all masks on the stack. This mask would then be used to determine other combinational logic, such as data forwarding, causing long combinational paths. To solve this, I changed my output mask to be registered and only update on pops or pushes to the mask stack, cutting combinational path significantly without any need to introduce bubbles or architectural slowdown.

The next example came from giving ALU access to the warps. I wanted to make sure that if the resources were available, the clock cycle that the ALU was needed by a warp, it could be given access and register the results on the next clock cycle. Having the warps request access on the cycle they needed failed timing, since the request had to go through the warp controllers FSM, then feed into large mux's to select that warps data, then go through the ALU itself, too long of a combinational path for a single clock cycle. To fix this, I included into the warps a lookahead circuit which would determine if on the next clock cycle it would need the ALU, based on factors such as expected stalling. This lookahead circuit would give the warp controller time register access for the warp into the mux, allowing for the warp to flow through the ALU on the clock cycle the data was ready. The logic for this lookahead became increasingly complex with the introduction of scoreboarding, ability to chain together multiple requests, and stalls that lasted an unpredictable amount of time.

## Acknowledgments
Special thanks go to Nick Beser, my academic advisor providing guidance on the development of the SoC.

Johns Hopkins University for the Genesys 2 Board which I build the SoC on.

Adam Majmudar, the creator of [tiny-gpu](https://github.com/adam-maj/tiny-gpu), and  
Grubre Jakub, the creator of [smol-gpu](https://github.com/Grubre/smol-gpu).  
My inspiration for starting this project was heavily taken from these two very educational and interesting projects.

The architecture itself is a modified variant of [RISC-V](https://github.com/riscv)

## Roadmap / Limitations
There is still a lot of work to be done around the GPU itself. As a whole I want to make the GPU itself more "realistic" and faster, which is a drive for many of my future goals.

- [ ] Add Floating Point Unit
- [ ] Pipeline arithmetic processes
- [ ] Create L1 and L2 "scratchpad" for inter and intra warp communication
- [ ] Reach 200 MHz clock speed
- [ ] Implement Caching
- [ ] Move to 32 bit words and instructions.
- [ ] Build as assembler to allow easier programming.
- [ ] Consolidate concurrent and non-concurrent memory instructions

## AI Usage
This project was created with the help of AI in some tasks, primarily in: Writing in-line comments, writing C code, writing repetitive or "simple" HDL, aid in debugging, and learning new software. Everything AI produced was double checked by me for correctness, and special effort was made to avoid AI for design/ architectural decisions, since that was a major learning point of the project and I wanted successes and failures on that front to be made by me.

## License
This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.
