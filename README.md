# Sistema Distribuido de Coordinación y Gestión de Emergencias (Elixir)

Proyecto final de **Programación III** — Universidad del Quindío, Ingeniería de Sistemas y Computación.
Contexto: atención y coordinación posterior a un terremoto. Enunciado completo en `ProyectoFinal.pdf`.

| Integrante | Código | Correo |
|---|---|---|
| (completar) | | |
| (completar) | | |
| (completar) | | |

Licencia: GNU GPL v3.

---

## 1. Requisitos

- Elixir **1.20.3** con Erlang/OTP **29** (`elixir --version`).
- **Sin `mix` y sin librerías externas**: se compila con `elixirc`, como en clase.
- En Windows, para ver bien las tildes en la terminal: `chcp 65001` antes de ejecutar.

## 2. Compilar

Desde la carpeta `proyecto_final/`:

```bash
compilar.bat
```

```bash
sh compilar.sh
```

Los dos scripts borran los `.beam` viejos y compilan todos los `.ex` de `lib/` hacia `ebin/` con la lista
de archivos en orden de dependencias. La compilación termina **sin warnings**.

## 3. Ejecutar

```bash
elixir -pa ebin iniciar.exs
```

- `-pa ebin` le dice a Elixir dónde están los `.beam` compilados.
- Sin argumentos usa la carpeta `datos/` (trae **datos de ejemplo**). Para empezar limpio, se pasa otra carpeta:
  `elixir -pa ebin iniciar.exs datos_video`.
- Se puede alimentar la consola con un archivo de comandos que termine en `exit`:
  `elixir -pa ebin iniciar.exs datos_flujo < docs/flujo_ejemplo_comandos.txt`.

Usuarios de los datos de ejemplo (son datos de prueba; los comandos que los crean están en
`docs/datos_ejemplo_comandos.txt`):

| Usuario | Contraseña | Tipo | Zona |
|---|---|---|---|
| admin | admin123 | administrador | centro |
| laura | 1234 | coordinador | centro |
| pedro | 5678 | voluntario | zona_norte |
| carlos | 2222 | ciudadano | zona_norte |

`connect usuario contraseña [tipo zona ["nombre completo"]]`: si el usuario no existe se registra
automáticamente (por defecto `ciudadano`, zona `sin_zona`); si existe, se valida la contraseña.
Se pueden tener **varias sesiones abiertas**: `connect` deja activa la nueva, `use usuario` cambia la activa
y `sessions` las lista. Cada comando se ejecuta en nombre de la sesión activa y queda en la bitácora.

## 4. Comandos por rol

`help` muestra los comandos del rol de la sesión activa. Sin sesión solo funcionan `connect`, `use`,
`sessions`, `help` y `exit`. Cada rol tiene todo lo del rol anterior.

| Rol | Comandos |
|---|---|
| **ciudadano** | `disconnect`, `list_zones`, `list_centers`, `zone_status`, `zone_stats`, `list_needs`, `list_resources`, `find_person`, `person_history`, `report_person`, `send_family_message`, `list_family_messages`, `report_pet`, `list_pets`, `check_shelter` |
| **voluntario** | + `register_need`, `update_person`, `register_entry`, `register_exit`, `match_pets`, `mark_message`, `resource_history` |
| **coordinador** | + `register_zone`, `register_sector`, `register_point`, `register_center`, `register_resource`, `resource_in`, `resource_out`, `assign_resource`, `transfer_resource`, `update_need`, `register_shelter`, `confirm_pet_match`, `discard_pet_match`, `summary`, `critical_resources`, `pending_needs`, `next_need`, `shelter_report` |
| **administrador** | + `list_users`, `activity [usuario]`, `crash_server proceso` |

Forma de cada comando:

