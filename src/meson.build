# The resource file
resource_files = files('chess.gresource.xml')
resources = gnome.compile_resources('org.gnome.chess', resource_files,
  c_name: 'resources'
)

# The gnome-chess binary
chess_sources = [
  resources,

  'portability.c',
  'portability.vapi',

  'ai-profile.vala',
  'chess-engine-cecp.vala',
  'chess-engine-uci.vala',
  'chess-engine.vala',
  'chess-scene.vala',
  'chess-view.vala',
  'gnome-chess.vala',
]

chess_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
]

chess_c_args = [
  '-include', 'config.h',
]

chess_deps = [
  glib,
  gmodule,
  gtk,
  librsvg,
  posix,
  libchess_dep,
]

executable('gnome-chess', chess_sources,
  include_directories: config_h_dir,
  vala_args: chess_vala_args,
  c_args: chess_c_args,
  dependencies: chess_deps,
  install: true,
)
