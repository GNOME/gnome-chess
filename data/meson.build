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
desktop_file = i18n.merge_file(
  input: '@0@.desktop.in'.format(application_id),
  output: '@0@.desktop'.format(application_id),
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'applications')
)
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif


# The appdata file
appdata_file = i18n.merge_file(
  input: '@0@.appdata.xml.in'.format(application_id),
  output: '@0@.appdata.xml'.format(application_id),
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', appdata_file.full_path()
    ]
  )
endif

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

# The man page
install_man('gnome-chess.6')
