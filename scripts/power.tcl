# OpenSTA: post-route power of one design with gate-level VCD activity (see power.sh).
read_liberty $::env(LIB)
read_verilog $::env(RUN)/final/nl/$::env(D).nl.v
link_design $::env(D)
if {[catch {read_sdc $::env(RUN)/final/sdc/$::env(D).sdc} err]} {
  puts "read_sdc failed ($err); using 10 ns clock"
  create_clock -name clk -period 10 [get_ports clk]
}
read_spef $::env(RUN)/final/spef/nom/$::env(D).nom.spef
read_vcd -scope $::env(SCOPE) build/activity.vcd
report_power
