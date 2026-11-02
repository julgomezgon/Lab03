// Testbench unitario de la ALU: prueba exhaustiva (16 x 16 x 8 = 2048 casos)
`timescale 1ns/1ps

module tb_alu;

    reg  [3:0] A, B;
    reg  [2:0] op;
    wire [3:0] result;

    alu dut (.A(A), .B(B), .op(op), .result(result));

    reg [3:0] esperado;
    integer i, j, k, errores;

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        errores = 0;

        for (k = 0; k < 8; k = k + 1)
            for (i = 0; i < 16; i = i + 1)
                for (j = 0; j < 16; j = j + 1) begin
                    A = i; B = j; op = k;
                    #1;
                    case (op)
                        3'b000:  esperado = i + j;
                        3'b001:  esperado = i - j;
                        3'b010:  esperado = i & j;
                        3'b011:  esperado = i | j;
                        default: esperado = 4'd0;
                    endcase
                    if (result !== esperado) begin
                        errores = errores + 1;
                        $display("ERROR op=%b A=%0d B=%0d -> %0d (esperado %0d)", op, A, B, result, esperado);
                    end
                end

        if (errores == 0) $display("tb_alu: PASA (2048 casos)");
        else              $display("tb_alu: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
