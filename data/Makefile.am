SUBDIRS = icons pieces textures

uidir = $(datadir)/glchess
ui_DATA = \
	glchess.ui \
	preferences.ui

gsettings_SCHEMAS = org.gnome.glchess.gschema.xml
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

aidir = $(datadir)/glchess/
ai_DATA = engines.conf

man_MANS = glchess.6

EXTRA_DIST = engines.conf \
	     org.gnome.glchess.gschema.xml.in \
	     $(man_MANS) \
	     $(ui_DATA)

CLEANFILES = $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
