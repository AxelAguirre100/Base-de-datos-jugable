-- ============================================================
-- Dungeon Quiz - TP Integrador "Una base de datos que se juega"
-- Informática II · UNNE · Proyecto C
-- Motor: MySQL 8.0.16+ / MariaDB 10.2.1+ (XAMPP)
-- Parte 1: estructura (DDL) + regla 1 (triggers)
-- ============================================================

CREATE DATABASE IF NOT EXISTS dungeon_quiz
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE dungeon_quiz;

-- Para poder volver a correr el script sobre una base ya usada
-- (primero las tablas hijas, después las padres)
DROP TABLE IF EXISTS partida_pregunta;
DROP TABLE IF EXISTS partida_monstruo;
DROP TABLE IF EXISTS respuesta;
DROP TABLE IF EXISTS pregunta;
DROP TABLE IF EXISTS partida;
DROP TABLE IF EXISTS monstruo;
DROP TABLE IF EXISTS jugador;

-- ------------------------------------------------------------
-- Tablas que no dependen de otras
-- ------------------------------------------------------------

CREATE TABLE jugador (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(50) NOT NULL UNIQUE,
  nivel       INT NOT NULL DEFAULT 1,
  experiencia INT NOT NULL DEFAULT 0,
  CONSTRAINT chk_jugador_nivel CHECK (nivel >= 1),
  CONSTRAINT chk_jugador_exp   CHECK (experiencia BETWEEN 0 AND 99)
) ENGINE=InnoDB;

CREATE TABLE monstruo (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(50) NOT NULL UNIQUE,
  dificultad TINYINT NOT NULL,
  vida_base  INT NOT NULL,
  CONSTRAINT chk_monstruo_dificultad CHECK (dificultad BETWEEN 1 AND 3),
  CONSTRAINT chk_monstruo_vida       CHECK (vida_base > 0)
) ENGINE=InnoDB;

CREATE TABLE pregunta (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  enunciado  VARCHAR(255) NOT NULL,
  categoria  VARCHAR(50) NOT NULL,
  dificultad TINYINT NOT NULL,
  CONSTRAINT chk_pregunta_dificultad CHECK (dificultad BETWEEN 1 AND 3)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tablas con claves foráneas
-- ------------------------------------------------------------

CREATE TABLE partida (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  fecha       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  puntaje     INT NOT NULL DEFAULT 0,
  resultado   VARCHAR(10) NOT NULL DEFAULT 'en_curso',
  vida_actual INT NOT NULL,
  id_jugador  INT NOT NULL,
  CONSTRAINT chk_partida_puntaje   CHECK (puntaje >= 0),
  CONSTRAINT chk_partida_resultado CHECK (resultado IN ('en_curso','victoria','derrota')),
  CONSTRAINT chk_partida_vida      CHECK (vida_actual >= 0),
  CONSTRAINT fk_partida_jugador FOREIGN KEY (id_jugador)
    REFERENCES jugador (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE respuesta (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  texto       VARCHAR(255) NOT NULL,
  es_correcta BOOLEAN NOT NULL DEFAULT FALSE,
  id_pregunta INT NOT NULL,
  -- Necesaria para la FK compuesta de partida_pregunta (regla 2)
  CONSTRAINT uq_respuesta_id_pregunta UNIQUE (id, id_pregunta),
  CONSTRAINT fk_respuesta_pregunta FOREIGN KEY (id_pregunta)
    REFERENCES pregunta (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- N:M partida - monstruo (atributo propio: vida_restante)
CREATE TABLE partida_monstruo (
  id_partida    INT NOT NULL,
  id_monstruo   INT NOT NULL,
  vida_restante INT NOT NULL,
  PRIMARY KEY (id_partida, id_monstruo),
  CONSTRAINT chk_pm_vida CHECK (vida_restante >= 0),
  CONSTRAINT fk_pm_partida FOREIGN KEY (id_partida)
    REFERENCES partida (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pm_monstruo FOREIGN KEY (id_monstruo)
    REFERENCES monstruo (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- N:M partida - pregunta (atributo propio: id_respuesta_elegida)
CREATE TABLE partida_pregunta (
  id_partida           INT NOT NULL,
  id_pregunta          INT NOT NULL,
  id_respuesta_elegida INT NULL,   -- NULL hasta que el jugador contesta
  PRIMARY KEY (id_partida, id_pregunta),
  CONSTRAINT fk_pp_partida FOREIGN KEY (id_partida)
    REFERENCES partida (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pp_pregunta FOREIGN KEY (id_pregunta)
    REFERENCES pregunta (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- Regla 2: la respuesta elegida pertenece a la pregunta respondida
  CONSTRAINT fk_pp_respuesta FOREIGN KEY (id_respuesta_elegida, id_pregunta)
    REFERENCES respuesta (id, id_pregunta)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Regla 1: cada pregunta tiene a lo sumo UNA respuesta correcta
-- (si lo corrés desde la consola de MySQL/phpMyAdmin, el
--  DELIMITER es necesario porque el trigger tiene ';' adentro)
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_respuesta_una_correcta_ins
BEFORE INSERT ON respuesta
FOR EACH ROW
BEGIN
  IF NEW.es_correcta = 1 AND EXISTS (
       SELECT 1 FROM respuesta
       WHERE id_pregunta = NEW.id_pregunta AND es_correcta = 1
     ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La pregunta ya tiene una respuesta correcta';
  END IF;
END$$

CREATE TRIGGER trg_respuesta_una_correcta_upd
BEFORE UPDATE ON respuesta
FOR EACH ROW
BEGIN
  IF NEW.es_correcta = 1 AND EXISTS (
       SELECT 1 FROM respuesta
       WHERE id_pregunta = NEW.id_pregunta
         AND es_correcta = 1
         AND id <> NEW.id
     ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La pregunta ya tiene una respuesta correcta';
  END IF;
END$$

DELIMITER ;
