subdir('icons')

# The resource file
resource_files = files('chess.gresource.xml')
resources = gnome.compile_resources(application_id, resource_files,
  c_name: 'resources'
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
    ],
    depends: [
      desktop_file
    ]
  )
endif

# Make D-Bus activatable
service_conf = configuration_data()
service_conf.set('bindir', bindir)

configure_file(
  input: '@0@.service.in'.format(application_id),
  output: '@0@.service'.format(application_id),
  install: true,
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
  configuration: service_conf
)

# The metainfo file
metainfo_file = i18n.merge_file(
  input: '@0@.metainfo.xml.in'.format(application_id),
  output: '@0@.metainfo.xml'.format(application_id),
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test(
    'validate-metainfo', appstreamcli,
    args: [
      'validate', '--no-net', metainfo_file.full_path()
    ],
    depends: [
      metainfo_file
    ],
  )
endif

install_data('@0@.gschema.xml'.format(application_id),
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)

# The man page
install_man('gnome-chess.6')
