# Lab03 – ALU + Banco de Registros + Diseño Modular

## Integrantes

- Julian David Gomez Gonzalez - 1007544331
- Cristian Norbey Hernández Gualteros - 1001091723
- Milton Nicolas Rincón Caicedo - 1021312724

**Semestre:** 2026-2

**Plataforma:** Digilent Zybo Z7-10 (Zynq-7000)

---

## Índice

1. [Introducción](#1-introducción)
2. [Descripción del sistema](#2-descripción-del-sistema)
3. [Arquitectura modular](#3-arquitectura-modular)
4. [Diseño de los módulos](#4-diseño-de-los-módulos)
5. [Simulación](#5-simulación)
6. [Implementación en FPGA](#6-implementación-en-fpga)
7. [Evidencia de funcionamiento en FPGA](#7-evidencia-de-funcionamiento-en-fpga)
8. [Análisis de resultados](#8-análisis-de-resultados)
9. [Conclusiones](#9-conclusiones)
10. [Referencias](#10-referencias)

---

## 1. Introducción

Se diseñó e implementó un sistema digital de 4 bits sobre la tarjeta Zybo Z7. El sistema permite guardar datos en un banco de cuatro registros, escoger dos de ellos como operandos, operarlos con una unidad aritmético-lógica (ALU) y mostrar el resultado en un display de 7 segmentos controlado por el circuito integrado TM1637.

El sistema se construyó por módulos, donde cada bloque cumple una función concreta, como almacenar datos, seleccionar operandos, calcular o mostrar el resultado, y se prueba por separado antes de integrarlo con los demás en el archivo `top.v`, que se limita a conectar los módulos entre sí y con los pines de la tarjeta. Esta forma de trabajo permite reutilizar bloques y hace que el diseño sea más fácil de entender y de ampliar. Además, el display  conserva el resultado de la última operación hasta que se presione BTN3, aunque después cambien los operandos, la combinación de registros o la operación seleccionada. Por esta razón el diseño incluye un registro que guarda el resultado en el momento de la ejecución y lo mantiene mientras no se ejecute una nueva operación.


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

Se eligió el formato decimal para la suma y la resta porque en ellas interesa el valor numérico del resultado, y el binario para las operaciones lógicas porque actúan sobre cada bit por separado,


## 3. Arquitectura modular

El diseño se dividió en módulos pequeños que se encuentran en siete archivos dentro de la carpeta `src/`, y el archivo `top.v` los instancia y los conecta con los pines de la tarjeta.

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



### 3.2 Conexión entre módulos

Los botones de la tarjeta no se conectan directo a la lógica. Cada uno pasa primero por su módulo `antirrebote`, que entrega una señal `pulso[i]` de un ciclo de reloj, y estos cuatro pulsos controlan el resto del sistema. Los switches, en cambio, llegan sin pasar por ningún filtro, ya que se leen en el momento en que se presiona un botón al banco de registros como dato de escritura, y a la ALU y a `reg_resultado` como código de operación.

La escritura del banco depende de dos pulsos. Con el pulso de BTN0, `sel_escritura` cambia la dirección `addr_w`, que le indica al banco cuál registro escribir y a `rgb_registro` qué color mostrar. Con el pulso de BTN1, el banco guarda el valor de SW[3:0] en esa dirección.

La lectura del banco la controla `comb_selector`, que entrega las direcciones `addr_a` y `addr_b` y las cambia con el pulso de BTN2. El banco usa estas direcciones para colocar en `dato_a` y `dato_b` el contenido de los registros y `leds_operandos` las usa para encender los LEDs de esa pareja.

La ALU recibe `dato_a`, `dato_b` y el código de SW[2:0], y calcula `alu_result` de forma continua, pero este valor no llega directo al display, porque con el pulso de BTN3 `reg_resultado` copia el resultado y el código de la operación en `res_guardado` y `op_guardada`, que son los valores que recibe `display_tm1637`. Este registro intermedio permite que el display no se altere cuando cambian los operandos o los switches después de una ejecución.

Por último, `display_tm1637` genera las señales `tm_clk` y `tm_dio`, que salen por el Pmod JC de la tarjeta hacia el módulo del display.

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


El archivo `top.v` no contiene lógica propia. Simplemente se usa para declarar las señales internas, instanciar los módulos y conectar sus puertos con los switches, los botones, los LEDs y el puerto Pmod JC.

El módulo tiene dos parámetros, `DEBOUNCE` y `TM_DIV`, que fijan el tiempo del antirrebote y la velocidad del bus del display. En la placa valen 1 250 000 y 625 ciclos de reloj, que equivalen a 10 ms y 5 µs a 125 MHz. En la simulación se reducen para que las pruebas terminen en menos tiempo.
## 4. Diseño de los módulos

En este capítulo se describe el funcionamiento interno de cada módulo, siguiendo el recorrido de las señales desde los botones hasta los indicadores.

### 4.1 Antirrebote

Al presionar o soltar un pulsador, el contacto mecánico rebota durante algunos milisegundos y la señal oscila varias veces entre 0 y 1 antes de quedarse estable. Si esa señal llegara directo a la lógica, una sola pulsación podría contarse como varias, por lo tanto, cada botón pasa por el módulo `antirrebote` antes de usarse.

El módulo trabaja en tres etapas. La primera es un sincronizador de dos flip-flops (`sync0` y `sync1`), porque el botón cambia en cualquier momento sin relación con el reloj de la FPGA, y una señal así puede dejar a un flip-flop en un estado indefinido durante un instante. La segunda etapa es un filtro que compara la entrada sincronizada con el último estado aceptado (`estable`) y cuenta los ciclos en que son diferentes, de modo que el cambio se acepta cuando se mantiene durante `LIMITE` ciclos seguidos y la cuenta vuelve a cero si un rebote devuelve la señal a su valor anterior. La tercera etapa genera la salida `pulso`, que vale 1 durante un ciclo de reloj cuando se acepta una pulsación y no se activa al soltar el botón.

Con `LIMITE` igual a 1 250 000 y un reloj de 125 MHz, el cambio debe mantenerse 10 ms para ser aceptado, que es un margen adecuado para cuando estas oscilaciones terminan. El siguiente fragmento corresponde al filtro y a la generación del pulso.

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

Como el índice tiene 3 bits puede tomar los valores 6 y 7, pero el contador nunca los alcanza, entonces se incluye una opción `default` que asigna la primera pareja, con lo que todas las salidas quedan definidas y se evita que el circuito incluya latches (elementos de memoria no deseados).

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

Las operaciones lógicas se aplican bit a bit, por lo tanto, cada bit del resultado depende de los bits de A y B que estén en la misma posición. En las operaciones aritméticas el resultado también tiene 4 bits y solo puede representar valores de 0 a 15, por lo que, cuando una suma supera ese rango o una resta da un valor negativo, el resultado da la vuelta y continúa desde el otro extremo. Por ejemplo, 9 + 9 da 2 en lugar de 18 y 3 − 5 da 14 en lugar de −2.

### 4.5 Registro del resultado

El módulo `reg_resultado` es el que permite que el display conserve el último resultado. Contiene dos registros, `result` de 4 bits y `op` de 3 bits, que copian la salida de la ALU y el código de operación en el ciclo en que llega el pulso de BTN3 y además mantienen su valor mientras ese pulso no se repita, aunque cambien los operandos o los switches. Descrito de la siguiente manera:

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

El primero, `formato_display`, es combinacional y convierte la operación y el resultado guardados en los cuatro bytes que indican qué segmentos se encienden en cada dígito, mientras que el segundo, `tm1637_driver`, envía esos bytes al TM1637 por medio de una máquina de estados que genera las dos señales del bus en serie, el reloj `tm_clk` y la línea de datos `tm_dio`.

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

Cada módulo se verificó con un testbench propio antes de integrarlo al sistema. La siguiente tabla relaciona cada testbench con el módulo que prueba y con los casos que revisa.

| Testbench | Módulo | Casos verificados |
| --- | --- | --- |
| `tb_alu.v` | `alu` | Las ocho operaciones, el desbordamiento de la suma, la resta con resultado negativo y que la operación NOT no dependa de `B` |
| `tb_reg_bank.v` | `reg_bank`, `sel_escritura` | La escritura de R0 a R3, que ningún registro cambie sin `write_enable`, el regreso de `addr_w` a 0 y la lectura de las seis parejas por los dos puertos |
| `tb_comb_selector.v` | `comb_selector` | Las seis parejas en orden, el regreso a R0-R1 y que la pareja no cambie sin pulso |
| `tb_almacenamiento.v` | `antirrebote`, `reg_resultado` | Que el ruido corto no genere pulsos, que una pulsación con rebotes genere un solo pulso y que el registro del resultado no cambie sin el pulso de `ejecutar` |
| `tb_indicadores.v` | `leds_operandos`, `rgb_registro` | Los LEDs encendidos para cada una de las seis parejas y el color del LED RGB para cada registro |
| `tb_tm1637_trama.v` | `display_tm1637` | La trama completa del bus, con un modelo del TM1637 que detecta START y STOP, lee los bits, responde el ACK y reconstruye el texto del display |

### 5.2 Testbench del sistema completo

El testbench `tb_top.v` instancia `top.v` y reproduce la secuencia de pasos que se haría en la placa. El texto del display se reconstruye a partir de los segmentos que genera `formato_display`, y los botones se simulan sin rebotes, ya que el antirrebote se prueba por separado en `tb_almacenamiento.v`. La siguiente tabla describe los pasos de la prueba y el resultado esperado en cada uno.

| Paso | Acción | Resultado esperado |
| --- | --- | --- |
| 1. Escritura | Carga 5, 3, 12 y 9 en R0 a R3 con `BTN1` y `BTN0` | Banco con los valores `[5 3 12 9]` |
| 2. Pareja R0, R1 | Ejecuta la suma y la AND con `BTN3` | `8` → `   8`, y `0001` → `0001` |
| 3. Pareja R0, R2 | Avanza con `BTN2` y ejecuta la XOR | `1001` → `1001` |
| 4. Conservación | Cambia los switches y pasa a la pareja R0, R3 sin presionar `BTN3` | El resultado y el display siguen en `1001` |
| 5. Pareja R0, R3 | Ejecuta la suma y la resta | `14` → `  14`, y `12` → `  12`, porque la resta 5 − 9 da la vuelta y resulta en 12 |

### 5.3 Formas de onda

En esta sección se presentan las capturas de GTKWave de cada testbench, con las señales que se muestran y lo que se observa en cada tramo de la simulación.

#### ALU (`tb_alu.v`)

La siguiente captura muestra las señales `op`, `A`, `B` y `esperado` en binario, con una prueba cada 10 ns que recorre las ocho operaciones.

![Simulación de la ALU](sim/GTKWave_Images/tb_alu.png)

Entre 0 y 40 ns se prueban la suma y la resta. Con `A = 0101` y `B = 0011` la suma da `1000` (8) y la resta `0010` (2), y luego se prueban los límites de 4 bits, donde `1111 + 1111` da `1110` (14) porque se pierde el acarreo del resultado 30, y `0011 - 0101` da `1110` (14, o E en hexadecimal), que es la forma en que el resultado −2 da la vuelta con 4 bits.

Entre 40 y 110 ns se prueban las operaciones lógicas con `A = 1100` y `B = 1010`. Estos valores contienen las cuatro combinaciones posibles de dos bits, por lo que cada resultado reproduce la tabla de verdad completa de su operación, y se obtiene `1000` para AND, `1110` para OR, `0110` para XOR, `1001` para XNOR y `0111` para NAND.

Entre 80 y 100 ns la operación NOT se ejecuta dos veces con el mismo `A` y con valores distintos de `B` (`1010` y `0000`), y en ambos casos el resultado es `0011`, lo que confirma que el negador no depende de `B`.

En todos los tramos `esperado` cambia en el mismo instante que las entradas, porque la ALU es combinacional.

#### Banco de registros (`tb_reg_bank.v`)

La captura del banco de registros muestra `clk`, `write_enable`, `siguiente`, `addr_w`, `data_w`, los registros R0 a R3, `addr_a`, `addr_b`, `data_a` y `data_b`, con los valores en decimal.

![Simulación del banco de registros](sim/GTKWave_Images/tb_reg_bank.png)

Entre 20 y 150 ns se repite cuatro veces la secuencia de un pulso de `write_enable` seguido de un pulso de `siguiente`. En cada flanco de subida de `clk` con `write_enable` en 1 cambia el registro indicado por `addr_w`, de modo que R0 toma 5, R1 toma 3, R2 toma 12 y R3 toma 9, mientras que con cada pulso de `siguiente` la dirección `addr_w` avanza y después de R3 regresa a 0.

Entre 150 y 190 ns `data_w` pasa a 15, pero ningún registro cambia porque `write_enable` permanece en 0.

Entre 190 y 250 ns `addr_a` y `addr_b` recorren las seis parejas, y `data_a` y `data_b` muestran el valor del registro correspondiente en el mismo instante en que cambian las direcciones, porque la lectura es combinacional. Con `addr_a` en 0 y `addr_b` en 2, por ejemplo, se leen 5 y 12.

#### Selector de combinaciones (`tb_comb_selector.v`)

En la captura del selector de combinaciones aparecen `clk`, `siguiente`, `indice`, `addr_a` y `addr_b`, en decimal.

![Simulación del selector de combinaciones](sim/GTKWave_Images/tb_comb_selector.png)

Cada pulso de `siguiente` hace avanzar `indice` en el siguiente flanco de subida de `clk`, y en ese mismo instante `addr_a` y `addr_b` cambian a la nueva pareja, recorriendo (0, 1), (0, 2), (0, 3), (1, 2), (1, 3) y (2, 3). Con el sexto pulso `indice` pasa de 5 a 0 y la pareja vuelve a (0, 1), y en el tramo final, donde no hay pulsos, el índice se mantiene.

#### Antirrebote (`tb_almacenamiento.v`)

La captura del antirrebote muestra `btn`, `ar.estable`, `ar.contador` en decimal y `pulso`, en el tramo de 0 a 1110 ns.

![Simulación del antirrebote](sim/GTKWave_Images/tb_antirrebote.png)

Cerca de los 40 ns `btn` sube durante 3 ciclos, lo que representa un ruido corto. El contador empieza a contar, pero se reinicia en cuanto `btn` vuelve a 0, y `pulso` no se activa.

Entre 250 y 730 ns aproximadamente se simula una pulsación con rebotes, en la que `btn` sube y baja varias veces antes de quedarse en 1. Cada rebote reinicia `contador`, y cuando `btn` se mantiene estable durante 8 ciclos, `estable` pasa a 1 y `pulso` genera un pulso de un ciclo. Al soltar el botón también hay rebotes, pero cuando `estable` vuelve a 0 no se genera ningún pulso.

Entre 720 y 1110 ns una pulsación sin rebotes genera un segundo pulso, lo que confirma que el filtro queda listo después de soltar el botón.

#### Registro del resultado (`tb_almacenamiento.v`)

La captura del registro del resultado muestra `clk`, `ejecutar`, `result_in`, `op_in`, `result` y `op`, en decimal y binario, en el tramo final de la simulación, desde cerca de 1100 ns.

![Simulación del registro del resultado](sim/GTKWave_Images/tb_reg_resultado.png)

Cuando `result_in` pasa a 9, `result` sigue en 0 mientras `ejecutar` permanece en 0. Con el primer pulso de `ejecutar`, `result` toma el valor 9 y `op` el código `000`, y aunque después `result_in` cambia a 5 y `op_in` a `011`, las salidas se mantienen en 9 y `000` hasta el segundo pulso de `ejecutar`, cuando pasan a 5 y `011`. Este es el mecanismo que conserva el resultado en el display hasta que se presiona `BTN3`.

#### LEDs y LED RGB (`tb_indicadores.v`)

La captura de los indicadores muestra `addr_a`, `addr_b`, `led` en binario, `addr_w`, `r`, `g` y `b`, con una prueba cada 10 ns.

![Simulación de los indicadores](sim/GTKWave_Images/tb_indicadores.png)

Entre 0 y 60 ns se recorren las seis parejas, y en cada una `led` tiene en 1 los bits de los dos registros activos y en 0 los demás, con los valores `0011`, `0101`, `1001`, `0110`, `1010` y `1100`.

Entre 60 y 100 ns `addr_w` recorre los valores de 0 a 3 y `{r, g, b}` toma `100` (rojo), `010` (verde), `001` (azul) y `110` (amarillo). Antes de los 60 ns `addr_w` todavía no tiene un valor asignado, por lo que aparece indefinido.

#### Trama del TM1637 (`tb_tm1637_trama.v`)

El TM1637 recibe el resultado como una secuencia de bytes que llega por dos líneas, `CLK` y `DIO`. El módulo `tm1637_driver` arma esa secuencia y la repite de forma continua, y en cada repetición, llamada trama, configura el modo de escritura, envía los cuatro dígitos y enciende el display, en ese orden.

**Estructura de la trama**

Cada trama tiene siete bytes repartidos en tres etapas, y cada etapa empieza con un START y termina con un STOP. La siguiente tabla muestra los bytes de una trama y la función de cada uno.

| `n_byte` | Etapa | Byte | Binario | Función |
| :---: | :---: | :---: | :---: | --- |
| 0 | 1 | `0x40` | `0100 0000` | Comando de datos, identificado por los bits `01`, con el bit 2 en `0` para activar la dirección automática y los bits `00` para indicar escritura en el display |
| 1 | 2 | `0xC0` | `1100 0000` | Comando de dirección, identificado por los bits `11`, con `0000` para que la escritura empiece en el dígito 0, el de la izquierda |
| 2 | 2 | dígito 0 | segmentos | Segmentos del dígito 0 |
| 3 | 2 | dígito 1 | segmentos | Segmentos del dígito 1, que se guardan en la siguiente posición sin enviar otra dirección gracias a la dirección automática |
| 4 | 2 | dígito 2 | segmentos | Segmentos del dígito 2 |
| 5 | 2 | dígito 3 | segmentos | Segmentos del dígito 3 |
| 6 | 3 | `0x8A` | `1000 1010` | Comando de control, identificado por los bits `10`, con el bit 3 en `1` para encender el display y `010` para fijar el brillo en el nivel 2 de una escala de 0 a 7 |

Por esta razón, en el código el STOP va después de los bytes 0, 5 y 6, como indica la señal `stop_despues`, ya que la dirección automática permite enviar `0xC0` y los cuatro dígitos seguidos en una sola etapa.

Los dígitos se envían como el patrón de segmentos que se debe encender, donde el bit 0 corresponde al segmento a, el bit 1 al b y así hasta el bit 6, que corresponde al g, mientras que el bit 7 controla el punto. La siguiente tabla muestra los patrones que aparecen en esta simulación.

| Carácter | Byte | Binario | Segmentos encendidos |
| :---: | :---: | :---: | --- |
| apagado | `0x00` | `0000 0000` | Ninguno |
| `0` | `0x3F` | `0011 1111` | a, b, c, d, e, f |
| `1` | `0x06` | `0000 0110` | b, c |
| `2` | `0x5B` | `0101 1011` | a, b, d, e, g |

**Transmisión de un byte**

La máquina de estados del driver tiene cuatro estados, cada uno dividido en cuatro fases de igual duración. En la simulación, con `DIV` igual a 4, cada fase dura 32 ns, mientras que en la placa, con `DIV` igual a 625, dura 5 µs, lo que da un reloj de 50 kHz en `tm_clk`. La siguiente tabla describe lo que ocurre en cada fase.

| Estado (`estado`) | Fase 0 | Fase 1 | Fase 2 | Fase 3 |
| --- | --- | --- | --- | --- |
| START (0) | `CLK` = 1, `DIO` libre | `DIO` baja con `CLK` en 1 → **START** | — | Pasa a enviar bits |
| BIT (1) | `CLK` baja | Se pone el bit en `DIO` | `CLK` sube → **el TM1637 lee el bit** | Siguiente bit, o ACK después del 8.º |
| ACK (2) | `CLK` baja | El driver suelta `DIO` | `CLK` sube → **el TM1637 responde** | STOP, o siguiente byte |
| STOP (3) | `CLK` baja | `DIO` en 0 | `CLK` sube | `DIO` sube con `CLK` en 1 → **STOP** |

De esta tabla se desprenden cuatro características que se deben observar en la simulación.

- Los datos cambian mientras `CLK` está en 0, en la fase 1 de BIT, y se leen en el flanco de subida de la fase 2, de modo que `DIO` ya está estable cuando el TM1637 lo lee.
- Un cambio de `DIO` con `CLK` en 1 es una señal de control, que corresponde a un START si `DIO` baja y a un STOP si sube. Como los datos nunca cambian con `CLK` en 1, el TM1637 puede distinguir un bit de un START o de un STOP.
- Los bits se envían del menos significativo al más significativo, ya que el driver transmite `dato[n_bit]` con `n_bit` de 0 a 7, por lo que en la onda cada byte aparece escrito al revés.
- `DIO` es una línea de drenador abierto, así que el driver la pone en 0 o la deja libre (`1'bz`) y la resistencia de pull-up la lleva a 1, lo que permite que en el noveno pulso el TM1637 la baje para confirmar que recibió el byte.

Cada byte usa nueve pulsos de `tm_clk`, ocho de datos y uno de ACK. Antes de cada STOP hay un pulso adicional que no lleva información y sirve para dejar `DIO` en 0 antes de subirla, por lo que las etapas 1 y 3 tienen 10 pulsos (9 + 1) y la etapa 2 tiene 46 (5 × 9 + 1).

**Vista completa**

La siguiente captura muestra `tm_clk`, `tm_dio`, `estado`, `n_byte` en decimal, `byte_tx` en hexadecimal, `ack` y `texto` en ASCII, durante el envío de dos tramas de unos 8.8 µs cada una.

![Simulación de la trama del TM1637](sim/GTKWave_Images/tb_tm1637_trama.png)

La siguiente tabla resume la entrada del display, los bytes enviados y el texto que reconstruye el modelo en cada trama.

| Trama | Entrada del display | Bytes enviados | `texto` al terminar |
| :---: | --- | --- | :---: |
| 1 | `op = 000` (suma), `result = 12` | `40` · `C0 00 00 06 5B` · `8A` | `"  12"` |
| 2 | `op = 010` (AND), `result = 0101` | `40` · `C0 3F 06 3F 06` · `8A` | `"0101"` |

En cada trama se distinguen tres grupos de pulsos de `tm_clk`, uno corto para la etapa 1 (cerca de 1.4 µs), uno largo para la etapa 2 (cerca de 6 µs) y otro corto para la etapa 3 (cerca de 1.4 µs). Entre un grupo y otro, `tm_clk` queda en 1 mientras `tm_dio` marca el STOP de una etapa y el START de la siguiente, y a lo largo de la trama `n_byte` avanza de 0 a 6 mientras `byte_tx` muestra el byte que se transmite en cada momento.

La suma se muestra en decimal, con `12` en los dos dígitos de la derecha y los otros dos apagados, y la AND en binario, con un bit por dígito. El modelo actualiza `texto` cuando recibe `0x8A`, es decir, cuando la trama ya está completa, para que el valor mostrado corresponda a los cuatro dígitos de una misma trama.

Los dígitos de una trama no se mezclan aunque `op` y `result` cambien durante el envío, porque al comenzar cada trama, en el START con `n_byte` igual a 0, el driver copia los cuatro dígitos en `buf0` a `buf3` y transmite esa copia. Por eso el cambio de entrada que ocurre al final de la primera trama se refleja en la segunda.

**Detalle de la etapa 2**

La siguiente captura amplía la etapa 2 de la primera trama, en la que `n_byte` va de 1 a 5, entre 1.4 µs y 7.4 µs aproximadamente.

![Detalle de la etapa 2 del TM1637](sim/GTKWave_Images/tb_tm1637_etapa2.png)

La etapa empieza con un START, en el que `tm_dio` baja mientras `tm_clk` está en 1, y a partir de ahí los bits de cada byte se obtienen leyendo `tm_dio` en cada flanco de subida de `tm_clk`, como se resume en la siguiente tabla.

| Byte | `tm_dio` en los pulsos 1 → 8 | Leído del bit 7 al 0 | Pulso 9 |
| :---: | :---: | :---: | :---: |
| `C0` | `0 0 0 0 0 0 1 1` | `1100 0000` | ACK |
| `00` | `0 0 0 0 0 0 0 0` | `0000 0000` | ACK |
| `00` | `0 0 0 0 0 0 0 0` | `0000 0000` | ACK |
| `06` | `0 1 1 0 0 0 0 0` | `0000 0110` | ACK |
| `5B` | `1 1 0 1 1 0 1 0` | `0101 1011` | ACK |

En el noveno pulso de cada byte `ack` está en 1, lo que indica que el modelo del TM1637 baja `tm_dio` para confirmar la recepción después de que el driver la soltó. Cuando `tm_clk` baja, `tm_dio` puede subir un instante por el pull-up antes de que el driver ponga el primer bit del siguiente byte, pero como ese cambio ocurre con `tm_clk` en 0 no se interpreta como un STOP. Después del quinto ACK, el pulso adicional y la subida de `tm_dio` con `tm_clk` en 1 forman el STOP que cierra la etapa.

Entre los cinco bytes no hay START ni STOP, ya que se envían en una sola transmisión continua gracias a la dirección automática configurada con `0x40`.

#### Sistema completo, escritura (`tb_top.v`)

La captura de la escritura en el sistema completo muestra `btn` y `sw` en binario, `dut.pulso` en binario, `dut.addr_w`, los registros R0 a R3 en decimal y los canales `dut.led6_r`, `dut.led6_g` y `dut.led6_b`, en el tramo de 0 a 3.2 µs aproximadamente.

![Escritura en el sistema completo](sim/GTKWave_Images/tb_top_escritura.png)

Para cada registro, `sw` toma el valor que se va a escribir y luego se presionan `BTN1` y `BTN0`, y cada pulsación genera un pulso en `dut.pulso`. Con el pulso de `BTN1` cambia el registro indicado por `addr_w`, y con el de `BTN0` la dirección avanza y el LED RGB cambia de color, hasta que el banco queda con los valores `[5 3 12 9]`.

#### Sistema completo, ejecución y conservación (`tb_top.v`)

La captura de la ejecución muestra `btn` y `sw` en binario, `dut.addr_a`, `dut.addr_b`, `led` en binario, `alu_result` y `resultado` en decimal y `texto` en ASCII, desde cerca de 3.2 µs hasta el final de la simulación.

![Ejecución y conservación en el sistema completo](sim/GTKWave_Images/tb_top_ejecucion.png)

Con la pareja R0, R1 y `sw` en `0000`, que corresponde a la suma, `BTN3` guarda el resultado 8 y `texto` muestra `"   8"`, y con `sw` en `0010`, la AND, se guarda 1 y se muestra `"0001"`.

Después `BTN2` cambia la pareja a R0, R2 y `led` pasa de `0011` a `0101`, y con `sw` en `0100`, la XOR, se guarda 9 y el display muestra `"1001"`.

Para probar la conservación del resultado, `sw` pasa a `0000` y `BTN2` cambia la pareja a R0, R3. `alu_result` cambia con cada movimiento, pero `resultado` y `texto` se mantienen en 9 y `"1001"` porque no se presionó `BTN3`.

Por último, con la pareja R0, R3, `BTN3` ejecuta la suma, que da 14 (`"  14"`), y con `sw` en `0001` la resta 5 − 9, que da la vuelta y resulta en 12 (`"  12"`).

## 6. Implementación en FPGA

### 6.1 Asignación de pines

El archivo `constrs/zybo_z7.xdc` asigna cada puerto de `top.v` a un pin de la Zybo Z7, como se resume en la siguiente tabla.

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

El módulo del display se conecta al Pmod JC con cuatro cables, según la siguiente tabla.

| TM1637 | Pmod JC |
| --- | --- |
| CLK | Pin 1 |
| DIO | Pin 2 |
| GND | Pin 5 |
| VCC | Pin 6 (3.3 V) |

A `tm_dio` se le activa el pull-up interno de la FPGA, ya que la línea es de drenador abierto y necesita una resistencia que la lleve a 1 cuando ningún dispositivo la ocupa.

---

## 7. Evidencia de funcionamiento en FPGA

### 7.1 Video de demostración

El siguiente video muestra el sistema funcionando en la Zybo Z7 con los valores de prueba de la sección 7.2.

https://github.com/user-attachments/assets/5525b1e7-5ded-4990-ac48-e17b8e3314a1

### 7.2 Valores usados en la prueba

Para la prueba en la placa se cargaron en los registros los valores de la siguiente tabla.

| Registro | Valor (binario) | Valor (decimal) |
| :---: | :---: | :---: |
| R0 | `1010` | 10 |
| R1 | `0101` | 5 |
| R2 | `0011` | 3 |
| R3 | `1000` | 8 |

---

## 8. Análisis de resultados

### 8.1 Lo que se observa en el video

En el video se pueden distinguir cinco partes del funcionamiento del sistema, que se describen a continuación en el orden en que aparecen.

1. La carga de los valores de la sección 7.2 en R0 a R3 con `SW[3:0]`, `BTN0` y `BTN1`, durante la cual el LED RGB cambia de color al cambiar de registro.
2. El cambio de pareja de operandos con `BTN2`, con los LEDs indicando los registros activos.
3. La ejecución de la suma y la resta con `BTN3`, con el resultado en decimal.
4. La ejecución de las operaciones lógicas, con el resultado en binario.
5. La conservación del resultado, ya que al cambiar los switches y la pareja sin presionar `BTN3` el display mantiene el último resultado.

### 8.2 Resultados esperados con los valores de prueba

Las siguientes tablas presentan los resultados que se esperan en el display para las parejas R0, R1 y R0, R2 con los valores de prueba.

**Pareja R0, R1** (`A = 1010`, `B = 0101`)

| Operación | Resultado | Display |
| --- | :---: | :---: |
| Suma | 15 | `  15` |
| Resta | 5 | `   5` |
| AND | `0000` | `0000` |
| OR | `1111` | `1111` |
| XOR | `1111` | `1111` |
| XNOR | `0000` | `0000` |
| NOT | `0101` | `0101` |
| NAND | `1111` | `1111` |

R0 y R1 son complementarios, es decir, no comparten ningún bit en 1, y por eso AND da `0000` mientras que OR y XOR dan `1111`.

**Pareja R0, R2** (`A = 1010`, `B = 0011`)

| Operación | Resultado | Display |
| --- | :---: | :---: |
| Suma | 13 | `  13` |
| Resta | 7 | `   7` |
| AND | `0010` | `0010` |
| OR | `1011` | `1011` |
| XOR | `1001` | `1001` |
| XNOR | `0110` | `0110` |
| NOT | `0101` | `0101` |
| NAND | `1101` | `1101` |

El resultado de NOT es el mismo en ambas parejas porque depende de `A`, que en las dos es R0.

### 8.3 Observaciones

- **Coincidencia entre simulación y hardware.** Los valores que muestra la placa coinciden con los esperados y con los obtenidos en la simulación.
- **Aritmética de 4 bits.** La suma y la resta trabajan con 4 bits, por lo que un resultado mayor que 15 pierde el acarreo y una resta con `B` mayor que `A` da la vuelta, ya que el diseño no representa números negativos. Para mostrarlos haría falta que la ALU entregara un bit de préstamo, porque con 4 bits de resultado no se puede distinguir, por ejemplo, un 14 de un −2.
- **Uso de los switches para la operación.** Al terminar de cargar datos, los switches quedan con el último valor escrito, que también es un código de operación válido, de modo que si se presiona `BTN3` sin cambiarlos se ejecuta esa operación y no la que se pretendía.
- **Antirrebote.** Sin este módulo, una sola pulsación produciría varios cambios de registro o de pareja, mientras que con el filtro de 10 ms cada pulsación produce un solo pulso.

---

## 9. Conclusiones

- **Funcionamiento del sistema.** El sistema tuvo el comportamiento esperado, ya que los registros almacenaron los datos, el selector recorrió las seis parejas con `BTN2`, la ALU ejecutó las ocho operaciones al presionar `BTN3` y el display conservó el último resultado hasta una nueva ejecución.
- **Diseño modular.** Dividir el sistema en bloques pequeños, cada uno con una función, permitió probarlos por separado con su propio testbench antes de integrarlos, mientras que `top.v` se limitó a instanciar y conectar los módulos, sin lógica propia.
- **Simulación antes de implementar.** Verificar cada módulo y el sistema completo en simulación permitió encontrar errores antes de programar la FPGA, donde depurar es más lento porque no se pueden observar las señales internas.
- **Conservación del resultado.** Guardar en `reg_resultado` el resultado y el código de operación aisló el display de los cambios en los switches, los registros y la pareja de operandos, y guardar la operación evitó que el formato del display cambiara al mover los switches.
- **Estrategia de visualización.** El formato decimal facilita la lectura del resultado de la suma y la resta, mientras que el binario permite comprobar bit a bit las operaciones lógicas aprovechando los cuatro dígitos del display.
- **Comunicación con el TM1637.** El display requirió implementar un protocolo serie de dos líneas parecido a I2C, con condiciones de START y STOP, envío del bit menos significativo primero y confirmación (ACK) por parte del receptor, y simularlo con un modelo del chip permitió verificar la trama bit a bit.
- **Flujo de diseño.** El desarrollo siguió el flujo completo de un sistema digital, desde la especificación y el diseño hasta la simulación y la implementación.

## 10. Referencias



1. Titan Micro Electronics, *TM1637 LED Drive Control Special Circuit*, hoja de datos.
2. Digilent, *Zybo Z7 Reference Manual*. Disponible en https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual
3. Digilent, *Zybo-Z7-Master.xdc*, archivo de restricciones de referencia para la Zybo Z7. Disponible en https://github.com/Digilent/digilent-xdc
4. S. Williams, *Icarus Verilog*, documentación. Disponible en https://steveicarus.github.io/iverilog/
5. T. Bybell, *GTKWave*, documentación. Disponible en https://gtkwave.sourceforge.net/
6. AMD Xilinx, *Vivado Design Suite User Guide: Using Constraints* (UG903).
