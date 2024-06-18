# The gnome-chess binary
chess_sources = [
  resources,
  'chess-scene.vala',
  'chess-view.vala',
  'chess-window.vala',
  'gnome-chess.vala',
  'new-game-window.vala',
  'preferences-window.vala',
  'preferences.vala',
  'promotion-type-selector-dialog.vala',
]

chess_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
  '--gresources', resource_files,
]

chess_c_args = [
  '-include', 'config.h',
]

chess_deps = [
  glib,
  gmodule,
  gtk,
  libadwaita,
  librsvg,
  m,
  pangocairo,
  posix,
  libchess_dep,
  libengine_dep,
]

executable('gnome-chess', chess_sources,
  include_directories: config_h_dir,
  vala_args: chess_vala_args,
  c_args: chess_c_args,
  dependencies: chess_deps,
  install: true,
)
