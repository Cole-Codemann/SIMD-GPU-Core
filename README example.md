# 3 Core Microblaze-V Controller 
An educational custom 3-core parallel processor in SystemVerilog, controlled by MicroBlaze V host and placed on Artix-V board.

## Introduction

The purpose of this project was to further my own understanding of parallel processors and familiarize myself with new tools in FPGA design, such as block diagram to instantiate hard IPs like the MicroBlaze V, DMA Engines, DDR3 Memory, AXI controllers, etc. Additionally to practice the development of firmware to the host controller in charge of writing to the parallel processors data and instruction memory, and controlling when it starts and stops.

For someone trying to learn how a GPU works, I recommend starting with tiny_gpu and smol_gpu, both great resources which inspired my to begin my design on my parallel processor, which grew through many iterations before becoming what it is now. I will omit from a basic introduction to GPU architecture, instead diving into my design in particular, but to the interested person I suggest the two resources mentioned before: tiny_gpu and smol_gpu.

### High Level - Parallel architecture at many levels
There are many layers of parallelization at play in a GPU design, and the terminology between threads, warps, and cores lack universal meaning between companies/architectures, so I will explain how each of these are defined in my design and how each provides a level of parallel abstraction. 

If we were to focus on the "smallest" processing component, we would have a **lane** (or a thread, as some call it). A lane is primarily composed at 16 registers that are, for the most part, unique to it.

A lane, however, has no "autonomy"; 16 lanes are controlled by a single **warp**, with the warp being a traditional SIMT (Single Instruction, Multiple Threads). A warp takes in a single instruction, determines which lanes should be running it, then performs the operation on each of the active lanes at the same time. Lets say for example an instruction goes to the warp telling it multiply Register 4 by Register 5, and place the result in Register 6. The warp will apply this operation to each of its 16 lanes, regardless of their values in each of the three registers. This is the basis of SIMT processing. Below is an example of one of these processors running 16 lanes, the design is heavily inspired by RISC-V 5 stage processor with some custom changes to match the architecture closer.

![Diagram](./images/warp.drawio.png)

