`timescale 1ns / 1ps

module non_lin_ops_tb;

  // Parameters
  parameter WIDTH = 32;

  // Testbench signals
  reg  clock;
  reg  reset;
  reg  in_valid;
  reg  [2:0] op;
  reg  [WIDTH-1:0] qin, qb, qc, qln2, qln2_inv, q1, bias, n_inv, max_bits, m, Sreq;
  reg  [WIDTH-1:0] fp_bits, shift, out_bits;
  reg  [7:0] e;
  wire [WIDTH-1:0] qout;
  wire out_valid;

  // Instantiate the design under test (DUT)
  non_lin_ops #(
    .WIDTH(WIDTH)
  ) dut (
    .clock(clock),
    .reset(reset),
    .in_valid(in_valid),
    .op(op),
    .qin(qin),
    .qb(qb),
    .qc(qc),
    .qln2(qln2),
    .qln2_inv(qln2_inv),
    .fp_bits(fp_bits),
    .q1(q1),
    .shift(shift),
    .bias(bias),
    .n_inv(n_inv),
    .max_bits(max_bits),
    .m(m),
    .out_bits(out_bits),
    .Sreq(Sreq),
    .e(e),
    .qout(qout),
    .out_valid(out_valid)
  );

  // Clock generation
  initial clock = 0;
  always #5 clock = ~clock; // 10ns clock period

  // Testbench stimulus
  initial begin
    // Initialize signals
    reset = 1;
    in_valid = 0;
    op = 3'b000;
    qin = 0;
    qb = 0;
    qc = 0;
    qln2 = 0;
    qln2_inv = 0;
    fp_bits = 0;
    q1 = 0;
    shift = 0;
    bias = 0;
    n_inv = 0;
    max_bits = 0;
    m = 0;
    Sreq = 0;
    out_bits = 0;
    e = 0;

    // Reset the DUT
    #10 reset = 0;

    // Test Case 1: exponential approximation
    in_valid = 1;
    op = 3'd0;
    qb = 32'h0000_0002; // Coefficient example
    qc = 32'h0000_0003; // Coefficient example
    qln2 = 32'h0000_0001;
    qln2_inv = 32'h0000_0001;
    fp_bits = 32'd30; // Fixed-point bits

    // Iterate through possible qin values
    for (qin = 32'h0000_0000; qin < 32'h0000_0010; qin = qin + 1) begin // Test a range of values (first 256)
      #90; // Wait for 9 clock cycles
    end

/*
qin = 2
qb = 2
qc = 3
qln2 = 1
qln2_inv = 1
fp_bits = 30
fp_mul = qin * qln2_inv   # mul
print(fp_mul)
z = fp_mul >> fp_bits
print(z)
qp = qin - z * qln2                 # mul, sub
print(qp)
ql = (qp + qb) * qp + qc            # poly
print(ql)
qout = ql >> z            # shift
print(qout)
*/

    // End simulation
    #100;
    $stop;
  end

  // Monitor output
  initial begin
    $monitor("Time: %0t | op: %b | qin: %h | qb: %h | qout: %h",
             $time, op, qin, qb, qout);
  end
endmodule
