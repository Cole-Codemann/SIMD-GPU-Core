# Smol GPU
An educational custom 3-core parallel processor in SystemVerilog, controlled by MicroBlaze V host and placed on Artix-V board.

## Introduction

The purpose of this project was to further my own understanding of parallel processors and familiarize myself with new tools in FPGA design, such as block diagram to instantiate hard IPs like the MicroBlaze V, DMA Engines, DDR3 Memory, AXI controllers, etc. Additionally to practice the development of firmware to the host controller in charge of writing to the parallel processors data and instruction memory, and controlling when it starts and stops.

For someone trying to learn how a GPU works, I recommend starting with tiny_gpu and smol_gpu, both great resources which inspired my to begin my design on my parallel processor, which grew through many iterations before becoming what it is now. I will omit from a basic introduction to GPU architecture, instead diving into my design in particular, but to the interested person I suggest the two resources mentioned before: tiny_gpu and smol_gpu.

### High Level - Parallel architecture at many levels
There are many layers of parallelization at play in a GPU design, and the terminology between threads, warps, and cores lack universal meaning between companies/architectures, so I will explain how each of these are defined in my design and how each provides a level of parallel abstraction. 

If we were to focus on the "smallest" processing component, we would have a **lane** (or a thread, as some call it). A lane is primarily composed at 16 registers that are, for the most part, unique to it.

A lane, however, has no "autonomy"; 16 lanes are controlled by a single **warp**, with the warp being a traditional SIMT (Single Instruction, Multiple Threads). A warp takes in a single instruction, determines which lanes should be running it, then performs the operation on each of the active lanes at the same time. Lets say for example an instruction goes to the warp telling it multiply Register 4 by Register 5, and place the result in Register 6. The warp will apply this operation to each of its 16 lanes, regardless of their values in each of the three registers. This is the basis of SIMT processing. 

