# Pruebas de los GenServers (cada prueba usa su propia carpeta temporal de datos).
# Ejecutar: elixir -pa ebin pruebas/servidores_prueba.exs
ExUnit.start()

defmodule ServidoresPrueba do
  use ExUnit.Case

  # Antes de CADA prueba se inicia el sistema completo en una carpeta temporal nueva.
  # start_supervised! lo detiene solo al terminar la prueba.
  setup do
    directorio = Path.join(System.tmp_dir!(), "emergencias_prueba_#{System.system_time(:microsecond)}_#{System.unique_integer([:positive])}")
    start_supervised!({SupervisorPrincipal, directorio: directorio})
    %{directorio: directorio}
  end

  # Crea el centro y avisa al inventario en qué zona queda (lo mismo que hace `register_center`).
  defp crear_centro(codigo, zona) do
    {:ok, _centro} = Centros.registrar(codigo, "Centro #{codigo}", "centro_acopio", zona)
    :ok = Inventario.registrar_ubicacion(codigo, zona)
  end

  describe "Usuarios" do
    test "registro automático, login correcto e incorrecto" do
      assert {:ok, %Usuario{usuario: "laura", tipo: "coordinador"}, :registrado} =
               Usuarios.conectar("laura", "1234", "coordinador", "centro")

      assert Usuarios.conectar("laura", "1234") == {:error, :ya_conectado}
      assert Usuarios.desconectar("laura") == {:ok, "laura"}
      assert Usuarios.conectar("laura", "malaclave") == {:error, :credenciales_invalidas}
      assert {:ok, %Usuario{usuario: "laura"}, :autenticado} = Usuarios.conectar("laura", "1234")
    end

    test "la contraseña se guarda como hash, no en texto plano" do
      {:ok, usuario, :registrado} = Usuarios.conectar("ana", "secreta", "ciudadano", "norte")
      refute usuario.hash_contrasena == "secreta"
      assert Usuario.contrasena_correcta?(usuario, "secreta")
    end

    test "valida el tipo de usuario y los caracteres" do
      assert Usuarios.conectar("pepe", "1", "pirata", "centro") ==
               {:error, {:opcion_invalida, :tipo, "pirata"}}

      assert Usuarios.conectar("pe;pe", "1", "ciudadano", "centro") == {:error, {:caracter_no_permitido, :usuario}}
    end

    test "cada conexión crea un proceso Sesion bajo el DynamicSupervisor" do
      {:ok, _, _} = Usuarios.conectar("laura", "1", "coordinador", "centro")
      {:ok, _, _} = Usuarios.conectar("pedro", "2", "voluntario", "norte")
      assert SupervisorSesiones.cantidad() == 2

      pid = Usuarios.sesiones() |> Map.get("pedro")
      assert %{usuario: "pedro", tipo: "voluntario", zona: "norte"} = Sesion.consultar(pid)

      {:ok, "pedro"} = Usuarios.desconectar("pedro")
      assert SupervisorSesiones.cantidad() == 1
      refute Process.alive?(pid)
    end
  end

  describe "Zonas" do
    test "zona, sector y punto con estadísticas acumuladas" do
      {:ok, _} = Zonas.registrar_zona("centro", "Zona Centro", "medio", 100)
      {:ok, _} = Zonas.registrar_sector("centro", "S1", "Sector 1", "critico", 40)
      {:ok, _} = Zonas.registrar_punto("S1", "PA1", "Punto Parque")

      assert Zonas.estadisticas("centro") ==
               {:ok, %{personas_afectadas: 140, sectores: 1, puntos: 1, nivel_mas_critico: "critico"}}

      assert Zonas.existe?("PA1")
    end

    test "códigos repetidos y padres inválidos" do
      {:ok, _} = Zonas.registrar_zona("centro", "Zona Centro", "medio", 100)
      assert Zonas.registrar_zona("centro", "Otra", "bajo", 1) == {:error, {:id_repetido, "centro"}}
      assert Zonas.registrar_punto("centro", "P9", "Punto") == {:error, {:padre_invalido, :zona, :punto}}
      assert Zonas.registrar_sector("nada", "S9", "Sector", "bajo", 1) == {:error, {:zona_no_encontrada, "nada"}}
      assert Zonas.registrar_zona("sur", "Sur", "terrible", 1) == {:error, {:opcion_invalida, :nivel, "terrible"}}
    end
  end

  describe "Inventario" do
    test "entradas, salidas, intento de dejar negativo e historial" do
      crear_centro("CA1", "centro")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua potable", "agua", 50, "litros", "CA1")

      assert {:ok, %Recurso{cantidad: 70}} = Inventario.registrar_entrada("R001", 20)
      assert {:ok, %Recurso{cantidad: 40}} = Inventario.registrar_salida("R001", 30)
      assert Inventario.registrar_salida("R001", 41) == {:error, {:inventario_insuficiente, disponible: 40}}
      assert Inventario.registrar_salida("R001", -5) == {:error, {:cantidad_invalida, :cantidad}}
      assert {:ok, %Recurso{cantidad: 40}} = Inventario.obtener("R001")

      tipos = "R001" |> Inventario.historial() |> Enum.map(& &1.tipo)
      assert tipos == ["entrada", "entrada", "salida"]
    end

    test "no acepta códigos repetidos, cantidades negativas ni ubicaciones desconocidas" do
      crear_centro("CA1", "centro")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 50, "litros", "CA1")
      assert Inventario.registrar_recurso("R001", "Agua", "agua", 5, "litros", "CA1") == {:error, {:id_repetido, "R001"}}

      assert Inventario.registrar_recurso("R002", "Agua", "agua", -5, "litros", "CA1") ==
               {:error, {:cantidad_negativa, :cantidad}}

      assert Inventario.registrar_recurso("R003", "Agua", "agua", 5, "litros", "XX") ==
               {:error, {:ubicacion_no_registrada, "XX"}}
    end

    test "transferencia entre centros" do
      crear_centro("CA1", "centro")
      crear_centro("ALB2", "norte")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 200, "litros", "CA1")

      assert {:ok, %Recurso{cantidad: 170}, %Recurso{codigo: "R001-ALB2", cantidad: 30, ubicacion: "ALB2"}} =
               Inventario.transferir("R001", "CA1", "ALB2", 30)

      assert Inventario.transferir("R001", "ALB2", "CA1", 5) == {:error, {:origen_incorrecto, "CA1"}}
      assert Inventario.transferir("R001", "CA1", "CA1", 5) == {:error, :mismo_origen_y_destino}
      assert Inventario.transferir("R001", "CA1", "ALB2", 500) == {:error, {:inventario_insuficiente, disponible: 170}}

      # Devolver al centro original suma en el mismo recurso R001.
      assert {:ok, _, %Recurso{codigo: "R001", cantidad: 180}} = Inventario.transferir("R001-ALB2", "ALB2", "CA1", 10)

      assert ["transferencia", "transferencia"] ==
               "R001-ALB2" |> Inventario.historial() |> Enum.map(& &1.tipo)

      assert Inventario.listar(%{"zona" => "norte"}) |> Enum.map(& &1.codigo) == ["R001-ALB2"]
    end
  end

  describe "Necesidades" do
    test "asignación por categoría y necesidad atendida que intenta consumir de nuevo" do
      crear_centro("CA1", "centro")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 100, "litros", "CA1")
      {:ok, %Necesidad{id: "N001"}} = Necesidades.registrar("agua", 30, "critica", "centro", "Punto 3", "laura")

      assert {:ok, %Necesidad{estado: "pendiente", cantidad_asignada: 10}} =
               Necesidades.asignar_recurso("N001", "agua", 10, "laura")

      assert Necesidades.asignar_recurso("N001", "agua", 25, "laura") == {:error, {:supera_faltante, 20}}

      assert {:ok, %Necesidad{estado: "asignada", cantidad_asignada: 30, asignaciones: [{"R001", 10}, {"R001", 20}]}} =
               Necesidades.asignar_recurso("N001", "R001", 20, "laura")

      {:ok, _} = Necesidades.actualizar_estado("N001", "en_atencion")
      {:ok, %Necesidad{estado: "atendida"}} = Necesidades.actualizar_estado("N001", "atendida")

      assert Necesidades.asignar_recurso("N001", "agua", 5, "laura") == {:error, :ya_cerrada}
      assert Necesidades.actualizar_estado("N001", "cancelada") == {:error, :ya_cerrada}
      assert {:ok, %Recurso{cantidad: 70}} = Inventario.obtener("R001")
    end

    test "si no alcanza, la necesidad no cambia" do
      crear_centro("CA1", "centro")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 20, "litros", "CA1")
      {:ok, _} = Necesidades.registrar("agua", 25, "alta", "centro", "Albergue", "pedro")

      assert Necesidades.asignar_recurso("N001", "agua", 25, "pedro") ==
               {:error, {:inventario_insuficiente, disponible: 20}}

      assert {:ok, %Necesidad{cantidad_asignada: 0, estado: "pendiente"}} = Necesidades.obtener("N001")
    end

    test "prefiere recursos de la zona de la necesidad" do
      crear_centro("CA1", "centro")
      crear_centro("CA2", "norte")
      {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 100, "litros", "CA1")
      {:ok, _} = Inventario.registrar_recurso("R002", "Agua", "agua", 100, "litros", "CA2")
      {:ok, _} = Necesidades.registrar("agua", 10, "media", "norte", "Sector norte", "pedro")

      assert {:ok, %Necesidad{asignaciones: [{"R002", 10}]}} = Necesidades.asignar_recurso("N001", "agua", 10, "pedro")
    end

    test "consultas filtradas y ordenadas por prioridad, siguiente necesidad" do
      {:ok, _} = Necesidades.registrar("agua", 10, "baja", "centro", "a", "laura")
      {:ok, _} = Necesidades.registrar("alimentos", 10, "critica", "norte", "b", "laura")
      {:ok, _} = Necesidades.registrar("agua", 10, "alta", "centro", "c", "laura")

      assert Necesidades.listar() |> Enum.map(& &1.id) == ["N002", "N003", "N001"]
      assert Necesidades.listar(%{"zona" => "centro"}) |> Enum.map(& &1.id) == ["N003", "N001"]
      assert {:ok, %Necesidad{id: "N002"}} = Necesidades.siguiente()
      assert {:ok, %Necesidad{id: "N003"}} = Necesidades.siguiente("centro")
      assert Necesidades.registrar("agua", 0, "alta", "centro", "x", "laura") == {:error, {:cantidad_invalida, :cantidad}}
      assert Necesidades.registrar("agua", 5, "urgente", "centro", "x", "laura") ==
               {:error, {:opcion_invalida, :prioridad, "urgente"}}
    end
  end

  describe "Personas y mensajes" do
    test "persona con historial de estados" do
      {:ok, %Persona{id: "P001"}} = Personas.registrar("123", "Andrés Pérez", 34, "norte", "reportada", "ana")
      {:ok, _} = Personas.actualizar_estado("123", "localizada", "pedro")
      {:ok, _} = Personas.actualizar_estado("123", "reunificada", "pedro")

      {:ok, historial} = Personas.historial("123")
      assert Enum.map(historial, fn {_fecha, anterior, nuevo, _usuario} -> {anterior, nuevo} end) ==
               [{"-", "reportada"}, {"reportada", "localizada"}, {"localizada", "reunificada"}]

      assert Personas.actualizar_estado("123", "localizada", "pedro") == {:error, :ya_reunificada}
      assert Personas.registrar("123", "Otro", 1, "norte", "reportada", "ana") == {:error, {:id_repetido, "123"}}
    end

    test "búsqueda por nombre, zona y estado" do
      {:ok, _} = Personas.registrar("1", "Andrés Pérez", 34, "norte", "localizada", "ana")
      {:ok, _} = Personas.registrar("2", "María Andrade", 20, "sur", "reportada", "ana")
      assert Personas.buscar(%{"nombre" => "andr"}) |> length() == 2
      assert [%Persona{documento: "2"}] = Personas.buscar(%{"zona" => "sur"})
      assert [%Persona{documento: "1"}] = Personas.buscar(%{"estado" => "localizada"})
    end

    test "mensajes pendientes y entregados" do
      {:ok, %Mensaje{id: "MS001", estado: "pendiente"}} = Personas.enviar_mensaje("ana", "123", "Estoy bien")
      {:ok, _} = Personas.enviar_mensaje("luis", "familia_perez", "Los buscamos")

      assert [%Mensaje{contenido: "Estoy bien"}] = Personas.mensajes_para("123")
      assert {:ok, %Mensaje{estado: "entregado"}} = Personas.marcar_mensaje("MS001", "entregado")

      assert Personas.marcar_mensaje("MS001", "entregado") ==
               {:error, {:transicion_invalida, "entregado", "entregado"}}

      assert {:ok, %Mensaje{estado: "pendiente"}} = Personas.marcar_mensaje("MS001", "pendiente")
    end
  end

  describe "Albergues" do
    test "albergue lleno, ingreso y salida" do
      {:ok, _} = Albergues.registrar("A01", "Albergue Norte", "norte", 1)
      {:ok, _} = Personas.registrar("1", "Andrés", 34, "norte", "localizada", "ana")
      {:ok, _} = Personas.registrar("2", "María", 20, "norte", "localizada", "ana")

      assert {:ok, albergue} = Albergues.registrar_ingreso("A01", "1")
      assert Albergue.ocupacion(albergue) == 1
      assert {:ok, %Persona{estado: "en_albergue"}} = Personas.obtener("1")

      assert Albergues.registrar_ingreso("A01", "2") == {:error, :albergue_lleno}
      assert {:ok, %Persona{estado: "localizada"}} = Personas.obtener("2")

      assert {:ok, vacio} = Albergues.registrar_salida("A01", "1")
      assert Albergue.cupos_disponibles(vacio) == 1
      assert {:ok, %Persona{estado: "trasladada"}} = Personas.obtener("1")
    end

    test "no ingresa personas no registradas y reporte de ocupación" do
      {:ok, _} = Albergues.registrar("A01", "Norte", "norte", 2)
      {:ok, _} = Albergues.registrar("A02", "Sur", "sur", 4)
      assert Albergues.registrar_ingreso("A01", "999") == {:error, {:persona_no_encontrada, "999"}}

      {:ok, _} = Personas.registrar("1", "Andrés", 34, "norte", "localizada", "ana")
      {:ok, _} = Albergues.registrar_ingreso("A01", "1")
      assert Albergues.reporte_ocupacion() |> Enum.map(& &1.codigo) == ["A01", "A02"]
      assert Albergues.registrar("A03", "X", "sur", -1) == {:error, {:cantidad_invalida, :capacidad}}
    end
  end

  describe "Mascotas" do
    test "reporte, coincidencias y confirmación que cierra ambos" do
      {:ok, %Mascota{id: "MA001"}} = Mascotas.reportar("perdida", "perro", "Luna", "negra", "mediana", "norte", "300")
      {:ok, %Mascota{id: "MA002"}} = Mascotas.reportar("encontrada", "perro", "desconocido", "negra", "mediana", "norte", "301")
      {:ok, _} = Mascotas.reportar("encontrada", "gato", "desconocido", "negra", "mediana", "norte", "302")

      assert Mascotas.buscar_coincidencias() == {:ok, [{"MA001", "MA002", 75}]}
      assert [%Mascota{id: "MA001"}, %Mascota{id: "MA002"}] = Mascotas.listar(%{"estado" => "posible_coincidencia"})

      assert {:ok, %Mascota{estado: "resuelta", coincidencia_con: "MA002"}, %Mascota{coincidencia_con: "MA001"}} =
               Mascotas.confirmar_coincidencia("MA001", "MA002")

      assert Mascotas.confirmar_coincidencia("MA001", "MA002") == {:error, :ya_resuelta}
      assert Mascotas.buscar_coincidencias() == {:ok, []}
    end

    test "validaciones del par y descarte" do
      {:ok, _} = Mascotas.reportar("perdida", "perro", "Luna", "negra", "mediana", "norte", "300")
      {:ok, _} = Mascotas.reportar("encontrada", "gato", "desconocido", "negra", "mediana", "norte", "301")
      {:ok, _} = Mascotas.reportar("encontrada", "perro", "desconocido", "negra", "mediana", "norte", "302")

      assert Mascotas.confirmar_coincidencia("MA001", "MA002") == {:error, :especies_distintas}
      assert Mascotas.confirmar_coincidencia("MA003", "MA001") == {:error, :tipos_de_reporte_invalidos}
      assert Mascotas.reportar("vista", "perro", "x", "x", "x", "x", "x") == {:error, {:opcion_invalida, :tipo_reporte, "vista"}}

      {:ok, [{"MA001", "MA003", 75}]} = Mascotas.buscar_coincidencias()
      assert {:ok, %Mascota{estado: "activa"}, %Mascota{estado: "activa"}} = Mascotas.descartar_coincidencia("MA001", "MA003")
    end
  end
end
