-- Migración 007: last_seen con la hora del servidor (SPEC-22)
-- Un aparato con el reloj mal no debe quedar offline por la limpieza de la 002.

CREATE OR REPLACE FUNCTION public.set_device_last_seen()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.last_seen IS NOT NULL THEN
            NEW.last_seen := timezone('utc'::text, now());
        END IF;
    ELSIF NEW.last_seen IS DISTINCT FROM OLD.last_seen THEN
        NEW.last_seen := timezone('utc'::text, now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_set_device_last_seen ON public.devices;
CREATE TRIGGER tr_set_device_last_seen
    BEFORE INSERT OR UPDATE ON public.devices
    FOR EACH ROW
    EXECUTE FUNCTION public.set_device_last_seen();
