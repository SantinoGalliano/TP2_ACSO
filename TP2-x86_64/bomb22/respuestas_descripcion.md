Nombre: Santino Galliano  
Mail: sgalliano@udesa.edu.ar  

---

## FASE 1

La función `phase_1` compara la línea ingresada con una cadena constante embebida en el ejecutable.  
Se usa `strings_not_equal` para comparar el input con un string ubicado en `0x4c9a60`. Usamos `x/s` en GDB para ver la cadena que se espera, y obtuvimos:

> "Junta esperencia en la vida  Porque nada ensenha tanto Como el sufrir y el llorar"

Al ingresar exactamente esta cadena como input, la fase fue desactivada correctamente sin que explotara la bomba.

---

## FASE 2

Primero analizamos el ensamblado de la función `phase_2`, observando que recibía como argumento una línea de texto (cadena de caracteres), probablemente tres números separados por espacio.  
Esto lo dedujimos al ver múltiples llamadas a una función que separa la línea (`call 4011c0`), y luego tres llamadas a `__strtol`, lo que confirmó que se trataba de tres números, que llamamos `x`, `y` y `z`.

A continuación, notamos esta operación:

```
xor ebx, ebp  ; x ^ y
sar ebx, 1    ; (x ^ y) >> 1
cmp ebx, eax  ; comparar con z
```

Eso nos indicó que se estaba calculando `(x ^ y) >> 1` y comparando con `z`.  
Por lo tanto, la primera condición era:

```
((x ^ y) >> 1) == z
```

Después, se llamaba a la función auxiliar `misterio`, que hacía lo siguiente:

```
test edi, edi
js   <ret>
call explode_bomb
```

Lo que indica que si `z >= 0`, la bomba explota. Es decir:

```
z < 0
```

Probando valores que cumplieran ambas condiciones, encontramos que:

```
-3 1 -2
```

era una solución válida para desactivar la fase 2.

---

## FASE 3

Esta fase comienza con:

```
call __isoc99_sscanf
→ formato "%s %d"
```

Esto nos indica que el programa espera como entrada:

```
una_palabra un_numero
```

Posteriormente, se llama a la función `readlines`, que carga un archivo llamado `palabras.txt`. Este archivo es un arreglo ordenado de palabras. Luego, la función `cuenta` realiza una búsqueda binaria **recursiva** para encontrar esa palabra.

El comportamiento observado en `cuenta` es el siguiente:

1. Se accede al primer carácter de la palabra actual:
    ```
    movzx r13d, BYTE PTR [r13]
    movsx eax, r13b
    ```
    Lo cual significa que se toma el **valor ASCII** del primer carácter de la palabra.

2. Se hace una comparación para ver si la palabra coincide, si no, se sigue recursivamente a la izquierda o derecha como una búsqueda binaria.

3. En cada paso, se **suma** el valor ASCII de ese primer carácter:

    ```
    add eax, r13d
    ```

4. Finalmente, en `phase_3`, se valida que:
    - El resultado final (`eax`) esté entre **401 y 799**
    - El número ingresado por el usuario coincida con el valor retornado por `cuenta`

Si alguna de esas condiciones no se cumple, se llama a `explode_bomb`.

Ejecutando el script se encontraron múltiples combinaciones válidas, por ejemplo:

```
interrogar 739
```

Esto cumple todas las condiciones, y fue validado en GDB como una solución correcta.
