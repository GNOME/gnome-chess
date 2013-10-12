AC_PREREQ([2.63])
AC_INIT([gnome-chess],[3.10.1])
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AC_CONFIG_SRCDIR([src/gnome-chess.vala])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
GNOME_MAINTAINER_MODE_DEFINES

AM_PROG_VALAC([0.21])
AM_PROG_CC_C_O

GLIB_GSETTINGS

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GTK_REQUIRED=3.4.0
RSVG_REQUIRED=2.32.0

PKG_CHECK_MODULES(GNOME_CHESS, [
  glib-2.0
  gio-2.0
  gmodule-2.0
  gtk+-3.0 >= $GTK_REQUIRED
  librsvg-2.0 >= $RSVG_REQUIRED
  gl
  glu
  x11
])

PKG_CHECK_MODULES(TEST, [
  gio-2.0
])

dnl ###########################################################################
dnl Disable C warnings
dnl ###########################################################################
GNOME_CHESS_CFLAGS="$GNOME_CHESS_CFLAGS -w"
AC_SUBST([GNOME_CHESS_CFLAGS])

TEST_CFLAGS="$TEST_CFLAGS -w"
AC_SUBST([TEST_CFLAGS])

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
data/pieces/Makefile
data/pieces/3d/Makefile
data/pieces/fancy/Makefile
data/pieces/simple/Makefile
data/textures/Makefile
data/glchess.desktop.in
help/Makefile
po/Makefile.in
src/Makefile
])
AC_OUTPUT
