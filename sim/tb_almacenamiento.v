`timescale 1ns/1ps

// Testbench de almacenamiento.v
// 1) antirrebote: una pulsación con rebotes debe dar un solo pulso
// 2) reg_resultado: solo cambia cuando llega el pulso de ejecutar

module tb_almacenamiento;

    localparam LIM = 8;             // en la placa es 1_250_000

    reg clk = 0;
    always #4 clk = ~clk;

    integer errores = 0;

    // ---------------- Antirrebote ----------------
    reg  btn = 0;
    wire pulso;

    antirrebote #(.LIMITE(LIM)) ar (
        .clk(clk), .btn(btn), .pulso(pulso)
    );

    integer n_pulsos = 0;
    always @(posedge clk) if (pulso) n_pulsos = n_pulsos + 1;

    // Cambia el botón y lo deja así n ciclos
    task boton(input v, input integer n);
        begin
            btn = v;
            repeat (n) @(negedge clk);
        end
    endtask

    task revisar_pulsos(input integer esperado, input [8*30-1:0] caso);
        begin
            if (n_pulsos == esperado)
                $display("%0s: %0d pulso(s)", caso, n_pulsos);
            else begin
                $display("ERROR %0s: %0d pulso(s), se esperaba %0d", caso, n_pulsos, esperado);
                errores = errores + 1;
            end
        end
    endtask

    // ---------------- Registro del resultado ----------------
    reg        ejecutar  = 0;
    reg  [3:0] result_in = 0;
    reg  [2:0] op_in     = 0;
    wire [3:0] result;
    wire [2:0] op;

    reg_resultado rr (
        .clk(clk), .ejecutar(ejecutar),
        .result_in(result_in), .op_in(op_in),
        .result(result), .op(op)
    );

    task revisar_reg(input [3:0] r, input [2:0] o, input [8*30-1:0] caso);
        begin
            if (result == r && op == o)
                $display("%0s: result=%0d op=%b", caso, result, op);
            else begin
                $display("ERROR %0s: result=%0d op=%b, se esperaba %0d %b", caso, result, op, r, o);
                errores = errores + 1;
            end
        end
    endtask

    // ---------------- Estímulos ----------------
    initial begin
        $dumpfile("tb_almacenamiento.vcd");
        $dumpvars(0, tb_almacenamiento);

        repeat (5) @(negedge clk);

        // Antirrebote
        $display("== antirrebote ==");

        boton(1, 3);                        // ruido corto, sin pulsación real
        boton(0, 3*LIM);
        revisar_pulsos(0, "ruido corto");

        boton(1, 2); boton(0, 3);           // pulsación con rebotes
        boton(1, 1); boton(0, 2);
        boton(1, 3*LIM);                    // queda presionado
        boton(0, 2); boton(1, 1);           // rebotes al soltar
        boton(0, 3*LIM);
        revisar_pulsos(1, "pulsacion con rebotes");

        boton(1, 3*LIM);                    // segunda pulsación limpia
        boton(0, 3*LIM);
        revisar_pulsos(2, "segunda pulsacion");

        // Registro del resultado
        $display("\n== reg_resultado ==");

        result_in = 4'd9; op_in = 3'b000;
        repeat (3) @(negedge clk);
        revisar_reg(0, 3'b000, "sin ejecutar");

        ejecutar = 1; @(negedge clk); ejecutar = 0;
        revisar_reg(9, 3'b000, "ejecutar");

        result_in = 4'd5; op_in = 3'b011;   // cambia la entrada
        repeat (5) @(negedge clk);
        revisar_reg(9, 3'b000, "conserva el valor");

        ejecutar = 1; @(negedge clk); ejecutar = 0;
        revisar_reg(5, 3'b011, "nueva ejecucion");

        if (errores == 0) $display("\ntb_almacenamiento: PASA");
        else              $display("\ntb_almacenamiento: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
