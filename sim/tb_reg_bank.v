`timescale 1ns/1ps

// Testbench de reg_bank.v
// sel_escritura elige el registro y reg_bank lo escribe, igual que en top.v.
// Se escriben 5, 3, 12 y 9 en R0..R3 y se leen por los dos puertos.

module tb_reg_bank;

    reg        clk = 0;
    reg        siguiente = 0;          // BTN0
    reg        write_enable = 0;       // BTN1
    reg  [3:0] data_w = 0;             // switches
    reg  [1:0] addr_a = 0, addr_b = 0;
    wire [1:0] addr_w;
    wire [3:0] data_a, data_b;

    always #4 clk = ~clk;

    sel_escritura sel (
        .clk(clk), .siguiente(siguiente), .addr_w(addr_w)
    );

    reg_bank banco (
        .clk(clk), .write_enable(write_enable),
        .addr_w(addr_w), .data_w(data_w),
        .addr_a(addr_a), .addr_b(addr_b),
        .data_a(data_a), .data_b(data_b)
    );

    // Registros internos para ver en GTKWave
    wire [3:0] R0 = banco.r0;
    wire [3:0] R1 = banco.r1;
    wire [3:0] R2 = banco.r2;
    wire [3:0] R3 = banco.r3;

    integer errores = 0;
    integer i;
    reg [3:0] valores [0:3];

    // Pulsos de un ciclo, como los del antirrebote
    task pulso_btn0;
        begin
            @(negedge clk) siguiente = 1;
            @(negedge clk) siguiente = 0;
        end
    endtask

    task pulso_btn1;
        begin
            @(negedge clk) write_enable = 1;
            @(negedge clk) write_enable = 0;
        end
    endtask

    task leer(input [1:0] a, input [1:0] b);
        begin
            addr_a = a; addr_b = b;
            #1;
            if (data_a == valores[a] && data_b == valores[b])
                $display("A=R%0d -> %2d   B=R%0d -> %2d", a, data_a, b, data_b);
            else begin
                $display("ERROR A=R%0d -> %0d   B=R%0d -> %0d", a, data_a, b, data_b);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_reg_bank.vcd");
        $dumpvars(0, tb_reg_bank);

        valores[0] = 4'd5; valores[1] = 4'd3; valores[2] = 4'd12; valores[3] = 4'd9;

        repeat (3) @(negedge clk);

        // Escritura
        $display("== escritura ==");
        for (i = 0; i < 4; i = i + 1) begin
            data_w = valores[i];
            pulso_btn1;
            $display("addr_w=%0d  dato=%2d  banco=[%0d %0d %0d %0d]", addr_w, data_w, R0, R1, R2, R3);
            pulso_btn0;
        end

        if (addr_w != 0) begin
            $display("ERROR addr_w no volvió a 0");
            errores = errores + 1;
        end

        // Sin write_enable no se escribe
        data_w = 4'd15;
        repeat (5) @(negedge clk);
        if (R0 != 5) begin
            $display("ERROR R0 cambió sin write_enable");
            errores = errores + 1;
        end

        // Lectura por los dos puertos
        $display("\n== lectura ==");
        leer(0, 1);
        leer(0, 2);
        leer(0, 3);
        leer(1, 2);
        leer(1, 3);
        leer(2, 3);

        if (errores == 0) $display("\ntb_reg_bank: PASA");
        else              $display("\ntb_reg_bank: FALLA (%0d errores)", errores);
        $finish;
    end

endmodule
