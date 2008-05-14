SUBDIRS = chess ggz gtkui scene ui

CLEANFILES = defaults.py

# Don't distribute generated defaults.py. If you know a simpler way that works
# e.g. nodist_glchess_PYTHON=defaults.py then please fix this
dist-hook:
	rm $(distdir)/defaults.py

glchessdir = $(pythondir)/glchess
glchess_PYTHON = \
	ai.py		\
	cecp.py		\
	config.py       \
	defaults.py	\
        display.py	\
	game.py		\
	glchess.py 	\
	history.py 	\
	__init__.py	\
	main.py		\
	network.py	\
	player.py	\
	uci.py
