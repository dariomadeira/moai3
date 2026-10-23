/// Pestañas de la sección TV. El `name` es el valor que se guarda en las
/// preferencias (`startup_tv_tab`), así que no se renombran (SPEC-50 §5.4).
enum TvTab {
  explore,
  search,
  groups;

  /// Valor guardado → pestaña; [explore] si falta o es desconocido.
  static TvTab fromStorage(String? value) =>
      TvTab.values.asNameMap()[value] ?? TvTab.explore;
}
