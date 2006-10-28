import os
import glob

from distutils.core import setup

DESCRIPTION = """glChess is an open source 3D chess interface for the Gnome desktop.
It is designed to be used by both beginner and experienced players.
Games can be played between a combination of local players, players connected via a LAN and artificial intelligences.
"""

CLASSIFIERS = ['License :: OSI-Approved Open Source :: GNU General Public License (GPL)',
               'Intended Audience :: by End-User Class :: End Users/Desktop',
               'Development Status :: 4 - Beta',
               'Topic :: Desktop Environment :: Gnome',
               'Topic :: Games/Entertainment :: Board Games',
               'Programming Language :: Python',
               'Operating System :: Grouping and Descriptive Categories :: All POSIX (Linux/BSD/UNIX-like OSes)',
               'Operating System :: Modern (Vendor-Supported) Desktop Operating Systems :: Linux',
               'User Interface :: Graphical :: Gnome',
               'User Interface :: Graphical :: OpenGL',
               'User Interface :: Toolkits/Libraries :: GTK+',
               'Translations :: English', 'Translations :: German', 'Translations :: Italian']

DATA_FILES = []

# MIME files
DATA_FILES.append(('share/mime/packages', ['mime/glchess.xml']))

# UI files
DATA_FILES.append(('share/games/glchess/gui', ['glchess.svg'] + glob.glob('lib/glchess/gtkui/*.glade')))

# Config files
DATA_FILES.append(('share/games/glchess/', ['ai.xml']))

# Texture files
TEXTURES = []
for file in ['board.png', 'piece.png']:
    TEXTURES.append('textures/' + file)
DATA_FILES.append(('share/games/glchess/textures', TEXTURES))

DATA_FILES.append(('share/applications', ['glchess.desktop']))
DATA_FILES.append(('share/pixmaps', ['glchess.svg']))

# Language files
#for poFile in glob.glob('po/*.po'):
#    language = poFile[3:-3]
#    DATA_FILES.append(('share/locale/' + language + '/LC_MESSAGES', poFile))
#print DATA_FILES

setup(name             = 'glchess',
      version          = '1.0RC1',
      classifiers      = CLASSIFIERS,
      description      = '3D Chess Interface',
      long_description = DESCRIPTION,
      author           = 'Robert Ancell',
      author_email     = 'bob27@users.sourceforge.net',
      license          = 'GPL',
      url              = 'http://glchess.sourceforge.net',
      download_url     = 'http://sourceforge.net/project/showfiles.php?group_id=6348',
      package_dir      = {'': 'lib'},
      packages         = ['glchess', 'glchess.chess', 'glchess.scene', 'glchess.scene.cairo', 'glchess.scene.opengl', 'glchess.ui', 'glchess.gtkui', 'glchess.network'],
      data_files       = DATA_FILES,
      scripts          = ['glchess'])