```
connect usuario contraseña [tipo zona ["nombre"]]   disconnect   use usuario   sessions   help   exit
register_zone codigo "nombre" nivel [personas]
register_sector zona codigo "nombre" nivel [personas]
register_point sector codigo "nombre" [nivel personas]
list_zones      zone_status codigo      zone_stats codigo
register_center codigo "nombre" (centro_acopio|albergue|punto_atencion) zona      list_centers
register_need tipo cantidad prioridad zona "descripcion"
list_needs [zona=.. tipo=.. prioridad=.. estado=..]     update_need id estado
pending_needs   next_need [zona]
assign_resource id_necesidad (categoria|codigo_recurso) cantidad      (acepta N001 o need001)
register_resource codigo categoria cantidad unidad ubicacion ["nombre"]
list_resources [categoria=.. zona=.. ubicacion=..]   resource_in codigo cantidad   resource_out codigo cantidad
transfer_resource codigo origen destino cantidad     resource_history codigo     critical_resources
report_person documento "nombre" [edad] zona estado  update_person documento estado
find_person (documento | nombre=.. | zona=.. | estado=..)   person_history documento
send_family_message destinatario "contenido"   list_family_messages destinatario   mark_message id (entregado|pendiente)
report_pet (lost|found) especie "nombre|desconocido" color tamano zona contacto ["caracteristicas"]
list_pets [especie=.. zona=.. estado=.. tipo=..]   match_pets   confirm_pet_match id_perdida id_encontrada
discard_pet_match id_perdida id_encontrada
register_shelter codigo "nombre" zona capacidad    check_shelter codigo    shelter_report
register_entry codigo documento    register_exit codigo documento [trasladada|reunificada]
summary    list_users    activity [usuario]    crash_server (inventario|necesidades|zonas|...)
```

Valores válidos: nivel `critico|alto|medio|bajo`; prioridad `critica|alta|media|baja`; tipo de necesidad y
categoría de recurso `agua|alimentos|medicamentos|primeros_auxilios|refugio|transporte|rescate|otra`.

## 5. Demostración de concurrencia y pruebas

```bash
elixir -pa ebin demo_concurrencia.exs
```

Usa una carpeta temporal nueva en cada ejecución (no toca `datos/`) y comprueba:

1. **Conflicto del enunciado** (diagrama `3b`): N001 pide 30 y N002 pide 25 del mismo recurso con 50 litros,
   lanzadas al mismo tiempo con `Task.async`. Se confirma exactamente una; la otra recibe
   `{:error, {:inventario_insuficiente, disponible: 20}}`. Nunca se asignan 55 ni queda inventario negativo.
2. 20 tareas piden 10 unidades de un recurso con 100 → exactamente 10 confirmadas, inventario 0.
3. 5 ingresos simultáneos a un albergue con 2 cupos → exactamente 2 adentro.
4. Dos `confirm_pet_match` simultáneos del mismo par → un `ok` y un `{:error, :ya_resuelta}`.
5. El resto del flujo del enunciado (Andrés localizado en el Albergue Norte, mensaje del familiar, mascota
   encontrada, `match_pets` y `summary` del coordinador).
6. Tolerancia a fallos: se mata `Inventario` y el supervisor lo reinicia con el mismo inventario.

Se ejecutó **5 veces** y las 5 terminaron con `RESULTADO: 9 de 9 verificaciones correctas.`

Pruebas (ExUnit sin mix):

```bash
elixir -pa ebin pruebas/todas.exs
```

Ejemplo de salida:

```
Running ExUnit with seed: 41721, max_cases: 32

.............................................................Aviso: ...centros.csv, línea 3 dañada; se ignora.
...............
Finished in 1.0 seconds (0.8s on load, 0.00s async, 0.2s sync)

Result: 76 passed
```

(El "Aviso" es intencional: lo produce la prueba que daña una línea de un archivo para comprobar que se ignora.)
Cada archivo también se puede correr solo, por ejemplo `elixir -pa ebin pruebas/concurrencia_prueba.exs`.

