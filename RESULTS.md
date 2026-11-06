# Results

All numbers are actual tool output from GitHub Actions run `42268125887`
(LibreLane 2.4.13, sky130A, sky130_fd_sc_hd, 10 ns clock, FP_CORE_UTIL 40). Raw files are in [`results/`](results/).

## Verification

| Check | Result |
|---|---|
| RTL simulation, Icarus 12 ([sim_rtl.txt](results/sim_rtl.txt)) | **PASS**: 1,308,642 cycles checked, 0 mismatches vs reference, 0 baseline-vs-optimised |
| Exhaustive multiplier | all 2^12 x 2^8 = 1,048,576 signed operand pairs; product range −262016..262144 (needs exactly 20 bits) |
| Directed | ±boundaries (−2048/2047 x −128/127), zero activation, accumulator wrap mod 2^20, clear with/without valid, idle cycles, reset with live inputs |
| Random | 100k cycles continuous valid + 100k intermittent valid (garbage on idle cycles) with a mid-stream reset |
| Gate-level simulation of both final (post-route) netlists ([sim_gl.txt](results/sim_gl.txt)) | **PASS**: 60,009 cycles, 0 mismatches |
| Formal equivalence (Yosys) | k-induction did not converge in 15+ min; bounded check (`sat -seq 10`) was still running when these results were recorded. See Limitations in the README |

## Physical design (both designs completed RTL-to-GDSII)

| Metric | Baseline | Operand-isolated | Δ |
|---|---|---|---|
| Std-cell instances | 1243 | 1270 | +27 |
| Std-cell area (µm²) | 7966.4 | 8179.1 | +2.7 % |
| Die area (µm²) | 26053.5 | 26603.9 | +2.1 % |
| Routed wirelength (µm) | 17850 | 18925 | +6.0 % |
| Setup WNS, typical tt 25 °C 1.80 V (ns) | +4.83 | +4.57 | |
| Setup WNS, slow ss 100 °C 1.60 V (ns, worst RC) | **−0.30** | **−0.44** | |
| Hold WNS, all corners (ns) | +0.13 | +0.13 | |
| Route DRC / Magic DRC / KLayout DRC | 0 / 0 / 0 | 0 / 0 / 0 | |
| LVS errors (Netgen) | 0 | 0 | |
| Antenna violating nets | 0 | 0 | |
| GDSII | [mac_baseline.gds.gz](results/mac_baseline.gds.gz) | [mac_opiso.gds.gz](results/mac_opiso.gds.gz) | |

Timing: 100 MHz is met at the typical corner but **not** at the slow corner (about 97 MHz / 96 MHz there).

## Switching activity (RTL, testbench toggle probes)

Continuous valid, post-ReLU activations, random weights, 20,000 cycles per sparsity level.

| Zero activations | Operand-register toggles (base → opt) | Product-register toggles | Accumulator toggles |
|---|---|---|---|
| 0 % | 190610 → 190489 (−0.1 %) | 197001 → 196915 | equal |
| 50 % | 162415 → 95520 (**−41 %**) | 144073 → 98437 (−32 %) | equal |
| 80 % | 119625 → 38030 (**−68 %**) | 69056 → 39617 (−43 %) | equal |

(The TB prints the reductions with integer rounding: 1 %, 42 %, 69 %.)

## Power (post-route, activity-annotated)

Method: gate-level simulation of each final netlist with zero-delay sky130 cell models, 50 % sparsity workload
(20,000 cycles at 100 MHz), VCD read into OpenSTA (`read_vcd`) with post-route nominal SPEF, tt_025C_1v80 liberty
([power.sh](scripts/power.sh), [power.tcl](scripts/power.tcl), [reports](results/)).

| Group (mW) | Baseline | Operand-isolated | Δ |
|---|---|---|---|
| Combinational | 0.294 | 0.230 | **−21.8 %** |
| Sequential | 0.298 | 0.300 | +0.7 % |
| Clock tree | 0.323 | 0.328 | +1.5 % |
| Leakage | 6.0 nW | 6.4 nW | |
| **Total** | **0.915** | **0.858** | **−6.2 %** |

Isolation removes about a fifth of the datapath logic power. Clock and flop power (about 2/3 of the total) are unchanged
because every flop is still clocked every cycle: that share can only be reduced by clock gating (ICG cells),
which this design deliberately avoids. Zero-delay simulation contains no glitches, so multiplier glitch power, which
isolation also suppresses, is not counted. LibreLane's own `power__total` (0.99 vs 1.15 mW) uses default vectorless
activity that ignores sparsity, so it is not used for this comparison.
