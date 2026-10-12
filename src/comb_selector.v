`timescale 1ns / 1ps
// =============================================================================
// comb_selector.v
// -----------------------------------------------------------------------------
// Generador de combinaciones de operandos (A, B) a partir de un índice interno.
// Cada pulso de BTN2 avanza el índice; se recorren las 6 parejas distintas:
//
//   idx | A  | B  | LEDs (R3..R0)
//   ----+----+----+--------------
//    0  | R0 | R1 | 0011
//    1  | R0 | R2 | 0101
//    2  | R0 | R3 | 1001
//    3  | R1 | R2 | 0110
//    4  | R1 | R3 | 1010
//    5  | R2 | R3 | 1100
// =============================================================================
module comb_selector (
    input  wire       clk,
    input  wire       next,          // Pulso de 1 ciclo (BTN2 filtrado)
    output wire [1:0] addr_a,        // Registro que actúa como operando A
    output wire [1:0] addr_b,        // Registro que actúa como operando B
    output wire [3:0] active_mask    // LEDs de registros activos
);

    reg [2:0] idx = 3'd0;

    always @(posedge clk) begin
        if (next)
            idx <= (idx == 3'd5) ? 3'd0 : idx + 3'd1;
    end

    // Tabla índice -> {addr_a, addr_b}
    function [3:0] comb_lut;
        input [2:0] i;
        begin
            case (i)
                3'd0:    comb_lut = {2'd0, 2'd1};
                3'd1:    comb_lut = {2'd0, 2'd2};
                3'd2:    comb_lut = {2'd0, 2'd3};
                3'd3:    comb_lut = {2'd1, 2'd2};
                3'd4:    comb_lut = {2'd1, 2'd3};
                default: comb_lut = {2'd2, 2'd3};
            endcase
        end
    endfunction

    assign {addr_a, addr_b} = comb_lut(idx);

    // Un LED por registro: se encienden los dos registros activos
    assign active_mask = (4'b0001 << addr_a) | (4'b0001 << addr_b);

endmodule
