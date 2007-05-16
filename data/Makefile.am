schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = glchess.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = ai.xml $(schema_in_files)
aidir = $(datadir)/glchess/
ai_DATA = ai.xml

DISTCLEANFILES = $(schema_DATA)
