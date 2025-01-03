module redor #(
  parameter WIDTH=64
) (
  input  wire [WIDTH-1:0] redor_i1,
  output wire             redor_o
);

  /************************* internal signals *************************/
  /************************* internal signals *************************/


  /************************* architecture *************************/
  
  // combinational logic
  assign redor_o = |redor_i1;
  
  /************************* architecture *************************/
  
endmodule
