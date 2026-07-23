# Project Progress Tracker

Living project update for my independent study.  
This is meant to track the rough timeline, weekly progress, side work that comes up along the way, and any issues/blockers worth flagging.

---

## Quick Status (7/23)
Three core system set up and working. Preliminary data collected for roofline analysis.

### Core goals
- Integrate GPU with MicroBlaze V host
- Interface cohesively with the integrated homogenous system.
- Benchmark GPU performance
- Continue to implement hardware to improve GPU performance
---

## Rough Timeline - From proposal (Many changes have been made)

- **Week 1** — MicroBlaze integration: architecture + interface design
- **Week 2** — MicroBlaze integration: bring-up + kernel dispatch
- **Week 3** — Parameterization + benchmarking infrastructure
- **Week 4** — Metric determination + FSM state tracking
- **Week 5** — Memory coalescing design + initial implementation
- **Week 6** — Memory coalescing integration + verification
- **Week 7** — Pipelined ALU + scoreboard design
- **Week 8** — Pipelined ALU + scoreboard implementation + verification
- **Week 9** — Full benchmark suite
- **Week 10** — Stretch goal or buffer week
- **Week 11** — Timing closure + full system verification
- **Week 12** — Report + cleanup


## Weekly Updates

---

<details>
<summary><strong>Week 1 — MicroBlaze integration: Research and design</strong></summary>

### Planned focus
- Define CPU/GPU interface
- Decide on register interface / dispatch approach
- Sketch overall system block diagram
- Identify control/status signals crossing the boundary
- Start Vivado block design with MicroBlaze V

### Main progress
- Began work on researching how CPU and GPU should interface. Looked into AXI protocols and standard homogenous system benchmarks. Begun learning about block diagram instantiation and created MicroBlaze V and peripherals needed to interface with design.

### Other work done
- Attempted a restructure of Warp.sv design to be a FSM in order to better track hang-ups and time utilization. Determined to a dead-end, as FSM design is unsuited for the work needed to get done. Instead, internal signals are used to control the warp, but are better labeled and can be used to track warps state indirectly. Will need to integrate the pulling of these signals later into a test bench which can further analyze time usage.

### Challenges ran into
- FSM of Warp is impractical, but another way of tracking time was foudn to be feasible. 

</details>

---

<details>
<summary><strong>Week 2 — MicroBlaze integration: Reconfigure GPU for integration</strong></summary>

### Planned focus
- Wire GPU into block design
- Implement control register interface
- Let MicroBlaze write instruction memory and trigger execution
- Verify a trivial kernel can round-trip:
  - load
  - start
  - poll done
  - read back result

### Main progress
- Memory interfaces previously placed internal to GPU design were wired out to it's interface so it can pull from the BRAM being written to by CPU. Block Diagram more fleshed out with control bits interface created and UART interface made to MicroBlaze V. 

### Other work done
- Two major reworks done to GPU code, admittedly pulling focus away from weeks original task:

- First, memory controller was known to be bottleneck for most testbenches. In process of pulling the memory interfaces out through GPU_top, I also reworked the memory controller to allow for wider data reads and writes when new instructions are called "Coalesced read/write". This is a half-measure towards a more comprehensive memory coalescing hardware block which is a large design task. Simple test bench has been made and it passed, fuller more intensive one planned for future.

- Second, to get an idea of timing a report was run. Some relatively large problems were seen and I went down a bit of a rabbit hole fixing them, introducing a new stage to the pipeline, and reworking a lot of logic in warp.sv, including necessitating some software restrictions with regards to concurrent instructions not being able to be ran (more details on this will be added to document to make clear). Timing is now almost closed for 100MHz target, satisfactory enough to move forward with. 

### Challenges ran into
- Closing timing introduced a lot of new bugs that needed to be chased down, new pipeline stage required, etc. This ended up eating a lot more of my time I wanted to dedicate to MicroBlaze V bring-up and integration. 


### Next up
- Full focus of next week will be on bring up MicroBlaze and trying to get a basic kernel to run, a "hello world" of sorts, and hopefully get a basic program to run by prompt of the MicroBlaze.

- Talking to Nick Beser, I want to try to keep test benches more up to date and published, allowing more frequent logic checks as I implement changes. I have been using a few testbenches which get changed periodically as the modules change purposes, goal is to standardize this.

- Additionally, increased visibility was determined to be helpful to make sure all goals are being met, and timelines aren't shifting. 

</details>

---

<details>
<summary><strong>Week 3 — Improve Visibility + Further Integration</strong></summary>

### Planned focus
Original goals:
- Parameterize top-level design
- Add cycle counter accessible to MicroBlaze
- Port matrix multiply kernel
- Add vector dot product
- Establish pre-coalescing baseline numbers

New goals:
- Complete CPU block diagram side
- Create interfacing module to contain both the GPU and MicroBlaze.
- Try to run basic program on GPU
- As time permits, clean up testbenches and set up everything here on GitHub, to be maintained in future

### Main progress
- Everything moved to GitHub, status tracker cleaned up
- Built overall top module to contain both GPU and CPU
- Built Imem BRAM blocks in top module, all being interfaced by one AXI
- Received board and get license working
- Installed and started working on Vitis

### Other work done
- [ ] 

### Challenges ran into
- License issues with new board
- Vitis not working

### Notes
-  Need to decide whether to have unique instructions for each Warp, same instructions for each warp. (current set up allows for relatively easy switching to other).
-  If we do same instructions, can build a caching system. (unnecessary complication?)

### Next up
- Run a testbenching kernel
- Finish developing testbenches for each module 

