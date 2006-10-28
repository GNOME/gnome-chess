SUBDIRS =  data glade help src textures

# Source files
EXTRA_DIST =
CLEAN_DIST =
CLEANFILES =

EXTRA_DIST += intltool-extract.in intltool-merge.in intltool-update.in
DISTCLEANFILES = intltool-extract intltool-merge intltool-update

#################################################################
# Launcher
@INTLTOOL_DESKTOP_RULE@

desktopdir = $(datadir)/applications
desktop_in_files = glchess.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
EXTRA_DIST += $(desktop_in_files)
CLEANFILES += $(desktop_DATA)

#################################################################

## Executable
bin_SCRIPTS = src/glchess
EXTRA_DIST += src/glchess
