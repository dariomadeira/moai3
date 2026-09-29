-- Migración 003: Tabla device_friends, índices y políticas RLS para MoAI 3 (SPEC-35)

-- 1. Crear tabla de relaciones de amistad
CREATE TABLE IF NOT EXISTS public.device_friends (
    device_id         TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    friend_device_id  TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (device_id, friend_device_id),
    CONSTRAINT chk_no_self_friend CHECK (device_id <> friend_device_id)
);

-- 2. Índices de rendimiento
CREATE INDEX IF NOT EXISTS idx_device_friends_device ON public.device_friends(device_id);
CREATE INDEX IF NOT EXISTS idx_device_friends_friend ON public.device_friends(friend_device_id);

-- 3. Habilitar Supabase Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.device_friends;

-- 4. Habilitar Row Level Security (RLS) para rol anónimo (MoAI 3 device-based auth)
ALTER TABLE public.device_friends ENABLE ROW LEVEL SECURITY;

-- Política SELECT: Permitir consultar amistades
CREATE POLICY "Permitir lectura de amigos" ON public.device_friends
    FOR SELECT TO anon USING (true);

-- Política INSERT: Permitir registrar una nueva relación de amistad
CREATE POLICY "Permitir agregar amigos" ON public.device_friends
    FOR INSERT TO anon WITH CHECK (true);

-- Política DELETE: Permitir eliminar una relación de amistad
CREATE POLICY "Permitir eliminar amigos" ON public.device_friends
    FOR DELETE TO anon USING (true);
