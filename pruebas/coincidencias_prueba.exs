# Pruebas del puntaje de coincidencias de mascotas (funciones puras).
# Ejecutar: elixir -pa ebin pruebas/coincidencias_prueba.exs
ExUnit.start()

defmodule CoincidenciasPrueba do
  use ExUnit.Case

  defp mascota(id, tipo, especie, nombre, color, tamano, zona, caracteristicas \\ "") do
    Mascota.crear(id, tipo, especie, nombre, caracteristicas, color, tamano, zona, "300")
  end

  test "ejemplo del enunciado: misma zona, color y tamaño = 75" do
    perdida = mascota("MA001", "perdida", "perro", "Luna", "negra", "mediana", "zona_norte")
    encontrada = mascota("MA002", "encontrada", "perro", "desconocido", "negra", "mediana", "zona_norte")
    assert Coincidencias.calcular_puntaje(perdida, encontrada) == 75
  end

  test "reportes iguales con nombre y características = 100" do
    perdida = mascota("MA001", "perdida", "gato", "Michi", "gris", "pequeno", "sur", "collar rojo")
    encontrada = mascota("MA002", "encontrada", "gato", "michi", "Gris", "pequeno", "sur", "Collar ROJO, cojea")
    assert Coincidencias.calcular_puntaje(perdida, encontrada) == 100
  end

  test "las palabras en común se cuentan recursivamente" do
    assert Coincidencias.palabras_en_comun(["collar", "rojo", "cojea"], ["rojo", "collar"]) == 2
    assert Coincidencias.palabras_en_comun([], ["rojo"]) == 0
  end

  test "distinta especie no es candidata" do
    perdida = mascota("MA001", "perdida", "perro", "Luna", "negra", "mediana", "norte")
    encontrada = mascota("MA002", "encontrada", "gato", "Luna", "negra", "mediana", "norte")
    assert Coincidencias.pares_candidatos([perdida], [encontrada]) == []
  end

  test "umbral: 45 no pasa, 50 sí pasa" do
    perdida = mascota("MA001", "perdida", "perro", "Luna", "negra", "mediana", "norte")
    # solo color (25) + tamaño (20) = 45
    lejos = mascota("MA002", "encontrada", "perro", "desconocido", "negra", "mediana", "sur")
    # zona (30) + tamaño (20) = 50
    cerca = mascota("MA003", "encontrada", "perro", "desconocido", "cafe", "mediana", "norte")

    assert Coincidencias.calcular_puntaje(perdida, lejos) == 45
    assert Coincidencias.calcular_puntaje(perdida, cerca) == 50
    assert [{^perdida, ^cerca, 50}] = Coincidencias.pares_candidatos([perdida], [lejos, cerca])
  end

  test "los pares quedan ordenados por puntaje y se ignoran los resueltos" do
    p1 = mascota("MA001", "perdida", "perro", "Luna", "negra", "mediana", "norte")
    e1 = mascota("MA002", "encontrada", "perro", "Luna", "negra", "mediana", "norte")
    e2 = mascota("MA003", "encontrada", "perro", "desconocido", "negra", "grande", "norte")
    resuelta = %{e1 | id: "MA004", estado: "resuelta"}

    pares = Coincidencias.pares_candidatos([p1], [e2, resuelta, e1])
    assert Enum.map(pares, fn {_p, e, puntaje} -> {e.id, puntaje} end) == [{"MA002", 90}, {"MA003", 55}]
  end
end
