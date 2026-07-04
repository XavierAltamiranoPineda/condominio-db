# condominio-db

Diseño y migraciones de la base de datos del Sistema de Gestión de
Condominios. Repositorio independiente de `condominio-api`,
`condominio-web`, `condominio-escritorio` y `condominio-movil`.

## Estructura

```
condominio-db/
├── README.md
├── CHANGELOG.md
├── V1__schema.sql        \
├── V2__constraints.sql    \
├── V3__indexes.sql         \  Migraciones Flyway
├── V4__triggers.sql        /  (aplicar en este orden, una sola vez)
├── V5__functions.sql      /
├── V6__seed.sql          /
├── V7__views.sql        /
├── dev-scripts/
│   ├── test_data.sql     ← datos ficticios, SOLO desarrollo local
│   └── drop_all.sql      ← reset destructivo, SOLO desarrollo local
├── MER.puml              ← modelo entidad-relación (PlantUML)
└── DER.pdf               ← diagrama entidad-relación exportado
```

## ¿Por qué `V1__` a `V7__` pero `test_data.sql`/`drop_all.sql` sin prefijo?

Flyway aplica cada archivo `V{n}__nombre.sql` **exactamente una vez**,
en orden, y deja registro en `flyway_schema_history`. Esa historia es
inmutable: no se edita un `V{n}` ya aplicado en un ambiente compartido,
se crea un `V{n+1}` nuevo.

`test_data.sql` y `drop_all.sql` viven fuera de esa cadena a propósito:

- `test_data.sql` inserta datos ficticios. Si fuera `V8__`, Flyway lo
  aplicaría también en producción al desplegar.
- `drop_all.sql` borra el esquema completo. Nunca debe formar parte de
  una migración versionada — Flyway no tiene forma seria de "deshacer"
  una migración ya aplicada.

Ambos son scripts de conveniencia para desarrollo local, se corren a
mano cuando se necesitan.

## Cómo levantar la base de datos localmente

```bash
createdb condominio_dev

# Aplicar las migraciones en orden (o dejar que Flyway lo haga
# automáticamente si el proyecto Spring Boot está configurado con
# spring.flyway.locations apuntando a este repo/carpeta):
for f in V1__schema.sql V2__constraints.sql V3__indexes.sql \
         V4__triggers.sql V5__functions.sql V6__seed.sql V7__views.sql; do
  psql -d condominio_dev -v ON_ERROR_STOP=1 -f "$f"
done

# Opcional: cargar datos ficticios para probar la API
psql -d condominio_dev -f dev-scripts/test_data.sql
```

## Cómo resetear todo durante el desarrollo

```bash
psql -d condominio_dev -f dev-scripts/drop_all.sql
# y volver a aplicar V1..V7 (+ test_data.sql si se quiere)
```

## Con Flyway + Spring Boot

1. Colocar `V1__schema.sql` ... `V7__views.sql` en
   `src/main/resources/db/migration/`.
2. Configurar en `application.yml`:
   ```yaml
   spring:
     flyway:
       enabled: true
       locations: classpath:db/migration
     datasource:
       url: jdbc:postgresql://localhost:5432/condominio_dev
   ```
3. Al arrancar la app, Flyway aplica automáticamente las migraciones
   pendientes. **Nunca** copiar `test_data.sql` ni `drop_all.sql` a esa
   carpeta.

## Convenciones del esquema

- PKs: `BIGSERIAL`, nombradas `id_<tabla>`.
- Snake_case en todo (tablas, columnas, constraints).
- Estados de bajo crecimiento (2-4 valores fijos) → `ENUM` nativo de
  Postgres. Estados administrables desde la app → tabla catálogo
  (`estado_unidad`, `estado_reserva`, `estado_pago`, `estado_acceso`,
  `estado_ticket`).
- Toda columna de auditoría (`fecha`, `fecha_creacion`) usa
  `TIMESTAMPTZ`, nunca `TIMESTAMP`.
- Triggers solo para: integridad crítica, auditoría, y estado
  derivado/historial. Toda la lógica de negocio de cálculo vive en
  `V5__functions.sql` o en la API — no en más triggers.

## Próximos pasos sugeridos

- [ ] Agregar `MER.puml` y exportar `DER.pdf` a este repo.
- [ ] Documentar en la API el uso de
      `SET LOCAL app.usuario_actual = '<id>'` al inicio de cada
      transacción, requerido por `fn_auditoria()` en V4.
- [ ] Evaluar tabla `dispositivo_token` para push notifications (FCM)
      cuando se implemente esa parte del backend.