| Archivo | Qué prueba |
|---|---|
| `transiciones_prueba.exs` | transiciones válidas e inválidas, cerrar dos veces |
| `permisos_prueba.exs` | permisos por rol |
| `analizador_comandos_prueba.exs` | tokenizador con comillas, vacíos, comillas sin cerrar, filtros |
| `validaciones_prueba.exs` | negativos, ids repetidos, `;` en textos, ids con ceros |
| `arbol_zonas_prueba.exs` | insertar, buscar, estadísticas acumuladas (2 sectores y 3 puntos), aplanar/construir |
| `prioridades_prueba.exs` | ordenamiento por prioridad y fecha, selección de la siguiente |
| `coincidencias_prueba.exs` | puntaje (iguales, distinta especie, umbral 50) |
| `servidores_prueba.exs` | login correcto/incorrecto, inventario, transferencias, necesidad atendida, albergue lleno, historial, mensajes, mascotas |
| `supervision_prueba.exs` | reinicio de Inventario, Necesidades y Bitacora; persistencia al detener y reiniciar; línea dañada |
| `concurrencia_prueba.exs` | los escenarios de la sección 6.2 con `Task.async` |
| `consola_prueba.exs` | sesiones múltiples, permisos, bitácora, validación de entradas, `crash_server` |

## 6. Tolerancia a fallos y persistencia

- Como administrador: `crash_server inventario` mata el proceso a la fuerza (equivale a
  `Process.exit(Process.whereis(Inventario), :kill)`); el `SupervisorPrincipal` (`:one_for_one`) lo reinicia
  y su `init/1` vuelve a cargar `recursos.csv` y `movimientos.csv`. Después, `list_resources` muestra lo mismo.
- Todo cambio confirmado se guarda en `datos/` desde el mismo `handle_call`. Al salir (`exit`) y volver a
  ejecutar `iniciar.exs`, los datos siguen ahí.

| Archivo | Contenido | Escritura |
|---|---|---|
| `usuarios.csv` | usuario;hash;nombre;tipo;zona;fecha | reescribir |
| `zonas.txt` | codigo;nombre;tipo;nivel;personas;codigo_padre | reescribir |
| `centros.csv` | codigo;nombre;tipo;zona | reescribir |
| `necesidades.csv` | id;tipo;descripcion;requerida;asignada;zona;prioridad;responsable;estado;fecha;asignaciones (`R001:30\|R002:10`) | reescribir |
| `recursos.csv` | codigo;nombre;categoria;cantidad;unidad;ubicacion | reescribir |
| `movimientos.csv` | id;fecha;tipo;codigo_recurso;cantidad;origen;destino;usuario;referencia | solo agregar |
| `personas.csv` / `historial_personas.csv` | personas / cambios de estado | reescribir / solo agregar |
| `mensajes.csv` | id;fecha;remitente;destinatario;contenido;estado | reescribir |
| `mascotas.csv` | todos los campos del struct | reescribir |
| `albergues.csv` | codigo;nombre;zona;capacidad;ocupantes (`doc1\|doc2`) | reescribir |
| `actividad.log` | fecha;usuario;comando;resultado | solo agregar (Bitacora) |

La primera línea de cada archivo es un encabezado que empieza por `#` y se ignora al leer. Si un archivo no
existe se empieza vacío; si una línea está dañada se avisa su número y se ignora.

## 7. Arquitectura

Ver `docs/diagramas/1_arquitectura.png`. Capas: **Interfaz** (`Consola`, `Comandos`, `Util2`) →
**Servidores** (GenServers + `Bitacora`) → **Lógica** (funciones puras y recursivas) y **Dominio** (structs)
→ **Persistencia** (`Persistencia`, `Archivo`) → `datos/`. La consola nunca modifica el estado: siempre llama
a la API del cliente de un GenServer (`GenServer.call`). Solo `Util2` hace `IO`; solo `Archivo` usa `File`.

Árbol de supervisión (`docs/diagramas/4_arbol_otp.png`): `SupervisorPrincipal` (`:one_for_one`) con
`Bitacora` (proceso simple `spawn_link` + `receive`, nombre `:bitacora`), `Usuarios`, `Zonas`, `Centros`,
`Inventario`, `Necesidades`, `Personas`, `Mascotas`, `Albergues` y `SupervisorSesiones`
(DynamicSupervisor con un `Sesion` por usuario conectado). Las tareas de `summary` y `zone_status` son
`Task.async` temporales.

La revisión diagrama ↔ código está en `docs/CORRESPONDENCIA_DIAGRAMAS.md`.

