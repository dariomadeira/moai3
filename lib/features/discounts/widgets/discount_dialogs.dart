import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';

/// "Mis bancos y billeteras": cuáles tiene el usuario, para mostrarle sólo
/// los descuentos que puede usar. Cada fila se prende y apaga con OK.
abstract final class TvDiscountBanksDialog {
  static Future<void> show(BuildContext context) => showTvGeneralDialog<void>(
    context: context,
    barrierLabel: 'DiscountBanks',
    builder: (_) => _TvDiscountToggleDialog(
      icon: MoaiIcons.discountBanks,
      title: LocaleKeys.discounts_banks_title.tr(),
      subtitle: LocaleKeys.discounts_banks_desc.tr(),
      searchLabel: LocaleKeys.discounts_banks_search.tr(),
      noResults: LocaleKeys.discounts_banks_no_results.tr(),
      unavailable: LocaleKeys.discounts_banks_unavailable.tr(),
      items: (s) => [
        for (final b in s.banks)
          _ToggleItem(id: b.id, label: b.name, icon: MoaiIcons.discountBanks),
      ],
      selected: (s) => s.selectedBankIds,
      toggle: (s, id) => s.toggleBank(id),
      clear: (s) => s.clearBanks(),
    ),
  );
}

/// "Mis comercios": dónde compra el usuario, de los que tienen promos.
/// Con alguno marcado, la semana muestra sólo esos (y las promos sin
/// comercio puntual, como "Comercios adheridos").
abstract final class TvDiscountMerchantsDialog {
  static Future<void> show(BuildContext context) => showTvGeneralDialog<void>(
    context: context,
    barrierLabel: 'DiscountMerchants',
    builder: (_) => _TvDiscountToggleDialog(
      icon: MoaiIcons.discountMerchants,
      title: LocaleKeys.discounts_merchants_title.tr(),
      subtitle: LocaleKeys.discounts_merchants_desc.tr(),
      searchLabel: LocaleKeys.discounts_merchants_search.tr(),
      noResults: LocaleKeys.discounts_merchants_no_results.tr(),
      unavailable: LocaleKeys.discounts_merchants_unavailable.tr(),
      items: (s) => [
        for (final m in s.merchants)
          _ToggleItem(
            id: m.key,
            label: m.name,
            description: DiscountFormat.rubro(m.rubro),
            icon: DiscountFormat.rubroIcon(m.rubro),
          ),
      ],
      selected: (s) => s.selectedMerchantKeys,
      toggle: (s, id) => s.toggleMerchant(id),
      clear: (s) => s.clearMerchants(),
    ),
  );
}

class _ToggleItem {
  const _ToggleItem({
    required this.id,
    required this.label,
    required this.icon,
    this.description,
  });

  final String id;
  final String label;
  final String? description;
  final IconData icon;
}

/// Lista para marcar y desmarcar (bancos, comercios) con buscador arriba y
/// "Desmarcar todo" / "Listo" abajo.
class _TvDiscountToggleDialog extends StatefulWidget {
  const _TvDiscountToggleDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.searchLabel,
    required this.noResults,
    required this.unavailable,
    required this.items,
    required this.selected,
    required this.toggle,
    required this.clear,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String searchLabel;
  final String noResults;

  /// Sin nada para elegir (no se pudo bajar).
  final String unavailable;
  final List<_ToggleItem> Function(DiscountsService) items;
  final Set<String> Function(DiscountsService) selected;
  final Future<void> Function(DiscountsService, String id) toggle;
  final Future<void> Function(DiscountsService) clear;

  @override
  State<_TvDiscountToggleDialog> createState() =>
      _TvDiscountToggleDialogState();
}

class _TvDiscountToggleDialogState extends State<_TvDiscountToggleDialog> {
  final _search = FocusNode(debugLabel: 'discount_toggle_search');
  final _clear = FocusNode(debugLabel: 'discount_toggle_clear');
  final _done = FocusNode(debugLabel: 'discount_toggle_done');
  final _searchController = TextEditingController();
  final _listKey = GlobalKey<TvWindowedListState<_ToggleItem>>();
  static const _itemExtent = 70.0;
  // Listas largas (bancos, comercios): 3 a la vista y flechas en su propio
  // lugar arriba y abajo.
  static const _window = 3;

  String _query = '';

