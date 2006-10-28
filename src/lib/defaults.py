import os, os.path
import gettext
#DOMAIN = 'glchess'
DOMAIN = 'gnome-games'
gettext.bindtextdomain(DOMAIN)
gettext.textdomain(DOMAIN)
from gettext import gettext as _
import gtk.glade
gtk.glade.bindtextdomain (DOMAIN)
gtk.glade.textdomain (DOMAIN)

VERSION = "2.17.1"
APPNAME = _("glChess")

# grab the proper subdirectory, assuming we're in
# lib/python/site-packages/glchess/
# special case our standard debian install, which puts
# all the python libraries into /usr/share/glchess
if __file__.find('/usr/share/glchess')==0:
    usr='/usr'
elif __file__.find('/usr/local/share/glchess')==0:
    usr='/usr/local'
else:
    usr=os.path.split(os.path.split(os.path.split(os.path.split(os.path.split(__file__)[0])[0])[0])[0])[0]
    # add share/glchess
    # this assumes the user only specified a general build
    # prefix. If they specified data and lib prefixes, we're
    # screwed. See the following email for details:
    # http://mail.python.org/pipermail/python-list/2004-May/220700.html

if usr:
    APP_DATA_DIR = os.path.join(usr,'share')
    ICON_DIR =     os.path.join(APP_DATA_DIR,'pixmaps')
    IMAGE_DIR = os.path.join(ICON_DIR,'glchess')
    GLADE_DIR = os.path.join(APP_DATA_DIR,'glchess')
    BASE_DIR = os.path.join(APP_DATA_DIR,'glchess')
else:
    ICON_DIR = '../../textures'
    IMAGE_DIR = '../../textures'
    GLADE_DIR = '../../glade'
    BASE_DIR = '../../data'

DATA_DIR = os.path.expanduser('~/.gnome2/glchess/')

def initialize_games_dir ():
    if not os.path.exists(DATA_DIR): os.makedirs(DATA_DIR)

