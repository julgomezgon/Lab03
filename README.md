# Lab03 – ALU + Banco de Registros + Diseño Modular

## Integrantes

- Julian David Gomez Gonzalez - 1007544331
- Cristian Norbey Hernández Gualteros - 1001091723
- Milton Nicolas Rincón Caicedo - 1021312724

**Semestre:** 2026-2
**Plataforma:** Digilent Zybo Z7 (Zynq-7000)

---

## Índice

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Arquitectura modular](#2-arquitectura-modular)
3. [Interfaz de usuario](#3-interfaz-de-usuario)
4. [Estrategia de visualización](#4-estrategia-de-visualización)
5. [Simulación en GTKWave](#5-simulación-en-gtkwave)
6. [Evidencia de funcionamiento en FPGA](#6-evidencia-de-funcionamiento-en-fpga)
7. [Análisis de resultados](#7-análisis-de-resultados)
8. [Conclusiones](#8-conclusiones)

---

## 1. Descripción del sistema

Se implementó un sistema digital de 4 bits sobre la FPGA Zybo Z7, construido a partir de módulos independientes que se integran en un archivo superior `top.v`. El sistema está compuesto por:

- Un **banco de 4 registros** de 4 bits (`R0`–`R3`).
- Una **ALU de 4 bits** con operaciones aritméticas y lógicas.
- Un **selector automático de combinaciones** de operandos `(A, B)`.
- Un **driver de display de 7 segmentos TM1637** para mostrar el resultado.

El sistema permite:

1. Almacenar valores en los registros usando los switches.
2. Recorrer las combinaciones de registros que actúan como operandos.
3. Ejecutar la operación seleccionada entre los registros activos.
4. Visualizar el resultado en el display.

El resultado mostrado **solo se actualiza al presionar `BTN3`**. Mientras no se ejecute una nueva operación, el display conserva el resultado de la última ejecución, aunque cambien los operandos, la combinación seleccionada o la operación de la ALU.

---

## 2. Arquitectura modular

### 2.1 Descripción de los módulos

| Módulo | Archivo | Función |
| --- | --- | --- |
| ALU | `src/alu.v` | Recibe los operandos `A`, `B` y el código de operación; entrega el resultado. Es combinacional. |
| Banco de registros | `src/reg_bank.v` | 4 registros de 4 bits. Escritura controlada por `write_enable`; lectura de dos registros según `addr_a` y `addr_b`. |
| Selector de combinaciones | `src/comb_selector.v` | Genera las parejas de registros `(A, B)` a partir de un índice interno que avanza con `BTN2`. |
| Driver del display | `src/display_tm1637.v` | Convierte el resultado almacenado a dígitos y lo envía al TM1637 mediante el protocolo serie `CLK`/`DIO`. |
| Top | `src/top.v` | Instancia y conecta los módulos con las entradas/salidas físicas. No contiene lógica compleja. |

### 2.2 Operaciones de la ALU

La operación se selecciona con `SW[2:0]`:

| `SW[2:0]` | Operación | Tipo | Formato en display |
| :---: | --- | --- | :---: |
| `000` | Suma `A + B` | Aritmética | Decimal |
| `001` | Resta `A - B` | Aritmética | Decimal |
| `010` | AND `A & B` | Lógica | Binario |
| `011` | OR `A \| B` | Lógica | Binario |
| `100` | XOR `A ^ B` | Lógica | Binario |
| `101` | NOT `~A` | Lógica | Binario |
| `110` | _(completar)_ | Lógica | Binario |
| `111` | _(completar)_ | Lógica | Binario |

### 2.3 Combinaciones de operandos

Cada pulsación de `BTN2` avanza el índice interno del selector:

| Índice | A | B | LEDs encendidos |
| :---: | :---: | :---: | :---: |
| 0 | R0 | R1 | LED0, LED1 |
| 1 | R0 | R2 | LED0, LED2 |
| 2 | R0 | R3 | LED0, LED3 |
| 3 | R1 | R2 | LED1, LED2 |
| 4 | R1 | R3 | LED1, LED3 |
| 5 | R2 | R3 | LED2, LED3 |

---

## 3. Interfaz de usuario

| Elemento | Función |
| --- | --- |
| `SW[3:0]` | Dato de entrada (4 bits) para escribir en el registro seleccionado. |
| `SW[2:0]` | Selección de la operación de la ALU. |
| `BTN0` | Selecciona el registro de escritura (`R0 → R1 → R2 → R3 → R0`). |
| `BTN1` | Escribe el dato de `SW[3:0]` en el registro seleccionado. |
| `BTN2` | Cambia la combinación de operandos `(A, B)`. |
| `BTN3` | Ejecuta la operación y actualiza el resultado en el display. |
| `LED[3:0]` | Indican los registros activos en la operación. |
| LED RGB | Indica el registro seleccionado para escritura. |
| Display TM1637 | Muestra el resultado de la última operación ejecutada. |

**Código de colores del LED RGB:**

| Registro | Color |
| :---: | :---: |
| R0 | _rojo_ |
| R1 | _verde_ |
| R2 | _azul_ |
| R3 | _amarillo_ |

---

## 4. Estrategia de visualización

Se utilizan **dos sistemas de representación** según el tipo de operación, buscando que el resultado sea lo más fácil de interpretar:

### 4.1 Operaciones aritméticas → Decimal

La **suma** y la **resta** se muestran en **formato decimal**, ya que el usuario interpreta naturalmente estas operaciones como cantidades numéricas.

| Operación | A | B | Resultado | Display |
| --- | :---: | :---: | :---: | :---: |
| Suma | 7 | 5 | 12 | `12` |
| Suma | 3 | 8 | 11 | `11` |
| Resta | 9 | 4 | 5 | `5` |
| Resta | 3 | 8 | -5 | `-5` |

### 4.2 Operaciones lógicas → Binario

Las operaciones lógicas (AND, OR, XOR, NOT, etc.) se muestran en **formato binario**, aprovechando que el TM1637 tiene 4 dígitos y el resultado tiene 4 bits. Así, cada dígito representa un bit y se puede verificar la operación bit a bit.

| Operación | A | B | Resultado | Display |
| --- | :---: | :---: | :---: | :---: |
| AND | `1100` | `1010` | `1000` | `1000` |
| OR | `1100` | `1010` | `1110` | `1110` |
| XOR | `1100` | `1010` | `0110` | `0110` |
| NOT | `1100` | — | `0011` | `0011` |

### 4.3 Retención del resultado

Al presionar `BTN3` se capturan en un registro **el resultado de la ALU y el código de operación**. El driver del display usa el código capturado para decidir el formato (decimal o binario), de modo que el valor mostrado no cambia si después se modifican los switches, los registros o la combinación.

---

## 5. Simulación en GTKWave

### 5.1 Pruebas individuales por módulo

| Módulo | Testbench | Qué se verifica |
| --- | --- | --- |
| `alu.v` | `sim/tb_alu.v` | Resultado de cada operación. |
| `reg_bank.v` | `sim/tb_reg_bank.v` | Escritura con `write_enable` y lectura por dirección. |
| `comb_selector.v` | `sim/tb_comb_selector.v` | Secuencia de combinaciones `(A, B)`. |
| `display_tm1637.v` | `sim/tb_display_tm1637.v` | Conversión a dígitos y trama serie. |

### 5.2 Testbench del sistema completo

### 5.3 Capturas de GTKWave

#### Escritura en el banco de registros

![Escritura en registros](doc/gtkwave_reg_bank.png)

_Descripción:_ _(completar)_

#### Combinaciones de operandos

![Combinaciones de operandos](doc/gtkwave_comb_selector.png)

_Descripción:_ _(completar)_

#### Operaciones de la ALU

![Operaciones ALU](doc/gtkwave_alu.png)

_Descripción:_ _(completar)_

#### Retención del resultado con BTN3

![Retención del resultado](doc/gtkwave_hold.png)

_Descripción:_ _(completar)_

---

## 6. Evidencia de funcionamiento en FPGA

### 6.1 Video de demostración

https://github.com/user-attachments/assets/5525b1e7-5ded-4990-ac48-e17b8e3314a1

### 6.2 Valores usados en la prueba

| Registro | Valor (binario) | Valor (decimal) |
| :---: | :---: | :---: |
| R0 | `1010` | 10 |
| R1 | `0101` | 5 |
| R2 | `0011` | 3 |
| R3 | `1000` | 8 |

## 7. Análisis de resultados

En el video se muestra:

1. La carga de los valores de la tabla 6.2 en los registros `R0`–`R3` usando `SW[3:0]`, `BTN0` y `BTN1`. El LED RGB indica el registro seleccionado.
2. El cambio de combinación de operandos con `BTN2`. Los LEDs muestran los registros activos.
3. La ejecución de la suma y la resta con `BTN3`, con el resultado en **decimal**.
4. La ejecución de las operaciones lógicas (AND, OR, XOR, NOT), con el resultado en **binario**.
5. La retención del resultado: se cambian los switches y la combinación sin presionar `BTN3`, y el display mantiene el último resultado.

En general, el sistema funcionó correctamente en todas las pruebas.

## 8. Conclusiones

- **Funcionamiento completo:** el sistema cumplió con todos los requerimientos de la guía. Los registros almacenaron correctamente los datos, el selector recorrió las combinaciones de operandos con `BTN2`, la ALU ejecutó todas las operaciones al presionar `BTN3` y el display conservó el último resultado hasta una nueva ejecución.
- **Simulación y hardware coinciden:** los resultados observados en la Zybo Z7 coincidieron con los obtenidos en la simulación en GTKWave, lo que confirma que validar el diseño antes de pasar a la FPGA permite detectar errores a tiempo y reduce la depuración en hardware.
- **Ventajas del diseño modular:** dividir el sistema en ALU, banco de registros, selector de combinaciones y driver del display permitió desarrollar y probar cada bloque por separado. El `top.v` se limitó a conectar los módulos, lo que hizo el diseño más ordenado, fácil de depurar y reutilizable.
- **Retención del resultado:** guardar en un registro el resultado y el código de operación al presionar `BTN3` aisló la visualización de los cambios en switches, registros y combinaciones, garantizando que el display solo cambiara con una nueva ejecución.
- **Estrategia de visualización adecuada:** mostrar la suma y la resta en decimal facilitó la lectura de cantidades numéricas, incluidos los resultados negativos, mientras que el formato binario para las operaciones lógicas permitió verificar el resultado bit a bit aprovechando los 4 dígitos del TM1637.
- **Flujo de diseño completo:** el laboratorio permitió aplicar el flujo real de un sistema digital: especificación → diseño → simulación → implementación.

---
