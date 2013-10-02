SUBDIRS = icons pieces textures

desktopdir = $(datadir)/applications
desktop_in_files = glchess.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

@INTLTOOL_XML_NOMERGE_RULE@
appdatadir = $(datadir)/appdata
appdata_files = gnome-chess.appdata.xml
dist_appdata_DATA = $(appdata_in_files:.xml.in=.xml)
appdata_in_files = gnome-chess.appdata.xml.in

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

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

EXTRA_DIST = \
	$(appdata_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS)

CLEANFILES = \
	$(app_data_in_files) \
	$(desktop_DATA)

-include $(top_srcdir)/git.mk
