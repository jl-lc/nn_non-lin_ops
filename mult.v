module mult #(
  parameter WIDTH=64
) (
  input  wire [WIDTH-1:0] mult_i1, mult_i2,
  output wire [WIDTH-1:0] mult_o
);

  /************************* internal signals *************************/
  /************************* internal signals *************************/


  /************************* architecture *************************/
  
  // combinational logic
  assign mult_o = mult_i1 + mult_i2;
      
  /************************* architecture *************************/
  
endmodule