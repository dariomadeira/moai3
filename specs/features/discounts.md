# SPEC-43: Descuentos (MODO)

> **Estado**: Vigente (rama `cristal`)  
> **Área**: Experiencia de Usuario / Sección Descuentos + Inicio  
> **Archivos de Referencia**:  
> - `lib/models/discount_models.dart` (`Discount`, `DiscountRubro`, `DiscountBank`, `DiscountMerchant`, `DayDiscounts`, `provinceOf`)  
> - `lib/services/discounts_service.dart`  
> - `lib/features/discounts/discount_format.dart`  
> - `lib/features/discounts/widgets/discount_dialogs.dart` (`TvDiscountBanksDialog`, `TvDiscountMerchantsDialog`, `TvDiscountDetailDialog`, `DiscountTile`)  
> - `lib/features/discounts/widgets/discounts_week_panel.dart`  
> - `lib/widgets/week/tv_week_grid.dart` (`TvWeekDayColumn`, `TvWeekHeaderButton`, `TvWeekStatusChip`: compartidos con la Agenda)  
> - `lib/features/discounts/widgets/discounts_settings_panel.dart`  
> - `lib/features/home/areas/home_discounts_area.dart`  
> - `lib/features/home/widgets/home_discounts_card.dart`  
> - `lib/features/settings/widgets/settings_general_panel.dart` (fila "Bancos y billeteras")  
> - `test/discounts_test.dart`  

---

## 1. Propósito

Que el usuario planifique las compras de la semana: marca qué bancos y billeteras tiene y **dónde compra**, y la app le muestra, **día por día**, el mejor descuento en cada uno de sus comercios. Tiene su propia sección en el rail porque va a crecer: más adelante, **listas de compras** (qué día y dónde conviene comprar cada producto).

### Non-Goals
- Cuenta DNI, Mercado Pago, Ualá: no tienen fuente de datos pública; sólo se cubre lo que se paga con MODO.
- Saber automáticamente qué comercios hay en la localidad: MODO no da ubicación (ver §2.2).
- Listas de compras (próxima etapa). Avisos o recordatorios.

## 2. Fuente de datos

API de la página pública de promociones de MODO (sin login). **No es oficial**: puede cambiar sin aviso; por eso se consulta como mucho una vez por día, se guarda y ante cualquier falla se sigue con lo último guardado.

Base: `https://www.modo.com.ar/promos/api/rewards`. Se envía un `User-Agent` de navegador.

| Pedido | Uso |
|--------|-----|
| `GET /banks?source=app_modo` | Bancos y billeteras. Se usan los de `on_hub_list == "true"` (~32). |
| `GET /v2/filter?slot_ids=web-modo-hub-supermercados&limit=100&page=N&source=web_modo&origin=WEB_MODO` | Supermercados (y mayoristas) (~300, 3 páginas). |
| `GET /v2/search?query=farmacia\|combustible\|mayorista&limit=100&page=N&source=web_modo&origin=WEB_MODO` | Farmacias (~400, 5 páginas), combustible (~40) y mayoristas (~25). |

`limit` máximo 100; se sigue `pagination.total_pages` (tope 10 páginas). Un rubro que falla no tira los demás. En total, unas 10 consultas por día.

### 2.1 Rubro (`DiscountRubro`)
MODO da el rubro como número sin nombre (`offer.categories`: 1 = supermercados, 4/15 = farmacias, 5 = combustible). `Discount.rubroOf` decide por nombre y número: "farmac…" → farmacias; categoría 5 o YPF/Shell/Axion/Puma/"combustible" → combustible; "mayorista", Makro, Diarco, Maxiconsumo, Vital, Yaguar, Blowmax… → mayoristas; categoría 1 → supermercados. De una **búsqueda** sólo quedan las del rubro buscado (descarta "Sorteo del Millón" y similares); del carrusel, lo que no dice otro rubro es supermercado.

Se descartan los **beneficios corporativos** (`benefit.scope == "Beneficios"`, p. ej. "Beneficio Farmacia Mori" al 100%): son sólo para empleados de una empresa.

### 2.2 Ubicación
MODO **no dice dónde vale** cada promo (ni provincia, ni ciudad, ni sucursales; buscar "quines" da 0). Sólo ~4 % de las promos nombra una provincia en el texto ("Supermercados de Mendoza", "Mi San Luis BNA"): `Discount.provinces` (buscadas en `validity_place`, `benefit.name` y la descripción).

