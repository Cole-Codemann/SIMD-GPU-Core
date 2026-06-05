# Project Progress Tracker

Living project update for my independent study.  
This is meant to track the rough timeline, weekly progress, side work that comes up along the way, and any issues/blockers worth flagging.

---

## Quick Status (6/5)
Focusing work on MicroBlaze V bringup and trying to get basic test in. Formalizing test benches and getting everything more visible

### Core goals
- Integrate GPU with MicroBlaze V host
- Interface cohesively with the integrated homogenous system.
- Benchmark GPU performance
- Continue to implement hardware to improve GPU performance
---

## Rough Timeline - From proposal

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
<summary><strong>Week 1 — MicroBlaze integration: architecture + interface design</strong></summary>

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
<summary><strong>Week 2 — MicroBlaze integration: bring-up + kernel dispatch</strong></summary>

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
<summary><strong>Week 3 — Parameterization + benchmarking infrastructure</strong></summary>

### Planned focus
Original goals:
- Parameterize top-level design
  - `NUM_WARPS`
  - `LANES_PER_WARP`
  - `REG_COUNT`
  - `ADDR_WIDTH`
- Add synthesis-time config header
- Add cycle counter accessible to MicroBlaze
- Port matrix multiply kernel
- Add vector dot product
- Establish pre-coalescing baseline numbers

New goals:
- Get MicroBlaze running on very basic kernel, test control register interfacing. 
- Create interfacing module to contain both the GPU and MicroBlaze.
- Try to run basic program on GPU
- As time permits, clean up testbenches and set up everything here on GitHub, to be maintained in future

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Baseline results
| Config | Kernel | Cycle Count | Memory Stall Cycles | Warp Utilization | Notes |
|---|---|---:|---:|---:|---|
| TBD | TBD | TBD | TBD | TBD | TBD |

### Notes
- [ ] 

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 4 — Warp FSM refactor</strong></summary>

### Planned focus
- Convert warp control to explicit FSM
- Keep behavior unchanged
- Re-run existing tests after refactor

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
<summary><strong>Week 5 — Memory coalescing: design + initial implementation</strong></summary>

### Planned focus
- Design coalescing logic in memory controller
- Define grouping granularity
- Handle partial coalescing correctly
- Make sure masks are handled correctly
- Add instrumentation counters
- Verify coalescing logic in isolation first

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Coalescing notes
- Granularity:
- Mask behavior:
- Requests before/after counter plan:
- Open questions:

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 6 — Memory coalescing: integration + verification</strong></summary>

### Planned focus
- Integrate coalescing into memory path
- Verify:
  - fully coalesced requests
  - fully uncoalesced requests
  - partial coalescing
  - masked requests
  - multiple warp requests
- Compare matrix multiply stall profile against baseline

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Results
| Kernel | Before | After | Delta | Notes |
|---|---:|---:|---:|---|
| Matrix Multiply | TBD | TBD | TBD | TBD |

### Notes
- [ ] 

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 7 — Pipelined ALU + scoreboard: design</strong></summary>

### Planned focus
- Pipeline multiplier into two stages
- Design scoreboard with per-warp busy bits
- Stall on issue when source/destination is busy
- Clear busy bits on writeback
- Account for ALU and memory latency together

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Design notes
- Pipeline stages:
- Busy-bit policy:
- Hazard handling:
- Open questions:

### Next up
- [ ] 

</details>

---

<details>
<summary><strong>Week 8 — Pipelined ALU + scoreboard: implementation + verification</strong></summary>

### Planned focus
- Implement pipelined ALU and scoreboard
- Run directed hazard tests
- Measure Fmax before/after pipelining
- Check whether schedule still supports stretch goal

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Timing results
| Build | Fmax | Notes |
|---|---:|---|
| Before pipelining | TBD | |
| After pipelining | TBD | |

### Verification checklist
- [ ] RAW hazard across pipelined multiply
- [ ] WAW hazard
- [ ] Hazard during memory wait
- [ ] Correct behavior under masking

### Next up
- [ ] 

</details>

---

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

### Report checklist
- [ ] Abstract
- [ ] Introduction
- [ ] Architecture overview
- [ ] MicroBlaze integration
- [ ] Coalescing design + motivation
- [ ] Scoreboard + pipelining
- [ ] Benchmark methodology
- [ ] Results
- [ ] Future work

### Main progress
- [ ] 

### Other work done
- [ ] 

### Challenges ran into
- [ ] 

### Notes
- [ ] 

### Wrap-up
- [ ] 

</details>

---

## Change Log

- **[date]** Initial tracker created
- **[date]** 
- **[date]** 

---

## Parking Lot / Side Tasks

Use this section for small tasks that come up outside the main weekly plan.

- [ ] 
- [ ] 
- [ ] 

---

## End Notes

A few things I want this tracker to capture clearly:
- what I planned to get done
- what actually got done
- side work that still mattered
- issues/blockers that changed the pace or direction
