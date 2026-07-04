-- ============================================================
-- V1__schema.sql
-- Tipos ENUM y estructura de tablas (forma de la BD).
-- No incluye UNIQUE compuestos, EXCLUDE ni índices de
-- performance: eso vive en V2 y V3.
-- ============================================================

-- ---------- TIPOS ENUM ----------
CREATE TYPE tipo_identificacion_enum AS ENUM ('CEDULA', 'PASAPORTE', 'RUC');
CREATE TYPE estado_persona_enum AS ENUM ('ACTIVO', 'INACTIVO');
CREATE TYPE estado_usuario_enum AS ENUM ('ACTIVO', 'INACTIVO', 'BLOQUEADO');
CREATE TYPE tipo_persona_unidad_enum AS ENUM ('PROPIETARIO', 'ARRENDATARIO', 'RESIDENTE');
CREATE TYPE estado_persona_unidad_enum AS ENUM ('ACTIVO', 'FINALIZADO', 'SUSPENDIDO');
CREATE TYPE tipo_unidad_enum AS ENUM ('DEPARTAMENTO', 'CASA', 'LOCAL', 'OFICINA');
CREATE TYPE estado_parqueadero_enum AS ENUM ('DISPONIBLE', 'OCUPADO');
CREATE TYPE tipo_vehiculo_enum AS ENUM ('AUTO', 'CAMIONETA', 'MOTO', 'BICICLETA', 'SCOOTER');
CREATE TYPE tipo_cuota_enum AS ENUM ('ORDINARIA', 'EXTRAORDINARIA', 'MULTA', 'FONDO_RESERVA');
CREATE TYPE estado_cuota_enum AS ENUM ('PENDIENTE', 'PAGADA', 'VENCIDA', 'ANULADA');
CREATE TYPE estado_convenio_enum AS ENUM ('ACTIVO', 'COMPLETADO', 'INCUMPLIDO', 'ANULADO');
CREATE TYPE estado_multa_enum AS ENUM ('REGISTRADA', 'FACTURADA', 'ANULADA');
CREATE TYPE prioridad_ticket_enum AS ENUM ('BAJA', 'MEDIA', 'ALTA', 'URGENTE');
CREATE TYPE destinatario_tipo_enum AS ENUM ('TODOS', 'TORRE', 'UNIDAD', 'ROL');
CREATE TYPE canal_notificacion_enum AS ENUM ('EMAIL', 'PUSH', 'SMS', 'WHATSAPP');
CREATE TYPE estado_envio_enum AS ENUM ('PENDIENTE', 'ENVIADO', 'FALLIDO');
CREATE TYPE tipo_asamblea_enum AS ENUM ('ORDINARIA', 'EXTRAORDINARIA');
CREATE TYPE estado_asamblea_enum AS ENUM ('PROGRAMADA', 'EN_CURSO', 'FINALIZADA', 'CANCELADA');
CREATE TYPE opcion_votacion_enum AS ENUM ('A_FAVOR', 'EN_CONTRA', 'ABSTENCION');
CREATE TYPE accion_auditoria_enum AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- ---------- CATÁLOGOS DE ESTADO (datos en V6__seed.sql) ----------
CREATE TABLE estado_unidad  ( id_estado BIGSERIAL PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE );
CREATE TABLE estado_reserva ( id_estado BIGSERIAL PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE );
CREATE TABLE estado_pago    ( id_estado BIGSERIAL PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE );
CREATE TABLE estado_acceso  ( id_estado BIGSERIAL PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE );
CREATE TABLE estado_ticket  ( id_estado BIGSERIAL PRIMARY KEY, nombre VARCHAR(50) NOT NULL UNIQUE );

-- ---------- CONFIGURACIÓN ----------
CREATE TABLE configuracion (
    id_configuracion BIGSERIAL PRIMARY KEY,
    clave            VARCHAR(100) NOT NULL UNIQUE,
    valor            TEXT NOT NULL
);

