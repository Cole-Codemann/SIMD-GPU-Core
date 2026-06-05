# Project Progress Tracker

Living project update for my independent study.  
This is meant to track the rough timeline, weekly progress, side work that comes up along the way, and any issues/blockers worth flagging.

---

## Quick Status

**Current status:** Not started / In progress / On track / Behind / Catching up  
**Current focus:** TBD  
**Biggest blocker right now:** TBD  
**Next milestone:** TBD  

---

## Project Goals

### Core goals
- [ ] Integrate GPU with MicroBlaze V host
- [ ] Implement memory coalescing
- [ ] Parameterize the design for comparisons
- [ ] Collect benchmark + timing results
- [ ] Finish conference-style technical report

### Secondary goal
- [ ] Add pipelined ALU + scoreboard

### Stretch goal
- [ ] Occupancy-aware scheduler or dual-issue

---

## Rough Timeline

- [ ] **Week 1** — MicroBlaze integration: architecture + interface design
- [ ] **Week 2** — MicroBlaze integration: bring-up + kernel dispatch
- [ ] **Week 3** — Parameterization + benchmarking infrastructure
- [ ] **Week 4** — Warp FSM refactor
- [ ] **Week 5** — Memory coalescing design + initial implementation
- [ ] **Week 6** — Memory coalescing integration + verification
- [ ] **Week 7** — Pipelined ALU + scoreboard design
- [ ] **Week 8** — Pipelined ALU + scoreboard implementation + verification
- [ ] **Week 9** — Full benchmark suite
- [ ] **Week 10** — Stretch goal or buffer week
- [ ] **Week 11** — Timing closure + full system verification
- [ ] **Week 12** — Report + cleanup

---

## Metrics I Want to Track

| Metric | Status | Notes |
|---|---|---|
| Cycle count | TBD | |
| Memory stall cycles | TBD | |
| Warp utilization | TBD | |
| Coalescing ratio | TBD | |
| ALU stall cycles | TBD | |
| Fmax | TBD | |
| FPGA utilization | TBD | |

---

## Known Risks / Watch Items

- MicroBlaze integration may take longer than planned
- Coalescing correctness could get tricky, especially with masks or multiple warp requests
- Timing closure may force design tradeoffs late
- Stretch goals are optional and should not get in the way of the core deliverables

---

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
<summary><strong>Week 3 — Parameterization + benchmarking infrastructure</strong></summary>

### Planned focus
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