  @override
  void initState() {
    super.initState();
    final service = DiscountsService.instance;
    service.ensureLoaded();
    // Sin lista todavía (primera vez o sin internet antes): pedirla.
    if (widget.items(service).isEmpty) service.refresh(force: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _clear.dispose();
    _done.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_ToggleItem> _filter(List<_ToggleItem> items) {
    final q = normalizeText(_query);
    if (q.isEmpty) return items;
    return [
      for (final i in items)
        if (normalizeText(i.label).contains(q)) i,
    ];
  }

  /// ↑ desde los botones: al último de la lista, o al buscador si no hay.
  void _upFromActions(int count) {
    if (count > 0) {
      _listKey.currentState?.ensureVisible(count - 1);
    } else {
      _search.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = DiscountsService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final all = widget.items(service);
        final items = _filter(all);
        final selected = widget.selected(service);
        if (all.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_done.hasFocus) _done.requestFocus();
          });
        }
        final emptyText = all.isEmpty
            ? (service.isLoading
                  ? LocaleKeys.discounts_loading.tr()
                  : widget.unavailable)
            : widget.noResults;
        return TvDialog(
          width: 520,
          icon: widget.icon,
          title: widget.title,
          subtitle: widget.subtitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (all.isNotEmpty) ...[
                TvTextField(
                  controller: _searchController,
                  focusNode: _search,
                  label: widget.searchLabel,
                  hint: LocaleKeys.search_field_hint.tr(),
                  textInputAction: TvTextInputAction.search,
                  dense: true,
                  leadingIcon: MoaiIcons.keyboard,
                  onChanged: (q) => setState(() => _query = q),
                  onSubmitted: (q) => setState(() => _query = q),
                  onFocusDown: () => items.isNotEmpty
                      ? _listKey.currentState?.ensureVisible(0)
                      : _clear.requestFocus(),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height:
                    _window * _itemExtent + 2 * TvWindowedList.arrowAreaHeight,
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: MoaiText.body(
                            context,
                            color: context.scheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : TvWindowedList<_ToggleItem>(
                        key: _listKey,
                        items: items,
                        windowSize: _window,
                        itemExtent: _itemExtent,
                        showScrollArrows: true,
                        onFocusUpFromFirst: _search.requestFocus,
                        onFocusDownFromLast: _done.requestFocus,
                        itemBuilder:
                            (
                              context,
                              item,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                            ) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: TvSettingsSwitchRow(
                                focusNode: focusNode,
                                icon: item.icon,
                                label: item.label,
                                description: item.description,
                                value: selected.contains(item.id),
                                onChanged: (_) =>
                                    widget.toggle(service, item.id),
                                onKeyLeft: () {},
                                onKeyUp: onKeyUp,
                                onKeyDown: onKeyDown,
                              ),
                            ),
                      ),
              ),
            ],
          ),
          actions: [
            if (all.isNotEmpty)
              TvDialogButton(
                label: LocaleKeys.discounts_banks_clear.tr(),
                focusNode: _clear,
                onPressed: () => widget.clear(service),
                onKeyRight: _done.requestFocus,
                onKeyUp: () => _upFromActions(items.length),
              ),
            TvDialogButton(
              label: LocaleKeys.discounts_done.tr(),
              variant: TvDialogButtonVariant.primary,
              focusNode: _done,
              autofocus: all.isEmpty,
              onPressed: () => Navigator.of(context).pop(),
              onKeyLeft: all.isNotEmpty ? _clear.requestFocus : null,
              onKeyUp: all.isNotEmpty
                  ? () => _upFromActions(items.length)
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Un descuento con todas sus condiciones: cuánto, dónde, con qué banco y
/// tarjetas, qué días y hasta cuándo.
class TvDiscountDetailDialog extends StatefulWidget {
  const TvDiscountDetailDialog({super.key, required this.discount});

  final Discount discount;

  static Future<void> show(BuildContext context, Discount discount) =>
      showTvGeneralDialog<void>(
        context: context,
        barrierLabel: 'DiscountDetail',
        builder: (_) => TvDiscountDetailDialog(discount: discount),
      );

  @override
  State<TvDiscountDetailDialog> createState() => _TvDiscountDetailDialogState();
}

class _TvDiscountDetailDialogState extends State<TvDiscountDetailDialog> {
  final _close = FocusNode(debugLabel: 'discount_detail_close');

  @override
  void dispose() {
    _close.dispose();
    super.dispose();
  }

  /// Un dato: ícono en el acento en una etiqueta de cristal, el nombre en gris y
  /// el valor en negro (como el detalle de un evento de la Agenda).
  Widget _detail(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = context.scheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: moaiGlassTagDecoration(scheme, radius: 12),
          child: Icon(
            icon,
            size: MoaiIconSizes.md,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Los 7 días de la semana: los que vale encendidos en el color del
  /// rubro, los demás de cristal apagado.
  Widget _weekdays(BuildContext context, Discount d, Color color) {
    final scheme = context.scheme;
    final all = d.weekdays.isEmpty || d.weekdays.length == 7;
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 6),
          Expanded(
            child: Builder(
              builder: (context) {
                final on = all || d.weekdays.contains(day);
                return Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: on
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(color, Colors.white, 0.18)!,
                              color,
                            ],
                          ),
                        )
                      : moaiGlassTagDecoration(scheme, radius: 10),
                  child: Text(
                    MoaiFormats.weekdayShort(day),
                    style: MoaiText.body(
                      context,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: on
                          ? Colors.white
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.discount;
    final scheme = context.scheme;
    final province = DiscountsService.instance.province;
    final color = DiscountFormat.rubroColor(d.rubro);
    final hasPercent = d.percent != null;

    // Etiquetas sólidas (como los géneros de película): el rubro en su
    // color; dónde se paga en el acento; la provincia, si la promo la nombra.
    final accent = Theme.of(context).colorScheme.primary;
    final tags = <(String, Color)>[
      (DiscountFormat.rubro(d.rubro), color),
      if (d.instore) (LocaleKeys.discounts_instore.tr(), accent),
      if (d.online) (LocaleKeys.discounts_online.tr(), accent),
      if (d.mentions(province))
        (
          LocaleKeys.discounts_in_your_province.tr(
            namedArgs: {'province': province!},
          ),
          MoaiStatusTag.soonColor,
        ),
    ];

    final details = <(IconData, String, String)>[
      if (d.bankLabel.isNotEmpty)
        (
          MoaiIcons.discountBanks,
          LocaleKeys.discounts_detail_bank.tr(),
          d.bankLabel,
        ),
      (
        MoaiIcons.discounts,
        LocaleKeys.discounts_detail_cap.tr(),
        DiscountFormat.cap(d),
      ),
      if (DiscountFormat.cards(d).isNotEmpty)
        (
          MoaiIcons.discountBanks,
          LocaleKeys.discounts_detail_cards.tr(),
          DiscountFormat.cards(d),
        ),
      if (d.installments > 0)
        (
          MoaiIcons.discounts,
          LocaleKeys.discounts_detail_installments.tr(),
          LocaleKeys.discounts_installments.tr(
            namedArgs: {'n': '${d.installments}'},
          ),
        ),
      if (DiscountFormat.validity(d).isNotEmpty)
        (
          MoaiIcons.calendarEvents,
          LocaleKeys.discounts_detail_validity.tr(),
          DiscountFormat.validity(d),
        ),
    ];

    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.onSurface.withValues(alpha: 0.08),
    );

    return TvDialog(
      width: 720,
      padding: const EdgeInsets.all(20),
      icon: DiscountFormat.rubroIcon(d.rubro),
      iconColor: color,
      title: d.merchant.trim(),
      subtitle: d.benefit,
      // El porcentaje, grande, en una pastilla del color del rubro.
      trailingHeader: hasPercent
          ? DecoratedBox(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.18)!, color],
                ),
                shadows: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Text(
                  DiscountFormat.headline(d),
                  style: MoaiText.display(
                    context,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, tint) in tags)
                TvMetaPill(
                  label: label,
                  tint: tint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          MoaiGlass(
            borderRadius: MoaiGlass.panelRadius,
            solid: true,
            elevated: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Los datos de a dos por fila.
                for (var i = 0; i < details.length; i += 2) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: divider,
                    ),
                  Row(
                    children: [
                      for (var j = i; j < i + 2; j++) ...[
                        if (j > i) const SizedBox(width: 16),
                        Expanded(
                          child: j < details.length
                              ? _detail(
                                  context,
                                  icon: details[j].$1,
                                  label: details[j].$2,
                                  value: details[j].$3,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: divider,
                ),
                Text(
                  LocaleKeys.discounts_detail_days.tr(),
                  style: MoaiText.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _weekdays(context, d, color),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Pie discreto, como el consejo de la prueba de voz.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  MoaiIcons.infoCircle,
                  size: MoaiIconSizes.sm,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.discounts_day_desc.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TvDialogButton(
          label: LocaleKeys.common_close.tr(),
          focusNode: _close,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