</details>

---

<details>
<summary><strong>Week 4 — Finalize Interface</strong></summary>

### Planned focus
- Convert warp control to explicit FSM
- Keep behavior unchanged
- Re-run existing tests after refactor

- New goals:
- Get MicroBlaze interface tested and working.
- Write simple program to GPU, one that is tested and true.
- Finish cleaning up testbenches and GitHub.
- Try to have baseline working version of SoC by end of week 5.
- Consider timing measurements

### Main progress
- Major improvements to testbenches of RTL
- Memory walk confirmed from CPU programming
- Working on simple write, set, go, and read finish program

### Challenges ran into
- Vitis is not playing as friendly as hoped
- Memory interface is not clean, neither fully driven by me or Xilinx IPs, causes issues.
- Difficulty building code between two different memory systems: One BRAM fully created from Xilinx IP, the other created by RTL being synthesized into BRAM
- BRAM addressing worked out differently than expected
- RTL driven BRAM being incorrectly synthesized. Needed to add useless code to trick Vivado into synthesizing correctly.

</details>

---

<details>
<summary><strong>Week 5 — Finalize and Test + Timing System Development</strong></summary>

### Planned focus
- Integrate ILA and use to debug CPU/GPU interface issues
- Fully verify more advanced program being driven by CPU
- Flesh out timing system (AXI Timer available)
- Determine memory method of storing "common" programs

### Main progress
- ILA set up and used for debugging interface
- CPU/GPU basic test completed and verified!!
- BRAM interface difficulties fixed (address shifting for DMEM, timing issue for IMEM)
- Simple lane ID write program created
- Ran matrix multiplication program
- Set up clock cycle counter accessible via AXI
  

### Other work done
- Set up timer accessible via AXi... Not a huge fan

### Challenges ran into
- Memory difficulties

### Next up
- Set up programs in BRAM accessible by CPU
- Setup read into CPU of clock cycles recorded by GPU
- Run fuller programs, begin recording how long they take.
- Test with and without memory coalescing instruction
- Set up scoreboarding and test with and without
- Some BRAM is actually being synthesized as LUTRAM

</details>

---

<details>
<summary><strong>Week 6 — Develop Significant Benchmarks</strong></summary>

### Planned focus
- Fully write more programs to run on GPU
- Create baseline timing measurement
- Test with and without memory coalescing instructions
- Determine next target for optimization (Scoreboarding most likely)
- Look into Nick's proposed benchmark test

### Main progress
- 3 programs currently able to be run directly on GPU
- Timing measurement fully developed: One clock counter for individual program performance and one for overall
- Each clock counter now able to be read by CPU
- Kernel developed, intialized on start up and then called to be moved over.
- Researched into IP usage for multiiplication/division

### Challenges ran into
- Development of kernel involved more memory with more issues

### Notes
- Need to collect timing reports and put them in document (although this will be able to be completed later through revision control)

### Next up
- Collect data, run with and without memory coalescing. (involves rewriting of programs)
- Collect data on bottlenecks (warp usage and time spent)
- develop basic scoreboard to allow removal of inserted NOPs
- Collect data on that improvement
- Look into Nick proposed benchmark test
- Work on IPs to increase speec

</details>

---

<details>
<summary><strong>Week 7

### Planned focus
- Pipeline multiplier into two stages
- Design scoreboard with per-warp busy bits
- Stall on issue when source/destination is busy
- Clear busy bits on writeback
- Account for ALU and memory latency together

### Main progress
- Finished memory coalesce, and rewrote programs for it
- Collected timing report of operations before and after memory coalesce
- Developed multiple address spaces
- Timing report of repeated operations before and after setting up ping-pong buffer
- Determined need to build DMA engine to support maximized operational throughput
### Other work done
- [ ] 

### Challenges ran into
- [ ] 


### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 8

### Planned focus
- Collected roofline data, started working on diagrams
- Set up third core
- Created RTL to measure utilization % of memory controller and ALU

### Main progress
- Collected roofline data, started working on diagrams
- Set up third core
- Created RTL to measure utilization % of memory controller and ALU

<details>
<summary><strong>Week 9 — Full benchmark suite</strong></summary>

### Planned focus
- Run all kernels across at least 3 configurations
- Record:
  - total cycle count
  - memory stall cycles
  - coalescing ratio
  - ALU stall cycles
  - Fmax
- Identify the most useful comparison/story

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Benchmark results
| Config | Kernel | Cycle Count | Mem Stall | Coalescing Ratio | ALU Stall | Fmax | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 10 — Stretch goal or buffer week</strong></summary>

### Planned focus
- If on schedule:
  - occupancy-aware scheduler, or
  - dual-issue
- If behind:
  - use this as a cleanup / stabilization week

### Chosen direction this week
- [ ] Stretch goal
- [ ] Buffer / cleanup

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Notes
- [ ] 

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 11 — Timing closure + full system verification</strong></summary>

### Planned focus
- Full implementation run at target frequency
- Verify complete system end-to-end
- Fix timing violations
- Finalize utilization + Fmax
- No new RTL after this week if possible

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Final build numbers
| Metric | Value | Notes |
|---|---|---|
| Fmax | TBD | |
| LUTs | TBD | |
| FFs | TBD | |
| BRAM | TBD | |
| DSP | TBD | |

### Notes
- [ ] 

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 12 — Report + cleanup</strong></summary>

### Planned focus
- Finalize technical report
- Clean up RTL
- Add comments/documentation
- Finalize block diagrams
- Submit everything
