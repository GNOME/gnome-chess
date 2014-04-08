noinst_PROGRAMS = test-chess-game test-chess-pgn

TESTS = test-chess-game test-chess-pgn

AM_CFLAGS = -w

test_chess_game_SOURCES = \
	test-chess-game.vala

test_chess_game_CPPFLAGS = \
	-I$(top_srcdir)/lib \
	$(TEST_CFLAGS)

test_chess_game_LDADD = \
	$(top_builddir)/lib/libchess.la \
	$(TEST_LIBS)

test_chess_game_VALAFLAGS = \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	$(top_builddir)/lib/libchess.vapi

test_chess_pgn_SOURCES = \
	test-chess-pgn.vala

test_chess_pgn_CPPFLAGS = \
	-I$(top_srcdir)/lib \
	$(TEST_CFLAGS)

test_chess_pgn_LDADD = \
	$(top_builddir)/lib/libchess.la \
	$(TEST_LIBS)

test_chess_pgn_VALAFLAGS = \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	$(top_builddir)/lib/libchess.vapi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp \
	*.log \
	*.trs

-include $(top_srcdir)/git.mk
