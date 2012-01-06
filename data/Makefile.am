SUBDIRS = icons pieces textures

desktopdir = $(datadir)/applications
desktop_in_files = glchess.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

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

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
