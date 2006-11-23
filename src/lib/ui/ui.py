"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

class ViewFeedback:
    """Template class for feedback from a view object"""
    
    def saveGame(self, path):
        """Called when the user requests the game in this view to be saved.
        
        'path' is the path to the file to save to (string).
        """
        print 'Save game to ' + path
    
    def renderGL(self):
        """Render the scene using OpenGL"""
        pass
    
    def renderCairoStatic(self, context):
        """Render the static elements of the scene.
        
        'context' is the cairo context to modify.
        
        Return False if the static elements have not changed otherwise True.
        """
        return False
    
    def renderCairoDynamic(self, context):
        """Render the dynamic elements of the scene.
        
        'context' is the cairo context to modify.
        """
        pass
    
    def reshape(self, width, height):
        """This method is called when the UI resizes the scene.
        
        'width' is the new width of the scene in pixels (integer).
        'height' is the new height of the scene in pixels (integer).
        """
        pass
    
    def select(self, x, y):
        """This method is called when the UI selects a position on the scene.
        
        'x' is the horizontal pixel location when the user has selected (integer, 0 = left pixel).
        'y' is the vertical pixel location when the user has selected (integer, 0 = top pixel).
        """
        pass
    
    def deselect(self, x, y):
        """This method is called when the UI deselects a position on the scene.
        
        'x' is the horizontal pixel location when the user has selected (integer, 0 = left pixel).
        'y' is the vertical pixel location when the user has selected (integer, 0 = top pixel).
        """
        pass
    
    def setMoveNumber(self, moveNumber):
        """This method is called when the UI changes the move to render.
        
        'moveNumber' is the moveNumber to watch (integer, negative numbers index from latest move).
        """
        pass

    def getFileName(self):
        """Get the file name to save to.
        
        Returns the file name (string) or None if game is not saved.
        """
        return None
    
    def needsSaving(self):
        """Check if this game needs saving.
        
        Return True if it does otherwise False.
        """
        return False
    
    def save(self, filename = None):
        """Save the game using this view.
        
        'filename' is the file to save to (string or None to save to last filename).
        """
        pass

    def close(self):
        """This method is called when the user requests this view be closed"""
        pass

class ViewController:
    """Template class for methods to control a view"""
    
    def addMove(self, move):
        """Register a move with this view.
        
        'move' TODO
        """
        pass
    
    def render(self):
        """Request this view is redrawn"""
        pass
    
    def close(self):
        """Close this view"""
        pass

class UI:
    """Template class for a glChess UI.
    """
    
    # Methods for glChess to implement
    
    def onAnimate(self, timeStep):
        """Called when an animation tick occurs.
        
        'timeStep' is the time between the last call to this method in seconds (float).
        
        Return True if animation should continue otherwise False
        """
        return False

    def onReadFileDescriptor(self, fd):
        """Called when a file descriptor is able to be read.
        
        'fds' is the file descriptor with available data to read (integer).
        
        Return False when finished otherwise True.
        """
        pass

    def onGameStart(self, gameName, allowSpectators, whiteName, whiteType, blackName, blackType, moves = None):
        """Called when a local game is started.
        
        'gameName' is the name of the game to create (string).
        'allowSpectators' is a flag to show if remote clients can watch this game (True or False).
        'whiteName' is the name of the white player.
        'whiteType' is the local player type. PLAYER_* or the AI type (string) or None for open.
        'blackName' is the name of the black player.
        'blackType' is the black player type. PLAYER_* or the AI type (string) or None for open.
        'moves' is a list of moves (strings) to start the game with.
        """
        pass
    
    def loadGame(self, path, returnResult):
        """Called when a game is loaded.
        
        'path' is the path to the game to load (string).
        'returnResult' is a flag to show if the UI requires the result of the load.
                       If True call reportGameLoaded() if the game can be loaded.
        """
        msg = 'Loading game ' + path
        if configureGame:
            msg += ' after configuring'
        print msg
    
    def onGameJoin(self, localName, localType, game):
        """Called when a network game is started (remote server).
        
        'localName' is the name of the local player (string).
        'localType' is the local player type. PLAYER_* or the AI type (string).
        'game' is the game to join (as passed in addNetworkGame).
        """
        pass
    
    def onNetworkServerSearch(self, hostName=None):
        """Called when the user searches for servers.
        
        'hostName' is the name of the host to look for servers on (string) or
                   None if search whole network.
        """
        pass
    
    def onNetworkGameStart(self, localName, localType, serverHost, serverId):
        """Called when a network game is started (remote server).
        
        'localName' is the name of the local player (string).
        'localType' is the local player type. PLAYER_* or the AI type (string).
        'serverHost' is the hostname of the server to connect to.
        'serverId' is the ID of the server to connect to.
        """
        pass
    
    def onNetworkGameServerStart(self, localName, localType, serverName):
        """Called when a network game is started (local server).
        
        'localName' is the name of the local player (string).
        'localType' is the local player type. PLAYER_* or the AI type (string).
        'serverName' is the name of the server to start.
        """
        pass

    def onQuit(self):
        """Called when the user quits the program"""
        pass
    
    # Methods for the UI to implement
    
    def startAnimation(self):
        """Start the animation callback"""
        pass
    
    def watchFileDescriptor(self, fd):
        """Notify when a file descriptor is able to be read.
        
        'fd' is the file descriptor to watch (integer).
        
        When data is available onReadFileDescriptor() is called.
        """
        pass
    
    def setDefaultView(self, feedback):
        """Set the default view to render.
        
        'feedback' is a object to report view events with (extends ViewFeedback).
        
        This will override the previous default view.
        
        Returns a view controller object (extends ViewController).
        """
        return None
    
    def addView(self, title, feedback):
        """Add a view to the UI.
        
        'title' is the title for the view (string).
        'feedback' is a object to report view events with (extends ViewFeedback).
        
        Returns a view controller object (extends ViewController).
        """
        return None
    
    def reportError(self, title, error):
        """Report an error.
        
        'title' is the title of the error (string).
        'error' is the description of the error (string).
        """
        pass

    def reportGameLoaded(self, gameName = None,
                         whiteName = None, blackName = None,
                         whiteAI = None, blackAI = None, moves = None):
        """Report a loaded game as required by onGameLoad().
        
        'gameName' is the name of the game (string) or None if unknown.
        'whiteName' is the name of the white player (string) or None if unknown.
        'blackName' is the name of the white player (string) or None if unknown.
        'whiteAI' is the type of AI the white player is (string) or None if no AI.
        'blackAI' is the type of AI the black player is (string) or None if no AI.
        'moves' is a list of moves (strings) that the have already been made.
        """
        pass
    
    def addNetworkGame(self, name, game):
        """Report a detected network game.
        
        'name' is the name of the network game (string).
        'game' is the game detected (user-defined).
        """
        pass
    
    def removeNetworkGame(self, game):
        """Report a network game as terminated.
        
        'game' is the game that has removed (as registered with addNetworkGame()).
        """
        pass
        
