`timescale 1ns/1ps

// Testbench del selector de combinaciones
// Se dan 6 pulsos: recorre las 6 parejas y vuelve a R0R1.

module tb_comb_selector;

    reg        clk = 0;
    reg        siguiente = 0;
    wire [2:0] indice;
    wire [1:0] addr_a, addr_b;

    always #4 clk = ~clk;

    comb_selector uut (
        .clk(clk), .siguiente(siguiente),
        .indice(indice), .addr_a(addr_a), .addr_b(addr_b)
    );

    integer i;
    integer errores = 0;

    // Pareja esperada para cada índice: {A, B}
    function [3:0] pareja(input integer n);
        case (n)
            0: pareja = {2'd0, 2'd1};
            1: pareja = {2'd0, 2'd2};
            2: pareja = {2'd0, 2'd3};
            3: pareja = {2'd1, 2'd2};
            4: pareja = {2'd1, 2'd3};
            5: pareja = {2'd2, 2'd3};
        endcase
    endfunction

    // Pulso de un ciclo, como el que entrega el antirrebote
    task pulso;
        begin
            @(negedge clk) siguiente = 1;
            @(negedge clk) siguiente = 0;
        end
    endtask

    task revisar(input integer n);
        begin
            if ({addr_a, addr_b} == pareja(n))
                $display("indice=%0d  A=R%0d  B=R%0d", indice, addr_a, addr_b);
            else begin
                $display("ERROR indice=%0d  A=R%0d  B=R%0d", indice, addr_a, addr_b);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_comb_selector.vcd");
        $dumpvars(0, tb_comb_selector);

        #20;
        revisar(0);                        // estado inicial

        for (i = 1; i <= 6; i = i + 1) begin
            pulso;
            revisar(i % 6);                // el 6.º pulso vuelve a 0
        end

        // Sin pulso no debe cambiar
        repeat (5) @(negedge clk);
        revisar(0);

        if (errores == 0) $display("\ntb_comb_selector: PASA");
        else              $display("\ntb_comb_selector: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