## 8. Pensamiento computacional por módulo funcional

### 8.1 Usuarios
- **Abstracción**: se necesita saber quién opera y qué puede hacer. Datos relevantes: usuario, hash de la
  contraseña, nombre completo, tipo (rol), zona y fecha de registro; además quién está conectado.
- **Descomposición**: leer `connect` → analizar → buscar el usuario → si no existe validar y registrar
  (hash) → si existe comparar el hash → abrir un proceso `Sesion` → guardar `usuarios.csv` → registrar en
  la bitácora → mostrar el mensaje. Para cada comando: verificar permiso del rol antes de ejecutar.
- **Reconocimiento de patrones**: `Util2.ingresar/mostrar`; resultados `{:ok, ...}`/`{:error, ...}` con una
  cláusula por forma (Guía 11); el actor con estado de la Guía 12 (aquí con GenServer); permisos con una
  cláusula por rol, como las decisiones con guardas de 2-05.
- **Codificación**: `Usuario` (struct + hash), `Usuarios` (GenServer), `Sesion`, `SupervisorSesiones`,
  `Permisos`, `Bitacora`, `Comandos.ejecutar/2`.

### 8.2 Zonas
- **Abstracción**: una jerarquía zona → sector → punto con nivel de afectación y personas afectadas;
  se pide el estado general y las estadísticas acumuladas.
- **Descomposición**: registrar zona / sector / punto validando el padre → insertar en el árbol → guardar
  aplanado → para consultar: buscar el nodo → recorrer el subárbol sumando personas, contando sectores y
  puntos y eligiendo el nivel más crítico → juntar necesidades, albergues, personas y recursos de la zona.
- **Reconocimiento de patrones**: recursión sobre listas `[cabeza | cola]` (2-07) y recursión indirecta
  (par/impar); Fibonacci con acumuladores para sumar estadísticas.
- **Codificación**: `NodoZona`, `ArbolZonas` (`insertar_hijo`, `buscar`, `estadisticas`, `construir`,
  `aplanar`, `codigos`), `Zonas` (GenServer), `Comandos` (`zone_status` con `Task.async`).

### 8.3 Necesidades
- **Abstracción**: solicitudes con id, tipo, cantidad, zona, prioridad, responsable y estado; la prioridad
  decide el orden de atención; una necesidad cerrada no consume recursos.
- **Descomposición**: validar → generar id `N###` → guardar → listar filtrando y ordenando por prioridad →
  seleccionar la siguiente → asignar: validar estado y faltante → pedir a Inventario → actualizar solo si
  Inventario confirma → guardar.
- **Reconocimiento de patrones**: ordenamiento por inserción recursivo; filtros como `Util2.aplicar_filtro`;
  máquina de estados con un mapa de transiciones.
- **Codificación**: `Necesidad`, `Prioridades`, `Transiciones`, `Necesidades` (GenServer).

### 8.4 Recursos
- **Abstracción**: inventario por centro con historial; nunca negativo; asignación concurrente segura.
- **Descomposición**: registrar (validar ubicación) → entradas y salidas → transferencias entre centros →
  asignar (elegir recurso de la categoría primero en la zona, luego en cualquiera; todo o nada) → registrar
  movimiento → guardar → consultar críticos.
- **Reconocimiento de patrones**: el actor de la Guía 12 que atiende un mensaje a la vez resuelve la
  condición de carrera; escritura de archivos con `Stream` + `Enum.into(File.stream!(..., [:append]))`.
- **Codificación**: `Recurso`, `Movimiento`, `Centro`, `Centros`, `Inventario` (`elegir_recurso` recursiva).

### 8.5 Comunicación entre familiares
- **Abstracción**: personas afectadas con estado e historial, y mensajes para una persona o familia.
- **Descomposición**: registrar persona (estado inicial válido) → cambiar estado validando la transición y
  guardando el historial → buscar por documento, nombre, zona o estado → dejar mensaje → listar → marcar
  entregado/pendiente.
- **Reconocimiento de patrones**: mismo patrón de GenServer + persistencia; historial como en los logs de la
  Guía 11 (archivo que solo crece).
