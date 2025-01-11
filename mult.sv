module mult #(
  parameter WIDTH=64
) (
  input  logic clk, rst,
  input  logic in_valid,
  input  logic [WIDTH-1:0] mult_i1, mult_i2,
  output logic [WIDTH-1:0] mult_o,
  output logic out_valid
);

  // *********************************************************************
  // INTERNAL SIGNALS
  // *********************************************************************
  
  logic [WIDTH-1:0] mult_r1;
  logic valid_r1, valid_r2;

  // *********************************************************************
  // ARCHITECTURE
  // *********************************************************************
  
  // pipelined multiplier
  always_ff @(posedge clk) begin
    if (rst) begin
      mult_r1 <= 0;
      mult_o  <= 0;
    end else if (in_valid) begin // in_valid for less utilization
      mult_r1 <= $signed(mult_i1) * $signed(mult_i2);
      mult_o  <= mult_r1;
    end else begin
      mult_r1 <= mult_r1;
      mult_o  <= mult_o;
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      valid_r1  <= 0;
      out_valid <= 0;
    end else begin
      valid_r1  <= (valid_r1 || out_valid) ? 0 : in_valid;
      out_valid <= valid_r1;
    end
  end
  
endmodule