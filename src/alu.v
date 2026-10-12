`timescale 1ns / 1ps
// =============================================================================
// alu.v
// -----------------------------------------------------------------------------
// ALU combinacional de 4 bits con 8 operaciones (selección por SW[2:0]).
// Los códigos 000-011 conservan la codificación del Lab02.
//
// La salida es de 5 bits para no perder información:
//   - ADD: bit 4 = acarreo (rango 0..30)
//   - SUB: resultado en complemento a 2 de 5 bits (rango -15..15)
//   - SHL: bit 4 = bit desplazado fuera de A
//   - Resto: bit 4 = 0
//
//   op  | Operación | result[4:0]
//   ----+-----------+-------------------------
//   000 | ADD       | A + B
//   001 | SUB       | A - B
//   010 | AND       | A & B
//   011 | OR        | A | B
//   100 | XOR       | A ^ B
//   101 | NOT A     | ~A
//   110 | SHL A     | A << 1
//   111 | SHR A     | A >> 1
// =============================================================================
module alu (
    input  wire [3:0] A,
    input  wire [3:0] B,
    input  wire [2:0] op,
    output reg  [4:0] result
);

    localparam [2:0] OP_ADD = 3'b000,
                     OP_SUB = 3'b001,
                     OP_AND = 3'b010,
                     OP_OR  = 3'b011,
                     OP_XOR = 3'b100,
                     OP_NOT = 3'b101,
                     OP_SHL = 3'b110,
                     OP_SHR = 3'b111;

    always @(*) begin
        case (op)
            OP_ADD:  result = {1'b0, A} + {1'b0, B};
            OP_SUB:  result = {1'b0, A} - {1'b0, B};
            OP_AND:  result = {1'b0, A & B};
            OP_OR:   result = {1'b0, A | B};
            OP_XOR:  result = {1'b0, A ^ B};
            OP_NOT:  result = {1'b0, ~A};
            OP_SHL:  result = {A, 1'b0};
            default: result = {2'b00, A[3:1]};   // OP_SHR
        endcase
    end

endmodule
