# SPEC-51: Recomendaciones de películas entre amigos

> **Estado**: Aprobada, en implementación (rama `cristal`)  
> **Área**: Features / Películas / Social  
> **Archivos de Referencia**:  
> - `supabase/migrations/006_create_movie_recommendations.sql`  
> - `lib/state/movie_recommendations_provider.dart`  
> - `lib/services/movie_recommendations_api.dart`  
> - `lib/features/home/widgets/home_recommendations_card.dart`  
> - `lib/features/movies/screens/movie_player_screen.dart`, `movie_detail_screen.dart`  

---

## 1. Propósito y alcance

Recomendar películas a los amigos y ver las de ellos en una tarjeta del Inicio.

### Non-Goals
- Notificaciones de recomendaciones nuevas.
- Comentarios o puntajes visibles: 👎 no sale del TV.
- Recomendar series o tráileres.

---

## 2. Amigos

Sólo cuentan los **mutuos** (`WatchPartyProvider.mutualFriends`): se agregaron entre sí. Sin amigos mutuos no hay pregunta, botón ni tarjeta.

## 3. Cómo se recomienda

### 3.1 Al final de la película
- En los últimos 5 minutos, una vez por reproducción, si la película no se respondió antes.
- No aparece en tráileres ni si se llegó a esos minutos saltando.
- Cartel en una esquina, **sin pausar**; se va solo a los 20 s y entonces se puede volver a preguntar otra vez que se vea.
- Mientras se ve: ←/→ eligen, OK confirma, atrás cierra. Arranca en **Cancelar**, para que un OK distraído no recomiende.

| Opción | Efecto |
| :--- | :--- |
| 👍 | Se guarda en Supabase y lo ven los amigos |
| 👎 | Queda en el TV: no se vuelve a preguntar |
| Cancelar | Nada |

### 3.2 En el detalle
Dos botones de ícono al lado de Marcar, 👍 y 👎, con el elegido resaltado (Marcar → 👍 → 👎). Apretar el voto actual lo quita y apretar el otro lo cambia. 👍 publica; dejar 👍 borra la publicación; 👎 no sale del TV.

## 4. Tarjeta del Inicio
- "Recomendadas", 2 lugares, como "Seguir viendo"; sólo si hay alguna y Películas está en el rail.
- La película elegida dice quién la recomendó ("Juan y 2 más").
- OK abre el detalle; mantener OK borra una; el botón borra todas, con confirmación.
- **Borrar es sólo para este TV** y se guarda localmente. No aparecen las películas ya votadas ni las ya vistas enteras.

## 5. Datos y carga

Tabla `movie_recommendations` (migración 006): quién, `content_id`, la película en JSON (para abrir el detalle sin el catálogo) y fecha.

| Punto | Regla |
| :--- | :--- |
| Tiempo real | No se usa, ni sondeo |
| Lectura | Al abrir el Inicio, como máximo cada 2 min salvo que cambien los amigos |
| Volumen | 40 filas, hasta 20 películas |
| Escritura | Una fila por persona y película |
| Limpieza | `pg_cron` diario: 60 días |
| Sin conexión | Publicar y quitar quedan pendientes y se reintentan en la próxima lectura |

Seguridad como `device_friends`: acceso anónimo por dispositivo, lectura abierta.
