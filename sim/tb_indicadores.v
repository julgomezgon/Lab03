`timescale 1ns/1ps

// Testbench de indicadores.v
// 1) leds_operandos: las 6 parejas de registros
// 2) rgb_registro: el color de cada registro de escritura

module tb_indicadores;

    integer errores = 0;
    integer i;

    // ---------------- LEDs de operandos ----------------
    reg  [1:0] addr_a, addr_b;
    wire [3:0] led;

    leds_operandos uled (
        .addr_a(addr_a), .addr_b(addr_b), .led(led)
    );

    task probar_leds(input [1:0] a, input [1:0] b, input [3:0] esperado);
        begin
            addr_a = a; addr_b = b;
            #10;
            if (led == esperado)
                $display("R%0d R%0d -> led=%b", a, b, led);
            else begin
                $display("ERROR R%0d R%0d -> led=%b, se esperaba %b", a, b, led, esperado);
                errores = errores + 1;
            end
        end
    endtask

    // ---------------- LED RGB ----------------
    reg  [1:0] addr_w;
    wire       r, g, b;

    rgb_registro urgb (
        .addr_w(addr_w), .r(r), .g(g), .b(b)
    );

    function [2:0] color(input [1:0] n);
        case (n)
            2'd0: color = 3'b100;           // rojo
            2'd1: color = 3'b010;           // verde
            2'd2: color = 3'b001;           // azul
            2'd3: color = 3'b110;           // amarillo
        endcase
    endfunction

    // ---------------- Estímulos ----------------
    initial begin
        $dumpfile("tb_indicadores.vcd");
        $dumpvars(0, tb_indicadores);

        $display("== leds_operandos ==");
        probar_leds(0, 1, 4'b0011);
        probar_leds(0, 2, 4'b0101);
        probar_leds(0, 3, 4'b1001);
        probar_leds(1, 2, 4'b0110);
        probar_leds(1, 3, 4'b1010);
        probar_leds(2, 3, 4'b1100);

        $display("\n== rgb_registro ==");
        for (i = 0; i < 4; i = i + 1) begin
            addr_w = i;
            #10;
            if ({r, g, b} == color(i))
                $display("R%0d -> rgb=%b%b%b", i, r, g, b);
            else begin
                $display("ERROR R%0d -> rgb=%b%b%b, se esperaba %b", i, r, g, b, color(i));
                errores = errores + 1;
            end
        end

        if (errores == 0) $display("\ntb_indicadores: PASA");
        else              $display("\ntb_indicadores: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