While each warp acts as a stand-alone processor in most control aspects, there are some resources they have to share, this is due to the fact that four warps coexist in a single core. Most importantly, these warps share a common ALU, meaning all additions, subtractions, multiplcations, etc. need to be scheduled since only one warp has access to it at a time (This is one of the larger differences between my current design and "realer" GPU's who have many different computational resources that are shared such as FPUs, MACs, etc... See section "Future Work" for how this is a goal to implement. In addition to the ALU, all the warps share a memory controller, which stands between the warps and the DMEM bank, scheduling and performing all reads and writes for the warps. The inclusion of the warps allow for maximized usage of the more bottlenecked and/or hardware intensive blocks while allowing each warp to step through their other instructions in parallel, increasing throughput substantially.

Finally, we take another step backwards; All together, the 4 warps, memory controller, ALU, and warp scheduled make up a single **core**. Each core is directed towards it's own data memory and instruction memory, which in this case is designed as a ping-pong buffer, which will be talked about later. The Artix-V board is capable of containing three unique cores, each with their own address spaces to work out of. The host, a MicroBlaze V processor, can directly control the reset signal of each core and monitor their "done" signals. Additionally, the MicroBlaze V works with a DMA Engine to transfer data memory to and from the DMEM space accessible by each core, allowing for high speed operational interface.

### ISA
Each instruction is passed into IMEM and given to every warp in the core. In order to focus my time on overall architecture, I chose a relatively simple 16-bit word, 

TALK ABOUT ADDRESS SPACE HERE

design. All arithmetic instructions by default apply to every lane, unless a divergent instruction is passed applying a mask. 



## Divergence
The GPU itself, is based on a 32-bit word, 32-bit address space ISA that closely resembles RV32I.
Some of the instructions that don't apply to a GPU design have been cut out (fence, csrrw, etc).
Also, currently, there is also no support for unsigned arithmetic instructions.

In order to differentiate between the warp and thread registers or instructions, the first ones will be called **scalar** and the second ones will be called **vector**.

### Vector Registers
Each of the threads within a warp has 32 of 32-bit registers.
As mentioned above, those are called vector registers and will be denoted with an `x` prefix (`x0`-`x31`).

Just like RV32I, `x0` is a read-only register with value 0.
However, for the purposes of GPU programming, registers `x1` - `x3` are also read-only and have a special purpose.
Namely, they contain the thread id, block id and block size, in that order.

The rest of the registers (`x4` - `x31`) are general purpose.

|**Register**|**Function**   |
|------------|---------------|
|`x0`        |zero           |
|`x1`        |thread id      |
|`x2`        |block id       |
|`x3`        |block size     |
|`x4`-`x31`  |general purpose|

### Scalar registers
Similarly to their vector counter part, there are 32 scalar registers that hold 32-bit words.
In order to differentiate between them, the scalar registers are prefixed with `s` (`s0`-`s31`).
The zero-th register is also tied to 0.

Register `s1` is called the execution mask and has a special purpose but is not read-only.
As mentioned in the intro, each of the bits in that register denotes whether the corresponding thread should execute the current instruction.

This is also the reason why the GPU can be configured to have at most 32 threads per warp (size of the register).


|**Register**|**Function**   |
|------------|---------------|
|`s0`        |zero           |
|`s1`        |execution mask |
|`s2`-`x31`  |general purpose|

### Instructions
The instructions are split into three types:
- vector instructions
- scalar instructions
- vector-scalar instructions

Vector instructions are executed by each thread on the vector registers, scalar instructions by each warp on the scalar registers and the vector-scalar instructions are a mix (more on that later).

Which instruction is being executed is determined by three values:
- opcode,
- funct3,
- funct7

All of the vector instructions have their scalar equivalent but not vice versa.
Specifically, the jump and branch instructions are scalar-only, because only the warps have a program counter (`jal`, `jalr`, `beq`, `bne`, `blt`, `bge`).

The most significant bit of the opcode is always equal to 0 for vector instruction and to 1 for other types.
That means, that changing the instruction type from vector to scalar is equivalent to this operation `(opcode) & (1 << 6)`.

#### Instruction list
Below is the instruction list.
The `S` bit in opcode denotes whether the instruction is vector or scalar with (1 - scalar, 0 - vector).
| mnemonic | opcode  | funct3 | funct7    |
|----------|---------|--------|-----------|
| **U-type**    |        |          |     |
| lui      | S110111 |   —    |     —     |
| auipc    | S010111 |   —    |     —     |
| **I-type arithmetic**  |          |     |
| addi     | S010011 | 000    |     —     |
| slti     | S010011 | 010    |     —     |
| xori     | S010011 | 100    |     —     |
| ori      | S010011 | 110    |     —     |
| andi     | S010011 | 111    |     —     |
| slli     | S010011 | 001    | 0000000X  |
| srli     | S010011 | 101    | 0000000X  |
| srai     | S010011 | 101    | 0100000X  |
| **R-type**    |        |          |     |
| add      | S110011 | 000    | 00000000  |
| sub      | S110011 | 000    | 01000000  |
| sll      | S110011 | 001    | 00000000  |
| slt      | S110011 | 010    | 00000000  |
| xor      | S110011 | 100    | 00000000  |
| srl      | S110011 | 101    | 00000000  |
| sra      | S110011 | 101    | 01000000  |
| or       | S110011 | 110    | 00000000  |
| and      | S110011 | 111    | 00000000  |
| **Load**      |        |          |     |
| lb       | S000011 | 000    |     —     |
| lh       | S000011 | 001    |     —     |
| lw       | S000011 | 010    |     —     |
| **Store**     |        |          |     |
| sb       | S100011 | 000    |     —     |
| sh       | S100011 | 001    |     —     |
| sw       | S100011 | 010    |     —     |
| **J-type**    |        |          |     |
| jal      | 1110111 |  —     |     —     |
| **I-type jumps** |     |          |     |
| jalr     | 1110011 | 000    |     —     |
| **B-type**    |        |          |     |
| beq      | 1110011 | 000    |     —     |
| bne      | 1110011 | 001    |     —     |
| blt      | 1110011 | 100    |     —     |
| bge      | 1110011 | 101    |     —     |
| **HALT**      |        |          |     |
| halt     | 1111111 |   —    |     —     |
| **SX type**   |        |          |     |
| sx.slt   | 1111110 |   —    |     —     |
| sx.slti  | 1111101 |   —    |     —     |

## Assembly
Currently, the supported assembly is quite simple.
It takes a single input file and line by line compiles it into machine code.

There are two directives supported:
- `.blocks <num_blocks>` - denotes the number of blocks to dispatch to the GPU,
- `.warps <num_blocks>` - denotes the number of warps to execute per each block

Together they form an API similar to that of CUDA:
```cuda
kernel<<<numBlocks, threadsPerBlock>>>(args...)`
```
The key difference being that CUDA allows you to set the number of threads per block while this GPU accepts the number of warps per block as a kernel parameter. 
A compiler developer can still implement the CUDA API using execution masking.

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

## Microarchitecture
todo

## Project structure
The project is split into several subdirectories:
- `external` - contains external dependencies (e.g. doctest)
- `src` - contains the system-verilog implementation of the GPU
- `sim` - contains the verilator based simulation environment and the assembler
- `test` - contains test files for the GPU, the assembler and the simulator

## Simulation
The prerequistes for running the simulation are:
- [verilator](https://www.veripool.org/wiki/verilator)
- [cmake](https://cmake.org/)
- A C++ compiler that supports C++23 (e.g. g++-14)

Verilator is a tool that can simulate or compile system-verilog code.
In this project, verilator translates the system-verilog code into C++ which then gets included as a library in the simulator.
Once the prerequistes are installed, you can build and run the simulator executable or the tests.
There are currently two ways to do this:

### Justfile
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

### Running the simulator
The produced exectuable is located at `build/sim/simulator` (or you can just use the justfile).
You can run it in the following way:
```bash
./build/sim/simulator <input_file.as> <data_file.bin>
```
The simulator will first assemble the input file and load the binary data file into the GPU data memory.
The program will fail if the assembly code contained in the input file is ill-formed.

In case it manages to assemble the code, it will then run the simulation and print the first 100 words of the memory to the console.
This is a temporary solution and will be replaced by a more sophisticated output mechanism in the future.

## Acknowledgments
Special thanks go to Adam Majmudar, the creator of [tiny-gpu](https://github.com/adam-maj/tiny-gpu).
As previously mentioned, this project is heavily inspired by it and built on top of it.

The architecture itself is a modified variant of [RISC-V](https://github.com/riscv) RV32I.

Much of the knowledge I've gathered in order to create this project comes from the General-Purpose Graphics Processor Architecture book(2018) by Tor M. Aamodt, Wilson Wai Lun Fung and Timothy G. Rogers,
which I highly recommend for anyone interested in the topic.

## Roadmap
There is still a lot of work to be done around the GPU itself, the simulator and the tooling around it.

- [ ] Add more tests and verify everything works as expected
- [ ] Benchmark (add memory latency benchmarks, etc)
- [ ] Parallelize the GPU pipeline
- [ ] Simulate on GEM5 with Ramulator
- [ ] Run it on an FPGA board

Another step would be to implement a CUDA-like compiler as writing the assembly gets very tedious, especially with manually masking out the threads for branching.
