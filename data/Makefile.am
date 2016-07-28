SUBDIRS = icons pieces

desktopdir = $(datadir)/applications
desktop_in_files = gnome-chess.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

$(desktop_DATA): $(desktop_in_files)
	$(AM_V_GEN) $(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

appstream_in_files = gnome-chess.appdata.xml.in
appstream_XML = $(appstream_in_files:.appdata.xml.in=.appdata.xml)
@APPSTREAM_XML_RULES@

$(appstream_XML): $(appstream_in_files)
	$(AM_V_GEN) $(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@

dist_noinst_DATA = \
	gnome-chess.ui \
	preferences.ui \
	promotion-type-selector.ui \
	menu.ui

gsettings_SCHEMAS = org.gnome.chess.gschema.xml
@GSETTINGS_RULES@

pkgsysconfdir = $(sysconfdir)/gnome-chess
dist_pkgsysconf_DATA = engines.conf

dist_man_MANS = gnome-chess.6

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

EXTRA_DIST = \
	$(appstream_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

AM_DISTCHECK_CONFIGURE_FLAGS == --enable-appdata-check

-include $(top_srcdir)/git.mk
