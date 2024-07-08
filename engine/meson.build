libengine_sources = [
  'ai-profile.vala',
  'chess-engine-cecp.vala',
  'chess-engine-uci.vala',
  'chess-engine.vala',
]

libengine_vala_args = [
  '--target-glib=@0@'.format(min_glib_version),
]

libengine_c_args = [
  '-include', 'config.h',
  '-w'
]

libengine_deps = [
  glib,
  gio,
  posix,
  libchess_dep,
]

libengine = static_library('libengine', libengine_sources,
  include_directories: config_h_dir,
  vala_args: libengine_vala_args,
  c_args: libengine_c_args,
  dependencies: libengine_deps
)

libengine_dep = declare_dependency(
  link_with: libengine,
  include_directories: include_directories('.'),
)
