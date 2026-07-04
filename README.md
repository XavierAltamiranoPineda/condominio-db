# condominio-db

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-336791?logo=postgresql&logoColor=white)
![Flyway](https://img.shields.io/badge/Flyway-10%2B-CC0200?logo=flyway&logoColor=white)
![License](https://img.shields.io/badge/license-privado-lightgrey)
![Status](https://img.shields.io/badge/status-en%20desarrollo-yellow)

Diseño y migraciones de la base de datos del Sistema de Gestión de
Condominios. Repositorio independiente de `condominio-api`,
`condominio-web`, `condominio-escritorio` y `condominio-movil`.

## Requisitos

- PostgreSQL 16 o superior
- `psql`
- Flyway 10+ (opcional, si no se integra vía Spring Boot)
- Java 21 + Spring Boot 3.x (si se usa Flyway integrado en `condominio-api`)

## Flujo del proyecto

```
condominio-web
        │
condominio-escritorio
        │
condominio-movil
        │
        ▼
condominio-api
        │
        ▼
condominio-db   ← este repositorio
        │
        ▼
 PostgreSQL
```

Ningún cliente (web, escritorio, móvil) accede directo a PostgreSQL.
Todo pasa por `condominio-api`.

## Estructura

```
condominio-db/
│
├── README.md
├── CHANGELOG.md
├── LICENSE
├── CONTRIBUTING.md
├── .gitignore
│
├── docs/
│   ├── MER.puml
│   ├── DER.pdf              (pendiente, ver Roadmap)
│   └── Arquitectura.pdf     (pendiente, ver Roadmap)
│
├── migrations/
│   ├── V1__schema.sql
│   ├── V2__constraints.sql
│   ├── V3__indexes.sql
│   ├── V4__triggers.sql
│   ├── V5__functions.sql
│   ├── V6__seed.sql
│   └── V7__views.sql
│
└── dev-scripts/
    ├── test_data.sql
    └── drop_all.sql
```

## Cómo levantar la base de datos localmente

```bash
createdb condominio_dev

for f in migrations/V1__schema.sql migrations/V2__constraints.sql \
         migrations/V3__indexes.sql migrations/V4__triggers.sql \
         migrations/V5__functions.sql migrations/V6__seed.sql \
         migrations/V7__views.sql; do
  psql -d condominio_dev -v ON_ERROR_STOP=1 -f "$f"
done

# Opcional: cargar datos ficticios para probar la API
psql -d condominio_dev -f dev-scripts/test_data.sql
```

## Cómo resetear todo durante el desarrollo

```bash
psql -d condominio_dev -f dev-scripts/drop_all.sql
# y volver a aplicar migrations/V1..V7 (+ test_data.sql si se quiere)
```

## Con Flyway + Spring Boot

1. Copiar el contenido de `migrations/` a
   `src/main/resources/db/migration/` en `condominio-api` (Flyway
   busca ahí por convención; el nombre de carpeta `migrations/` de
   este repo es solo para claridad al navegarlo en GitHub).
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

## Versionado

Las migraciones siguen el esquema de versiones de Flyway:

- `V1__schema.sql`
- `V2__constraints.sql`
- `V3__indexes.sql`
- `V4__triggers.sql`
- `V5__functions.sql`
- `V6__seed.sql`
- `V7__views.sql`

**Las migraciones ya aplicadas nunca se modifican.** Cualquier cambio
posterior se implementa mediante una nueva migración (`V8__`, `V9__`,
etc.), documentada en `CHANGELOG.md`. Ver `CONTRIBUTING.md` para el
flujo completo.

Releases del repo se marcan con tags (`v1.0.0-db`, `v1.1.0-db`, ...)
cuando se cierra un conjunto estable de migraciones — por ejemplo,
`v1.0.0-db` al completar V1-V7.

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
  `migrations/V5__functions.sql` o en la API — no en más triggers.

## Roadmap

- [x] Modelo conceptual
- [x] Modelo lógico
- [x] Modelo físico
- [x] Implementación PostgreSQL (V1-V7 probadas de punta a punta)
- [ ] Integración Flyway en `condominio-api`
- [ ] Integración Spring Boot (entidades JPA)
- [ ] API REST
- [ ] Web
- [ ] Escritorio
- [ ] Móvil

## Licencia

Ver [`LICENSE`](./LICENSE). Proyecto privado de uso académico.
