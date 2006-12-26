__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
import sys
import select
import signal
import termios
import xml.dom.minidom

import game
import cecp
import uci

from defaults import *

CECP = 'CECP'
UCI  = 'UCI'

class Option:
    """
    """
    value = ''

class Level:
    """
    """
    options = None
    
    def __init__(self):
        self.options = []

class Profile:
    """
    """
    name       = ''
    protocol   = ''
    executable = ''
    path       = ''
    arguments  = None
    profiles   = None
    
    def __init__(self):
        self.arguments = []
        self.profiles = {}

    def detect(self):
        """
        """
        try:
            path = os.environ['PATH'].split(os.pathsep)
        except KeyError:
            path = []

        for directory in path:
            b = directory + os.sep + self.executable
            if os.path.isfile(b):
                self.path = b
                return
        self.path = None
        
def _getXMLText(node):
    """
    """
    if len(node.childNodes) == 0:
        return ''
    if len(node.childNodes) > 1 or node.childNodes[0].nodeType != node.TEXT_NODE:
        raise ValueError
    return node.childNodes[0].nodeValue

def _loadLevel(node):
    """
    """
    level = Level()
    n = node.getElementsByTagName('name')
    if len(n) != 1:
        return None
    level.name = _getXMLText(n[0])
    
    for e in node.getElementsByTagName('option'):
        option = Option()
        option.value = _getXMLText(e)
        try:
            attribute = e.attributes['name']
        except KeyError:
            pass
        else:
            option.name = _getXMLText(attribute)
        level.options.append(option)
        
    return level

def loadProfiles():
    """
    """
    profiles = []
    
    fileNames = [os.path.expanduser(LOCAL_AI_CONFIG), os.path.join(BASE_DIR, 'ai.xml'), 'ai.xml']
    document = None
    for f in fileNames:
        try:
            document = xml.dom.minidom.parse(f)
        except IOError:
            pass
        except xml.parsers.expat.ExpatError:
            print 'AI configuration at ' + f + ' is invalid, ignoring'
        else:
            print 'Loading AI configuration from ' + f
            break
    if document is None:
        print 'WARNING: No AI configuration'
        return profiles

    elements = document.getElementsByTagName('aiconfig')
    if len(elements) == 0:
        return profiles

    for e in elements:
        for p in e.getElementsByTagName('ai'):
            try:
                protocolName = p.attributes['type'].nodeValue
            except KeyError:
                assert(False)
            if protocolName == 'cecp':
                protocol = CECP
            elif protocolName == 'uci':
                protocol = UCI
            else:
                assert(False), 'Uknown AI type: ' + repr(protocolName)
            
            n = p.getElementsByTagName('name')
            assert(len(n) > 0)
            name = _getXMLText(n[0])
            
            n = p.getElementsByTagName('binary')
            assert(len(n) > 0)
            executable = _getXMLText(n[0])
            
            arguments = [executable]
            for x in p.getElementsByTagName('argument'):
                arguments.append(_getXMLText(x))

            levels = {}
            for x in p.getElementsByTagName('level'):
                level = _loadLevel(x)
                if level is not None:
                    levels[level.name] = level

            profile = Profile()
            profile.name       = name
            profile.protocol   = protocol
            profile.executable = executable
            profile.arguments  = arguments
            profile.levels     = levels
            profiles.append(profile)
    
    return profiles

class CECPConnection(cecp.Connection):
    """
    """
    player = None
    
    def __init__(self, player):
        """
        """
        self.player = player
        cecp.Connection.__init__(self)
        
    def onOutgoingData(self, data):
        """Called by cecp.Connection"""
        self.player.logText(data, 'output')
        self.player.sendToEngine(data)

    def onMove(self, move):
        """Called by cecp.Connection"""
        self.player.moving = True
        self.player.move(move)
        
    def logText(self, text, style):
        """Called by cecp.Connection"""
        self.player.logText(text, style)

