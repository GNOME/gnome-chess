SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = glchess
EXTRA_DIST  = glchess glchess.in
CLEANFILES  = glchess

glchess: $(builddir)/glchess.in
	sed \
		-e "s|\#pyexecdir\#|$(pyexecdir)|" \
	    	$< > $@
	if test -f $@; then chmod u+x $@; fi
