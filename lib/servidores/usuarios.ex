defmodule Usuarios do
  @moduledoc """
  GenServer que guarda los usuarios registrados y quiénes están conectados
  (diagrama `3a_secuencia_connect.png`).

  ¿Qué es un GenServer? (NO visto en clase; lo pide el enunciado)
  Es un PROCESO como la "caja registradora" de la Guía 12: tiene un estado privado,
  vive en un ciclo recursivo y atiende mensajes UNO A LA VEZ. Elixir ya trae ese
  ciclo hecho; nosotros solo escribimos:
    - `init/1`: arma el estado inicial (aquí, cargando el archivo).
    - `handle_call/3`: atiende un mensaje y RESPONDE `{:reply, respuesta, nuevo_estado}`.
  Las funciones públicas de arriba (API del cliente) envían el mensaje con
  `GenServer.call/2`, que es como `send` + `receive` juntos: espera la respuesta.

  Estado: `%{directorio, usuarios: %{usuario => %Usuario{}}, conectados: MapSet, sesiones: %{usuario => pid}}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # `use GenServer` trae el comportamiento de GenServer a este módulo.
  use GenServer

  @tipo_por_defecto "ciudadano"
  @zona_por_defecto "sin_zona"

  # ---------------------------------------------------------------
  # API del cliente (lo que llaman los demás módulos)
  # ---------------------------------------------------------------

  @doc """
  Inicia el GenServer y lo registra con el nombre `Usuarios`.
  """
  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc """
  Conecta un usuario. Si no existe, lo registra automáticamente; si existe, valida la contraseña.
  Al conectarse se crea un proceso `Sesion` bajo `SupervisorSesiones`.

  ## Retorna
    - `{:ok, %Usuario{}, :registrado}` | `{:ok, %Usuario{}, :autenticado}`
    - `{:error, :credenciales_invalidas}` | `{:error, :ya_conectado}` | error de validación
  """
  def conectar(usuario, contrasena, tipo \\ nil, zona \\ nil, nombre_completo \\ nil) do
    GenServer.call(__MODULE__, {:conectar, usuario, contrasena, tipo, zona, nombre_completo})
  end

  @doc """
  Desconecta un usuario y termina su proceso `Sesion`.
  Retorna `{:ok, usuario}` o `{:error, :no_conectado}`.
  """
  def desconectar(usuario), do: GenServer.call(__MODULE__, {:desconectar, usuario})

  @doc "Lista de todos los usuarios registrados."
  def listar(), do: GenServer.call(__MODULE__, :listar)

  @doc "Lista de nombres de usuario conectados."
  def conectados(), do: GenServer.call(__MODULE__, :conectados)

  @doc "Mapa `usuario => pid` de las sesiones abiertas."
  def sesiones(), do: GenServer.call(__MODULE__, :sesiones)

  # ---------------------------------------------------------------
  # Servidor (lo que corre dentro del proceso)
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    usuarios =
      directorio
      |> Persistencia.cargar_usuarios()
      |> Enum.map(fn usuario -> {usuario.usuario, usuario} end)
      |> Enum.into(%{})

    {:ok, %{directorio: directorio, usuarios: usuarios, conectados: MapSet.new(), sesiones: %{}}}
  end

  @doc false
  def handle_call({:conectar, usuario, contrasena, tipo, zona, nombre}, _de, estado) do
    estado.usuarios
    |> Map.get(usuario)
    |> conectar_usuario({usuario, contrasena, tipo, zona, nombre}, estado)
  end

  def handle_call({:desconectar, usuario}, _de, estado) do
    estado.conectados
    |> MapSet.member?(usuario)
    |> desconectar_usuario(usuario, estado)
  end

  def handle_call(:listar, _de, estado) do
    lista = estado.usuarios |> Map.values() |> Enum.sort_by(& &1.usuario)
    {:reply, lista, estado}
  end

  def handle_call(:conectados, _de, estado), do: {:reply, MapSet.to_list(estado.conectados), estado}
  def handle_call(:sesiones, _de, estado), do: {:reply, estado.sesiones, estado}

  # El usuario NO existe → registro automático.
  defp conectar_usuario(nil, {usuario, contrasena, tipo, zona, nombre}, estado) do
    tipo = Validaciones.normalizar(tipo || @tipo_por_defecto)
    zona = zona || @zona_por_defecto
    nombre = nombre || usuario

    [
      Validaciones.validar_texto(usuario, :usuario),
      Validaciones.validar_texto(contrasena, :contrasena),
      Validaciones.validar_opcion(tipo, Validaciones.tipos_usuario(), :tipo),
      Validaciones.validar_texto(zona, :zona),
      Validaciones.validar_texto(nombre, :nombre_completo)
    ]
    |> Validaciones.primer_error()
    |> registrar_y_conectar({usuario, contrasena, tipo, zona, nombre}, estado)
  end

  # El usuario existe → se valida la contraseña.
  defp conectar_usuario(%Usuario{} = existente, {_usuario, contrasena, _tipo, _zona, _nombre}, estado) do
    existente
    |> Usuario.contrasena_correcta?(contrasena)
    |> autenticar(existente, estado)
  end

  defp registrar_y_conectar(:ok, {usuario, contrasena, tipo, zona, nombre}, estado) do
    nuevo = Usuario.crear(usuario, contrasena, nombre, tipo, zona, Validaciones.fecha_actual())
    # Se crea un mapa NUEVO con el usuario agregado: en Elixir nada se modifica.
    estado = %{estado | usuarios: Map.put(estado.usuarios, usuario, nuevo)}

    estado.usuarios
    |> Map.values()
    |> Persistencia.guardar_usuarios(estado.directorio)

    abrir_sesion(nuevo, :registrado, estado)
  end

  defp registrar_y_conectar(error, _datos, estado), do: {:reply, error, estado}

  defp autenticar(false, _usuario, estado), do: {:reply, {:error, :credenciales_invalidas}, estado}
  defp autenticar(true, usuario, estado), do: abrir_sesion(usuario, :autenticado, estado)

  defp abrir_sesion(usuario, modo, estado) do
    estado.conectados
    |> MapSet.member?(usuario.usuario)
    |> iniciar_si_libre(usuario, modo, estado)
  end

  defp iniciar_si_libre(true, _usuario, _modo, estado), do: {:reply, {:error, :ya_conectado}, estado}

  defp iniciar_si_libre(false, usuario, modo, estado) do
    usuario
    |> SupervisorSesiones.iniciar_sesion()
    |> registrar_sesion(usuario, modo, estado)
  end

  defp registrar_sesion({:ok, pid}, usuario, modo, estado) do
    nuevo_estado = %{
      estado
      | conectados: MapSet.put(estado.conectados, usuario.usuario),
        sesiones: Map.put(estado.sesiones, usuario.usuario, pid)
    }

    {:reply, {:ok, usuario, modo}, nuevo_estado}
  end

  defp registrar_sesion({:error, motivo}, _usuario, _modo, estado) do
    {:reply, {:error, {:sesion_no_iniciada, motivo}}, estado}
  end

  defp desconectar_usuario(false, _usuario, estado), do: {:reply, {:error, :no_conectado}, estado}

  defp desconectar_usuario(true, usuario, estado) do
    estado.sesiones
    |> Map.get(usuario)
    |> SupervisorSesiones.terminar_sesion()

    nuevo_estado = %{
      estado
      | conectados: MapSet.delete(estado.conectados, usuario),
        sesiones: Map.delete(estado.sesiones, usuario)
    }

    {:reply, {:ok, usuario}, nuevo_estado}
  end
end
