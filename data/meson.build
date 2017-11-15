subdir('icons')

# The SVGs of the chess pieces
install_subdir('pieces',
  install_dir: join_paths(datadir, meson.project_name())
)

# The engines.conf file
install_data('engines.conf',
  install_dir: pkgsysconfdir,
)

# The desktop file
i18n.merge_file(
  input: 'gnome-chess.desktop.in',
  output: 'gnome-chess.desktop',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'applications')
)

# The appdata file
i18n.merge_file(
  input: 'gnome-chess.appdata.xml.in',
  output: 'gnome-chess.appdata.xml',
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)

install_data('org.gnome.chess.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

# The man page
install_man('gnome-chess.6')
