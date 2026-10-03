# OBJ-3A-2 — Acceso del huésped por código

Avance de Carlos, 3 de octubre de 2026, rama `obj3a-acceso-huesped`.

## Implementado

- `auth/huesped/OtpAccessService`: pedir y verificar códigos con reloj inyectable.
- Código aleatorio de seis dígitos, hash PBKDF2 con sal independiente por código; el código plano no se devuelve al cliente ni se registra en logs.
- Caducidad de diez minutos y consumo de un solo uso. Al pedir otro código se invalida el anterior.
- Cinco verificaciones fallidas bloquean al huésped durante quince minutos. Pedir otro código no reinicia el contador. Al finalizar el bloqueo se reinicia el contador; un acceso correcto también lo reinicia.
- Mensaje genérico al solicitar un código, incluyendo correos sin reservas y huéspedes bloqueados. Solo se encola un correo cuando hay al menos una reserva y no existe un bloqueo vigente.
- `JdbcOtpStore`: usa las tablas actuales `huespedes`, `reservas` y `codigos_otp`. `FOR UPDATE` serializa las operaciones por huésped. Los errores de acceso se lanzan después del commit para preservar intentos y bloqueos.
- La emisión de la sesión y el consumo del código comparten una transacción. Fallos del emisor o del Outbox deben revertir la operación.

## Integración pendiente

Este avance no expone endpoints HTTP y no envía correo ni emite JWT por sí solo. No hay un adaptador de correo directo, una seguridad alternativa ni un emisor ficticio activado en Spring.

1. Hugo implementa `AccessCodeEmail.enqueue(email, code, expires)` mediante su Outbox, con tipo/plantilla `codigo-acceso`. Debe insertar el mensaje dentro de la transacción actual y dejar la entrega y sus reintentos al trabajador existente. No debe enviar SMTP de manera síncrona desde este método.
2. Pablo adapta `GuestSessionIssuer<T>.issue(guestId)` a su emisor: tipo HUESPED, acceso de 15 minutos y refresh rotativo de 7 días. La persistencia debe participar en la transacción actual. El identificador es el del huésped para vincular todas sus reservas.
3. Crear el bean `OtpAccessService<T>` usando `JdbcOtpStore`, ambos adaptadores y `Clock.systemUTC()`.
4. Con el contrato parte 2 de Josué, añadir controlador y DTOs, validación de correo/código y mapeo de `OtpAccessException.reason()` a los errores acordados. No envolver las verificaciones fallidas en un rollback del contador; el almacén usa su propia transacción.
5. Coordinar con Pablo el permiso público solo para pedir/verificar código. Cierre de sesión y eliminación del push quedan pendientes del mismo mecanismo de refresh y del contrato.
6. Probar correo en Mailpit y login real desde la app antes de considerar HU-HUE-08 terminada.

Los adaptadores deben participar en la misma transacción de base de datos. No deben abrir una transacción independiente ni llamar a un emisor remoto que no pueda revertirse.

## Pruebas

Con Java 21 y Maven:

```bash
mvn -Dtest=OtpAccessServiceTest test
```

Doce pruebas de lógica pasan: hash, mensaje genérico, vencimiento, código usado, cinco fallos, reenvío, fin del bloqueo, contador, errores de integración y uso simultáneo.

Para persistencia, con Docker encendido:

```bash
mvn -Dtest=OtpAccessServiceTest,JdbcOtpStoreTest test
```

`JdbcOtpStoreTest` levanta PostgreSQL 17 aislado y carga V1/V2 existentes. Comprueba commit del bloqueo, rollback de inserción cuando falla Outbox, huésped sin reservas, invalidación al reenviar y exclusión concurrente.

En esta sesión: compilación y 12 pruebas de lógica aprobadas con las versiones del pom original; las 5 pruebas PostgreSQL fueron omitidas por no haber Docker disponible. La persistencia y la integración HTTP/Outbox/JWT aún no se han validado de extremo a extremo.

No se modificaron pom.xml, seguridad, contrato ni migraciones. Los cambios siguen locales; no se ha hecho commit ni push.
