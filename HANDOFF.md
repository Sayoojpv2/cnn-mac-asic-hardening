# HANDOFF — cnn-mac-asic-hardening

Last updated: 2026-11-06 (session 1). Stopped early: weekly usage was already 90% used at session start
(resets 2026-11-06 23:00 UTC), which is past the ~20%-remaining stopping rule.

## Objective
ASIC implementation and low-power optimisation of the CNN MAC unit extracted from
`Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator`:
1. Baseline signed MAC. 2. Optimised MAC with sparsity-aware operand isolation (no clock gating).
Arithmetic: 12-bit signed activation x 8-bit signed weight -> 20-bit product, 20-bit accumulator.
Both must be bit-exact equivalent. Then SKY130 RTL-to-GDSII for both, with an honest PPA comparison.
Full brief: the original prompt (keep minimal files; never modify the original repo; never fabricate results).

## Existing repository (read-only, never modify)
- github.com/Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator — branch `main`, MIT licence, ~180 MB (do not clone).
- Files to read (fetched once, NOT yet analysed): README.md, PROJECT_RECOVERY.md, ENERGY_OPTIMIZATION.md,
  MNIST_CNN_FPGA.srcs/sources_1/new/{mul,MAC,PE,acc}.sv, MNIST_CNN_FPGA.srcs/sim_1/new/tb_sadcg_verify.sv, LICENSE.
- Fetch them (git-bash) into a folder outside this repo, e.g. `../orig_ref` (fetch command below).

## Status
| Phase | State |
|---|---|
| 0. Environment + usage check | DONE |
| 1. Read original MAC/mul/acc/PE + docs | NOT STARTED (next) |
| 2. RTL: baseline + optimised | NOT STARTED |
| 3. Testbench + simulation | NOT STARTED |
| 4. Formal equivalence (Yosys) | NOT STARTED |
| 5. ASIC flow (SKY130) | NOT STARTED |
| 6. README / RESULTS / CI | NOT STARTED |
| 7. GitHub repo | NOT CREATED |

Files created: `HANDOFF.md` only. No git repo initialised yet. No tests run.

## Environment (Windows 11 Home, checked 2026-11-06)
- Available: git, gh (authenticated as `Sayoojpv2`), Python 3.14 (`C:\Python314`), pip.
- MISSING: iverilog, verilator, yosys, docker, WSL (not installed), openlane/openroad/sta/magic/klayout/netgen.
- Blocker: no local simulator and no Docker/WSL, so OpenLane cannot run locally. Do NOT spend usage installing WSL/Docker.

## Decided plan (works around the blocker)
1. Local lint/synth + formal equivalence: `pip install yowasp-yosys` (Yosys as WebAssembly, no Docker).
   Equivalence: miter of baseline vs optimised + `sat -verify -tempinduct -prove trigger 0` (sequential).
2. Simulation in GitHub Actions (ubuntu runner, `apt-get install iverilog`): one self-checking TB,
   exhaustive 2^20 multiplier sweep, directed (zero act, signed boundaries -2048/2047, -128/127, overflow wrap),
   reset, continuous + intermittent valid, random vectors, baseline-vs-optimised compare.
3. ASIC flow in GitHub Actions with Docker: OpenLane 2, dockerized, SKY130 (sky130_fd_sc_hd).
   FIRST check current docs: OpenLane 2 continues as **LibreLane** (FOSSi) after Efabless closed — confirm the
   pip package / Docker image / PDK fetcher (ciel vs volare) before writing the workflow.
4. Create the repo PRIVATE first so CI can run, download actual reports with `gh run download`,
   record real metrics in RESULTS.md, make it public only after verification passes.
5. Planned files only: `rtl/mac_baseline.sv`, `rtl/mac_opiso.sv`, `tb/tb_mac.sv`, `scripts/` (sim + equiv),
   `asic/<design>/config.json`, `.github/workflows/ci.yml`, `README.md`, `RESULTS.md`, `HANDOFF.md`, `LICENSE` (MIT, keep original attribution).

## Exact next step
Phase 1: fetch and read the 8 original files, record the exact arithmetic/reset/valid behaviour of MAC.sv/mul.sv/acc.sv here,
then write the two RTL files.

## Resume commands
```bash
cd /c/Users/acer/cnn-mac-asic-hardening
mkdir -p ../orig_ref && R=repos/Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator; S=MNIST_CNN_FPGA.srcs; for f in README.md PROJECT_RECOVERY.md ENERGY_OPTIMIZATION.md LICENSE $S/sources_1/new/mul.sv $S/sources_1/new/MAC.sv $S/sources_1/new/PE.sv $S/sources_1/new/acc.sv $S/sim_1/new/tb_sadcg_verify.sv; do gh api -H "Accept: application/vnd.github.raw" "$R/contents/$f" > "../orig_ref/$(basename $f)"; done
pip install yowasp-yosys
```
In Claude Code: open this folder and say `RESUME`.

## GitHub
`cnn-mac-asic-hardening` — not created, nothing pushed. Original repo untouched.
