#!/usr/bin/env bash
# Run after both LibreLane flows (CI). 1) Gate-level simulation of the two final
# netlists with zero-delay sky130 models: re-checks them against the reference model
# and dumps the 50 % sparsity activity window to build/activity.vcd.
# 2) OpenSTA report_power per design using that VCD and post-route (nom) SPEF.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
PDK=${PDK_ROOT:-$HOME/.ciel}
LIB=$(find -L "$PDK" -name 'sky130_fd_sc_hd__tt_025C_1v80.lib' -path '*libs.ref*' | head -1)
V=$(dirname "$(find -L "$PDK" -name 'sky130_fd_sc_hd.v' -path '*libs.ref/sky130_fd_sc_hd/verilog*' | head -1)")
iverilog -g2012 -DGL -DFUNCTIONAL -o build/tb_gl.vvp "$V/primitives.v" "$V/sky130_fd_sc_hd.v" \
  asic/mac_baseline/runs/ci/final/nl/mac_baseline.nl.v \
  asic/mac_opiso/runs/ci/final/nl/mac_opiso.nl.v tb/tb_mac.sv
vvp -n build/tb_gl.vvp +power_only +vcd > build/sim_gl.log
grep '^TB RESULT' build/sim_gl.log
IMG=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i librelane | head -1)
for d in mac_baseline mac_opiso; do
  s=u_base; [ "$d" = mac_opiso ] && s=u_opt
  docker run --rm -v "$PWD:$PWD" -v "$PDK:$PDK" -w "$PWD" \
    -e LIB="$LIB" -e D="$d" -e RUN="asic/$d/runs/ci" -e SCOPE="tb_mac/$s" "$IMG" \
    sta -no_init -exit scripts/power.tcl > "build/power_$d.rpt" 2>&1
done
grep -H 'Total' build/power_*.rpt
