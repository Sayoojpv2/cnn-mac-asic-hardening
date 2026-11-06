#!/usr/bin/env bash
# RTL simulation of the self-checking testbench (Icarus Verilog >= 11). Full log: build/sim.log
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -o build/tb_mac.vvp rtl/mac_baseline.sv rtl/mac_opiso.sv tb/tb_mac.sv
vvp -n build/tb_mac.vvp > build/sim.log
grep -E '^(MISMATCH|DIRECTED|EXHAUSTIVE|RANDOM|ACTIVITY|TB RESULT)' build/sim.log
grep -q '^TB RESULT: PASS' build/sim.log
