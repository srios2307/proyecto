# Ejecuta TODAS las pruebas del proyecto.
# Uso (desde la carpeta proyecto_final, después de compilar):
#   elixir -pa ebin pruebas/todas.exs
#
# Code.require_file (NO visto en clase) carga y ejecuta otro script .exs, igual que
# si se escribiera su contenido aquí. Cada archivo define su módulo de pruebas y
# ExUnit los ejecuta todos al final.
ExUnit.start()

[
  "transiciones_prueba.exs",
  "permisos_prueba.exs",
  "analizador_comandos_prueba.exs",
  "validaciones_prueba.exs",
  "arbol_zonas_prueba.exs",
  "prioridades_prueba.exs",
  "coincidencias_prueba.exs",
  "servidores_prueba.exs",
  "supervision_prueba.exs",
  "concurrencia_prueba.exs",
  "consola_prueba.exs"
]
|> Enum.each(fn archivo -> __DIR__ |> Path.join(archivo) |> Code.require_file() end)
