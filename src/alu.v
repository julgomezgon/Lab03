// ALU de 4 bits (combinacional)
// op: 000 suma, 001 resta, 010 AND, 011 OR,
//     100 XOR, 101 XNOR, 110 NOT A, 111 NAND

module alu (
    input  wire [3:0] A,        // operando A
    input  wire [3:0] B,        // operando B
    input  wire [2:0] op,       // código de operación (SW[2:0])
    output reg  [3:0] result    // resultado
);

    always @(*) begin
        case (op)
            3'b000:  result = A + B;      // suma
            3'b001:  result = A - B;      // resta
            3'b010:  result = A & B;      // AND
            3'b011:  result = A | B;      // OR
            3'b100:  result = A ^ B;      // XOR
            3'b101:  result = ~(A ^ B);   // XNOR
            3'b110:  result = ~A;         // negador (solo usa A)
            3'b111:  result = ~(A & B);   // NAND
            default: result = 4'b0000;    // evita latches
        endcase
    end

endmodule
