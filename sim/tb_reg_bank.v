`timescale 1ns / 1ps
// =============================================================================
// tb_reg_bank.v - Prueba unitaria del banco de registros
// Verifica:
//   1. Ciclo de selección de registro (sel_next) y decodificador RGB
//   2. Escritura síncrona en el registro seleccionado (write_enable)
//   3. Aislamiento y persistencia cuando write_enable = 0
//   4. Lectura simultánea de dos operandos (addr_a, addr_b)
// =============================================================================
module tb_reg_bank;

    reg        clk = 1'b0;
    reg        sel_next = 1'b0;
    reg        write_enable = 1'b0;
    reg  [3:0] wr_data = 4'd0;
    reg  [1:0] addr_a  = 2'd0;
    reg  [1:0] addr_b  = 2'd0;
    wire [3:0] data_a, data_b;
    wire [1:0] wr_addr;
    wire [2:0] rgb;

    integer errors = 0;
    integer checks = 0;
    integer i, j;
    reg [3:0] model [0:3];

    always #4 clk = ~clk;

    reg_bank uut (
        .clk(clk),
        .sel_next(sel_next),
        .write_enable(write_enable),
        .wr_data(wr_data),
        .addr_a(addr_a),
        .addr_b(addr_b),
        .data_a(data_a),
        .data_b(data_b),
        .wr_addr(wr_addr),
        .rgb(rgb)
    );

    task cycle_select;
        input [1:0] exp_addr;
        input [2:0] exp_rgb;
        begin
            @(negedge clk);
            sel_next = 1'b1;
            @(negedge clk);
            sel_next = 1'b0;
            #1;
            checks = checks + 1;
            if (wr_addr !== exp_addr || rgb !== exp_rgb) begin
                errors = errors + 1;
                $display("[FAIL] sel_next -> wr_addr=%d (exp %d), rgb=%b (exp %b)",
                         wr_addr, exp_addr, rgb, exp_rgb);
            end
        end
    endtask

    task write_current;
        input [3:0] data;
        begin
            @(negedge clk);
            wr_data = data;
            write_enable = 1'b1;
            @(negedge clk);
            write_enable = 1'b0;
            model[wr_addr] = data;
        end
    endtask

    task check_all_reads;
        begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    addr_a = i; addr_b = j; #1;
                    checks = checks + 1;
                    if (data_a !== model[i] || data_b !== model[j]) begin
                        errors = errors + 1;
                        $display("[FAIL] %0t A=R%0d(%h) B=R%0d(%h) esperado %h/%h",
                                 $time, i, data_a, j, data_b, model[i], model[j]);
                    end
                end
        end
    endtask

    initial begin
        $dumpfile("tb_reg_bank.vcd");
        $dumpvars(0, tb_reg_bank);
        for (i = 0; i < 4; i = i + 1) model[i] = 4'd0;

        #20;
        check_all_reads;                 // Valores iniciales = 0
        if (wr_addr !== 2'd0 || rgb !== 3'b100) errors = errors + 1;

        // Escribir en R0
        write_current(4'h3);

        // Pasar a R1 y escribir
        cycle_select(2'd1, 3'b010);
        write_current(4'hC);

        // Pasar a R2 y escribir
        cycle_select(2'd2, 3'b001);
        write_current(4'h5);

        // Pasar a R3 y escribir
        cycle_select(2'd3, 3'b110);
        write_current(4'hA);

        // Retornar a R0
        cycle_select(2'd0, 3'b100);

        check_all_reads;

        // Sin write_enable no debe escribir aunque cambie el dato
        @(negedge clk);
        wr_data = 4'hF;
        repeat (5) @(negedge clk);
        check_all_reads;

        // Sobrescritura en R0
        write_current(4'h9);
        check_all_reads;

        $display("RESULTADO tb_reg_bank: %0d verificaciones, %0d errores", checks, errors);
        $finish;
    end

endmodule
