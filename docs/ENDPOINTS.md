# Endpoints y autenticación — Villa Serena

Propuesta completa del 3 de octubre de 2026. Rama `obj0-contrato-completo`. Fuente principal: [openapi.yaml](../openapi.yaml). No está congelada y no afirma que los endpoints estén implementados. Josué, Pablo y Hugo deben revisar sus módulos.

**Método HTTP y autenticación son distintos:** un GET puede exigir JWT. `security: []` indica que no se exige JWT, pero login requiere contraseña, verificación requiere OTP y renovación requiere refresh válido. Canal y Stripe usan credenciales propias.

| Método | Uso |
|---|---|
| GET | Consultar sin cambiar datos |
| POST | Crear o ejecutar acciones, como cancelar, tomar o confirmar check-out |
| PUT | Reemplazar una representación completa |
| PATCH | Actualizar campos parciales o un estado de catálogo |
| DELETE | Eliminar solo donde la historia lo permite: temporada, asignación o dispositivo push |

Los registros con historial (reservas, cargos, pedidos, solicitudes, incidencias) no se borran mediante DELETE. Los catálogos con activación se desactivan. ADMIN tiene solo sus permisos; no hereda los de operación.

## Resumen

130 operaciones: 29 conservadas de parte 1 y 101 nuevas. 109 de Nivel 1 y 21 opcionales de Nivel 2.

| Grupo | Operaciones |
|---|---:|
| auth | 6 |
| publico | 7 |
| pagos | 1 |
| canal | 1 |
| huespedes | 2 |
| reservas | 10 |
| habitaciones | 3 |
| app | 23 |
| room-service | 6 |
| limpieza | 7 |
| incidencias | 5 |
| cuentas | 3 |
| checkout | 2 |
| facturas | 2 |
| archivos | 1 |
| admin | 51 |

## auth

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/auth/login` | Correo y contraseña · sin JWT | Personal | 1 | LoginPeticion | 200 SesionEmpleado | HU-EMP-01 |
| POST | `/api/v1/auth/renovar` | Refresh token · sin JWT | Sesión válida | 1 | RefreshPeticion | 200 Tokens | HU-EMP-01, HU-HUE-08 |
| POST | `/api/v1/auth/cerrar-sesion` | JWT | ADMIN, RECEPCION, ROOM_SERVICE, MANTENIMIENTO_LIMPIEZA | 1 | RefreshPeticion | 204 sin cuerpo | HU-EMP-01 |
| POST | `/api/v1/auth/cambiar-contrasena` | JWT | ADMIN, RECEPCION, ROOM_SERVICE, MANTENIMIENTO_LIMPIEZA | 1 | CambiarContrasenaPeticion | 200 SesionEmpleado | HU-EMP-02 |
| GET | `/api/v1/auth/yo` | JWT | ADMIN, RECEPCION, ROOM_SERVICE, MANTENIMIENTO_LIMPIEZA | 1 | Sin cuerpo | 200 EmpleadoSesion | HU-EMP-01, HU-EMP-02 |
| POST | `/api/v1/auth/ws-ticket` | JWT | ADMIN, RECEPCION, ROOM_SERVICE, MANTENIMIENTO_LIMPIEZA | 1 | Sin cuerpo | 200 WsTicket | HU-EMP-01 |

## publico

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/publico/hotel` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 Hotel | HU-HUE-01 |
| GET | `/api/v1/publico/tipos-habitacion` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 TipoHabitacionPublico[] | HU-HUE-02 |
| GET | `/api/v1/publico/tipos-habitacion/{id}` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 TipoHabitacionPublico | HU-HUE-02 |
| GET | `/api/v1/publico/disponibilidad` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 OpcionDisponiblePublica[] | HU-HUE-03, HU-HUE-04 |
| POST | `/api/v1/publico/reservas` | Pública · sin JWT | Cualquiera | 1 | ReservaWebPeticion | 201 ReservaWebCreada | HU-HUE-05 |
| POST | `/api/v1/publico/reservas/{codigo}/pago` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 PagoIniciado | HU-HUE-06 |
| GET | `/api/v1/publico/reservas/{codigo}/estado` | Pública · sin JWT | Cualquiera | 1 | Sin cuerpo | 200 EstadoReservaPublico | HU-HUE-06 |

