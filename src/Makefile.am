bin_PROGRAMS = gnome-chess

noinst_PROGRAMS = test-chess-game test-chess-pgn

TESTS = test-chess-game test-chess-pgn

gnome_chess_SOURCES = \
	config.vapi \
	gl.vapi \
	glu.vapi \
	glx.vapi \
	prctl.vapi \
	3ds.vala \
	gnome-chess.vala \
	ai-profile.vala \
	chess-bitboard.vala \
	chess-clock.vala \
	chess-engine.vala \
	chess-engine-cecp.vala \
	chess-engine-uci.vala \
	chess-game.vala \
	chess-pgn.vala \
	chess-scene.vala \
	chess-view.vala \
	chess-view-2d.vala \
	chess-view-3d.vala

test_chess_game_SOURCES = \
	chess-bitboard.vala \
	chess-clock.vala \
	chess-game.vala \
	test-chess-game.vala
test_chess_game_CFLAGS = \
	-w \
	$(TEST_CFLAGS)
test_chess_game_LDADD = \
	$(TEST_LIBS)
test_chess_game_VALAFLAGS = \
    --pkg gobject-2.0 \
    --pkg posix

test_chess_pgn_SOURCES = \
	chess-pgn.vala \
	test-chess-pgn.vala
test_chess_pgn_CFLAGS = \
	-w \
	$(TEST_CFLAGS)
test_chess_pgn_LDADD = \
	$(TEST_LIBS)
test_chess_pgn_VALAFLAGS = \
    --pkg gio-2.0

gnome_chess_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DPKGDATADIR=\"$(pkgdatadir)/\" \
	-DLOCALEDIR=\"$(localedir)\" \
	-DSYSCONFDIR=\"$(sysconfdir)\" \
	-w \
	$(GNOME_CHESS_CFLAGS)

gnome_chess_LDADD = \
	$(GNOME_CHESS_LIBS)

gnome_chess_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gdk-x11-3.0 \
    --pkg gmodule-2.0 \
    --pkg librsvg-2.0 \
    --pkg posix \
    --pkg sqlite3

if WITH_PRCTL
    gnome_chess_VALAFLAGS += -D HAVE_LINUX_PRCTL_H
endif

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp \
	*.log \
	*.trs

-include $(top_srcdir)/git.mk
