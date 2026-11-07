# HANDOFF: cnn-mac-asic-hardening

Current state as of 2026-11-07 (branch `fix/formal-power-timing-2026-11`, PR into `main`).

## Objective
ASIC study of the CNN MAC extracted from `Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator` (read-only, never
modified): baseline vs sparsity-aware operand-isolated MAC, bit-exact, SKY130 RTL-to-GDSII, honest PPA comparison.

## State: complete (all phases done)
| Area | Status |
|---|---|
| RTL (`rtl/`) | done; unchanged by the audit (no functional issue found) |
| RTL + gate-level simulation (`tb/tb_mac.sv`) | PASS, 1,308,660 cycles each, 0 mismatches |
| Formal | unbounded equivalence PROVEN on the concrete RTL (ABC PDR) and independently with an abstracted multiplier (Yosys k-induction); both catch an injected mutant in every CI run (`scripts/formal.sh`) |
| ASIC flow | both designs RTL-to-GDSII, DRC/LVS/antenna clean |
| Timing | baseline meets 100 MHz at all 9 corners; `mac_opiso` fails nom_ss/max_ss by up to 0.168 ns |
| Power | activity-based OpenSTA, corrected 10 ns VCD: −13.0 % total, −26.0 % combinational at 49.6 % zeros |
| Docs | README.md (design, verification, soundness argument, limitations), RESULTS.md (all numbers + run IDs) |

## Key files
- `scripts/sim.sh`: RTL simulation. `scripts/formal.sh pdr|induct`: unbounded formal + mutant checks
  (`equiv_induct.ys` + `mul_abstract.v` for k-induction). `scripts/equiv_bmc.ys`: bounded check (depth 4, does not finish).
- `scripts/power.sh`, `scripts/power.tcl`, `scripts/vcd_check.py`: gate-level regression and VCD sanity check
  (fails on a VCD/SDC period mismatch), then OpenSTA power.
- `asic/*/config.json`: LibreLane 2.4.13 configs (10 ns, `RUN_POST_GRT_RESIZER_TIMING`, `SYNTH_MUL_BOOTH`).
- `.github/workflows/ci.yml`: jobs `sim`, `formal`, `asic` on push; `formal-concrete-experiment` manual only
  (`gh workflow run ci.yml -f formal_experiments=true`).
- `results/`: raw outputs of CI run 42355384118 (metrics, STA summaries, power reports, logs, GDS gz);
  formal logs from run 42358706554.

## Tools
CI (ubuntu-24.04): Icarus 12, Yosys 0.33 + ABC (apt), LibreLane 2.4.13 Docker image (OpenROAD/OpenSTA 2.6.0, Magic,
KLayout, Netgen), sky130A via ciel. Local Windows machine: git, gh, Python, `pip install yowasp-yosys` (Yosys 0.70).
There is no local simulator or Docker, so simulation and the flow run in CI.

## Known limitations / possible next steps
1. Close `mac_opiso` slow-corner timing (multiplier stage, −0.168 ns): try `SYNTH_STRATEGY` DELAY variants for both designs.
2. Formal RTL-to-gate-level-netlist equivalence (currently covered by gate-level simulation and LVS only).
3. Power with real MNIST activations and with glitch-aware (SDF-annotated) simulation.

## Resume
Open this folder in Claude Code and say `RESUME`. Check `git status`, `gh pr list`, `gh run list -L 5`.
