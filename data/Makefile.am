SUBDIRS = icons pieces textures

desktopdir = $(datadir)/applications
desktop_in_files = glchess.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = gnome-chess.appdata.xml.in
appdata_DATA = $(appdata_in_files:.appdata.xml.in=.appdata.xml)
@INTLTOOL_XML_RULE@

uidir = $(pkgdatadir)
dist_ui_DATA = \
	gnome-chess.ui \
	preferences.ui \
	promotion-type-selector.ui \
	menu.ui

gsettings_SCHEMAS = org.gnome.gnome-chess.gschema.xml
@GSETTINGS_RULES@

dist_sysconf_DATA = chess-engines.conf

dist_man_MANS = gnome-chess.6

EXTRA_DIST = \
	$(appdata_in_files) \
	$(gsettings_SCHEMAS)

CLEANFILES = \
	$(appdata_DATA) \
	glchess.desktop

DISTCLEANFILES = glchess.desktop.in

-include $(top_srcdir)/git.mk
