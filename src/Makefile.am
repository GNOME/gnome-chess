bin_PROGRAMS = gnome-chess

gnome_chess_SOURCES = \
	config.vapi \
	portability.vapi \
	portability.c \
	portability.h \
	gnome-chess.vala \
	ai-profile.vala \
	chess-engine.vala \
	chess-engine-cecp.vala \
	chess-engine-uci.vala \
	chess-scene.vala \
	chess-view.vala

gnome_chess_CFLAGS = \
	-w

gnome_chess_CPPFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPKGDATADIR=\"$(pkgdatadir)/\" \
	-DLOCALEDIR=\"$(localedir)\" \
	-DSYSCONFDIR=\"$(sysconfdir)\" \
	-I$(top_srcdir)/lib \
	$(GNOME_CHESS_CFLAGS)

gnome_chess_LDADD = \
	$(GNOME_CHESS_LIBS) \
	$(top_builddir)/lib/libchess.la

gnome_chess_VALAFLAGS = \
	--pkg glib-2.0 \
	--pkg gmodule-2.0 \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--pkg posix \
	--target-glib=$(GLIB_REQUIRED) \
	$(top_builddir)/lib/libchess.vapi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp \
	*.log \
	*.trs

-include $(top_srcdir)/git.mk
