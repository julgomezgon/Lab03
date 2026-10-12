`timescale 1ns / 1ps
// =============================================================================
// display_tm1637.v
// -----------------------------------------------------------------------------
// Visualización del resultado de la ALU en display de 7 segmentos TM1637.
//
// Integra:
//   1. REGISTRO DE RETENCIÓN DE RESULTADO:
//      Al presionar BTN3 (exec), captura la operación (alu_op) y el resultado
//      de la ALU (alu_result). Mientras no vuelva a presionarse BTN3, retiene
//      y conserva el último resultado mostrado, ignorando cambios posteriores
//      en operandos, registros o switches.
//
//   2. FORMATEADOR DE DÍGITOS (combinacional):
//      - Estado inicial (sin ejecución previa): muestra "----"
//      - Suma (000) / Resta (001): representación decimal con signo alineada
//        a la derecha (ejemplos: "  15", "  -2", "  30").
//      - Operaciones lógicas y desplazamientos: representación binaria de 4
//        dígitos (ejemplo: "1010").
//
//   3. DRIVER DEL PROTOCOLO SERIE TM1637:
//      Genera las señales de reloj (CLK) y datos bidireccional (DIO open-drain)
//      para refrescar continuamente el display físico.
// =============================================================================
module display_tm1637 #(
    parameter integer CLK_DIV = 1250
)(
    input  wire        clk,
    input  wire        exec,               // Pulso para ejecutar y actualizar display (BTN3)
    input  wire [2:0]  alu_op,             // Operación seleccionada en ALU (SW[2:0])
    input  wire [4:0]  alu_result,         // Resultado instantáneo de la ALU
    output reg         tm_clk = 1'b1,      // Línea CLK para módulo TM1637
    inout  wire        tm_dio,             // Línea DIO para módulo TM1637 (open-drain)
    output wire [4:0]  result_latched,     // Último resultado retenido
    output wire [2:0]  op_latched,         // Última operación retenida
    output wire        valid,              // Indica si ya se ejecutó alguna operación
    output wire [31:0] seg_data            // Código de 7 segmentos de los 4 dígitos
);

    // -------------------------------------------------------------------------
    // 1) Registro de retención (Latching al pulsar BTN3)
    // -------------------------------------------------------------------------
    reg [4:0] reg_result = 5'd0;
    reg [2:0] reg_op     = 3'd0;
    reg       reg_valid  = 1'b0;

    always @(posedge clk) begin
        if (exec) begin
            reg_result <= alu_result;
            reg_op     <= alu_op;
            reg_valid  <= 1'b1;
        end
    end

    assign result_latched = reg_result;
    assign op_latched     = reg_op;
    assign valid          = reg_valid;

    // -------------------------------------------------------------------------
    // 2) Formateador de dígitos de 7 segmentos
    // -------------------------------------------------------------------------
    localparam [2:0] OP_ADD = 3'b000,
                     OP_SUB = 3'b001;

    localparam [7:0] SEG_BLANK = 8'h00,
                     SEG_MINUS = 8'h40;

    function [7:0] seg_digit;
        input [3:0] d;
        begin
            case (d)
                4'd0:    seg_digit = 8'h3F;
                4'd1:    seg_digit = 8'h06;
                4'd2:    seg_digit = 8'h5B;
                4'd3:    seg_digit = 8'h4F;
                4'd4:    seg_digit = 8'h66;
                4'd5:    seg_digit = 8'h6D;
                4'd6:    seg_digit = 8'h7D;
                4'd7:    seg_digit = 8'h07;
                4'd8:    seg_digit = 8'h7F;
                4'd9:    seg_digit = 8'h6F;
                default: seg_digit = SEG_BLANK;
            endcase
        end
    endfunction

    function [31:0] format_display;
        input       v;
        input [2:0] o;
        input [4:0] r;
        reg         neg;
        reg   [4:0] mag, tens, units;
        reg   [7:0] d0, d1, d2, d3;
        begin
            neg   = (o == OP_SUB) && r[4];
            mag   = neg ? (~r + 5'd1) : r;
            tens  = mag / 5'd10;
            units = mag % 5'd10;

            if (!v) begin
                d0 = SEG_MINUS; d1 = SEG_MINUS; d2 = SEG_MINUS; d3 = SEG_MINUS;
            end else if (o == OP_ADD || o == OP_SUB) begin
                d0 = SEG_BLANK;
                if (tens != 5'd0) begin
                    d1 = neg ? SEG_MINUS : SEG_BLANK;
                    d2 = seg_digit(tens[3:0]);
                end else begin
                    d1 = SEG_BLANK;
                    d2 = neg ? SEG_MINUS : SEG_BLANK;
                end
                d3 = seg_digit(units[3:0]);
            end else begin
                d0 = seg_digit({3'b000, r[3]});
                d1 = seg_digit({3'b000, r[2]});
                d2 = seg_digit({3'b000, r[1]});
                d3 = seg_digit({3'b000, r[0]});
            end
            format_display = {d0, d1, d2, d3};
        end
    endfunction

    assign seg_data = format_display(reg_valid, reg_op, reg_result);

    // -------------------------------------------------------------------------
    // 3) Driver del protocolo serie TM1637
    // -------------------------------------------------------------------------
    localparam integer CW = (CLK_DIV < 2) ? 1 : $clog2(CLK_DIV);

    reg  [CW-1:0] div_cnt = {CW{1'b0}};
    wire          tick    = (div_cnt == CLK_DIV - 1);

    always @(posedge clk)
        div_cnt <= tick ? {CW{1'b0}} : div_cnt + 1'b1;

    localparam [3:0] S_IDLE     = 4'd0,
                     S_START_A  = 4'd1,
                     S_START_B  = 4'd2,
                     S_BIT_SET  = 4'd3,
                     S_BIT_HIGH = 4'd4,
                     S_BIT_LOW  = 4'd5,
                     S_STOP_A   = 4'd6,
                     S_STOP_B   = 4'd7,
                     S_STOP_C   = 4'd8;

    reg [3:0]  state    = S_IDLE;
    reg        dio_low  = 1'b0;
    reg [1:0]  trans    = 2'd0;
    reg [2:0]  byte_idx = 3'd0;
    reg [3:0]  bit_idx  = 4'd0;
    reg [31:0] latched  = {4{SEG_MINUS}};

    assign tm_dio = dio_low ? 1'b0 : 1'bz;

    function [7:0] select_byte;
        input [1:0]  t;
        input [2:0]  b;
        input [31:0] digits;
        begin
            case (t)
                2'd0:    select_byte = 8'h40;
                2'd1: begin
                    case (b)
                        3'd0:    select_byte = 8'hC0;
                        3'd1:    select_byte = digits[31:24];
                        3'd2:    select_byte = digits[23:16];
                        3'd3:    select_byte = digits[15:8];
                        default: select_byte = digits[7:0];
                    endcase
                end
                default: select_byte = 8'h8F;
            endcase
        end
    endfunction

    wire [7:0] cur_byte  = select_byte(trans, byte_idx, latched);
    wire [2:0] last_byte = (trans == 2'd1) ? 3'd4 : 3'd0;

    always @(posedge clk) begin
        if (tick) begin
            case (state)
                S_IDLE: begin
                    tm_clk  <= 1'b1;
                    dio_low <= 1'b0;
                    if (trans == 2'd0)
                        latched <= seg_data;
                    state <= S_START_A;
                end
                S_START_A: begin
                    dio_low <= 1'b1;
                    state   <= S_START_B;
                end
                S_START_B: begin
                    tm_clk   <= 1'b0;
                    byte_idx <= 3'd0;
                    bit_idx  <= 4'd0;
                    state    <= S_BIT_SET;
                end
                S_BIT_SET: begin
                    dio_low <= (bit_idx == 4'd8) ? 1'b0 : ~cur_byte[bit_idx[2:0]];
                    state   <= S_BIT_HIGH;
                end
                S_BIT_HIGH: begin
                    tm_clk <= 1'b1;
                    state  <= S_BIT_LOW;
                end
                S_BIT_LOW: begin
                    tm_clk <= 1'b0;
                    if (bit_idx == 4'd8) begin
                        bit_idx <= 4'd0;
                        if (byte_idx == last_byte) begin
                            state <= S_STOP_A;
                        end else begin
                            byte_idx <= byte_idx + 3'd1;
                            state    <= S_BIT_SET;
                        end
                    end else begin
                        bit_idx <= bit_idx + 4'd1;
                        state   <= S_BIT_SET;
                    end
                end
                S_STOP_A: begin
                    dio_low <= 1'b1;
                    state   <= S_STOP_B;
                end
                S_STOP_B: begin
                    tm_clk <= 1'b1;
                    state  <= S_STOP_C;
                end
                S_STOP_C: begin
                    dio_low <= 1'b0;
                    trans   <= (trans == 2'd2) ? 2'd0 : trans + 2'd1;
                    state   <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
