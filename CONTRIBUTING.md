# Contribuir a condominio-db

## Reglas para migraciones (`migrations/`)

1. **Nunca modificar una migración ya aplicada** en `main` o en
   cualquier ambiente compartido (staging, producción). Si Flyway ya
   la registró en `flyway_schema_history` en algún ambiente que no sea
   el tuyo local, está congelada.
2. **Todo cambio de esquema es una migración nueva**: `V8__`, `V9__`,
   etc. Nombre descriptivo en snake_case después del doble guion bajo
   (ej. `V8__agregar_tabla_dispositivo_token.sql`).
3. Una migración = un cambio lógico. No mezclar, por ejemplo, un
   `ALTER TABLE` con datos de seed en el mismo archivo.
4. Antes de abrir el PR, correr localmente:
   ```bash
   psql -d condominio_dev -f dev-scripts/drop_all.sql
   for f in migrations/V*.sql; do psql -d condominio_dev -v ON_ERROR_STOP=1 -f "$f"; done
   ```
   Si algo falla ahí, va a fallar en CI o en el ambiente de otro
   compañero.
5. Actualizar `CHANGELOG.md` en el mismo PR que agrega la migración.

## Flujo de trabajo

- **No hacer commits directamente a `main`.**
- Rama por cambio: `feature/nombre-corto` o `fix/nombre-corto`.
- Usar Pull Request, aunque sea equipo pequeño — deja registro de por
  qué se hizo cada cambio de esquema.
- Al menos otro integrante revisa antes de mergear (aunque sea rápido).

## Scripts de desarrollo (`dev-scripts/`)

- `test_data.sql` y `drop_all.sql` **nunca** van a
  `migrations/`. Son solo para desarrollo local.
- Si agregas datos de prueba nuevos, hazlo en `test_data.sql`
  respetando el orden de dependencias (FKs) que ya sigue el archivo.

## Documentación (`docs/`)

- Si el modelo ER cambia, actualizar `docs/MER.puml` en el mismo PR
  que la migración correspondiente.