class UCIConnection(uci.StateMachine):
    """
    """
    player = None
    
    def __init__(self, player):
        """
        """
        self.player = player
        uci.StateMachine.__init__(self)
        
    def onOutgoingData(self, data):
        """Called by uci.StateMachine"""
        self.player.logText(data, 'output')
        self.player.sendToEngine(data)
        
    def logText(self, text, style):
        """Called by uci.StateMachine"""
        self.player.logText(text, style)

    def onMove(self, move):
        """Called by uci.StateMachine"""
        self.player.move(move)

class Player(game.ChessPlayer):
    """
    """    
    # The profile we are using
    __profile    = None
    __level      = None
        
    # File object to engine stdin/out/err
    __fd         = None
    
    __connection = None
    
    moving = False
    
    def __init__(self, name, profile, level = 'normal'):
        """Constructor for an AI player.
        
        'name' is the name of the player (string).
        'profile' is the profile to use for the AI (Profile).
        'level' is the difficulty level to use (string).
        """
        self.__profile = profile
        self.__level = level

        game.ChessPlayer.__init__(self, name)
        
        (self.__pid, self.__fd) = os.forkpty()
        if self.__pid == 0:
            os.nice(10)
            try:
                os.execv(profile.path, profile.arguments)
            except OSError:
                pass
            os._exit(0)
            
        # Stop our commands being echod back
        (iflag, oflag, cflag, lflag, ispeed, ospeed, cc) = termios.tcgetattr(self.__fd)
        lflag &= ~termios.ECHO
        termios.tcsetattr(self.__fd, termios.TCSANOW, [iflag, oflag, cflag, lflag, ispeed, ospeed, cc])
        
        if profile.protocol == CECP:
            self.connection = CECPConnection(self)
        elif profile.protocol == UCI:
            self.connection = UCIConnection(self)
        else:
            assert(False)
            
        self.connection.start()
        self.connection.startGame()
        try:
            level = self.__profile.levels[self.__level]
        except KeyError:
            self.connection.configure()
        else:
            self.connection.configure(level.options)

    # Methods to extend
    
    def logText(self, text, style):
        """
        """
        pass
        
    # Public methods
    
    def getProfile(self):
        """Get the AI profile this AI is using.
        
        Returns a 2-tuple containing the profile name (str) and the difficulty level (str).
        """
        return (self.__profile.name, self.__level)
    
    def fileno(self):
        """Returns the file descriptor for communicating with the engine (integer)"""
        return self.__fd

    def read(self):
        """Read an process data from the engine.
        
        This is non-blocking.
        """
        while True:
            # Check if data is available
            (rlist, _, _) = select.select([self.__fd], [], [], 0)
            if len(rlist) == 0:
                return
            
            # Read a chunk and process
            try:
                data = os.read(self.__fd, 256)
            except OSError, e:
                print 'Error reading from chess engine: ' + str(e)
                return
            if data == '':
                return
            self.connection.registerIncomingData(data)

    def sendToEngine(self, data):
        """
        """
        try:
            os.write(self.__fd, data)
        except OSError, e:
            print 'Failed to write to engine: ' + str(e)

    def quit(self):
        """Disconnect the AI"""
        # Wait for the pipe to close
        # There must be a better way of doing this!
        count = 0
        while True:
            select.select([], [], [], 0.1)
            try:
                os.write(self.__fd, '\nquit\n') # FIXME: CECP specific
            except OSError:
                return
            count += 1
            if count > 5:
                break
        
        print 'Killing AI'
        os.kill(self.__pid, signal.SIGKILL)

    # Extended methods
    
    def onPlayerMoved(self, player, move):
        """Called by game.ChessPlayer"""
        isSelf = player is self and self.moving
        self.moving = False
        self.connection.reportMove(move.canMove, isSelf)
    
    def readyToMove(self):
        """Called by game.ChessPlayer"""
        self.connection.requestMove()
        
    def onGameEnded(self, winningPlayer = None):
        """Called by game.ChessPlayer"""
        self.quit()
