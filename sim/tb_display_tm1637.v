`timescale 1ns / 1ps
// =============================================================================
// tb_display_tm1637.v - Prueba unitaria del driver TM1637 con retención
// Verifica:
//   1. Retención del resultado previo hasta que llega el pulso exec (BTN3)
//   2. Formateo correcto en 7 segmentos (decimal con signo y binario)
//   3. Transmisión física serie en el bus CLK / DIO (decodificado por monitor)
// =============================================================================
module tb_display_tm1637;

    reg        clk        = 1'b0;
    reg        exec       = 1'b0;
    reg  [2:0] alu_op     = 3'd0;
    reg  [4:0] alu_result = 5'd0;
    wire       tm_clk;
    wire       tm_dio;
    wire [4:0] result_latched;
    wire [2:0] op_latched;
    wire       valid;
    wire [31:0] seg_data;

    integer errors = 0;
    integer checks = 0;

    always #4 clk = ~clk;          // 125 MHz
    pullup (tm_dio);               // Resistencia de pull-up del bus

    display_tm1637 #(.CLK_DIV(2)) uut (
        .clk(clk),
        .exec(exec),
        .alu_op(alu_op),
        .alu_result(alu_result),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio),
        .result_latched(result_latched),
        .op_latched(op_latched),
        .valid(valid),
        .seg_data(seg_data)
    );

    // ------------------------------------------------------------------
    // Monitor del protocolo TM1637
    // ------------------------------------------------------------------
    reg        in_frame = 1'b0;
    integer    bitcnt   = 0;
    integer    nbytes   = 0;
    reg  [7:0] shreg    = 8'h00;
    reg  [7:0] frame [0:7];
    integer    frames_40 = 0, frames_c0 = 0, frames_8f = 0;
    reg [31:0] bus_digits = 32'h0;

    always @(negedge tm_dio)                        // START: DIO baja con CLK alto
        if (tm_clk === 1'b1) begin
            in_frame = 1'b1; bitcnt = 0; nbytes = 0;
        end

    always @(posedge tm_clk)                        // Muestreo en flanco de subida
        if (in_frame) begin
            if (bitcnt < 8) shreg[bitcnt] = (tm_dio !== 1'b0);
            bitcnt = bitcnt + 1;
            if (bitcnt == 9) begin                  // 8 datos + ACK
                frame[nbytes] = shreg;
                nbytes = nbytes + 1;
                bitcnt = 0;
            end
        end

    always @(posedge tm_dio)                        // STOP: DIO sube con CLK alto
        if (tm_clk === 1'b1 && in_frame) begin
            in_frame = 1'b0;
            if (nbytes == 1 && frame[0] == 8'h40) frames_40 = frames_40 + 1;
            if (nbytes == 1 && frame[0] == 8'h8F) frames_8f = frames_8f + 1;
            if (nbytes == 5 && frame[0] == 8'hC0) begin
                bus_digits = {frame[1], frame[2], frame[3], frame[4]};
                frames_c0  = frames_c0 + 1;
            end
        end

    // ------------------------------------------------------------------
    // Ejecuta (pulso exec) y verifica retención y bus
    // ------------------------------------------------------------------
    task exec_and_check;
        input  [2:0] o;
        input  [4:0] r;
        input [31:0] expected;
        integer start;
        begin
            @(negedge clk);
            alu_op = o;
            alu_result = r;
            exec = 1'b1;
            @(negedge clk);
            exec = 1'b0;

            start = frames_c0;
            wait (frames_c0 >= start + 2);          // Refresco completo
            checks = checks + 1;
            if (seg_data !== expected || bus_digits !== expected) begin
                errors = errors + 1;
                $display("[FAIL] op=%b result=%b -> seg=%h bus=%h esperado=%h",
                         o, r, seg_data, bus_digits, expected);
            end else
                $display("[PASS] op=%b result=%b -> display %h", o, r, bus_digits);
        end
    endtask

    initial begin
        $dumpfile("tb_display_tm1637.vcd");
        $dumpvars(0, tb_display_tm1637);

        // Sin ejecutar previamente: debe mostrar "----"
        wait (frames_c0 >= 2);
        checks = checks + 1;
        if (bus_digits !== 32'h40404040) begin
            errors = errors + 1;
            $display("[FAIL] Estado inicial debe ser '----', obtenido %h", bus_digits);
        end else
            $display("[PASS] Estado inicial es '----'");

        //                op      result     esperado {d0,d1,d2,d3}
        exec_and_check(3'b000, 5'd0,     32'h0000003F); // "   0"
        exec_and_check(3'b000, 5'd7,     32'h00000007); // "   7"
        exec_and_check(3'b000, 5'd19,    32'h0000066F); // "  19"
        exec_and_check(3'b000, 5'd30,    32'h00004F3F); // "  30"
        exec_and_check(3'b001, 5'd5,     32'h0000006D); // "   5"
        exec_and_check(3'b001, 5'b11110, 32'h0000405B); // "  -2"
        exec_and_check(3'b001, 5'b10111, 32'h0000406F); // "  -9"
        exec_and_check(3'b001, 5'b10001, 32'h0040066D); // " -15"
        exec_and_check(3'b010, 5'b01010, 32'h063F063F); // "1010"
        exec_and_check(3'b101, 5'b00011, 32'h3F3F0606); // "0011"
        exec_and_check(3'b110, 5'b11000, 32'h063F3F3F); // "1000" (SHL)

        // Prueba de retención: cambiar alu_result y alu_op SIN exec -> no debe cambiar
        @(negedge clk);
        alu_op = 3'b000;
        alu_result = 5'd25;
        repeat (100) @(posedge clk);
        checks = checks + 1;
        if (seg_data !== 32'h063F3F3F) begin
            errors = errors + 1;
            $display("[FAIL] El valor cambió sin exec");
        end else
            $display("[PASS] Retención comprobada sin exec");

        checks = checks + 1;
        if (frames_40 == 0 || frames_8f == 0) begin
            errors = errors + 1;
            $display("[FAIL] No se observaron los comandos 0x40 / 0x8F");
        end else
            $display("[PASS] Comandos observados: 0x40 x%0d, 0xC0 x%0d, 0x8F x%0d",
                     frames_40, frames_c0, frames_8f);

        $display("RESULTADO tb_display_tm1637: %0d verificaciones, %0d errores", checks, errors);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("[FAIL] Timeout de simulacion");
        $display("RESULTADO tb_display_tm1637: %0d verificaciones, %0d errores", checks, errors + 1);
        $finish;
    end

endmodule
