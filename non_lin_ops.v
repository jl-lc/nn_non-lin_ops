module non_lin_ops #(
  parameter WIDTH=32
) (
  input wire              clk, rst, in_valid, out_ready,
	input wire							sum, max, 
  input wire [2:0]        op,       // select which op in tb
  input wire [WIDTH-1:0]  qin,      // int32, input                                       exp, gelu, layer_norm, requant, softmax
                          qb,       // int32, fixed inference coefficients                exp, gelu, softmax
                          qc,       // int32, fixed inference coefficients                exp, gelu, softmax
                          qln2,     // int32, fixed inference coefficients                exp, softmax
                          qln2_inv, // int32, fixed inference coefficients                exp, softmax
                          fp_bits,  // constant, fixed point multiplication bits, int=30  exp, layer_norm, softmax
                          q1,       // int32, fixed inference coefficients                gelu
                          shift,    // constant, shift amount                             gelu, layer_norm
                          bias,     // int32, bias                                        layer_norm, requant
                          n_inv,    // int32, integer constants                           layer_norm
                          max_bits, // int32, integer constants                           layer_norm, softmax
                          m,        // int32, requantization multiplier                   requant
                          out_bits, // int, number of out bits                            requant, softmax
                          Sreq,     // int32, requantization coefficient                  softmax
  input wire [7:0]        e,        // int8, requantization shifter                       requant
  output reg [WIDTH-1:0]  qout,     // int32, output, integer approximation of exp
  output reg              out_valid, in_ready
);

  // TODO:
	// verify if handshaking logic is correct. do in_valid and out_ready need to be registered
	// confirm internal signal sizings
	// constants in input of each operation (i.e. fp_bits, shift), how are they handled
  // constants of the functions, should they be hardcoded? (current implementation isn't)

  /************************* internal signals *************************/

  // operations
  localparam exp=3'd0, gelu=3'd1, layer_norm=3'd2, requant=3'd3, softmax=3'd4;

  reg [5:0] state, next; // support 44 cycles

  localparam INTERNAL_WIDTH = WIDTH*2; // all internal signals are int64
	localparam INTERNAL_SQRTIN_WIDTH = WIDTH; // sqrt input is int32
	localparam INTERNAL_SQRTOUT_WIDTH = WIDTH/2; // sqrt output is int16
	localparam INTERNAL_DIV_WIDTH = WIDTH; // div input/output is int32

  reg [2:0] op_r;
	reg sum_r, max_r;
  reg not_busy;

  // sign-extend 64bits        
  reg signed [INTERNAL_WIDTH-1:0] qin_r; 
  reg signed [INTERNAL_WIDTH-1:0] qb_r;          
  reg signed [INTERNAL_WIDTH-1:0] qc_r;          
  reg signed [INTERNAL_WIDTH-1:0] qln2_r;          
  reg signed [INTERNAL_WIDTH-1:0] qln2_inv_r;          
  reg signed [INTERNAL_WIDTH-1:0] fp_bits_r;         
  reg signed [INTERNAL_WIDTH-1:0] q1_r;          
  reg signed [INTERNAL_WIDTH-1:0] shift_r;         
  reg signed [INTERNAL_WIDTH-1:0] bias_r;          
  reg signed [INTERNAL_WIDTH-1:0] n_inv_r;         
  reg signed [INTERNAL_WIDTH-1:0] max_bits_r;            
  reg signed [INTERNAL_WIDTH-1:0] m_r;         
  reg signed [INTERNAL_WIDTH-1:0] out_bits_r;          
  reg signed [INTERNAL_WIDTH-1:0] Sreq_r;          
  reg signed [INTERNAL_WIDTH-1:0] e_r;         

  // muxed inputs to functional units
  reg                             addsub;
  reg signed [INTERNAL_WIDTH-1:0] add_i1, add_i2;
  reg signed [INTERNAL_WIDTH-1:0] mult_i1, mult_i2;
  reg                             varshift_lr;
  reg signed [INTERNAL_WIDTH-1:0] varshift_i1, varshift_i2;
  reg                             usrmux_sel;
  reg signed [INTERNAL_WIDTH-1:0] usrmux_i0, usrmux_i1;
  reg signed [INTERNAL_WIDTH-1:0] redor_i1;
  reg signed [INTERNAL_DIV_WIDTH-1:0] div_i1, div_i2;
  reg signed [INTERNAL_SQRTIN_WIDTH-1:0] sqrt_i1;

  // outputs from functional units
  wire signed [INTERNAL_WIDTH-1:0] add_o;
  wire signed [INTERNAL_WIDTH-1:0] mult_o;
  wire signed [INTERNAL_WIDTH-1:0] varshift_o;
  wire signed [INTERNAL_WIDTH-1:0] usrmux_o;
  wire signed                      redor_o;
  wire signed [INTERNAL_DIV_WIDTH-1:0] div_o;
  wire signed [INTERNAL_SQRTOUT_WIDTH-1:0] sqrt_o;

  // registered outputs
  reg signed [INTERNAL_WIDTH-1:0] add_r;
  reg signed [INTERNAL_WIDTH-1:0] mult_r;
  reg signed [INTERNAL_WIDTH-1:0] varshift_r;
  reg signed [INTERNAL_WIDTH-1:0] usrmux_r;
  reg signed                      redor_r;
  reg signed [INTERNAL_WIDTH-1:0] div_r;
  reg signed [INTERNAL_WIDTH-1:0] sqrt_r;

  // register enable/disable
  reg mult_en;
  reg add_en;
  reg varshift_en;
  reg usrmux_en;
  reg redor_en;
  reg div_en;
  reg sqrt_en;

  // sum(), max() regs
  reg [INTERNAL_WIDTH-1:0] rr0, rr1;
	
	// sqrt/div out valid
	wire sqrt_o_valid; 
	wire div_o_valid;

  /************************* internal signals *************************/



  /************************* architecture *************************/

  // register inputs and sign-extend 64 bits           
	always @(posedge clk) begin
		if (rst) begin
      op_r        <= 0;
			sum_r				<= 0;
			max_r				<= 0;
			qin_r       <= 0; 
			qb_r        <= 0;        
			qc_r        <= 0;       
			qln2_r      <= 0;             
			qln2_inv_r  <= 0;                             
			fp_bits_r   <= 0;                   
			q1_r        <= 0;       
			shift_r     <= 0;             
			bias_r      <= 0;             
			n_inv_r     <= 0;             
			max_bits_r  <= 0;                           
			m_r         <= 0; 
			out_bits_r  <= 0;                         
			Sreq_r      <= 0;             
			e_r         <= 0; 
		end else begin
			// accept input when in_valid and not busy, and not necessarily when out_ready. the idea is to hide latency
      op_r        <= (in_valid && not_busy) ? op  : op_r;
      sum_r       <= (in_valid && not_busy) ? sum : sum_r;
			max_r       <= (in_valid && not_busy) ? max : max_r;
			qin_r       <= (in_valid && not_busy) ? {{WIDTH{qin     [WIDTH-1]}},       qin} : qin_r; 
  		qb_r        <= (in_valid && not_busy) ? {{WIDTH{qb      [WIDTH-1]}},        qb} : qb_r;               
  		qc_r        <= (in_valid && not_busy) ? {{WIDTH{qc      [WIDTH-1]}},        qc} : qc_r;              
  		qln2_r      <= (in_valid && not_busy) ? {{WIDTH{qln2    [WIDTH-1]}},      qln2} : qln2_r;                  
  		qln2_inv_r  <= (in_valid && not_busy) ? {{WIDTH{qln2_inv[WIDTH-1]}},  qln2_inv} : qln2_inv_r;                              
  		fp_bits_r   <= (in_valid && not_busy) ? {{WIDTH{fp_bits [WIDTH-1]}},   fp_bits} : fp_bits_r;                     
  		q1_r        <= (in_valid && not_busy) ? {{WIDTH{q1      [WIDTH-1]}},        q1} : q1_r;              
  		shift_r     <= (in_valid && not_busy) ? {{WIDTH{shift   [WIDTH-1]}},     shift} : shift_r;                 
  		bias_r      <= (in_valid && not_busy) ? {{WIDTH{bias    [WIDTH-1]}},      bias} : bias_r;                  
  		n_inv_r     <= (in_valid && not_busy) ? {{WIDTH{n_inv   [WIDTH-1]}},     n_inv} : n_inv_r;                 
  		max_bits_r  <= (in_valid && not_busy) ? {{WIDTH{max_bits[WIDTH-1]}},  max_bits} : max_bits_r;                            
  		m_r         <= (in_valid && not_busy) ? {{WIDTH{m       [WIDTH-1]}},         m} : m_r;         
  		out_bits_r  <= (in_valid && not_busy) ? {{WIDTH{out_bits[WIDTH-1]}},  out_bits} : out_bits_r;                          
  		Sreq_r      <= (in_valid && not_busy) ? {{WIDTH{Sreq    [WIDTH-1]}},      Sreq} : Sreq_r;                  
  		e_r         <= (in_valid && not_busy) ? {{24   {e       [8-1]}},             e} : e_r;         
		end
	end

  // state transition logic
  always @(*) begin
    case (op_r)
			exp: begin
        case (state)
          6'd0:    next <= in_valid ? 6'd1 : 6'd0; // rst state
          6'd1:    next <= 6'd2;
          6'd2:    next <= 6'd3;
          6'd3:    next <= 6'd4;
          6'd4:    next <= 6'd5;
          6'd5:    next <= 6'd6;
          6'd6:    next <= 6'd7;
          6'd7:    next <= 6'd8;
          6'd8:    next <= 6'd9;
          6'd9:    next <= out_ready ? (in_valid ? 6'd1 : 6'd0) : 6'd9; // output state. keep output if not consumed
          default: next <= 6'd0;
        endcase
			end
      
			gelu: begin
				case (state)
					6'd0 :		next <= in_valid ? 6'd1 : 6'd0; // rst state
					6'd1 :		next <= 6'd2;
					6'd2 :		next <= 6'd3;
					6'd3 :		next <= 6'd4;
					6'd4 :		next <= 6'd5;
					6'd5 :		next <= 6'd6;
					6'd6 :		next <= 6'd7;
					6'd7 :		next <= 6'd8;
					6'd8 :		next <= 6'd9;
					6'd9 :		next <= 6'd10;
					6'd10:		next <= 6'd11;
					6'd11:		next <= 6'd12;
					6'd12:		next <= out_ready ? (in_valid ? 6'd1 : 6'd0) : 6'd12; // output state. keep output if not consumed
					default:	next <= 6'd0;
				endcase
			end

			layer_norm: begin
				case (state)
					6'd0 :		next <= in_valid ? 6'd1 : 6'd0; // rst state
					6'd1 :		next <= 6'd2;
					6'd2 :		next <= 6'd3;
					6'd3 :		next <= 6'd4;
					6'd4 :		next <= sum_r ? (in_valid ? 6'd1 : 6'd0) : 6'd5; // sum state
					6'd5 :		next <= 6'd6;
					6'd6 :		next <= 6'd7;
					6'd7 :		next <= 6'd8;
					6'd8 :		next <= 6'd9;
					6'd9 :		next <= sqrt_o_valid ? 6'd11 : 6'd10;
					6'd10:		next <= sqrt_o_valid ? 6'd11 : 6'd10; // sqrt state
					6'd11:		next <= 6'd12;
					6'd12:		next <= div_o_valid ? 6'd14 : 6'd13;
					6'd13:		next <= div_o_valid ? 6'd14 : 6'd13; // div state
					6'd14: 		next <= 6'd15;
					6'd15:		next <= 6'd16;
					6'd16:		next <= 6'd17;
					6'd17:		next <= out_ready ? (in_valid ? 6'd1 : 6'd0) : 6'd17; // output state. keep output if not consumed
					default:	next <= 6'd0;
				endcase
			end

			requant: begin
				case (state)
					6'd0 :		next <= in_valid ? 6'd1 : 6'd0; // rst state
					6'd1 :		next <= 6'd2;
					6'd2 :		next <= 6'd3;
					6'd3 :		next <= 6'd4;
					6'd4 :		next <= 6'd5;
					6'd5 :		next <= 6'd6;
					6'd6 :		next <= 6'd7;
					6'd7 :		next <= 6'd8;
					6'd8 :		next <= 6'd9;
					6'd9 :		next <= 6'd10;
					6'd10:		next <= 6'd11;
					6'd11:		next <= 6'd12;
					6'd12:		next <= 6'd13;
					6'd13:		next <= 6'd14;
					6'd14: 		next <= 6'd15;
					6'd15:		next <= 6'd16;
					6'd16:		next <= 6'd17;
					6'd17:		next <= out_ready ? (in_valid ? 6'd1 : 6'd0) : 6'd17; // output state. keep output if not consumed
					default:	next <= 6'd0;
				endcase     
			end

			softmax: begin
				case (state)
					6'd0 :		next <= in_valid ? 6'd1 : 6'd0; // rst state
					6'd1 :		next <= 6'd2;
					6'd2 :		next <= 6'd3;
					6'd3 :		next <= max_r ? (in_valid ? 6'd1 : 6'd0) : 6'd4; // max state
					6'd4 :		next <= 6'd5;
					6'd5 :		next <= 6'd6;
					6'd6 :		next <= 6'd7;
					6'd7 :		next <= 6'd8;
					6'd8 :		next <= 6'd9;
					6'd9 :		next <= 6'd10;
					6'd10:		next <= 6'd11;
					6'd11:		next <= 6'd12;
					6'd12:		next <= 6'd13;
					6'd13:		next <= 6'd14;
					6'd14: 		next <= 6'd15;
					6'd15:		next <= 6'd16;
					6'd16:		next <= 6'd17;
					6'd17:		next <= 6'd18;
					6'd18:		next <= 6'd19;
					6'd19:		next <= 6'd20;
					6'd20:		next <= 6'd21;
					6'd21:		next <= 6'd22;
					6'd22:		next <= sum_r ? (in_valid ? 6'd1 : 6'd0) : 6'd23; // sum state
					6'd23:		next <= div_o_valid ? 6'd25 : 6'd24;
					6'd24:		next <= div_o_valid ? 6'd25 : 6'd24; // div state
					6'd25:		next <= 6'd26;
					6'd26:		next <= 6'd27;
					6'd27:		next <= out_ready ? (in_valid ? 6'd1 : 6'd0) : 6'd27; // output state. keep output if not consumed
					default:	next <= 6'd0;
				endcase    
			end

			default: begin
        next <= 6'd0;
			end
    endcase
  end

	// state ff
  always @(posedge clk) 
    state <= rst ? 6'd0 : next;

  // output logic
  always @(*) begin
    case (op_r)
      exp: begin
				out_valid <= (state == 6'd9);
        qout <= (state == 6'd9) ? varshift_r : 0;
				not_busy <= (state == 6'd0) || ((state == 6'd9) && out_ready); // upstream ready hi when rst state or output data consumed
      end

      gelu: begin
        out_valid <= (state == 6'd12);
        qout <= (state == 6'd12) ? mult_r : 0;
				not_busy <= (state == 6'd0) || ((state == 6'd12) && out_ready); // upstream ready hi when rst state or output data consumed
      end   

      layer_norm: begin
        out_valid <= (state == 6'd17);
        qout <= (state == 6'd17) ? add_r : 0;
				not_busy <= (state == 6'd0) || ((state == 6'd17) && out_ready) ||
									  (sum_r && state == 6'd4); // upstream ready hi when rst state or output data consumed or sum()
      end   

      requant: begin
        out_valid <= (state == 6'd17);
        qout <= (state == 6'd17) ? usrmux_r : 0;
				not_busy <= (state == 6'd0) || ((state == 6'd17) && out_ready); // upstream ready hi when rst state or output data consumed
      end   

      softmax: begin
        out_valid <= (state == 6'd27);
        qout <= (state == 6'd27) ? varshift_r : 0;
				not_busy <= (state == 6'd0) || ((state == 6'd27) && out_ready) ||
                    (max_r && state == 6'd3) || (sum_r && state == 6'd22); 
                    // upstream ready hi when rst state or output data consumed or max() or sum()
      end   

      default: begin
        qout <= 0;
        out_valid <= 0;
        not_busy <= 0;
      end
    endcase
  end

  always @(*)
    in_ready <= not_busy;
  
  // mux add inputs
	localparam ADD=0, SUB=1;
  always @(*) begin
    case (op_r)
			exp: begin
        case (state)
          6'd4: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= qin_r;
            add_i2 <= mult_r;
          end
          6'd5: begin
            add_en <= 1;
						addsub <= ADD;
            add_i1 <= qb_r;
            add_i2 <= add_r;
          end
          6'd7: begin
            add_en <= 1;
						addsub <= ADD;
            add_i1 <= qc_r;
            add_i2 <= mult_r;
          end
          default: begin
            add_en <= 0;
						addsub <= 0;
            add_i1 <= 0;
            add_i2 <= 0;
          end
        endcase
			end

      gelu: begin
				case (state)
					6'd3: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= mult_r;
						add_i2 <= usrmux_r;
					end
					6'd5: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= mult_r;
						add_i2 <= usrmux_r;
					end
					6'd7: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= mult_r;
						add_i2 <= qc_r;
					end
					6'd10: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= varshift_r;
						add_i2 <= q1_r;
					end
					default: begin
						add_en <= 0;
						addsub <= 0;
						add_i1 <= 0;
						add_i2 <= 0;
					end
				endcase
      end

      layer_norm: begin
				case (state)
					6'd2: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= rr0;
						add_i2 <= usrmux_r;
					end
					6'd4: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= rr1;
						add_i2 <= mult_r;
					end
					6'd8: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= rr1;
						add_i2 <= varshift_r;
					end
					6'd11: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= qin_r;
						add_i2 <= usrmux_r;
					end
					6'd16: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= bias_r;
						add_i2 <= varshift_r;
					end
					default: begin
						add_en <= 0;
						addsub <= 0;
						add_i1 <= 0;
						add_i2 <= 0;
					end
				endcase
      end   

      requant: begin
        case (state)
					6'd1: begin
						add_en <= 1;
						addsub <= ADD;
						add_i1 <= qin_r;
						add_i2 <= bias_r;
					end
					6'd2: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= INTERNAL_WIDTH; // constant at runtime?
						add_i2 <= e_r;
					end
          6'd7: begin
						add_en <= 1;
						addsub <= ADD;
            add_i1 <= usrmux_r;
            add_i2 <= varshift_r;
          end
					6'd9: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= out_bits_r;
						add_i2 <= 64'd1;
					end
					6'd12: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= usrmux_r;
						add_i2 <= mult_r;
					end
					6'd14: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= mult_r;
						add_i2 <= 64'd1;
					end
					6'd15: begin
						add_en <= 1;
						addsub <= SUB;
						add_i1 <= usrmux_r;
						add_i2 <= add_r;
					end
					default: begin
						add_en <= 0;
						addsub <= 0;
						add_i1 <= 0;
						add_i2 <= 0;
					end
        endcase
      end    

      softmax: begin
        case (state)
          6'd2: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= usrmux_r;
            add_i2 <= rr0;
          end
          6'd4: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= qin_r;
            add_i2 <= rr0;
          end
          6'd8: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= add_r;
            add_i2 <= mult_r;
          end
          6'd9: begin
						add_en <= 1;
						addsub <= ADD;
            add_i1 <= qb_r;
            add_i2 <= add_r;
          end
          6'd11: begin
						add_en <= 1;
						addsub <= ADD;
            add_i1 <= qc_r;
            add_i2 <= mult_r;
          end
          6'd13: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= INTERNAL_WIDTH; // constant at runtime?
            add_i2 <= fp_bits_r;
          end
          6'd18: begin
						add_en <= 1;
						addsub <= ADD;
            add_i1 <= usrmux_r;
            add_i2 <= varshift_r;
          end
          6'd22: begin
						add_en <= 1;
						addsub <= ADD;
            add_i1 <= rr1;
            add_i2 <= usrmux_r;
          end
          6'd25: begin
						add_en <= 1;
						addsub <= SUB;
            add_i1 <= max_bits_r;
            add_i2 <= out_bits_r;
          end
          default: begin
            add_en <= 0;
						addsub <= 0;
            add_i1 <= 0;
            add_i2 <= 0;
          end
        endcase
      end   

      default: begin
				addsub <= 0;
        add_en <= 0;
        add_i1 <= 0;
        add_i2 <= 0;
      end
    endcase
  end
  
  // mux mult inputs
  always @(*) begin
    case (op_r)
			exp: begin
        case (state)
          6'd1: begin
            mult_en <= 1;
            mult_i1 <= qin_r;
            mult_i2 <= qln2_inv_r;
          end
          6'd3: begin
            mult_en <= 1;
            mult_i1 <= qln2_r;
            mult_i2 <= varshift_r;
          end
          6'd6: begin
            mult_en <= 1;
            mult_i1 <= add_r;
            mult_i2 <= usrmux_r;
          end
          default: begin
            mult_en <= 0;
            mult_i1 <= 0;
            mult_i2 <= 0;
          end
        endcase
			end

			gelu: begin
				case (state)
          6'd1: begin
            mult_en <= 1;
            mult_i1 <= qin_r;
            mult_i2 <= -64'd1;
          end
          6'd2: begin
            mult_en <= 1;
            mult_i1 <= qb_r;
            mult_i2 <= -64'd1;
          end
          6'd4: begin
            mult_en <= 1;
            mult_i1 <= qb_r;
            mult_i2 <= 64'd2;
          end
          6'd6: begin
            mult_en <= 1;
            mult_i1 <= add_r;
            mult_i2 <= usrmux_r;
          end
          6'd8: begin
            mult_en <= 1;
            mult_i1 <= add_r;
            mult_i2 <= usrmux_r;
          end
          6'd11: begin
            mult_en <= 1;
            mult_i1 <= add_r;
            mult_i2 <= qin_r;
          end
					default: begin
            mult_en <= 0;
            mult_i1 <= 0;
            mult_i2 <= 0;
          end
				endcase
			end

      layer_norm: begin
				case (state)
					6'd3: begin
						mult_en <= 1;
						mult_i1 <= varshift_r;
						mult_i2 <= varshift_r;
					end
					6'd4: begin
						mult_en <= 1;
						mult_i1 <= n_inv_r;
						mult_i2 <= rr0;
					end
					6'd5: begin
						mult_en <= 1;
						mult_i1 <= 64'd2;
						mult_i2 <= shift_r;
					end
					6'd6: begin
						mult_en <= 1;
						mult_i1 <= varshift_r;
						mult_i2 <= rr0;
					end
					6'd14: begin
						mult_en <= 1;
						mult_i1 <= div_r;
						mult_i2 <= add_r;
					end
					default: begin	
						mult_en <= 0;
						mult_i1 <= 0;
						mult_i2 <= 0;
					end
        endcase
      end   

      requant: begin
				case (state)
					6'd2: begin
						mult_en <= 1;
						mult_i1 <= add_r;
						mult_i2 <= m_r;
					end
					6'd11: begin
						mult_en <= 1;
						mult_i1 <= varshift_r;
						mult_i2 <= -64'd1;
					end
					6'd13: begin
						mult_en <= 1;
						mult_i1 <= mult_r;
						mult_i2 <= -64'd1;
					end
					6'd15: begin
						mult_en <= 1;
						mult_i1 <= add_r;
						mult_i2 <= 64'd1;
					end
					default: begin	
						mult_en <= 0;
						mult_i1 <= 0;
						mult_i2 <= 0;
					end
        endcase
      end

      softmax: begin
				case (state)
					6'd5: begin
						mult_en <= 1;
						mult_i1 <= add_r;
						mult_i2 <= qln2_inv_r;
					end
					6'd7: begin
						mult_en <= 1;
						mult_i1 <= qln2_r;
						mult_i2 <= varshift_r;
					end
					6'd10: begin
						mult_en <= 1;
						mult_i1 <= add_r;
						mult_i2 <= usrmux_r;
					end
					6'd13: begin
						mult_en <= 1;
						mult_i1 <= Sreq_r;
						mult_i2 <= varshift_r;
					end
					6'd21: begin
						mult_en <= 1;
						mult_i1 <= usrmux_r;
						mult_i2 <= 64'd1;
					end
					6'd25: begin
						mult_en <= 1;
						mult_i1 <= mult_r;
						mult_i2 <= div_r;
					end
					default: begin	
						mult_en <= 0;
						mult_i1 <= 0;
						mult_i2 <= 0;
					end
        endcase
      end 

      default: begin
        mult_en <= 0;
        mult_i1 <= 0;
        mult_i2 <= 0;
      end
    endcase
  end

  // mux varshift inputs
	localparam LEFT=0, RIGHT=1;
  always @(*) begin
    case (op_r)
			exp: begin
        case (state)
          6'd2: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= fp_bits_r;
          end
          6'd8: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= add_r;
            varshift_i2 <= varshift_r;
          end
          default: begin
            varshift_en <= 0;
            varshift_lr <= 0;
            varshift_i1 <= 0;
            varshift_i2 <= 0;
          end
        endcase
			end

			gelu: begin
				case (state)
          6'd9: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= shift_r;
          end
          default: begin
            varshift_en <= 0;
            varshift_lr <= 0;
            varshift_i1 <= 0;
            varshift_i2 <= 0;
          end
				endcase
			end

      layer_norm: begin
				case (state)
          6'd2: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= usrmux_r;
            varshift_i2 <= shift_r;
          end
					6'd5: begin
						varshift_en <= 1;
						varshift_lr <= RIGHT;
						varshift_i1 <= mult_r;
						varshift_i2 <= fp_bits_r;
					end
					6'd7: begin
						varshift_en <= 1;
						varshift_lr <= RIGHT;
						varshift_i1 <= mult_r;
						varshift_i2 <= usrmux_r;
					end
					6'd9: begin
						varshift_en <= 1;
						varshift_lr <= LEFT;
						varshift_i1 <= 64'd1;
						varshift_i2 <= max_bits_r;
					end
					6'd11: begin
						varshift_en <= 1;
						varshift_lr <= LEFT;
						varshift_i1 <= sqrt_r;
						varshift_i2 <= shift_r;
					end
					6'd15: begin
						varshift_en <= 1;
						varshift_lr <= RIGHT;
						varshift_i1 <= mult_r;
						varshift_i2 <= 64'd1;
					end
          default: begin
            varshift_en <= 0;
            varshift_lr <= 0;
            varshift_i1 <= 0;
            varshift_i2 <= 0;
          end
				endcase
      end
      
      requant: begin
				case (state)
          6'd3: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= mult_r;
            varshift_i2 <= add_r;
          end
          6'd4: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= varshift_r;
            varshift_i2 <= (INTERNAL_WIDTH-1); // constant at runtime?
          end
          6'd5: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= usrmux_r;
            varshift_i2 <= 64'd1;
          end
          6'd6: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= e_r;
          end
          6'd10: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= 64'd1;
            varshift_i2 <= add_r;
          end
          default: begin
            varshift_en <= 0;
            varshift_lr <= 0;
            varshift_i1 <= 0;
            varshift_i2 <= 0;
          end
				endcase
      end
      
      softmax: begin
        case (state)
          6'd6: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= fp_bits_r;
          end
          6'd12: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= add_r;
            varshift_i2 <= varshift_r;
          end
          6'd14: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= mult_r;
            varshift_i2 <= add_r;
          end
          6'd15: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= varshift_r; // signed shift
            varshift_i2 <= (INTERNAL_WIDTH-1); // constant at runtime?
          end
          6'd16: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= usrmux_r;
            varshift_i2 <= 64'd1;
          end
          6'd17: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= fp_bits_r;
          end
          6'd22: begin
            varshift_en <= 1;
            varshift_lr <= LEFT;
            varshift_i1 <= 64'd1;
            varshift_i2 <= max_bits_r;
          end
          6'd26: begin
            varshift_en <= 1;
            varshift_lr <= RIGHT;
            varshift_i1 <= mult_r;
            varshift_i2 <= add_r;
          end
          default: begin
            varshift_en <= 0;
            varshift_lr <= 0;
            varshift_i1 <= 0;
            varshift_i2 <= 0;
          end
        endcase
      end
      
      default: begin
        varshift_en <= 0;
        varshift_lr <= 0;
        varshift_i1 <= 0;
        varshift_i2 <= 0;
      end
    endcase
  end

  // mux user mux inputs
  always @(*) begin
    case (op_r)
			exp: begin
        case (state)
          6'd5: begin
            usrmux_en  <= 1;
            usrmux_sel <= 0;
            usrmux_i0  <= add_r;
            usrmux_i1  <= 0;
          end
          default: begin
            usrmux_en  <= 0;
            usrmux_sel <= 0;
            usrmux_i0  <= 0;
            usrmux_i1  <= 0;
          end
        endcase
			end

			gelu: begin
        case (state)
          6'd2: begin
            usrmux_en  <= 1;
            usrmux_sel <= qin_r[63]; // sign bit
            usrmux_i0  <= qin_r;
            usrmux_i1  <= mult_r;
          end
          6'd4: begin
            usrmux_en  <= 1;
            usrmux_sel <= add_r[63]; // sign bit
            usrmux_i0  <= usrmux_r;
            usrmux_i1  <= mult_r;
          end
          6'd7: begin
            usrmux_en  <= 1;
            usrmux_sel <= qin_r[63]; // sign bit
            usrmux_i0  <= 64'd1;
            usrmux_i1  <= -64'd1;
          end
          default: begin
            usrmux_en  <= 0;
            usrmux_sel <= 0;
            usrmux_i0  <= 0;
            usrmux_i1  <= 0;
          end
        endcase
			end
				
      layer_norm: begin
				case (state)
          6'd1: begin
            usrmux_en  <= 1;
            usrmux_sel <= sum_r;
            usrmux_i0  <= 0;
            usrmux_i1  <= qin_r;
          end
					6'd6: begin
						usrmux_en  <= 1;
						usrmux_sel <= 0;
						usrmux_i0  <= mult_r;
						usrmux_i1  <= 0;
					end
					6'd7: begin
						usrmux_en  <= 1;
						usrmux_sel <= 0;
						usrmux_i0  <= varshift_r;
						usrmux_i1  <= 0;
					end
					6'd11: begin
						usrmux_en  <= 1;
						usrmux_sel <= 0;
						usrmux_i0  <= varshift_r;
						usrmux_i1  <= 0;
					end
          default: begin
            usrmux_en  <= 0;
            usrmux_sel <= 0;
            usrmux_i0  <= 0;
            usrmux_i1  <= 0;
          end
        endcase
      end 
      
      requant: begin
        case (state)
          6'd4: begin
            usrmux_en  <= 1;
            usrmux_sel <= 0;
            usrmux_i0  <= varshift_r;
            usrmux_i1  <= 0;
          end
          6'd6: begin
            usrmux_en  <= 1;
            usrmux_sel <= redor_r;
            usrmux_i0  <= 64'd0;
            usrmux_i1  <= 64'd1;
          end
          6'd8: begin
            usrmux_en  <= 1;
            usrmux_sel <= redor_r;
            usrmux_i0  <= varshift_r;
            usrmux_i1  <= add_r;
          end
          6'd9: begin
            usrmux_en  <= 1;
            usrmux_sel <= varshift_r[0]; // hope this is allowed
            usrmux_i0  <= usrmux_r;
            usrmux_i1  <= add_r;
          end
          6'd13: begin
            usrmux_en  <= 1;
            usrmux_sel <= add_r[63]; // sign bit
            usrmux_i0  <= usrmux_r;
            usrmux_i1  <= mult_r;
          end
          6'd16: begin
            usrmux_en  <= 1;
            usrmux_sel <= add_r[63]; // !sign bit
            usrmux_i0  <= mult_r;
            usrmux_i1  <= usrmux_r;
          end
          default: begin
            usrmux_en  <= 0;
            usrmux_sel <= 0;
            usrmux_i0  <= 0;
            usrmux_i1  <= 0;
          end
        endcase
      end
      
      softmax: begin
        case (state)
          6'd1: begin
            usrmux_en  <= 1;
            usrmux_sel <= max_r;
            usrmux_i0  <= 0;
            usrmux_i1  <= qin_r;
          end
          6'd3: begin
            usrmux_en  <= 1;
            usrmux_sel <= add_r[63]; // sign bit
            usrmux_i0  <= qin_r;
            usrmux_i1  <= rr0;
          end
          6'd9: begin
            usrmux_en  <= 1;
            usrmux_sel <= 0;
            usrmux_i0  <= add_r;
            usrmux_i1  <= 0;
          end
          6'd15: begin
            usrmux_en  <= 1;
            usrmux_sel <= 0;
            usrmux_i0  <= varshift_r;
            usrmux_i1  <= 0;
          end
          6'd17: begin
            usrmux_en  <= 1;
            usrmux_sel <= redor_r;
            usrmux_i0  <= 64'd0;
            usrmux_i1  <= 64'd1;
          end
          6'd19: begin
            usrmux_en  <= 1;
            usrmux_sel <= redor_r;
            usrmux_i0  <= varshift_r;
            usrmux_i1  <= add_r;
          end
          6'd20: begin
            usrmux_en  <= 1;
            usrmux_sel <= varshift_r[0]; // hope this is allowed
            usrmux_i0  <= usrmux_r;
            usrmux_i1  <= add_r;
          end
          6'd21: begin
            usrmux_en  <= 1;
            usrmux_sel <= sum_r;
            usrmux_i0  <= 0;
            usrmux_i1  <= usrmux_r;
          end
          default: begin
            usrmux_en  <= 0;
            usrmux_sel <= 0;
            usrmux_i0  <= 0;
            usrmux_i1  <= 0;
          end
        endcase
      end
      
      default: begin
        usrmux_en  <= 0;
        usrmux_sel <= 0;
        usrmux_i0  <= 0;
        usrmux_i1  <= 0;
      end
    endcase
  end

	// mux reduction or inputs
	always @(*) begin
    case (op_r)
      requant: begin
        case (state)
          6'd5: begin
            redor_en = 1;
            redor_i1 = varshift_r;
          end
          6'd6: begin
            redor_en = 1;
            redor_i1 = varshift_r;
          end
          default: begin
            redor_en = 0;
            redor_i1 = 0;
          end
        endcase
      end

      softmax: begin
        case (state)
          6'd16: begin
            redor_en = 1;
            redor_i1 = varshift_r;
          end
          6'd17: begin
            redor_en = 1;
            redor_i1 = varshift_r;
          end
          default: begin
            redor_en = 0;
            redor_i1 = 0;
          end
        endcase
      end

      default: begin
        redor_en = 0;
        redor_i1 = 0;
      end
    endcase
  end

	// mux div inputs
	always @(*) begin
		case (op_r) 
			layer_norm: begin
				case (state) 
					6'd12: begin
						div_en <= 1;
						div_i1 <= usrmux_r;
						div_i2 <= varshift_r;
					end
					6'd13: begin
						div_en <= 1;
						div_i1 <= usrmux_r;
						div_i2 <= varshift_r;
					end
					default: begin
						div_en <= 0;
						div_i1 <= 0;
						div_i2 <= 0;
					end
				endcase
			end

			softmax: begin
				case (state) 
					6'd23: begin
						div_en <= 1;
						div_i1 <= varshift_r;
						div_i2 <= rr1;
					end
					6'd24: begin
						div_en <= 1;
						div_i1 <= varshift_r;
						div_i2 <= rr1;
					end
					default: begin
						div_en <= 0;
						div_i1 <= 0;
						div_i2 <= 0;
					end
				endcase
			end
			
			default: begin
				div_en <= 0;
				div_i1 <= 0;
				div_i2 <= 0;
			end
		endcase
	end

	// mux sqrt inputs
	always @(*) begin
		case (op_r) 
			layer_norm: begin
				case (state) 
					6'd9: begin
						sqrt_en <= 0;     // sqrt looks like it samples the previous cycle's input when en=1
						sqrt_i1 <= add_r;
					end
					6'd10: begin
						sqrt_en <= 1;
						sqrt_i1 <= add_r;
					end
					default: begin
						sqrt_en <= 0;
						sqrt_i1 <= 0;
					end
				endcase
			end
			
			default: begin
				sqrt_en <= 0;
				sqrt_i1 <= 0;
			end
		endcase
	end

  // functional units
  add #(
    .WIDTH(INTERNAL_WIDTH)
  )
  add_instance (
		.addsub(addsub),
    .add_i1(add_i1),
    .add_i2(add_i2),
    .add_o(add_o)
  );
  
  mult #(
    .WIDTH(INTERNAL_WIDTH)
  )
  mult_instance (
    .mult_i1(mult_i1),
    .mult_i2(mult_i2),
    .mult_o(mult_o)
  );

  varshift #(
    .WIDTH(INTERNAL_WIDTH)
  )
  varshift_instance (
    .varshift_lr(varshift_lr),
    .varshift_i1(varshift_i1),
    .varshift_i2(varshift_i2),
    .varshift_o(varshift_o)
  );

  usrmux #(
    .WIDTH(INTERNAL_WIDTH)
  )
  usrmux_instance (
    .usrmux_sel(usrmux_sel),
    .usrmux_i0(usrmux_i0),
    .usrmux_i1(usrmux_i1),
    .usrmux_o(usrmux_o)
  );

  redor #(
    .WIDTH(INTERNAL_WIDTH)
  )
  redor_instance (
    .redor_i1(redor_i1),
    .redor_o(redor_o)
  );

	div #(
    .D_W(INTERNAL_DIV_WIDTH)
	)
	div_instance (
    .clk(clk),
    .rst(rst),
    .in_valid(div_en),
		.divident(div_i1),
    .divisor(div_i2),
		.quotient(div_o),
    .out_valid(div_o_valid)
	);

	sqrt #(
    .D_W(INTERNAL_SQRTIN_WIDTH)
	)
  sqrt_instance (
		.clk(clk),
    .rst(rst),
    .in_valid(sqrt_en),
    .qin(sqrt_i1),
    .out_valid(sqrt_o_valid),
    .qout(sqrt_o)
	);

  // functional units registers
  always @(posedge clk) begin
    if (rst) begin
      add_r       <= 0;
      mult_r      <= 0;
      varshift_r  <= 0;
      usrmux_r    <= 0;  
      redor_r     <= 0;
      div_r       <= 0;
      sqrt_r      <= 0;
    end else begin
      add_r       <= add_en       ? add_o       : add_r;
      mult_r      <= mult_en      ? mult_o      : mult_r;
      varshift_r  <= varshift_en  ? varshift_o  : varshift_r;
      usrmux_r    <= usrmux_en    ? usrmux_o    : usrmux_r;  
      redor_r     <= redor_en     ? redor_o     : redor_r;
      div_r       <= div_en       ? {{WIDTH{div_o[WIDTH-1]}}, div_o} : div_r; // sizing
      sqrt_r      <= sqrt_en      ? {{(INTERNAL_SQRTOUT_WIDTH + WIDTH){1'b0}}, sqrt_o} : sqrt_r; // sizing
    end
  end

	// sum(), max() registers
	always @(posedge clk) begin
		if (rst) begin
			rr0 <= 0;
			rr1 <= 0;
		end else begin
			rr0 <= (op_r == softmax) ? ((state == 6'd3  && usrmux_en) ? usrmux_o : rr0) : // softmax
                                 ((state == 6'd2  && add_en)    ? add_o    : rr0);  // layer_norm    
			rr1 <= (op_r == softmax) ? ((state == 6'd22 && add_en)    ? add_o    : rr1) : // softmax
                                 ((state == 6'd4  && add_en)    ? add_o    : rr1);  // layer_norm    
		end
	end

  /************************* architecture *************************/

endmodule
