// Baseline signed MAC for the CNN accelerator datapath.
// 12-bit signed activation x 8-bit signed weight -> 20-bit product (exact),
// 20-bit two's-complement accumulator (wraps, as in the original MAC.sv).
// Arithmetic taken from MAC.sv of Sayoojpv2/MNIST-CNN-Zynq-Energy-Efficient-Accelerator (MIT).
//
// Pipeline: S1 operand registers -> S2 product register -> S3 accumulator.
// clear_i travels with its sample: the accumulator restarts from that sample
// (or from 0 if valid_i was low). valid_o pulses when acc_o has absorbed a sample.
module mac_baseline (
    input  logic               clk,
    input  logic               rst_n,     // synchronous, active low
    input  logic               valid_i,
    input  logic               clear_i,
    input  logic signed [11:0] act_i,
    input  logic signed [7:0]  wgt_i,
    output logic signed [19:0] acc_o,
    output logic               valid_o
);
  logic signed [11:0] act_q;
  logic signed [7:0]  wgt_q;
  logic signed [19:0] prod_q;
  logic               v1, v2, c1, c2;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      act_q   <= '0;
      wgt_q   <= '0;
      prod_q  <= '0;
      {v1, v2, c1, c2} <= '0;
      acc_o   <= '0;
      valid_o <= 1'b0;
    end else begin
      // S1: operands load on every valid sample, including zero activations.
      if (valid_i) begin
        act_q <= act_i;
        wgt_q <= wgt_i;
      end
      v1 <= valid_i;
      c1 <= clear_i;
      // S2: multiplier evaluates every cycle.
      prod_q <= act_q * wgt_q;
      v2 <= v1;
      c2 <= c1;
      // S3: accumulate.
      if (c2)      acc_o <= v2 ? prod_q : '0;
      else if (v2) acc_o <= acc_o + prod_q;
      valid_o <= v2;
    end
  end
endmodule
