`timescale 1ns / 1ps
// =============================================================================
// reg_bank.v
// -----------------------------------------------------------------------------
// Banco de 4 registros de 4 bits (R0..R3) para almacenamiento de operandos.
//   - Selección de registro destino mediante sel_next (BTN0: R0 -> R1 -> R2 -> R3).
//   - Salida rgb para el LED RGB que indica el registro seleccionado para escritura:
//       R0 = Rojo, R1 = Verde, R2 = Azul, R3 = Amarillo
//   - Escritura síncrona en el registro seleccionado al activar write_enable (BTN1).
//   - Dos puertos de lectura independientes (addr_a, addr_b) para suministrar
//     simultáneamente los operandos A y B a la ALU.
// =============================================================================
module reg_bank (
    input  wire       clk,
    input  wire       sel_next,      // Pulso para conmutar registro destino (BTN0)
    input  wire       write_enable,  // Pulso de habilitación de escritura (BTN1)
    input  wire [3:0] wr_data,       // Dato de entrada a almacenar (SW[3:0])
    input  wire [1:0] addr_a,        // Dirección de lectura del operando A
    input  wire [1:0] addr_b,        // Dirección de lectura del operando B
    output wire [3:0] data_a,        // Operando A leído
    output wire [3:0] data_b,        // Operando B leído
    output wire [1:0] wr_addr,       // Registro actualmente seleccionado (0..3)
    output wire [2:0] rgb            // Indicador {R, G, B} para LED RGB
);

    reg [1:0] reg_sel = 2'd0;
    reg [3:0] regs [0:3];

    integer i;
    initial begin
        for (i = 0; i < 4; i = i + 1)
            regs[i] = 4'b0000;
    end

    // Selección secuencial de registro destino (R0 -> R1 -> R2 -> R3 -> R0 ...)
    always @(posedge clk) begin
        if (sel_next)
            reg_sel <= reg_sel + 2'd1;
    end

    assign wr_addr = reg_sel;

    // Decodificación de color para el LED RGB
    function [2:0] rgb_lut;
        input [1:0] a;
        begin
            case (a)
                2'd0:    rgb_lut = 3'b100; // R0 -> Rojo
                2'd1:    rgb_lut = 3'b010; // R1 -> Verde
                2'd2:    rgb_lut = 3'b001; // R2 -> Azul
                default: rgb_lut = 3'b110; // R3 -> Amarillo (R+G)
            endcase
        end
    endfunction

    assign rgb = rgb_lut(reg_sel);

    // Escritura síncrona controlada por write_enable
    always @(posedge clk) begin
        if (write_enable)
            regs[reg_sel] <= wr_data;
    end

    // Lectura combinacional de los registros solicitados
    assign data_a = regs[addr_a];
    assign data_b = regs[addr_b];

    // Señales auxiliares para inspección en GTKWave
    wire [3:0] r0 = regs[0];
    wire [3:0] r1 = regs[1];
    wire [3:0] r2 = regs[2];
    wire [3:0] r3 = regs[3];

endmodule