- **Codificación**: `Persona`, `Mensaje`, `Personas` (GenServer), `Transiciones`.

### 8.6 Mascotas
- **Abstracción**: reportes de mascotas perdidas y encontradas; encontrar parejas probables con un puntaje y
  cerrar ambos reportes una sola vez.
- **Descomposición**: reportar → separar perdidas y encontradas → recorrer todos los pares de la misma
  especie → calcular puntaje → quedarse con los ≥ 50 ordenados → marcar `posible_coincidencia` → confirmar
  (o descartar) dentro de un solo mensaje del GenServer.
- **Reconocimiento de patrones**: comparación de secuencias del parcial 2 (palabras en común contadas con
  recursión); doble recorrido recursivo de listas.
- **Codificación**: `Mascota`, `Coincidencias` (`pares_candidatos`, `calcular_puntaje`,
  `palabras_en_comun`), `Mascotas` (GenServer).

### 8.7 Albergues
- **Abstracción**: albergues con capacidad y ocupantes; nunca superar la capacidad; reporte de ocupación.
- **Descomposición**: registrar (también como centro, para recibir recursos) → ingreso: validar cupo →
  pedir a Personas el cambio a `en_albergue` → agregar al `MapSet` → guardar → salida análoga → reporte
  ordenado por porcentaje.
- **Reconocimiento de patrones**: `MapSet` como conjunto sin repetidos; GenServer que llama a otro sin ciclos
  (igual que Necesidades → Inventario).
- **Codificación**: `Albergue` (struct con `MapSet`), `Albergues` (GenServer).

## 9. Estructuras de datos usadas (y por qué)

| Estructura | Dónde | Por qué |
|---|---|---|
| Structs | los 10 de `lib/dominio/` | campos con nombre fijo, se validan con pattern matching (`%Necesidad{estado: "pendiente"}`) |
| Mapas `id => struct` | estado de cada GenServer | buscar por id en tiempo constante (`Map.get`, `Map.put`) |
| Listas | historial, movimientos, asignaciones, árbol | orden de llegada y recorrido recursivo `[cabeza \| cola]` |
| Tuplas | resultados `{:ok, ...}`/`{:error, ...}`, `{codigo, cantidad}`, `{fecha, anterior, nuevo, usuario}` | agrupar pocos valores fijos |
| Árbol (`NodoZona.hijos`) | zonas → sectores → puntos | la jerarquía del enunciado; se recorre con recursión |
| `MapSet` | ocupantes del albergue, usuarios conectados, códigos de una zona | conjunto sin repetidos: una persona no ocupa dos cupos |
| Stream | carga de archivos (`Archivo.leer_lineas_utiles`) | lectura perezosa línea por línea (Guía 10) |
| Átomos | tipos de nodo, comandos, motivos de error | valores fijos y comparables por pattern matching |

## 10. Funciones recursivas propias (marcadas `# RECURSIVA` en el código)

1. `ArbolZonas.insertar_hijo/3` + `insertar_en_lista/3` (recursión indirecta) — `lib/logica/arbol_zonas.ex`
2. `ArbolZonas.buscar/2` + `buscar_en_lista/2` — idem
3. `ArbolZonas.estadisticas/1` (estadísticas acumuladas de la zona y sus sectores) — idem
4. `ArbolZonas.construir/1`, `aplanar/1`, `codigos/1` — idem
5. `Prioridades.insertar_ordenado/2`, `ordenar/1`, `seleccionar_mayor/1` — `lib/logica/prioridades.ex`
6. `Inventario.elegir_recurso/4` — `lib/servidores/inventario.ex`
7. `Coincidencias.palabras_en_comun/2` y el recorrido de todos los pares — `lib/logica/coincidencias.ex`
8. `AnalizadorComandos.separar/4` (tokenizador) y `convertir_filtros/3` — `lib/logica/analizador_comandos.ex`
9. Además: `Consola.ciclo/1`, `Bitacora.loop/1`, `Validaciones.primer_error/1`, `Comandos.todos_ok/1`,
   `Consola.dibujar_arbol/2` y otras (37 marcas en total).

## 11. Decisiones de diseño

