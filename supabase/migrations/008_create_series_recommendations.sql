-- Migración 008: Recomendaciones de series entre amigos (como la 006 de
-- películas, en una tabla aparte para que las versiones viejas de la app no
-- vean series mezcladas con películas).
--
-- Una fila por persona y serie: content_id es la serie (el contentId de su
-- primera temporada, el mismo en todos los TV). season_number es la última
-- temporada que esa persona votó ("hasta T3"): se recomienda al terminar
-- cada temporada y cada 👍 la actualiza.

-- 1. Una fila por persona y serie: repetir no duplica.
CREATE TABLE IF NOT EXISTS public.series_recommendations (
    recommender_device_id TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    content_id            TEXT NOT NULL,
    series                JSONB NOT NULL,
    season_number         INTEGER,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (recommender_device_id, content_id),
    CONSTRAINT chk_recommendation_series_size CHECK (pg_column_size(series) < 32768)
);

-- 2. La única consulta: las últimas de los amigos.
CREATE INDEX IF NOT EXISTS idx_series_recommendations_recent
    ON public.series_recommendations(recommender_device_id, created_at DESC);

-- 3. Row Level Security para rol anónimo (MoAI 3 device-based auth), como
-- movie_recommendations. Sin Realtime: la app consulta al abrir el Inicio.
ALTER TABLE public.series_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir leer recomendaciones de series" ON public.series_recommendations
    FOR SELECT TO anon USING (true);

CREATE POLICY "Permitir recomendar series" ON public.series_recommendations
    FOR INSERT TO anon WITH CHECK (true);

-- Repetir una recomendación (otra temporada) la actualiza (upsert).
CREATE POLICY "Permitir renovar recomendaciones de series" ON public.series_recommendations
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Permitir quitar recomendaciones de series" ON public.series_recommendations
    FOR DELETE TO anon USING (true);

-- 4. Limpieza diaria: a los 60 días se borran solas.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_series_recommendations') THEN
        PERFORM cron.unschedule('cleanup_series_recommendations');
    END IF;
END $$;

SELECT cron.schedule(
    'cleanup_series_recommendations',
    '35 4 * * *',
    $$DELETE FROM public.series_recommendations
      WHERE created_at < timezone('utc'::text, now()) - interval '60 days'$$
);
