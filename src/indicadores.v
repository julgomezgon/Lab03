// LEDs de los registros activos: LED[i] encendido si Ri es A o B

module leds_operandos (
    input  wire [1:0] addr_a,
    input  wire [1:0] addr_b,
    output wire [3:0] led
);

    // Máscaras: un solo bit en 1 por registro
    wire [3:0] mascara_a = 4'b0001 << addr_a;
    wire [3:0] mascara_b = 4'b0001 << addr_b;

    assign led = mascara_a | mascara_b;

endmodule


// LED RGB: color del registro seleccionado para escritura
// R0 rojo, R1 verde, R2 azul, R3 amarillo

module rgb_registro (
    input  wire [1:0] addr_w,
    output reg        r,
    output reg        g,
    output reg        b
);

    always @(*) begin
        case (addr_w)
            2'd0: {r, g, b} = 3'b100;     // rojo
            2'd1: {r, g, b} = 3'b010;     // verde
            2'd2: {r, g, b} = 3'b001;     // azul
            2'd3: {r, g, b} = 3'b110;     // amarillo
        endcase
    end

endmodule
