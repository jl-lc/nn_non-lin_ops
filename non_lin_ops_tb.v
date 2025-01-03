`timescale 1ns / 1ps

module non_lin_ops_tb;

  // Parameters
  parameter WIDTH = 32;

  // Testbench signals
  reg  clk;
  reg  rst;
  reg  in_valid, out_ready;
	reg  sum, max;
  reg  [2:0] op;
  reg  [WIDTH-1:0] qin, qb, qc, qln2, qln2_inv, q1, bias, n_inv, max_bits, m, Sreq;
  reg  [WIDTH-1:0] fp_bits, shift, out_bits;
  reg  [7:0] e;
  wire [WIDTH-1:0] qout;
  wire out_valid, in_ready;


/*
  // Instantiate the design under test (DUT)
  non_lin_ops #(
    .WIDTH(WIDTH)
  ) 
  dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
		.out_ready(out_ready),
		.sum(sum),
		.max(max),
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
    .out_valid(out_valid),
		.in_ready(in_ready)
  );
  */
  
  // Instantiate synth design
  non_lin_ops_synth
  dut (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
		.out_ready(out_ready),
		.sum(sum),
		.max(max),
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
    .out_valid(out_valid),
		.in_ready(in_ready)
  );

  // clk generation
  initial clk = 0;
  always #5 clk = ~clk; // 10ns clk period

  // Test vector files
  integer file_in, file_out, r;
  reg [WIDTH-1:0] expected_qout;
  integer ln_vector_length = 768;
  reg [WIDTH-1:0] ln_qin[767:0];           // ln qin array
  reg [WIDTH-1:0] ln_bias[767:0];          // ln bias array
  reg [WIDTH-1:0] ln_expected_qout[767:0]; // Expected qout array
  integer sm_vector_length = 32;
  reg [WIDTH-1:0] sm_qin[31:0];           // sm qin array
  reg [WIDTH-1:0] sm_qb;                  // sm values  
  reg [WIDTH-1:0] sm_qc;                  // sm values  
  reg [WIDTH-1:0] sm_qln2;                // sm values    
  reg [WIDTH-1:0] sm_qln2_inv;            // sm values        
  reg [WIDTH-1:0] sm_Sreq;                // sm values    
  reg [WIDTH-1:0] sm_expected_qout[31:0]; // Expected qout array
  integer vector_count;

  // Testbench stimulus
  initial begin
    // Initialize signals
    rst = 1;
    in_valid = 0;
		out_ready = 0;
		sum = 0;
		max = 0;
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

    // rst the DUT
    #15 rst = 0;


    /************************* Test Case 1: exponential approximation *************************/
    
    file_in = $fopen("exp_test_vectors.txt", "r");
    file_out = $fopen("/home/jlc2lam/Documents/Vivado/nn_non-lin_ops/test_vectors/exp_test_results.txt", "w");
    if (file_in == 0) begin
      $display("Error: Cannot open exp_test_vectors.txt");
      $finish;
    end
    if (file_out == 0) begin
      $display("Error: Cannot open exp_test_results.txt");
      $finish;
    end
    
    while (!$feof(file_in)) begin
      @(posedge clk);
      r = $fscanf(file_in, "%h %h %h %h %h %h\n", qin, qb, qc, qln2, qln2_inv, expected_qout);
      in_valid = 1;
		  out_ready = 1;
      op = 3'b000;  // exp operation
      fp_bits = 32'd30; // Fixed-point bits init
      @(posedge clk);
      in_valid = 0;

      // Wait for valid output
      wait(out_valid);

      // Write results to file
      if (qout !== expected_qout) begin
        $fwrite(file_out, "FAIL: qin=%h qb=%h qc=%h qln2=%h qln2_inv=%h expected_qout=%h got_qout=%h\n",
                qin, qb, qc, qln2, qln2_inv, expected_qout, qout);
        $fflush(file_out); // Flush the output to the file
      end else begin
        $fwrite(file_out, "PASS: qin=%h\n", qin);
        $fflush(file_out); // Flush the output to the file
      end
    end
    
    $fclose(file_in);
    $fclose(file_out);
    
    /************************* Test Case 1: exponential approximation *************************/



    /************************* Test Case 2: GELU approximation *************************/
    /*
    file_in = $fopen("gelu_test_vectors.txt", "r");
    file_out = $fopen("/home/jlc2lam/Documents/Vivado/nn_non-lin_ops/test_vectors/gelu_test_results.txt", "w");
    if (file_in == 0) begin
      $display("Error: Cannot open gelu_test_vectors.txt");
      $finish;
    end
    if (file_out == 0) begin
      $display("Error: Cannot open gelu_test_results.txt");
      $finish;
    end

    // // test in_valid same cycle as out_valid
    // @(negedge clk);
    // r = $fscanf(file_in, "%h %h %h %h %h\n", qin, qb, qc, q1, expected_qout);
    // in_valid = 1;
    // op = 3'b001;  // GELU operation
    // shift = {{WIDTH-4{1'b0}}, 4'd14}; // shift amount init
    // #20 ;
		// out_ready = 1;
    // #20;
    // @(negedge clk);
    // in_valid = 0;
    // out_ready = 0;

    // // Wait for valid output
    // wait(out_valid);

    // while (!$feof(file_in)) begin
    //   // Write results to file
    //   if (qout !== expected_qout) begin
    //     $fwrite(file_out, "FAIL: qin=%h qb=%h qc=%h q1=%h expected_qout=%h got_qout=%h\n",
    //             qin, qb, qc, q1, expected_qout, qout);
    //     $fflush(file_out); // Flush the output to the file
    //   end else begin
    //     $fwrite(file_out, "PASS: qin=%h\n", qin);
    //     $fflush(file_out); // Flush the output to the file
    //   end

    //   // @(posedge clk);
    //   r = $fscanf(file_in, "%h %h %h %h %h\n", qin, qb, qc, q1, expected_qout);
    //   in_valid = 1;
    //   op = 3'b001;  // GELU operation
    //   shift = {{WIDTH-4{1'b0}}, 4'd14}; // shift amount init
    //   #20 ;
    //   out_ready = 1;
    //   #20;
    //   @(negedge clk);
    //   in_valid = 0;
    //   out_ready = 0;

    //   // Wait for valid output
    //   wait(out_valid);
    // end

    // normal test
    while (!$feof(file_in)) begin
      @(negedge clk);
      r = $fscanf(file_in, "%h %h %h %h %h\n", qin, qb, qc, q1, expected_qout);
      in_valid = 1;
		  out_ready = 1;
      op = 3'b001;  // GELU operation
      shift = {{WIDTH-4{1'b0}}, 4'd14}; // shift amount init
      @(negedge clk);
      in_valid = 0;

      // Wait for valid output
      wait(out_valid);

      // Write results to file
      if (qout !== expected_qout) begin
        $fwrite(file_out, "FAIL: qin=%h qb=%h qc=%h q1=%h expected_qout=%h got_qout=%h\n",
                qin, qb, qc, q1, expected_qout, qout);
        $fflush(file_out); // Flush the output to the file
      end else begin
        $fwrite(file_out, "PASS: qin=%h\n", qin);
        $fflush(file_out); // Flush the output to the file
      end
    end
    
    $fclose(file_in);
    $fclose(file_out);
    */    
    /************************* Test Case 2: GELU approximation *************************/



    /************************* Test Case 3: layer_norm approximation *************************/
    /*
    file_in = $fopen("ln_test_vectors.txt", "r");
    file_out = $fopen("/home/jlc2lam/Documents/Vivado/nn_non-lin_ops/test_vectors/ln_test_results.txt", "w");
    if (file_in == 0) begin
      $display("Error: Cannot open ln_test_vectors.txt");
      $finish;
    end else begin
      $display("Success: Opened ln_test_vectors.txt");
    end
    if (file_out == 0) begin
      $display("Error: Cannot open ln_test_results.txt");
      $finish;
    end else begin
      $display("Success: Opened ln_test_results.txt");
    end

    vector_count = 0;

    // Read and process the file line by line
    while (!$feof(file_in)) begin
      // rst the DUT
      #10 rst = 1;
      #10 rst = 0;

      // Loop through all vector elements
      for (integer i = 0; i < ln_vector_length; i = i + 1) begin
        r = $fscanf(file_in, "%h", ln_qin[i]);
      end
      r = $fscanf(file_in, "|");
      for (integer i = 0; i < ln_vector_length; i = i + 1) begin
        r = $fscanf(file_in, "%h", ln_bias[i]);
      end
      r = $fscanf(file_in, "|");
      for (integer i = 0; i < ln_vector_length; i = i + 1) begin
        r = $fscanf(file_in, "%h", ln_expected_qout[i]);
      end

      // Apply test vector to DUT
      for (integer i = 0; i < ln_vector_length; i = i + 1) begin // sum()
        @(negedge clk);
        sum = 1;
        in_valid = 1;
        qin = ln_qin[i];
		    out_ready = 1;
        op = 3'b010;  // layer_norm operation
        shift = 32'd6; // shift amount init
        n_inv = 32'd1398101; // n_inv amount init
        fp_bits = 32'd30; // Fixed-point bits init
        max_bits = 32'd31; // Fixed-point bits
        @(negedge clk);
        in_valid = 0;

        // Wait for valid output
        wait(in_ready);
      end
      for (integer i = 0; i < ln_vector_length; i = i + 1) begin // vector calculation
        @(negedge clk);
        sum = 0;
        in_valid = 1;
        qin = ln_qin[i];
        bias = ln_bias[i];
		    out_ready = 1;
        op = 3'b010;  // layer_norm operation
        shift = 32'd6; // shift amount init
        n_inv = 32'd1398101; // n_inv amount init
        fp_bits = 32'd30; // Fixed-point bits init
        max_bits = 32'd31; // max bits init
        @(negedge clk);
        in_valid = 0;

        // Wait for valid output
        wait(out_valid);

        // Check results
        $fwrite(file_out, "vector count %0d:\n", vector_count);
        if (qout !== ln_expected_qout[i]) begin
          $fwrite(file_out, "FAIL at index %0d: ln_qin=%h, ln_bias=%h, qout=%h, expected=%h\n",
                   i, ln_qin[i], ln_bias[i], qout, ln_expected_qout[i]);
          $fflush(file_out); // Flush the output to the file
        end else begin
          $fwrite(file_out, "PASS at index %0d: ln_qin=%h\n", i, ln_qin[i]);
          $fflush(file_out); // Flush the output to the file
        end
      end
      vector_count = vector_count + 1;
    end

    $fclose(file_in);
    $fclose(file_out);
    */
    /************************* Test Case 3: layer_norm approximation *************************/



    /************************* Test Case 4: requant approximation *************************/
    /*
    file_in = $fopen("req_test_vectors.txt", "r");
    file_out = $fopen("/home/jlc2lam/Documents/Vivado/nn_non-lin_ops/test_vectors/req_test_results.txt", "w");
    if (file_in == 0) begin
      $display("Error: Cannot open req_test_vectors.txt");
      $finish;
    end
    if (file_out == 0) begin
      $display("Error: Cannot open req_test_results.txt");
      $finish;
    end
    
    while (!$feof(file_in)) begin
      @(negedge clk);
      r = $fscanf(file_in, "%h %h %h %h %h\n", qin, bias, m, e, expected_qout);
      in_valid = 1;
		  out_ready = 1;
      op = 3'b011;  // req operation
      out_bits = 32'd8; // Fixed-point bits init
      @(negedge clk);
      in_valid = 0;

      // Wait for valid output
      wait(out_valid);

      // Write results to file
      if (qout !== expected_qout) begin
        $fwrite(file_out, "FAIL: qin=%h bias=%h m=%h e=%h expected_qout=%h got_qout=%h\n",
                qin, bias, m, e, expected_qout, qout);
        $fflush(file_out); // Flush the output to the file
      end else begin
        $fwrite(file_out, "PASS: qin=%h\n", qin);
        $fflush(file_out); // Flush the output to the file
      end
    end
    
    $fclose(file_in);
    $fclose(file_out);
    */
    /************************* Test Case 4: requant approximation *************************/



    /************************* Test Case 5: softmax approximation *************************/
    /*
    file_in = $fopen("sm_test_vectors.txt", "r");
    file_out = $fopen("/home/jlc2lam/Documents/Vivado/nn_non-lin_ops/test_vectors/sm_test_results.txt", "w");
    if (file_in == 0) begin
      $display("Error: Cannot open sm_test_vectors.txt");
      $finish;
    end else begin
      $display("Success: Opened sm_test_vectors.txt");
    end
    if (file_out == 0) begin
      $display("Error: Cannot open sm_test_results.txt");
      $finish;
    end else begin
      $display("Success: Opened sm_test_results.txt");
    end

    vector_count = 0;

    // Read and process the file line by line
    while (!$feof(file_in)) begin
      // rst the DUT
      #10 rst = 1;
      #10 rst = 0;

      // Loop through all vector elements
      for (integer i = 0; i < sm_vector_length; i = i + 1) begin
        r = $fscanf(file_in, "%h", sm_qin[i]);
      end
      r = $fscanf(file_in, " | %h | %h | %h | %h | %h | ", sm_qb, sm_qc, sm_qln2, sm_qln2_inv, sm_Sreq);
      for (integer i = 0; i < sm_vector_length; i = i + 1) begin
        r = $fscanf(file_in, "%h", sm_expected_qout[i]);
      end

      // Apply test vector to DUT
      for (integer i = 0; i < sm_vector_length; i = i + 1) begin // max()
        @(negedge clk);
        max = 1;
        in_valid = 1;
        qin = sm_qin[i];
		    out_ready = 1;
        op = 3'b100;  // softmax operation
        fp_bits = 32'd30; // Fixed-point bits init
        max_bits = 32'd30; // Fixed-point bits
        out_bits = 32'd6; // Fixed-point bits
        qb = sm_qb;
        qc = sm_qc;
        qln2 = sm_qln2;
        qln2_inv = sm_qln2_inv;
        Sreq = sm_Sreq;
        @(negedge clk);
        in_valid = 0;

        // Wait for valid output
        wait(in_ready);
      end
      for (integer i = 0; i < sm_vector_length; i = i + 1) begin // sum()
        @(negedge clk);
        max = 0;
        sum = 1;
        in_valid = 1;
        qin = sm_qin[i];
		    out_ready = 1;
        op = 3'b100;  // softmax operation
        fp_bits = 32'd30; // Fixed-point bits init
        max_bits = 32'd30; // Fixed-point bits
        out_bits = 32'd6; // Fixed-point bits
        qb = sm_qb;
        qc = sm_qc;
        qln2 = sm_qln2;
        qln2_inv = sm_qln2_inv;
        Sreq = sm_Sreq;
        @(negedge clk);
        in_valid = 0;

        // Wait for valid output
        wait(in_ready);
      end
      for (integer i = 0; i < sm_vector_length; i = i + 1) begin // vector calculation
        @(negedge clk);
        sum = 0;
        in_valid = 1;
        qin = sm_qin[i];
		    out_ready = 1;
        op = 3'b100;  // softmax operation
        fp_bits = 32'd30; // Fixed-point bits init
        max_bits = 32'd30; // max bits init
        out_bits = 32'd6; // out bits inits
        qb = sm_qb;
        qc = sm_qc;
        qln2 = sm_qln2;
        qln2_inv = sm_qln2_inv;
        Sreq = sm_Sreq;
        @(negedge clk);
        in_valid = 0;

        // Wait for valid output
        wait(out_valid);

        // Check results
        $fwrite(file_out, "vector count %0d:\n", vector_count);
        if (qout !== sm_expected_qout[i]) begin
          $fwrite(file_out, "FAIL at index %0d: sm_qin=%h, sm_qb=%h, sm_qc=%h, sm_qln2=%h, sm_qln2_inv=%h, sm_Sreq=%h, qout=%h, expected=%h\n",
                   i, sm_qin[i], sm_qb, sm_qc, sm_qln2, sm_qln2_inv, sm_Sreq, qout, sm_expected_qout[i]);
          $fflush(file_out); // Flush the output to the file
        end else begin
          $fwrite(file_out, "PASS at index %0d: sm_qin=%h\n", i, sm_qin[i]);
          $fflush(file_out); // Flush the output to the file
        end
      end
      vector_count = vector_count + 1;
    end

    $fclose(file_in);
    $fclose(file_out);
    */
    /************************* Test Case 5: softmax approximation *************************/



    /************************* Test Case 6: handshaking stress test *************************/
    /************************* Test Case 6: handshaking stress test *************************/
    $finish;
  end
endmodule
