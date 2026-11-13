# Guion del video de demostración

Comandos exactos, en orden. Todo se probó de punta a punta antes de escribir este guion: si se escriben igual,
las respuestas son las que aparecen aquí. Duración estimada: 20–25 minutos.

Reparto sugerido (igual que `docs/SUSTENTACION.md`):
- **Integrante 1**: partes 0, 1 y 3.1–3.3 (compilación, pruebas, usuarios, zonas, consola y tokenizador).
- **Integrante 2**: partes 2 y 3.4–3.5 (concurrencia, necesidades, prioridad e inventario).
- **Integrante 3**: partes 3.6–3.9, 4, 5 y 6 (familiares, mascotas, albergues, supervisión, persistencia y diagramas).

---

## 0. Preparación (antes de grabar)

Abrir una terminal en `proyecto_final/`. En Windows, para ver bien las tildes:

```bash
chcp 65001
```

```bash
compilar.bat
```

Debe terminar en `Compilacion terminada` sin ninguna línea `warning`.
Mostrar rápidamente la estructura de carpetas y `docs/diagramas/5_estructura.png` (ítem "diagramas").

## 1. Pruebas (ítem: "Existen pruebas")

```bash
elixir -pa ebin pruebas/todas.exs
```

Resultado esperado: `Result: 76 passed`. Explicar que el "Aviso … línea 3 dañada" es intencional (prueba que
una línea dañada se ignora sin detener el sistema). Mencionar los archivos de `pruebas/` (tabla del README).

## 2. Concurrencia (ítems: "procesos concurrentes", "conflicto concurrente resuelto")

```bash
elixir -pa ebin demo_concurrencia.exs
```

Explicar mientras corre, mostrando `docs/diagramas/3b_secuencia_conflicto.png`:
1. N001 (laura, 30 L) y N002 (pedro, 25 L) piden el mismo recurso R001 de 50 L **al mismo tiempo** con
   `Task.async`. Se ve `Task A … OK` y `Task B … ERROR -> Inventario insuficiente: solo hay 20 …`.
   "Inventario final de R001: 20 litros. Total asignado: 30 (nunca 55)."
2. 20 tareas × 10 unidades sobre 100 → `Confirmadas: 10 … Inventario final: 0`.
3. 5 ingresos simultáneos a un albergue de 2 cupos → `Ocupación final: 2/2`.
4. Dos confirmaciones simultáneas de la misma mascota → un `OK` y un `ERROR … no se resuelve dos veces`.
5. Resto del flujo del enunciado (Andrés, mensaje, mascota, `summary`).
6. Se mata `Inventario` y el supervisor lo reinicia con el mismo dato.
Final: `RESULTADO: 9 de 9 verificaciones correctas.` Por qué funciona: cada GenServer atiende un mensaje a la
vez y verifica + resta + guarda dentro del mismo `handle_call` (abrir `lib/servidores/inventario.ex`,
función `elegir_recurso/4` y el `handle_call({:asignar, ...})`).

## 3. Consola con todos los requisitos (carpeta limpia `datos_video`)

```bash
elixir -pa ebin iniciar.exs datos_video
```

### 3.1 Usuarios, roles y sesiones (ítem: "gestiona usuarios")

```
help
connect admin admin123 administrador centro "Administrador General"
```
→ `Usuario admin registrado como administrador …` (registro automático).

### 3.2 Zonas y sectores (ítems: "gestiona zonas y sectores", recursión)

```
register_zone centro "Zona Centro" alto 500
register_sector centro S3 "Sector 3" critico 120
register_point S3 PA3 "Punto de atencion sector 3" critico 15
register_zone zona_norte "Zona Norte" medio 300
register_sector zona_norte N1 "Barrio La Cumbre" alto 90
register_point centro P9 "Punto mal ubicado"
list_zones
zone_stats centro
```
→ el punto mal ubicado da `ERROR: No se puede poner un 'punto' dentro de un 'zona' …`.
→ `zone_stats centro`: `635 personas afectadas, 1 sectores, 1 puntos, nivel más crítico: critico`
(estadística acumulada, calculada con la función recursiva `ArbolZonas.estadisticas/1`).

```
register_center centro_acopio_1 "Centro de Acopio 1" centro_acopio centro
register_shelter A01 "Albergue Norte" zona_norte 150
register_shelter A02 "Albergue Pequeno" centro 1
connect laura 1234 coordinador centro "Laura Gomez"
disconnect
connect laura 9999
connect laura 1234
```
→ `disconnect` cierra la sesión de laura y queda activa la de admin.
→ `connect laura 9999`: `ERROR: Usuario o contraseña incorrectos.`
→ `connect laura 1234`: `Bienvenido de nuevo, Laura Gomez (coordinador).` (diagrama `3a`).

### 3.3 Flujo de ejemplo del enunciado (necesidad crítica de 30 L sobre 50 L)

```
register_need agua 30 critica centro "Punto de atencion sector 3"
register_resource R001 agua 50 litros centro_acopio_1 "Agua potable"
assign_resource N001 agua 30
connect pedro 5678 coordinador centro "Pedro Ruiz"
register_need agua 25 alta centro "Albergue temporal sector 3"
assign_resource N002 agua 25
```
→ N001 queda `asignada` (30/30). N002: `ERROR: Inventario insuficiente: solo hay 20 disponibles …`.
Nunca se entregan 55 litros.

### 3.4 Necesidades y prioridad (ítem: "gestiona necesidades")

```
register_need medicamentos 5 media S3 "Botiquin del hospital"
list_needs
list_needs zona=centro prioridad=critica
pending_needs
next_need
```
→ `list_needs` sale ordenada por prioridad (crítica, alta, media) con la inserción ordenada recursiva.
→ `next_need`: `Siguiente necesidad a atender: N002 [alta] …`.

