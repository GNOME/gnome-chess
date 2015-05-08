AC_PREREQ([2.63])
AC_INIT([GNOME Chess], [3.16.2], [https://bugzilla.gnome.org/],
        [gnome-chess], [https://wiki.gnome.org/Apps/Chess])

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([src/gnome-chess.vala])

AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
GNOME_MAINTAINER_MODE_DEFINES

AM_PROG_VALAC([0.27.1])
AM_PROG_CC_C_O

LT_PREREQ([2.2])
LT_INIT

GLIB_GSETTINGS

APPSTREAM_XML

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40
GTK_REQUIRED=3.15.0
RSVG_REQUIRED=2.32.0

AC_SUBST([GLIB_REQUIRED])

PKG_CHECK_MODULES(GNOME_CHESS, [
  glib-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  gmodule-2.0
  gtk+-3.0 >= $GTK_REQUIRED
  librsvg-2.0 >= $RSVG_REQUIRED
])

PKG_CHECK_MODULES(LIBCHESS, [
  glib-2.0
  gio-2.0
])

PKG_CHECK_MODULES(TEST, [
  glib-2.0
  gio-2.0
])

AC_CHECK_HEADERS([linux/prctl.h])
AM_CONDITIONAL([WITH_PRCTL], [test x$ac_cv_header_linux_prctl_h = xyes])

AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

dnl ###########################################################################
dnl GResources
dnl ###########################################################################

AC_PATH_PROG([GLIB_COMPILE_RESOURCES],[glib-compile-resources])

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL([0.50])
AC_SUBST(GETTEXT_PACKAGE, gnome-chess)

dnl ###########################################################################
dnl Documentation
dnl ###########################################################################

YELP_HELP_INIT

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
data/Makefile
data/icons/Makefile
data/icons/hicolor/Makefile
data/pieces/Makefile
data/pieces/fancy/Makefile
data/pieces/simple/Makefile
help/Makefile
lib/Makefile
po/Makefile.in
src/Makefile
tests/Makefile
])
AC_OUTPUT
