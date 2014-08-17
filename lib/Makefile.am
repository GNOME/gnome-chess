noinst_LTLIBRARIES = libchess.la

libchess_la_SOURCES = \
	chess-bitboard.vala \
	chess-clock.vala \
	chess-game.vala \
	chess-move.vala \
	chess-pgn.vala \
	chess-piece.vala \
	chess-player.vala \
	chess-state.vala

libchess_la_CFLAGS = \
	-w

libchess_la_CPPFLAGS = \
	$(LIBCHESS_CFLAGS)

libchess_la_LIBADD = \
	$(LIBCHESS_LIBS)

libchess_la_VALAFLAGS = \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg posix \
	--header=libchess.h \
	--vapi=libchess.vapi \
	--target-glib=$(GLIB_REQUIRED)

EXTRA_DIST = \
	libchess.h \
	libchess.vapi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp \
	*.log \
	*.trs \
	libchess.vapi \
	libchess.h

-include $(top_srcdir)/git.mk
