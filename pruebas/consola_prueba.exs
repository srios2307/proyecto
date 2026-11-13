# Pruebas de la interfaz: Comandos (sesiones, permisos, bitácora) y los mensajes de Consola.
# Ejecutar: elixir -pa ebin pruebas/consola_prueba.exs
ExUnit.start()

defmodule ConsolaPrueba do
  use ExUnit.Case

  setup do
    directorio = Path.join(System.tmp_dir!(), "emergencias_prueba_#{System.system_time(:microsecond)}_#{System.unique_integer([:positive])}")
    start_supervised!({SupervisorPrincipal, directorio: directorio})
    :ok
  end

  # Ejecuta una línea como lo haría la consola y retorna {respuesta, nuevo_estado}.
  defp ejecutar(linea, estado) do
    linea
    |> AnalizadorComandos.analizar()
    |> Comandos.ejecutar(estado)
  end

  test "sin sesión solo se permiten los comandos básicos" do
    estado = Comandos.estado_inicial()
    assert {{:error, :sin_sesion}, ^estado} = ejecutar("list_needs", estado)
    assert {{:ok, {nil, _comandos}}, _} = ejecutar("help", estado)
    assert {{:error, {:comando_desconocido, "volar"}}, _} = ejecutar("volar", estado)
  end

  test "varias sesiones abiertas, cambio de sesión activa y permisos por rol" do
    {_, estado} = ejecutar("connect laura 1234 coordinador centro", Comandos.estado_inicial())
    {_, estado} = ejecutar("connect carlos 2222 ciudadano centro", estado)
    assert estado.activa == "carlos"

    assert {{:error, {:sin_permiso, "ciudadano", :summary}}, _} = ejecutar("summary", estado)

    {{:ok, "laura"}, estado} = ejecutar("use laura", estado)
    assert {{:ok, _resumen}, _} = ejecutar("summary", estado)

    assert {{:ok, {sesiones, "laura"}}, _} = ejecutar("sessions", estado)
    assert Enum.map(sesiones, & &1.usuario) == ["carlos", "laura"]

    {{:ok, "laura"}, estado} = ejecutar("disconnect", estado)
    assert estado.activa == "carlos"
    assert {{:error, {:sesion_no_encontrada, "laura"}}, _} = ejecutar("use laura", estado)
  end

  test "flujo del enunciado por comandos y registro en la bitácora" do
    {_, estado} = ejecutar(~s(connect admin admin123 administrador centro), Comandos.estado_inicial())
    {_, estado} = ejecutar(~s(register_zone centro "Zona Centro" alto 500), estado)
    {_, estado} = ejecutar(~s(register_center centro_acopio_1 "Centro de Acopio 1" centro_acopio centro), estado)
    {_, estado} = ejecutar(~s(connect laura 1234 coordinador centro), estado)
    {{:ok, %Necesidad{id: "N001"}}, estado} = ejecutar(~s(register_need agua 30 critica centro "Punto de atención sector 3"), estado)
    {{:ok, _}, estado} = ejecutar(~s(register_resource R001 agua 50 litros centro_acopio_1), estado)
    {{:ok, %Necesidad{estado: "asignada"}}, estado} = ejecutar("assign_resource need001 agua 30", estado)
    {{:ok, resumen}, estado} = ejecutar("summary", estado)
    assert resumen.recursos_por_categoria == %{"agua" => 20}

    # La bitácora es asíncrona: la consulta llega después de los registros (mismo remitente, mismo orden).
    {_, estado} = ejecutar("use admin", estado)
    {{:ok, actividad}, _} = ejecutar("activity laura", estado)
    comandos = Enum.map(actividad, fn {_fecha, _usuario, comando, _resultado} -> comando end)
    assert comandos == ["connect", "register_need", "register_resource", "assign_resource", "summary"]
  end

  test "validaciones de entrada antes de modificar el estado" do
    {_, estado} = ejecutar("connect laura 1234 coordinador centro", Comandos.estado_inicial())
    assert {{:error, {:numero_invalido, "treinta"}}, _} = ejecutar(~s(register_need agua treinta critica centro "x"), estado)
    assert {{:error, {:zona_no_registrada, "luna"}}, _} = ejecutar(~s(register_need agua 30 critica luna "x"), estado)
    assert {{:error, {:uso_incorrecto, :register_need}}, _} = ejecutar("register_need agua", estado)
    assert {{:error, :comillas_sin_cerrar}, _} = ejecutar(~s(register_need agua 30 critica centro "x), estado)
    assert Necesidades.listar() == []
  end

  test "crash_server: el supervisor reinicia el proceso y los datos siguen" do
    {_, estado} = ejecutar("connect admin admin123 administrador centro", Comandos.estado_inicial())
    {_, estado} = ejecutar(~s(register_zone centro "Zona Centro" alto 10), estado)
    {{:ok, {"inventario", viejo, nuevo}}, estado} = ejecutar("crash_server inventario", estado)
    refute viejo == nuevo
    assert {{:ok, [_zona]}, _} = ejecutar("list_zones", estado)
  end

  test "mensajes de la consola" do
    assert Consola.generar_mensaje({:list_needs, {:ok, []}}) == "Necesidades (ordenadas por prioridad): (ninguno)\n"
    assert Consola.generar_mensaje({:x, {:error, :albergue_lleno}}) == "ERROR: El albergue está lleno: no hay cupos."

    assert Consola.generar_mensaje({:match_pets, {:ok, [{"MA001", "MA002", 75}]}}) =~ "MA001 (perdida) <-> MA002 (encontrada): 75 puntos"

    assert Consola.describir_error({:inventario_insuficiente, disponible: 20}) =~ "solo hay 20 disponibles"
  end
end
