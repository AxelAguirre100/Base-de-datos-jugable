import streamlit as st
import mysql.connector
from mysql.connector import Error

# ============================================================
# CONFIGURACIÓN DE CONEXIÓN A MYSQL / MARIADB (XAMPP)
# ============================================================
DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "",          # Cambiar si tu MySQL tiene contraseña
    "database": "dungeon_quiz",
    "charset": "utf8mb4"
}

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

# ============================================================
# FUNCIONES DE ACCESO A DATOS
# ============================================================

def obtener_jugadores():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, nombre, nivel, experiencia FROM jugador ORDER BY nombre")
    filas = cursor.fetchall()
    cursor.close()
    conn.close()
    return filas

def crear_jugador(nombre):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # La restricción UNIQUE en 'nombre' impide duplicados desde la base
        cursor.execute("INSERT INTO jugador (nombre) VALUES (%s)", (nombre.strip(),))
        conn.commit()
        return True, f"Héroe '{nombre}' creado con éxito."
    except Error as err:
        conn.rollback()
        return False, f"Error de base de datos al crear jugador: {err.msg}"
    finally:
        cursor.close()
        conn.close()

def iniciar_nueva_partida(id_jugador, nivel_jugador):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()
        
        # 1. Crear la partida con 100 de vida inicial
        cursor.execute(
            "INSERT INTO partida (vida_actual, id_jugador) VALUES (%s, %s)",
            (100, id_jugador)
        )
        id_partida = cursor.lastrowid

        # 2. Elegir un monstruo aleatorio acorde al nivel (tope dificultad 3)
        dif_buscada = min(nivel_jugador, 3)
        cursor.execute(
            "SELECT id, nombre, dificultad, vida_base FROM monstruo WHERE dificultad <= %s ORDER BY RAND() LIMIT 1",
            (dif_buscada,)
        )
        monstruo = cursor.fetchone()

        # 3. Registrar el encuentro en partida_monstruo
        cursor.execute(
            "INSERT INTO partida_monstruo (id_partida, id_monstruo, vida_restante) VALUES (%s, %s, %s)",
            (id_partida, monstruo["id"], monstruo["vida_base"])
        )

        conn.commit()
        return id_partida, monstruo
    except Error as err:
        conn.rollback()
        st.error(f"Error al iniciar partida (ROLLBACK ejecutado): {err.msg}")
        return None, None
    finally:
        cursor.close()
        conn.close()

def obtener_siguiente_pregunta(id_partida, dificultad_monstruo):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    
    # Pregunta aleatoria según dificultad del monstruo, sin repetir en la misma partida
    query_pregunta = """
        SELECT p.id, p.enunciado, p.categoria, p.dificultad
        FROM pregunta p
        WHERE p.dificultad = %s
          AND p.id NOT IN (
              SELECT id_pregunta FROM partida_pregunta WHERE id_partida = %s
          )
        ORDER BY RAND()
        LIMIT 1
    """
    cursor.execute(query_pregunta, (dificultad_monstruo, id_partida))
    pregunta = cursor.fetchone()

    # Respaldo si se agotaron las preguntas de esa dificultad
    if not pregunta:
        cursor.execute("""
            SELECT p.id, p.enunciado, p.categoria, p.dificultad
            FROM pregunta p
            WHERE p.id NOT IN (
                SELECT id_pregunta FROM partida_pregunta WHERE id_partida = %s
            )
            ORDER BY RAND()
            LIMIT 1
        """, (id_partida,))
        pregunta = cursor.fetchone()

    opciones = []
    if pregunta:
        cursor.execute(
            "SELECT id, texto FROM respuesta WHERE id_pregunta = %s ORDER BY RAND()",
            (pregunta["id"],)
        )
        opciones = cursor.fetchall()

    cursor.close()
    conn.close()
    return pregunta, opciones

