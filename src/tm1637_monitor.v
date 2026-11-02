// Monitor del bus TM1637 (solo simulación)
// Escucha tm_clk / tm_dio, reconstruye los bytes y entrega los 4 dígitos
// como texto, para comprobar en el testbench lo que mostraría el display.
`timescale 1ns/1ps

module tm1637_monitor (
    input wire tm_clk,
    input wire tm_dio
);

    reg  [7:0] byte_rx  = 8'h00;
    integer    n_bit    = 0;
    integer    n_dig    = 0;
    reg        en_datos = 1'b0;

    reg  [7:0] dig [0:3];               // bytes de segmentos recibidos
    reg  [8*4-1:0] texto = "????";      // lo que se ve en el display
    integer    tramas   = 0;            // tramas completas recibidas
    integer    n_brillo = 0;            // comandos 0x8A recibidos
    integer    err_bus  = 0;            // bytes con cantidad de bits incorrecta

    // Segmentos -> carácter
    function [7:0] caracter(input [7:0] s);
        case (s)
            8'h3F: caracter = "0";  8'h06: caracter = "1";
            8'h5B: caracter = "2";  8'h4F: caracter = "3";
            8'h66: caracter = "4";  8'h6D: caracter = "5";
            8'h7D: caracter = "6";  8'h07: caracter = "7";
            8'h7F: caracter = "8";  8'h6F: caracter = "9";
            8'h00: caracter = " ";
            default: caracter = "?";
        endcase
    endfunction

    // Start: DIO baja con CLK en alto
    always @(negedge tm_dio) if (tm_clk === 1'b1) n_bit = 0;

    // Stop: DIO sube con CLK en alto. La secuencia de stop tiene su propio
    // pulso de CLK, así que aquí n_bit vale 1; cualquier otro valor indica
    // que un byte quedó cortado.
    always @(posedge tm_dio)
        if (tm_clk === 1'b1) begin
            if (n_bit > 1) err_bus = err_bus + 1;
            n_bit = 0;
        end

    // Muestreo en cada flanco de subida de CLK (LSB primero, 9.º pulso = ACK)
    always @(posedge tm_clk) begin
        if (n_bit < 8) begin
            byte_rx[n_bit] = (tm_dio === 1'b0) ? 1'b0 : 1'b1;
            n_bit = n_bit + 1;
        end else begin
            n_bit = 0;                       // pulso de ACK: byte terminado
            if (byte_rx == 8'hC0) begin
                en_datos = 1'b1;
                n_dig    = 0;
            end else if (byte_rx == 8'h8A) begin
                n_brillo = n_brillo + 1;
            end else if (en_datos) begin
                dig[n_dig] = byte_rx;
                n_dig = n_dig + 1;
                if (n_dig == 4) begin
                    en_datos = 1'b0;
                    texto  = {caracter(dig[0]), caracter(dig[1]), caracter(dig[2]), caracter(dig[3])};
                    tramas = tramas + 1;
                end
            end
        end
    end

endmodule
