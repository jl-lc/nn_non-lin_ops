module non_lin_ops #(
  parameter WIDTH=32
) (
  input wire              clock, reset,
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
  output reg [WIDTH-1:0]  qout      // int32, output, integer approximation of exp
);

  // TODO:
  // is varshift shift right always arithmetic shift right
  // the rest of the ops

  
  /************************* internal signals *************************/

  // ops
  parameter exp=3'd0, gelu=3'd1, layer_norm=3'd2, requant=3'd3, softmax=3'd4;

  reg [5:0] state, next; // support 44 cycles

  parameter INTERNAL_WIDTH = WIDTH*2; // all internal signals are int64

  // sign-extend 64bits        
  wire signed [INTERNAL_WIDTH-1:0] qin_r; 
  wire signed [INTERNAL_WIDTH-1:0] qb_r;          
  wire signed [INTERNAL_WIDTH-1:0] qc_r;          
  wire signed [INTERNAL_WIDTH-1:0] qln2_r;          
  wire signed [INTERNAL_WIDTH-1:0] qln2_inv_r;          
  wire signed [INTERNAL_WIDTH-1:0] fp_bits_r;         
  wire signed [INTERNAL_WIDTH-1:0] q1_r;          
  wire signed [INTERNAL_WIDTH-1:0] shift_r;         
  wire signed [INTERNAL_WIDTH-1:0] bias_r;          
  wire signed [INTERNAL_WIDTH-1:0] n_inv_r;         
  wire signed [INTERNAL_WIDTH-1:0] max_bits_r;            
  wire signed [INTERNAL_WIDTH-1:0] m_r;         
  wire signed [INTERNAL_WIDTH-1:0] out_bits_r;          
  wire signed [INTERNAL_WIDTH-1:0] Sreq_r;          
  wire signed [INTERNAL_WIDTH-1:0] e_r;         

  // muxed inputs to functional units
  reg signed [INTERNAL_WIDTH-1:0] add_i1, add_i2;
  reg signed [INTERNAL_WIDTH-1:0] mult_i1, mult_i2;
  reg                             varshift_lr;
  reg signed [INTERNAL_WIDTH-1:0] varshift_i1, varshift_i2;
  reg                             usrmux_sel;
  reg signed [INTERNAL_WIDTH-1:0] usrmux_i1, usrmux_i2;
  reg signed [INTERNAL_WIDTH-1:0] redor_i1;
  reg signed [INTERNAL_WIDTH-1:0] div_i1, div_i2;
  reg signed [INTERNAL_WIDTH-1:0] sqrt_i1;

  // outputs from functional units
  reg signed [INTERNAL_WIDTH-1:0] add_o;
  reg signed [INTERNAL_WIDTH-1:0] mult_o;
  reg signed [INTERNAL_WIDTH-1:0] varshift_o;
  reg signed [INTERNAL_WIDTH-1:0] usrmux_o;
  reg signed [INTERNAL_WIDTH-1:0] redor_o;
  reg signed [INTERNAL_WIDTH-1:0] div_o;
  reg signed [INTERNAL_WIDTH-1:0] sqrt_o;

  // registered outputs
  reg signed [INTERNAL_WIDTH-1:0] add_r;
  reg signed [INTERNAL_WIDTH-1:0] mult_r;
  reg signed [INTERNAL_WIDTH-1:0] varshift_r;
  reg signed [INTERNAL_WIDTH-1:0] usrmux_r;
  reg signed [INTERNAL_WIDTH-1:0] redor_r;
  reg signed [INTERNAL_WIDTH-1:0] div_r;
  reg signed [INTERNAL_WIDTH-1:0] sqrt_r;

  // register enable/disable
  wire mult_en;
  wire add_en;
  wire varshift_en;
  wire usrmux_en;
  wire redor_en;
  wire div_en;
  wire sqrt_en;

  // sum(), max() regs
  reg [INTERNAL_WIDTH-1] rr0_reg, rr1_reg;

  /************************* internal signals *************************/



  /************************* architecture *************************/

  // sign-extend 64 bits           
  assign qin_r      = {WIDTH{qin[WIDTH-1]},       qin}; 
  assign qb_r       = {WIDTH{qb[WIDTH-1]},        qb};               
  assign qc_r       = {WIDTH{qc[WIDTH-1]},        qc};              
  assign qln2_r     = {WIDTH{qln2[WIDTH-1]},      qln2};                  
  assign qln2_inv_r = {WIDTH{qln2_inv[WIDTH-1]},  qln2_inv};                              
  assign fp_bits_r  = {WIDTH{fp_bits[WIDTH-1]},   fp_bits};                     
  assign q1_r       = {WIDTH{q1[WIDTH-1]},        q1};              
  assign shift_r    = {WIDTH{shift[WIDTH-1]},     shift};                 
  assign bias_r     = {WIDTH{bias[WIDTH-1]},      bias};                  
  assign n_inv_r    = {WIDTH{n_inv[WIDTH-1]},     n_inv};                 
  assign max_bits_r = {WIDTH{max_bits[WIDTH-1]},  max_bits};                            
  assign m_r        = {WIDTH{m[WIDTH-1]},         m};         
  assign out_bits_r = {WIDTH{out_bits[WIDTH-1]},  out_bits};                          
  assign Sreq_r     = {WIDTH{Sreq[WIDTH-1]},      Sreq};                  
  assign e_r        = {24{e[24-1]},               e};         

  // state transition logic
  always @(*) begin
    case (op)
      exp:
        case (state)
          6'd0:    next = 6'd1;
          6'd1:    next = 6'd2;
          6'd2:    next = 6'd3;
          6'd3:    next = 6'd4;
          6'd4:    next = 6'd5;
          6'd5:    next = 6'd6;
          6'd6:    next = 6'd7;
          6'd7:    next = 6'd8;
          6'd8:    next = 6'd0; // for output, if expect back to back operations, need modify
          default: next = 6'd0;
        endcase
      gelu:

      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: 
      
    endcase
  end

  // state ff
  always @(posedge clock) 
    state <= reset ? 6'd0 : next;

  // output logic
  always @(*) begin
    case (op)
      exp:
        qout = (state == 6'd8) ? varshift_r : 0;
      gelu: 
      
      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: 
        qout = 0;
    endcase
  end
  
  // mux add inputs
  always @(*) begin
    case (op)
      exp:
        case (state)
          6'd3: begin
            add_en = 1;
            add_i1 = qin_r;
            add_i2 = mult_r;
          end
          6'd4: begin
            add_en = 1;
            add_i1 = qb_r;
            add_i2 = add_r;
          end
          6'd6: begin
            add_en = 1;
            add_i1 = qc_r;
            add_i2 = mult_r;
          end
          default: begin
            add_en = 0;
            add_i1 = 0;
            add_i2 = 0;
          end
        endcase
      gelu:

      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: begin
        add_en = 0;
        add_i1 = 0;
        add_i2 = 0;
      end
    endcase
  end
  
  // mux mult inputs
  always @(*) begin
    case (op)
      exp:
        case (state)
          6'd0: begin
            mult_en = 1;
            mult_i1 = qin_r;
            mult_i2 = qln2_inv_r;
          end
          6'd2: begin
            mult_en = 1;
            mult_i1 = qln2_r;
            mult_i2 = varshift_r;
          end
          6'd5: begin
            mult_en = 1;
            mult_i1 = add_r;
            mult_i2 = usrmux_r;
          end
          default: begin
            mult_en = 0;
            mult_i1 = 0;
            mult_i2 = 0;
          end
        endcase
      gelu:

      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: begin
        mult_en = 0;
        mult_i1 = 0;
        mult_i2 = 0;
      end
    endcase
  end

  // mux varshift inputs
  always @(*) begin
    case (op)
      exp:
        case (state)
          6'd1: begin
            varshift_en = 1;
            varshift_lr = 1;
            varshift_i1 = mult_r;
            varshift_i2 = INTERNAL_WIDTH'd30; // sus
          end
          6'd7: begin
            varshift_en = 1;
            varshift_lr = 1;
            varshift_i1 = add_r;
            varshift_i2 = varshift_r;
          end
          default: begin
            varshift_en = 0;
            varshift_lr = 0;
            varshift_i1 = 0;
            varshift_i2 = 0;
          end
        endcase
      gelu:

      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: begin
        varshift_en = 0;
        varshift_lr = 0;
        varshift_i1 = 0;
        varshift_i2 = 0;
      end
    endcase
  end

  // mux user mux inputs
  always @(*) begin
    case (op)
      exp:
        usrmux_en  = 1;
        usrmux_sel = 0;
        usrmux_i1  = add_r;
        usrmux_i2  = 0;
      gelu:

      layer_norm: 
      
      requant: 
      
      softmax: 
      
      default: begin
        usrmux_en  = 0;
        usrmux_sel = 0;
        usrmux_i1  = 0;
        usrmux_i2  = 0;
      end
    endcase
  end

  // functional units
  add #(
    .WIDTH(INTERNAL_WIDTH)
  )
  add_instance (
    .add_i1(add_i1),
    .add_i2(add_i2),
    .add_o(add_o),
  );
  
  mult #(
    .WIDTH(INTERNAL_WIDTH)
  )
  mult_instance (
    .mult_i1(mult_i1),
    .mult_i2(mult_i2),
    .mult_o(mult_o),
  );

  varshift #(
    .WIDTH(INTERNAL_WIDTH)
  )
  varshift_instance (
    .varshift_lr(varshift_lr),
    .varshift_i1(varshift_i1),
    .varshift_i2(varshift_i2),
    .varshift_o(varshift_o),
  );

  usrmux #(
    .WIDTH(INTERNAL_WIDTH)
  )
  usrmux_instance (
    .usrmux_lr(usrmux_sel),
    .usrmux_i1(usrmux_i1),
    .usrmux_i2(usrmux_i2),
    .usrmux_o(usrmux_o),
  );

  // functional units registers
  always @(posedge clock) begin
    if (reset) begin
      add_r       <= 0;
      mult_r      <= 0;
      varshift_r  <= 0;
      usrmux_r    <= 0;  
      redor_r     <= 0;
      div_r       <= 0;
      sqrt_r      <= 0;
    end
    else begin
      add_r       <= add_en       ? add_o       : add_r;
      mult_r      <= mult_en      ? mult_o      : mult_r;
      varshift_r  <= varshift_en  ? varshift_o  : varshift_r;
      usrmux_r    <= usrmux_en    ? usrmux_o    : usrmux_r;  
      redor_r     <= redor_en     ? redor_o     : redor_r;
      div_r       <= div_en       ? div_o       : div_r;
      sqrt_r      <= sqrt_en      ? sqrt_o      : sqrt_r;
    end
  end

  /************************* architecture *************************/

endmodule