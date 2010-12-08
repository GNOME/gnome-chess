SUBDIRS = pieces textures

uidir = $(datadir)/glchess
ui_DATA = \
	glchess.ui \
	preferences.ui

man_MANS = glchess.6

EXTRA_DIST = engines.conf \
	     $(man_MANS) \
	     $(ui_DATA)

aidir = $(datadir)/glchess/
ai_DATA = engines.conf

-include $(top_srcdir)/git.mk
