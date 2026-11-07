# CNN MAC: ASIC implementation and sparsity-aware operand isolation (SKY130)

A focused ASIC study of the multiply-accumulate (MAC) unit of my FPGA CNN accelerator. The MAC arithmetic is
re-implemented as synthesizable SystemVerilog in two bit-exact versions: a baseline and a sparsity-aware
operand-isolated one. Both are verified in simulation and formally, then taken through the open-source SkyWater
SKY130 RTL-to-GDSII flow. All measured results are in **[RESULTS.md](RESULTS.md)**.

## Relationship to the Zynq CNN project

- **Previous project:** [MNIST-CNN-Zynq-Energy-Efficient-Accelerator](https://github.com/Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator),
  a complete CNN accelerator integrated on a Zynq-7000 FPGA. It is unchanged by this work.
- **This project:** extracts only the MAC arithmetic of its `MAC.sv` (MIT licence, Copyright (c) 2024 Hoooo) and
  implements it as an ASIC block, comparing a baseline against an operand-isolated version. It is **not** a CNN ASIC:
  no convolution array, buffers, controller or memories were implemented.
- The FPGA design's "SADCG" optimisation is **not** the same technique. SADCG forced the product register to 0 for a
  zero activation, but the multiplier's inputs (operand flops in `MAC.sv`, line buffers in `mul.sv`) still changed
  every sample, so the multiplier logic kept switching. On Zynq it was intended to map to DSP48 clock enables. Operand isolation here stops the multiplier's inputs from changing at all.

## Design

Arithmetic: 12-bit signed activation x 8-bit signed weight → 20-bit exact product (−2048 x −128 = 262144 needs
20 bits), 20-bit two's-complement accumulator that wraps on overflow.

```
act_i,wgt_i ──► [S1 operand regs] ──► 12x8 multiplier ──► [S2 product reg] ──► + ──► [S3 acc_o]
valid_i,clear_i ─► v1,c1 ───────────────────────────────► v2,c2 ──────────────────► valid_o
```

| Port | Meaning |
|---|---|
| `clk`, `rst_n` | clock; synchronous active-low reset (all state to 0) |
| `valid_i`, `act_i`, `wgt_i` | input sample |
| `clear_i` | travels with its sample: the accumulator restarts from that sample (from 0 if `valid_i` = 0) |
| `acc_o`, `valid_o` | accumulator; `valid_o` pulses for one cycle, 3 cycles after a valid sample, when `acc_o` includes it |

- [`rtl/mac_baseline.sv`](rtl/mac_baseline.sv): operand registers load every valid sample, including zero activations.
- [`rtl/mac_opiso.sv`](rtl/mac_opiso.sv): **operand isolation.** A zero activation means a zero product, so the
  sample is not loaded. The operand registers hold, so the multiplier inputs, product register and adder inputs stay
  constant. A 1-bit flag (`n1`→`n2`) marks live products, and for zero samples the accumulator holds instead of adding
  0. This uses register enables, not clock gating: every flop is clocked every cycle, so there is no gated clock to
  glitch and no CTS impact. The extra logic is a 12-bit zero detector and two flops.

## Verification

- **Simulation:** [`tb/tb_mac.sv`](tb/tb_mac.sv) is one self-checking testbench. Both designs get identical stimulus
  and are compared every cycle against an independent reference model. It covers all 1,048,576 multiplier operand
  pairs, signed boundaries, zero activations, accumulator wrap, clear, latency, reset with live inputs, continuous and
  intermittent valid, and random vectors. The same testbench also runs on both post-route gate-level netlists.
- **Formal, unbounded, real multiplier** ([`scripts/formal.sh`](scripts/formal.sh) `pdr`): Yosys builds a bit-level
  miter of the two RTL designs (the outputs are compared every cycle, all flops start at the reset value 0), and ABC
  PDR proves the mismatch output can never be 1. It does this by finding an inductive invariant (255 clauses over
  124 of the 126 flops) and checking it. This is a full sequential-equivalence proof of the concrete RTL for every
  input sequence of any length.
- **Formal, unbounded, abstracted multiplier** ([`scripts/equiv_induct.ys`](scripts/equiv_induct.ys)): an independent
  second proof by Yosys k-induction (length 3). It replaces the multiplier in both designs with the abstraction in
  [`scripts/mul_abstract.v`](scripts/mul_abstract.v): f(a, w) = 0 if a = 0, otherwise the concatenation {a, w}.

  **Why this is sound.** Only `prod_q` and `acc_o` depend on the multiplier function; the operand registers, the
  valid/clear/live flags and `valid_o` do not. Suppose the real designs differ for some input sequence, and take the
  first cycle where `acc_o` differs. In that cycle the baseline adds `v2 ? a*w : 0` and the optimised design adds
  `n2 ? a'*w' : 0` (or loads it, on clear), and these two terms are different. That can only happen if a product with
  a non-zero activation is involved or the operand pairs differ. f distinguishes every such case, because f(0, w) = 0
  = 0*w and f is injective and non-zero whenever a ≠ 0. So the abstracted designs also differ, in that cycle or
  earlier. Proving the abstracted miter therefore proves the real designs equivalent. The script also checks
  structurally that both designs contain exactly one identical signed 12x8→20 `$mul`.
- **Non-vacuity:** every CI run repeats both proofs on a broken `mac_opiso` (accumulating on `v2` instead of `n2`).
  Each proof must then fail with a counterexample, and does: PDR at frame 4.
- **Why bounded checking failed:** Yosys `sat` unrolls the miter and has no structural hashing, so it has to show
  two separate multiplier copies agree, with inputs that are equal only under path conditions. That is the classic
  multiplier-equivalence problem. Depth 4, the first depth at which a product reaches the outputs, did not finish in
  20 minutes, and ABC `bmc3` reached only 5 frames in 20 minutes. PDR succeeds because it reasons one transition at
  a time against a learned invariant instead of unrolling.

## Physical design

LibreLane 2.4.13 (the maintained continuation of OpenLane 2), classic flow:
- **Flow steps:** Yosys synthesis, OpenROAD floorplan, placement, CTS and routing, OpenSTA multi-corner STA, Magic
  and KLayout DRC, Netgen LVS, GDSII.
- **Settings:** sky130A, sky130_fd_sc_hd, 10 ns clock, `FP_CORE_UTIL` 40.
- **Flow knobs (identical for both designs):** `RUN_POST_GRT_RESIZER_TIMING` and `SYNTH_MUL_BOOTH`
  ([configs](asic/)).

Summary of the final run (details, timing experiments and raw reports in [RESULTS.md](RESULTS.md)):

| | Baseline | Operand-isolated |
|---|---|---|
| Sequential equivalence (formal, unbounded) | proven | proven |
| Std-cell area | 6764.0 µm² | 6750.2 µm² |
| 100 MHz, typical corner | met (+4.91 ns) | met (+4.75 ns) |
| 100 MHz, all 9 corners | **met** (worst +0.150 ns) | **not met** (worst −0.168 ns, 2 slow corners) |
| DRC / LVS / antenna | 0 / 0 / 0 | 0 / 0 / 0 |
| Power, 50 % zero activations (activity-based) | 1.2805 mW | 1.1137 mW (−13.0 %) |

## Reproduce

```bash
bash scripts/sim.sh                          # RTL simulation (Icarus Verilog >= 11)
bash scripts/formal.sh pdr                   # unbounded formal equivalence, concrete RTL (Yosys + yosys-abc)
bash scripts/formal.sh induct                # independent proof with abstracted multiplier (Yosys)
pip install librelane==2.4.13                # needs Docker
librelane --dockerized --run-tag ci asic/mac_baseline/config.json
librelane --dockerized --run-tag ci asic/mac_opiso/config.json
bash scripts/power.sh                        # gate-level regression, VCD check, OpenSTA power
```

[CI](.github/workflows/ci.yml) runs all of this on every RTL, script or flow change. The slow bounded formal
experiments run only when triggered manually.

## Limitations

- Nothing has been fabricated or taped out. All results come from the open-source flow.
- **Timing:** the operand-isolated design misses 100 MHz at 2 of 9 slow corners, by up to 0.168 ns. The violating path
  is the multiplier stage, not the isolation logic, and closing it would need further flow work or a deeper pipeline,
  which would change latency.
- **Formal scope:** the proofs compare the two RTL designs (as Yosys models them at bit level) and assume power-up in
  the reset state. The gate-level netlists are checked against the RTL by gate-level simulation, and the layout
  against the netlist by LVS. There is no formal RTL-to-netlist equivalence check.
- **Power:** zero-delay activity (no glitches), typical corner, one synthetic workload (about 50 % zeros, random
  data), not real MNIST activations. Absolute power depends on the workload; the comparison uses identical stimulus.
- This is one MAC, not a CNN array. Clock and flop power are untouched by design, because there is no clock gating.

## Licence

MIT. MAC arithmetic derived from the MIT-licensed upstream repository above (Copyright (c) 2024 Hoooo); see [LICENSE](LICENSE).
