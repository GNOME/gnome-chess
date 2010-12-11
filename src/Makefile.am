bin_PROGRAMS = glchess

glchess_SOURCES = \
	3ds.vala \
	glchess.vala \
	ai-profile.vala \
	chess-engine.vala \
	chess-engine-cecp.vala \
	chess-engine-uci.vala \
	chess-game.vala \
	chess-pgn.vala \
	chess-view.vala \
	chess-view-2d.vala \
	chess-view-3d.vala \
	chess-view-options.vala

glchess_CFLAGS = \
	$(GMODULE_CFLAGS) \
	$(GTK_CFLAGS) \
	$(GDK_X11_CFLAGS) \
	$(GLX_CFLAGS) \
	$(OPENGL_CFLAGS) \
	$(RSVG_CFLAGS) \
	$(GTKGLEXT_CFLAGS) \
	$(WARN_CFLAGS)

glchess_LDADD = \
	$(GMODULE_LIBS) \
	$(GTK_LIBS) \
	$(GDK_X11_LIBS) \
	$(GLX_LIBS) \
	$(OPENGL_LIBS) \
	$(RSVG_LIBS) \
	$(GTKGLEXT_LIBS)

glchess_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gdk-x11-3.0 \
    --pkg gmodule-2.0 \
    --pkg glx \
    --pkg librsvg-2.0 \
    --pkg posix \
    --vapidir . \
    --pkg gl \
    --pkg glu

DISTCLEANFILES = \
	Makefile.in
