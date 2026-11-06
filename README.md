# CNN MAC: ASIC implementation and sparsity-aware operand isolation (SKY130)

The multiply-accumulate unit of my FPGA CNN accelerator
([MNIST-CNN-Zynq-Energy-Efficient-Accelerator](https://github.com/Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator)),
re-implemented as ASIC-ready SystemVerilog in two bit-exact versions and taken through the open-source
SkyWater SKY130 RTL-to-GDSII flow. Measured results are in **[RESULTS.md](RESULTS.md)**.

## Design

Arithmetic (same as the original `MAC.sv`): 12-bit signed activation x 8-bit signed weight → 20-bit exact product,
20-bit two's-complement accumulator that wraps on overflow.

```
act_i,wgt_i ──► [S1 operand regs] ──► 12x8 multiplier ──► [S2 product reg] ──► + ──► [S3 acc_o]
valid_i,clear_i ─► v1,c1 ───────────────────────────────► v2,c2 ──────────────────► valid_o
```

| Port | Meaning |
|---|---|
| `clk`, `rst_n` | clock; synchronous active-low reset (all state to 0) |
| `valid_i`, `act_i`, `wgt_i` | input sample |
| `clear_i` | travels with its sample: the accumulator restarts from that sample (from 0 if `valid_i` = 0) |
| `acc_o`, `valid_o` | accumulator; `valid_o` pulses 3 cycles after a sample, when `acc_o` includes it |

- [`rtl/mac_baseline.sv`](rtl/mac_baseline.sv): operand registers load every valid sample, including zero activations.
- [`rtl/mac_opiso.sv`](rtl/mac_opiso.sv): **operand isolation.** A zero activation means a zero product, so the
  sample is not loaded. The operand registers hold, so the multiplier inputs, the product register and the
  adder inputs do not switch. A 1-bit flag (`n1`→`n2`) marks live products, and the accumulator holds
  instead of adding 0. This is done with register enables, not clock gating, so there is no gated clock to glitch
  and no CTS impact. The cost is one 12-bit zero detector and two flops.

Why not keep the original scheme? The FPGA "SADCG" forced the product register to 0, but its operand
flops kept loading every sample. On an ASIC the multiplier array would still switch on every zero activation.

## Verification

- [`tb/tb_mac.sv`](tb/tb_mac.sv): one self-checking testbench. Both designs get identical stimulus and are compared
  every cycle against an independent reference model. It covers an exhaustive multiplier sweep (all 1,048,576 pairs),
  signed boundaries, zero activations, accumulator wrap, clear, reset with live inputs, continuous and intermittent
  valid, and random vectors. It also measures register toggles at 0/50/80 % sparsity.
- The same testbench re-runs on both post-route gate-level netlists (`-DGL`).
- [`scripts/equiv.ys`](scripts/equiv.ys): Yosys miter + SAT equivalence check of the two RTL designs.

## Reproduce

```bash
bash scripts/sim.sh                       # RTL simulation (Icarus Verilog >= 11)
yosys -s scripts/equiv.ys                 # formal equivalence (bounded)
pip install librelane==2.4.13             # needs Docker
librelane --dockerized --run-tag ci asic/mac_baseline/config.json
librelane --dockerized --run-tag ci asic/mac_opiso/config.json
bash scripts/power.sh                     # gate-level sim + OpenSTA VCD power
```

[CI](.github/workflows/ci.yml) runs all of this on every RTL/flow change.

## Limitations

- Silicon has not been fabricated or taped out. All results are from the open-source flow.
- **Timing:** 100 MHz is met at the typical corner (+4.6 ns slack) but fails at the slow ss/100 °C/1.60 V corner by
  0.30 ns (baseline) and 0.44 ns (optimised). The constraint or the pipeline would need adjusting for sign-off.
- **Formal:** unbounded k-induction did not converge (the induction step becomes a SAT equivalence of two multiplier
  copies). Only a bounded proof from reset is used, and it had not finished when the results were recorded.
  Equivalence is established by exhaustive and random simulation, at RTL and gate level.
- **Power:** estimate from zero-delay gate-level activity (no glitches), typical corner, one synthetic workload
  (50 % zeros, random data), not real MNIST activations.
- This is one MAC, not the full CNN array. The clock and flop power share is untouched by design (no clock gating).
- The optimised design costs +2.7 % area and has slightly worse slow-corner slack (zero detector on the input path).

## Licence

MIT. MAC arithmetic derived from the MIT-licensed original repository (Copyright (c) 2024 Hoooo); see [LICENSE](LICENSE).
