defmodule AnalizadorComandos do
  @moduledoc """
  Convierte la línea que escribe el usuario en una tupla `{comando, argumentos}`.
  Funciones puras.

  - Los argumentos se separan por espacios, pero un texto entre comillas es UN solo
    argumento: `send_family_message 123 "Estoy bien, en el albergue"` → 2 argumentos.
  - En los comandos de consulta, los filtros `clave=valor` se juntan en un mapa que
    queda como ÚLTIMO argumento: `list_needs zona=centro` → `{:list_needs, [%{"zona" => "centro"}]}`.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Texto que escribe el usuario → átomo del comando. Se usa un mapa fijo para no
  # crear átomos nuevos con lo que escriba el usuario.
  @comandos %{
    "connect" => :connect,
    "disconnect" => :disconnect,
    "use" => :use,
    "sessions" => :sessions,
    "help" => :help,
    "exit" => :exit,
    "register_zone" => :register_zone,
    "register_sector" => :register_sector,
    "register_point" => :register_point,
    "list_zones" => :list_zones,
    "zone_status" => :zone_status,
    "zone_stats" => :zone_stats,
    "register_center" => :register_center,
    "list_centers" => :list_centers,
    "register_need" => :register_need,
    "list_needs" => :list_needs,
    "update_need" => :update_need,
    "pending_needs" => :pending_needs,
    "next_need" => :next_need,
    "assign_resource" => :assign_resource,
    "register_resource" => :register_resource,
    "list_resources" => :list_resources,
    "resource_in" => :resource_in,
    "resource_out" => :resource_out,
    "transfer_resource" => :transfer_resource,
    "resource_history" => :resource_history,
    "critical_resources" => :critical_resources,
    "report_person" => :report_person,
    "update_person" => :update_person,
    "find_person" => :find_person,
    "person_history" => :person_history,
    "send_family_message" => :send_family_message,
    "list_family_messages" => :list_family_messages,
    "mark_message" => :mark_message,
    "report_pet" => :report_pet,
    "list_pets" => :list_pets,
    "match_pets" => :match_pets,
    "confirm_pet_match" => :confirm_pet_match,
    "discard_pet_match" => :discard_pet_match,
    "register_shelter" => :register_shelter,
    "check_shelter" => :check_shelter,
    "register_entry" => :register_entry,
    "register_exit" => :register_exit,
    "shelter_report" => :shelter_report,
    "summary" => :summary,
    "list_users" => :list_users,
    "activity" => :activity,
    "crash_server" => :crash_server
  }

  # Comandos en los que `clave=valor` es un filtro.
  @comandos_con_filtros [:list_needs, :list_resources, :find_person, :list_pets]

  @doc """
  Analiza una línea de la consola.

  ## Retorna
    - `{comando, argumentos}` con `comando` como átomo y `argumentos` como lista
    - `{:vacio, []}` si la línea está vacía
    - `{:desconocido, [nombre]}` si el comando no existe
    - `{:error, :comillas_sin_cerrar}` si falta cerrar unas comillas

  ## Ejemplo
      AnalizadorComandos.analizar("register_need agua 30 critica centro \\"Punto 3\\"")
      # {:register_need, ["agua", "30", "critica", "centro", "Punto 3"]}
  """
  def analizar(linea) do
    linea
    |> separar()
    |> construir_comando()
  end

  defp construir_comando({:error, motivo}), do: {:error, motivo}
  defp construir_comando({:ok, []}), do: {:vacio, []}

  defp construir_comando({:ok, [nombre | argumentos]}) do
    @comandos
    |> Map.get(String.downcase(nombre))
    |> armar_tupla(nombre, argumentos)
  end

  defp armar_tupla(nil, nombre, _argumentos), do: {:desconocido, [nombre]}

  defp armar_tupla(comando, _nombre, argumentos) when comando in @comandos_con_filtros do
    {comando, convertir_filtros(argumentos)}
  end

  defp armar_tupla(comando, _nombre, argumentos), do: {comando, argumentos}

  @doc """
  Separa una línea en palabras respetando los textos entre comillas.

  ## Retorna
    - `{:ok, lista_de_palabras}` o `{:error, :comillas_sin_cerrar}`
  """
  def separar(linea) do
    linea
    |> String.graphemes()
    |> separar("", false, [])
  end

  # RECURSIVA: tokenizador propio. Recorre los caracteres uno por uno.
  #   - actual: la palabra que se está armando
  #   - dentro_de_comillas: true si estamos dentro de "..."
  #   - acumulado: palabras ya terminadas
  # Casos base: se acabaron los caracteres.
  defp separar([], "", false, acumulado), do: {:ok, acumulado}
  defp separar([], actual, false, acumulado), do: {:ok, acumulado ++ [actual]}
  defp separar([], _actual, true, _acumulado), do: {:error, :comillas_sin_cerrar}

  # Casos recursivos:
  # unas comillas abren o cierran el texto (no se guardan)
  defp separar(["\"" | resto], actual, dentro_de_comillas, acumulado) do
    separar(resto, actual, not dentro_de_comillas, acumulado)
  end

  # un espacio, un tabulador o la marca invisible "﻿" (BOM, que algunas terminales
  # ponen al inicio del texto) fuera de comillas termina la palabra actual
  defp separar([caracter | resto], actual, false, acumulado) when caracter in [" ", "\t", "﻿"] do
    separar(resto, "", false, agregar_palabra(acumulado, actual))
  end

  # cualquier otro carácter (o un espacio dentro de comillas) se pega a la palabra
  defp separar([caracter | resto], actual, dentro_de_comillas, acumulado) do
    separar(resto, actual <> caracter, dentro_de_comillas, acumulado)
  end

  # Varios espacios seguidos no generan palabras vacías.
  defp agregar_palabra(acumulado, ""), do: acumulado
  defp agregar_palabra(acumulado, palabra), do: acumulado ++ [palabra]

  @doc """
  Separa los argumentos normales de los filtros `clave=valor`. Si hay filtros, el
  mapa queda como último argumento.

  ## Ejemplo
      AnalizadorComandos.convertir_filtros(["zona=centro", "prioridad=critica"])
      # [%{"zona" => "centro", "prioridad" => "critica"}]
  """
  def convertir_filtros(argumentos), do: convertir_filtros(argumentos, [], %{})

  # RECURSIVA: caso base sin argumentos → arma el resultado.
  defp convertir_filtros([], posicionales, filtros) when filtros == %{}, do: posicionales
  defp convertir_filtros([], posicionales, filtros), do: posicionales ++ [filtros]

  # Caso recursivo: si el argumento tiene "=", es un filtro; si no, es normal.
  defp convertir_filtros([argumento | resto], posicionales, filtros) do
    argumento
    |> String.split("=", parts: 2)
    |> clasificar_argumento(argumento, resto, posicionales, filtros)
  end

  defp clasificar_argumento([clave, valor], _argumento, resto, posicionales, filtros) when clave != "" do
    convertir_filtros(resto, posicionales, Map.put(filtros, String.downcase(clave), valor))
  end

  defp clasificar_argumento(_partes, argumento, resto, posicionales, filtros) do
    convertir_filtros(resto, posicionales ++ [argumento], filtros)
  end
end
