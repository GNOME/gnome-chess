SUBDIRS =  data glade help src textures

desktopdir = $(datadir)/applications
desktop_in_files = glchess.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
EXTRA_DIST = $(desktop_in_files)
CLEANFILES = $(desktop_DATA)

@INTLTOOL_DESKTOP_RULE@

#################################################################

## Executable
bin_SCRIPTS = src/glchess
EXTRA_DIST += src/glchess
