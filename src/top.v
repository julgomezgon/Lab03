`timescale 1ns / 1ps
// =============================================================================
// top.v
// -----------------------------------------------------------------------------
// Módulo de nivel superior (Top-level) del sistema digital modular.
// Integra los 4 módulos funcionales principales descritos en la guía:
//   - reg_bank.v        (Banco de registros + control de escritura + LED RGB)
//   - comb_selector.v   (Selector de combinaciones de operandos + LEDs)
//   - alu.v             (Unidad aritmético-lógica de 4 bits / 8 operaciones)
//   - display_tm1637.v  (Retención del resultado + formateo + controlador TM1637)
//
// Mapeo físico en Zybo Z7:
//   SW[3:0] : Dato de entrada para escritura en registros
//   SW[2:0] : Operación seleccionada de la ALU
//   BTN0    : Cambiar registro de escritura (R0 -> R1 -> R2 -> R3)
//   BTN1    : Escribir dato actual en el registro seleccionado
//   BTN2    : Cambiar combinación de operandos (A, B)
//   BTN3    : Ejecutar operación ALU y actualizar el resultado en el display
//   LED[3:0]: Registros activos en la operación actual
//   LED RGB : Registro seleccionado actualmente para escritura
//   TM1637  : Muestra el resultado de la última operación ejecutada
// =============================================================================
module top #(
    parameter integer DEBOUNCE_CYCLES = 2_500_000,  // 20 ms @ 125 MHz (en simulación se reduce)
    parameter integer TM_CLK_DIV      = 1250        // Divisor reloj serie TM1637
)(
    input  wire       sysclk,
    input  wire [3:0] sw,
    input  wire [3:0] btn,
    output wire [3:0] led,
    output wire       led6_r,
    output wire       led6_g,
    output wire       led6_b,
    output wire       tm_clk,
    inout  wire       tm_dio
);

    // -------------------------------------------------------------------------
    // Señales de pulsos de botones (filtrados por antirrebote)
    // -------------------------------------------------------------------------
    wire [3:0] btn_pulse;

    genvar k;
    generate
        for (k = 0; k < 4; k = k + 1) begin : g_btn
            btn_debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_db (
                .clk       (sysclk),
                .btn_in    (btn[k]),
                .pulse     (btn_pulse[k])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Interconexiones del Datapath
    // -------------------------------------------------------------------------
    wire [1:0]  addr_a, addr_b;
    wire [3:0]  data_a, data_b;
    wire [4:0]  alu_result;
    wire [2:0]  rgb;
    wire [1:0]  wr_addr;
    wire [4:0]  result_latched;
    wire [2:0]  op_latched;
    wire        valid;
    wire [31:0] seg_data;

    // -------------------------------------------------------------------------
    // 1. Selector de Combinaciones de Operandos (comb_selector.v)
    // -------------------------------------------------------------------------
    comb_selector u_comb (
        .clk         (sysclk),
        .next        (btn_pulse[2]),  // BTN2 conmuta la pareja (A, B)
        .addr_a      (addr_a),
        .addr_b      (addr_b),
        .active_mask (led)            // LEDs[3:0] indican registros activos
    );

    // -------------------------------------------------------------------------
    // 2. Banco de Registros (reg_bank.v)
    // -------------------------------------------------------------------------
    reg_bank u_reg_bank (
        .clk          (sysclk),
        .sel_next     (btn_pulse[0]), // BTN0 selecciona registro de escritura
        .write_enable (btn_pulse[1]), // BTN1 escribe dato en registro
        .wr_data      (sw),           // SW[3:0] dato de entrada
        .addr_a       (addr_a),
        .addr_b       (addr_b),
        .data_a       (data_a),
        .data_b       (data_b),
        .wr_addr      (wr_addr),
        .rgb          (rgb)           // LED RGB indica registro seleccionado
    );

    // -------------------------------------------------------------------------
    // 3. Unidad Aritmético-Lógica (alu.v)
    // -------------------------------------------------------------------------
    alu u_alu (
        .A      (data_a),
        .B      (data_b),
        .op     (sw[2:0]),            // SW[2:0] selecciona la operación
        .result (alu_result)
    );

    // -------------------------------------------------------------------------
    // 4. Módulo de Visualización y Retención (display_tm1637.v)
    // -------------------------------------------------------------------------
    display_tm1637 #(.CLK_DIV(TM_CLK_DIV)) u_display (
        .clk            (sysclk),
        .exec           (btn_pulse[3]),  // BTN3 ejecuta y captura resultado
        .alu_op         (sw[2:0]),
        .alu_result     (alu_result),
        .tm_clk         (tm_clk),
        .tm_dio         (tm_dio),
        .result_latched (result_latched),
        .op_latched     (op_latched),
        .valid          (valid),
        .seg_data       (seg_data)
    );

    // -------------------------------------------------------------------------
    // Salidas físicas del LED RGB
    // -------------------------------------------------------------------------
    assign led6_r = rgb[2];
    assign led6_g = rgb[1];
    assign led6_b = rgb[0];

endmodule

// =============================================================================
// Módulo auxiliar de acondicionamiento de pulsador (Antirrebote + Detector de flanco)
// =============================================================================
module btn_debounce #(
    parameter integer DEBOUNCE_CYCLES = 2_500_000
)(
    input  wire clk,
    input  wire btn_in,
    output reg  pulse = 1'b0
);
    localparam integer CW = (DEBOUNCE_CYCLES < 2) ? 1 : $clog2(DEBOUNCE_CYCLES);

    reg          sync0 = 1'b0;
    reg          sync1 = 1'b0;
    reg          btn_level = 1'b0;
    reg [CW-1:0] cnt   = {CW{1'b0}};

    always @(posedge clk) begin
        sync0 <= btn_in;
        sync1 <= sync0;
        pulse <= 1'b0;

        if (sync1 == btn_level) begin
            cnt <= {CW{1'b0}};
        end else if (cnt == DEBOUNCE_CYCLES - 1) begin
            cnt       <= {CW{1'b0}};
            btn_level <= sync1;
            if (sync1)
                pulse <= 1'b1;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule
