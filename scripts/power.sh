#!/usr/bin/env bash
# Run after both LibreLane flows (CI). Fails on any error.
# 1) Gate-level simulation of the two final netlists together (zero-delay sky130 models),
#    checked against the reference model; the 50 % sparsity window is dumped to build/activity.vcd.
# 2) VCD sanity check: the clock period seen in each DUT scope must be the 10 ns SDC period.
# 3) OpenSTA report_power per design with that VCD, post-route nominal SPEF, tt_025C_1v80.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
PDK=${PDK_ROOT:-$HOME/.ciel}
LIB=$(find -L "$PDK" -name 'sky130_fd_sc_hd__tt_025C_1v80.lib' -path '*libs.ref*' | head -1)
V=$(dirname "$(find -L "$PDK" -name 'sky130_fd_sc_hd.v' -path '*libs.ref/sky130_fd_sc_hd/verilog*' | head -1)")
echo "liberty: $LIB"
iverilog -g2012 -DGL -DFUNCTIONAL -o build/tb_gl.vvp "$V/primitives.v" "$V/sky130_fd_sc_hd.v" \
  asic/mac_baseline/runs/ci/final/nl/mac_baseline.nl.v \
  asic/mac_opiso/runs/ci/final/nl/mac_opiso.nl.v tb/tb_mac.sv
vvp -n build/tb_gl.vvp +power_only +vcd > build/sim_gl.log
grep -E '^(MISMATCH|DIRECTED FAIL|WINDOW|TB RESULT)' build/sim_gl.log
grep -q '^TB RESULT: PASS' build/sim_gl.log
python3 scripts/vcd_check.py build/activity.vcd 10 tb_mac.u_base tb_mac.u_opt | tee build/vcd_check.log

IMG=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i librelane | head -1)
for d in mac_baseline mac_opiso; do
  s=u_base; [ "$d" = mac_opiso ] && s=u_opt
  docker run --rm -v "$PWD:$PWD" -v "$PDK:$PDK" -w "$PWD" \
    -e LIB="$LIB" -e D="$d" -e RUN="asic/$d/runs/ci" -e SCOPE="tb_mac/$s" "$IMG" \
    sta -no_init -exit scripts/power.tcl > "build/power_$d.rpt" 2>&1
  grep -q '^Total' "build/power_$d.rpt"
done
# A VCD/SDC period mismatch means the activity densities are wrong: treat it as a failure.
if grep -H 'differs from SDC clock period' build/power_*.rpt; then exit 1; fi
grep -H -E '^(Total|Combinational|Sequential|Clock) ' build/power_*.rpt
