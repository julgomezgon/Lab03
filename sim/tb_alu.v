`timescale 1ns / 1ps
// =============================================================================
// tb_alu.v - Prueba unitaria de la ALU
// Barrido exhaustivo: 16 x 16 x 8 = 2048 combinaciones contra un modelo de
// referencia, más casos dirigidos legibles en GTKWave.
// =============================================================================
module tb_alu;

    reg  [3:0] A;
    reg  [3:0] B;
    reg  [2:0] op;
    wire [4:0] result;

    integer errors = 0;
    integer checks = 0;
    integer ia, ib, iop;

    alu uut (.A(A), .B(B), .op(op), .result(result));

    // Modelo de referencia
    function [4:0] alu_ref;
        input [3:0] a, b;
        input [2:0] o;
        begin
            case (o)
                3'b000: alu_ref = a + b;
                3'b001: alu_ref = {1'b0, a} - {1'b0, b};
                3'b010: alu_ref = a & b;
                3'b011: alu_ref = a | b;
                3'b100: alu_ref = a ^ b;
                3'b101: alu_ref = {1'b0, ~a};
                3'b110: alu_ref = {a, 1'b0};
                default: alu_ref = a >> 1;
            endcase
        end
    endfunction

    task check_case;
        input [4:0] expected;
        begin
            #1;
            checks = checks + 1;
            if (result !== expected) begin
                errors = errors + 1;
                $display("[FAIL] op=%b A=%b B=%b -> result=%b esperado=%b",
                         op, A, B, result, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // ---------------- Casos dirigidos (10 ns cada uno) ----------------
        A = 4'd3;  B = 4'd4;  op = 3'b000; check_case(5'd7);       #9; // 3+4
        A = 4'd15; B = 4'd15; op = 3'b000; check_case(5'd30);      #9; // acarreo
        A = 4'd12; B = 4'd7;  op = 3'b000; check_case(5'd19);      #9; // 19 (Lab02 daba 3)
        A = 4'd9;  B = 4'd4;  op = 3'b001; check_case(5'd5);       #9; // 9-4
        A = 4'd3;  B = 4'd5;  op = 3'b001; check_case(5'b11110);   #9; // -2
        A = 4'd0;  B = 4'd15; op = 3'b001; check_case(5'b10001);   #9; // -15
        A = 4'b1100; B = 4'b1010; op = 3'b010; check_case(5'b01000); #9; // AND
        A = 4'b1100; B = 4'b1010; op = 3'b011; check_case(5'b01110); #9; // OR
        A = 4'b1100; B = 4'b1010; op = 3'b100; check_case(5'b00110); #9; // XOR
        A = 4'b1100; B = 4'b1010; op = 3'b101; check_case(5'b00011); #9; // NOT A
        A = 4'b1101; B = 4'b0000; op = 3'b110; check_case(5'b11010); #9; // SHL
        A = 4'b1101; B = 4'b0000; op = 3'b111; check_case(5'b00110); #9; // SHR

        // ---------------- Barrido exhaustivo ----------------
        for (iop = 0; iop < 8; iop = iop + 1)
            for (ia = 0; ia < 16; ia = ia + 1)
                for (ib = 0; ib < 16; ib = ib + 1) begin
                    op = iop; A = ia; B = ib;
                    check_case(alu_ref(A, B, op));
                end

        $display("RESULTADO tb_alu: %0d verificaciones, %0d errores", checks, errors);
        $finish;
    end

endmodule
