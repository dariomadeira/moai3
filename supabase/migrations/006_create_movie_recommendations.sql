-- Migración 006: Recomendaciones de películas entre amigos (SPEC-51)

-- 1. Una fila por persona y película: repetir no duplica.
CREATE TABLE IF NOT EXISTS public.movie_recommendations (
    recommender_device_id TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    content_id            TEXT NOT NULL,
    movie                 JSONB NOT NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (recommender_device_id, content_id),
    CONSTRAINT chk_recommendation_movie_size CHECK (pg_column_size(movie) < 32768)
);

-- 2. La única consulta: las últimas de los amigos.
CREATE INDEX IF NOT EXISTS idx_movie_recommendations_recent
    ON public.movie_recommendations(recommender_device_id, created_at DESC);

-- 3. Row Level Security para rol anónimo (MoAI 3 device-based auth), como
-- device_friends. Sin Realtime: la app consulta al abrir el Inicio.
ALTER TABLE public.movie_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir leer recomendaciones" ON public.movie_recommendations
    FOR SELECT TO anon USING (true);

CREATE POLICY "Permitir recomendar" ON public.movie_recommendations
    FOR INSERT TO anon WITH CHECK (true);

-- Repetir una recomendación la actualiza (upsert).
CREATE POLICY "Permitir renovar recomendaciones" ON public.movie_recommendations
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "Permitir quitar recomendaciones" ON public.movie_recommendations
    FOR DELETE TO anon USING (true);

-- 4. Limpieza diaria: a los 60 días se borran solas.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_movie_recommendations') THEN
        PERFORM cron.unschedule('cleanup_movie_recommendations');
    END IF;
END $$;

SELECT cron.schedule(
    'cleanup_movie_recommendations',
    '30 4 * * *',
    $$DELETE FROM public.movie_recommendations
      WHERE created_at < timezone('utc'::text, now()) - interval '60 days'$$
);
