module usrmux #(
  parameter WIDTH=64
) (
  input  wire usrmux_sel,
  input  wire [WIDTH-1:0] usrmux_i0, usrmux_i1,
  output wire [WIDTH-1:0] usrmux_o
);

  /************************* internal signals *************************/
  /************************* internal signals *************************/



  /************************* architecture *************************/

  // combinational logic
  assign usrmux_o = ~usrmux_sel ? usrmux_i0 : usrmux_i1;
      
  /************************* architecture *************************/
  
endmodule