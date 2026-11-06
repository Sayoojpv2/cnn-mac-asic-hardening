// Self-checking testbench. mac_baseline and mac_opiso get identical stimulus and
// are both checked every cycle against an independent reference model
// (32-bit integer product, explicit pipeline). Plusargs:
//   +vcd         dump DUT activity during the 50 % sparsity window to build/activity.vcd
//   +power_only  run only reset + the activity windows (for gate-level power runs)
// Define GL when simulating gate-level netlists (disables internal toggle probes).
`timescale 1ns/1ps
module tb_mac;
  logic clk = 1'b0, rst_n = 1'b0, valid = 1'b0, clear = 1'b0;
  logic signed [11:0] act = '0;
  logic signed [7:0]  wgt = '0;
  logic signed [19:0] acc_b, acc_x;
  logic               vo_b, vo_x;

  always #5 clk = ~clk;

  mac_baseline u_base (.clk(clk), .rst_n(rst_n), .valid_i(valid), .clear_i(clear),
                       .act_i(act), .wgt_i(wgt), .acc_o(acc_b), .valid_o(vo_b));
  mac_opiso    u_opt  (.clk(clk), .rst_n(rst_n), .valid_i(valid), .clear_i(clear),
                       .act_i(act), .wgt_i(wgt), .acc_o(acc_x), .valid_o(vo_x));

  // ---------------- reference model ----------------
  integer             p, pmin = 0, pmax = 0;
  logic signed [19:0] m_p1, m_p2, m_acc;
  logic               m_v1, m_v2, m_c1, m_c2, m_vo;
  always @(posedge clk) begin
    if (!rst_n) begin
      {m_v1, m_v2, m_c1, m_c2, m_vo} <= '0;
      m_p1 <= '0; m_p2 <= '0; m_acc <= '0;
    end else begin
      p = act * wgt;                         // exact, 32-bit signed
      if (valid && p < pmin) pmin = p;
      if (valid && p > pmax) pmax = p;
      m_p1 <= valid ? p[19:0] : 20'sd0;
      m_v1 <= valid;  m_c1 <= clear;
      m_p2 <= m_p1;   m_v2 <= m_v1;  m_c2 <= m_c1;
      if (m_c2)      m_acc <= m_v2 ? m_p2 : 20'sd0;
      else if (m_v2) m_acc <= m_acc + m_p2;
      m_vo <= m_v2;
    end
  end

  // ---------------- checker ----------------
  logic chk_en = 1'b0;
  integer errors = 0, eq_err = 0, dir_err = 0, checks = 0, samples = 0;
  always @(negedge clk) if (chk_en) begin
    checks = checks + 1;
    if (acc_b !== acc_x || vo_b !== vo_x) eq_err = eq_err + 1;
    if (acc_b !== m_acc || vo_b !== m_vo || acc_x !== m_acc || vo_x !== m_vo) begin
      errors = errors + 1;
      if (errors <= 10)
        $display("MISMATCH t=%0t base=%0d/%b opt=%0d/%b ref=%0d/%b",
                 $time, acc_b, vo_b, acc_x, vo_x, m_acc, m_vo);
    end
  end

  // ---------------- stimulus helpers ----------------
  integer seed = 32'h5EED_1234;
  integer r;
  task automatic step(input logic v, input logic c, input logic [11:0] a, input logic [7:0] w);
    @(negedge clk);
    valid = v; clear = c; act = a; wgt = w;
    if (v) samples = samples + 1;
  endtask
  task automatic flush;            // drain the 3-cycle pipeline
    repeat (3) step(1'b0, 1'b0, 12'd0, 8'd0);
  endtask
  task automatic expect_acc(input integer exp, input string what);
    flush();
    if (acc_b !== exp[19:0] || acc_x !== exp[19:0]) begin
      dir_err = dir_err + 1;
      $display("DIRECTED FAIL %s: exp=%0d base=%0d opt=%0d", what, $signed(exp[19:0]), acc_b, acc_x);
    end
  endtask
  task automatic rand_step(input integer valid_pct, input integer zero_pct,
                           input logic relu, input integer clear_mod);
    logic v, c; logic [11:0] a; logic [7:0] w;
    r = $random(seed); v = ((r & 32'h7fff_ffff) % 100) < valid_pct;
    r = $random(seed); a = r[11:0];
    if (relu) a[11] = 1'b0;                                  // post-ReLU: non-negative
    r = $random(seed); if (((r & 32'h7fff_ffff) % 100) < zero_pct) a = '0;
    r = $random(seed); w = r[7:0];
    r = $random(seed); c = (clear_mod > 0) ? (((r & 32'h7fff_ffff) % clear_mod) == 0) : 1'b0;
    step(v, c, a, w);
  endtask

`ifndef GL
  // ---------------- switching-activity probes (RTL) ----------------
  logic   meas = 1'b0;
  longint t_ops_b, t_ops_x, t_prod_b, t_prod_x, t_acc_b, t_acc_x;
  logic [19:0] s_ops_b, s_ops_x, s_prod_b, s_prod_x, s_acc_b, s_acc_x;
  function automatic integer pop(input logic [19:0] x);
    pop = 0;
    for (int i = 0; i < 20; i++) pop = pop + x[i];
  endfunction
  always @(negedge clk) begin
    if (meas) begin
      t_ops_b  += pop({u_base.act_q, u_base.wgt_q} ^ s_ops_b);
      t_ops_x  += pop({u_opt.act_q,  u_opt.wgt_q}  ^ s_ops_x);
      t_prod_b += pop(u_base.prod_q ^ s_prod_b);
      t_prod_x += pop(u_opt.prod_q  ^ s_prod_x);
      t_acc_b  += pop(u_base.acc_o  ^ s_acc_b);
      t_acc_x  += pop(u_opt.acc_o   ^ s_acc_x);
    end
    s_ops_b  = {u_base.act_q, u_base.wgt_q};  s_ops_x  = {u_opt.act_q, u_opt.wgt_q};
    s_prod_b = u_base.prod_q;  s_prod_x = u_opt.prod_q;
    s_acc_b  = u_base.acc_o;   s_acc_x  = u_opt.acc_o;
  end
