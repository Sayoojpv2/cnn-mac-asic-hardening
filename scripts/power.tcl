# OpenSTA: post-route power of one design with gate-level VCD activity (see power.sh).
# Expected warnings: tap/decap/fill cells have no liberty model and become black boxes
# (physical-only cells, no logic pins; their leakage is not counted).
read_liberty $::env(LIB)
read_verilog $::env(RUN)/final/nl/$::env(D).nl.v
link_design $::env(D)
read_sdc $::env(RUN)/final/sdc/$::env(D).sdc
read_spef $::env(RUN)/final/spef/nom/$::env(D).nom.spef
# read_vcd prints "Annotated N pin activities"; compare with the total below.
read_vcd -scope $::env(SCOPE) build/activity.vcd
puts "Instance pins in design: [llength [get_pins */*]]"
report_power -digits 4
