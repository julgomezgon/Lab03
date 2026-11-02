`timescale 1ns/1ps

// Testbench sencillo de la ALU: prueba las 8 operaciones con varios pares (A, B)
// y compara contra el resultado esperado.

module tb_alu;

    reg  [3:0] A, B;
    reg  [2:0] op;
    wire [3:0] result;

    alu uut (
        .A      (A),
        .B      (B),
        .op     (op),
        .result (result)
    );

    integer errores = 0;

    // Aplica una prueba y compara con el valor esperado
    task probar(input [2:0] o, input [3:0] a, input [3:0] b, input [3:0] esperado);
        begin
            op = o; A = a; B = b;
            #10;                                  // la ALU es combinacional
            if (result === esperado)
                $display("OK     op=%b  A=%b (%2d)  B=%b (%2d)  ->  %b (%2d)",
                         op, A, A, B, B, result, result);
            else begin
                $display("ERROR  op=%b  A=%b  B=%b  ->  %b  (se esperaba %b)",
                         op, A, B, result, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // 000 suma
        probar(3'b000, 4'd5,  4'd3,  4'd8);       // 5 + 3 = 8
        probar(3'b000, 4'd15, 4'd15, 4'd14);      // 30 se desborda -> 14

        // 001 resta
        probar(3'b001, 4'd5,  4'd3,  4'd2);       // 5 - 3 = 2
        probar(3'b001, 4'd3,  4'd5,  4'd14);      // -2 en 4 bits = 14

        // 010 AND
        probar(3'b010, 4'b1100, 4'b1010, 4'b1000);

        // 011 OR
        probar(3'b011, 4'b1100, 4'b1010, 4'b1110);

        // 100 XOR
        probar(3'b100, 4'b1100, 4'b1010, 4'b0110);

        // 101 XNOR
        probar(3'b101, 4'b1100, 4'b1010, 4'b1001);

        // 110 NOT A (B no importa)
        probar(3'b110, 4'b1100, 4'b1010, 4'b0011);
        probar(3'b110, 4'b1100, 4'b0000, 4'b0011);

        // 111 NAND
        probar(3'b111, 4'b1100, 4'b1010, 4'b0111);

        if (errores == 0) $display("\ntb_alu: PASA");
        else              $display("\ntb_alu: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
