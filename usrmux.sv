module usrmux #(
  parameter WIDTH=64
) (
  input  logic usrmux_sel,
  input  logic [WIDTH-1:0] usrmux_i0, usrmux_i1,
  output logic [WIDTH-1:0] usrmux_o
);
  // *********************************************************************
  // INTERNAL SIGNALS
  // *********************************************************************
  
  // *********************************************************************
  // ARCHITECTURE
  // *********************************************************************

  // combinational logic
  always_comb usrmux_o = usrmux_sel ? usrmux_i1 : usrmux_i0;
  
endmodule