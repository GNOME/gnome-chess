bin_PROGRAMS = glchess

noinst_PROGRAMS = test-chess-game

glchess_SOURCES = \
	3ds.vala \
	glchess.vala \
	ai-profile.vala \
	chess-bitboard.vala \
	chess-engine.vala \
	chess-engine-cecp.vala \
	chess-engine-uci.vala \
	chess-game.vala \
	chess-pgn.vala \
	chess-view.vala \
	chess-view-2d.vala \
	chess-view-3d.vala \
	chess-view-options.vala \
	history.vala

test_chess_game_SOURCES = \
	chess-bitboard.vala \
	chess-game.vala \
	test-chess-game.vala

test_chess_game_CFLAGS = \
	$(GOBJECT_CFLAGS)

test_chess_game_LDADD = \
	$(GOBJECT_LIBS)

test_chess_game_VALAFLAGS = \
    --pkg gobject-2.0 \
    --pkg posix

glchess_CFLAGS = \
	-DPKGDATADIR=\"@datadir@/glchess\" \
	$(GMODULE_CFLAGS) \
	$(GTK_CFLAGS) \
	$(GLX_CFLAGS) \
	$(OPENGL_CFLAGS) \
	$(RSVG_CFLAGS) \
	$(SQLITE_CFLAGS) \
	$(GTKGLEXT_CFLAGS) \
	$(WARN_CFLAGS)

glchess_LDADD = \
	$(GMODULE_LIBS) \
	$(GTK_LIBS) \
	$(GDK_X11_LIBS) \
	$(GLX_LIBS) \
	$(OPENGL_LIBS) \
	$(RSVG_LIBS) \
	$(SQLITE_LIBS) \
	$(GTKGLEXT_LIBS)

glchess_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gdk-x11-3.0 \
    --pkg gmodule-2.0 \
    --pkg librsvg-2.0 \
    --pkg posix \
    --pkg sqlite3 \
    --vapidir . \
    --pkg config \
    --pkg gl \
    --pkg glu \
    --pkg glx

EXTRA_DIST = config.vapi gl.vapi glu.vapi glx.vapi

DISTCLEANFILES = \
	Makefile.in
