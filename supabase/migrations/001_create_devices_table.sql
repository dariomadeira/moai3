-- Migración 001: Tabla devices, índices, triggers y RLS para MoAI 3 (SPEC-22)

-- 1. Tabla principal de dispositivos
CREATE TABLE IF NOT EXISTS public.devices (
    device_id       TEXT PRIMARY KEY,                             -- UUID v4 único del dispositivo
    user_code       VARCHAR(10) UNIQUE,                           -- Código corto (ej. "MOAI-7421")
    nickname        VARCHAR(50),                                  -- Nombre de usuario (opcional)
    app_version     VARCHAR(20),                                  -- Versión de MoAI instalada
    is_active       BOOLEAN NOT NULL DEFAULT true,                -- false = bloqueado por admin
    block_reason    TEXT,                                         -- Motivo del bloqueo
    online          BOOLEAN NOT NULL DEFAULT false,               -- true = app abierta actualmente
    last_seen       TIMESTAMPTZ,                                  -- Última conexión
    first_seen      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 2. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_devices_online ON public.devices(online);
CREATE INDEX IF NOT EXISTS idx_devices_is_active ON public.devices(is_active);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON public.devices(last_seen);

-- 3. Función y trigger para generar automáticamente user_code ('MOAI-XXXX') al insertar si viene nulo
CREATE OR REPLACE FUNCTION public.generate_device_user_code()
RETURNS TRIGGER AS $$
DECLARE
    new_code VARCHAR(10);
    chars CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    i INT;
    candidate_exists BOOLEAN;
BEGIN
    IF NEW.user_code IS NULL OR NEW.user_code = '' THEN
        LOOP
            new_code := 'MOAI-';
            FOR i IN 1..4 LOOP
                new_code := new_code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
            END LOOP;
            
            SELECT EXISTS (SELECT 1 FROM public.devices WHERE user_code = new_code) INTO candidate_exists;
            IF NOT candidate_exists THEN
                NEW.user_code := new_code;
                EXIT;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_generate_device_user_code ON public.devices;
CREATE TRIGGER tr_generate_device_user_code
    BEFORE INSERT ON public.devices
    FOR EACH ROW
    EXECUTE FUNCTION public.generate_device_user_code();

-- 4. Seguridad de Negocio (RB-10 / Non-Goals):
-- Evitar que una app con clave 'anon' pueda desbloquearse a sí misma o alterar block_reason.
-- Solo un administrador (service_role o dashboard) puede modificar is_active y block_reason.
CREATE OR REPLACE FUNCTION public.protect_device_status()
RETURNS TRIGGER AS $$
BEGIN
    IF current_user = 'anon' THEN
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            NEW.is_active := OLD.is_active; -- Ignorar intento de reactivación desde la app
        END IF;
        IF NEW.block_reason IS DISTINCT FROM OLD.block_reason THEN
            NEW.block_reason := OLD.block_reason;
        END IF;
    END IF;
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_protect_device_status ON public.devices;
CREATE TRIGGER tr_protect_device_status
    BEFORE UPDATE ON public.devices
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_device_status();

-- 5. Habilitar Row Level Security (RLS)
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Política SELECT: Permitir lectura de registros
CREATE POLICY "Permitir lectura de dispositivos"
    ON public.devices FOR SELECT
    TO anon
    USING (true);

-- Política INSERT: Permitir auto-registro de nuevos dispositivos
CREATE POLICY "Permitir registro de nuevos dispositivos"
    ON public.devices FOR INSERT
    TO anon
    WITH CHECK (true);

-- Política UPDATE: Permitir actualización de presencia
CREATE POLICY "Permitir actualización de presencia"
    ON public.devices FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

-- 6. Habilitar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.devices;
