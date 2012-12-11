SUBDIRS = icons pieces textures

desktopdir = $(datadir)/applications
desktop_in_files = gnome-chess.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

uidir = $(datadir)/gnome-chess
ui_DATA = \
	gnome-chess.ui \
	preferences.ui \
	promotion-type-selector.ui

gsettings_SCHEMAS = org.gnome.gnome-chess.gschema.xml
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

aidir = $(datadir)/gnome-chess/
ai_DATA = engines.conf

man_MANS = gnome-chess.6

EXTRA_DIST = engines.conf \
	     org.gnome.gnome-chess.gschema.xml.in \
	     $(man_MANS) \
	     $(ui_DATA)

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
