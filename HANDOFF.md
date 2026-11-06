# HANDOFF — cnn-mac-asic-hardening

Last updated: 2026-11-06 (session 1). Weekly usage ~94% used at last check; work stopped/paused near the limit.

## Objective
ASIC implementation of the CNN MAC from `Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator`:
baseline signed MAC vs sparsity-aware operand-isolated MAC (no clock gating), 12b act x 8b wgt -> 20b product,
20b wrapping accumulator, bit-exact equivalent, SKY130 RTL-to-GDSII with honest PPA comparison.

## Existing repository (read-only, never modified)
Read: mul.sv, MAC.sv, PE.sv, acc.sv, ENERGY_OPTIMIZATION.md (MIT, Copyright (c) 2024 Hoooo).
Finding: original "SADCG" only forces the product register to 0; operand flops still load, so the multiplier
array still switches on an ASIC. New design holds the operand registers instead (operand isolation).

## Files (all committed on `main`)
- `rtl/mac_baseline.sv`, `rtl/mac_opiso.sv` — 3-stage pipeline (operands -> product -> acc), sync active-low reset,
  `clear_i` travels with its sample (acc restarts from it).
- `tb/tb_mac.sv` — one self-checking TB, both DUTs vs independent reference model; RTL toggle probes; `+vcd`, `+power_only`, `-DGL`.
- `scripts/sim.sh` (Icarus), `scripts/equiv.ys` (Yosys formal), `scripts/power.sh` + `power.tcl` (GL sim + OpenSTA VCD power).
- `asic/<design>/config.json` — LibreLane 2.4.13 (OpenLane 2 successor), sky130A/sky130_fd_sc_hd, 10 ns clock, FP_CORE_UTIL 40.
- `.github/workflows/ci.yml` — jobs: sim, formal, asic (both flows + power).

## Results so far (actual)
- RTL sim (CI, ubuntu-24.04 Icarus): **PASS** — 1,048,576 exhaustive operand pairs, directed boundary/wrap/clear,
  200k random cycles (continuous + intermittent valid, mid-stream reset); 1,308,642 cycles checked, 0 mismatches,
  0 baseline-vs-opt mismatches. Product range seen -262016..262144 (needs exactly 20 bits).
- RTL operand-register toggles, opt vs base: 0% zeros -1%, 50% zeros -42%, 80% zeros -69%; product reg -1/-32/-43%.
- Formal: k-induction (`sat -tempinduct`) did not converge in 15+ min (induction step = SAT multiplier equivalence).
  Switched to bounded proof `sat -seq 10` from reset — result: see below / RESULTS.md.
- ASIC (CI run 42268125887): both designs completed RTL-to-GDSII; DRC 0 (route/Magic/KLayout), LVS 0, antenna 0;
  GL sim of final netlists PASS; area +2.7 %; VCD power −6.2 % total (−21.8 % combinational); typical-corner
  timing met, slow corner fails by 0.30/0.44 ns. All numbers in RESULTS.md, raw files + GDS (gz) in results/.
- Run 1 (42267304096) failed: `librelane --dockerized` needs a TTY; fixed with `script -q -e -c` in ci.yml.

## Tools
Local (Windows): git, gh (Sayoojpv2), Python 3.14, yowasp-yosys 0.70 (user site:
`C:\Users\acer\AppData\Roaming\Python\Python314\Scripts\yowasp-yosys.exe`). No local Icarus/Docker/WSL —
simulation and the ASIC flow run in GitHub Actions only.

## GitHub
`https://github.com/Sayoojpv2/cnn-mac-asic-hardening`: created private, made PUBLIC after verification.

## Status: phases 1-7 DONE (RTL, TB, CI sim, ASIC flow, power, docs, repo published)
Open items, in priority order:
1. Formal: check the `formal` job of run 42268125887 (`gh run view 42268125887 --json jobs`) and the local
   `build/equiv.log`. If `sat -seq 10` finished, put the result in RESULTS.md + README Limitations. If it timed out,
   lower to `-seq 6`, or abstract the multiplier for an unbounded proof.
2. Optional timing closure at the slow corner: e.g. CLOCK_PERIOD 11, or move the zero detector off the input path
   (register `live` with the sample). Re-run CI, update RESULTS.md.

## Resume
Open this folder in Claude Code and say `RESUME`. Local proof: `yowasp-yosys -s scripts/equiv.ys` (from repo root).
