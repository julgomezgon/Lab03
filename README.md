# Lab03 – ALU + Banco de Registros + Diseño Modular

## Integrantes

- Julian David Gomez Gonzalez - 1007544331
- Cristian Norbey Hernández Gualteros - 1001091723
- Milton Nicolas Rincón Caicedo - 1021312724

**Semestre:** 2026-2
**Plataforma:** Digilent Zybo Z7-10 (Zynq-7000)

---

## Índice

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Arquitectura modular](#2-arquitectura-modular)
3. [Interfaz de usuario](#3-interfaz-de-usuario)
4. [Estrategia de visualización](#4-estrategia-de-visualización)
5. [Simulación](#5-simulación)
6. [Implementación en FPGA](#6-implementación-en-fpga)
7. [Evidencia de funcionamiento en FPGA](#7-evidencia-de-funcionamiento-en-fpga)
8. [Análisis de resultados](#8-análisis-de-resultados)
9. [Conclusiones](#9-conclusiones)

---

## 1. Descripción del sistema

Se diseñó e implementó un sistema digital de 4 bits sobre la tarjeta Zybo Z7. El sistema permite guardar datos en un banco de cuatro registros, escoger dos de ellos como operandos, operarlos con una unidad aritmético-lógica (ALU) y mostrar el resultado en un display de 7 segmentos controlado por el circuito integrado TM1637.

El sistema se construyó por módulos, donde cada bloque cumple una función concreta, como almacenar datos, seleccionar operandos, calcular o mostrar el resultado, y se prueba por separado antes de integrarlo con los demás en el archivo `top.v`, que se limita a conectar los módulos entre sí y con los pines de la tarjeta. Esta forma de trabajo nos permite reutilizar bloques y hace que el diseño sea más fácil de entender y de ampliar. Además, el display que será implementado, va a conservar el resultado de la última operación hasta que se presione BTN3, aunque después cambien los operandos, la combinación de registros o la operación seleccionada. Por esta razón el diseño incluye un registro que guarda el resultado en el momento de la ejecución y lo mantiene mientras no se ejecute una nueva operación.


## 2. Descripción del sistema

### 2.1 Funcionamiento general

El sistema trabaja con datos de 4 bits y se controla con los cuatro switches y los cuatro botones de la Zybo Z7. Con ellos se guardan valores en cuatro registros (R0 a R3), se elige la pareja de registros que se va a operar, se selecciona la operación y se ejecuta. El resultado aparece en un display de cuatro dígitos conectado a la tarjeta.

La tarjeta también indica el estado del sistema. El LED RGB muestra con un color qué registro está seleccionado para escritura, y los LEDs LD0 a LD3 señalan cuáles registros forman la pareja de operandos activa.

### 2.2 Requisitos de funcionamiento

- Cada registro guarda un valor de 4 bits que se carga desde los switches y se conserva hasta que se vuelva a escribir.
- Los operandos A y B se toman de una de las seis parejas posibles de registros, y cada pulsación de BTN2 avanza a la siguiente pareja.
- La ALU realiza la operación indicada en SW[2:0] sobre los operandos de la pareja activa.
- El resultado se guarda al presionar BTN3 y el display lo mantiene hasta la siguiente ejecución, aunque cambien los operandos, la pareja de registros o la operación seleccionada.
- Cada pulsación de un botón produce una sola acción, sin importar los rebotes mecánicos del pulsador.

### 2.3 Controles e indicadores

El sistema se maneja con los switches y botones de la Zybo Z7, y su estado se observa en los LEDs y el display. La siguiente tabla resume la función que cumple cada uno de estos elementos dentro del diseño.

| Elemento | Función |
|---|---|
| SW[3:0] | Dato que se escribe en un registro |
| SW[2:0] | Código de la operación |
| BTN0 | Cambia el registro de escritura (R0 → R1 → R2 → R3) |
| BTN1 | Escribe el dato en el registro seleccionado |
| BTN2 | Cambia la pareja de operandos |
| BTN3 | Ejecuta la operación y actualiza el display |
| LD0 a LD3 | Indican los registros de la pareja activa |
| LED RGB | Indica el registro de escritura (R0 rojo, R1 verde, R2 azul, R3 amarillo) |
| Display | Muestra el resultado de la última operación |

Las parejas de operandos se recorren en el orden R0-R1, R0-R2, R0-R3, R1-R2, R1-R3 y R2-R3.

### 2.4 Operaciones de la ALU

La ALU realiza ocho operaciones, dos aritméticas y seis lógicas, que se eligen con el código de tres bits de SW[2:0]. En la tabla se relaciona cada código con su operación y con el formato en que se presenta el resultado en el display. La operación NOT usa el operando A y no tiene en cuenta el valor de B.

| SW[2:0] | Operación | Resultado | Formato en el display |
|---|---|---|---|
| 000 | Suma | A + B | Decimal |
| 001 | Resta | A − B | Decimal |
| 010 | AND | A AND B | Binario |
| 011 | OR | A OR B | Binario |
| 100 | XOR | A XOR B | Binario |
| 101 | XNOR | A XNOR B | Binario |
| 110 | NOT | NOT A | Binario |
| 111 | NAND | A NAND B | Binario |

La razón de usar decimal en unas operaciones y binario en otras se explica en la sección 5.


## 3. Arquitectura modular

El diseño se dividió en módulos pequeños, estos se encuentran en siete archivos dentro de la carpeta `src/`, y el archivo `top.v` los instancia y los conecta con los pines de la tarjeta.

### 3.1 Módulos del diseño

La siguiente tabla presenta los módulos que forman el sistema, el archivo en el que se encuentra cada uno y la función que cumple.

| Módulo | Archivo | Función |
|---|---|---|
| `antirrebote` | `almacenamiento.v` | Filtra los rebotes de un botón y entrega un pulso de un ciclo de reloj por cada pulsación. Se usan cuatro copias, una por botón |
| `sel_escritura` | `reg_bank.v` | Guarda la dirección del registro que se va a escribir y la avanza con cada pulso de BTN0 |
| `reg_bank` | `reg_bank.v` | Banco de cuatro registros de 4 bits. Escribe el dato de los switches con BTN1 y entrega al mismo tiempo los dos registros de la pareja activa |
| `comb_selector` | `comb_selector.v` | Cuenta de 0 a 5 con cada pulso de BTN2 y traduce esa cuenta en las direcciones de los registros A y B |
| `alu` | `alu.v` | Realiza la operación indicada por SW[2:0] sobre A y B. Es un circuito combinacional, por lo que su salida cambia en cuanto cambian sus entradas |
| `reg_resultado` | `almacenamiento.v` | Guarda el resultado de la ALU y el código de la operación cuando llega el pulso de BTN3, y los conserva hasta la siguiente ejecución |
| `display_tm1637` | `display_tm1637.v` | Convierte el resultado guardado en los cuatro dígitos del display y los envía al TM1637. Contiene los submódulos `formato_display` y `tm1637_driver` |
| `leds_operandos` | `indicadores.v` | Enciende los LEDs de los dos registros de la pareja activa |
| `rgb_registro` | `indicadores.v` | Asigna un color del LED RGB a cada registro de escritura |
| `top` | `top.v` | Instancia todos los módulos y los conecta entre sí y con los pines de la tarjeta |



### 3.3 Conexión entre módulos

Los botones de la tarjeta no se conectan directo a la lógica. Cada uno pasa primero por su módulo `antirrebote`, que entrega una señal `pulso[i]` de un ciclo de reloj, y estos cuatro pulsos controlan el resto del sistema. Los switches, en cambio, llegan sin pasar por ningún filtro (no es necesario) al banco de registros como dato de escritura, y a la ALU y a `reg_resultado` como código de operación.

La escritura del banco depende de dos pulsos. Con el pulso de BTN0, `sel_escritura` cambia la dirección `addr_w`, que le indica al banco cuál registro escribir y a `rgb_registro` qué color mostrar. Con el pulso de BTN1, el banco guarda el valor de SW[3:0] en esa dirección.

La lectura del banco la controla `comb_selector`, que entrega las direcciones `addr_a` y `addr_b` y las cambia con el pulso de BTN2. El banco usa estas direcciones para colocar en `dato_a` y `dato_b` el contenido de los registros  y `leds_operandos` las usa para encender los LEDs de esa pareja.

La ALU recibe `dato_a`, `dato_b` y el código de SW[2:0], y calcula `alu_result` de forma continua, pero este valor no llega directo al display , porque con el pulso de BTN3 `reg_resultado` copia el resultado y el código de la operación en `res_guardado` y `op_guardada`, que son los valores que recibe `display_tm1637`. Este registro intermedio, permite que el display no se altera cuando cambian los operandos o los switches después de una ejecución.

Por último, `display_tm1637` genera las señales `tm_clk` y `tm_dio`, que salen por un puerto Pmod de la tarjeta hacia el módulo del display.

La siguiente tabla resume las señales internas declaradas en `top.v`, con el módulo que genera cada una y los módulos que la reciben.

| Señal | Bits | Sale de | Llega a |
|---|---|---|---|
| `pulso[3:0]` | 4 | `antirrebote` | `sel_escritura`, `reg_bank`, `comb_selector`, `reg_resultado` |
| `addr_w` | 2 | `sel_escritura` | `reg_bank`, `rgb_registro` |
| `addr_a`, `addr_b` | 2 cada una | `comb_selector` | `reg_bank`, `leds_operandos` |
| `dato_a`, `dato_b` | 4 cada una | `reg_bank` | `alu` |
| `alu_result` | 4 | `alu` | `reg_resultado` |
| `res_guardado` | 4 | `reg_resultado` | `display_tm1637` |
| `op_guardada` | 3 | `reg_resultado` | `display_tm1637` |


El archivo `top.v` no contiene lógica propia. Simplemente se usa para declarar las señales internas, instanciar los módulos y conectar sus puertos con los switches, los botones, los LEDs y el puerto Pmod.

El módulo tiene dos parámetros, `DEBOUNCE` y `TM_DIV`, que fijan el tiempo del antirrebote y la velocidad del bus del display. En la placa valen 1 250 000 y 625 ciclos de reloj, que equivalen a 10 ms y 5 µs a 125 MHz. En la simulación se reducen para que las pruebas terminen en poco tiempo, sin modificar el código de los módulos.

## 4. Diseño de los módulos

Para describir el funcionamiento interno de cada módulo, se va a realizar el recorrido desde las señales desde los botones hasta los indicadores.

### 4.1 Antirrebote

Al presionar o soltar un pulsador, el contacto mecánico rebota durante algunos milisegundos y la señal oscila varias veces entre 0 y 1 antes de quedarse estable. Si esa señal llegara directo a la lógica, una sola pulsación podría contarse como varias (entonces no hay certeza sobre si el estado es alto o bajo), por lo que cada botón pasa por el módulo `antirrebote` antes de usarse.

El módulo trabaja en tres etapas. La primera es un sincronizador de dos flip-flops (`sync0` y `sync1`), porque el botón cambia en cualquier momento sin relación con el reloj de la FPGA, y una señal así puede dejar a un flip-flop en un estado indefinido durante un instante. La segunda etapa es un filtro que compara la entrada sincronizada con el último estado aceptado (`estable`) y cuenta los ciclos en que son diferentes, de modo que el cambio se acepta cuando se mantiene durante `LIMITE` ciclos seguidos y la cuenta vuelve a cero si un rebote devuelve la señal a su valor anterior. La tercera etapa genera la salida `pulso`, que vale 1 durante un ciclo de reloj cuando se acepta una pulsación y no se activa al soltar el botón.

Con `LIMITE` igual a 1 250 000 y un reloj de 125 MHz, el cambio debe mantenerse 10 ms para ser aceptado, que es cuando esas oscilaciones descritas anteriormente terminan. El siguiente fragmento corresponde al filtro y a la generación del pulso.

```verilog
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
```

### 4.2 Banco de registros y selección de escritura

El módulo `reg_bank` contiene cuatro registros de 4 bits, de R0 a R3, que valen cero al encender la tarjeta. Cada vez que llega el pulso de BTN1, el banco toma el valor de los switches y lo guarda en el registro seleccionado por `addr_w`, sin modificar los otros tres. Esta escritura es síncrona porque ocurre en el flanco de subida del reloj, como se observa en el siguiente fragmento.

```verilog
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
```

La lectura se realiza por dos puertos, uno para el operando A y otro para el B. Cada puerto es un multiplexor combinacional que entrega el contenido del registro indicado por `addr_a` o `addr_b`, de manera que los dos operandos están disponibles en todo momento y cambian apenas se selecciona una nueva pareja (no es necesario esperar un flanco de reloj).

La dirección de escritura la proporciona `sel_escritura`, un contador de 2 bits que aumenta con cada pulso de BTN0. Como 2 bits representan los valores de 0 a 3, después de R3 el contador se desborda y regresa a R0.

### 4.3 Selector de combinaciones

Con cuatro registros existen seis parejas distintas si no se repite un registro ni se tiene en cuenta el orden. El módulo `comb_selector` recorre estas parejas por medio de un contador (`indice`), que avanza con cada pulso de BTN2 y regresa a 0 después de llegar a 5, y de un bloque combinacional que traduce el índice en las direcciones de los dos registros según la siguiente tabla.

| `indice` | `addr_a` | `addr_b` | Pareja |
|---|---|---|---|
| 0 | 0 | 1 | R0, R1 |
| 1 | 0 | 2 | R0, R2 |
| 2 | 0 | 3 | R0, R3 |
| 3 | 1 | 2 | R1, R2 |
| 4 | 1 | 3 | R1, R3 |
| 5 | 2 | 3 | R2, R3 |

Como el índice tiene 3 bits puede tomar los valores 6 y 7, pero el contador nunca los alcanza, entonces se incluye una opción `default` que asigna la primera pareja, con lo que todas las salidas quedan definidas y no infieren latches (elementos de memoria no deseados).

### 4.4 Unidad aritmético-lógica

La ALU es un circuito combinacional descrito con un bloque `always @(*)` y una sentencia `case` que elige la operación según el código `op`, como se observa en el siguiente fragmento. Las ocho operaciones y sus códigos son aquellos de la sección 2.4.

```verilog
always @(*) begin
    case (op)
        3'b000:  result = A + B;      // suma
        3'b001:  result = A - B;      // resta
        3'b010:  result = A & B;      // AND
        3'b011:  result = A | B;      // OR
        3'b100:  result = A ^ B;      // XOR
        3'b101:  result = ~(A ^ B);   // XNOR
        3'b110:  result = ~A;         // negador (solo usa A)
        3'b111:  result = ~(A & B);   // NAND
        default: result = 4'b0000;    // evita latches
    endcase
end
```

Las operaciones lógicas se aplican bit a bit, por lo tanto, cada bit del resultado depende de los bits de A y B que estén en la misma posición. En las operaciones aritméticas el resultado también tiene 4 bits y solo puede representar valores de 0 a 15, por lo que, cuando una suma supera ese rango o una resta da un valor negativo, el resultado da la vuelta y continúa desde el otro extremo. Por ejemplo, 9 + 9 da 2 en lugar de 18 y 3 − 5 da 14 en lugar de −2, este comportamiento se analiza en la sección 8.

### 4.5 Registro del resultado

El módulo `reg_resultado` es el que permite que el display conserve el último resultado. Contiene dos registros, `result` de 4 bits y `op` de 3 bits, que copian la salida de la ALU y el código de operación en el ciclo en que llega el pulso de BTN3 y además mantiene su valor mientras ese pulso no se repita, aunque cambien los operandos o los switches. Descrito de la siguiente manera:
```verilog
always @(posedge clk) begin
    if (ejecutar) begin
        result <= result_in;
        op     <= op_in;
    end
end
```

Guardar la operación junto con el resultado fue necesario porque el formato del display depende del tipo de operación. En el caso donde el display tomara el código directo de SW[2:0], al mover los switches después de una ejecución cambiaría la forma de presentar el número aunque el valor fuera el mismo.

Ambos registros inician en cero, es decir, a una suma con resultado 0, por lo que al encender la tarjeta el display muestra `   0`.

### 4.6 Display TM1637

El módulo `display_tm1637` agrupa dos submódulos.

El módulo `display_tm1637` agrupa dos submódulos. El primero, `formato_display`, es combinacional y convierte la operación y el resultado guardados en los cuatro bytes que indican qué segmentos se encienden en cada dígito, mientras que el segundo, `tm1637_driver`, envía esos bytes al TM1637 por medio de una máquina de estados que genera las dos señales del bus en serie, el reloj `tm_clk` y la línea de datos `tm_dio`.

### 4.7 Indicadores

El módulo `leds_operandos` enciende los LEDs de los registros. Para hacerlo convierte cada dirección en un valor de 4 bits que tiene un 1 en la posición del registro y 0 en las demás, desplazando el valor `0001` tantas posiciones como indique la dirección, y luego combina los valores de A y B con una operación OR, como se muestra en el siguiente fragmento.

```verilog
wire [3:0] mascara_a = 4'b0001 << addr_a;
wire [3:0] mascara_b = 4'b0001 << addr_b;

assign led = mascara_a | mascara_b;
```

Para R1, R3, por ejemplo, la dirección 1 se convierte en `0010` y la dirección 3 en `1000`, y su combinación `1010` enciende LD1 y LD3.


El módulo `rgb_registro` asigna un color a cada registro de escritura por medio de un bloque combinacional que activa los canales rojo, verde y azul del LED RGB según la siguiente tabla. El amarillo se obtiene al encender al mismo tiempo el rojo y verde.

| `addr_w` | Registro | Color | R | G | B |
|---|---|---|---|---|---|
| 0 | R0 | Rojo | 1 | 0 | 0 |
| 1 | R1 | Verde | 0 | 1 | 0 |
| 2 | R2 | Azul | 0 | 0 | 1 |
| 3 | R3 | Amarillo | 1 | 1 | 0 |




--------------------------------

## 5. Simulación

### 5.1 Testbench por módulo

| Testbench | Módulo | Qué se verifica |
| --- | --- | --- |
| `tb_alu.v` | `alu` | Las 8 operaciones, el desborde de la suma, la resta con resultado negativo y que NOT ignore `B`. |
| `tb_reg_bank.v` | `reg_bank`, `sel_escritura` | Escritura de R0–R3, que sin `write_enable` no se escriba, la vuelta de `addr_w` a 0 y la lectura de las 6 parejas por los dos puertos. |
| `tb_comb_selector.v` | `comb_selector` | Las 6 parejas en orden, la vuelta a R0-R1 y que sin pulso no cambie. |
| `tb_almacenamiento.v` | `antirrebote`, `reg_resultado` | Que el ruido corto no genere pulsos, que una pulsación con rebotes genere exactamente uno y que el registro solo cambie con `ejecutar`. |
| `tb_indicadores.v` | `leds_operandos`, `rgb_registro` | LEDs de las 6 parejas y color de cada registro. |
| `tb_tm1637_trama.v` | `display_tm1637` | Trama completa del bus. Incluye un modelo del TM1637 que detecta START y STOP, lee los bits, responde el ACK y reconstruye el texto del display. |

### 5.2 Testbench del sistema completo

`tb_top.v` instancia `top.v` y sigue la misma secuencia que se haría en la placa. El texto del display se obtiene de los segmentos que genera `formato_display`. Los botones se simulan sin rebotes, ya que el antirrebote se prueba por separado en `tb_almacenamiento.v`.

| Paso | Qué hace | Resultado esperado |
| --- | --- | --- |
| 1. Escritura | Carga 5, 3, 12 y 9 en R0–R3 con `BTN1` y `BTN0`. | Banco = `[5 3 12 9]`. |
| 2. Pareja R0, R1 | Ejecuta suma y AND con `BTN3`. | `8` → `   8` y `0001` → `0001`. |
| 3. Pareja R0, R2 | Avanza con `BTN2` y ejecuta XOR. | `1001` → `1001`. |
| 4. Conservación | Cambia los switches y pasa a la pareja R0, R3 **sin** presionar `BTN3`. | El resultado y el display siguen en `1001`. |
| 5. Pareja R0, R3 | Ejecuta suma y resta. | `14` → `  14` y `12` → `  12` (5 − 9 = −4, en módulo 16). |

### 5.3 Formas de onda

#### ALU (`tb_alu.v`)

![Simulación de la ALU](sim/GTKWave_Images/tb_alu.png)

Señales: `op`, `A`, `B` y `esperado`, en binario. Cada prueba dura 10 ns y se aplican las 8 operaciones.

- **0–40 ns, suma y resta:** `0101 + 0011 = 1000` (8) y `0101 - 0011 = 0010` (2). Además se prueban los límites de 4 bits: `1111 + 1111` da `1110` (14), porque se pierde el acarreo de 30, y `0011 - 0101` da `1110` (14 o  E), que es −2 en módulo 16.
- **40–110 ns, operaciones lógicas:** con `A = 1100` y `B = 1010` aparecen las cuatro combinaciones de bits, así que cada resultado corresponde a la tabla de verdad completa: AND `1000`, OR `1110`, XOR `0110`, XNOR `1001` y NAND `0111`.
- **80–100 ns, NOT:** se ejecuta dos veces con el mismo `A` y distinto `B` (`1010` y `0000`), y en ambos casos el resultado es `0011`. Esto confirma que el negador solo usa `A`.

En todos los tramos `esperado` cambia en el mismo instante que las entradas, porque la ALU es combinacional.

#### Banco de registros (`tb_reg_bank.v`)

![Simulación del banco de registros](sim/GTKWave_Images/tb_reg_bank.png)

Señales: `clk`, `write_enable`, `siguiente`, `addr_w`, `data_w`, `R0`–`R3`, `addr_a`, `addr_b`, `data_a` y `data_b`, en decimal.

- **Escritura (20–150 ns):** se repite cuatro veces la secuencia pulso de `write_enable` → pulso de `siguiente`. En el flanco de subida de `clk` en que `write_enable` está en 1, solo cambia el registro que indica `addr_w`: R0 toma 5, R1 toma 3, R2 toma 12 y R3 toma 9. Con cada pulso de `siguiente`, `addr_w` avanza, y después de R3 vuelve a 0.
- **Sin escritura (150–190 ns):** `data_w` pasa a 15, pero como `write_enable` sigue en 0, ningún registro cambia.
- **Lectura (190–250 ns):** `addr_a` y `addr_b` recorren las 6 parejas. `data_a` y `data_b` muestran de inmediato el valor del registro correspondiente, porque la lectura es combinacional; por ejemplo, con `addr_a = 0` y `addr_b = 2` se leen 5 y 12.

#### Selector de combinaciones (`tb_comb_selector.v`)

![Simulación del selector de combinaciones](sim/GTKWave_Images/tb_comb_selector.png)

Señales: `clk`, `siguiente`, `indice`, `addr_a` y `addr_b`, en decimal.

Cada pulso de `siguiente` hace avanzar `indice` en el siguiente flanco de subida de `clk`, y en ese mismo instante `addr_a` y `addr_b` cambian a la nueva pareja: (0, 1), (0, 2), (0, 3), (1, 2), (1, 3) y (2, 3). Con el sexto pulso, `indice` pasa de 5 a 0 y la pareja vuelve a (0, 1). En el tramo final no hay pulsos y el índice se mantiene.

#### Antirrebote (`tb_almacenamiento.v`)

![Simulación del antirrebote](sim/GTKWave_Images/tb_antirrebote.png)

Señales: `btn`, `ar.estable`, `ar.contador` (decimal) y `pulso`. Se muestra el tramo de 0 a 1110 ns.

- **Ruido corto (~40 ns):** `btn` sube solo 3 ciclos. `contador` empieza a contar, pero se reinicia en cuanto `btn` vuelve a 0, y `pulso` no se activa.
- **Pulsación con rebotes (~250–730 ns):** `btn` sube y baja varias veces antes de quedarse en 1. Cada rebote reinicia `contador`; solo cuando `btn` se mantiene estable durante 8 ciclos, `estable` pasa a 1 y `pulso` genera **un único pulso** de un ciclo. Al soltar también hay rebotes, y cuando `estable` vuelve a 0 no se genera ningún pulso.
- **Segunda pulsación (~720–1110 ns):** una pulsación limpia genera un segundo pulso, lo que confirma que el filtro queda listo después de soltar.

#### Registro del resultado (`tb_almacenamiento.v`)

![Simulación del registro del resultado](sim/GTKWave_Images/tb_reg_resultado.png)

Señales: `clk`, `ejecutar`, `result_in`, `op_in`, `result` y `op`, en decimal y binario. Se muestra el tramo final de la simulación, desde ~1100 ns.

`result_in` pasa a 9 y, mientras `ejecutar` está en 0, `result` sigue en 0. Con el primer pulso de `ejecutar`, `result` toma 9 y `op` toma `000`. Luego `result_in` cambia a 5 y `op_in` a `011`, pero `result` y `op` **se mantienen** en 9 y `000` hasta el segundo pulso de `ejecutar`, cuando pasan a 5 y `011`. Este es el mecanismo que conserva el resultado del display hasta presionar `BTN3`.

#### LEDs y LED RGB (`tb_indicadores.v`)

![Simulación de los indicadores](sim/GTKWave_Images/tb_indicadores.png)

Señales: `addr_a`, `addr_b`, `led` (binario), `addr_w`, `r`, `g` y `b`. Cada prueba dura 10 ns.

- **0–60 ns, LEDs de operandos:** para cada pareja, `led` tiene en 1 exactamente los bits de los dos registros activos: `0011`, `0101`, `1001`, `0110`, `1010` y `1100`.
- **60–100 ns, LED RGB:** `addr_w` recorre 0 a 3 y `{r, g, b}` toma `100` (rojo), `010` (verde), `001` (azul) y `110` (amarillo). Antes de los 60 ns `addr_w` aún no tiene valor asignado, por eso aparece indefinido.


#### Trama del TM1637 (`tb_tm1637_trama.v`)

El TM1637 no recibe el número directamente: recibe una secuencia de bytes por dos líneas, `CLK` y `DIO`. El módulo `tm1637_driver` arma esa secuencia y la repite de forma continua. Para que el display muestre un resultado, cada repetición (trama) tiene que hacer tres cosas en orden: configurar el modo de escritura, enviar los 4 dígitos y encender el display.

**Estructura de la trama.** Una trama tiene 7 bytes repartidos en 3 etapas. Cada etapa empieza con un START y termina con un STOP:

| `n_byte` | Etapa | Byte | Binario | Función |
| :---: | :---: | :---: | :---: | --- |
| 0 | 1 | `0x40` | `0100 0000` | **Comando de datos.** Los bits `01` indican que es un comando de datos, el bit 2 en `0` activa la dirección automática y los bits `00` indican escritura en el display. |
| 1 | 2 | `0xC0` | `1100 0000` | **Comando de dirección.** Los bits `11` indican que es un comando de dirección y `0000` que la escritura empieza en el dígito 0 (el de la izquierda). |
| 2 | 2 | dígito 0 | segmentos | Segmentos del dígito 0. |
| 3 | 2 | dígito 1 | segmentos | Segmentos del dígito 1. Por la dirección automática, se guarda en la siguiente posición sin enviar otra dirección. |
| 4 | 2 | dígito 2 | segmentos | Segmentos del dígito 2. |
| 5 | 2 | dígito 3 | segmentos | Segmentos del dígito 3. |
| 6 | 3 | `0x8A` | `1000 1010` | **Control del display.** Los bits `10` indican que es un comando de control, el bit 3 en `1` enciende el display y `010` fija el brillo en el nivel 2 (de 0 a 7). |

Por eso en el código el STOP solo va después de los bytes 0, 5 y 6 (`stop_despues`): gracias a la dirección automática, `0xC0` y los 4 dígitos se envían seguidos en una sola etapa.

Los dígitos no se envían como números, sino como el patrón de segmentos que se debe encender. Cada bit corresponde a un segmento: bit 0 = a, bit 1 = b, …, bit 6 = g y bit 7 = punto. Los que aparecen en esta simulación son:

| Carácter | Byte | Binario | Segmentos encendidos |
| :---: | :---: | :---: | --- |
| apagado | `0x00` | `0000 0000` | Ninguno |
| `0` | `0x3F` | `0011 1111` | a, b, c, d, e, f |
| `1` | `0x06` | `0000 0110` | b, c |
| `2` | `0x5B` | `0101 1011` | a, b, d, e, g |

**Transmisión de un byte.** La máquina de estados del driver tiene 4 estados, y cada uno se divide en 4 fases de igual duración. En la simulación (`DIV = 4`) cada fase dura 32 ns; en la placa (`DIV = 625`) dura 5 µs, lo que da un reloj de 50 kHz en `tm_clk`.

| Estado (`estado`) | Fase 0 | Fase 1 | Fase 2 | Fase 3 |
| --- | --- | --- | --- | --- |
| START (0) | `CLK` = 1, `DIO` libre | `DIO` baja con `CLK` en 1 → **START** | — | Pasa a enviar bits |
| BIT (1) | `CLK` baja | Se pone el bit en `DIO` | `CLK` sube → **el TM1637 lee el bit** | Siguiente bit, o ACK tras el 8.º |
| ACK (2) | `CLK` baja | El driver suelta `DIO` | `CLK` sube → **el TM1637 responde** | STOP, o siguiente byte |
| STOP (3) | `CLK` baja | `DIO` en 0 | `CLK` sube | `DIO` sube con `CLK` en 1 → **STOP** |

De esta tabla salen las reglas que se deben ver en la simulación:

- **Los datos solo cambian con `CLK` en 0** (fase 1 de BIT) y se leen en el flanco de subida (fase 2). Así, cuando el TM1637 lee, `DIO` ya está estable.
- **Un cambio de `DIO` con `CLK` en 1 es una señal de control:** si baja es START y si sube es STOP. Como los datos nunca cambian con `CLK` en 1, el TM1637 puede distinguir un bit de un START o un STOP.
- **Los bits se envían del menos significativo al más significativo** (`dato[n_bit]`, con `n_bit` de 0 a 7). En la onda, cada byte aparece escrito "al revés".
- **`DIO` es de drenador abierto:** el driver solo la pone en 0 o la suelta (`1'bz`), y la resistencia de pull-up la lleva a 1. Así, en el noveno pulso (ACK), el TM1637 puede bajarla para confirmar que recibió el byte.

Cada byte usa entonces 9 pulsos de `tm_clk`: 8 de datos y 1 de ACK. Antes de cada STOP hay un pulso adicional que no lleva información y sirve para dejar `DIO` en 0 antes de subirla. Por eso las etapas 1 y 3 tienen 10 pulsos (9 + 1) y la etapa 2 tiene 46 (5 × 9 + 1).

**Vista completa**

![Simulación de la trama del TM1637](sim/GTKWave_Images/tb_tm1637_trama.png)

Señales: `tm_clk`, `tm_dio`, `estado`, `n_byte` (decimal), `byte_tx` (hexadecimal), `ack` y `texto` (ASCII). Se envían dos tramas, cada una de unos 8.8 µs:

| Trama | Entrada del display | Bytes enviados | `texto` al terminar |
| :---: | --- | --- | :---: |
| 1 | `op = 000` (suma), `result = 12` | `40` · `C0 00 00 06 5B` · `8A` | `"  12"` |
| 2 | `op = 010` (AND), `result = 0101` | `40` · `C0 3F 06 3F 06` · `8A` | `"0101"` |

En cada trama se distinguen tres grupos de pulsos de `tm_clk`: uno corto (etapa 1, ~1.4 µs), uno largo (etapa 2, ~6 µs) y otro corto (etapa 3, ~1.4 µs). Entre grupos, `tm_clk` queda en 1 mientras `tm_dio` marca el STOP de una etapa y el START de la siguiente. `n_byte` avanza de 0 a 6 y `byte_tx` muestra el byte que se transmite en cada momento.

La suma se muestra en decimal (`12` en los dos dígitos de la derecha y los otros apagados) y la AND en binario (un bit por dígito), según la estrategia de visualización. `texto` solo cambia cuando el modelo recibe `0x8A`, igual que el TM1637 real, que muestra los dígitos al recibir el comando de encendido.

Los dígitos de cada trama no se mezclan aunque `op` y `result` cambien a mitad de una trama: al comenzar cada trama (START con `n_byte = 0`), el driver copia los 4 dígitos en `buf0`–`buf3` y transmite esa copia. Por eso el cambio de entrada al final de la primera trama solo aparece en la segunda.

**Detalle de la etapa 2**

![Detalle de la etapa 2 del TM1637](sim/GTKWave_Images/tb_tm1637_etapa2.png)

Etapa 2 de la primera trama (`n_byte` de 1 a 5, aproximadamente de 1.4 µs a 7.4 µs). Empieza con un START: `tm_dio` baja mientras `tm_clk` está en 1. Desde ahí, leyendo `tm_dio` en cada flanco de subida de `tm_clk`, se obtienen los bits de cada byte:

| Byte | `tm_dio` en los pulsos 1 → 8 | Leído del bit 7 al 0 | Pulso 9 |
| :---: | :---: | :---: | :---: |
| `C0` | `0 0 0 0 0 0 1 1` | `1100 0000` | ACK |
| `00` | `0 0 0 0 0 0 0 0` | `0000 0000` | ACK |
| `00` | `0 0 0 0 0 0 0 0` | `0000 0000` | ACK |
| `06` | `0 1 1 0 0 0 0 0` | `0000 0110` | ACK |
| `5B` | `1 1 0 1 1 0 1 0` | `0101 1011` | ACK |

En el noveno pulso de cada byte, `ack` está en 1: el modelo del TM1637 baja `tm_dio` para confirmar la recepción, aunque el driver ya la haya soltado. Justo después, cuando `tm_clk` baja, `tm_dio` puede subir un instante por el pull-up antes de que el driver ponga el primer bit del siguiente byte; como ocurre con `tm_clk` en 0, no se interpreta como STOP. Después del quinto ACK, el pulso adicional y la subida de `tm_dio` con `tm_clk` en 1 forman el STOP que cierra la etapa.

Entre los 5 bytes no hay START ni STOP: es una sola transmisión continua, posible gracias a la dirección automática configurada con `0x40`.


#### Sistema completo: escritura (`tb_top.v`)

![Escritura en el sistema completo](sim/GTKWave_Images/tb_top_escritura.png)

Señales: `btn` y `sw` (binario), `dut.pulso` (binario), `dut.addr_w`, `R0`–`R3` (decimal), `dut.led6_r`, `dut.led6_g` y `dut.led6_b`. Tramo de 0 a ~3.2 µs.

Para cada registro, `sw` toma el valor a escribir y se presiona `BTN1` y luego `BTN0`. Cada pulsación genera un único pulso en `dut.pulso`. Con el pulso de `BTN1` cambia solo el registro indicado por `addr_w`, y con el de `BTN0`, `addr_w` avanza y el LED RGB cambia de color. Al final el banco queda en `[5 3 12 9]`.

#### Sistema completo: ejecución y conservación (`tb_top.v`)

![Ejecución y conservación en el sistema completo](sim/GTKWave_Images/tb_top_ejecucion.png)

Señales: `btn` y `sw` (binario), `dut.addr_a`, `dut.addr_b`, `led` (binario), `alu_result`, `resultado` (decimal) y `texto` (ASCII). Tramo desde ~3.2 µs hasta el final.

- **R0, R1:** con `sw = 0000` (suma), `BTN3` guarda 8 y `texto` muestra `"   8"`. Con `sw = 0010` (AND), guarda 1 y muestra `"0001"`.
- **R0, R2:** `BTN2` cambia la pareja y `led` pasa de `0011` a `0101`. Con `sw = 0100` (XOR) se guarda 9 y el display muestra `"1001"`.
- **Conservación:** `sw` pasa a `0000` y `BTN2` cambia la pareja a R0, R3. `alu_result` cambia con cada movimiento, pero `resultado` y `texto` **se mantienen** en 9 y `"1001"`, porque no se presionó `BTN3`.
- **R0, R3:** al presionar `BTN3` se ejecuta la suma (14, `"  14"`), y con `sw = 0001`, la resta 5 − 9, que da 12 en módulo 16 (`"  12"`).

## 6. Implementación en FPGA

### 6.1 Asignación de pines

El archivo `constrs/zybo_z7.xdc` consta de los pines que se utilizaron para el módulo TM1637.

| Señal | Pin | Elemento de la placa |
| --- | :---: | --- |
| `clk` | K17 | Reloj de 125 MHz |
| `sw[0]` – `sw[3]` | G15, P15, W13, T16 | SW0 – SW3 |
| `btn[0]` – `btn[3]` | K18, P16, K19, Y16 | BTN0 – BTN3 |
| `led[0]` – `led[3]` | M14, M15, G14, D18 | LD0 – LD3 |
| `led6_r`, `led6_g`, `led6_b` | V16, F17, M17 | LED RGB LD6 |
| `tm_clk` | V15 | Pmod JC, pin 1 |
| `tm_dio` | W15 | Pmod JC, pin 2 (con `PULLUP true`) |


### 6.2 Conexión del TM1637

| TM1637 | Pmod JC |
| --- | --- |
| CLK | Pin 1 |
| DIO | Pin 2 |
| GND | Pin 5 |
| VCC | Pin 6 (3.3 V) |

A `tm_dio` se le activa el pull-up interno de la FPGA, ya que la línea es de drenador abierto y necesita una resistencia que la lleve a 1 cuando nadie la maneja.

---

## 7. Evidencia de funcionamiento en FPGA

### 7.1 Video de demostración

https://github.com/user-attachments/assets/5525b1e7-5ded-4990-ac48-e17b8e3314a1

### 8.2 Valores usados en la prueba

| Registro | Valor (binario) | Valor (decimal) |
| :---: | :---: | :---: |
| R0 | `1010` | 10 |
| R1 | `0101` | 5 |
| R2 | `0011` | 3 |
| R3 | `1000` | 8 |

---

## 8. Análisis de resultados

### 8.1 Lo que se observa en el video

1. La carga de los valores de la tabla 8.2 en `R0`–`R3` con `SW[3:0]`, `BTN0` y `BTN1`. El LED RGB cambia de color al cambiar de registro.
2. El cambio de pareja de operandos con `BTN2`. Los LEDs indican los registros activos.
3. La ejecución de la suma y la resta con `BTN3`, con el resultado en decimal.
4. La ejecución de las operaciones lógicas, con el resultado en binario.
5. La conservación del resultado: al cambiar los switches y la pareja sin presionar `BTN3`, el display mantiene el último resultado.

### 8.2 Resultados esperados con los valores de prueba

**Pareja R0, R1** (`A = 1010`, `B = 0101`):

| Operación | Resultado | Display |
| --- | :---: | :---: |
| Suma | 15 | `··15` |
| Resta | 5 | `···5` |
| AND | `0000` | `0000` |
| OR | `1111` | `1111` |
| XOR | `1111` | `1111` |
| XNOR | `0000` | `0000` |
| NOT | `0101` | `0101` |
| NAND | `1111` | `1111` |

R0 y R1 son complementarios (no comparten ningún bit en 1), por eso AND da `0000` y OR y XOR dan `1111`.

**Pareja R0, R2** (`A = 1010`, `B = 0011`):

| Operación | Resultado | Display |
| --- | :---: | :---: |
| Suma | 13 | `··13` |
| Resta | 7 | `···7` |
| AND | `0010` | `0010` |
| OR | `1011` | `1011` |
| XOR | `1001` | `1001` |
| XNOR | `0110` | `0110` |
| NOT | `0101` | `0101` |
| NAND | `1101` | `1101` |

El resultado de NOT es igual en ambas parejas porque solo depende de `A`, que en las dos es R0.

### 8.3 Observaciones

- **Coincidencia entre simulación y hardware:** los valores mostrados en la placa coinciden con los esperados y con los de la simulación.
- **Aritmética de 4 bits:** la suma y la resta trabajan en módulo 16. Un resultado mayor que 15 pierde el acarreo y una resta con `B > A` da la vuelta, ya que el diseño no representa números negativos. Para mostrarlos haría falta que la ALU entregara un bit de préstamo, porque con solo 4 bits de resultado no se puede distinguir, por ejemplo, un 14 de un −2.
- **Uso de los switches para la operación:** al terminar de cargar datos, los switches quedan con el último valor escrito, que también es un código de operación válido. Si se presiona `BTN3` sin cambiarlos, se ejecuta esa operación, no la que se pretendía.
- **Antirrebote:** sin él, una sola pulsación produciría varios cambios de registro o de pareja. Con el filtro de 10 ms, cada pulsación produce exactamente un pulso.

---

## 9. Conclusiones

- **Funcionamiento completo:** el sistema cumplió los requerimientos de la guía. Los registros almacenaron los datos, el selector recorrió las 6 parejas con `BTN2`, la ALU ejecutó las 8 operaciones al presionar `BTN3` y el display conservó el último resultado hasta una nueva ejecución.
- **Diseño modular:** dividir el sistema en bloques pequeños con una sola función permitió probar cada uno por separado con su propio testbench antes de integrarlos. `top.v` se limitó a instanciar y conectar, sin lógica propia.
- **Simulación antes de implementar:** verificar cada módulo y el sistema completo en simulación permitió encontrar errores antes de programar la FPGA, donde depurar es más lento porque no se ven las señales internas.
- **Conservación del resultado:** guardar el resultado **y** el código de operación en `reg_resultado` aisló el display de los cambios en los switches, los registros y la pareja de operandos. Guardar también la operación evita que el formato del display (decimal o binario) cambie al mover los switches.
- **Estrategia de visualización:** el formato decimal facilita leer el resultado de la suma y la resta, mientras que el binario permite comprobar las operaciones lógicas bit a bit aprovechando los 4 dígitos del display.
- **Interfaz con periféricos:** el TM1637 requirió implementar un protocolo serie de dos hilos parecido a I2C, con condiciones de START y STOP, bit menos significativo primero y confirmación (ACK) del receptor. Simularlo con un modelo del chip permitió verificar la trama bit a bit.
- **Flujo de diseño:** el laboratorio aplicó el flujo completo de un sistema digital: especificación → diseño → simulación → implementación.
