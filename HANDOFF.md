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
- ASIC: first CI run 42267304096 in progress at time of writing.

## Tools
Local (Windows): git, gh (Sayoojpv2), Python 3.14, yowasp-yosys 0.70 (user site:
`C:\Users\acer\AppData\Roaming\Python\Python314\Scripts\yowasp-yosys.exe`). No local Icarus/Docker/WSL —
simulation and the ASIC flow run in GitHub Actions only.

## GitHub
`github.com/Sayoojpv2/cnn-mac-asic-hardening` — created PRIVATE. Make public only after results are recorded:
`gh repo edit Sayoojpv2/cnn-mac-asic-hardening --visibility public --accept-visibility-change-consequences`

## Next steps
1. Check CI: `gh run list -L 3`; download: `gh run download <id> -n asic-results -D build/ci`.
2. Record metrics from `asic/*/runs/ci/final/metrics.json` + `build/power_*.rpt` into RESULTS.md; write README.md.
3. Commit the bounded-equivalence change (scripts/equiv.ys), push, confirm formal job passes.
4. Make repo public.

## Resume
Open this folder in Claude Code and say `RESUME`. Local proof: `yowasp-yosys -s scripts/equiv.ys` (from repo root).
