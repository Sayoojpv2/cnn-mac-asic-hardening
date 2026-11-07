#!/usr/bin/env bash
# Formal equivalence of mac_baseline and mac_opiso, with a non-vacuity check: every proof
# is re-run on a deliberately broken mac_opiso (accumulates on v2 instead of n2) and must
# then FAIL with a counterexample.
#   bash scripts/formal.sh induct   # Yosys k-induction, multiplier abstracted (equiv_induct.ys)
#   bash scripts/formal.sh pdr      # ABC PDR on the concrete miter (real multiplier), unbounded
# Logs in build/. Override tools with YOSYS=... ABC=...
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
YOSYS=${YOSYS:-yosys}
ABC=${ABC:-yosys-abc}
sed 's/else if (n2) acc_o <= acc_o + prod_q;/else if (v2) acc_o <= acc_o + prod_q;/' \
  rtl/mac_opiso.sv > build/mac_opiso_mutant.sv
grep -q 'else if (v2) acc_o' build/mac_opiso_mutant.sv

induct() {  # $1 = mac_opiso source, $2 = tag
  sed "s#rtl/mac_opiso.sv#$1#" scripts/equiv_induct.ys > "build/equiv_induct_$2.ys"
  "$YOSYS" -q -l "build/equiv_induct_$2.log" -s "build/equiv_induct_$2.ys"
}

pdr() {  # $1 = mac_opiso source, $2 = tag
  # Bit-level AIG of the miter; all flops zero-initialised (= reset state of both designs).
  "$YOSYS" -q -l "build/miter_$2.log" -p "read_verilog -sv rtl/mac_baseline.sv $1; proc; \
    miter -equiv -flatten mac_baseline mac_opiso miter; hierarchy -top miter; flatten; opt_clean; \
    dffunmap; techmap; opt -fast; dffunmap; setundef -zero -init; aigmap; opt_clean; stat; \
    write_aiger -zinit build/miter_$2.aig"
  "$ABC" -c "read_aiger build/miter_$2.aig; print_stats; pdr -T 1500" > "build/abc_pdr_$2.log"
  cat "build/abc_pdr_$2.log"
}

case "${1:-}" in
  induct)
    induct rtl/mac_opiso.sv real
    grep 'Induction step proven: SUCCESS' build/equiv_induct_real.log
    if induct build/mac_opiso_mutant.sv mutant; then echo "mutant was NOT caught"; exit 1; fi
    grep 'model found for base case: FAIL' build/equiv_induct_mutant.log ;;
  pdr)
    pdr rtl/mac_opiso.sv real
    grep -q 'Property proved' build/abc_pdr_real.log
    pdr build/mac_opiso_mutant.sv mutant
    grep -E 'asserted in frame' build/abc_pdr_mutant.log ;;
  *) echo "usage: $0 induct|pdr"; exit 2 ;;
esac
