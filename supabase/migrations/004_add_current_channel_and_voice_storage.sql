-- Migración 004: Canal sintonizado, almacenamiento de notas de voz y Realtime (SPEC-37)
-- Habilita el seguimiento de canal en tiempo real y la infraestructura de audio para Watch Party ("Miremos Juntos")

-- 1. Agregar columnas de canal sintonizado en la tabla 'devices'
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS current_channel_id TEXT NULL,
ADD COLUMN IF NOT EXISTS current_channel_name TEXT NULL;

-- Índice para consultas y filtros rápidos por canal
CREATE INDEX IF NOT EXISTS idx_devices_current_channel 
ON public.devices(current_channel_id);

-- 2. Bucket de Storage para notas de voz en formato .m4a (AAC)
INSERT INTO storage.buckets (id, name, public)
VALUES ('voice_messages', 'voice_messages', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage para el bucket voice_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir subida de notas de voz'
    ) THEN
        CREATE POLICY "Permitir subida de notas de voz"
        ON storage.objects FOR INSERT TO anon
        WITH CHECK (bucket_id = 'voice_messages');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Permitir descarga de notas de voz'
    ) THEN
        CREATE POLICY "Permitir descarga de notas de voz"
        ON storage.objects FOR SELECT TO anon
        USING (bucket_id = 'voice_messages');
    END IF;
END $$;

-- 3. Tabla para eventos de notas de voz y Supabase Realtime
CREATE TABLE IF NOT EXISTS public.voice_messages (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_device_id TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    channel_id       TEXT NOT NULL,
    channel_name     TEXT NULL,
    audio_url        TEXT NOT NULL,
    duration_ms      INT NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de consulta y rendimiento
CREATE INDEX IF NOT EXISTS idx_voice_messages_channel ON public.voice_messages(channel_id);
CREATE INDEX IF NOT EXISTS idx_voice_messages_sender ON public.voice_messages(sender_device_id);
CREATE INDEX IF NOT EXISTS idx_voice_messages_created_at ON public.voice_messages(created_at);

-- Habilitar Supabase Realtime para recibir nuevos audios al instante
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'voice_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.voice_messages;
    END IF;
END $$;

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.voice_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'voice_messages' AND policyname = 'Permitir lectura de mensajes de voz'
    ) THEN
        CREATE POLICY "Permitir lectura de mensajes de voz" ON public.voice_messages
            FOR SELECT TO anon USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' AND tablename = 'voice_messages' AND policyname = 'Permitir envio de mensajes de voz'
    ) THEN
        CREATE POLICY "Permitir envio de mensajes de voz" ON public.voice_messages
            FOR INSERT TO anon WITH CHECK (true);
    END IF;
END $$;

-- 4. Mantenimiento y limpieza automática:
-- Si pg_cron está activo, actualizar cron de presencia para resetear canal a NULL si el dispositivo cae offline,
-- y purgar mensajes de voz mayores a 2 horas para mantener la base de datos ligera.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Actualizar cron de dispositivos offline para limpiar también canal actual
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_offline_devices') THEN
            PERFORM cron.unschedule('cleanup_offline_devices');
            PERFORM cron.schedule(
                'cleanup_offline_devices',
                '* * * * *',
                'UPDATE public.devices SET online = false, current_channel_id = NULL, current_channel_name = NULL, updated_at = timezone(''utc''::text, now()) WHERE online = true AND last_seen < timezone(''utc''::text, now()) - interval ''2 minutes'''
            );
        END IF;

        -- Limpieza periódica de audios viejos cada 30 minutos
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_old_voice_messages') THEN
            PERFORM cron.unschedule('cleanup_old_voice_messages');
        END IF;
        PERFORM cron.schedule(
            'cleanup_old_voice_messages',
            '*/30 * * * *',
            'DELETE FROM public.voice_messages WHERE created_at < timezone(''utc''::text, now()) - interval ''2 hours'''
        );
    END IF;
END $$;
