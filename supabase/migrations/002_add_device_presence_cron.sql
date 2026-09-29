-- Migración 002: Tarea programada de limpieza TTL para presencia de dispositivos (SPEC-22)
-- Marca automáticamente como offline (online = false) a los dispositivos cuyo last_seen exceda 2 minutos.

-- 1. Asegurar extensión pg_cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Desprogramar si ya existía para evitar duplicados
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_offline_devices') THEN
        PERFORM cron.unschedule('cleanup_offline_devices');
    END IF;
END $$;

-- 3. Programar la tarea periódica (cada 1 minuto)
SELECT cron.schedule(
    'cleanup_offline_devices',
    '* * * * *',
    $$UPDATE public.devices 
      SET online = false, updated_at = timezone('utc'::text, now()) 
      WHERE online = true AND last_seen < timezone('utc'::text, now()) - interval '2 minutes'$$
);
