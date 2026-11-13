# Pruebas de supervisión (reinicio de procesos), persistencia y bitácora.
# Ejecutar: elixir -pa ebin pruebas/supervision_prueba.exs
ExUnit.start()

defmodule SupervisionPrueba do
  use ExUnit.Case

  setup do
    directorio = Path.join(System.tmp_dir!(), "emergencias_prueba_#{System.system_time(:microsecond)}_#{System.unique_integer([:positive])}")
    start_supervised!({SupervisorPrincipal, directorio: directorio})
    %{directorio: directorio}
  end

  # RECURSIVA: espera (sin dormir) hasta que el nombre apunte a un proceso NUEVO.
  # Caso base: Process.whereis da un pid distinto al viejo. Caso recursivo: volver a preguntar.
  defp esperar_reinicio(nombre, pid_viejo) do
    nombre
    |> Process.whereis()
    |> revisar_pid(nombre, pid_viejo)
  end

  defp revisar_pid(nil, nombre, pid_viejo), do: esperar_reinicio(nombre, pid_viejo)
  defp revisar_pid(pid, nombre, pid_viejo) when pid == pid_viejo, do: esperar_reinicio(nombre, pid_viejo)
  defp revisar_pid(pid_nuevo, _nombre, _pid_viejo), do: pid_nuevo

  defp matar(nombre) do
    pid_viejo = Process.whereis(nombre)
    Process.exit(pid_viejo, :kill)
    esperar_reinicio(nombre, pid_viejo)
  end

  test "si Inventario se cae, el supervisor lo reinicia y recupera el inventario del archivo" do
    {:ok, _} = Centros.registrar("CA1", "Centro 1", "centro_acopio", "centro")
    :ok = Inventario.registrar_ubicacion("CA1", "centro")
    {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 50, "litros", "CA1")
    {:ok, _} = Inventario.registrar_salida("R001", 8)

    pid_viejo = Process.whereis(Inventario)
    pid_nuevo = matar(Inventario)

    refute pid_nuevo == pid_viejo
    assert {:ok, %Recurso{cantidad: 42}} = Inventario.obtener("R001")
    assert length(Inventario.historial("R001")) == 2
    # Los demás procesos NO se reiniciaron (estrategia :one_for_one).
    assert Process.alive?(Process.whereis(Necesidades))
  end

  test "si Necesidades se cae, los ids siguen sin repetirse" do
    {:ok, %Necesidad{id: "N001"}} = Necesidades.registrar("agua", 5, "alta", "centro", "a", "laura")
    matar(Necesidades)
    assert {:ok, %Necesidad{id: "N002"}} = Necesidades.registrar("agua", 5, "alta", "centro", "b", "laura")
  end

  test "la Bitacora (proceso simple) también se reinicia y conserva la actividad" do
    Bitacora.registrar("laura", "connect", "ok")
    Bitacora.registrar("pedro", "summary", "error:sin_permiso")
    assert [{_fecha, "laura", "connect", "ok"}] = Bitacora.consultar("laura")

    matar(:bitacora)
    assert length(Bitacora.consultar()) == 2
  end

  test "persistencia: detener todo y volver a iniciar con la misma carpeta", %{directorio: directorio} do
    {:ok, _, :registrado} = Usuarios.conectar("laura", "1234", "coordinador", "centro")
    {:ok, _} = Zonas.registrar_zona("centro", "Zona Centro", "alto", 100)
    {:ok, _} = Zonas.registrar_sector("centro", "S1", "Sector 1", "critico", 10)
    {:ok, _} = Centros.registrar("CA1", "Centro 1", "centro_acopio", "centro")
    :ok = Inventario.registrar_ubicacion("CA1", "centro")
    {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 50, "litros", "CA1")
    {:ok, _} = Necesidades.registrar("agua", 30, "critica", "centro", "Punto 3", "laura")
    {:ok, _} = Necesidades.asignar_recurso("N001", "agua", 30, "laura")
    {:ok, _} = Personas.registrar("123", "Andrés", 34, "centro", "localizada", "ana")
    {:ok, _} = Personas.enviar_mensaje("ana", "123", "Estoy bien")
    {:ok, _} = Albergues.registrar("A01", "Albergue Norte", "centro", 10)
    {:ok, _} = Albergues.registrar_ingreso("A01", "123", "pedro")
    {:ok, _} = Mascotas.reportar("perdida", "perro", "Luna", "negra", "mediana", "centro", "300", "collar rojo")

    :ok = stop_supervised(SupervisorPrincipal)
    start_supervised!({SupervisorPrincipal, directorio: directorio})

    assert {:ok, _, :autenticado} = Usuarios.conectar("laura", "1234")
    assert {:ok, %{sectores: 1, personas_afectadas: 110}} = Zonas.estadisticas("centro")
    assert {:ok, %Recurso{cantidad: 20}} = Inventario.obtener("R001")
    # La ubicación CA1 se recuperó de centros.csv: se puede seguir asignando en la zona.
    assert {:ok, %Necesidad{estado: "asignada", asignaciones: [{"R001", 30}]}} = Necesidades.obtener("N001")
    assert {:ok, %Persona{estado: "en_albergue", historial: historial}} = Personas.obtener("123")
    assert length(historial) == 2
    assert [%Mensaje{contenido: "Estoy bien"}] = Personas.mensajes_para("123")
    assert {:ok, albergue} = Albergues.consultar("A01")
    assert Albergue.presente?(albergue, "123")
    assert [%Mascota{caracteristicas: "collar rojo"}] = Mascotas.listar()
    assert {:ok, %Necesidad{id: "N002"}} = Necesidades.registrar("agua", 1, "baja", "centro", "x", "laura")
  end

  test "una línea dañada se ignora y el sistema sigue", %{directorio: directorio} do
    {:ok, _} = Centros.registrar("CA1", "Centro 1", "centro_acopio", "centro")
    :ok = stop_supervised(SupervisorPrincipal)

    directorio |> Path.join("centros.csv") |> Archivo.agregar("esto;no;sirve\n")
    start_supervised!({SupervisorPrincipal, directorio: directorio})

    assert [%Centro{codigo: "CA1"}] = Centros.listar()
  end
end
