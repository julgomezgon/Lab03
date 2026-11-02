// Banco de 4 registros de 4 bits (R0..R3)
// Escritura síncrona con write_enable, lectura combinacional por 2 puertos

module reg_bank (
    input  wire       clk,
    input  wire       write_enable,   // pulso de BTN1
    input  wire [1:0] addr_w,         // registro a escribir
    input  wire [3:0] data_w,         // dato (switches)
    input  wire [1:0] addr_a,         // registro leído como A
    input  wire [1:0] addr_b,         // registro leído como B
    output reg  [3:0] data_a,
    output reg  [3:0] data_b
);

    reg [3:0] r0 = 4'd0;
    reg [3:0] r1 = 4'd0;
    reg [3:0] r2 = 4'd0;
    reg [3:0] r3 = 4'd0;

    // Escritura: solo cambia el registro seleccionado
    always @(posedge clk) begin
        if (write_enable) begin
            case (addr_w)
                2'd0: r0 <= data_w;
                2'd1: r1 <= data_w;
                2'd2: r2 <= data_w;
                2'd3: r3 <= data_w;
            endcase
        end
    end

    // Lectura del operando A
    always @(*) begin
        case (addr_a)
            2'd0: data_a = r0;
            2'd1: data_a = r1;
            2'd2: data_a = r2;
            2'd3: data_a = r3;
        endcase
    end

    // Lectura del operando B
    always @(*) begin
        case (addr_b)
            2'd0: data_b = r0;
            2'd1: data_b = r1;
            2'd2: data_b = r2;
            2'd3: data_b = r3;
        endcase
    end

endmodule


// Registro seleccionado para escritura: cada pulso de BTN0 avanza R0 -> R1 -> R2 -> R3 -> R0

module sel_escritura (
    input  wire       clk,
    input  wire       siguiente,      // pulso de BTN0
    output reg  [1:0] addr_w = 2'd0
);

    always @(posedge clk) begin
        if (siguiente)
            addr_w <= addr_w + 1'b1;  // de 3 vuelve a 0 solo
    end

endmodule
