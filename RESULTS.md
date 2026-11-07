# Results

All numbers are tool output from GitHub Actions run
[`42355384118`](https://github.com/Sayoojpv2/cnn-mac-asic-hardening/actions/runs/42355384118) on commit
`79e49a3` (LibreLane 2.4.13, sky130A, sky130_fd_sc_hd, 10 ns clock at every corner). Raw files are in
[`results/`](results/). A second, independent run on the same commit
([`42355390097`](https://github.com/Sayoojpv2/cnn-mac-asic-hardening/actions/runs/42355390097)) produced identical
metrics and power reports. Its GDS files differ only in BGNLIB/BGNSTR timestamp records, so the geometry is identical.
Run `42358706554` (commit `af97ede`, formal changes only) reproduced the same metrics and power again.

## Verification

| Check | Result |
|---|---|
| RTL simulation, Icarus 12 ([sim_rtl.txt](results/sim_rtl.txt)) | **PASS**: 1,308,660 cycles checked; 0 mismatches vs the reference model, 0 baseline vs optimised, 0 directed failures |
| Exhaustive multiplier | all 2^12 x 2^8 = 1,048,576 signed operand pairs; product range −262016..262144 (needs exactly 20 bits) |
| Directed | ±boundaries, zero activation, zero activations with changing weights, accumulator wrap mod 2^20, clear with/without valid, clear on a zero activation, idle cycles, 3-cycle latency and one-cycle `valid_o`, reset with live inputs |
| Random | 100k cycles continuous valid + 100k intermittent valid (garbage inputs on idle cycles), mid-stream reset |
| Gate-level regression of both final post-route netlists ([sim_gl.txt](results/sim_gl.txt)) | **PASS**: same full testbench, 1,308,660 cycles, 0 mismatches |
| Formal, **unbounded, concrete RTL (real multiplier)**, ABC `pdr` ([formal_pdr.txt](results/formal_pdr.txt)) | **PROVEN**: "Property proved" in 265.6 s; ABC found and checked a 255-clause inductive invariant over 124 of the 126 flops of the miter (24 inputs, 1 output, 2703 AND nodes) |
| Formal, unbounded, multiplier abstracted, Yosys `sat -tempinduct` ([formal_induct.txt](results/formal_induct.txt)) | **PROVEN**: induction succeeds at length 3 |
| Non-vacuity (both proofs, every CI run) | a mutant `mac_opiso` that accumulates on `v2` instead of `n2` is caught: PDR gives a counterexample at frame 4, k-induction a base-case counterexample |
| Bounded engines on the concrete miter ([formal_bounded.txt](results/formal_bounded.txt)) | Yosys `sat -seq 4` did not finish (20 min CI, 15 min local); depth 3 passes but is vacuous. ABC `bmc3` reached 5 frames in 20 min |

Formal results are from CI run [`42358706554`](https://github.com/Sayoojpv2/cnn-mac-asic-hardening/actions/runs/42358706554)
(Yosys 0.33, yosys-abc). Both proofs compare the two RTL designs and assume power-up in the reset (all-zero) state.
A local mutation check of the abstracted proof also caught three further injected bugs: setting `n1` from `valid_i`
and ignoring `n2` on clear each gave a counterexample from reset at 5 cycles, and an unsigned weight was rejected by
the multiplier-identity check.

## Physical design (final flow: post-GRT timing repair + Booth multiplier, both designs)

| Metric | Baseline | Operand-isolated | Δ |
|---|---|---|---|
| Std-cell area (µm²) | 6763.99 | 6750.22 | −0.2 % |
| Std-cell instances incl. tap cells | 1049 | 1025 | |
| Logic cells (excluding tap/fill) | 789 | 770 | |
| Flip-flops | 65 | 67 | +2 (`n1`, `n2`) |
| Die area (µm²) | 23235.1 | 22730.0 | |
| Routed wirelength (µm) | 14613 | 14643 | |
| Setup WNS, typical nom_tt_025C_1v80 (ns) | +4.910 | +4.745 | |
| Setup WNS, slow nom_ss_100C_1v60 (ns) | +0.236 | **−0.049** | |
| Setup WNS, slow max_ss_100C_1v60 (ns, worst) | +0.150 | **−0.168** | |
| Setup TNS (ns) / violating endpoints | 0 / 0 | −0.172 / 3 | |
| Hold WNS, all corners (ns) | +0.111 | +0.118 | |
| Route / Magic / KLayout DRC errors | 0 / 0 / 0 | 0 / 0 / 0 | |
| LVS errors (Netgen) | 0 | 0 | |
| Antenna violating nets / pins | 0 / 0 | 0 / 0 | |
| GDSII (gzip) | [mac_baseline.gds.gz](results/mac_baseline.gds.gz) | [mac_opiso.gds.gz](results/mac_opiso.gds.gz) | |

**Is 100 MHz met at all corners?** Baseline: yes, all 9 STA corners. Operand-isolated: **no**. It fails 2 of 9
corners (nom_ss −0.049 ns, max_ss −0.168 ns) and passes min_ss (+0.038 ns). Per-corner tables:
[baseline](results/sta_summary_mac_baseline.rpt), [optimised](results/sta_summary_mac_opiso.rpt).

The critical path in both designs is `wgt_q` → multiplier → `prod_q`. The zero detector is not on it: the worst
input-to-register path of `mac_opiso` (`act_i[3]` → operand register) has +4.68 ns slack at max_ss. The two designs'
critical paths are logically the same, so the ~0.3 ns difference comes from placement and buffering, not from the
isolation logic. Moving the zero detection off the input path would therefore not help, so the RTL was left unchanged.

### Timing experiments (same RTL, same 10 ns constraint, same settings for both designs)

| Flow | Run | Baseline WNS (ns) | Opt WNS (ns) | Area base / opt (µm²) |
|---|---|---|---|---|
| A: LibreLane defaults | 42268125887 | −0.302 | −0.442 | 7966.4 / 8179.1 |
| B: + `RUN_POST_GRT_RESIZER_TIMING` | 42353296821 | −0.127 | −0.395 | 7987.7 / 8205.4 |
| C: B + `SYNTH_MUL_BOOTH` (final) | 42355384118 | **+0.150** | **−0.168** | 6764.0 / 6750.2 |

The worst-corner WNS is always max_ss_100C_1v60. The clock period and IO constraints were never changed.

## Switching activity (RTL toggle probes, [sim_rtl.txt](results/sim_rtl.txt))

Continuous valid, post-ReLU (non-negative) activations, random weights, 20,000 cycles per window, clear every 25 samples.
The zero fraction is measured among the window's valid samples.

| Measured zeros | Operand-register toggles (base → opt) | Product-register toggles | Accumulator toggles |
|---|---|---|---|
| 0.06 % | 190610 → 190489 (−0.1 %) | 197001 → 196915 (−0.04 %) | equal |
| 49.41 % | 163293 → 95879 (**−41.3 %**) | 145492 → 99671 (−31.5 %) | equal |
| 80.25 % | 118895 → 37583 (**−68.4 %**) | 67573 → 38702 (−42.7 %) | equal |

## Power (post-route, activity-annotated)

**Method** ([power.sh](scripts/power.sh), [power.tcl](scripts/power.tcl)):
1. Both final netlists are simulated together in one testbench with zero-delay sky130 cell models, so they receive
   cycle-identical stimulus.
2. One VCD covers only the 50 % sparsity window: 20,000 workload cycles plus 3 drain cycles. The measured zero
   fraction is 49.57 % ([sim_gl.txt](results/sim_gl.txt)).
3. OpenSTA 2.6.0 runs `read_vcd -scope tb_mac/<dut>` with the post-route nominal SPEF, the tt_025C_1v80 liberty and
   the flow's SDC, then `report_power`.

**Checks** ([vcd_check.txt](results/vcd_check.txt)):
- **VCD span:** 200,030 ns, which is exactly 20,003 cycles.
- **Clock:** 40,006 clock transitions in each DUT scope, giving **10.0000 ns**, the SDC period. OpenSTA reports no
  period warning.
- **Annotation:** 2696 of 2781 instance pins (baseline) and 2665 of 2754 (optimised) received VCD activity. The 85
  and 89 unannotated pins equal each netlist's count of resizer timing-repair buffers, which suggests those are
  buffer pins, but OpenSTA 2.6 cannot list them. OpenSTA computes their activity itself instead of reading it from
  the VCD.
- **Expected warnings:** tap, decap and fill cells have no liberty model and become black boxes. They have no logic
  pins, and their leakage is not counted.

| Group (mW) | Baseline | Operand-isolated | Δ |
|---|---|---|---|
| Combinational | 0.5719 | 0.4229 | **−26.0 %** |
| Sequential | 0.3628 | 0.3447 | −5.0 % |
| Clock tree | 0.3459 | 0.3461 | +0.1 % |
| Leakage | 4.85 nW | 4.75 nW | |
| **Total** | **1.2805** | **1.1137** | **−13.0 %** |

Clock power is unchanged because every flop is still clocked every cycle. Only clock gating could reduce it, and this
design deliberately does not use clock gating. Sequential power falls a little because held operand flops do not
switch their outputs. Zero-delay simulation has no glitches, so multiplier glitch power, which isolation also
suppresses, is not counted. The workload is synthetic, not MNIST activations.

**Correction of the earlier figure (6.2 %, commit c920397).** The earlier VCD started dumping before the 50 %
window, called `$dumpoff` after it, then simulated another 20,000 cycles before `$finish`. The VCD therefore spanned
about 40,000 cycles but held clock edges for only 20,000. OpenSTA reported a 20.002 ns period against the 10 ns SDC
and computed every activity density about 2x too low, so the earlier absolute powers (0.915 / 0.858 mW) were wrong.
Because the dilution was the same for every net in both designs, it should not have changed the ratio much. The
change from 6.2 % to 13.0 % mainly reflects the different final netlists (Booth multiplier, post-GRT repair). This
attribution is reasoned, not re-measured on the old netlists.

LibreLane's own `power__total` is vectorless (default activity, ignores sparsity): 1.369 mW baseline,
1.344 mW optimised. It is not used for the comparison.