-- ---------- ARCHIVOS ----------
CREATE TABLE archivo (
    id_archivo  BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(255) NOT NULL,
    ruta        TEXT NOT NULL,
    tipo        VARCHAR(50) NOT NULL,
    mime_type   VARCHAR(100),
    tamano      BIGINT,
    fecha       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- CONDOMINIO ----------
CREATE TABLE condominio (
    id_condominio BIGSERIAL PRIMARY KEY,
    nombre        VARCHAR(150) NOT NULL,
    direccion     VARCHAR(255),
    telefono      VARCHAR(30),
    email         VARCHAR(150)
);

CREATE TABLE torre (
    id_torre      BIGSERIAL PRIMARY KEY,
    id_condominio BIGINT NOT NULL REFERENCES condominio(id_condominio) ON DELETE CASCADE,
    nombre        VARCHAR(100) NOT NULL
);

CREATE TABLE unidad (
    id_unidad     BIGSERIAL PRIMARY KEY,
    id_condominio BIGINT NOT NULL REFERENCES condominio(id_condominio) ON DELETE RESTRICT,
    id_torre      BIGINT REFERENCES torre(id_torre) ON DELETE RESTRICT,
    id_estado     BIGINT NOT NULL REFERENCES estado_unidad(id_estado),
    numero        VARCHAR(20) NOT NULL,
    piso          VARCHAR(10),
    tipo          tipo_unidad_enum NOT NULL,
    alicuota      NUMERIC(8,6),
    UNIQUE (id_condominio, numero)
);

CREATE TABLE parqueadero (
    id_parqueadero BIGSERIAL PRIMARY KEY,
    id_unidad      BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE CASCADE,
    numero         VARCHAR(20) NOT NULL,
    estado         estado_parqueadero_enum NOT NULL DEFAULT 'DISPONIBLE'
);

CREATE TABLE area_comun (
    id_area       BIGSERIAL PRIMARY KEY,
    id_condominio BIGINT NOT NULL REFERENCES condominio(id_condominio) ON DELETE CASCADE,
    nombre        VARCHAR(100) NOT NULL,
    descripcion   TEXT,
    capacidad     INTEGER
);

-- ---------- PERSONAS ----------
CREATE TABLE persona (
    id_persona            BIGSERIAL PRIMARY KEY,
    tipo_identificacion   tipo_identificacion_enum NOT NULL,
    numero_identificacion VARCHAR(30) NOT NULL,
    nombres               VARCHAR(100) NOT NULL,
    apellidos             VARCHAR(100) NOT NULL,
    telefono              VARCHAR(30),
    correo                VARCHAR(254) NOT NULL,
    fecha_nacimiento      DATE,
    direccion             VARCHAR(255),
    foto_perfil           TEXT,
    estado                estado_persona_enum NOT NULL DEFAULT 'ACTIVO',
    UNIQUE (tipo_identificacion, numero_identificacion),
    UNIQUE (correo)
);

CREATE TABLE persona_unidad (
    id_persona_unidad BIGSERIAL PRIMARY KEY,
    id_persona        BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE CASCADE,
    id_unidad         BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE CASCADE,
    tipo              tipo_persona_unidad_enum NOT NULL,
    estado            estado_persona_unidad_enum NOT NULL DEFAULT 'ACTIVO',
    fecha_inicio      DATE NOT NULL,
    fecha_fin         DATE,
    CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE TABLE vehiculo (
    id_vehiculo       BIGSERIAL PRIMARY KEY,
    id_unidad         BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE CASCADE,
    id_persona_actual BIGINT REFERENCES persona(id_persona) ON DELETE SET NULL,
    tipo              tipo_vehiculo_enum NOT NULL,
    placa             VARCHAR(15),
    marca             VARCHAR(50),
    modelo            VARCHAR(50),
    color             VARCHAR(30)
);

-- ---------- AUTENTICACIÓN ----------
CREATE TABLE usuario (
    id_usuario             BIGSERIAL PRIMARY KEY,
    id_persona             BIGINT NOT NULL UNIQUE REFERENCES persona(id_persona) ON DELETE CASCADE,
    username               VARCHAR(50) NOT NULL UNIQUE,
    password_hash          TEXT NOT NULL,
    estado                 estado_usuario_enum NOT NULL DEFAULT 'ACTIVO',
    fecha_creacion         TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_login           TIMESTAMPTZ,
    intentos_fallidos      INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta        TIMESTAMPTZ,
    token_recuperacion     TEXT,
    fecha_expiracion_token TIMESTAMPTZ
);

CREATE TABLE rol (
    id_rol      BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

CREATE TABLE usuario_rol (
    id_usuario       BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    id_rol           BIGINT NOT NULL REFERENCES rol(id_rol) ON DELETE CASCADE,
    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id_usuario, id_rol)
);

CREATE TABLE permiso (
    id_permiso BIGSERIAL PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    modulo     VARCHAR(50) NOT NULL,
    accion     VARCHAR(50) NOT NULL,
    UNIQUE (modulo, accion)
);

CREATE TABLE rol_permiso (
    id_rol     BIGINT NOT NULL REFERENCES rol(id_rol) ON DELETE CASCADE,
    id_permiso BIGINT NOT NULL REFERENCES permiso(id_permiso) ON DELETE CASCADE,
    PRIMARY KEY (id_rol, id_permiso)
);

CREATE TABLE login (
    id_login   BIGSERIAL PRIMARY KEY,
    id_usuario BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    ip         INET NOT NULL,
    user_agent TEXT,
    fecha      TIMESTAMPTZ NOT NULL DEFAULT now(),
    exitoso    BOOLEAN NOT NULL
);

CREATE TABLE refresh_token (
    id_refresh_token BIGSERIAL PRIMARY KEY,
    id_usuario       BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    token            TEXT NOT NULL UNIQUE,
    ip               INET,
    dispositivo      VARCHAR(150),
    fecha_expiracion TIMESTAMPTZ NOT NULL,
    revocado         BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_creacion   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- AUDITORÍA ----------
CREATE TABLE auditoria (
    id_auditoria       BIGSERIAL PRIMARY KEY,
    tabla_afectada     VARCHAR(100) NOT NULL,
    id_registro        BIGINT NOT NULL,
    accion             accion_auditoria_enum NOT NULL,
    id_usuario         BIGINT REFERENCES usuario(id_usuario) ON DELETE SET NULL,
    valores_anteriores JSONB,
    valores_nuevos     JSONB,
    ip                 INET,
    user_agent         TEXT,
    fecha              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- FINANZAS ----------
CREATE TABLE cuota (
    id_cuota          BIGSERIAL PRIMARY KEY,
    id_unidad         BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE RESTRICT,
    mes               SMALLINT NOT NULL CHECK (mes BETWEEN 1 AND 12),
    anio              SMALLINT NOT NULL,
    valor             NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
    tipo              tipo_cuota_enum NOT NULL,
    descripcion       TEXT,
    fecha_vencimiento DATE NOT NULL,
    estado            estado_cuota_enum NOT NULL DEFAULT 'PENDIENTE'
);

CREATE TABLE pago (
    id_pago    BIGSERIAL PRIMARY KEY,
    id_cuota   BIGINT NOT NULL REFERENCES cuota(id_cuota) ON DELETE RESTRICT,
    id_estado  BIGINT NOT NULL REFERENCES estado_pago(id_estado),
    fecha      TIMESTAMPTZ NOT NULL DEFAULT now(),
    valor      NUMERIC(10,2) NOT NULL CHECK (valor > 0),
    metodo     VARCHAR(50) NOT NULL,
    referencia VARCHAR(100)
);

CREATE TABLE recibo (
    id_recibo  BIGSERIAL PRIMARY KEY,
    numero     VARCHAR(30) NOT NULL UNIQUE,
    id_pago    BIGINT NOT NULL UNIQUE REFERENCES pago(id_pago) ON DELETE RESTRICT,
    id_archivo BIGINT REFERENCES archivo(id_archivo) ON DELETE SET NULL
);

CREATE TABLE convenio_pago (
    id_convenio  BIGSERIAL PRIMARY KEY,
    id_persona   BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    id_unidad    BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE RESTRICT,
    monto_total  NUMERIC(10,2) NOT NULL CHECK (monto_total > 0),
    num_cuotas   SMALLINT NOT NULL CHECK (num_cuotas > 0),
    fecha_inicio DATE NOT NULL,
    estado       estado_convenio_enum NOT NULL DEFAULT 'ACTIVO'
);

CREATE TABLE multa (
    id_multa    BIGSERIAL PRIMARY KEY,
    id_unidad   BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE RESTRICT,
    id_persona  BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    id_cuota    BIGINT UNIQUE REFERENCES cuota(id_cuota) ON DELETE SET NULL,
    motivo      VARCHAR(150) NOT NULL,
    descripcion TEXT,
    valor       NUMERIC(10,2) NOT NULL CHECK (valor > 0),
    fecha       DATE NOT NULL DEFAULT CURRENT_DATE,
    estado      estado_multa_enum NOT NULL DEFAULT 'REGISTRADA'
);

-- ---------- MANTENIMIENTO ----------
CREATE TABLE categoria (
    id_categoria BIGSERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE ticket (
    id_ticket         BIGSERIAL PRIMARY KEY,
    id_persona        BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    id_unidad         BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE RESTRICT,
    id_tecnico        BIGINT REFERENCES persona(id_persona) ON DELETE SET NULL,
    id_categoria      BIGINT REFERENCES categoria(id_categoria) ON DELETE SET NULL,
    id_estado_actual  BIGINT REFERENCES estado_ticket(id_estado),
    titulo            VARCHAR(150) NOT NULL,
    descripcion       TEXT NOT NULL,
    prioridad         prioridad_ticket_enum NOT NULL DEFAULT 'MEDIA',
    fecha_creacion    TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_cierre      TIMESTAMPTZ
);

CREATE TABLE historial_ticket (
    id_historial BIGSERIAL PRIMARY KEY,
    id_ticket    BIGINT NOT NULL REFERENCES ticket(id_ticket) ON DELETE CASCADE,
    id_estado    BIGINT NOT NULL REFERENCES estado_ticket(id_estado),
    id_usuario   BIGINT NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
    fecha        TIMESTAMPTZ NOT NULL DEFAULT now(),
    comentario   TEXT
);

CREATE TABLE ticket_comentario (
    id_comentario BIGSERIAL PRIMARY KEY,
    id_ticket     BIGINT NOT NULL REFERENCES ticket(id_ticket) ON DELETE CASCADE,
    id_persona    BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    comentario    TEXT NOT NULL,
    fecha         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ticket_archivo (
    id_ticket  BIGINT NOT NULL REFERENCES ticket(id_ticket) ON DELETE CASCADE,
    id_archivo BIGINT NOT NULL REFERENCES archivo(id_archivo) ON DELETE CASCADE,
    PRIMARY KEY (id_ticket, id_archivo)
);

-- ---------- SEGURIDAD (visitas) ----------
CREATE TABLE visitante (
    id_visitante BIGSERIAL PRIMARY KEY,
    nombre       VARCHAR(150) NOT NULL,
    cedula       VARCHAR(30),
    telefono     VARCHAR(30)
);

CREATE TABLE visitante_preautorizado (
    id_preautorizacion BIGSERIAL PRIMARY KEY,
    id_visitante        BIGINT NOT NULL REFERENCES visitante(id_visitante) ON DELETE CASCADE,
    id_unidad           BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE CASCADE,
    autorizado_por       BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    fecha_autorizada     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE acceso (
    id_acceso           BIGSERIAL PRIMARY KEY,
    id_visitante         BIGINT NOT NULL REFERENCES visitante(id_visitante) ON DELETE RESTRICT,
    id_unidad            BIGINT NOT NULL REFERENCES unidad(id_unidad) ON DELETE RESTRICT,
    id_guardia           BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    id_vehiculo          BIGINT REFERENCES vehiculo(id_vehiculo) ON DELETE SET NULL,
    id_preautorizacion   BIGINT REFERENCES visitante_preautorizado(id_preautorizacion) ON DELETE SET NULL,
    id_estado            BIGINT NOT NULL REFERENCES estado_acceso(id_estado),
    hora_ingreso         TIMESTAMPTZ NOT NULL DEFAULT now(),
    hora_salida          TIMESTAMPTZ,
    foto                 TEXT,
    CHECK (hora_salida IS NULL OR hora_salida >= hora_ingreso)
);

-- ---------- RESERVAS ----------
CREATE TABLE reserva (
    id_reserva           BIGSERIAL PRIMARY KEY,
    id_area               BIGINT NOT NULL REFERENCES area_comun(id_area) ON DELETE CASCADE,
    id_persona            BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    id_estado             BIGINT NOT NULL REFERENCES estado_reserva(id_estado),
    id_usuario_aprobador  BIGINT REFERENCES usuario(id_usuario) ON DELETE SET NULL,
    fecha                 DATE NOT NULL,
    hora_inicio           TIME NOT NULL,
    hora_fin              TIME NOT NULL,
    fecha_creacion        TIMESTAMPTZ NOT NULL DEFAULT now(),
    motivo                VARCHAR(200),
    observaciones         TEXT,
    periodo               tsrange GENERATED ALWAYS AS (tsrange(fecha + hora_inicio, fecha + hora_fin)) STORED,
    bloquea_horario        BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (hora_fin > hora_inicio)
);

-- ---------- COMUNICACIÓN ----------
CREATE TABLE comunicado (
    id_comunicado     BIGSERIAL PRIMARY KEY,
    titulo             VARCHAR(150) NOT NULL,
    mensaje            TEXT NOT NULL,
    fecha              TIMESTAMPTZ NOT NULL DEFAULT now(),
    id_autor           BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    destinatario_tipo  destinatario_tipo_enum NOT NULL,
    destinatario_id    BIGINT
    -- FK polimórfica (según destinatario_tipo); validada en la API, no en BD.
);

CREATE TABLE comunicado_lectura (
    id_comunicado  BIGINT NOT NULL REFERENCES comunicado(id_comunicado) ON DELETE CASCADE,
    id_persona     BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE CASCADE,
    fecha_lectura  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id_comunicado, id_persona)
);

CREATE TABLE notificacion (
    id_notificacion BIGSERIAL PRIMARY KEY,
    id_persona       BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE CASCADE,
    tipo             VARCHAR(50) NOT NULL,
    titulo           VARCHAR(150) NOT NULL,
    mensaje          TEXT NOT NULL,
    canal            canal_notificacion_enum NOT NULL,
    estado_envio     estado_envio_enum NOT NULL DEFAULT 'PENDIENTE',
    fecha_envio      TIMESTAMPTZ,
    leido            BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_lectura    TIMESTAMPTZ
);

-- ---------- ASAMBLEAS ----------
CREATE TABLE asamblea (
    id_asamblea       BIGSERIAL PRIMARY KEY,
    id_condominio      BIGINT NOT NULL REFERENCES condominio(id_condominio) ON DELETE CASCADE,
    fecha              TIMESTAMPTZ NOT NULL,
    tipo               tipo_asamblea_enum NOT NULL,
    quorum_requerido   NUMERIC(5,2),
    estado             estado_asamblea_enum NOT NULL DEFAULT 'PROGRAMADA'
);

CREATE TABLE votacion (
    id_votacion  BIGSERIAL PRIMARY KEY,
    id_asamblea   BIGINT NOT NULL REFERENCES asamblea(id_asamblea) ON DELETE CASCADE,
    id_persona    BIGINT NOT NULL REFERENCES persona(id_persona) ON DELETE RESTRICT,
    opcion        opcion_votacion_enum NOT NULL,
    fecha         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id_asamblea, id_persona)
);

CREATE TABLE acta (
    id_acta      BIGSERIAL PRIMARY KEY,
    id_asamblea   BIGINT NOT NULL UNIQUE REFERENCES asamblea(id_asamblea) ON DELETE CASCADE,
    contenido     TEXT
);

CREATE TABLE acta_archivo (
    id_acta     BIGINT NOT NULL REFERENCES acta(id_acta) ON DELETE CASCADE,
    id_archivo  BIGINT NOT NULL REFERENCES archivo(id_archivo) ON DELETE CASCADE,
    PRIMARY KEY (id_acta, id_archivo)
);
