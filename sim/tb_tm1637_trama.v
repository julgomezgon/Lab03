`timescale 1ns/1ps

// Testbench del display TM1637
// Se envían dos resultados y un modelo simple del chip lee el bus
// para verificar qué dígitos llegan.

module tb_tm1637_trama;

    reg        clk = 0;
    reg  [2:0] op;
    reg  [3:0] result;
    wire       tm_clk;
    wire       tm_dio;

    always #4 clk = ~clk;           // 125 MHz

    pullup (tm_dio);

    display_tm1637 #(.DIV(4)) dut (
        .clk(clk), .op(op), .result(result),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

    // Señales internas del driver para ver en GTKWave
    wire [7:0] byte_tx = dut.driver.dato;
    wire [2:0] n_byte  = dut.driver.n_byte;
    wire [2:0] n_bit   = dut.driver.n_bit;
    wire [1:0] estado  = dut.driver.estado;    // 0 start, 1 bit, 2 ack, 3 stop

    // ---------------- Modelo del TM1637 ----------------
    reg        ack = 0;
    assign tm_dio = ack ? 1'b0 : 1'bz;

    integer    cuenta = 0;
    integer    n_dig  = 0;
    integer    tramas = 0;
    reg  [7:0] byte_rx = 0;
    reg        datos   = 0;
    reg  [7:0] dig [0:3];
    reg  [8*4-1:0] texto = "    ";

    function [7:0] car(input [7:0] s);
        case (s)
            8'h3F: car = "0";  8'h06: car = "1";  8'h5B: car = "2";  8'h4F: car = "3";
            8'h66: car = "4";  8'h6D: car = "5";  8'h7D: car = "6";  8'h07: car = "7";
            8'h7F: car = "8";  8'h6F: car = "9";  8'h00: car = " ";
            default: car = "?";
        endcase
    endfunction

    // Start y stop: DIO cambia con CLK en alto
    always @(negedge tm_dio) if (tm_clk === 1'b1) cuenta = 0;
    always @(posedge tm_dio) if (tm_clk === 1'b1) cuenta = 0;

    // Lectura de bits (LSB primero)
    always @(posedge tm_clk) begin
        if (cuenta < 8) begin
            byte_rx[cuenta] = (tm_dio === 1'b0) ? 1'b0 : 1'b1;
            cuenta = cuenta + 1;
        end else if (cuenta == 8) begin
            cuenta = 9;
            recibir(byte_rx);
        end
    end

    // ACK en el noveno pulso
    always @(negedge tm_clk) begin
        if (cuenta == 8)
            ack <= 1'b1;
        else if (cuenta == 9) begin
            ack <= 1'b0;
            cuenta = 0;
        end
    end

    task recibir(input [7:0] b);
        begin
            $display("%8.3f us  byte = %h", $realtime / 1000.0, b);
            if (b == 8'hC0) begin
                datos = 1;
                n_dig = 0;
            end else if (datos) begin
                dig[n_dig] = b;
                n_dig = n_dig + 1;
                if (n_dig == 4) datos = 0;
            end else if (b[7:6] == 2'b10) begin
                texto  = {car(dig[0]), car(dig[1]), car(dig[2]), car(dig[3])};
                tramas = tramas + 1;
                $display("  display: \"%s\"", texto);
            end
        end
    endtask

    // ---------------- Estímulos ----------------
    initial begin
        $dumpfile("tb_tm1637_trama.vcd");
        $dumpvars(0, tb_tm1637_trama);

        op = 3'b000; result = 4'd12;       // suma
        $display("\nTrama 1: suma = 12");
        wait (tramas == 1);

        op = 3'b010; result = 4'b0101;     // AND
        $display("\nTrama 2: AND = 0101");
        wait (tramas == 2);

        #200;
        $finish;
    end

endmodule
