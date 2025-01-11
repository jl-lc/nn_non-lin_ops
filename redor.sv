module redor #(
  parameter WIDTH=64
) (
  input  logic [WIDTH-1:0] redor_i1,
  output logic             redor_o
);

  // *********************************************************************
  // INTERNAL SIGNALS
  // *********************************************************************
  
  // *********************************************************************
  // ARCHITECTURE
  // *********************************************************************
  
  // combinational logic
  always_comb redor_o = |redor_i1;
  
endmodule
