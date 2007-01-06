schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = glchess.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

EXTRA_DIST = ai.xml glchess.svg $(schema_in_files)
aidir = $(datadir)/glchess/
ai_DATA = ai.xml glchess.svg

icondir = $(datadir)/pixmaps
icon_DATA = glchess.svg

DISTCLEANFILES = $(schema_DATA)