While each warp acts as a stand-alone processor in most control aspects, there are some resources they have to share, this is due to the fact that four warps coexist in a single core. Most importantly, these warps share a common ALU, meaning all additions, subtractions, multiplcations, etc. need to be scheduled since only one warp has access to it at a time (This is one of the larger differences between my current design and "realer" GPU's who have many different computational resources that are shared such as FPUs, MACs, etc... See section "Future Work" for how this is a goal to implement. In addition to the ALU, all the warps share a memory controller, which stands between the warps and the DMEM bank, scheduling and performing all reads and writes for the warps. The inclusion of the warps allow for maximized usage of the more bottlenecked and/or hardware intensive blocks while allowing each warp to step through their other instructions in parallel, increasing throughput substantially. Below is a simplified representation of how each component interfaces between eachother.

![Diagram](./images/singlecore.drawio.png)

Finally, we take another step backwards; All together, the 4 warps, memory controller, ALU, and warp scheduled make up a single **core**. Each core is directed towards it's own data memory and instruction memory, which in this case is designed as a ping-pong buffer, which will be talked about later. The Artix-V board is capable of containing three unique cores, each with their own address spaces to work out of. The host, a MicroBlaze V processor, can directly control the reset signal of each core and monitor their "done" signals. Additionally, the MicroBlaze V works with a DMA Engine to transfer data memory between their DMEM space and the DDR3 memory, allowing for high speed operational interface. Below we can again see a simplified demonstration of how these three cores are all maintained by the single host and DMA

![Diagram](./images/3core.drawio.png)

### ISA
Each instruction is passed into IMEM and given to every warp in the core. In order to focus my time on overall architecture/ Further SoC inegration, I chose a relatively simple 16-bit word, 16 bit instruction set, seen below:

| mnemonic | opcode  | funct3 | funct7    |
|----------|---------|--------|-----------|
| lui      | S110111 |   —    |     —     |
| auipc    | S010111 |   —    |     —     |

TALK ABOUT ADDRESS SPACE for each core *************************

All arithmetic operations are applied to every valid lane within the warp. However, with relatively simple masking applied through the software, operations done on any abitrary number of lanes is easy to accomplish.

## Divergence
Whereas a classic CPU has a straightforward idea of branching, and changing PC depending on conditional tests, a SIMT processor has more complication to it, due to the simple question "what if some lanes meet the condition to branch, but others don't?". There are many unique approaches to this problem, I decided to implement my own slightly modified design involving NZP flags, stacked masks, and conditional branching. 

The CMP, BRnzp, and SYNC instruction carry all the weight of controlling the flow of the warp and divergence. The CMP instruction subtracts one register from another and sets the n - negative, z - zero, and p - postive flag depending on the result, calculated unique for each lane. The BRnzp instruction allows the programmer to determine which flags to look for when deciding when to branch, for example if nzp = '100' in the instruction, then only the lanes with their negative flag set will branch, applying a mask to all other lanes. The destination of the branch is equal to the current PC plus the signed 8-wide immediate passed into the instruction. When a mask is applied to a warp, that particular mask also gets pushed into a LIFO stack. The overall mask applied to the warp will be the "or'ed" result of the entire mask stack, allowing for nested branches. When a SYNC instruction is called, it simply pops the top mask off the stack. Below is an example of nested masks and SYNC call:

![Diagram](./images/Warp-Divergence.drawio.png)

Some nuances for this design include the choice to not add the mask stack when an unconditional branch has all lanes taking the branch, typically done by allowing a branch of the n, z, or p flags are set: nzp = '111'. This allows for programmers to jump around their instruction count freely using unconditional branching (essentially, a jump instruction) without fear of overflowing the mask stack. Additionally, a programmer is able to apply a mask without jumping to a new PC at all, by setting the lower 8 bits of the BRnzp instruction to all 0's, the processor never adds to it's PC and steps forward normally, with the new mask applied.

## Memory Controllers
The next hurdle to overcome, beyond the scope of a single SIMT, was to have our hardware determine how to allocate shared resources between each warp. Starting with the memory controller, this is a major bottleneck for any processor design, even with all data being preloaded into allocated BRAM by the host to enable fast read/write times. 

To start with the warps side, when a memory request is made from a warp, it signals out to the memory controller whether it needs a load or read performed, and whether that request is concurrent or not (more into this shortly). The warp will hold this signal high until the memory controller pulses an acknoledgement, at which time the warp knows it's request has been read. The warp will then hold the data in the EXE until the memory controller sends another signal, signifying it's finished the request. In the case of a read request, this signal acts as a 'valid' pulse which the warp will recognize and store the data from the memory controller into it's EXE2 register, continuing the pipeline. 

I implemented two modes of read/write instructions for the warps to use depending on use case when interfacing with the memory controller: concurrent and non-concurrent. Given 16 lanes per warp, meaning 16 unique word read/writes across any range of memory space, the non-concurrent instruction performs close to how one might expect; The memory controller goes to the targeted memory address for each unmasked lane and performs the operation needed there, whether that's writing data from another register in that lane, or reading the value in memory which is stores locally until finished and ready to present back to the warp. This, however, involves up to 16 unique memory accesses. This revealed to be a major bottleneck in almost every benchmark operation tested.

After observing this benchmark, I created two more instructions for concurrent read and write operations. The thought process here is that host will present words concurrently in the memory space for many of the operations faced, from matrix multiplication, to most types of vector math. I therefore widened the BRAM port to 8 words and created the concurrent instructions to follow the condition that each lane must be filled with the address in lane 0 plus targeted lane id. In practice this looks similar to copying over a 16 word wide vector starting an the memory address in lane 0. This allows for memory operations to be performed in 2 operations instead of 16, significantly opening the bottleneck of operation, especially for initial reads which are typically well-ordered by the host.

## ALU Controller
The ALU controller is responsible for ensuring fair and clear usage of the ALU lanes, a single block of hardware in our case. The controller maintains fine-course warp scheduling with round-robin arbitration. This hands off access between the warps by clock cycle depending on when they need to perform a computation, and doesn't allow for a single warp to run consecutively when another is waiting for access. 

## MicroBlaze V and SoC Implementation
The MicroBlaze V (MBV) acts as the host of the system, and is communicated to via the Vitis suite, allowing for direct writing to the host without needing to reprogram the full FPGA. The MBV is capable of directly writing to and from the Data and Instruction memory spaces of the GPU via AXI *FIGURE OUT WHAT WORD GOES HERE* that connects it. The process of directly reading and writing, especially on the large address space that holds the data memory, is very slow for the MBV to do directly, which is why the DMA was created and is primarily responsible.

Currently, on initialization, the MBV loads the DDR3 space with instruction sets corresponding to commonly used program; in my case, I have three operations loaded and used as my primary benchmark measures. The MBV holds the addresses and size of these instructions and can pass them to the DMA to load into the instruction space of any of the cores. Similarly, the DMA is controlled by the MBV to read and write to the data memory space of each of the GPU cores in order to maintain high core utilization. 

Each core memory space is built as a ping-pong buffer by diving the total address space in two. The GPU core does not have control of which address space it is reading and writing to, as this is something fully controlled by the host. This allows the same instruction set in the GPU to be able to run two times in a immediate succession, each targeting a different data memory space, while the host collects the data from the finished operation and prepares the space again for the next, maximizing core utilization.

Currently, the addition of the two additional cores on top of the first has had a near 0% slowdown on core utilization, with the DMA able to successfully service all 3 DMEM spaces and sustain their buffers on my benchmark consecutive 16x16 matrix multiplication operations.

### Syntax
The general syntax looks as follows:
```
<mnemonic> <rd>, <rs1>, <rs2>       ; For R-type
<mnemonic> <rd>, <rs1>, <imm>       ; For I-type
<mnemonic> <rd>, <imm>              ; For U-type
<mnemonic> <rd>, <imm>(<rs1>)       ; For Load/Store
HALT                                ; For HALT
jalr <rd>, <label>                  ; jump to label
jalr <rd>, <imm>(<rs1>)             ; jump to register + offset
```
In order to turn the instruction from vector to scalar you can add the `s.` prefix.
So if you want to execute the scalar version of `addi` you would put `s.addi` as the mnemonic and use scalar registers as `src` and `dest`.

Each of the operands must be separated by a comma.

The comments are single line and the comment char is `#`.

#### Example
An example program might look like this:
```python
.blocks 32
.warps 12

# This is a comment
jalr x0, label              # jump to label
label: addi x5, x1, 1       # x5 := thread_id + 1
sx.slti s1, x5, 5           # s1[thread_id] := x5 < 5 (mask)
sw x5, 0(x1)                # mem[thread_id] := x5 (only non-masked threads exectute this)
halt                        # Stop the execution
```

## Project structure
The project is split into several subdirectories:
- `external` - contains external dependencies (e.g. doctest)
- `src` - contains the system-verilog implementation of the GPU
- `sim` - contains the verilator based simulation environment and the assembler
- `test` - contains test files for the GPU, the assembler and the simulator

## Simulation
Because this project was designed and built with a board in mind (the Artix-V), high level simulations were not made and instead tested on the board itself. There are however, multiple test benches for the individual modules provided in the files, at the highest level simulating a full core running a matrix multiplication algorithm. 

For those who do have access to an Artix-V board I highly encourage running the full programs onto the MicroBlaze. For those who do not, I hope the simulation of a single core running a matrix multiplcation is interesting enough to saite you. 

### Justfile (maybe we run this version instead of make)
First, and the more convenient way, is to use the provided [justfile](https://github.com/casey/just).
`Just` is a modern alternative to `make`, which makes it slightly more sane to write build scripts with.
In the case of this project, the justfile is a very thin wrapper around cmake.
The available recipes are as follows:
- `compile` - builds the verilated GPU and the simulator
- `run <input_file.as> [data_file.bin]` - builds and then runs the simulator with the given assembly file
- `test` - runs the tests for the GPU, the assembler and the simulator
- `clean` - removes the build directory

In order to use it, just type `just <recipe>` in one of the subdirectories.

**Note, that the paths you pass as arguments to the `run` recipe are relative to the root of the project.
This is due to the way that the `just` command runner works.**

### CMake
As mentioned, the justfile is only a wrapper around cmake.
In case you want to use it directly, follow these steps:
```bash
mkdir build
cd build
cmake ..
cmake --build . -j$(nproc)
# The executable is build/sim/simulator
# You can also run the tests with the ctest command when in the build directory
```


### Roofline analysis, Metrics taken, etc.
Analysis of hardware utilization
OI


The produced exectuable is located at `build/sim/simulator` (or you can just use the justfile).
You can run it in the following way:
```bash
./build/sim/simulator <input_file.as> <data_file.bin>
```
The simulator will first assemble the input file and load the binary data file into the GPU data memory.
The program will fail if the assembly code contained in the input file is ill-formed.

In case it manages to assemble the code, it will then run the simulation and print the first 100 words of the memory to the console.
This is a temporary solution and will be replaced by a more sophisticated output mechanism in the future.

### Educational: Interesting Timing Problems
Registering Mask
Lookahead on controller requests
Change from full combinational to scoreboard

For educational reasons, I wanted to talk briefly about two of the more interesting examples of timing problems I ran into during the development of this project, read only if interested:

When building the mask stack to determine divergence, particularly for nested loops, my output mask value was originally a combinational circuit taken from OR'ing each lane in all masks on the stack. This mask would then be used to determine other combinational logic, such as data forwarding causing long combinational paths. To solve this, I changed my output mask to be registered and only update on pops or pushes to the mask stack, cutting combinational path in half without any need to introduce bubbles or architectural slowdown.

The next example came from giving ALU access to the warps. I wanted to make sure that if the resources were available, the clock cycle that the ALU was needed by a warp, it could be given access and register the results on the next clock cycle. Having the warps request access on the cycle they needed failed timing, since the request had to go through the warp controllers FSM, then feed into large mux's to select that warps data, then go through the ALU itself, too long of a combinational path for a single clock cycle. To fix this, I included into the warps a lookahead circuit which would determine if on the next clock cycle it would need the ALU, based on factors such as expected stalling. This lookahead circuit would give the warp controller time register access for the warp into the mux, allowing for the warp to flow through the ALU on the clock cycle the data was ready. The logic for this lookahead became increasingly complex with the introduction of scoreboarding, ability to chain together multiple requests, and stalls that lasted an unpredictable amount of time.

## Acknowledgments
Special thanks go to Nick Beser, my academic advisor providing guidance on the development of the SoC.

Johns Hopkins University for the Genesys 2 Board which I build the SoC on.

Adam Majmudar, the creator of [tiny-gpu](https://github.com/adam-maj/tiny-gpu), and 
Grubre Jakub, the creator of [smol-gpu](https://github.com/Grubre/smol-gpu). 
My inspiration for starting this project was heavily taken from these two very educational and interesting projects.

The architecture itself is a modified variant of [RISC-V](https://github.com/riscv)

## Roadmap
There is still a lot of work to be done around the GPU itself. As a whole I want to make the GPU itself more "realistic" and faster, which is a drive for many of my future goals

- [ ] Add Floating Point Unit
- [ ] Pipeline arithmetic processes
- [ ] Create L1 and L2 "scratchpad" for inter and intra warp communication
- [ ] Reach 200 MHz clock speed
- [ ] Implement Caching
- [ ] Move to 32 bit words and instructions.
- [ ] Build as assembler to allow easier programming.
- [ ] Consolodate concurrent and non-concurrent memory instructions

Another step would be to implement a CUDA-like compiler as writing the assembly gets very tedious, especially with manually masking out the threads for branching.
