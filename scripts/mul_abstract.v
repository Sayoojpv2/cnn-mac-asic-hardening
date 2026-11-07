// Formal-only abstraction of the multiplier, used by scripts/equiv_induct.ys (never synthesised).
// Replaces each $mul cell with f(a, w) = (a == 0) ? 0 : {a, w}.
// f agrees with a*w when a == 0 and is injective (and non-zero) when a != 0, so it
// distinguishes at least every operand pair that a*w distinguishes. The README
// ("Formal verification") explains why equivalence under f implies equivalence under a*w.
(* techmap_celltype = "$mul" *)
module mul_abstract #(
    parameter A_SIGNED = 0, B_SIGNED = 0, A_WIDTH = 1, B_WIDTH = 1, Y_WIDTH = 1
) (
    input  [A_WIDTH-1:0] A,
    input  [B_WIDTH-1:0] B,
    output [Y_WIDTH-1:0] Y
);
  assign Y = (A == 0) ? {Y_WIDTH{1'b0}} : {A, B};
endmodule
