def cuenta_simulada(palabra_objetivo, palabras, inicio, fin, profundidad=0):
    if inicio > fin:
        return None, profundidad

    medio = (inicio + fin) // 2
    palabra_actual = palabras[medio]

    ascii_val = ord(palabra_actual[0])
    if palabra_objetivo == palabra_actual:
        return ascii_val, profundidad + 1

    if palabra_objetivo < palabra_actual:
        resultado, prof = cuenta_simulada(palabra_objetivo, palabras, inicio, medio - 1, profundidad + 1)
    else:
        resultado, prof = cuenta_simulada(palabra_objetivo, palabras, medio + 1, fin, profundidad + 1)

    if resultado is None:
        return None, prof

    return ascii_val + resultado, prof


def main():
    try:
        with open("palabras.txt", "r", encoding="utf-8") as f:
            palabras = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print("Error: No se encontró el archivo 'palabras.txt'.")
        return

    print(f"{'Palabra':<20} {'Resultado':<10} {'Recursiones'}")
    print("-" * 45)

    for palabra in palabras:
        resultado, profundidad = cuenta_simulada(palabra, palabras, 0, len(palabras) - 1)
        if resultado is not None and 401 <= resultado <= 799:
            print(f"{palabra:<20} {resultado:<10} {profundidad}")


if __name__ == "__main__":
    main()
