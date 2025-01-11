module add #(
  parameter WIDTH=64
) (
	input  logic addsub,
  input  logic [WIDTH-1:0] add_i1, add_i2,
  output logic [WIDTH-1:0] add_o
);

  // *********************************************************************
  // INTERNAL SIGNALS
  // *********************************************************************

  // *********************************************************************
  // ARCHITECTURE
  // *********************************************************************
  
  // combinational logic
  always_comb add_o = addsub ? $signed(add_i1 - add_i2) : $signed(add_i1 + add_i2);
  
endmodule
