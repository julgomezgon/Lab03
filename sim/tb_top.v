`timescale 1ns / 1ps
// =============================================================================
// tb_top.v - Testbench del sistema completo (Lab03)
// -----------------------------------------------------------------------------
// Verifica:
//   1. Escritura correcta en el banco de registros (BTN0 / BTN1) y LED RGB
//   2. Generación de combinaciones de operandos (BTN2) y LEDs
//   3. Funcionamiento de la ALU con las 8 operaciones en las 6 combinaciones
//   4. Actualización del resultado y del display al ejecutar (BTN3)
//   5. Conservación del último resultado mientras no se presione BTN3
//   6. Antirrebote: un botón con rebotes y mantenido genera un único pulso
// El resultado del display se comprueba tanto en el formateador como en el
// bus físico TM1637 (CLK/DIO) mediante un monitor de protocolo.
// =============================================================================
module tb_top;

    // ------------------------------------------------------------------
    // Estímulos y DUT
    // ------------------------------------------------------------------
    reg        clk = 1'b0;
    reg  [3:0] sw  = 4'd0;
    reg  [3:0] btn = 4'd0;
    wire [3:0] led;
    wire       led6_r, led6_g, led6_b;
    wire       tm_clk;
    wire       tm_dio;

    always #4 clk = ~clk;          // 125 MHz (igual que la Zybo Z7)
    pullup (tm_dio);

    top #(.DEBOUNCE_CYCLES(4), .TM_CLK_DIV(2)) uut (
        .sysclk(clk), .sw(sw), .btn(btn), .led(led),
        .led6_r(led6_r), .led6_g(led6_g), .led6_b(led6_b),
        .tm_clk(tm_clk), .tm_dio(tm_dio)
    );

    // Acceso jerárquico a señales internas (también visibles en GTKWave)
    wire [3:0]  R0       = uut.u_reg_bank.r0;
    wire [3:0]  R1       = uut.u_reg_bank.r1;
    wire [3:0]  R2       = uut.u_reg_bank.r2;
    wire [3:0]  R3       = uut.u_reg_bank.r3;
    wire [2:0]  rgb      = {led6_r, led6_g, led6_b};
    wire [1:0]  addr_a   = uut.addr_a;
    wire [1:0]  addr_b   = uut.addr_b;
    wire [4:0]  result_q = uut.result_latched;
    wire [2:0]  op_q     = uut.op_latched;
    wire [31:0] seg_data = uut.seg_data;

    // ------------------------------------------------------------------
    // Modelos de referencia
    // ------------------------------------------------------------------
    reg [3:0] regm   [0:3];        // Contenido esperado de R0..R3
    reg [1:0] comb_a [0:5];
    reg [1:0] comb_b [0:5];

    function [4:0] alu_ref;
        input [3:0] a, b;
        input [2:0] o;
        begin
            case (o)
                3'b000: alu_ref = a + b;
                3'b001: alu_ref = {1'b0, a} - {1'b0, b};
                3'b010: alu_ref = a & b;
                3'b011: alu_ref = a | b;
                3'b100: alu_ref = a ^ b;
                3'b101: alu_ref = {1'b0, ~a};
                3'b110: alu_ref = {a, 1'b0};
                default: alu_ref = a >> 1;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------
    // Monitor del bus TM1637
    // ------------------------------------------------------------------
    reg        in_frame = 1'b0;
    integer    bitcnt = 0, nbytes = 0, frames_c0 = 0;
    reg  [7:0] shreg = 8'h00;
    reg  [7:0] frame [0:7];
    reg [31:0] bus_digits = 32'h0;

    always @(negedge tm_dio)
        if (tm_clk === 1'b1) begin in_frame = 1'b1; bitcnt = 0; nbytes = 0; end

    always @(posedge tm_clk)
        if (in_frame) begin
            if (bitcnt < 8) shreg[bitcnt] = (tm_dio !== 1'b0);
            bitcnt = bitcnt + 1;
            if (bitcnt == 9) begin frame[nbytes] = shreg; nbytes = nbytes + 1; bitcnt = 0; end
        end

    always @(posedge tm_dio)
        if (tm_clk === 1'b1 && in_frame) begin
            in_frame = 1'b0;
            if (nbytes == 5 && frame[0] == 8'hC0) begin
                bus_digits = {frame[1], frame[2], frame[3], frame[4]};
                frames_c0  = frames_c0 + 1;
            end
        end

    // ------------------------------------------------------------------
    // Utilidades de verificación
    // ------------------------------------------------------------------
    integer errors = 0;
    integer checks = 0;
    integer c, o, k, idx_before;
    reg [4:0]  saved_result;
    reg [2:0]  saved_op;
    reg [31:0] saved_seg;

    task expect_val;
        input [31:0]    got;
        input [31:0]    exp;
        input [8*48-1:0] name;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("[FAIL] %8t ns  %0s: obtenido=0x%0h esperado=0x%0h", $time, name, got, exp);
            end else
                $display("[PASS] %8t ns  %0s = 0x%0h", $time, name, got);
        end
    endtask

    // Pulsación limpia de un botón
    task press;
        input integer i;
        begin
            btn[i] = 1'b1; repeat (16) @(posedge clk);
            btn[i] = 1'b0; repeat (16) @(posedge clk);
        end
    endtask

    // Espera dos refrescos completos del display
    task wait_display;
        integer start;
        begin
            start = frames_c0;
            wait (frames_c0 >= start + 2);
            @(posedge clk);
        end
    endtask

    // Ejecuta (BTN3) con la operación op y verifica el resultado retenido
    task exec_check;
        input integer cidx;
        input [2:0]   op;
        reg   [4:0]   exp;
        begin
            sw = {1'b0, op};
            press(3);
            exp = alu_ref(regm[comb_a[cidx]], regm[comb_b[cidx]], op);
            expect_val(result_q, exp, "result_q");
            expect_val(op_q, op, "op_q");
        end
    endtask

    // Ejecuta y verifica el contenido del display (formateador y bus)
    task exec_display;
        input integer cidx;
        input [2:0]   op;
        input [31:0]  exp_seg;
        begin
            exec_check(cidx, op);
            expect_val(seg_data, exp_seg, "display (formateador)");
            wait_display;
            expect_val(bus_digits, exp_seg, "display (bus TM1637)");
        end
    endtask

    // ------------------------------------------------------------------
    // Secuencia de prueba
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
        $timeformat(-9, 0, "", 8);           // %t en nanosegundos

        regm[0] = 0; regm[1] = 0; regm[2] = 0; regm[3] = 0;
        comb_a[0]=0; comb_b[0]=1;   comb_a[1]=0; comb_b[1]=2;
        comb_a[2]=0; comb_b[2]=3;   comb_a[3]=1; comb_b[3]=2;
        comb_a[4]=1; comb_b[4]=3;   comb_a[5]=2; comb_b[5]=3;

        repeat (20) @(posedge clk);

        // ============ 0. Estado inicial ============
        $display("\n=== 0. Estado inicial ===");
        expect_val(rgb, 3'b100, "RGB = R0 (rojo)");
        expect_val(led, 4'b0011, "LEDs = R0,R1");
        wait_display;
        expect_val(bus_digits, 32'h40404040, "display '----' sin ejecucion");

        // ============ 1. Escritura en el banco ============
        $display("\n=== 1. Escritura en el banco de registros ===");
        sw = 4'd3;  press(1); regm[0] = 4'd3;       // R0 = 3
        expect_val(R0, 4'd3, "R0");
        press(0);  expect_val(rgb, 3'b010, "RGB = R1 (verde)");
        sw = 4'd12; press(1); regm[1] = 4'd12;      // R1 = 12
        press(0);  expect_val(rgb, 3'b001, "RGB = R2 (azul)");
        sw = 4'd5;  press(1); regm[2] = 4'd5;       // R2 = 5
        press(0);  expect_val(rgb, 3'b110, "RGB = R3 (amarillo)");
        sw = 4'd10; press(1); regm[3] = 4'd10;      // R3 = 10
        press(0);  expect_val(rgb, 3'b100, "RGB vuelve a R0");
        expect_val(R0, 4'd3,  "R0");
        expect_val(R1, 4'd12, "R1");
        expect_val(R2, 4'd5,  "R2");
        expect_val(R3, 4'd10, "R3");

        // ============ 2. Combinaciones de operandos ============
        $display("\n=== 2. Combinaciones de operandos ===");
        for (c = 0; c < 6; c = c + 1) begin
            expect_val(addr_a, comb_a[c], "addr_a");
            expect_val(addr_b, comb_b[c], "addr_b");
            expect_val(led, (4'b0001 << comb_a[c]) | (4'b0001 << comb_b[c]), "LEDs activos");
            press(2);
        end
        expect_val(addr_a, 2'd0, "retorno addr_a = R0");
        expect_val(addr_b, 2'd1, "retorno addr_b = R1");

        // ============ 3. ALU: 8 operaciones x 6 combinaciones ============
        $display("\n=== 3. ALU: 8 operaciones en las 6 combinaciones ===");
        for (c = 0; c < 6; c = c + 1) begin
            for (o = 0; o < 8; o = o + 1)
                exec_check(c, o);
            press(2);
        end

        // ============ 4. Resultado mostrado en el display ============
        $display("\n=== 4. Resultado en el display ===");
        // Combinación 0: A = R0 = 3, B = R1 = 12
        exec_display(0, 3'b000, 32'h0000066D);  // 3 + 12  = "  15"
        exec_display(0, 3'b001, 32'h0000406F);  // 3 - 12  = "  -9"
        exec_display(0, 3'b011, 32'h06060606);  // 3 | 12  = "1111"
        press(2);                               // Combinación 1: A = 3, B = 5
        exec_display(1, 3'b001, 32'h0000405B);  // 3 - 5   = "  -2"
        exec_display(1, 3'b010, 32'h3F3F3F06);  // 3 & 5   = "0001"
        press(2); press(2); press(2);           // Combinación 4: A = 12, B = 10
        exec_display(4, 3'b000, 32'h00005B5B);  // 12 + 10 = "  22"
        exec_display(4, 3'b110, 32'h063F3F3F);  // 12 << 1 = 1_1000 -> "1000"

        // ============ 5. Conservación del resultado ============
        $display("\n=== 5. Conservacion del ultimo resultado ===");
        saved_result = result_q;
        saved_op     = op_q;
        saved_seg    = seg_data;
        for (k = 0; k < 16; k = k + 1) begin     // Se mueven todos los switches
            sw = k; repeat (4) @(posedge clk);
        end
        press(2); press(2);                      // Cambia la combinación (-> 0)
        press(0);                                // Cambia el registro destino (-> R1)
        sw = 4'd15; press(1); regm[1] = 4'd15;   // Reescribe R1 = 15
        expect_val(R1, 4'd15, "R1 reescrito");
        expect_val(result_q, saved_result, "result_q se conserva");
        expect_val(op_q,     saved_op,     "op_q se conserva");
        expect_val(seg_data, saved_seg,    "display se conserva (formateador)");
        wait_display;
        expect_val(bus_digits, saved_seg,  "display se conserva (bus TM1637)");

        // Nueva ejecución: combinación 0 -> A = R0 = 3, B = R1 = 15
        exec_display(0, 3'b000, 32'h0000067F);   // 3 + 15 = "  18"

        // ============ 6. Antirrebote ============
        $display("\n=== 6. Antirrebote (rebotes + boton mantenido) ===");
        idx_before = uut.u_comb.idx;
        for (k = 0; k < 5; k = k + 1) begin      // Rebotes de 2 ciclos
            btn[2] = 1'b1; repeat (2) @(posedge clk);
            btn[2] = 1'b0; repeat (2) @(posedge clk);
        end
        btn[2] = 1'b1; repeat (200) @(posedge clk);   // Mantenido
        btn[2] = 1'b0; repeat (30)  @(posedge clk);
        expect_val(uut.u_comb.idx, (idx_before + 1) % 6, "un solo avance de combinacion");

        $display("\nRESULTADO tb_top: %0d verificaciones, %0d errores", checks, errors);
        $finish;
    end

    initial begin
        #20_000_000;
        $display("[FAIL] Timeout de simulacion");
        $display("RESULTADO tb_top: %0d verificaciones, %0d errores", checks, errors + 1);
        $finish;
    end

endmodule
