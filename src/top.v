module top #(
    parameter DEBOUNCE = 1_250_000,   // 10 ms a 125 MHz
    parameter TM_DIV   = 625          // bus TM1637 a 50 kHz
) (
    input  wire       clk,      // reloj de 125 MHz
    input  wire [3:0] sw,       // dato (SW[3:0]) / operación (SW[2:0])
    input  wire [3:0] btn,      // BTN0 sel. registro, BTN1 escribir, BTN2 combinación, BTN3 ejecutar
    output wire [3:0] led,      // registros activos
    output wire       led6_r,   // LED RGB: registro de escritura
    output wire       led6_g,
    output wire       led6_b,
    output wire       tm_clk,   // TM1637
    inout  wire       tm_dio
);

    // Cables internos
    wire [3:0] pulso;           // pulsos limpios de los botones
    wire [1:0] addr_w;
    wire [1:0] addr_a;
    wire [1:0] addr_b;
    wire [3:0] dato_a;
    wire [3:0] dato_b;
    wire [3:0] alu_result;
    wire [3:0] res_guardado;
    wire [2:0] op_guardada;

    // Antirrebote de los 4 botones
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : ar
            antirrebote #(.LIMITE(DEBOUNCE)) ar_btn (
                .clk   (clk),
                .btn   (btn[i]),
                .pulso (pulso[i])
            );
        end
    endgenerate

    // Registro de escritura (BTN0)
    sel_escritura sel_w (
        .clk       (clk),
        .siguiente (pulso[0]),
        .addr_w    (addr_w)
    );

    // Banco de registros (BTN1 escribe)
    reg_bank banco (
        .clk          (clk),
        .write_enable (pulso[1]),
        .addr_w       (addr_w),
        .data_w       (sw),
        .addr_a       (addr_a),
        .addr_b       (addr_b),
        .data_a       (dato_a),
        .data_b       (dato_b)
    );

    // Combinación de operandos (BTN2)
    comb_selector comb (
        .clk       (clk),
        .siguiente (pulso[2]),
        .indice    (),
        .addr_a    (addr_a),
        .addr_b    (addr_b)
    );

    // ALU
    alu mi_alu (
        .A      (dato_a),
        .B      (dato_b),
        .op     (sw[2:0]),
        .result (alu_result)
    );

    // Resultado guardado (BTN3 ejecuta)
    reg_resultado res (
        .clk       (clk),
        .ejecutar  (pulso[3]),
        .result_in (alu_result),
        .op_in     (sw[2:0]),
        .result    (res_guardado),
        .op        (op_guardada)
    );

    // Display TM1637
    display_tm1637 #(.DIV(TM_DIV)) disp (
        .clk    (clk),
        .op     (op_guardada),
        .result (res_guardado),
        .tm_clk (tm_clk),
        .tm_dio (tm_dio)
    );

    // LEDs y LED RGB
    leds_operandos ind_leds (
        .addr_a (addr_a),
        .addr_b (addr_b),
        .led    (led)
    );

    rgb_registro ind_rgb (
        .addr_w (addr_w),
        .r      (led6_r),
        .g      (led6_g),
        .b      (led6_b)
    );

endmodule