- **Pesos del puntaje de mascotas** (máximo 100): zona +30 (un animal perdido casi siempre aparece cerca),
  color +25 (se ve a simple vista y casi no se confunde), tamaño +20 (útil pero subjetivo: "mediano" vs
  "grande"), nombre +15 solo si ambos lo conocen (quien encuentra casi nunca lo sabe), +5 por palabra en común
  en las características con máximo +10 (texto libre, poco confiable). **Umbral 50**: hacen falta al menos dos
  atributos fuertes (por ejemplo zona + tamaño); color + tamaño en otra zona (45) no alcanza. Solo se comparan
  reportes de la misma especie.
- **Umbral crítico de recursos = 10** unidades, o menos de lo que falta por atender en su zona.
- **Asignación todo o nada** y de un solo recurso: si ningún recurso de la categoría alcanza, no se entrega
  nada y la necesidad no cambia; el error informa el máximo disponible. Se prefiere un recurso de la zona de la
  necesidad y, si no hay, de cualquier zona.
- **Hash SHA-256** de la contraseña (`:crypto.hash(:sha256, contraseña) |> Base.encode16()`): en el archivo
  queda la "huella", nunca la contraseña.
- **Prioridad**: ordena (`list_needs`, `pending_needs`) por prioridad descendente, luego fecha ascendente y luego
  id; `next_need` toma la primera.
- Una necesidad pasa a `asignada` solo cuando `assign_resource` cubre toda la cantidad (no con `update_need`).
- Una necesidad puede pertenecer a una zona, sector, punto o a un albergue/centro (por eso `check_shelter`
  muestra las necesidades con la zona igual al código del albergue).
- `report_person` acepta el formato del enunciado sin edad (`documento nombre zona estado`); la edad queda en 0.
- Una transferencia crea el recurso `R001-destino` en el centro destino, o suma en uno equivalente si ya existe.
- Las sesiones son `restart: :temporary`: si una sesión se cae, el usuario vuelve a hacer `connect`.

**Para confirmar con el docente:**
1. `connect` permite auto-registrarse con cualquier tipo, incluso `administrador` (así lo plantea el
   enunciado). ¿Se debe restringir el registro de administradores?
2. ¿Se exige estructura `mix` o modo distribuido con nodos? (No se hicieron: ver fase 7 del plan.)
3. ¿Es aceptable que `Persistencia` avise por pantalla las líneas dañadas (diferencia D3 del documento de
   correspondencia)?

## 12. Lo que se usó y NO se vio en clase

Lo exige el enunciado y está explicado con comentarios donde aparece por primera vez:
`GenServer` (`lib/servidores/usuarios.ex`), `Supervisor` (`lib/supervision/supervisor_principal.ex`),
`DynamicSupervisor` (`lib/supervision/supervisor_sesiones.ex`), `MapSet` (`lib/dominio/albergue.ex`),
ExUnit (`pruebas/transiciones_prueba.exs`), `:crypto` + `Base.encode16` (`lib/dominio/usuario.ex`).

Funciones de la biblioteca estándar que no estaban en la lista de clase, por ser necesarias o más claras:
`Code.require_file` (`pruebas/todas.exs`), `System.argv` (`iniciar.exs`), `Process.exit` (demostración de
fallos), `String.contains?` (búsqueda por nombre), `Enum.member?`, `Enum.reject`, `Enum.max`, `List.last`,
`Map.keys`, `Map.has_key?`, `Kernel.inspect` (para convertir un error a texto en la bitácora) y, solo en
pruebas y demo, `System.tmp_dir!`, `System.system_time` y `System.unique_integer` (carpetas temporales).
**No** se usaron `mix`, librerías externas, `Agent`, `Registry`, ETS, `Enum.reduce`, `for`, `with`, `Regex`,
`File.read`, `IO.inspect`, `raise` ni `Process.sleep`.

## 13. Lista de verificación final

