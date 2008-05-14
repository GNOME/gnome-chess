SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = glchess
CLEANFILES  = glchess glchess.in

glchess: glchess.in
	sed \
		-e "s|\#pyexecdir\#|$(pyexecdir)|" \
	    	$< > $@
	if test -f $@; then chmod u+x $@; fi
