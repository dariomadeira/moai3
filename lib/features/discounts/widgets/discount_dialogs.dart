import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

/// "Mis bancos y billeteras": cuáles tiene el usuario, para mostrarle sólo
/// los descuentos que puede usar. Cada fila se prende y apaga con OK.
class TvDiscountBanksDialog extends StatefulWidget {
  const TvDiscountBanksDialog({super.key});

  static Future<void> show(BuildContext context) => showTvGeneralDialog<void>(
    context: context,
    barrierLabel: 'DiscountBanks',
    builder: (_) => const TvDiscountBanksDialog(),
  );

  @override
  State<TvDiscountBanksDialog> createState() => _TvDiscountBanksDialogState();
}

class _TvDiscountBanksDialogState extends State<TvDiscountBanksDialog> {
  final _done = FocusNode(debugLabel: 'discount_banks_done');
  static const _itemExtent = 70.0;
  static const _window = 4;

  @override
  void initState() {
    super.initState();
    final service = DiscountsService.instance;
    service.ensureLoaded();
    // Sin lista todavía (primera vez o sin internet antes): pedirla.
    if (service.banks.isEmpty) service.refresh(force: true);
  }

  @override
  void dispose() {
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = DiscountsService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final banks = service.banks;
        if (banks.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_done.hasFocus) _done.requestFocus();
          });
        }
        return TvDialog(
          width: 520,
          icon: MoaiIcons.discountBanks,
          title: LocaleKeys.discounts_banks_title.tr(),
          subtitle: LocaleKeys.discounts_banks_desc.tr(),
          content: SizedBox(
            height: _window * _itemExtent,
            child: banks.isEmpty
                ? Center(
                    child: Text(
                      service.isLoading
                          ? LocaleKeys.discounts_loading.tr()
                          : LocaleKeys.discounts_banks_unavailable.tr(),
                      textAlign: TextAlign.center,
                      style: MoaiText.body(
                        context,
                        color: context.scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  )
                : TvWindowedList<DiscountBank>(
                    items: banks,
                    windowSize: _window,
                    itemExtent: _itemExtent,
                    showScrollDots: true,
                    onFocusDownFromLast: _done.requestFocus,
                    itemBuilder:
                        (
                          context,
                          bank,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TvSettingsSwitchRow(
                            focusNode: focusNode,
                            icon: MoaiIcons.discountBanks,
                            label: bank.name,
                            value: service.selectedBankIds.contains(bank.id),
                            onChanged: (_) => service.toggleBank(bank.id),
                            onKeyLeft: () {},
                            onKeyUp: onKeyUp,
                            onKeyDown: onKeyDown,
                          ),
                        ),
                  ),
          ),
          actions: [
            TvDialogButton(
              label: LocaleKeys.discounts_done.tr(),
              variant: TvDialogButtonVariant.primary,
              focusNode: _done,
              autofocus: banks.isEmpty,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// Todos los descuentos de un día con los bancos del usuario, con sus
/// condiciones (tope, tarjetas, vigencia). ↑/↓ los recorren.
class TvDiscountsDayDialog extends StatelessWidget {
  const TvDiscountsDayDialog({
    super.key,
    required this.day,
    required this.discounts,
  });

  final DayDiscounts day;
  final List<Discount> discounts;

  static Future<void> show(BuildContext context, DayDiscounts day) =>
      showTvGeneralDialog<void>(
        context: context,
        barrierLabel: 'DiscountsDay',
        builder: (_) =>
            TvDiscountsDayDialog(day: day, discounts: day.discounts),
      );

  static const _itemExtent = 76.0;
  static const _window = 4;

  @override
  Widget build(BuildContext context) {
    final title = LocaleKeys.discounts_day_title.tr(
      namedArgs: {'day': DiscountFormat.day(day.day, DateTime.now())},
    );
    return TvDialog(
      width: 560,
      icon: MoaiIcons.discounts,
      title: title,
      subtitle: LocaleKeys.discounts_day_desc.tr(),
      content: SizedBox(
        height: _window * _itemExtent,
        child: discounts.isEmpty
            ? Center(
                child: Text(
                  LocaleKeys.discounts_none_day.tr(),
                  style: MoaiText.body(
                    context,
                    color: context.scheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              )
            : TvWindowedList<Discount>(
                items: discounts,
                windowSize: _window,
                itemExtent: _itemExtent,
                showScrollDots: true,
                itemBuilder:
                    (
                      context,
                      discount,
                      focusNode,
                      local,
                      global,
                      onKeyUp,
                      onKeyDown,
                    ) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: _DiscountRow(
                        discount: discount,
                        focusNode: focusNode,
                        onUp: onKeyUp,
                        onDown: onKeyDown,
                      ),
                    ),
              ),
      ),
    );
  }
}

/// Un descuento: porcentaje grande, comercio y condiciones.
class _DiscountRow extends StatefulWidget {
  const _DiscountRow({
    required this.discount,
    required this.focusNode,
    required this.onUp,
    required this.onDown,
  });

  final Discount discount;
  final FocusNode focusNode;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  State<_DiscountRow> createState() => _DiscountRowState();
}

class _DiscountRowState extends State<_DiscountRow> {
  late bool _focused = widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final d = widget.discount;
    final details = [
      d.bankLabel,
      DiscountFormat.cap(d),
      DiscountFormat.cards(d),
      if (d.installments > 0)
        LocaleKeys.discounts_installments.tr(
          namedArgs: {'n': '${d.installments}'},
        ),
    ].where((s) => s.trim().isNotEmpty).join('  ·  ');

    return TvPressDetector(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onUp: widget.onUp,
      onDown: widget.onDown,
      child: MoaiGlass(
        borderRadius: 12,
        elevated: false,
        solid: true,
        focused: _focused,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                DiscountFormat.headline(d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  color: scheme.primary,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
