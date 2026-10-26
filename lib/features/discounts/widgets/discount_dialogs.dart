import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

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

  @override
  Widget build(BuildContext context) {
    final d = widget.discount;
    final province = DiscountsService.instance.province;
    final rows = <(IconData, String)>[
      (DiscountFormat.rubroIcon(d.rubro), DiscountFormat.rubro(d.rubro)),
      if (d.bankLabel.isNotEmpty) (MoaiIcons.discountBanks, d.bankLabel),
      (MoaiIcons.discounts, DiscountFormat.cap(d)),
      if (DiscountFormat.cards(d).isNotEmpty)
        (MoaiIcons.discountBanks, DiscountFormat.cards(d)),
      if (d.installments > 0)
        (
          MoaiIcons.discounts,
          LocaleKeys.discounts_installments.tr(
            namedArgs: {'n': '${d.installments}'},
          ),
        ),
      (MoaiIcons.calendarEvents, DiscountFormat.weekdays(d)),
      if (DiscountFormat.validity(d).isNotEmpty)
        (MoaiIcons.calendarEvents, DiscountFormat.validity(d)),
      if (DiscountFormat.where(d).isNotEmpty)
        (MoaiIcons.discountMerchants, DiscountFormat.where(d)),
      if (d.mentions(province))
        (
          MoaiIcons.discountLocation,
          LocaleKeys.discounts_in_your_province.tr(
            namedArgs: {'province': province!},
          ),
        ),
    ];

    return TvDialog(
      width: 520,
      icon: DiscountFormat.rubroIcon(d.rubro),
      title: '${DiscountFormat.headline(d)} · ${d.merchant.trim()}',
      subtitle: d.benefit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: MoaiIconSizes.sm,
                    color: context.scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: context.scheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.discounts_day_desc.tr(),
            style: MoaiText.body(
              context,
              color: context.scheme.onSurfaceVariant,
              fontSize: 12,
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
