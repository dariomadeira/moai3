# SPEC-01: Guía Operativa del Modelo SSD (Spec-Driven Development)

> **Estado**: Activo  
> **Área**: Metodología de Desarrollo y Gobernanza de Código

---

## 1. ¿Qué es el Modelo SSD en MoAI 3?

El modelo **SSD (Spec-Driven Development)** establece que la **especificación formal es la única fuente de verdad** del comportamiento del sistema. Todo cambio en el comportamiento, arquitectura, contratos o experiencia de usuario debe documentarse y acordarse en una especificación **antes** de modificar o escribir código.

```text
[Requerimiento / Bug / Mejora]
             │
             ▼
    [1. Escribir / Modificar Spec] ──(Revisión / Validación)──┐
             │                                                │
             ▼                                                │ Aprobado
    [2. Implementar Código contra Spec]                        │
             │                                                │
             ▼                                                │
    [3. Verificación con Matriz de Aceptación] <──────────────┘
             │
             ▼
    [4. Commit / Release con referencia a SPEC-XX]
```

---

## 2. Convención de Nomenclatura y Estructura

Las especificaciones se almacenan de forma canónica en el directorio `specs/`:

| Directorio | Propósito | Ejemplo |
| :--- | :--- | :--- |
| `specs/` | Documentos de arquitectura y guías globales | `00_architecture_overview.md` |
| `specs/contracts/` | Contratos binarios e interfaces de plataforma | `plugin_contract_v1.md`, `method_channels.md` |
| `specs/domain/` | Modelos de entidades, esquemas y lógica de negocio | `channels_and_categories.md` |
| `specs/features/` | Funcionalidades de usuario, flujos y pantallas TV | `tv_navigation_and_focus.md`, `player_engine.md` |
| `specs/verification/` | Matrices de pruebas y criterios de aceptación (Gherkin) | `baseline_acceptance_matrix.md` |

---

## 3. Estructura Obligatoria de un Documento Spec

Todo nuevo archivo dentro de `specs/` debe contener como mínimo:

1. **Cabecera de Metadatos**:
   - `SPEC-ID` y Título descriptivo.
   - `Estado`: Borrador / En Revisión / Aprobado / Congelado / Obsoleto.
   - `Versión de destino` (ej. v3.0.12).
2. **Propósito y Alcance**:
   - Qué problema resuelve.
   - Qué queda estrictamente **fuera de alcance** (Non-Goals).
3. **Definición de Tipos / Contratos**:
   - Modelos Dart, interfaces Kotlin, campos de mapas y valores por defecto.
4. **Comportamiento y Reglas de Negocio**:
   - Máquinas de estado, condiciones de fallo, reintentos, fallbacks.
5. **Criterios de Aceptación (Gherkin o Given-When-Then)**:
   - Casos de prueba verificables que demuestran el cumplimiento del spec.

---

## 4. Reglas Inquebrantables de MoAI 3

1. **Inmutabilidad del Contrato de Plugins**:
   - `CURRENT_CONTRACT = 1` en `PluginContract.kt` no puede modificarse rompiendo compatibilidad hacia atrás.
   - Cualquier cambio estructural en firmas de `IPlugin` requiere incrementar `CURRENT_CONTRACT` a `2` y mantener soporte para versiones anteriores si la política lo exige.
2. **Compatibilidad con D-Pad de TV**:
   - Ningún widget o pantalla interactiva puede agregarse sin definir explícitamente su navegación por teclado direccional (`FocusNode`, `TvKeyHandler` o `FocusScrollSync`).
3. **Fallbacks de Datos Obligatorios**:
   - Ninguna cadena de categoría o país en un canal puede ser nula o quedar en blanco en la UI; debe sanitizarse a `'General'`.