def procesar_turno_transaccion(id_partida, id_jugador, id_monstruo, id_pregunta, id_respuesta_elegida):
    """
    REGLA 3 (Transacción atómica):
    Registra la respuesta, verifica acierto y actualiza vida/puntaje/monstruo.
    Si falla alguna restricción de la base, ejecuta ROLLBACK.
    """
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    mensaje_turno = ""
    estado_final = "en_curso"

    try:
        conn.start_transaction()

        # 1. Verificar en la BD si la respuesta elegida es correcta
        cursor.execute(
            "SELECT es_correcta FROM respuesta WHERE id = %s AND id_pregunta = %s",
            (id_respuesta_elegida, id_pregunta)
        )
        resp = cursor.fetchone()
        if resp is None:
            conn.rollback()
            return False, "La respuesta elegida no pertenece a esta pregunta.", "error"
        es_correcta = bool(resp["es_correcta"])

        # 2. Registrar respuesta en partida_pregunta (FK compuesta fk_pp_respuesta valida consistencia)
        cursor.execute(
            "INSERT INTO partida_pregunta (id_partida, id_pregunta, id_respuesta_elegida) VALUES (%s, %s, %s)",
            (id_partida, id_pregunta, id_respuesta_elegida)
        )

        # 3. Obtener estado actual
        cursor.execute("SELECT vida_actual, puntaje FROM partida WHERE id = %s", (id_partida,))
        partida = cursor.fetchone()

        cursor.execute(
            "SELECT vida_restante FROM partida_monstruo WHERE id_partida = %s AND id_monstruo = %s",
            (id_partida, id_monstruo)
        )
        pm = cursor.fetchone()

        if es_correcta:
            dano_al_monstruo = 20
            puntos_ganados = 30
            nueva_vida_monstruo = max(0, pm["vida_restante"] - dano_al_monstruo)
            nuevo_puntaje = partida["puntaje"] + puntos_ganados

            cursor.execute(
                "UPDATE partida_monstruo SET vida_restante = %s WHERE id_partida = %s AND id_monstruo = %s",
                (nueva_vida_monstruo, id_partida, id_monstruo)
            )
            cursor.execute(
                "UPDATE partida SET puntaje = %s WHERE id = %s",
                (nuevo_puntaje, id_partida)
            )
            mensaje_turno = f"¡Acierto! Infligiste {dano_al_monstruo} de daño y ganaste {puntos_ganados} puntos."

            if nueva_vida_monstruo == 0:
                estado_final = "victoria"
                cursor.execute(
                    "UPDATE partida SET resultado = 'victoria' WHERE id = %s",
                    (id_partida,)
                )
                # Subir experiencia (respeta CHECK experiencia BETWEEN 0 AND 99)
                cursor.execute("SELECT nivel, experiencia FROM jugador WHERE id = %s", (id_jugador,))
                jug = cursor.fetchone()
                total_exp = jug["experiencia"] + 50
                nuevo_nivel = jug["nivel"] + (total_exp // 100)
                nueva_exp = total_exp % 100
                cursor.execute(
                    "UPDATE jugador SET nivel = %s, experiencia = %s WHERE id = %s",
                    (nuevo_nivel, nueva_exp, id_jugador)
                )
                mensaje_turno += " ¡Has derrotado al monstruo y ganado la partida (+50 EXP)!"
        else:
            dano_al_heroe = 35
            nueva_vida_heroe = max(0, partida["vida_actual"] - dano_al_heroe)

            cursor.execute(
                "UPDATE partida SET vida_actual = %s WHERE id = %s",
                (nueva_vida_heroe, id_partida)
            )
            mensaje_turno = f"Respuesta incorrecta. El monstruo te quitó {dano_al_heroe} puntos de vida."

            if nueva_vida_heroe == 0:
                estado_final = "derrota"
                cursor.execute(
                    "UPDATE partida SET resultado = 'derrota' WHERE id = %s",
                    (id_partida,)
                )
                mensaje_turno += " Tu vida llegó a 0. ¡Has sido derrotado!"

        conn.commit()
        return True, mensaje_turno, estado_final

    except Error as err:
        conn.rollback()
        return False, f"Transacción revertida (ROLLBACK): {err.msg}", "error"
    finally:
        cursor.close()
        conn.close()

def obtener_estado_combate(id_partida, id_monstruo):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT puntaje, vida_actual, resultado FROM partida WHERE id = %s", (id_partida,))
    p = cursor.fetchone()
    cursor.execute(
        "SELECT vida_restante FROM partida_monstruo WHERE id_partida = %s AND id_monstruo = %s",
        (id_partida, id_monstruo)
    )
    pm = cursor.fetchone()
    cursor.close()
    conn.close()
    return p, pm

def obtener_leaderboard():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    # Consume directamente la vista v_ranking definida en la Parte 5 del script SQL
    cursor.execute("""
        SELECT nombre AS Jugador,
               nivel AS Nivel,
               mejor_puntaje AS `Mejor Puntaje`,
               partidas AS Partidas,
               victorias AS Victorias
        FROM v_ranking
        ORDER BY mejor_puntaje DESC
        LIMIT 5
    """)
    filas = cursor.fetchall()
    cursor.close()
    conn.close()
    return filas

def obtener_rendimiento_categorias():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    # Consulta obligatoria Q2: Rendimiento por categoría
    cursor.execute("""
        SELECT pr.categoria AS Categoria,
               COUNT(*) AS Respondidas,
               SUM(r.es_correcta) AS Aciertos,
               CONCAT(ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1), '%') AS Efectividad
        FROM partida_pregunta pp
        JOIN pregunta pr ON pr.id = pp.id_pregunta
        JOIN respuesta r ON r.id = pp.id_respuesta_elegida
        GROUP BY pr.categoria
        ORDER BY SUM(r.es_correcta) / COUNT(*) DESC
    """)
    filas = cursor.fetchall()
    cursor.close()
    conn.close()
    return filas

# ============================================================
# INTERFAZ DE USUARIO (STREAMLIT)
# ============================================================

st.set_page_config(page_title="Dungeon Quiz - UNNE", page_icon="⚔️", layout="centered")
st.title("⚔️ Dungeon Quiz")
st.caption("TP Integrador · Informática II · UNNE · Proyecto C")

if "partida_id" not in st.session_state:
    st.session_state.partida_id = None
    st.session_state.jugador = None
    st.session_state.monstruo = None
    st.session_state.pregunta_actual = None
    st.session_state.opciones_actuales = []
    st.session_state.ultimo_mensaje = None

tab_juego, tab_ranking = st.tabs(["🏰 Mazmorra (Jugar)", "🏆 Leaderboard y Estadísticas"])

# ------------------------------------------------------------
# PESTAÑA 1: JUEGO
# ------------------------------------------------------------
with tab_juego:
    if st.session_state.partida_id is None:
        st.subheader("1. Selecciona o crea tu héroe")
        if st.session_state.get("mensaje_creacion"):
            st.success(st.session_state.mensaje_creacion)
            st.session_state.mensaje_creacion = None
        col1, col2 = st.columns(2)
        with col1:
            jugadores = obtener_jugadores()
            opciones_jug = {f"{j['nombre']} (Nvl {j['nivel']} - {j['experiencia']} EXP)": j for j in jugadores}
            seleccion = st.selectbox("Héroes registrados:", list(opciones_jug.keys()))
            if st.button("Entrar a la Mazmorra", type="primary", use_container_width=True):
                jug_elegido = opciones_jug[seleccion]
                pid, monstruo = iniciar_nueva_partida(jug_elegido["id"], jug_elegido["nivel"])
                if pid:
                    st.session_state.partida_id = pid
                    st.session_state.jugador = jug_elegido
                    st.session_state.monstruo = monstruo
                    st.session_state.pregunta_actual = None
                    st.session_state.ultimo_mensaje = None
                    st.rerun()

        with col2:
            nuevo_nombre = st.text_input("O registra un nuevo héroe:")
            if st.button("Crear Héroe", use_container_width=True):
                if nuevo_nombre.strip():
                    ok, msg = crear_jugador(nuevo_nombre)
                    if ok:
                        st.session_state.mensaje_creacion = msg
                        st.rerun()
                    else:
                        st.error(msg)
                else:
                    st.warning("Ingresa un nombre válido.")

    else:
        p_estado, pm_estado = obtener_estado_combate(
            st.session_state.partida_id,
            st.session_state.monstruo["id"]
        )

        c1, c2, c3 = st.columns(3)
        c1.metric("🧙 Héroe", st.session_state.jugador["nombre"], f"Vida: {p_estado['vida_actual']} HP")
        c2.metric("👹 Enemigo", st.session_state.monstruo["nombre"], f"Vida: {pm_estado['vida_restante']} / {st.session_state.monstruo['vida_base']}")
        c3.metric("⭐ Puntaje", p_estado["puntaje"], f"Dificultad: {st.session_state.monstruo['dificultad']}")

        st.divider()

        if st.session_state.ultimo_mensaje:
            st.info(st.session_state.ultimo_mensaje)

        if p_estado["resultado"] in ("victoria", "derrota"):
            if p_estado["resultado"] == "victoria":
                st.success(f"🎉 ¡VICTORIA! Puntaje final guardado en la base: {p_estado['puntaje']} pts.")
            else:
                st.error(f"💀 DERROTA. Puntaje final guardado en la base: {p_estado['puntaje']} pts.")
            
            if st.button("Volver al menú principal", type="primary"):
                st.session_state.partida_id = None
                st.session_state.pregunta_actual = None
                st.rerun()
        else:
            if st.session_state.pregunta_actual is None:
                preg, ops = obtener_siguiente_pregunta(
                    st.session_state.partida_id,
                    st.session_state.monstruo["dificultad"]
                )
                st.session_state.pregunta_actual = preg
                st.session_state.opciones_actuales = ops

            preg = st.session_state.pregunta_actual
            ops = st.session_state.opciones_actuales

            if not preg:
                st.warning("No quedan más preguntas disponibles en el banco para esta partida.")
                if st.button("Finalizar partida"):
                    st.session_state.partida_id = None
                    st.rerun()
            else:
                st.markdown(f"**Categoría:** `{preg['categoria']}` | **Dificultad:** `{preg['dificultad']}`")
                st.subheader(preg["enunciado"])

                with st.form("form_respuesta"):
                    mapa_opciones = {op["texto"]: op["id"] for op in ops}
                    eleccion_texto = st.radio("Elige tu respuesta:", list(mapa_opciones.keys()))
                    enviado = st.form_submit_button("Atacar con respuesta", type="primary")

                    if enviado:
                        id_resp = mapa_opciones[eleccion_texto]
                        ok, msg, estado = procesar_turno_transaccion(
                            st.session_state.partida_id,
                            st.session_state.jugador["id"],
                            st.session_state.monstruo["id"],
                            preg["id"],
                            id_resp
                        )
                        st.session_state.ultimo_mensaje = msg
                        st.session_state.pregunta_actual = None
                        st.rerun()

# ------------------------------------------------------------
# PESTAÑA 2: LEADERBOARD Y ESTADÍSTICAS
# ------------------------------------------------------------
with tab_ranking:
    st.subheader("🏆 Top 5 Mejores Puntajes (Vista v_ranking)")
    st.dataframe(obtener_leaderboard(), use_container_width=True, hide_index=True)

    st.subheader("📊 Rendimiento Global por Categoría")
    st.dataframe(obtener_rendimiento_categorias(), use_container_width=True, hide_index=True)