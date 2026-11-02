// Selector de combinaciones de operandos (A, B)
// 6 parejas: R0R1, R0R2, R0R3, R1R2, R1R3, R2R3 (avanza con BTN2)

module comb_selector (
    input  wire       clk,
    input  wire       siguiente,      // pulso de BTN2
    output reg  [2:0] indice = 3'd0,  // combinación actual (0..5)
    output reg  [1:0] addr_a,         // registro usado como A
    output reg  [1:0] addr_b          // registro usado como B
);

    // Contador módulo 6
    always @(posedge clk) begin
        if (siguiente) begin
            if (indice == 3'd5)
                indice <= 3'd0;
            else
                indice <= indice + 1'b1;
        end
    end

    // Índice -> pareja de registros
    always @(*) begin
        case (indice)
            3'd0:    begin addr_a = 2'd0; addr_b = 2'd1; end
            3'd1:    begin addr_a = 2'd0; addr_b = 2'd2; end
            3'd2:    begin addr_a = 2'd0; addr_b = 2'd3; end
            3'd3:    begin addr_a = 2'd1; addr_b = 2'd2; end
            3'd4:    begin addr_a = 2'd1; addr_b = 2'd3; end
            3'd5:    begin addr_a = 2'd2; addr_b = 2'd3; end
            default: begin addr_a = 2'd0; addr_b = 2'd1; end   // evita latches
        endcase
    end

endmodule
