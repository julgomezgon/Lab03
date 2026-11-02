# Lab03 – ALU + Banco de Registros + Diseño Modular

## Integrantes

- Julian David Gomez Gonzalez - 1007544331
- Cristian Norbey Hernández Gualteros - 1001091723
- Milton Nicolas Rincón Caicedo - 1021312724

**Semestre:** 2026-2
**Plataforma:** Digilent Zybo Z7-10 (Zynq-7000, `xc7z010clg400-1`)
**Herramientas:** Vivado, Icarus Verilog, GTKWave

---

## Índice

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Estructura del repositorio](#2-estructura-del-repositorio)
3. [Arquitectura modular](#3-arquitectura-modular)
4. [Interfaz de usuario](#4-interfaz-de-usuario)
5. [Estrategia de visualización](#5-estrategia-de-visualización)
6. [Simulación](#6-simulación)
7. [Implementación en FPGA](#7-implementación-en-fpga)
8. [Evidencia de funcionamiento en FPGA](#8-evidencia-de-funcionamiento-en-fpga)
9. [Análisis de resultados](#9-análisis-de-resultados)
10. [Conclusiones](#10-conclusiones)



## 8. Evidencia de funcionamiento en FPGA

### 8.1 Video de demostración

https://github.com/user-attachments/assets/5525b1e7-5ded-4990-ac48-e17b8e3314a1

### 8.2 Valores usados en la prueba

| Registro | Valor (binario) | Valor (decimal) |
| :---: | :---: | :---: |
| R0 | `1010` | 10 |
| R1 | `0101` | 5 |
| R2 | `0011` | 3 |
| R3 | `1000` | 8 |

---

## 9. Análisis de resultados

### 9.1 Lo que se observa en el video

1. La carga de los valores de la tabla 8.2 en `R0`–`R3` con `SW[3:0]`, `BTN0` y `BTN1`. El LED RGB cambia de color al cambiar de registro.
2. El cambio de pareja de operandos con `BTN2`. Los LEDs indican los registros activos.
3. La ejecución de la suma y la resta con `BTN3`, con el resultado en decimal.
4. La ejecución de las operaciones lógicas, con el resultado en binario.
5. La conservación del resultado: al cambiar los switches y la pareja sin presionar `BTN3`, el display mantiene el último resultado.

### 9.2 Resultados esperados con los valores de prueba

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

### 9.3 Observaciones

- **Coincidencia entre simulación y hardware:** los valores mostrados en la placa coinciden con los esperados y con los de la simulación.
- **Aritmética de 4 bits:** la suma y la resta trabajan en módulo 16. Un resultado mayor que 15 pierde el acarreo y una resta con `B > A` da la vuelta, ya que el diseño no representa números negativos. Para mostrarlos haría falta que la ALU entregara un bit de préstamo, porque con solo 4 bits de resultado no se puede distinguir, por ejemplo, un 14 de un −2.
- **Uso de los switches para la operación:** al terminar de cargar datos, los switches quedan con el último valor escrito, que también es un código de operación válido. Si se presiona `BTN3` sin cambiarlos, se ejecuta esa operación, no la que se pretendía.
- **Antirrebote:** sin él, una sola pulsación produciría varios cambios de registro o de pareja. Con el filtro de 10 ms, cada pulsación produce exactamente un pulso.

---

## 10. Conclusiones

- **Funcionamiento completo:** el sistema cumplió los requerimientos de la guía. Los registros almacenaron los datos, el selector recorrió las 6 parejas con `BTN2`, la ALU ejecutó las 8 operaciones al presionar `BTN3` y el display conservó el último resultado hasta una nueva ejecución.
- **Diseño modular:** dividir el sistema en bloques pequeños con una sola función permitió probar cada uno por separado con su propio testbench antes de integrarlos. `top.v` se limitó a instanciar y conectar, sin lógica propia.
- **Simulación antes de implementar:** verificar cada módulo y el sistema completo en simulación permitió encontrar errores antes de programar la FPGA, donde depurar es más lento porque no se ven las señales internas.
- **Conservación del resultado:** guardar el resultado **y** el código de operación en `reg_resultado` aisló el display de los cambios en los switches, los registros y la pareja de operandos. Guardar también la operación evita que el formato del display (decimal o binario) cambie al mover los switches.
- **Estrategia de visualización:** el formato decimal facilita leer el resultado de la suma y la resta, mientras que el binario permite comprobar las operaciones lógicas bit a bit aprovechando los 4 dígitos del display.
- **Interfaz con periféricos:** el TM1637 requirió implementar un protocolo serie de dos hilos parecido a I2C, con condiciones de START y STOP, bit menos significativo primero y confirmación (ACK) del receptor. Simularlo con un modelo del chip permitió verificar la trama bit a bit.
- **Flujo de diseño:** el laboratorio aplicó el flujo completo de un sistema digital: especificación → diseño → simulación → implementación.
