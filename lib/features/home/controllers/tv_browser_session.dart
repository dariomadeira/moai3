import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/features/favorites/controllers/favorites_list_controller.dart';
import 'package:moai3/features/groups/controllers/groups_browser_controller.dart';
import 'package:moai3/features/home/controllers/viewer_favorites_controller.dart';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/focus/tv_panel_layout.dart';

/// Estado de navegación de la sección TV que sobrevive al cambio de sección
/// (SPEC-50 §3.1): al volver de Ajustes o la Agenda, TV conserva país,
/// categoría, canal, pestaña, búsqueda y panel abierto.
///
/// Lo crea y descarta [HomeScreen]; `HomeTvArea` solo lo usa. El reproductor
/// no vive acá: se sigue destruyendo al salir de TV.
class TvBrowserSession {
  final browser = ChannelBrowserController();
  final search = HomeSearchController();
  final groups = GroupsBrowserController();
  final favorites = FavoritesListController();
  final favoritesBar = ViewerFavoritesController();

  /// `null` hasta la primera visita: se usa la pestaña de arranque.
  TvTab? tab;

  /// Panel abierto del acordeón Explorar.
  TvExplorePanel? activePanel;
  int groupsPanelIndex = 0;

  /// `true` después de la primera visita a TV.
  bool get isPopulated => tab != null;

  void dispose() {
    browser.dispose();
    search.dispose();
    groups.dispose();
    favorites.dispose();
    favoritesBar.dispose();
  }
}
