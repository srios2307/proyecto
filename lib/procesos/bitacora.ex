defmodule Bitacora do
  @moduledoc """
  Proceso SIMPLE (sin GenServer) que registra la actividad de cada usuario en
  `actividad.log`. Está hecho igual que la "caja registradora" de la Guía 12:
  `spawn_link` + un `loop/1` recursivo con `receive`, registrado con el nombre `:bitacora`.

  Mensajes que entiende:
    - `{:registrar, usuario, comando, resultado}`: agrega una línea al archivo (asíncrono).
    - `{:consultar, usuario, remitente}`: responde `{:actividad, lista}` al remitente.

  Supervisión: `iniciar/1` retorna `{:ok, pid}`, que es lo que espera un Supervisor.
  Como el proceso se crea con `spawn_link` desde el supervisor, quedan VINCULADOS:
  si la bitácora se cae, el supervisor se entera y la vuelve a iniciar.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @nombre :bitacora
  @espera_maxima 5_000

  @doc """
  Crea el proceso de la bitácora y lo registra como `:bitacora`.
  La llama el SupervisorPrincipal (`%{id: Bitacora, start: {Bitacora, :iniciar, [directorio]}}`).
  """
  def iniciar(directorio) do
    registros = Persistencia.cargar_actividad(directorio)
    pid = spawn_link(fn -> loop(%{directorio: directorio, registros: registros}) end)
    Process.register(pid, @nombre)
    {:ok, pid}
  end

  @doc """
  Registra una acción (no espera respuesta: `send` es asíncrono).
  """
  def registrar(usuario, comando, resultado) do
    @nombre
    |> Process.whereis()
    |> enviar({:registrar, usuario, comando, resultado})
  end

  @doc """
  Consulta la actividad de un usuario (o de todos con `nil`).
  Retorna una lista de tuplas `{fecha, usuario, comando, resultado}`.
  """
  def consultar(usuario \\ nil) do
    @nombre
    |> Process.whereis()
    |> enviar({:consultar, usuario, self()})

    receive do
      {:actividad, lista} -> lista
    after
      # `after` evita esperar para siempre si la bitácora no responde (Guía 12).
      @espera_maxima -> []
    end
  end

  # Si la bitácora no está corriendo (se está reiniciando), el registro se pierde
  # pero el sistema sigue funcionando.
  defp enviar(nil, _mensaje), do: :ok
  defp enviar(pid, mensaje), do: send(pid, mensaje)

  @doc false
  # RECURSIVA: loop del proceso. Cada mensaje se atiende y se vuelve a llamar con el
  # nuevo estado. No hay caso base: el proceso vive hasta que el supervisor lo detenga.
  def loop(estado) do
    receive do
      {:registrar, usuario, comando, resultado} ->
        registro = {Validaciones.fecha_actual(), usuario, comando, resultado}
        Persistencia.agregar_actividad(registro, estado.directorio)
        loop(%{estado | registros: estado.registros ++ [registro]})

      {:consultar, usuario, remitente} ->
        send(remitente, {:actividad, filtrar(estado.registros, usuario)})
        loop(estado)
    end
  end

  defp filtrar(registros, nil), do: registros
  defp filtrar(registros, usuario), do: Enum.filter(registros, fn {_fecha, quien, _comando, _resultado} -> quien == usuario end)
end