## pagos

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/pagos/stripe/webhook` | Firma Stripe | STRIPE | 1 | EventoStripe | 200 sin cuerpo | HU-HUE-06, HU-HUE-16 |

## canal

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/canal/reservas` | Canal + clave | CANAL | 1 | ReservaCanalPeticion | 200 ReservaCanalRespuesta; 201 ReservaCanalRespuesta | HU-CM-01 |

## huespedes

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/huespedes` | JWT | RECEPCION | 1 | HuespedDatos | 200 RegistroHuespedRespuesta; 201 RegistroHuespedRespuesta | HU-REC-01 |
| GET | `/api/v1/huespedes` | JWT | RECEPCION | 1 | Query: q* | 200 Huesped[] | HU-REC-01 |

## reservas

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/reservas/disponibilidad` | JWT | RECEPCION | 1 | Sin cuerpo | 200 OpcionDisponibleRecepcion[] | HU-REC-03 |
| POST | `/api/v1/reservas` | JWT | RECEPCION | 1 | ReservaRecepcionPeticion | 201 ReservaDetalle | HU-REC-04, HU-REC-09 |
| GET | `/api/v1/reservas` | JWT | RECEPCION | 1 | Query: texto, codigo, desde, hasta, estado, canal, rapido, page, size | 200 PaginaReservas | HU-REC-06, HU-CM-02 |
| GET | `/api/v1/reservas/calendario` | JWT | RECEPCION | 1 | Query: desde*, hasta* | 200 CalendarioReservas | HU-REC-08, HU-REC-09, HU-CM-02 |
| GET | `/api/v1/reservas/{codigo}` | JWT | RECEPCION | 1 | Sin cuerpo | 200 ReservaDetalle | HU-REC-06, HU-CM-02 |
| POST | `/api/v1/reservas/{codigo}/huespedes-adicionales` | JWT | RECEPCION | 1 | HuespedAdicionalDatos | 201 HuespedAdicional | HU-REC-02 |
| GET | `/api/v1/reservas/{codigo}/cancelacion` | JWT | RECEPCION | 1 | Sin cuerpo | 200 VistaPreviaCancelacion | HU-REC-05 |
| POST | `/api/v1/reservas/{codigo}/cancelar` | JWT | RECEPCION | 1 | CancelarReservaPeticion | 200 ReservaDetalle | HU-REC-05 |
| PUT | `/api/v1/reservas/{codigo}/habitacion` | JWT | RECEPCION | 1 | AsignarHabitacionPeticion | 200 ReservaDetalle | HU-REC-07 |
| POST | `/api/v1/reservas/{codigo}/check-in` | JWT | RECEPCION | 1 | Sin cuerpo | 200 ReservaDetalle | HU-REC-12 |