- La provincia del usuario sale del **clima** (`WeatherProvider.weather.region` → `provinceOf`, sólo provincias argentinas). `HomeScreen` la pasa a `DiscountsService.province` cada vez que cambia el clima. "Mi localidad" en Configurar abre la ubicación del clima.
- Una promo que nombra **otra** provincia se oculta (`availableIn`); una que nombra **la mía** va teñida del acento y su detalle dice "Promo de San Luis".
- El resto lo da el usuario con **Mis comercios**.

### 2.3 Campos que se leen (`Discount.fromModoCard`)

| Campo de MODO | `Discount` |
|---------------|-----------|
| `card.validity_place` | `merchant` (`merchantKey`: normalizado con `normalizeText`, "COTO" = "Coto") |
| `card.benefit` | `benefit` (texto: "20% de reintegro") |
| `offer.categories` + nombre | `rubro` |
| texto de la promo | `provinces` |
| `offer.outcomes.cashback.amount` (si `amount_type == percent`; si no, el % del texto) | `percent` |
| `offer.outcomes.financing.installments[]` con `type == sin_interes` → mayor `number` | `installments` |
| `offer.limits.period_cap.amount_by_period` / `card.cashback_cap` | `cap` |
| `offer.limits.period_cap.reset_by` (`day`/`week`/`month`) | `capPeriod` |
| `benefit.conditions.schedule.days_of_week` (`monday`…) | `weekdays` (1–7; vacío = todos) |
| `benefit.conditions.schedule.start_date` / `stop_date` | `start` / `stop` (inclusive) |
| `offer.requirements.banks.list` | `bankIds` (vacío = cualquier banco) |
| `card.participating_bank` | `bankLabel` |
| `benefit.conditions.payment_methods.methods[].issuer` | `cardBrands` |
| `benefit.conditions.payment_flow.flows` | `instore` / `online` |

Una tarjeta que no se entiende se descarta sin romper el resto. Las repetidas (mismo `card_id`) se descartan.

**Genéricas** (`isGeneric`): sin comercio puntual ("Comercios adheridos", "Supermercados adheridos", "Combustible", "Farmacias", "Estaciones de servicio"). Valen en cualquier lado: se muestran aunque no estén en Mis comercios y no aparecen en su lista.

## 3. Servicio (`DiscountsService`)

Singleton `ChangeNotifier`.

- `ensureLoaded()`: lee una sola vez las preferencias y el caché; después `refresh()` en segundo plano.
- `refresh({force})`: si lo guardado no es de **hoy** (o con `force`), baja bancos y promos de los 4 rubros. Se arman en otro isolate (`parseModoRubroPages`). Sólo reemplaza lo guardado si llegaron promos.
- Caché: `<app support>/discounts.json` con `version` (3), `fetchedAt`, bancos y promos. Si la versión no coincide se usa igual pero se vuelve a bajar.
- Preferencias:
  - `discount_bank_ids`: bancos y billeteras (`toggleBank`, `clearBanks`).
  - `discount_merchants`: Mis comercios, por `merchantKey` (`toggleMerchant`, `clearMerchants`).
  - `discount_rubros`: rubros que interesan (por defecto, todos; `toggleRubro`).
  - `discount_only_mine`: sólo Mis comercios (por defecto `true`; `setOnlyMine`).
- `merchants`: los comercios no genéricos de los rubros elegidos que pueden valer en mi provincia, por nombre.
- `isVisible(d)`: rubro elegido, vale en mi provincia y, con "sólo Mis comercios" y alguno marcado, es mío o genérico. **Sin comercios marcados se ve todo.**
- `discountsOn(day, {rubro})` / `week(from, {rubro})`: las visibles que valen ese día con mis bancos, `bestPerMerchant` (mejor % primero, empate mayor tope, **una por comercio**). Sin bancos: vacío.

## 4. Interfaz

### 4.1 Sección "Descuentos" del rail (`HomeDiscountsArea`)
Entre Agenda y Arcade (`HomeSection.discounts`, ícono `percentTag`). Acordeón de 2 paneles, como la Agenda.

