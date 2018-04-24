project('gnome-chess', [ 'vala', 'c' ],
  version: '3.29.1',
  license: 'GPL3+',
  meson_version: '>= 0.37',
)

gnome = import('gnome')
i18n = import('i18n')

# Add our config VAPI
add_project_arguments(
  [
    '--vapidir', join_paths(meson.source_root(), 'src'),
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
po_dir = join_paths(meson.source_root(), 'po')

# Dependencies
min_glib_version = '2.44.0'

gio = dependency('gio-unix-2.0', version: '>=' + min_glib_version)
glib = dependency('glib-2.0', version: '>=' + min_glib_version)
gmodule = dependency('gmodule-2.0', version: '>=' + min_glib_version)
gtk = dependency('gtk+-3.0', version: '>= 3.19.0')
librsvg = dependency('librsvg-2.0', version: '>= 2.32.0')

posix = meson.get_compiler('vala').find_library('posix')
has_prctl = meson.get_compiler('c').has_header('sys/prctl.h')

# Configuration
conf = configuration_data()
conf.set10('HAVE_PRCTL', has_prctl)
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', localedir)
conf.set_quoted('PACKAGE_NAME', meson.project_name())
conf.set_quoted('PACKAGE_STRING', meson.project_name())
conf.set_quoted('PACKAGE_VERSION', meson.project_version())
conf.set_quoted('PKGDATADIR', pkgdatadir)
conf.set_quoted('SYSCONFDIR', sysconfdir)
conf.set_quoted('VERSION', meson.project_version())
configure_file(output: 'config.h', configuration: conf)

# Post-install scripts
meson.add_install_script('meson_post_install.py')

# Subfolders
subdir('data')
subdir('po')
subdir('lib')
subdir('src')
subdir('tests')
subdir('help')