## habitaciones

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/habitaciones` | JWT | RECEPCION | 1 | Query: ocupacion, condicion, tipoHabitacionId, piso | 200 HabitacionEstado[] | HU-REC-10 |
| GET | `/api/v1/habitaciones/disponibles` | JWT | RECEPCION | 1 | Query: tipoHabitacionId* | 200 HabitacionReferencia[] | HU-REC-07 |
| POST | `/api/v1/habitaciones/{id}/marcar-sucia` | JWT | RECEPCION | 1 | Sin cuerpo | 200 HabitacionEstado | HU-REC-11 |

## app

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/app/acceso/solicitar-codigo` | Pública · sin JWT | Cualquiera | 1 | CodigoAccesoPeticion | 200 MensajeGenerico | HU-HUE-08 |
| POST | `/api/v1/app/acceso/verificar-codigo` | OTP · sin JWT | Huésped con código | 1 | VerificarCodigoPeticion | 200 Tokens | HU-HUE-08 |
| POST | `/api/v1/app/cerrar-sesion` | JWT | HUESPED · HUESPED solo propios | 1 | RefreshPeticion | 204 sin cuerpo | HU-HUE-08, HU-HUE-17 |
| GET | `/api/v1/app/reservas` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 ReservaAppResumen[] | HU-HUE-09 |
| GET | `/api/v1/app/reservas/{codigo}` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 ReservaAppDetalle | HU-HUE-09 |
| GET | `/api/v1/app/reservas/{codigo}/menu` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 MenuApp | HU-HUE-10 |
| GET | `/api/v1/app/reservas/{codigo}/pedidos` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 PedidoHuesped[] | HU-HUE-11 |
| POST | `/api/v1/app/reservas/{codigo}/pedidos` | JWT | HUESPED · HUESPED solo propios | 1 | CrearPedidoPeticion | 201 PedidoHuesped | HU-HUE-10 |
| GET | `/api/v1/app/reservas/{codigo}/pedidos/{id}` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 PedidoHuesped | HU-HUE-11 |
| GET | `/api/v1/app/reservas/{codigo}/articulos` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 ArticuloSolicitable[] | HU-HUE-13 |
| GET | `/api/v1/app/reservas/{codigo}/solicitudes` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 SolicitudHuesped[] | HU-HUE-14 |
| POST | `/api/v1/app/reservas/{codigo}/solicitudes/limpieza` | JWT | HUESPED · HUESPED solo propios | 1 | SolicitarLimpiezaPeticion | 201 SolicitudHuesped | HU-HUE-12 |
| POST | `/api/v1/app/reservas/{codigo}/solicitudes/articulos` | JWT | HUESPED · HUESPED solo propios | 1 | SolicitarArticulosPeticion | 201 SolicitudHuesped | HU-HUE-13 |
| POST | `/api/v1/app/reservas/{codigo}/solicitudes/{id}/cancelar` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 SolicitudHuesped | HU-HUE-14 |
| GET | `/api/v1/app/reservas/{codigo}/cuenta` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 CuentaHuesped | HU-HUE-15 |
| GET | `/api/v1/app/reservas/{codigo}/checkout` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 VistaCheckout | HU-HUE-16 |
| POST | `/api/v1/app/reservas/{codigo}/checkout` | JWT | HUESPED · HUESPED solo propios | 1 | CheckoutAppPeticion | 200 CheckoutResultado | HU-HUE-16, HU-HUE-17 |
| POST | `/api/v1/app/reservas/{codigo}/pago-saldo` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 PagoIniciado; 204 sin cuerpo | HU-HUE-16 |
| GET | `/api/v1/app/reservas/{codigo}/factura` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 FacturaDetalle | HU-HUE-16 |
| POST | `/api/v1/app/dispositivos-push` | JWT | HUESPED · HUESPED solo propios | 1 | DispositivoPushPeticion | 200 DispositivoPushRegistrado; 201 DispositivoPushRegistrado | HU-HUE-17 |
| DELETE | `/api/v1/app/dispositivos-push/{id}` | JWT | HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 204 sin cuerpo | HU-HUE-17 |
| GET | `/api/v1/app/amenidades` | JWT | HUESPED | 2 · opcional | Sin cuerpo | 200 AmenidadApp[] | HU-HUE-18 |
| GET | `/api/v1/app/wifi` | JWT | HUESPED | 2 · opcional | Sin cuerpo | 200 Wifi | HU-HUE-18 |

