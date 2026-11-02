`timescale 1ns/1ps

// Testbench sencillo del sistema completo (top.v)
// Escribe R0..R3, ejecuta algunas operaciones y revisa que el
// resultado solo cambie con BTN3.

module tb_top;                       

    localparam DEB = 8;                 // en la placa 1_250_000

    reg        clk = 0;
    reg  [3:0] sw  = 0;
    reg  [3:0] btn = 0;
    wire [3:0] led;
    wire       led6_r, led6_g, led6_b;
    wire       tm_clk;
    wire       tm_dio;

    always #4 clk = ~clk;

    pullup (tm_dio);

    top #(.DEBOUNCE(DEB), .TM_DIV(4)) dut (
        .clk(clk), .sw(sw), .btn(btn), .led(led),
        .led6_r(led6_r), .led6_g(led6_g), .led6_b(led6_b),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

    // Señales internas para GTKWave
    wire [3:0] R0 = dut.banco.r0;
    wire [3:0] R1 = dut.banco.r1;
    wire [3:0] R2 = dut.banco.r2;
    wire [3:0] R3 = dut.banco.r3;
    wire [3:0] alu_result = dut.alu_result;
    wire [3:0] resultado  = dut.res_guardado;

    // Texto que se envía al display (a partir de los segmentos)
    function [7:0] car(input [7:0] s);
        case (s)
            8'h3F: car = "0";  8'h06: car = "1";  8'h5B: car = "2";  8'h4F: car = "3";
            8'h66: car = "4";  8'h6D: car = "5";  8'h7D: car = "6";  8'h07: car = "7";
            8'h7F: car = "8";  8'h6F: car = "9";  8'h00: car = " ";
            default: car = "?";
        endcase
    endfunction

    wire [8*4-1:0] texto = {car(dut.disp.seg0), car(dut.disp.seg1),
                            car(dut.disp.seg2), car(dut.disp.seg3)};

    integer errores = 0;

    // Pulsación sin rebotes (los rebotes se prueban en tb_almacenamiento)
    task presionar(input integer b);
        begin
            @(negedge clk) btn[b] = 1;
            repeat (3*DEB) @(negedge clk);
            btn[b] = 0;
            repeat (3*DEB) @(negedge clk);
        end
    endtask

    task revisar(input [3:0] r, input [8*4-1:0] t, input [8*20-1:0] caso);
        begin
            if (resultado == r && texto == t)
                $display("%0s: resultado=%2d  display=\"%s\"", caso, resultado, texto);
            else begin
                $display("ERROR %0s: resultado=%0d display=\"%s\", se esperaba %0d \"%s\"",
                         caso, resultado, texto, r, t);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_top.vcd");             
        $dumpvars(0, tb_top);                

        repeat (5) @(negedge clk);

        // Escritura: R0=5, R1=3, R2=12, R3=9
        sw = 4'd5;  presionar(1); presionar(0);
        sw = 4'd3;  presionar(1); presionar(0);
        sw = 4'd12; presionar(1); presionar(0);
        sw = 4'd9;  presionar(1); presionar(0);
        $display("banco = [%0d %0d %0d %0d]  led=%b", R0, R1, R2, R3, led);

        if (R0 != 5 || R1 != 3 || R2 != 12 || R3 != 9) begin
            $display("ERROR en la escritura del banco");
            errores = errores + 1;
        end

        // Pareja R0, R1
        sw = 4'b0000; presionar(3);
        revisar(4'd8, "   8", "R0 + R1");

        sw = 4'b0010; presionar(3);
        revisar(4'd1, "0001", "R0 AND R1");

        // Pareja R0, R2
        presionar(2);
        sw = 4'b0100; presionar(3);
        revisar(4'd9, "1001", "R0 XOR R2");

        // Sin BTN3 el resultado no cambia
        sw = 4'b0000;
        presionar(2);                       // pasa a R0, R3
        revisar(4'd9, "1001", "sin BTN3");

        // Pareja R0, R3
        presionar(3);
        revisar(4'd14, "  14", "R0 + R3");

        sw = 4'b0001; presionar(3);
        revisar(4'd12, "  12", "R0 - R3");

        if (errores == 0) $display("\ntb_top_simple: PASA");
        else              $display("\ntb_top_simple: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