**Semana** (`DiscountsWeekPanel`):
- **Usa las mismas piezas que la semana de la Agenda** (`tv_week_grid.dart`): se ven y se manejan igual.
- Encabezado: ícono y el rango ("26 Oct - 1 Nov 2026") y 3 botones: **Mis comercios ↔ Todos los comercios**, **rubro** (Todos los rubros → Supermercados → … cicla con OK) y **actualizar**.
- 7 columnas (`TvWeekDayColumn`), de **hoy** a hoy+6 (no lunes a domingo: se planifica hacia adelante). Cada una: "LUN / 26" con el chip de cuántas hay (hoy teñido); debajo, ventana de 4 tarjetas como las de eventos (ícono del rubro + % arriba, comercio abajo; si nombra mi provincia, teñida y con chip) con flechas si hay más. Día sin promos: el pozo con ícono ("Sin descuentos" / "Elegí tus bancos en Configurar").
- Teclas: ←/→ cambian de día (← en hoy sale al rail; → en el último va a Configurar); ↓/↑ recorren el día; ↑ en el primero sube a los botones; OK abre el **detalle** (`TvDiscountDetailDialog`: rubro, banco, tope, tarjetas, cuotas, días, vigencia, local/en línea, "Promo de <provincia>", aviso de confirmar en la app del banco, "Cerrar").

**Configurar** (`DiscountsSettingsPanel`): el mismo armado que **Agenda › Suscripciones** (encabezado, ventana de 6 filas de 70 pegada abajo). Mis bancos y billeteras (cuántos), Mis comercios (cuántos / "Ninguno: se ven todos"), Mi localidad (la del clima, abre `TvWeatherLocationDialog`) y un interruptor por rubro con lo que incluye ("Coto, Carrefour, Día…"). ← vuelve a la semana.

### 4.2 Diálogos de bancos y comercios
`TvDiscountBanksDialog` y `TvDiscountMerchantsDialog` comparten la lista con buscador (`_TvDiscountToggleDialog`): buscador arriba (sin mayúsculas ni acentos), ventana de **3** `TvSettingsSwitchRow` (los comercios con su rubro e ícono), "Desmarcar todo" y "Listo". El indicador son **flechas en su propio lugar** arriba y abajo de la lista (`TvWindowedList` con `showScrollArrows`, `arrowAreaHeight` 22), nunca encima de los ítems, con el mismo chip que la grilla semanal. Sin lista todavía, la pide (`refresh(force: true)`). Bancos también desde **Ajustes › General › Bancos y billeteras**.

### 4.3 Tarjeta "Descuentos" del Inicio (resumen)
- Izquierda: título, ayuda ("Con tus bancos y comercios" / "OK: ver el día") y el botón **"Configurar"**. Derecha: 7 columnas con el mejor %, comercio y "+N más", con los mismos filtros que la sección.
- OK en un día abre la sección **en ese día**; OK en "Configurar" (o sin bancos) la abre en **Configurar** (`HomeDashboardArea.onOpenDiscounts`).

## 5. Próxima etapa: listas de compras
El modelo ya separa promo = comercio + rubro + días + % + tope + bancos. Una lista tendrá productos con rubro o comercio; "qué día y dónde" es cruzarla con `discountsOn`. Va como tercer panel de la sección.

## 6. Criterios de aceptación

- Sin bancos elegidos no hay descuentos y se pide elegirlos.
- Marcar un banco, comercio o rubro actualiza la semana y la tarjeta sin reiniciar.
- Con comercios marcados y "Mis comercios", sólo esos y los genéricos; "Todos los comercios" muestra todo.
- Con la localidad en San Luis, "Supermercados de Mendoza" no aparece.
- Los beneficios corporativos no aparecen.
- La API se consulta como máximo una vez por día; sin internet se ve lo último guardado.
- La sección, la tarjeta y los diálogos no desbordan a 960×540.
- Tests (`test/discounts_test.dart`): lectura de una tarjeta, vigencia y días, tarjeta rota, ida y vuelta JSON, mejor por comercio, formatos, servicio con HTTP falso, rubros (número y nombre, búsqueda que descarta otros), corporativos, provincias, Mis comercios + genéricos + Todos + rubros, la tarjeta en tamaño TV (OK abre ese día) y la semana en tamaño TV (OK abre el detalle).