`endif

  // Activity workload: continuous valid, post-ReLU activations with the given
  // zero fraction, random weights, clear every 25 samples (one 5x5 conv window).
  task automatic activity(input integer zero_pct, input integer n);
`ifndef GL
    {t_ops_b, t_ops_x, t_prod_b, t_prod_x, t_acc_b, t_acc_x} = '0;
    meas = 1'b1;
`endif
    for (int i = 0; i < n; i++) begin
      rand_step(100, zero_pct, 1'b1, 0);
      clear = (i % 25) == 0;
    end
    flush();
`ifndef GL
    meas = 1'b0;
    $display("ACTIVITY zero=%0d%% cycles=%0d | operand-reg toggles base=%0d opt=%0d (%0d%%) | product-reg toggles base=%0d opt=%0d (%0d%%) | acc toggles base=%0d opt=%0d",
             zero_pct, n, t_ops_b, t_ops_x, 100 - (100 * t_ops_x) / t_ops_b,
             t_prod_b, t_prod_x, 100 - (100 * t_prod_x) / t_prod_b, t_acc_b, t_acc_x);
    $display("         (percentages are reductions of opt vs base)");
`endif
  endtask

  // ---------------- test sequence ----------------
  initial begin
    // 1. Reset with live, toggling inputs: outputs must be 0 and stay 0.
    rst_n = 1'b0;
    repeat (4) rand_step(100, 0, 1'b0, 4);
    chk_en = 1'b1;
    if (acc_b !== 0 || acc_x !== 0 || vo_b !== 0 || vo_x !== 0) begin
      dir_err = dir_err + 1; $display("DIRECTED FAIL reset");
    end
    rst_n = 1'b1;

    if (!$test$plusargs("power_only")) begin
      // 2. Boundary values and extreme products.
      step(1, 1, -12'sd2048, -8'sd128); expect_acc( 262144, "-2048*-128");
      step(1, 1,  12'sd2047, -8'sd128); expect_acc(-262016, "2047*-128");
      step(1, 1, -12'sd2048,  8'sd127); expect_acc(-260096, "-2048*127");
      step(1, 1,  12'sd2047,  8'sd127); expect_acc( 259969, "2047*127");
      step(1, 1,  12'sd0,     8'sd127); expect_acc(      0, "0*127");
      step(1, 1,  -12'sd1,   -8'sd1);   expect_acc(      1, "-1*-1");
      // Accumulator: zero activation adds nothing; overflow wraps modulo 2^20.
      step(1, 1, 12'sd100, 8'sd3); step(1, 0, 12'sd0, -8'sd77); step(1, 0, -12'sd5, 8'sd4);
      expect_acc(280, "100*3 + 0*-77 + -5*4");
      step(1, 1, 12'sd2047, 8'sd127);
      repeat (4) step(1, 0, 12'sd2047, 8'sd127);
      expect_acc(5 * 259969 - 1048576, "5x 2047*127 wraps");
      // Clear without a valid sample restarts from 0; idle cycles change nothing.
      step(1, 1, 12'sd7, 8'sd9); step(0, 1, 12'sd55, 8'sd55); expect_acc(0, "clear w/o valid");
      step(1, 1, 12'sd7, 8'sd9); step(0, 0, 12'sd55, 8'sd55); step(1, 0, 12'sd1, 8'sd1);
      expect_acc(64, "idle cycle ignored");
      $display("DIRECTED boundary/accumulator/clear checks: %0d failures", dir_err);

      // 3. Exhaustive multiplier: all 2^12 x 2^8 operand pairs, continuous valid,
      //    clear on every sample so acc_o is each product, checked every cycle.
      for (integer a = -2048; a < 2048; a++)
        for (integer w = -128; w < 128; w++)
          step(1'b1, 1'b1, a[11:0], w[7:0]);
      flush();
      $display("EXHAUSTIVE 1048576 operand pairs done, product range %0d..%0d, mismatches so far %0d",
               pmin, pmax, errors);

      // 4. Continuous valid, signed random data, 50 % zero activations, random clears.
      repeat (100000) rand_step(100, 50, 1'b0, 32);
      // 5. Intermittent valid (garbage inputs on idle cycles), with a reset mid-stream.
      repeat (50000) rand_step(50, 50, 1'b0, 32);
      rst_n = 1'b0; repeat (2) rand_step(100, 0, 1'b0, 0); rst_n = 1'b1;
      repeat (50000) rand_step(50, 50, 1'b0, 32);
      flush();
      $display("RANDOM 200000 cycles (continuous + intermittent valid, mid-stream reset), mismatches so far %0d", errors);
    end

    // 6. Switching activity at three sparsity levels.
    activity(0, 20000);
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/activity.vcd");
      $dumpvars(0, u_base);
      $dumpvars(0, u_opt);
    end
    activity(50, 20000);
    if ($test$plusargs("vcd")) $dumpoff;
    activity(80, 20000);

    $display("TB RESULT: %s  cycles_checked=%0d valid_samples=%0d ref_mismatches=%0d base_vs_opt_mismatches=%0d directed_failures=%0d",
             (errors == 0 && eq_err == 0 && dir_err == 0 && checks > 0) ? "PASS" : "FAIL",
             checks, samples, errors, eq_err, dir_err);
    $finish;
  end
endmodule
