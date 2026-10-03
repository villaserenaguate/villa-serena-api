package com.villaserena.api.auth.huesped;

import static org.junit.jupiter.api.Assertions.*;
import java.time.*;
import java.util.ArrayList;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers(disabledWithoutDocker = true)
class JdbcOtpStoreTest {
    @Container static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(DockerImageName.parse("postgres:17"));
    private JdbcTemplate jdbc;
    private JdbcOtpStore store;
    private OtpAccessService<String> service;
    private final ArrayList<String> sent = new ArrayList<>();
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-03T16:00:00Z"), ZoneOffset.UTC);

    @BeforeEach void setup() {
        var source = new DriverManagerDataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        jdbc = new JdbcTemplate(source);
        jdbc.execute("DROP SCHEMA public CASCADE"); jdbc.execute("CREATE SCHEMA public");
        new ResourceDatabasePopulator(new ClassPathResource("db/migration/V1__seguridad_huespedes.sql"),
                new ClassPathResource("db/migration/V2__catalogos_reservas.sql")).execute(source);
        jdbc.update("""
            INSERT INTO huespedes(nombre_completo,correo,telefono,nacionalidad,tipo_documento,numero_documento)
            VALUES ('Ana','ana@example.com','00000000','Guatemala','DPI','DEMO-1'),
                   ('Sin reservas','sin@example.com','00000000','Guatemala','DPI','DEMO-2')
            """);
        jdbc.update("INSERT INTO tipos_habitacion(nombre,descripcion,capacidad,precio_base) VALUES ('Suite','Prueba',2,900)");
        jdbc.update("""
            INSERT INTO reservas(codigo,huesped_id,tipo_habitacion_id,fecha_entrada,fecha_salida,numero_huespedes,estado,canal,total)
            VALUES ('VS-ABC123',1,1,'2026-10-06','2026-10-08',2,'CONFIRMADA','DIRECTO_WEB',1800)
            """);
        store = new JdbcOtpStore(jdbc, new DataSourceTransactionManager(source));
        service = new OtpAccessService<>(store, (email, code, expires) -> sent.add(code), id -> "session-" + id, clock);
    }
    @Test void failedAttemptsAreCommittedDespiteAccessException() {
        service.requestCode("ana@example.com");
        for (int i = 0; i < 5; i++) assertThrows(OtpAccessException.class, () -> service.verifyCode("ana@example.com", "bad"));
        assertEquals(5, jdbc.queryForObject("SELECT otp_intentos_fallidos FROM huespedes WHERE id=1", Integer.class));
        assertNotNull(jdbc.queryForObject("SELECT otp_bloqueado_hasta FROM huespedes WHERE id=1", java.sql.Timestamp.class));
    }
    @Test void outboxFailureRollsBackCodeInsertion() {
        var failing = new OtpAccessService<>(store, (email, code, expires) -> { throw new IllegalStateException("Outbox"); }, id -> "session", clock);
        assertThrows(IllegalStateException.class, () -> failing.requestCode("ana@example.com"));
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM codigos_otp", Integer.class));
    }
    @Test void guestWithoutReservationsReceivesNoCode() {
        assertEquals(OtpAccessService.REQUEST_MESSAGE, service.requestCode("sin@example.com"));
        assertTrue(sent.isEmpty());
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM codigos_otp", Integer.class));
    }
    @Test void resendingInvalidatesPreviousRecord() {
        service.requestCode("ana@example.com"); service.requestCode("ana@example.com");
        assertEquals(1, jdbc.queryForObject("SELECT count(*) FROM codigos_otp WHERE usado_en IS NULL", Integer.class));
        assertEquals("session-1", service.verifyCode("ana@example.com", sent.getLast()));
        assertEquals(0, jdbc.queryForObject("SELECT count(*) FROM codigos_otp WHERE usado_en IS NULL", Integer.class));
    }
    @Test void postgresLockPreventsDoubleUse() throws Exception {
        service.requestCode("ana@example.com"); String code = sent.getLast();
        var issued = new AtomicInteger(); var start = new CountDownLatch(1);
        var concurrent = new OtpAccessService<>(store, (email, value, expires) -> {}, id -> { issued.incrementAndGet(); return "session"; }, clock);
        try (var executor = Executors.newFixedThreadPool(2)) {
            Callable<Boolean> verify = () -> { start.await(); try { concurrent.verifyCode("ana@example.com", code); return true; } catch (OtpAccessException e) { return false; } };
            var first = executor.submit(verify); var second = executor.submit(verify); start.countDown();
            assertNotEquals(first.get(10, TimeUnit.SECONDS), second.get(10, TimeUnit.SECONDS));
            assertEquals(1, issued.get());
        }
    }
}
