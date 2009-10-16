bin_PROGRAMS = gnome-gnuchess

gnome_gnuchess_SOURCES = atak.c book.c cmd.c debug.c epd.c eval.c genmove.c \
 getopt.c getopt1.c hash.c\
 hung.c	init.c input.c iterate.c main.c move.c null.c output.c players.c\
 pgn.c ponder.c quiesce.c random.c repeat.c search.c solve.c sort.c\
 swap.c test.c ttable.c util.c common.h book.h eval.h getopt.h \
 inlines.h version.h lexpgn.c lexpgn.h

gnome_gnuchess_CFLAGS = $(PTHREAD_CFLAGS) $(AM_CFLAGS)

gnome_gnuchess_LDFLAGS = $(PTHREAD_LDFLAGS) $(PTHREAD_LIBS) $(AM_LDFLAGS)
