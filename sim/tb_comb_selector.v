`timescale 1ns / 1ps
// =============================================================================
// tb_comb_selector.v - Prueba unitaria del selector de combinaciones
// =============================================================================
module tb_comb_selector;

    reg        clk  = 1'b0;
    reg        next = 1'b0;
    wire [1:0] addr_a, addr_b;
    wire [3:0] active_mask;

    integer errors = 0;
    integer checks = 0;
    integer n;

    reg [1:0] exp_a [0:5];
    reg [1:0] exp_b [0:5];
    reg [3:0] exp_m [0:5];

    always #4 clk = ~clk;

    comb_selector uut (
        .clk(clk), .next(next), .addr_a(addr_a), .addr_b(addr_b), .active_mask(active_mask)
    );

    task check_comb;
        input integer k;
        begin
            #1;
            checks = checks + 1;
            if (addr_a !== exp_a[k] || addr_b !== exp_b[k] || active_mask !== exp_m[k]) begin
                errors = errors + 1;
                $display("[FAIL] paso %0d: A=R%0d B=R%0d LED=%b esperado A=R%0d B=R%0d LED=%b",
                         k, addr_a, addr_b, active_mask, exp_a[k], exp_b[k], exp_m[k]);
            end else
                $display("[PASS] combinacion %0d: A=R%0d B=R%0d LED=%b", k, addr_a, addr_b, active_mask);
        end
    endtask

    task pulse_next;
        begin
            @(negedge clk); next = 1'b1;
            @(negedge clk); next = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_comb_selector.vcd");
        $dumpvars(0, tb_comb_selector);

        exp_a[0]=0; exp_b[0]=1; exp_m[0]=4'b0011;
        exp_a[1]=0; exp_b[1]=2; exp_m[1]=4'b0101;
        exp_a[2]=0; exp_b[2]=3; exp_m[2]=4'b1001;
        exp_a[3]=1; exp_b[3]=2; exp_m[3]=4'b0110;
        exp_a[4]=1; exp_b[4]=3; exp_m[4]=4'b1010;
        exp_a[5]=2; exp_b[5]=3; exp_m[5]=4'b1100;

        #20;
        check_comb(0);
        // Dos vueltas completas para comprobar el retorno al inicio
        for (n = 1; n <= 12; n = n + 1) begin
            pulse_next;
            check_comb(n % 6);
        end

        // Sin pulso no debe avanzar
        repeat (10) @(negedge clk);
        check_comb(0);

        $display("RESULTADO tb_comb_selector: %0d verificaciones, %0d errores", checks, errors);
        $finish;
    end

endmodule
