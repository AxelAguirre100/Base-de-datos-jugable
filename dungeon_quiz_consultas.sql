-- ============================================================
-- Dungeon Quiz - Consultas (10)
-- Correr DESPUÉS de dungeon_quiz_schema.sql y dungeon_quiz_datos.sql
-- Motor: MySQL 8.0.16+ / MariaDB 10.2.1+ (XAMPP)
-- ============================================================

USE dungeon_quiz;

-- ------------------------------------------------------------
-- OBLIGATORIAS DEL PROYECTO C
-- ------------------------------------------------------------

-- Q1) Tabla de clasificación (leaderboard): los 5 mayores puntajes.
--     Técnicas: JOIN, ORDER BY, LIMIT.
--     Esperado con los datos semilla: Ana 120, Ana 60, Beto 40, Carla 20.
SELECT j.nombre, p.puntaje, p.resultado, p.fecha
FROM partida p
JOIN jugador j ON j.id = p.id_jugador
ORDER BY p.puntaje DESC
LIMIT 5;

-- Q2) Rendimiento por categoría: porcentaje de aciertos.
--     Técnicas: JOIN, GROUP BY, agregaciones.
--     Solo cuenta preguntas ya contestadas (el JOIN con respuesta descarta los NULL).
--     Esperado: Bases de datos 6 / 4 / 66.7 ; Programación 1 / 1 / 100.0
SELECT pr.categoria,
       COUNT(*)           AS respondidas,
       SUM(r.es_correcta) AS aciertos,
       ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1) AS porcentaje_aciertos
FROM partida_pregunta pp
JOIN pregunta  pr ON pr.id = pp.id_pregunta
JOIN respuesta r  ON r.id  = pp.id_respuesta_elegida
GROUP BY pr.categoria
ORDER BY porcentaje_aciertos DESC;

-- Q3) Selección aleatoria de preguntas según dificultad.
--     Cambiar el 1 por 2 o 3 según el nivel del jugador.
--     En la app, el 1 y el 3 son parámetros.
SELECT id, enunciado, categoria
FROM pregunta
WHERE dificultad = 1
ORDER BY RAND()
LIMIT 3;

-- ------------------------------------------------------------
-- REQUISITOS DE TÉCNICA
-- ------------------------------------------------------------

-- Q4) JOIN de 5 tablas: detalle de cada pregunta respondida en cada partida.
--     Muestra quién jugó, qué se le preguntó, qué eligió y si acertó.
SELECT j.nombre AS jugador,
       pa.id    AS partida,
       pr.enunciado,
       r.texto  AS respuesta_elegida,
       CASE WHEN r.es_correcta = 1 THEN 'Acierto' ELSE 'Error' END AS resultado
FROM jugador j
JOIN partida          pa ON pa.id_jugador = j.id
JOIN partida_pregunta pp ON pp.id_partida = pa.id
JOIN pregunta         pr ON pr.id = pp.id_pregunta
JOIN respuesta        r  ON r.id  = pp.id_respuesta_elegida
ORDER BY pa.id, pr.id;

-- Q5) Anti-join (LEFT JOIN ... IS NULL): preguntas que nunca se usaron en
--     ninguna partida. Sirve para detectar preguntas sin rotación del banco.
--     Esperado: las preguntas 8 a 15 (solo se usaron 1 a 7).
SELECT pr.id, pr.enunciado, pr.categoria
FROM pregunta pr
LEFT JOIN partida_pregunta pp ON pp.id_pregunta = pr.id
WHERE pp.id_pregunta IS NULL
ORDER BY pr.id;

-- Q6) Subconsulta escalar: partidas con puntaje mayor al promedio general.
--     Esperado: Ana (120). El promedio es (120+40+20+60)/4 = 60, y 60 no es > 60.
SELECT j.nombre, pa.puntaje, pa.resultado
FROM partida pa
JOIN jugador j ON j.id = pa.id_jugador
WHERE pa.puntaje > (SELECT AVG(puntaje) FROM partida)
ORDER BY pa.puntaje DESC;

-- Q7) GROUP BY + HAVING: jugadores con 2 o más partidas jugadas,
--     con su puntaje total y el mejor.
--     Esperado: solo Ana (2 partidas, total 180, mejor 120).
SELECT j.nombre,
       COUNT(pa.id)    AS partidas,
       SUM(pa.puntaje) AS puntaje_total,
       MAX(pa.puntaje) AS mejor_puntaje
FROM jugador j
JOIN partida pa ON pa.id_jugador = j.id
GROUP BY j.id, j.nombre
HAVING COUNT(pa.id) >= 2;

-- ------------------------------------------------------------
-- 3 CONSULTAS A ELECCIÓN
-- ------------------------------------------------------------

-- Q8) Monstruos derrotados por jugador (vida_restante = 0 significa derrotado).
--     Incluye a los jugadores que todavía no derrotaron ninguno (LEFT JOIN).
--     Esperado: Ana 2, Beto 0, Carla 0.
SELECT j.nombre,
       COUNT(pm.id_monstruo) AS monstruos_derrotados
FROM jugador j
LEFT JOIN partida pa          ON pa.id_jugador = j.id
LEFT JOIN partida_monstruo pm ON pm.id_partida = pa.id AND pm.vida_restante = 0
GROUP BY j.id, j.nombre
ORDER BY monstruos_derrotados DESC, j.nombre;

-- Q9) Tasa de aciertos por jugador (de las preguntas que contestó).
--     Esperado: Ana 3/3 = 100.0 ; Beto 1/3 = 33.3 ; Carla 1/1 = 100.0
SELECT j.nombre,
       COUNT(*)           AS respondidas,
       SUM(r.es_correcta) AS aciertos,
       ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1) AS porcentaje_aciertos
FROM jugador j
JOIN partida          pa ON pa.id_jugador = j.id
JOIN partida_pregunta pp ON pp.id_partida = pa.id
JOIN respuesta        r  ON r.id = pp.id_respuesta_elegida
GROUP BY j.id, j.nombre
ORDER BY porcentaje_aciertos DESC;

-- Q10) Subconsulta con IN: preguntas que algún jugador contestó mal,
--      para revisarlas o reforzar ese tema.
--      Esperado: las preguntas 4 y 5.
SELECT pr.id, pr.enunciado, pr.categoria, pr.dificultad
FROM pregunta pr
WHERE pr.id IN (
        SELECT pp.id_pregunta
        FROM partida_pregunta pp
        JOIN respuesta r ON r.id = pp.id_respuesta_elegida
        WHERE r.es_correcta = 0
      )
ORDER BY pr.dificultad DESC, pr.id;
