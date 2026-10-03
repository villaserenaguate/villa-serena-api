# Cobertura de historias — contrato completo

Cada historia V3 tiene operación HTTP o mecanismo explícito. La cobertura describe el diseño, no confirma implementación. Nivel 2 permanece opcional.

| Historia | Nombre | Nivel | Operaciones / mecanismo | RF |
|---|---|---|---|---|
| HU-ADM-01 | Crear un empleado | 1 | `POST /api/v1/admin/empleados` | RF-ADM-003 |
| HU-ADM-02 | Editar, desactivar o restablecer la contraseña de un empleado | 1 | `GET /api/v1/admin/empleados`<br>`PATCH /api/v1/admin/empleados/{id}`<br>`PATCH /api/v1/admin/empleados/{id}/estado`<br>`POST /api/v1/admin/empleados/{id}/restablecer-contrasena` | RF-ADM-014, RF-ADM-015 |
| HU-ADM-03 | Gestionar tipos de habitación | 1 | `POST /api/v1/archivos/imagenes`<br>`GET /api/v1/admin/tipos-habitacion`<br>`POST /api/v1/admin/tipos-habitacion`<br>`GET /api/v1/admin/tipos-habitacion/{id}`<br>`PATCH /api/v1/admin/tipos-habitacion/{id}`<br>`PATCH /api/v1/admin/tipos-habitacion/{id}/estado`<br>`PUT /api/v1/admin/tipos-habitacion/{id}/fotos` | RF-ADM-005, RF-TAR-001 |
| HU-ADM-04 | Gestionar habitaciones | 1 | `GET /api/v1/admin/habitaciones`<br>`POST /api/v1/admin/habitaciones`<br>`PATCH /api/v1/admin/habitaciones/{id}`<br>`PATCH /api/v1/admin/habitaciones/{id}/estado` | RF-ADM-011 |
| HU-ADM-05 | Gestionar el menú de Room Service | 1 | `POST /api/v1/archivos/imagenes`<br>`GET /api/v1/admin/menu/categorias`<br>`POST /api/v1/admin/menu/categorias`<br>`PATCH /api/v1/admin/menu/categorias/{id}`<br>`GET /api/v1/admin/menu/items`<br>`POST /api/v1/admin/menu/items`<br>`PATCH /api/v1/admin/menu/items/{id}`<br>`PATCH /api/v1/admin/menu/items/{id}/estado`<br>`POST /api/v1/admin/menu/items/{id}/reactivar` | RF-ADM-012, RF-RS-006 |
| HU-ADM-06 | Gestionar temporadas | 1 | `GET /api/v1/admin/temporadas`<br>`POST /api/v1/admin/temporadas`<br>`PUT /api/v1/admin/temporadas/{id}`<br>`DELETE /api/v1/admin/temporadas/{id}` | RF-ADM-001, RF-TAR-002 |
| HU-ADM-07 | Configurar el ajuste de fin de semana | 1 | `PATCH /api/v1/admin/tipos-habitacion/{id}/ajuste-fin-semana` | RF-ADM-001, RF-TAR-003 |
| HU-ADM-08 | Configurar los datos del hotel y de facturación | 1 | `POST /api/v1/archivos/imagenes`<br>`GET /api/v1/admin/hotel`<br>`PUT /api/v1/admin/hotel` | RF-ADM-006, RF-FAC-005 |
| HU-ADM-09 | Ver los indicadores básicos | 1 | `GET /api/v1/admin/indicadores` | RF-ADM-002 |
| HU-ADM-10 | Consultar las incidencias de mantenimiento | 1 | `GET /api/v1/incidencias`<br>`GET /api/v1/incidencias/{id}` | RF-MAN-001, RF-SEG-003 |
| HU-ADM-11 | Gestionar amenidades y el Wi-Fi | 2 | `POST /api/v1/archivos/imagenes`<br>`GET /api/v1/admin/amenidades`<br>`POST /api/v1/admin/amenidades`<br>`PATCH /api/v1/admin/amenidades/{id}`<br>`PATCH /api/v1/admin/amenidades/{id}/estado`<br>`GET /api/v1/admin/wifi`<br>`PUT /api/v1/admin/wifi` | RF-ADM-013, RF-ADM-017 |
| HU-ADM-12 | Definir y asignar turnos | 2 | `GET /api/v1/admin/turnos`<br>`POST /api/v1/admin/turnos`<br>`PATCH /api/v1/admin/turnos/{id}`<br>`POST /api/v1/admin/turnos/{id}/desactivar`<br>`GET /api/v1/admin/asignaciones-turnos`<br>`POST /api/v1/admin/asignaciones-turnos`<br>`DELETE /api/v1/admin/asignaciones-turnos/{id}` | RF-ADM-009, RF-ADM-010 |
| HU-ADM-13 | Gestionar el inventario | 2 | `GET /api/v1/admin/inventario/productos`<br>`POST /api/v1/admin/inventario/productos`<br>`PATCH /api/v1/admin/inventario/productos/{id}`<br>`POST /api/v1/admin/inventario/productos/{id}/desactivar`<br>`GET /api/v1/admin/inventario/productos/{id}/movimientos`<br>`POST /api/v1/admin/inventario/productos/{id}/movimientos` | RF-ADM-004, RF-ADM-016 |
| HU-CM-01 | Recibir una reserva de un canal externo | 1 | `POST /api/v1/canal/reservas` | RF-CM-002, RF-CM-008, RF-HUE-001, RF-PAG-007, RF-PAG-013, RF-RES-001, RF-RES-003, RF-RES-010, RF-RES-014 |
| HU-CM-02 | Ver el canal de origen de las reservas | 1 | `GET /api/v1/reservas`<br>`GET /api/v1/reservas/calendario`<br>`GET /api/v1/reservas/{codigo}` | RF-CM-004, RF-RES-005, RF-RES-010 |
| HU-CM-03 | Enviar reservas de prueba con el canal simulado | 1 | `POST /api/v1/admin/canal-simulado/reservas` | RF-CM-005, RF-CM-008 |
| HU-HUE-01 | Ver la información del hotel | 1 | `GET /api/v1/publico/hotel` | RF-ADM-007 |
| HU-HUE-02 | Ver el catálogo de habitaciones | 1 | `GET /api/v1/publico/tipos-habitacion`<br>`GET /api/v1/publico/tipos-habitacion/{id}` | RF-HAB-006 |
| HU-HUE-03 | Buscar disponibilidad por fechas y huéspedes | 1 | `GET /api/v1/publico/disponibilidad` | RF-RES-001 |
| HU-HUE-04 | Ver el precio total de mi estadía | 1 | `GET /api/v1/publico/disponibilidad` | RF-TAR-004 |
| HU-HUE-05 | Ingresar mis datos y confirmar la reserva | 1 | `POST /api/v1/publico/reservas` | RF-HUE-001, RF-PAG-007, RF-RES-003, RF-RES-008, RF-RES-010, RF-RES-016 |
| HU-HUE-06 | Pagar mi reserva en línea | 1 | `POST /api/v1/publico/reservas/{codigo}/pago`<br>`GET /api/v1/publico/reservas/{codigo}/estado`<br>`POST /api/v1/pagos/stripe/webhook` | RF-PAG-003, RF-PAG-004, RF-PAG-012, RF-RES-009 |
| HU-HUE-07 | Recibir la confirmación por correo | 1 | <br>Automático: correo por Outbox cuando la reserva queda CONFIRMADA. Reutiliza creación/confirmación y webhook; no hay endpoint de enviar correo. | RF-NOT-002, RF-RES-014 |
| HU-HUE-08 | Entrar a la app con mi correo y un código | 1 | `POST /api/v1/auth/renovar`<br>`POST /api/v1/app/acceso/solicitar-codigo`<br>`POST /api/v1/app/acceso/verificar-codigo`<br>`POST /api/v1/app/cerrar-sesion` | RF-APP-001, RF-APP-006, RF-NOT-002 |
| HU-HUE-09 | Ver mis reservas y el detalle de mi estadía | 1 | `GET /api/v1/app/reservas`<br>`GET /api/v1/app/reservas/{codigo}` | RF-APP-002, RF-APP-004, RF-RES-013, RF-SEG-002 |
| HU-HUE-10 | Pedir room service | 1 | `GET /api/v1/app/reservas/{codigo}/menu`<br>`POST /api/v1/app/reservas/{codigo}/pedidos` | RF-APP-004, RF-RS-010 |
| HU-HUE-11 | Seguir mi pedido en vivo | 1 | `GET /api/v1/app/reservas/{codigo}/pedidos`<br>`GET /api/v1/app/reservas/{codigo}/pedidos/{id}` | RF-NOT-001, RF-RS-011 |
| HU-HUE-12 | Solicitar limpieza | 1 | `POST /api/v1/app/reservas/{codigo}/solicitudes/limpieza` | RF-APP-004, RF-SOL-001, RF-SOL-002 |
| HU-HUE-13 | Solicitar artículos | 1 | `GET /api/v1/app/reservas/{codigo}/articulos`<br>`POST /api/v1/app/reservas/{codigo}/solicitudes/articulos` | RF-APP-004, RF-SOL-002, RF-SOL-004 |
| HU-HUE-14 | Ver el estado de mis solicitudes | 1 | `GET /api/v1/app/reservas/{codigo}/solicitudes`<br>`POST /api/v1/app/reservas/{codigo}/solicitudes/{id}/cancelar` | RF-SOL-003, RF-SOL-005 |
| HU-HUE-15 | Ver mi cuenta | 1 | `GET /api/v1/app/reservas/{codigo}/cuenta` | RF-APP-004, RF-PAG-002, RF-PAG-011, RF-SEG-002 |
| HU-HUE-16 | Pagar mi saldo y hacer check-out desde la app | 1 | `POST /api/v1/pagos/stripe/webhook`<br>`GET /api/v1/app/reservas/{codigo}/checkout`<br>`POST /api/v1/app/reservas/{codigo}/checkout`<br>`POST /api/v1/app/reservas/{codigo}/pago-saldo`<br>`GET /api/v1/app/reservas/{codigo}/factura`<br>`GET /api/v1/facturas/{id}`<br>`GET /api/v1/facturas/{id}/pdf` | RF-APP-004, RF-APP-005, RF-FAC-001, RF-FAC-002, RF-NOT-002, RF-PAG-003, RF-PAG-004, RF-PAG-010, RF-REC-002, RF-REC-004, RF-REC-005 |
| HU-HUE-17 | Recibir notificaciones en mi teléfono | 1 | `POST /api/v1/app/cerrar-sesion`<br>`POST /api/v1/app/reservas/{codigo}/checkout`<br>`POST /api/v1/app/dispositivos-push`<br>`DELETE /api/v1/app/dispositivos-push/{id}` | RF-APP-005, RF-NOT-003 |
| HU-HUE-18 | Ver las amenidades y el Wi-Fi | 2 | `GET /api/v1/app/amenidades`<br>`GET /api/v1/app/wifi` | RF-APP-003 |
| HU-MYL-01 | Ver las habitaciones pendientes de limpieza | 1 | `GET /api/v1/limpieza/habitaciones` | RF-LIM-001, RF-LIM-010, RF-NOT-001 |
| HU-MYL-02 | Iniciar o interrumpir la limpieza de una habitación | 1 | `POST /api/v1/limpieza/habitaciones/{id}/iniciar`<br>`POST /api/v1/limpieza/habitaciones/{id}/interrumpir` | RF-HAB-004, RF-LIM-002 |
| HU-MYL-03 | Marcar la limpieza como terminada | 1 | `POST /api/v1/limpieza/habitaciones/{id}/terminar` | RF-HAB-004, RF-LIM-003 |
| HU-MYL-04 | Ver y tomar solicitudes de huéspedes | 1 | `GET /api/v1/limpieza/solicitudes`<br>`POST /api/v1/limpieza/solicitudes/{id}/tomar` | RF-LIM-004, RF-LIM-015, RF-NOT-001, RF-SEG-002, RF-SOL-002 |
| HU-MYL-05 | Atender una solicitud | 1 | `POST /api/v1/limpieza/solicitudes/{id}/atender` | RF-LIM-005 |
| HU-MYL-06 | Reportar un daño | 1 | `POST /api/v1/incidencias`<br>`POST /api/v1/archivos/imagenes` | RF-HAB-005, RF-LIM-006, RF-MAN-003, RF-MAN-006, RF-SOL-002 |
| HU-MYL-07 | Ver las incidencias y tomar una | 1 | `GET /api/v1/incidencias`<br>`GET /api/v1/incidencias/{id}`<br>`POST /api/v1/incidencias/{id}/tomar` | RF-MAN-005, RF-MAN-006, RF-MAN-013, RF-SEG-002 |
| HU-MYL-08 | Resolver una incidencia | 1 | `POST /api/v1/incidencias/{id}/resolver` | RF-MAN-006, RF-MAN-008, RF-MAN-014 |
| HU-EMP-01 | Iniciar y cerrar sesión en la web privada | 1 | `POST /api/v1/auth/login`<br>`POST /api/v1/auth/renovar`<br>`POST /api/v1/auth/cerrar-sesion`<br>`GET /api/v1/auth/yo`<br>`POST /api/v1/auth/ws-ticket` | RF-SEG-001, RF-SEG-002 |
| HU-EMP-02 | Cambiar mi contraseña temporal | 1 | `POST /api/v1/auth/cambiar-contrasena`<br>`GET /api/v1/auth/yo` | RF-SEG-004 |
| HU-REC-01 | Registrar un huésped | 1 | `POST /api/v1/huespedes`<br>`GET /api/v1/huespedes` | RF-HUE-001 |
| HU-REC-02 | Registrar huéspedes adicionales | 1 | `POST /api/v1/reservas/{codigo}/huespedes-adicionales` | RF-HUE-002 |
| HU-REC-03 | Consultar disponibilidad | 1 | `GET /api/v1/reservas/disponibilidad` | RF-RES-001, RF-TAR-004 |
| HU-REC-04 | Crear una reserva | 1 | `POST /api/v1/reservas` | RF-PAG-007, RF-RES-002, RF-RES-003, RF-RES-010, RF-RES-014, RF-TAR-004 |
| HU-REC-05 | Cancelar una reserva | 1 | `GET /api/v1/reservas/{codigo}/cancelacion`<br>`POST /api/v1/reservas/{codigo}/cancelar` | RF-PAG-009, RF-RES-005, RF-RES-016 |
| HU-REC-06 | Buscar reservas | 1 | `GET /api/v1/reservas`<br>`GET /api/v1/reservas/{codigo}` | RF-RES-006, RF-RES-007, RF-SEG-003 |
| HU-REC-07 | Asignar o cambiar la habitación antes del check-in | 1 | `PUT /api/v1/reservas/{codigo}/habitacion`<br>`GET /api/v1/habitaciones/disponibles` | RF-HAB-002, RF-RES-003, RF-RES-016 |
| HU-REC-08 | Ver el calendario Gantt | 1 | `GET /api/v1/reservas/calendario` | RF-RES-012, RF-RES-016 |
| HU-REC-09 | Crear una reserva seleccionando días en el Gantt | 2 | `POST /api/v1/reservas`<br>`GET /api/v1/reservas/calendario`<br>UI opcional del Gantt: precargar fechas y habitación y reutilizar POST /reservas. No requiere endpoint propio. | RF-RES-015 |
| HU-REC-10 | Ver el estado de las habitaciones | 1 | `GET /api/v1/habitaciones` | RF-HAB-001, RF-HAB-003, RF-NOT-001 |
| HU-REC-11 | Marcar una habitación libre como sucia | 1 | `POST /api/v1/habitaciones/{id}/marcar-sucia` | RF-HAB-003, RF-HAB-004 |
| HU-REC-12 | Realizar el check-in | 1 | `POST /api/v1/reservas/{codigo}/check-in` | RF-APP-004, RF-HAB-003, RF-REC-001 |
| HU-REC-13 | Consultar la cuenta y agregar cargos | 1 | `GET /api/v1/cuentas/{codigo}`<br>`POST /api/v1/cuentas/{codigo}/cargos`<br>`POST /api/v1/cuentas/{codigo}/cargos/{id}/anular` | RF-PAG-002, RF-PAG-007, RF-PAG-008, RF-PAG-011 |
| HU-REC-14 | Realizar el check-out con pago único | 1 | `GET /api/v1/checkout/{codigo}`<br>`POST /api/v1/checkout/{codigo}` | RF-FAC-001, RF-HAB-003, RF-HAB-005, RF-PAG-001, RF-REC-002, RF-REC-004, RF-REC-005 |
| HU-REC-15 | Emitir la factura | 1 | `POST /api/v1/checkout/{codigo}`<br>`GET /api/v1/facturas/{id}`<br>`GET /api/v1/facturas/{id}/pdf`<br>Factura dentro del check-out; solo lectura/descarga por HTTP, sin emisión manual. | RF-FAC-001, RF-FAC-002, RF-FAC-003, RF-NOT-002 |
| HU-REC-16 | Imprimir la factura | 1 | `GET /api/v1/facturas/{id}`<br>Impresión desde HTML/CSS de la web en 80 mm/carta; no cambia estado y no requiere endpoint de impresión. | RF-FAC-003 |
| HU-REC-17 | Reportar un daño en una habitación | 1 | `POST /api/v1/incidencias`<br>`POST /api/v1/archivos/imagenes` | RF-HAB-005, RF-MAN-003, RF-SOL-002 |
| HU-RS-01 | Ver la cola de pedidos activos | 1 | `GET /api/v1/room-service/pedidos` | RF-NOT-001, RF-RS-001 |
| HU-RS-02 | Ver el detalle de un pedido | 1 | `GET /api/v1/room-service/pedidos/{id}` | RF-RS-002, RF-SEG-002, RF-SEG-003 |
| HU-RS-03 | Avanzar el estado de un pedido | 1 | `POST /api/v1/room-service/pedidos/{id}/avanzar` | RF-RS-004 |
| HU-RS-04 | Cancelar un pedido | 1 | `POST /api/v1/room-service/pedidos/{id}/cancelar` | RF-RS-005 |
| HU-RS-05 | Consultar el menú y marcar ítems agotados | 1 | `GET /api/v1/room-service/menu`<br>`POST /api/v1/room-service/menu/items/{id}/agotar` | RF-RS-006 |
| HU-RS-06 | Generar el cargo del pedido entregado | 1 | `POST /api/v1/room-service/pedidos/{id}/avanzar`<br>Cargo único al avanzar a ENTREGADO; no tiene POST de cargo automático. | RF-RS-007 |
| HU-RS-07 | Recibir aviso de pedido nuevo | 1 | <br>WebSocket evento NUEVO_PEDIDO en /topic/pedidos; la cola y detalle GET se reutilizan. Sonido opcional Nivel 2, sin endpoint nuevo. | RF-NOT-001, RF-RS-009, RF-RS-012 |

**Cobertura:** 68/68 historias. Infraestructura, CI/CD, backups, primer administrador, monitorización y diseño futuro de Booking/Expedia no crean endpoints de negocio. No se incluyeron funcionalidades descartadas (check-in anticipado, modificación de reservas, pedidos telefónicos, pagos parciales, FEL/SAT, objetos olvidados o consumo integrado de inventario).
