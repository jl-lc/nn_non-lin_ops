module varshift #(
  parameter WIDTH=64
) (
  input  logic varshift_lr,
  input  logic [WIDTH-1:0] varshift_i1, varshift_i2,
  output logic [WIDTH-1:0] varshift_o
);

  // *********************************************************************
  // INTERNAL SIGNALS
  // *********************************************************************
  
  // *********************************************************************
  // ARCHITECTURE
  // *********************************************************************

  // combinational logic
  always_comb varshift_o = varshift_lr ? ($signed(varshift_i1) >>> $signed(varshift_i2)) : ($signed(varshift_i1) << $signed(varshift_i2));
  
endmodule