## room-service

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/room-service/pedidos` | JWT | ROOM_SERVICE | 1 | Sin cuerpo | 200 PedidoRoomService[] | HU-RS-01 |
| GET | `/api/v1/room-service/pedidos/{id}` | JWT | ROOM_SERVICE | 1 | Sin cuerpo | 200 PedidoRoomService | HU-RS-02 |
| POST | `/api/v1/room-service/pedidos/{id}/avanzar` | JWT | ROOM_SERVICE | 1 | AvanzarPedidoPeticion | 200 PedidoRoomService | HU-RS-03, HU-RS-06 |
| POST | `/api/v1/room-service/pedidos/{id}/cancelar` | JWT | ROOM_SERVICE | 1 | MotivoPeticion | 200 PedidoRoomService | HU-RS-04 |
| GET | `/api/v1/room-service/menu` | JWT | ROOM_SERVICE | 1 | Sin cuerpo | 200 MenuApp | HU-RS-05 |
| POST | `/api/v1/room-service/menu/items/{id}/agotar` | JWT | ROOM_SERVICE | 1 | Sin cuerpo | 200 ItemMenuApp | HU-RS-05 |

## limpieza

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/limpieza/habitaciones` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 HabitacionLimpieza[] | HU-MYL-01 |
| POST | `/api/v1/limpieza/habitaciones/{id}/iniciar` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 ResultadoCondicionHabitacion | HU-MYL-02 |
| POST | `/api/v1/limpieza/habitaciones/{id}/interrumpir` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 ResultadoCondicionHabitacion | HU-MYL-02 |
| POST | `/api/v1/limpieza/habitaciones/{id}/terminar` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 ResultadoCondicionHabitacion | HU-MYL-03 |
| GET | `/api/v1/limpieza/solicitudes` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 SolicitudLimpieza[] | HU-MYL-04 |
| POST | `/api/v1/limpieza/solicitudes/{id}/tomar` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 SolicitudLimpieza | HU-MYL-04 |
| POST | `/api/v1/limpieza/solicitudes/{id}/atender` | JWT | MANTENIMIENTO_LIMPIEZA (LIMPIEZA/AMBAS) | 1 | Sin cuerpo | 200 SolicitudLimpieza | HU-MYL-05 |

## incidencias

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/incidencias` | JWT | RECEPCION, MANTENIMIENTO_LIMPIEZA | 1 | ReportarIncidenciaPeticion | 201 IncidenciaCreada | HU-MYL-06, HU-REC-17 |
| GET | `/api/v1/incidencias` | JWT | ADMIN, MANTENIMIENTO_LIMPIEZA (MANTENIMIENTO/AMBAS) | 1 | Query: estado, habitacionId, tecnicoId | 200 IncidenciaResumen[] | HU-MYL-07, HU-ADM-10 |
| GET | `/api/v1/incidencias/{id}` | JWT | ADMIN, MANTENIMIENTO_LIMPIEZA (MANTENIMIENTO/AMBAS) | 1 | Sin cuerpo | 200 IncidenciaDetalle | HU-MYL-07, HU-ADM-10 |
| POST | `/api/v1/incidencias/{id}/tomar` | JWT | MANTENIMIENTO_LIMPIEZA (MANTENIMIENTO/AMBAS) | 1 | Sin cuerpo | 200 IncidenciaDetalle | HU-MYL-07 |
| POST | `/api/v1/incidencias/{id}/resolver` | JWT | MANTENIMIENTO_LIMPIEZA (MANTENIMIENTO/AMBAS) | 1 | ResolverIncidenciaPeticion | 200 IncidenciaDetalle | HU-MYL-08 |

## cuentas

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/cuentas/{codigo}` | JWT | RECEPCION | 1 | Sin cuerpo | 200 CuentaRecepcion | HU-REC-13 |
| POST | `/api/v1/cuentas/{codigo}/cargos` | JWT | RECEPCION | 1 | AgregarCargoPeticion | 201 CargoCuentaRecepcion | HU-REC-13 |
| POST | `/api/v1/cuentas/{codigo}/cargos/{id}/anular` | JWT | RECEPCION | 1 | MotivoPeticion | 200 CargoCuentaRecepcion | HU-REC-13 |

## checkout

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/checkout/{codigo}` | JWT | RECEPCION | 1 | Sin cuerpo | 200 VistaCheckout | HU-REC-14 |
| POST | `/api/v1/checkout/{codigo}` | JWT | RECEPCION | 1 | CheckoutRecepcionPeticion | 200 CheckoutResultado | HU-REC-14, HU-REC-15 |

## facturas

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/facturas/{id}` | JWT | RECEPCION, HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 FacturaDetalle | HU-REC-15, HU-REC-16, HU-HUE-16 |
| GET | `/api/v1/facturas/{id}/pdf` | JWT | RECEPCION, HUESPED · HUESPED solo propios | 1 | Sin cuerpo | 200 DescargaFactura | HU-REC-15, HU-HUE-16 |

