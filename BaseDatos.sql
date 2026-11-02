-- =====================================================================
--  BaseDatos.sql  -  Sistema de seguimiento de estudiantes con riesgo de abandono escolar
--  Universidad Mariano Gálvez de Guatemala - Programación II
--
--  CÓMO EJECUTARLO (MySQL Workbench):
--    File > Open SQL Script > seleccione este archivo > botón del rayo (Execute).
--  Crea la base de datos "seguimiento_estudiantil", las tablas y datos de prueba.
--  ¡OJO! Borra la base de datos si ya existía.
--
--  USUARIOS DE PRUEBA (contraseña entre paréntesis):
--    admin (admin123) | docente1 (doc123) | docente2 (doc123)
--    orient1 (ori123) | coord1 (coord123) | dir1 (dir123)
-- =====================================================================

DROP DATABASE IF EXISTS seguimiento_estudiantil;
CREATE DATABASE seguimiento_estudiantil CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE seguimiento_estudiantil;

-- ---------------------------------------------------------------------
-- 1. Datos del centro educativo (solo hay un registro por instalación)
-- ---------------------------------------------------------------------
CREATE TABLE centro_educativo (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL,
    codigo        VARCHAR(30)  NOT NULL,
    direccion     VARCHAR(200),
    telefono      VARCHAR(20),
    correo        VARCHAR(100),
    director      VARCHAR(100),
    niveles       VARCHAR(100),
    logotipo      VARCHAR(255),
    anio_vigente  INT NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. Usuarios y roles
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    nombres    VARCHAR(80) NOT NULL,
    apellidos  VARCHAR(80) NOT NULL,
    usuario    VARCHAR(40) NOT NULL UNIQUE,
    clave      CHAR(64)    NOT NULL,   -- SHA-256 de la contraseña (nunca texto plano)
    rol        ENUM('Administrador','Docente','Orientador','Coordinador académico','Director') NOT NULL,
    estado     ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo'
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. Estructura académica
-- ---------------------------------------------------------------------
CREATE TABLE grupo (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    codigo         VARCHAR(30) NOT NULL UNIQUE,
    anio           INT NOT NULL,
    nivel          ENUM('Preprimaria','Primaria','Básico','Diversificado','Universitario') NOT NULL,
    grado          VARCHAR(40) NOT NULL,
    carrera        VARCHAR(80) NULL,     -- solo para Diversificado o Universitario
    seccion        VARCHAR(10),
    jornada        ENUM('Matutina','Vespertina','Nocturna','Fin de semana') NOT NULL,
    id_docente     INT NULL,             -- docente encargado
    estado         ENUM('Activo','Inactivo') NOT NULL DEFAULT 'Activo',
    observaciones  TEXT,
    CONSTRAINT fk_grupo_docente FOREIGN KEY (id_docente) REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE curso (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(80) NOT NULL UNIQUE,
    descripcion  VARCHAR(200)
) ENGINE=InnoDB;

-- Qué docente imparte cada curso en cada grupo
CREATE TABLE asignacion (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    anio          INT NOT NULL,
    id_docente    INT NOT NULL,
    id_curso      INT NOT NULL,
    id_grupo      INT NOT NULL,
    fecha_inicio  DATE NOT NULL,
    fecha_fin     DATE NULL,
    estado        ENUM('Activa','Finalizada') NOT NULL DEFAULT 'Activa',
    CONSTRAINT uq_asignacion UNIQUE (anio, id_curso, id_grupo),
    CONSTRAINT fk_asig_docente FOREIGN KEY (id_docente) REFERENCES usuario(id),
    CONSTRAINT fk_asig_curso   FOREIGN KEY (id_curso)   REFERENCES curso(id),
    CONSTRAINT fk_asig_grupo   FOREIGN KEY (id_grupo)   REFERENCES grupo(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. Estudiantes y responsables familiares
-- ---------------------------------------------------------------------
CREATE TABLE responsable (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    nombres         VARCHAR(80) NOT NULL,
    apellidos       VARCHAR(80) NOT NULL,
    identificacion  VARCHAR(30) NOT NULL,
    direccion       VARCHAR(200),
    telefono        VARCHAR(20) NOT NULL,
    correo          VARCHAR(100),
    ocupacion       VARCHAR(80),
    observaciones   TEXT
) ENGINE=InnoDB;

CREATE TABLE estudiante (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    carne              VARCHAR(20) NOT NULL UNIQUE,
    nombres            VARCHAR(80) NOT NULL,
    apellidos          VARCHAR(80) NOT NULL,
    fecha_nacimiento   DATE NOT NULL,
    sexo               ENUM('Masculino','Femenino') NOT NULL,
    direccion          VARCHAR(200),
    comunidad          VARCHAR(100),
    telefono           VARCHAR(20),
    fecha_inscripcion  DATE NOT NULL,
    id_grupo           INT NOT NULL,     -- cada estudiante pertenece a un grupo
    estado             ENUM('Activo','En seguimiento','Trasladado','Retirado','Graduado','Inactivo') NOT NULL DEFAULT 'Activo',
    fotografia         VARCHAR(255),
    observaciones      TEXT,
    CONSTRAINT fk_est_grupo FOREIGN KEY (id_grupo) REFERENCES grupo(id)
) ENGINE=InnoDB;

-- Un responsable puede tener varios estudiantes; un estudiante puede tener varios responsables
CREATE TABLE estudiante_responsable (
    id_estudiante  INT NOT NULL,
    id_responsable INT NOT NULL,
    parentesco     VARCHAR(40) NOT NULL,
    PRIMARY KEY (id_estudiante, id_responsable),
    CONSTRAINT fk_er_est  FOREIGN KEY (id_estudiante)  REFERENCES estudiante(id),
    CONSTRAINT fk_er_resp FOREIGN KEY (id_responsable) REFERENCES responsable(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. Asistencia y justificaciones
-- ---------------------------------------------------------------------
CREATE TABLE asistencia (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    fecha          DATE NOT NULL,
    id_curso       INT NOT NULL,
    id_grupo       INT NOT NULL,
    id_estudiante  INT NOT NULL,
    estado         ENUM('Presente','Ausente','Ausencia justificada','Llegada tarde','Retiro anticipado') NOT NULL,
    motivo         VARCHAR(200),
    id_docente     INT NOT NULL,
    observaciones  TEXT,
    -- Regla: no hay asistencia duplicada para el mismo estudiante, curso y fecha
    CONSTRAINT uq_asistencia UNIQUE (fecha, id_curso, id_estudiante),
    CONSTRAINT fk_as_curso   FOREIGN KEY (id_curso)      REFERENCES curso(id),
    CONSTRAINT fk_as_grupo   FOREIGN KEY (id_grupo)      REFERENCES grupo(id),
    CONSTRAINT fk_as_est     FOREIGN KEY (id_estudiante) REFERENCES estudiante(id),
    CONSTRAINT fk_as_docente FOREIGN KEY (id_docente)    REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE justificacion (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    id_asistencia        INT NOT NULL UNIQUE,   -- una ausencia se justifica una sola vez
    motivo               VARCHAR(200) NOT NULL,
    id_responsable       INT NOT NULL,          -- quién presentó la justificación
    fecha_presentacion   DATE NOT NULL,
    documento            VARCHAR(255),
    id_usuario_autoriza  INT NOT NULL,          -- usuario que autorizó
    observaciones        TEXT,
    CONSTRAINT fk_just_asis FOREIGN KEY (id_asistencia)       REFERENCES asistencia(id),
    CONSTRAINT fk_just_resp FOREIGN KEY (id_responsable)      REFERENCES responsable(id),
    CONSTRAINT fk_just_user FOREIGN KEY (id_usuario_autoriza) REFERENCES usuario(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Rendimiento académico
-- ---------------------------------------------------------------------
CREATE TABLE rendimiento (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante  INT NOT NULL,
    id_curso       INT NOT NULL,
    periodo        VARCHAR(30) NOT NULL,        -- Unidad 1, Bimestre 2, Semestre 1, etc.
    nota           DECIMAL(5,2) NOT NULL,
    nota_minima    DECIMAL(5,2) NOT NULL,       -- nota mínima de aprobación
    id_docente     INT NOT NULL,
    fecha          DATE NOT NULL,
    observaciones  TEXT,
    CONSTRAINT ck_nota CHECK (nota >= 0 AND nota_minima >= 0),
    CONSTRAINT fk_rend_est     FOREIGN KEY (id_estudiante) REFERENCES estudiante(id),
    CONSTRAINT fk_rend_curso   FOREIGN KEY (id_curso)      REFERENCES curso(id),
    CONSTRAINT fk_rend_docente FOREIGN KEY (id_docente)    REFERENCES usuario(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. Alertas (los límites se configuran aquí, NO en el código Java)
-- ---------------------------------------------------------------------
CREATE TABLE config_alerta (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    clave        VARCHAR(40) NOT NULL UNIQUE,
    descripcion  VARCHAR(200) NOT NULL,
    valor        DECIMAL(8,2) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE alerta (
    id              INT AUTO_INCREMENT PRIMARY KEY,   -- número de alerta
    id_estudiante   INT NOT NULL,
    fecha           DATE NOT NULL,
    tipo            VARCHAR(50)  NOT NULL,
    motivo          VARCHAR(255) NOT NULL,
    prioridad       ENUM('Bajo','Medio','Alto') NOT NULL,
    informacion     TEXT,                              -- información que originó la alerta
    id_responsable  INT NULL,                          -- responsable asignado
    estado          ENUM('Pendiente de revisión','Confirmada','En seguimiento','Resuelta','Descartada') NOT NULL DEFAULT 'Pendiente de revisión',
    observaciones   TEXT,
    CONSTRAINT fk_alerta_est  FOREIGN KEY (id_estudiante)  REFERENCES estudiante(id),
    CONSTRAINT fk_alerta_resp FOREIGN KEY (id_responsable) REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE factor_riesgo (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante  INT NOT NULL,
    tipo           ENUM('Dificultades económicas','Problemas de transporte','Trabajo infantil o juvenil','Cambio de residencia',
                        'Problemas de salud','Responsabilidades familiares','Falta de apoyo académico','Dificultades de aprendizaje',
                        'Acoso escolar','Otros factores justificados') NOT NULL,
    descripcion    TEXT,
    fecha          DATE NOT NULL,
    id_usuario     INT NOT NULL,
    CONSTRAINT fk_fr_est  FOREIGN KEY (id_estudiante) REFERENCES estudiante(id),
    CONSTRAINT fk_fr_user FOREIGN KEY (id_usuario)    REFERENCES usuario(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. Seguimiento: planes, acciones, reuniones y visitas
-- ---------------------------------------------------------------------
CREATE TABLE plan_seguimiento (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante      INT NOT NULL,
    id_alerta          INT NOT NULL UNIQUE,            -- un plan por alerta confirmada
    situacion          TEXT NOT NULL,
    objetivos          TEXT NOT NULL,
    acciones           TEXT,
    responsables       VARCHAR(200) NOT NULL,
    fecha_inicio       DATE NOT NULL,
    fecha_revision     DATE,
    estado             ENUM('Abierto','Cerrado') NOT NULL DEFAULT 'Abierto',
    observaciones      TEXT,
    -- Datos del cierre del caso
    fecha_cierre       DATE NULL,
    motivo_cierre      VARCHAR(80) NULL,
    resultado_cierre   TEXT NULL,
    id_usuario_cierre  INT NULL,
    CONSTRAINT fk_plan_est    FOREIGN KEY (id_estudiante)     REFERENCES estudiante(id),
    CONSTRAINT fk_plan_alerta FOREIGN KEY (id_alerta)         REFERENCES alerta(id),
    CONSTRAINT fk_plan_cierre FOREIGN KEY (id_usuario_cierre) REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE accion_apoyo (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    id_plan         INT NOT NULL,
    fecha           DATE NOT NULL,
    tipo            ENUM('Entrevista con el estudiante','Reunión con el responsable familiar','Tutoría académica','Visita domiciliaria',
                         'Apoyo con materiales','Orientación','Referencia a otra institución','Acuerdo de asistencia',
                         'Otras acciones autorizadas') NOT NULL,
    id_responsable  INT NOT NULL,                      -- toda acción tiene un responsable
    descripcion     TEXT NOT NULL,
    resultado       TEXT,
    compromisos     TEXT,
    proxima_fecha   DATE,
    evidencia       VARCHAR(255),
    CONSTRAINT fk_acc_plan FOREIGN KEY (id_plan)        REFERENCES plan_seguimiento(id),
    CONSTRAINT fk_acc_resp FOREIGN KEY (id_responsable) REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE reunion (
    id                     INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante          INT NOT NULL,
    id_responsable         INT NOT NULL,
    fecha_hora             DATETIME NOT NULL,
    motivo                 VARCHAR(200) NOT NULL,
    participantes          TEXT,
    situacion              TEXT,
    acuerdos               TEXT,
    responsables_acuerdos  VARCHAR(200),
    fecha_revision         DATE,
    estado                 ENUM('Pendiente','Cumplido','Incumplido') NOT NULL DEFAULT 'Pendiente',
    observaciones          TEXT,
    id_usuario             INT NOT NULL,
    CONSTRAINT fk_reu_est  FOREIGN KEY (id_estudiante)  REFERENCES estudiante(id),
    CONSTRAINT fk_reu_resp FOREIGN KEY (id_responsable) REFERENCES responsable(id),
    CONSTRAINT fk_reu_user FOREIGN KEY (id_usuario)     REFERENCES usuario(id)
) ENGINE=InnoDB;

CREATE TABLE visita_domiciliaria (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante    INT NOT NULL,
    familia_visitada VARCHAR(120) NOT NULL,
    fecha_hora       DATETIME NOT NULL,
    id_usuario       INT NOT NULL,                     -- personal responsable
    motivo           VARCHAR(200) NOT NULL,
    situacion        TEXT,
    acciones         TEXT,
    compromisos      TEXT,
    proxima_visita   DATE,
    observaciones    TEXT,
    CONSTRAINT fk_vis_est  FOREIGN KEY (id_estudiante) REFERENCES estudiante(id),
    CONSTRAINT fk_vis_user FOREIGN KEY (id_usuario)    REFERENCES usuario(id)
) ENGINE=InnoDB;

-- Índices para acelerar las consultas y reportes más usados
CREATE INDEX ix_asistencia_est  ON asistencia(id_estudiante, fecha);
CREATE INDEX ix_rendimiento_est ON rendimiento(id_estudiante, id_curso);
CREATE INDEX ix_alerta_est      ON alerta(id_estudiante, estado);
CREATE INDEX ix_estudiante_grp  ON estudiante(id_grupo);

-- =====================================================================
--  DATOS DE PRUEBA
-- =====================================================================
INSERT INTO centro_educativo (nombre, codigo, direccion, telefono, correo, director, niveles, anio_vigente) VALUES
('Instituto Nacional de Educación Básica Ejemplo', '01-01-0001-43', '5a avenida 10-20 zona 1, Guatemala', '2222-3333',
 'info@inebejemplo.edu.gt', 'Elena Torres', 'Básico', 2026);

INSERT INTO usuario (nombres, apellidos, usuario, clave, rol) VALUES
('Administrador', 'del Sistema', 'admin',    SHA2('admin123', 256), 'Administrador'),
('Marta',  'López',  'docente1', SHA2('doc123', 256),   'Docente'),
('Luis',   'Pérez',  'docente2', SHA2('doc123', 256),   'Docente'),
('Ana',    'Ruiz',   'orient1',  SHA2('ori123', 256),   'Orientador'),
('Carlos', 'Méndez', 'coord1',   SHA2('coord123', 256), 'Coordinador académico'),
('Elena',  'Torres', 'dir1',     SHA2('dir123', 256),   'Director');

INSERT INTO curso (nombre, descripcion) VALUES
('Matemática', 'Matemática de nivel básico'),
('Comunicación y Lenguaje', 'Idioma español'),
('Ciencias Naturales', 'Biología y física básica'),
('Estudios Sociales', 'Historia y formación ciudadana');

INSERT INTO grupo (codigo, anio, nivel, grado, carrera, seccion, jornada, id_docente, estado) VALUES
('B1-A-2026', 2026, 'Básico', 'Primero Básico', NULL, 'A', 'Matutina', 2, 'Activo'),
('B2-B-2026', 2026, 'Básico', 'Segundo Básico', NULL, 'B', 'Matutina', 3, 'Activo');

INSERT INTO asignacion (anio, id_docente, id_curso, id_grupo, fecha_inicio, estado) VALUES
(2026, 2, 1, 1, '2026-01-15', 'Activa'),
(2026, 3, 2, 1, '2026-01-15', 'Activa'),
(2026, 2, 3, 1, '2026-01-15', 'Activa'),
(2026, 3, 1, 2, '2026-01-15', 'Activa'),
(2026, 2, 4, 2, '2026-01-15', 'Activa');

INSERT INTO responsable (codigo, nombres, apellidos, identificacion, direccion, telefono, correo, ocupacion) VALUES
('R-001', 'Rosa',   'Hernández', '2501 12345 0101', 'Colonia El Milagro, zona 6', '5555-1111', 'rosa@correo.com', 'Comerciante'),
('R-002', 'Pedro',  'Gómez',     '2502 23456 0101', 'Aldea San José',              '5555-2222', NULL,             'Agricultor'),
('R-003', 'Julia',  'Castillo',  '2503 34567 0101', 'Barrio La Libertad',          '5555-3333', 'julia@correo.com', 'Maestra'),
('R-004', 'Miguel', 'Ramírez',   '2504 45678 0101', 'Colonia Nueva Esperanza',     '5555-4444', NULL,             'Albañil');

INSERT INTO estudiante (carne, nombres, apellidos, fecha_nacimiento, sexo, direccion, comunidad, telefono, fecha_inscripcion, id_grupo, estado) VALUES
('2026-001', 'Kevin',   'Hernández', '2012-04-10', 'Masculino', 'Colonia El Milagro, zona 6', 'El Milagro',   '5555-1111', '2026-01-10', 1, 'Activo'),
('2026-002', 'Daniela', 'Gómez',     '2012-08-22', 'Femenino',  'Aldea San José',             'San José',      NULL,        '2026-01-10', 1, 'Activo'),
('2026-003', 'Andrea',  'Castillo',  '2011-12-05', 'Femenino',  'Barrio La Libertad',         'La Libertad',   '5555-3333', '2026-01-11', 1, 'Activo'),
('2026-004', 'Josué',   'Ramírez',   '2010-02-17', 'Masculino', 'Colonia Nueva Esperanza',    'Nueva Esperanza','5555-4444','2026-01-11', 2, 'Activo'),
('2026-005', 'Lucía',   'Hernández', '2011-06-30', 'Femenino',  'Colonia El Milagro, zona 6', 'El Milagro',    '5555-1111', '2026-01-12', 2, 'Activo');

INSERT INTO estudiante_responsable (id_estudiante, id_responsable, parentesco) VALUES
(1, 1, 'Madre'), (2, 2, 'Padre'), (3, 3, 'Madre'), (4, 4, 'Padre'), (5, 1, 'Madre');

-- Límites configurables de las alertas
INSERT INTO config_alerta (clave, descripcion, valor) VALUES
('max_ausencias',         'Cantidad de ausencias sin justificar que genera alerta',            5),
('pct_inasistencia',      'Porcentaje de inasistencia que genera alerta',                     20),
('min_registros',         'Mínimo de registros de asistencia para evaluar el porcentaje',      5),
('max_tardes',            'Cantidad de llegadas tarde que genera alerta',                      5),
('promedio_minimo',       'Promedio general mínimo establecido',                              60),
('max_cursos_reprobados', 'Cantidad de cursos reprobados que genera alerta',                   2),
('caida_rendimiento',     'Puntos de caída entre dos notas consecutivas que genera alerta',   15),
('nota_maxima',           'Nota máxima permitida (las notas deben estar entre 0 y este valor)', 100),
('nota_aprobacion',       'Nota mínima de aprobación por defecto',                            60);

-- Asistencia del curso 1 (Matemática), grupo 1: Kevin (id 1) tiene muchas ausencias; Daniela (id 2) muchas llegadas tarde
INSERT INTO asistencia (fecha, id_curso, id_grupo, id_estudiante, estado, motivo, id_docente) VALUES
('2026-03-02', 1, 1, 1, 'Ausente', NULL, 2), ('2026-03-03', 1, 1, 1, 'Ausente', NULL, 2),
('2026-03-09', 1, 1, 1, 'Ausente', NULL, 2), ('2026-03-16', 1, 1, 1, 'Presente', NULL, 2),
('2026-03-23', 1, 1, 1, 'Ausente', NULL, 2), ('2026-03-30', 1, 1, 1, 'Ausente', NULL, 2),
('2026-04-06', 1, 1, 1, 'Ausente', NULL, 2), ('2026-04-13', 1, 1, 1, 'Presente', NULL, 2),
('2026-03-02', 1, 1, 2, 'Llegada tarde', 'Transporte', 2), ('2026-03-03', 1, 1, 2, 'Llegada tarde', 'Transporte', 2),
('2026-03-09', 1, 1, 2, 'Llegada tarde', NULL, 2), ('2026-03-16', 1, 1, 2, 'Llegada tarde', NULL, 2),
('2026-03-23', 1, 1, 2, 'Llegada tarde', NULL, 2), ('2026-03-30', 1, 1, 2, 'Presente', NULL, 2),
('2026-03-02', 1, 1, 3, 'Presente', NULL, 2), ('2026-03-03', 1, 1, 3, 'Ausencia justificada', 'Cita médica', 2),
('2026-03-09', 1, 1, 3, 'Presente', NULL, 2), ('2026-03-16', 1, 1, 3, 'Presente', NULL, 2);

INSERT INTO justificacion (id_asistencia, motivo, id_responsable, fecha_presentacion, id_usuario_autoriza, observaciones) VALUES
(16, 'Cita médica de control', 3, '2026-03-04', 4, 'Presentó constancia del centro de salud');

-- Notas: Josué (id 4) tiene notas bajas y una caída fuerte; Andrea (id 3) buenas notas
INSERT INTO rendimiento (id_estudiante, id_curso, periodo, nota, nota_minima, id_docente, fecha) VALUES
(4, 1, 'Unidad 1', 72, 60, 3, '2026-03-20'), (4, 1, 'Unidad 2', 48, 60, 3, '2026-05-20'),
(4, 4, 'Unidad 1', 55, 60, 2, '2026-03-20'), (4, 4, 'Unidad 2', 50, 60, 2, '2026-05-20'),
(3, 1, 'Unidad 1', 88, 60, 2, '2026-03-20'), (3, 2, 'Unidad 1', 92, 60, 3, '2026-03-20'),
(1, 1, 'Unidad 1', 65, 60, 2, '2026-03-20'), (2, 1, 'Unidad 1', 70, 60, 2, '2026-03-20'),
(5, 1, 'Unidad 1', 80, 60, 3, '2026-03-20');

-- Una reunión de ejemplo (sirve para probar el Acta de reunión en PDF)
INSERT INTO reunion (id_estudiante, id_responsable, fecha_hora, motivo, participantes, situacion, acuerdos,
                     responsables_acuerdos, fecha_revision, estado, id_usuario) VALUES
(2, 2, '2026-04-20 10:00:00', 'Llegadas tarde frecuentes',
 'Pedro Gómez (padre), Ana Ruiz (orientadora), Daniela Gómez',
 'La estudiante llega tarde por problemas de transporte desde su aldea.',
 'El padre buscará un horario de transporte más temprano. La orientadora dará seguimiento semanal.',
 'Pedro Gómez y Ana Ruiz', '2026-05-20', 'Pendiente', 4);

-- Fin del script
