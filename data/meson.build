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
  input: '@0@.desktop.in'.format(application_id),
  output: '@0@.desktop'.format(application_id),
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'applications')
)

# The appdata file
i18n.merge_file(
  input: '@0@.appdata.xml.in'.format(application_id),
  output: '@0@.appdata.xml'.format(application_id),
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

# The man page
install_man('gnome-chess.6')
