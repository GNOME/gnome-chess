# The gnome-chess internal library
libchess_sources = [
  'chess-bitboard.vala',
  'chess-clock.vala',
  'chess-game.vala',
  'chess-move.vala',
  'chess-pgn.vala',
  'chess-piece.vala',
  'chess-player.vala',
  'chess-state.vala',
]

libchess_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
]

libchess_c_args = [
  '-include', 'config.h',
  '-w'
]

libchess_deps = [
  glib,
  gio,
  posix,
]

libchess = static_library('libchess', libchess_sources,
  include_directories: config_h_dir,
  vala_args: libchess_vala_args,
  c_args: libchess_c_args,
  dependencies: libchess_deps
)

libchess_dep = declare_dependency(
  link_with: libchess,
  include_directories: include_directories('.'),
)
