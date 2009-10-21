SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = glchess
CLEANFILES  = glchess glchess.in

glchess: glchess.in
	$(AM_V_GEN) $(SED) -e "s|\#pyexecdir\#|$(pyexecdir)|" $< > $@ && chmod u+x $@

-include $(top_srcdir)/git.mk
