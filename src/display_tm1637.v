// Display TM1637: une el formato de los dígitos con el driver del bus

module display_tm1637 #(
    parameter DIV = 625               // 5 us por fase a 125 MHz
) (
    input  wire       clk,
    input  wire [2:0] op,             // operación guardada
    input  wire [3:0] result,         // resultado guardado
    output wire       tm_clk,
    inout  wire       tm_dio
);

    wire [7:0] seg0, seg1, seg2, seg3;    // seg0 = dígito izquierdo

    formato_display formato (
        .op     (op),
        .result (result),
        .seg0   (seg0),
        .seg1   (seg1),
        .seg2   (seg2),
        .seg3   (seg3)
    );

    tm1637_driver #(.DIV(DIV)) driver (
        .clk    (clk),
        .seg0   (seg0),
        .seg1   (seg1),
        .seg2   (seg2),
        .seg3   (seg3),
        .tm_clk (tm_clk),
        .tm_dio (tm_dio)
    );

endmodule


// Formato: suma y resta en decimal (0..15), AND y OR en binario

module formato_display (
    input  wire [2:0] op,
    input  wire [3:0] result,
    output wire [7:0] seg0,
    output wire [7:0] seg1,
    output wire [7:0] seg2,
    output wire [7:0] seg3
);

    localparam APAGADO = 4'd10;       // código de dígito apagado

    wire es_aritmetica = (op == 3'b000) || (op == 3'b001);

    reg [3:0] d0, d1, d2, d3;

    always @(*) begin
        if (es_aritmetica) begin                            // decimal: "  12"
            d0 = APAGADO;
            d1 = APAGADO;
            d2 = (result >= 4'd10) ? 4'd1 : APAGADO;            // decenas
            d3 = (result >= 4'd10) ? result - 4'd10 : result;   // unidades
        end else begin                                      // binario: "1010"
            d0 = {3'b000, result[3]};
            d1 = {3'b000, result[2]};
            d2 = {3'b000, result[1]};
            d3 = {3'b000, result[0]};
        end
    end

    assign seg0 = segmentos(d0);
    assign seg1 = segmentos(d1);
    assign seg2 = segmentos(d2);
    assign seg3 = segmentos(d3);

    // Decodificador de 7 segmentos (bits: dp g f e d c b a)
    function [7:0] segmentos;
        input [3:0] codigo;
        case (codigo)
            4'd0:    segmentos = 8'h3F;
            4'd1:    segmentos = 8'h06;
            4'd2:    segmentos = 8'h5B;
            4'd3:    segmentos = 8'h4F;
            4'd4:    segmentos = 8'h66;
            4'd5:    segmentos = 8'h6D;
            4'd6:    segmentos = 8'h7D;
            4'd7:    segmentos = 8'h07;
            4'd8:    segmentos = 8'h7F;
            4'd9:    segmentos = 8'h6F;
            default: segmentos = 8'h00;   // apagado
        endcase
    endfunction

endmodule


// Driver del TM1637 (bus de 2 hilos tipo I2C)
// Trama: 0x40 | 0xC0 + 4 dígitos | 0x8A, y se repite

module tm1637_driver #(
    parameter DIV = 625
) (
    input  wire       clk,
    input  wire [7:0] seg0,
    input  wire [7:0] seg1,
    input  wire [7:0] seg2,
    input  wire [7:0] seg3,
    output reg        tm_clk = 1'b1,
    inout  wire       tm_dio
);

    // DIO de drenador abierto: 0 o alta impedancia (el pull-up da el 1)
    reg dio_bajo = 1'b0;
    assign tm_dio = dio_bajo ? 1'b0 : 1'bz;

    // Divisor: un tick cada DIV ciclos
    reg [15:0] div_cnt = 16'd0;
    wire       tick    = (div_cnt == DIV - 1);

    always @(posedge clk) begin
        if (tick)
            div_cnt <= 16'd0;
        else
            div_cnt <= div_cnt + 1'b1;
    end

    // Byte que se envía según la posición en la trama
    reg [2:0] n_byte = 3'd0;
    reg [7:0] buf0 = 8'h00, buf1 = 8'h00,     // copia de los dígitos
              buf2 = 8'h00, buf3 = 8'h00;     // al inicio de cada trama

    reg [7:0] dato;
    always @(*) begin
        case (n_byte)
            3'd0:    dato = 8'h40;    // escritura con dirección automática
            3'd1:    dato = 8'hC0;    // dirección del primer dígito
            3'd2:    dato = buf0;
            3'd3:    dato = buf1;
            3'd4:    dato = buf2;
            3'd5:    dato = buf3;
            default: dato = 8'h8A;    // display encendido, brillo medio
        endcase
    end

    // Bytes después de los que va un stop
    wire stop_despues = (n_byte == 3'd0) || (n_byte == 3'd5) || (n_byte == 3'd6);

    // Máquina de estados: cada estado tiene 4 fases de un tick
    localparam S_START = 2'd0,
               S_BIT   = 2'd1,
               S_ACK   = 2'd2,
               S_STOP  = 2'd3;

    reg [1:0] estado = S_START;
    reg [1:0] fase   = 2'd0;
    reg [2:0] n_bit  = 3'd0;

    always @(posedge clk) begin
        if (tick) begin
            fase <= fase + 1'b1;

            case (estado)
                // Start: DIO baja con CLK en 1
                S_START: case (fase)
                    2'd0: begin
                        tm_clk   <= 1'b1;
                        dio_bajo <= 1'b0;
                        if (n_byte == 3'd0) begin     // nueva trama
                            buf0 <= seg0;
                            buf1 <= seg1;
                            buf2 <= seg2;
                            buf3 <= seg3;
                        end
                    end
                    2'd1: dio_bajo <= 1'b1;
                    2'd3: begin
                        estado <= S_BIT;
                        n_bit  <= 3'd0;
                    end
                    default: ;
                endcase

                // Bit: CLK baja, se pone el dato (LSB primero), CLK sube
                S_BIT: case (fase)
                    2'd0: tm_clk   <= 1'b0;
                    2'd1: dio_bajo <= ~dato[n_bit];
                    2'd2: tm_clk   <= 1'b1;
                    2'd3: begin
                        if (n_bit == 3'd7)
                            estado <= S_ACK;
                        else
                            n_bit <= n_bit + 1'b1;
                    end
                endcase

                // ACK: se suelta DIO y el TM1637 responde
                S_ACK: case (fase)
                    2'd0: tm_clk   <= 1'b0;
                    2'd1: dio_bajo <= 1'b0;
                    2'd2: tm_clk   <= 1'b1;
                    2'd3: begin
                        if (stop_despues) begin
                            estado <= S_STOP;
                        end else begin
                            estado <= S_BIT;
                            n_bit  <= 3'd0;
                            n_byte <= n_byte + 1'b1;
                        end
                    end
                endcase

                // Stop: DIO sube con CLK en 1
                S_STOP: case (fase)
                    2'd0: tm_clk   <= 1'b0;
                    2'd1: dio_bajo <= 1'b1;
                    2'd2: tm_clk   <= 1'b1;
                    2'd3: begin
                        dio_bajo <= 1'b0;
                        estado   <= S_START;
                        n_byte   <= (n_byte == 3'd6) ? 3'd0 : n_byte + 1'b1;
                    end
                endcase
            endcase
        end
    end

endmodule
