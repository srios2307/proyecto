# Sistema Distribuido de Coordinación y Gestión de Emergencias (Elixir)

Proyecto final de **Programación III** — Universidad del Quindío, Ingeniería de Sistemas y Computación.
Contexto: atención y coordinación posterior a un terremoto. 

Licencia: GNU GPL v3.

---

## 1. Requisitos

- Elixir **1.20.3** con Erlang/OTP **29** (`elixir --version`).
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