## archivos

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| POST | `/api/v1/archivos/imagenes` | JWT | ADMIN, RECEPCION, MANTENIMIENTO_LIMPIEZA | 1 | SubirImagenPeticion (multipart/form-data) | 201 ImagenSubida | HU-ADM-03, HU-ADM-05, HU-ADM-08, HU-ADM-11, HU-REC-17, HU-MYL-06 |

## admin

| Método | Ruta | Autenticación | Roles / área | Nivel | Entrada | Respuesta | HU |
|---|---|---|---|---|---|---|---|
| GET | `/api/v1/admin/empleados` | JWT | ADMIN | 1 | Query: rol, estado | 200 EmpleadoAdmin[] | HU-ADM-02 |
| POST | `/api/v1/admin/empleados` | JWT | ADMIN | 1 | CrearEmpleadoPeticion | 201 EmpleadoCreado | HU-ADM-01 |
| PATCH | `/api/v1/admin/empleados/{id}` | JWT | ADMIN | 1 | EditarEmpleadoPeticion | 200 EmpleadoAdmin | HU-ADM-02 |
| PATCH | `/api/v1/admin/empleados/{id}/estado` | JWT | ADMIN | 1 | EstadoCatalogoPeticion | 200 EmpleadoAdmin | HU-ADM-02 |
| POST | `/api/v1/admin/empleados/{id}/restablecer-contrasena` | JWT | ADMIN | 1 | Sin cuerpo | 200 ContrasenaRestablecida | HU-ADM-02 |
| GET | `/api/v1/admin/tipos-habitacion` | JWT | ADMIN | 1 | Query: estado | 200 TipoHabitacionAdmin[] | HU-ADM-03 |
| POST | `/api/v1/admin/tipos-habitacion` | JWT | ADMIN | 1 | CrearTipoHabitacionPeticion | 201 TipoHabitacionAdmin | HU-ADM-03 |
| GET | `/api/v1/admin/tipos-habitacion/{id}` | JWT | ADMIN | 1 | Sin cuerpo | 200 TipoHabitacionAdmin | HU-ADM-03 |
| PATCH | `/api/v1/admin/tipos-habitacion/{id}` | JWT | ADMIN | 1 | EditarTipoHabitacionPeticion | 200 TipoHabitacionAdmin | HU-ADM-03 |
| PATCH | `/api/v1/admin/tipos-habitacion/{id}/estado` | JWT | ADMIN | 1 | EstadoCatalogoPeticion | 200 TipoHabitacionAdmin | HU-ADM-03 |
| PUT | `/api/v1/admin/tipos-habitacion/{id}/fotos` | JWT | ADMIN | 1 | FotosTipoPeticion | 200 TipoHabitacionAdmin | HU-ADM-03 |
| PATCH | `/api/v1/admin/tipos-habitacion/{id}/ajuste-fin-semana` | JWT | ADMIN | 1 | AjusteFinSemanaPeticion | 200 TipoHabitacionAdmin | HU-ADM-07 |
| GET | `/api/v1/admin/habitaciones` | JWT | ADMIN | 1 | Query: estado, tipoHabitacionId | 200 HabitacionAdmin[] | HU-ADM-04 |
| POST | `/api/v1/admin/habitaciones` | JWT | ADMIN | 1 | CrearHabitacionPeticion | 201 HabitacionAdmin | HU-ADM-04 |
| PATCH | `/api/v1/admin/habitaciones/{id}` | JWT | ADMIN | 1 | EditarHabitacionPeticion | 200 HabitacionAdmin | HU-ADM-04 |
| PATCH | `/api/v1/admin/habitaciones/{id}/estado` | JWT | ADMIN | 1 | EstadoCatalogoPeticion | 200 HabitacionAdmin | HU-ADM-04 |
| GET | `/api/v1/admin/menu/categorias` | JWT | ADMIN | 1 | Sin cuerpo | 200 CategoriaMenu[] | HU-ADM-05 |
| POST | `/api/v1/admin/menu/categorias` | JWT | ADMIN | 1 | CategoriaMenuPeticion | 201 CategoriaMenu | HU-ADM-05 |
| PATCH | `/api/v1/admin/menu/categorias/{id}` | JWT | ADMIN | 1 | CategoriaMenuPeticion | 200 CategoriaMenu | HU-ADM-05 |
| GET | `/api/v1/admin/menu/items` | JWT | ADMIN | 1 | Query: categoriaId, estado | 200 ItemMenuAdmin[] | HU-ADM-05 |
| POST | `/api/v1/admin/menu/items` | JWT | ADMIN | 1 | CrearItemMenuPeticion | 201 ItemMenuAdmin | HU-ADM-05 |
| PATCH | `/api/v1/admin/menu/items/{id}` | JWT | ADMIN | 1 | EditarItemMenuPeticion | 200 ItemMenuAdmin | HU-ADM-05 |
| PATCH | `/api/v1/admin/menu/items/{id}/estado` | JWT | ADMIN | 1 | EstadoCatalogoPeticion | 200 ItemMenuAdmin | HU-ADM-05 |
| POST | `/api/v1/admin/menu/items/{id}/reactivar` | JWT | ADMIN | 1 | Sin cuerpo | 200 ItemMenuAdmin | HU-ADM-05 |
| GET | `/api/v1/admin/temporadas` | JWT | ADMIN | 1 | Sin cuerpo | 200 TemporadaAdmin[] | HU-ADM-06 |
| POST | `/api/v1/admin/temporadas` | JWT | ADMIN | 1 | TemporadaPeticion | 201 TemporadaAdmin | HU-ADM-06 |
| PUT | `/api/v1/admin/temporadas/{id}` | JWT | ADMIN | 1 | TemporadaPeticion | 200 TemporadaAdmin | HU-ADM-06 |
| DELETE | `/api/v1/admin/temporadas/{id}` | JWT | ADMIN | 1 | Sin cuerpo | 204 sin cuerpo | HU-ADM-06 |
| GET | `/api/v1/admin/hotel` | JWT | ADMIN | 1 | Sin cuerpo | 200 HotelAdmin | HU-ADM-08 |
| PUT | `/api/v1/admin/hotel` | JWT | ADMIN | 1 | HotelAdminPeticion | 200 HotelAdmin | HU-ADM-08 |
| GET | `/api/v1/admin/indicadores` | JWT | ADMIN | 1 | Query: inicio, fin | 200 Indicadores | HU-ADM-09 |
| POST | `/api/v1/admin/canal-simulado/reservas` | JWT | ADMIN | 1 | CanalSimuladoPeticion | 200 CanalSimuladoResultado | HU-CM-03 |
| GET | `/api/v1/admin/amenidades` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 AmenidadAdmin[] | HU-ADM-11 |
| POST | `/api/v1/admin/amenidades` | JWT | ADMIN | 2 · opcional | AmenidadPeticion | 201 AmenidadAdmin | HU-ADM-11 |
| PATCH | `/api/v1/admin/amenidades/{id}` | JWT | ADMIN | 2 · opcional | EditarAmenidadPeticion | 200 AmenidadAdmin | HU-ADM-11 |
| PATCH | `/api/v1/admin/amenidades/{id}/estado` | JWT | ADMIN | 2 · opcional | EstadoCatalogoPeticion | 200 AmenidadAdmin | HU-ADM-11 |
| GET | `/api/v1/admin/wifi` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 Wifi | HU-ADM-11 |
| PUT | `/api/v1/admin/wifi` | JWT | ADMIN | 2 · opcional | Wifi | 200 Wifi | HU-ADM-11 |
| GET | `/api/v1/admin/turnos` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 TurnoAdmin[] | HU-ADM-12 |
| POST | `/api/v1/admin/turnos` | JWT | ADMIN | 2 · opcional | TurnoPeticion | 201 TurnoAdmin | HU-ADM-12 |
| PATCH | `/api/v1/admin/turnos/{id}` | JWT | ADMIN | 2 · opcional | EditarTurnoPeticion | 200 TurnoAdmin | HU-ADM-12 |
| POST | `/api/v1/admin/turnos/{id}/desactivar` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 TurnoAdmin | HU-ADM-12 |
| GET | `/api/v1/admin/asignaciones-turnos` | JWT | ADMIN | 2 · opcional | Query: inicio*, fin* | 200 AsignacionTurno[] | HU-ADM-12 |
| POST | `/api/v1/admin/asignaciones-turnos` | JWT | ADMIN | 2 · opcional | AsignarTurnosPeticion | 201 AsignacionTurno[] | HU-ADM-12 |
| DELETE | `/api/v1/admin/asignaciones-turnos/{id}` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 204 sin cuerpo | HU-ADM-12 |
| GET | `/api/v1/admin/inventario/productos` | JWT | ADMIN | 2 · opcional | Query: categoria, soloStockBajo, estado | 200 ProductoInventario[] | HU-ADM-13 |
| POST | `/api/v1/admin/inventario/productos` | JWT | ADMIN | 2 · opcional | ProductoInventarioPeticion | 201 ProductoInventario | HU-ADM-13 |
| PATCH | `/api/v1/admin/inventario/productos/{id}` | JWT | ADMIN | 2 · opcional | EditarProductoInventarioPeticion | 200 ProductoInventario | HU-ADM-13 |
| POST | `/api/v1/admin/inventario/productos/{id}/desactivar` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 ProductoInventario | HU-ADM-13 |
| GET | `/api/v1/admin/inventario/productos/{id}/movimientos` | JWT | ADMIN | 2 · opcional | Sin cuerpo | 200 MovimientoInventario[] | HU-ADM-13 |
| POST | `/api/v1/admin/inventario/productos/{id}/movimientos` | JWT | ADMIN | 2 · opcional | MovimientoInventarioPeticion | 201 MovimientoInventario | HU-ADM-13 |