### 3.5 Recursos e inventario (ítem: "gestiona recursos")

```
resource_in R001 40
assign_resource N002 R001 25
resource_out R001 100
resource_out R001 5
transfer_resource R001 centro_acopio_1 A01 5
resource_history R001
list_resources zona=zona_norte
critical_resources
zone_status centro
```
→ entrada (60 L), asignación por código (N002 queda 25/25), salida rechazada (`solo hay 35`, nunca negativo),
salida de 5, transferencia al Albergue Norte (crea `R001-A01`), historial con 6 movimientos `MV0001…MV0006`,
`R001-A01` aparece como crítico (5 < 10). `zone_status centro` usa `Task.async` para consultar varios
GenServers en paralelo.

```
use laura
update_need N001 en_atencion
update_need N001 atendida
assign_resource N001 agua 1
update_need N001 cancelada
```
→ las dos últimas: `ERROR: La necesidad ya está cerrada …: no consume más recursos.` (no se cierra dos veces).

### 3.6 Comunicación entre familiares (ítem: "comunicación entre familiares")

```
connect carlos 2222 ciudadano zona_norte "Carlos Mora"
assign_resource N003 agua 1
report_person 1001 "Andres Perez" 34 zona_norte localizada
report_person 1002 "Maria Lopez" 61 centro reportada
send_family_message 1001 "Estoy bien, estoy en el albergue norte"
report_pet lost perro "Luna" negra mediana zona_norte 3001234567 "collar rojo"
```
→ `assign_resource` como ciudadano: `ERROR: Un usuario de tipo 'ciudadano' no tiene permiso …` (roles).

### 3.7 Albergues (ítem: "gestión de albergues")

```
connect sofia 1111 voluntario zona_norte "Sofia Diaz"
register_entry A01 1001
register_entry A02 1002
register_entry A02 1001
check_shelter A01
```
→ Andrés entra al Albergue Norte (su estado pasa a `en_albergue`); A02 tiene 1 cupo: el tercer ingreso da
`ERROR: El albergue está lleno: no hay cupos.`

```
find_person nombre=andres
person_history 1001
list_family_messages 1001
mark_message MS001 entregado
```
→ el historial muestra `- -> localizada (por carlos)` y `localizada -> en_albergue (por sofia)`.

### 3.8 Mascotas (ítem: "mascotas perdidas y encontradas")

```
report_pet found perro desconocido negra mediana zona_norte 3109876543 "collar rojo, asustada"
list_pets especie=perro
match_pets
use laura
confirm_pet_match MA001 MA002
confirm_pet_match MA001 MA002
```
→ `MA001 (perdida) <-> MA002 (encontrada): 85 puntos` (zona 30 + color 25 + tamaño 20 + 2 palabras 10),
mostrando `docs/diagramas/3c_secuencia_mascotas.png`.
→ segunda confirmación: `ERROR: El reporte ya estaba resuelto: no se resuelve dos veces.`

### 3.9 Reportes, sesiones y bitácora

```
register_exit A01 1001 reunificada
shelter_report
summary
sessions
```
→ `summary` (coordinadora): recursos restantes, necesidades por estado y prioridad, personas por estado,
mensajes y mascotas, y albergues ordenados por ocupación. `sessions`: 5 sesiones abiertas a la vez, cada una
es un proceso `Sesion` bajo el `DynamicSupervisor`.

## 4. Supervisión (ítems: "GenServer", "Supervisor y DynamicSupervisor")

```
use admin
crash_server inventario
list_resources
list_users
activity laura
exit
```
→ `inventario se detuvo a la fuerza (#PID<…>) y el supervisor lo reinició (#PID<…>)`; `list_resources`
muestra lo mismo que antes (R001 25 L y R001-A01 5 L): el nuevo proceso cargó `recursos.csv`.
Mostrar `docs/diagramas/4_arbol_otp.png` y `lib/supervision/supervisor_principal.ex`.
→ `activity laura`: 16 registros de la bitácora (proceso simple `spawn_link` + `receive`).

## 5. Persistencia (ítem: "existe persistencia")

Abrir `datos_video/` y mostrar dos archivos (por ejemplo `necesidades.csv` y `movimientos.csv`). Luego:

```bash
elixir -pa ebin iniciar.exs datos_video
```

```
connect laura 1234
list_needs
list_resources
person_history 1001
list_pets
exit
```
→ todo sigue ahí: N001 `atendida`, N002 `asignada`, N003 `pendiente`; R001 25 L; Andrés `reunificada` con
3 cambios en su historial; MA001 y MA002 `resuelta` con `-> coincide con …`.

## 6. Código y diagramas (ítems: "estructuras de datos", "funciones recursivas", "diagramas = código")

- Abrir `docs/CORRESPONDENCIA_DIAGRAMAS.md` y recorrer 2 o 3 filas abriendo el archivo:línea que indica.
- Mostrar 2 funciones recursivas con su caso base y caso recursivo (por ejemplo
  `ArbolZonas.estadisticas/1` y `AnalizadorComandos.separar/4`).
- Mostrar el `MapSet` de `Albergue.ocupantes` y el árbol `NodoZona.hijos` (sección 9 del README).
- Cerrar con la lista de verificación (sección 13 del README).

## Opcional: datos de ejemplo

```bash
elixir -pa ebin iniciar.exs
```

```
connect laura 1234
zone_status centro
critical_resources
exit
```
Usa la carpeta `datos/` incluida en el repositorio (comandos que la generaron: `docs/datos_ejemplo_comandos.txt`).
