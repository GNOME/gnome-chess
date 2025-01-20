project('gnome-chess', [ 'vala', 'c' ],
  version: '48~alpha1',
  license: 'GPL3+',
  meson_version: '>= 0.59',
)
application_id = 'org.gnome.Chess'
gnome = import('gnome')
i18n = import('i18n')

# Add our config VAPI
add_project_arguments(
  [
    '--vapidir', join_paths(meson.project_source_root(), 'src'),
    '--pkg', 'config',
  ],
  language: 'vala'
)

# Some variables
config_h_dir = include_directories('.')
localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
pkgdatadir = join_paths(datadir, meson.project_name())
sysconfdir = join_paths(get_option('prefix'), get_option('sysconfdir'))
pkgsysconfdir = join_paths(sysconfdir, meson.project_name())
po_dir = join_paths(meson.project_source_root(), 'po')
bindir = join_paths(get_option('prefix'), get_option('bindir'))

# Dependencies
min_glib_version = '2.44.0'

gio = dependency('gio-unix-2.0', version: '>=' + min_glib_version)
glib = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule = dependency('gmodule-2.0', version: '>=' + min_glib_version)
gtk = dependency('gtk4', version: '>= 4.14')
libadwaita = dependency('libadwaita-1', version: '>= 1.5')
librsvg = dependency('librsvg-2.0', version: '>= 2.46.0')
pangocairo = dependency('pangocairo')

m = meson.get_compiler('c').find_library('m', required : false)

posix = meson.get_compiler('vala').find_library('posix')

# Configuration
conf = configuration_data()
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', localedir)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('PKGDATADIR', pkgdatadir)
conf.set_quoted('SYSCONFDIR', sysconfdir)
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('G_LOG_DOMAIN', meson.project_name())
configure_file(output: 'config.h', configuration: conf)

# Post-install scripts
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)

# Subfolders
subdir('data')
subdir('po')
subdir('lib')
subdir('engine')
subdir('src')
subdir('tests')
subdir('help')
