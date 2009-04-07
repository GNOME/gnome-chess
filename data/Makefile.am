uidir = $(datadir)/glchess
ui_DATA = \
	chess_view.ui \
	glchess.ui \
	load_game.ui \
	log.ui \
	new_game.ui \
	network_game.ui \
	network_new_server.ui \
	preferences.ui \
	save_game.ui

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = glchess.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = ai.xml $(schema_in_files) $(ui_DATA)
aidir = $(datadir)/glchess/
ai_DATA = ai.xml

DISTCLEANFILES = $(schema_DATA)
