__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
import sys
import select
import signal
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
    def __init__(self):
        self.options = []

class Profile:
    """
    """   
    def __init__(self):
        self.name = ''
        self.protocol = ''
        self.path = ''
        self.executables = []
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
            for executable in self.executables:
                b = directory + os.sep + executable
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
            print 'AI configuration from %s is invalid, ignoring' % f
        else:
            #print 'Loading AI configuration from %s' % f
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
                assert(False), 'Uknown AI type: %s' % repr(protocolName)
            
            n = p.getElementsByTagName('name')
            assert(len(n) > 0)
            name = _getXMLText(n[0])

            executables = []
            n = p.getElementsByTagName('binary')
            assert(len(n) > 0)
            for x in n:
                executables.append(_getXMLText(x))

            arguments = []
            for x in p.getElementsByTagName('argument'):
                arguments.append(_getXMLText(x))

            levels = {}
            for x in p.getElementsByTagName('level'):
                level = _loadLevel(x)
                if level is not None:
                    levels[level.name] = level

            profile = Profile()
            profile.name        = name
            profile.protocol    = protocol
            profile.executables = executables
            profile.arguments   = arguments
            profile.levels      = levels
            profiles.append(profile)
    
    return profiles

class CECPConnection(cecp.Connection):
    """
    """
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
        if self.player.isReadyToMove():
            self.player.moving = True
            self.player.move(move)
        else:
            assert(self.player.suppliedMove is None)
            self.player.suppliedMove = move
        
    def logText(self, text, style):
        """Called by cecp.Connection"""
        self.player.logText(text, style)

class UCIConnection(uci.StateMachine):
    """
    """
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
    def __init__(self, name, profile, level = 'normal'):
        """Constructor for an AI player.
        
        'name' is the name of the player (string).
        'profile' is the profile to use for the AI (Profile).
        'level' is the difficulty level to use (string).
        """
        self.__profile = profile
        self.__level = level
        
        self.moving = False
        self.suppliedMove = None

        game.ChessPlayer.__init__(self, name)
        
        # Pipe to communicate to engine with
        toManagerPipe = os.pipe()
        fromManagerPipe = os.pipe()
        
        # Store the file descripter for reading/writing
        self.__toEngineFd = toManagerPipe[1]
        self.__fromEngineFd = fromManagerPipe[0]
        
        # Catch if the child dies
        def cDied(sig, stackFrame):
            try:
                os.waitpid(-1, os.WNOHANG)
            except OSError:
                pass
        signal.signal(signal.SIGCHLD, cDied)

        # Fork off a child process to manage the engine
        if os.fork() == 0:
            # ..
            os.close(toManagerPipe[1])
            os.close(fromManagerPipe[0])
            
            # Make pipes to the engine
            stdinPipe = os.pipe()
            stdoutPipe = os.pipe()
            stderrPipe = os.pipe()
            
            # Fork off the engine
            engineFd = os.fork()
            if engineFd == 0:
                # Make the engine low priority for CPU usage
                os.nice(19)
                
                # Change directory so any log files are not in the users home directory
                try:
                    os.mkdir(LOG_DIR)
                except OSError:
                    pass
                try:
                    os.chdir(LOG_DIR)
                except OSError:
                    pass
                
                # Connect stdin, stdout and stderr to the manager process
                os.dup2(stdinPipe[0], sys.stdin.fileno())
                os.dup2(stdoutPipe[1], sys.stdout.fileno())
                os.dup2(stderrPipe[1], sys.stderr.fileno())
                
                # Execute the engine
                try:
                    os.execv(profile.path, [profile.path] + profile.arguments)
                except OSError:
                    pass
                os._exit(0)
                
            # Catch if the child dies
            def childDied(sig, stackFrame):
                try:
                    os.waitpid(-1, os.WNOHANG)
                except OSError:
                    return
                
                # Close connection to the application
                os.close(fromManagerPipe[1])
                    
                os._exit(0)
            signal.signal(signal.SIGCHLD, childDied)

            # Forward data between the application and the engine and wait for closed pipes
            inputPipes = [toManagerPipe[0], stdoutPipe[0], stderrPipe[0]]
            pipes = [toManagerPipe[0], toManagerPipe[1], stdinPipe[0], stdinPipe[1], stdoutPipe[0], stdoutPipe[1], stderrPipe[0], stderrPipe[1]]
            while True:                
                # Wait for data
                (rfds, _, xfds) = select.select(inputPipes, [], pipes, None)
                
                for fd in rfds:
                    data = os.read(fd, 65535)
                    
                    # One of the connections has closed - kill the engine and quit
                    if len(data) == 0:
                        try:
                            os.kill(engineFd, signal.SIGQUIT)
                        except OSError:
                            pass
                        os._exit(0)
                    
                    # Send data from the application to the engines stdin
                    if fd == toManagerPipe[0]:
                        os.write(stdinPipe[1], data)
                    # Send engine output to the application
                    else:
                        os.write(fromManagerPipe[1], data)

            os._exit(0)
            
        os.close(toManagerPipe[0])
        os.close(fromManagerPipe[1])

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
        return self.__fromEngineFd

    def read(self):
        """Read an process data from the engine.
        
        This is non-blocking.
        """       
        while True:
            # Connection was closed
            if self.__fromEngineFd == None:
                return False

            # Check if data is available
            (rlist, _, _) = select.select([self.__fromEngineFd], [], [], 0)
            if len(rlist) == 0:
                return True

            # Read a chunk and process
            try:
                data = os.read(self.__fromEngineFd, 256)
            except OSError, e:
                print 'Error reading from chess engine: ' + str(e)
                self.die()
                return False
            if len(data) == 0:
                print 'Engine has died'
                self.die()
                return False
            self.connection.registerIncomingData(data)

    def sendToEngine(self, data):
        """
        """
        if self.__toEngineFd == None:
            return
        
        try:
            os.write(self.__toEngineFd, data)
        except OSError, e:
            print 'Failed to write to engine: ' + str(e)

    def quit(self):
        """Disconnect the AI"""
        fd = self.__toEngineFd
        self.__toEngineFd = None
        self.__fromEngineFd = None
        
        # Send quit
        try:
            os.write(fd, '\nquit\n') # FIXME: CECP specific
        except:
            return

    # Extended methods
    
    def onPlayerMoved(self, player, move):
        """Called by game.ChessPlayer"""
        isSelf = player is self and self.moving
        self.moving = False
        self.connection.reportMove(move.canMove, isSelf)

    def readyToMove(self):
        """Called by game.ChessPlayer"""
        game = self.getGame()
        whiteTime = game.getWhite().getRemainingTime()
        blackTime = game.getBlack().getRemainingTime()
        if game.getWhite() is self:
            ownTime = whiteTime
        else:
            ownTime = blackTime
        
        if self.suppliedMove is None:
            self.connection.requestMove(whiteTime, blackTime, ownTime)
        else:
            self.moving = True
            move = self.suppliedMove
            self.suppliedMove = None
            self.move(move)
        
    def onGameEnded(self, game):
        """Called by game.ChessPlayer"""
        self.quit()
