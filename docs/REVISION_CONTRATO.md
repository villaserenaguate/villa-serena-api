# Revisión del contrato completo

## Alcance y estado

Propuesta OpenAPI 3.1, versión `0.2.0-propuesta`, preparada el 3 de octubre de 2026 en la rama `obj0-contrato-completo`.

- 130 operaciones HTTP: 29 conservadas de parte 1 y 101 nuevas.
- 109 operaciones Nivel 1 y 21 opcionales Nivel 2.
- Cobertura de las 68 historias V3 mediante HTTP, WebSocket, efectos internos o reutilización de una pantalla/operación.
- Tabla completa: [ENDPOINTS.md](ENDPOINTS.md).
- Explorador sin dependencias: abrir [EXPLORAR_CONTRATO.html](EXPLORAR_CONTRATO.html) en un navegador. Permite filtrar GET, JWT, rol, nivel y texto; no realiza peticiones al API.
- 47 GET requieren JWT. Login, OTP y renovación no requieren JWT, pero sí sus credenciales respectivas. Canal requiere ambos encabezados; Stripe exige firma.

El contrato describe lo que cada módulo debe implementar. No cambia el código Java, las migraciones ni las pantallas web/móvil; no afirma que exista ya el backend completo. El módulo OTP continúa en `obj3a-acceso-huesped`.

## Parte 1 preservada

Base: `origin/obj0-contrato-openapi`, commit `b4f26f25e225da1c4adefd90a9f17f971cd1cd76`.

Se compararon todos los PathItem y todos los esquemas originales mediante comparación estructural: las 27 rutas (29 operaciones) y sus esquemas permanecen iguales. Las reglas por rol y la trazabilidad ampliada se documentan en la extensión global `x-permisos`, sin alterar los métodos existentes. Se agregaron nuevos grupos y esquemas, metadatos de revisión y validación de ejemplos.

La misma ruta del webhook de Stripe se reutiliza para el pago del saldo. `x-integraciones.webhookStripe` detalla esta ampliación funcional y la necesidad de que Pablo la confirme; no cambia el payload ni las respuestas del webhook original.

## Convenciones

- Prefijo `/api/v1`; JSON camelCase.
- Montos GTQ con dos decimales. El cliente no fija precios de pedidos, monto del pago de saldo ni monto del pago de Recepción.
- Fechas de estadía `YYYY-MM-DD`, instantes ISO 8601 con zona. Horarios y fechas operativas calculados en `America/Guatemala`.
- Estados del documento 07; sin no-show, anulaciones de factura, pagos parciales o inventario integrado.
- Errores `{ codigo, mensaje, detalles }`; 400, 401, 403, 404 y 409 según el endpoint. OTP vencido/usado/incorrecto o bloqueo responde 401 con código estable y mensaje específico.
- Listas sin paginación; solo búsqueda de reservas conserva page/size de parte 1.
- JWT no otorga permisos por sí mismo. `x-autorizacion` y `x-permisos` documentan rol, área, propiedad, responsable y condiciones; Spring debe implementar estos controles.
- ADMIN no usa las rutas de operación; en incidencias solo consulta. HUESPED recibe 404 para recursos ajenos. MYL puede reportar daños desde cualquier área; limpiar y atender solicita LIMPIEZA/AMBAS, tomar/resolver incidencias MANTENIMIENTO/AMBAS.
- Vistas distintas de pedidos, solicitudes y cuentas para no filtrar datos personales ni referencias de pago a roles operativos.
- `x-websocket`: cuatro destinos, cuatro tipos de evento, autenticación CONNECT y autorización SUBSCRIBE. Los esquemas de evento diferencian Room Service y huésped.
- `x-push`: mensajes sin datos personales ni montos, solo EN_ESTADIA, datos internos para abrir la pantalla y revocación de dispositivos.
- Imágenes JPG/PNG hasta 5 MiB, autorizadas por uso/rol. Incidencias y PDF en almacenamiento privado. El GET del PDF devuelve enlace firmado temporal, no un PDF público permanente.
- La impresión 80 mm/carta es HTML/CSS del frontend; no hay endpoint de imprimir ni estado COPIA.

## Validación realizada

1. `npx --yes @redocly/cli lint openapi.yaml`: sin errores. Se activaron como errores las reglas de ejemplos de esquemas y de peticiones/respuestas.
2. Se generaron tipos con `openapi-typescript` desde el contrato completo sin errores, en un archivo temporal. No se reemplazó el contrato usado por la app mientras está pendiente la revisión.
3. Auditoría estructural: referencias internas válidas, operationId únicos, parámetros de ruta declarados y requeridos, todas las operaciones con permisos y trazabilidad, dos rutas OTP sin JWT y las demás nuevas con JWT explícito.
4. Cobertura de historias: 68/68, incluyendo notas de los efectos internos y de las funciones de UI que reutilizan endpoints.

El validador muestra siete advertencias conocidas:

- Dos heredadas: GET público de hotel y catálogo de tipos no declaran respuesta 4XX. Se conservaron para no cambiar la parte congelada.
- Cinco por los esquemas de eventos STOMP: se usan en `x-websocket`; la regla de componentes no usados solo recorre operaciones HTTP. La auditoría comprueba estas referencias explícitamente. No se agregaron endpoints HTTP artificiales para silenciarlas.

## Qué debe confirmar el equipo antes de congelar

| Revisor | Puntos |
|---|---|
| Josué | Rutas/DTOs nuevos, tipos de identificadores, validaciones, relación con esquema actual y alcance de Nivel 2 |
| Pablo | Emisión/renovación/revocación para HUESPED, permisos, ws-ticket, condiciones de cuenta/check-out y ampliación del webhook a saldo |
| Hugo | Room Service, limpieza/incidencias de su módulo, Outbox, PDF firmado, WebSocket `/ws`, encabezado CONNECT `ticket`, nombres/campos de eventos y payload push |
| Kim, Alex y Carlos | Copiar el contrato revisado y generar tipos; comprobar que los DTOs corresponden a sus pantallas |

Los nombres de rutas/campos añadidos, `/ws`, `ticket` y los payloads son decisiones de esta propuesta, sujetos a esa revisión. No se enviaron mensajes al equipo, no se marcaron objetivos como terminados y no se anunció un contrato congelado. No se hizo commit ni push de esta rama.
