module varshift #(
  parameter WIDTH=64
) (
  input  wire varshift_lr,
  input  wire [WIDTH-1:0] varshift_i1, varshift_i2,
  output wire [WIDTH-1:0] varshift_o
);

  /************************* internal signals *************************/
  /************************* internal signals *************************/



  /************************* architecture *************************/

  // combinational logic
  assign varshift_o = ~varshift_lr ? ($signed(varshift_i1) << $signed(varshift_i2)) : ($signed(varshift_i1) >>> $signed(varshift_i2)); // always asr?

  /************************* architecture *************************/
  
endmodule