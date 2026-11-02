// Antirrebote: entrega un pulso de 1 ciclo por cada pulsación

module antirrebote #(
    parameter LIMITE = 1_250_000      // 10 ms a 125 MHz
) (
    input  wire clk,
    input  wire btn,                  // botón físico (con rebotes)
    output reg  pulso = 1'b0          // pulso limpio
);

    reg        sync0    = 1'b0;
    reg        sync1    = 1'b0;
    reg        estable  = 1'b0;       // estado limpio del botón
    reg [20:0] contador = 21'd0;

    always @(posedge clk) begin
        // Sincronizador de 2 etapas
        sync0 <= btn;
        sync1 <= sync0;

        pulso <= 1'b0;

        // Filtro: el cambio debe durar LIMITE ciclos
        if (sync1 == estable) begin
            contador <= 21'd0;
        end else begin
            contador <= contador + 1'b1;
            if (contador == LIMITE - 1) begin
                estable  <= sync1;
                contador <= 21'd0;
                if (sync1 == 1'b1)    // solo al presionar
                    pulso <= 1'b1;
            end
        end
    end

endmodule


// Registro del resultado: se actualiza solo con BTN3 y conserva el último valor

module reg_resultado (
    input  wire       clk,
    input  wire       ejecutar,           // pulso de BTN3
    input  wire [3:0] result_in,          // salida de la ALU
    input  wire [2:0] op_in,              // operación ejecutada
    output reg  [3:0] result = 4'd0,      // resultado guardado
    output reg  [2:0] op     = 3'b000     // operación guardada (para el formato del display)
);

    always @(posedge clk) begin
        if (ejecutar) begin
            result <= result_in;
            op     <= op_in;
        end
    end

endmodule
