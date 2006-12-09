SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = glchess
EXTRA_DIST  = glchess
CLEANFILES  = glchess

glchess: glchess.in
	sed \
		-e "s|\@pyexecdir\@|$(pyexecdir)|" \
		glchess.in > glchess

