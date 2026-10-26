# SPEC-43: Descuentos en supermercados (MODO)

> **Estado**: Vigente (rama `cristal`)  
> **Área**: Experiencia de Usuario / Inicio + Ajustes  
> **Archivos de Referencia**:  
> - `lib/models/discount_models.dart` (`Discount`, `DiscountBank`, `DayDiscounts`)  
> - `lib/services/discounts_service.dart`  
> - `lib/features/discounts/discount_format.dart`  
> - `lib/features/discounts/widgets/discount_dialogs.dart` (`TvDiscountBanksDialog`, `TvDiscountsDayDialog`)  
> - `lib/features/home/widgets/home_discounts_card.dart`  
> - `lib/features/settings/widgets/settings_general_panel.dart` (fila "Bancos para descuentos")  
> - `test/discounts_test.dart`  

---

## 1. Propósito

Que el usuario planifique las compras de la semana: marca qué bancos y billeteras tiene y el Inicio le muestra, **día por día**, en qué supermercado tiene el mejor descuento.

### Non-Goals
- Cuenta DNI y Mercado Pago: no se encontró una fuente de datos pública.
- Rubros distintos de supermercados (la API los tiene; se pueden sumar cambiando el slot).
- Avisos o recordatorios.

## 2. Fuente de datos

API de la página pública de promociones de MODO (sin login). **No es oficial**: puede cambiar sin aviso; por eso se consulta poco, se guarda y ante cualquier falla se sigue con lo último guardado.

Base: `https://www.modo.com.ar/promos/api/rewards`

| Pedido | Uso |
|--------|-----|
| `GET /banks?source=app_modo` | Bancos y billeteras. Se usan los de `on_hub_list == "true"` (~32). |
| `GET /v2/filter?slot_ids=web-modo-hub-supermercados&limit=100&page=N&source=web_modo&origin=WEB_MODO` | Promos de supermercados (~297, 3 páginas de ~250 KB). `limit` máximo 100; se sigue `pagination.total_pages` (tope 10 páginas). |

Se envía un `User-Agent` de navegador.

### Campos que se leen (`Discount.fromModoCard`)

| Campo de MODO | `Discount` |
|---------------|-----------|
| `card.validity_place` | `merchant` |
| `card.benefit` | `benefit` (texto: "20% de reintegro") |
| `offer.outcomes.cashback.amount` (si `amount_type == percent`; si no, el % del texto) | `percent` |
| `offer.outcomes.financing.installments[]` con `type == sin_interes` → mayor `number` | `installments` |
| `offer.limits.period_cap.amount_by_period` / `card.cashback_cap` | `cap` |
| `offer.limits.period_cap.reset_by` (`day`/`week`/`month`) | `capPeriod` |
| `benefit.conditions.schedule.days_of_week` (`monday`…) | `weekdays` (1–7; vacío = todos) |
| `benefit.conditions.schedule.start_date` / `stop_date` | `start` / `stop` (inclusive) |
| `offer.requirements.banks.list` | `bankIds` (vacío = cualquier banco) |
| `card.participating_bank` | `bankLabel` |
| `benefit.conditions.payment_methods.methods[].issuer` | `cardBrands` ("Mastercard", "American Express", "Patagonia 365"…) |
| `benefit.conditions.payment_flow.flows` | `instore` / `online` |

Una tarjeta que no se entiende se descarta (`null`) sin romper el resto. Las repetidas (mismo `card_id`) se descartan.

## 3. Servicio (`DiscountsService`)

Singleton `ChangeNotifier`.

- `ensureLoaded()`: lee una sola vez los bancos elegidos (preferencias) y el caché; después llama a `refresh()` en segundo plano.
- `refresh({force})`: si lo guardado no es de **hoy** (o con `force`), baja bancos y promos. Las promos se arman en otro isolate (`Isolate.run(parseModoPages)`). Sólo reemplaza lo guardado si llegaron promos.
- Caché: `<app support>/discounts.json` con `fetchedAt`, bancos y promos compactas. Se lee y escribe en otro isolate.
- Bancos elegidos: preferencia `discount_bank_ids` (lista de ids de MODO). `toggleBank(id)`.
- `week(from)`: 7 `DayDiscounts` desde hoy.
- `bestPerMerchant(all, day, banks)`: las promos que valen ese día (vigencia + día de la semana) con alguno de los bancos elegidos, ordenadas por porcentaje (empate: mayor tope; sin tope gana), **una por comercio**. Sin bancos elegidos: lista vacía.

## 4. Interfaz

### 4.1 Tarjeta "Descuentos" del Inicio
- Izquierda: ícono (`MoaiIcons.discounts`), título, una línea de ayuda y el botón **"Mis bancos"**.
- Derecha: 7 columnas (Hoy, Mañana, MIÉ 28…): mejor %, comercio y "+N más".
- Sin bancos elegidos: "Elegí tus bancos y billeteras" y un mensaje explicativo; OK abre la lista de bancos.
- Teclas: ←/→ recorren el botón y los días (← desde el botón sale al rail); OK en el botón abre los bancos, OK en un día abre el detalle; ↑/↓ cambian de tarjeta.

### 4.2 "Mis bancos y billeteras" (`TvDiscountBanksDialog`)
Lista con ventana de 4 (`TvWindowedList`) de `TvSettingsSwitchRow`, uno por banco, ordenados por nombre; botón "Listo". Si todavía no hay lista, la pide (`refresh(force: true)`) y muestra "Buscando descuentos…" o el error. También se abre desde **Ajustes › General › Bancos para descuentos**.

### 4.3 Detalle del día (`TvDiscountsDayDialog`)
"Descuentos · Hoy": todas las promos del día, una fila por comercio con %, banco, tope ("Tope $25.000 por mes" / "Sin tope"), tarjetas (5 o más marcas → "Cualquier tarjeta") y cuotas sin interés. Aclara que hay que confirmar las condiciones en la app del banco.

## 5. Criterios de aceptación

- Sin bancos elegidos la tarjeta no muestra descuentos y pide elegirlos.
- Al marcar un banco la semana se actualiza sin reiniciar.
- La API se consulta como máximo una vez por día; sin internet se ve lo último guardado.
- La tarjeta y los diálogos no desbordan a 960×540.
- Tests (`test/discounts_test.dart`): lectura de una tarjeta real recortada, vigencia y días, tarjeta rota, ida y vuelta JSON, mejor por comercio con filtro de bancos, formatos de dinero, servicio con HTTP falso (descarga, caché, no repite el mismo día) y la tarjeta en tamaño TV (sin bancos / con bancos + OK abre el día).