## Reglas de seguridad

- JWT válido no basta: validar rol, área, dueño, estado y responsable en el servidor. Las extensiones `x-autorizacion`/`x-permisos` documentan estos controles; no los implementan automáticamente.
- 401: credencial ausente, inválida o vencida. 403: rol/área o empleado a cargo no permitido. 404: inexistente o registro ajeno solicitado por huésped. 409: estado, horario o cambio concurrente incompatible. 400: datos inválidos.
- Una contraseña temporal bloquea módulos y ws-ticket hasta cambiarla; solo están permitidas las rutas de sesión acordadas.
- No comprobar ACTIVO en cada acción del empleado: se rechaza login/refresh y el JWT vigente dura hasta 15 minutos.
- MYL puede reportar daños desde cualquier área. Iniciar limpieza/solicitudes exige LIMPIEZA o AMBAS; tomar/resolver incidencias exige MANTENIMIENTO o AMBAS. ADMIN consulta incidencias pero no las toma ni resuelve.
- El huésped solo ve sus reservas, pedidos, solicitudes, cuenta, factura y dispositivos. El código de reserva no reemplaza la autenticación de `/app`.
- El acceso público al estado de la reserva recién pagada conserva exactamente el mecanismo limitado de parte 1; no usarlo para listar huéspedes o reservas.
- Room Service recibe solo el nombre del huésped como dato personal; MYL no recibe ningún dato personal del huésped. Los esquemas por audiencia son distintos.
- El GET de PDF exige autorización para generar una URL firmada temporal. La URL firmada autoriza la descarga de MinIO hasta su vencimiento; no es un PDF público permanente.
- Web: el BFF conserva JWT en cookies httpOnly; app: SecureStore y llamadas directas. WebSocket autentica CONNECT y cada SUBSCRIBE.

## Tiempo real y acciones sin endpoint propio

Los cuatro destinos y los cuatro eventos están descritos en `x-websocket`; push en `x-push`. Correo, cargo automático al entregar, emisión de factura y efectos del check-out son acciones internas, no endpoints públicos adicionales. Ver [cobertura de historias](COBERTURA_CONTRATO.md) y [revisión pendiente](REVISION_CONTRATO.md).
