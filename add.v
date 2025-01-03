module add #(
  parameter WIDTH=64
) (
	input  wire addsub,
  input  wire [WIDTH-1:0] add_i1, add_i2,
  output wire [WIDTH-1:0] add_o
);

  /************************* internal signals *************************/
  /************************* internal signals *************************/


  /************************* architecture *************************/
  
  // combinational logic
  assign add_o = ~addsub ? $signed(add_i1 + add_i2) : $signed(add_i1 - add_i2);
  
  /************************* architecture *************************/
  
endmodule
