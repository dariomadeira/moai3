# Guía de Actualizaciones de la Aplicación (Opcionales u Obligatorias)

En Moai3, el sistema de actualización OTA (Over-The-Air) consulta automáticamente las versiones publicadas en **GitHub Releases** (o en un servidor JSON personalizado).

---

## 1. Tipos de Actualización

### A) Actualización Opcional (Predeterminada)
- Muestra el diálogo al iniciar la app con las notas de la versión.
- El usuario puede elegir entre **"Actualizar ahora"** o **"Más tarde"**.
- El usuario puede cerrar el diálogo y seguir navegando normalmente en el TV.

### B) Actualización Obligatoria (Forzada / Infranqueable)
- Muestra el título en rojo con la etiqueta **`REQUERIDA`** y la advertencia: *"Esta actualización es necesaria para continuar utilizando la aplicación."*
- Se **elimina** el botón *"Más tarde"*. Solo queda disponible el botón **"Actualizar ahora"**.
- Se deshabilita el botón *Atrás* del control remoto (`PopScope(canPop: false)`). El usuario no puede eludir el diálogo ni navegar a otras secciones hasta actualizar.

---

## 2. Cómo obligar una actualización al publicar en GitHub Releases

Cuando crees o edites una **Release en GitHub**, tenés dos formas de obligar a los usuarios a actualizar:

### Método 1: Agregar la etiqueta `[mandatory]` en la descripción (Recomendado)
Agregá la marca `[mandatory]` (o `[obligatoria]` o `[required]`) en cualquier parte de la descripción (*Release Notes / Body*) de la versión en GitHub.

**Ejemplo de Release Body en GitHub:**
```text
[mandatory]
- Se actualizó el protocolo de streaming.
- Nueva sección de Plugins Generales.
- Correcciones críticas de estabilidad.
```

> 💡 *Nota: El sistema detectará automáticamente la etiqueta `[mandatory]`, forzará la actualización obligatoria y eliminará esa etiqueta para que los usuarios no la vean en las notas del cambio.*

---

### Método 2: Definir una versión mínima (`min_version: X.Y.Z`)
Si querés que la actualización sea obligatoria únicamente para usuarios que estén en versiones muy antiguas (por ejemplo, anteriores a la `3.0.30`):

Agregá `min_version: 3.0.30` en el cuerpo de la Release en GitHub.

**Ejemplo de Release Body en GitHub:**
```text
min_version: 3.0.30

- Novedades de la versión 3.1.0...
```

**Resultado:**
- Si un usuario tiene la versión `3.0.20` (< `3.0.30`), la actualización será **Obligatoria**.
- Si un usuario tiene la versión `3.0.30`, la actualización a la `3.1.0` será **Opcional**.

---

## 3. Formato para Servidor JSON Personalizado (Si no usás GitHub Releases)

Si en el futuro usás un endpoint JSON en tu servidor o Supabase para verificar actualizaciones (`updateEndpoint`), podés enviar los campos directamente en el JSON:

```json
{
  "version": "3.1.0",
  "min_version": "3.0.30",
  "mandatory": true,
  "apkUrl": "https://midominio.com/app-release.apk",
  "changelog": "Actualización crítica de seguridad y plugins."
}
```

---

## Resumen Rápido

| Para publicar una versión... | ¿Qué poner en GitHub Release? |
| :--- | :--- |
| **Opcional** | Publicar normalmente con las notas del cambio. |
| **Obligatoria para todos** | Incluir `[mandatory]` en las notas de la release. |
| **Obligatoria para versiones antiguas** | Incluir `min_version: 3.0.30` en las notas de la release. |
