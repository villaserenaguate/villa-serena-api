# villa-serena-api

API de Villa Serena (Spring Boot 4.1, Java 21, PostgreSQL 17 + Flyway). Ver `AGENTS.md` y la documentación en `villa-serena-docs`.

## Probar el esquema

`scripts/probar-esquema.sql` comprueba los datos iniciales y las restricciones de la base de datos (EXCLUDE de reservas, correos únicos, un cargo por pedido, una factura por cuenta, etc.). Corre dentro de una transacción que se deshace al final, así que **no deja datos**. Si algo falla, se detiene y muestra `FALLO ...`.

**Sobre una base ya migrada por Flyway** (con `./mvnw spring-boot:run`):

```bash
docker exec -i villa-serena-dev-postgres-1 psql -U villaserena -d villaserena < scripts/probar-esquema.sql
```

**Sin Spring, en una base temporal** (aplica las migraciones con valores de prueba en los placeholders y la borra al final):

```bash
C=villa-serena-dev-postgres-1; DB=vs_prueba_esquema
docker exec $C psql -U villaserena -d postgres -c "CREATE DATABASE $DB"
for f in $(ls src/main/resources/db/migration | sort -V); do
  sed -e 's/\${demo_password_hash}/hash-de-prueba-no-real/' \
      -e 's/\${canal1_key_hash}/'"$(printf '0%.0s' {1..63})1"'/' \
      -e 's/\${canal2_key_hash}/'"$(printf '0%.0s' {1..63})2"'/' \
      "src/main/resources/db/migration/$f" | docker exec -i $C psql -q -U villaserena -d $DB -v ON_ERROR_STOP=1
done
docker exec -i $C psql -U villaserena -d $DB < scripts/probar-esquema.sql
docker exec $C psql -U villaserena -d postgres -c "DROP DATABASE $DB WITH (FORCE)"
```