| Ítem del enunciado | Cumple | Dónde |
|---|---|---|
| El sistema gestiona usuarios | ☑ | `lib/servidores/usuarios.ex`, `lib/logica/permisos.ex`, `lib/procesos/bitacora.ex` |
| El sistema gestiona zonas y sectores | ☑ | `lib/servidores/zonas.ex`, `lib/logica/arbol_zonas.ex` |
| El sistema gestiona necesidades | ☑ | `lib/servidores/necesidades.ex`, `lib/logica/prioridades.ex` |
| El sistema gestiona recursos | ☑ | `lib/servidores/inventario.ex`, `lib/servidores/centros.ex` |
| Existe comunicación entre familiares | ☑ | `lib/servidores/personas.ex` (personas, historial y mensajes) |
| Existe gestión de mascotas perdidas y encontradas | ☑ | `lib/servidores/mascotas.ex`, `lib/logica/coincidencias.ex` |
| Existe gestión de albergues | ☑ | `lib/servidores/albergues.ex`, `lib/dominio/albergue.ex` |
| Se utilizan varias estructuras de datos justificadas | ☑ | sección 9 de este README |
| Existen al menos cuatro funciones recursivas propias | ☑ | sección 10 (37 marcas `# RECURSIVA`) |
| Existen procesos concurrentes | ☑ | `lib/procesos/bitacora.ex`, GenServers, `Task.async` en `lib/interfaz/comandos.ex` y `demo_concurrencia.exs` |
| Se utiliza GenServer | ☑ | los 9 archivos de `lib/servidores/` |
| Existe Supervisor y/o DynamicSupervisor | ☑ | `lib/supervision/supervisor_principal.ex`, `lib/supervision/supervisor_sesiones.ex` |
| Se demuestra un conflicto concurrente resuelto correctamente | ☑ | `demo_concurrencia.exs`, `pruebas/concurrencia_prueba.exs` |
| Existe persistencia | ☑ | `lib/persistencia/`, `datos/`, `pruebas/supervision_prueba.exs` |
| Existen pruebas | ☑ | `pruebas/` (76 pruebas, `pruebas/todas.exs`) |
| Los diagramas corresponden al código final | ☑ | `docs/CORRESPONDENCIA_DIAGRAMAS.md` (diferencias menores D1–D6 documentadas) |
| Todos los integrantes participan en el repositorio y la sustentación | ☐ | lo hace el grupo: ver `docs/SUSTENTACION.md` y la sección 14 |

## 14. Sugerencia de commits (los hace el grupo)

Para que los tres participen en el repositorio, cada integrante puede subir los archivos de su bloque de
sustentación (`docs/SUSTENTACION.md`):

| Integrante | Mensaje sugerido | Archivos |
|---|---|---|
| 1 | `Base del proyecto: Util2, Archivo, structs y scripts de compilación` | `lib/util2.ex`, `lib/persistencia/archivo.ex`, `lib/dominio/`, `compilar.*` |
| 1 | `Zonas: árbol recursivo, tokenizador y consola` | `lib/logica/arbol_zonas.ex`, `lib/logica/analizador_comandos.ex`, `lib/servidores/zonas.ex`, `lib/interfaz/`, `iniciar.exs` y sus pruebas |
| 2 | `Inventario, necesidades y prioridad con conflicto concurrente` | `lib/servidores/inventario.ex`, `necesidades.ex`, `centros.ex`, `lib/logica/prioridades.ex`, `validaciones.ex`, `transiciones.ex`, `permisos.ex`, `demo_concurrencia.exs`, `pruebas/concurrencia_prueba.exs` |
| 3 | `Personas, mascotas, albergues, supervisión y bitácora` | `lib/servidores/personas.ex`, `mascotas.ex`, `albergues.ex`, `usuarios.ex`, `sesion.ex`, `lib/logica/coincidencias.ex`, `lib/procesos/`, `lib/supervision/`, `lib/persistencia/persistencia.ex` y sus pruebas |
| 3 | `Documentación, datos de ejemplo y correspondencia con diagramas` | `README.md`, `docs/`, `datos/` |

`ebin/` se puede regenerar en cualquier momento con `compilar.bat` o `compilar.sh`. Las carpetas que se crean
al ensayar el video (`datos_video/`, `datos_flujo/`) son de prueba y no hace falta subirlas.
