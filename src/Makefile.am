bin_PROGRAMS = glchess

glchess_SOURCES = \
	glchess.vala \
	ai-profile.vala \
	chess-engine.vala \
	chess-engine-cecp.vala \
	chess-engine-uci.vala \
	chess-game.vala \
	chess-pgn.vala \
	chess-view.vala \
	chess-view-2d.vala \
	chess-view-options.vala

#	3ds.vala
#	chess-view-3d.vala

glchess_CFLAGS = \
	$(GMODULE_CFLAGS) \
	$(GTK_CFLAGS) \
	$(RSVG_CFLAGS) \
	$(GTKGLEXT_CFLAGS) \
	$(WARN_CFLAGS)

glchess_LDADD = \
	$(GMODULE_LIBS) \
	$(GTK_LIBS) \
	$(RSVG_LIBS) \
	$(GTKGLEXT_LIBS)

glchess_VALAFLAGS = \
    --pkg gtk+-3.0 \
    --pkg gmodule-2.0 \
    --pkg librsvg-2.0 \
    --pkg posix \
    --vapidir . \
    --pkg gl \
    --pkg glu

#    --pkg gtkglext-1.0

DISTCLEANFILES = \
	Makefile.in
