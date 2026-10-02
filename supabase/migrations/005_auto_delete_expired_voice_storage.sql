-- Migración 005: Eliminación automática de audios físicos en Supabase Storage (SPEC-37)
-- Garantiza que al expirar o borrarse un registro de 'voice_messages', su archivo .m4a en 'storage.objects'
-- sea eliminado de inmediato, evitando consumo acumulativo de almacenamiento.

-- 1. Función para eliminar el archivo físico en storage.objects al borrar una fila de voice_messages
CREATE OR REPLACE FUNCTION public.delete_storage_voice_audio()
RETURNS TRIGGER AS $$
DECLARE
    v_object_path TEXT;
BEGIN
    -- Extraer la ruta relativa del archivo en el bucket voice_messages
    -- La URL tiene formato: .../voice_messages/audios/<device_id>/<file_name>.m4a
    v_object_path := substring(regexp_replace(OLD.audio_url, '\?.*$', '') from '/voice_messages/(.*)$');
    
    IF v_object_path IS NOT NULL AND v_object_path <> '' THEN
        DELETE FROM storage.objects
        WHERE bucket_id = 'voice_messages' AND name = v_object_path;
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger para invocar la eliminación en Storage cada vez que se borra un mensaje de voz
DROP TRIGGER IF EXISTS trg_delete_voice_audio_on_message_delete ON public.voice_messages;
CREATE TRIGGER trg_delete_voice_audio_on_message_delete
    AFTER DELETE ON public.voice_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.delete_storage_voice_audio();

-- 3. Procedimiento integral de limpieza periódica (mensajes + audios huérfanos)
CREATE OR REPLACE FUNCTION public.cleanup_expired_voice_data()
RETURNS void AS $$
BEGIN
    -- a) Borrar mensajes de voz mayores a 2 horas (el trigger borra automáticamente el archivo en storage.objects)
    DELETE FROM public.voice_messages 
    WHERE created_at < timezone('utc'::text, now()) - interval '2 hours';

    -- b) Limpieza de seguridad: borrar archivos en storage.objects que tengan más de 2 horas
    -- (en caso de fallas de red donde el audio se subió pero nunca se insertó el registro en la tabla)
    DELETE FROM storage.objects 
    WHERE bucket_id = 'voice_messages' 
      AND created_at < timezone('utc'::text, now()) - interval '2 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Actualizar el cron job de pg_cron si está disponible
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_old_voice_messages') THEN
            PERFORM cron.unschedule('cleanup_old_voice_messages');
        END IF;

        PERFORM cron.schedule(
            'cleanup_old_voice_messages',
            '*/30 * * * *',
            'SELECT public.cleanup_expired_voice_data()'
        );
    END IF;
END $$;
