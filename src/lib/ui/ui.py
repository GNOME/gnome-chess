"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

class Player:
    # Name of the player
    name = ''
    
    # The AI type or '' for human
    type = ''
    
    # The AI difficulty level
    level = ''
    
class Game:
    name = ''
    
    path = ''
    
    duration = 0
    
    allowSpectators = False
    
    def __init__(self):
        self.white = Player()
        self.black = Player()
        self.moves = []
    
class NetworkFeedback:
    """Template class for feedback from a network game selector"""
    
    def setProfile(self, profile):
        pass
    
    def joinRoom(self, room):
        pass
    
    def joinTable(self, table):
        pass
    
class NetworkController:
    """"""
    
    def setVisible(self, isVisible):
        pass
    
    def addProfile(self, profile, name):
        pass
    
    def setBusy(self, isBusy):
        pass
    
    def addChat(self, user, channel, text):
        """Add chat 
        """
        pass
    
    def addRoom(self, index, name, description, room, protocol):
        """Add a game room.
        
        'index' ???
        'name' is the name of the room (string).
        'description' is a description of the room (string).
        'room' is the room to add (user-defined)
        'protocol' ???
        """
        pass

    def removeRoom(self, room):
        pass
    
    def clearRooms(self):
        pass
    
    def addTable(self, name, table):
        pass

    def removeTable(self, table):
        pass
    
    def clearTables(self):
        pass
    
    def addPlayer(self, player, name, icon):
        pass
    
    def removePlayer(self, player):
        pass
    
    def clearPlayers(self):
        pass

    def addAdvert(self, title, rating, advert):
        """Add a game advert.
        
        'title' is the title of the advert (string).
        'rating' is the rating for this game (string).
        'advert' is an object to key this advert with (user-defined).
        """
        pass
        
    def removeAdvert(self, advert):
        """Remove a game advert.
        
        'advert' is an object that was passed into addAdvert().
        """
        pass
    
    def requestGame(self, gameName):
        """Request this player joins a game.
        
        'gameName' is the name of the game this player requested to join (string).
        """
        pass
    
class ViewFeedback:
    """Template class for feedback from a view object"""
    
    def showMoveHints(self, showHints):
        """Configure move hinting.
        
        'showHints' sets if move hints should be shown (boolean).
        """
        pass
    
    def saveGame(self, path):
        """Called when the user requests the game in this view to be saved.
        
        'path' is the path to the file to save to (string).
        
        Returns the error that occured (string) or None if successful.
        """
        print 'Save game to ' + path
        return None
    
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
    
    def regsign(self):
        """Indicates the human player wants to resign"""
        pass
    
    def claimDraw(self):
        """Indicates the human player wants to claim a draw"""
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
    
    def setWhiteTimer(self, total, remaining):
        """Set the time remaining for the white player.
        
        'total' FIXME TODO
        'remaining' FIXME TODO
        """
        pass

    def setBlackTimer(self, total, remaining):
        """Set the time remaining for the black player.
        
        'total' FIXME TODO
        'remaining' FIXME TODO
        """
        pass

    def setAttention(self, requiresAttention):
        """Get the users attention for this view.
        
        'requiresAttention' is a flag to show if this view requires attention.
        """
        pass

class UIFeedback:
    """Template class for feedback from a UI"""
    
    def onAnimate(self, timeStep):
        """Called when an animation tick occurs.
        
        'timeStep' is the time between the last call to this method in seconds (float).
        
        Return True if animation should continue otherwise False
        """
        return False

    def onReadFileDescriptor(self, fd):
        """Called when a file descriptor is able to be read.
        
        'fd' is the file descriptor with available data to read (integer).
        
        Return False when finished otherwise True.
        """
        return False

    def onWriteFileDescriptor(self, fd):
        """Called when a file descriptor can be written to.
        
        'fd' is the file descriptor that can be written to (integer).
        
        Return False if writing is completed otherwise True
        """
        return False
    
    def onGameStart(self, game):
        """Called when a local game is started.
        
        'game' is the game propertied (Game).
        """
        pass
    
    def loadGame(self, path):
        """Called when a game is loaded.
        
        'path' is the path to the game to load (string).
        
        Returns the error that occured (string) or None if successful.
        """
        print 'Loading game ' + path
        return None

    def onNewNetworkGame(self):
        """
        """
        pass

    def onQuit(self):
        """Called when the user quits the program"""
        pass
    
class TimerFeedback:
    """
    """
    
    def onTick(self, time):
        """Called when the timer hits a one second boundary.
        
        'time' is the boundary time in seconds.
        """
        pass
    
    def onExpired(self):
        """Called when this timer expires"""
        pass
    
class Timer:
    """
    """
    
    def getRemaining(self):
        """Get the amount of time remaining on this clock.
        
        returns the amount of time in milliseconds (int)
        """
        pass
       
    def pause(self):
        """Stop this timer from counting down"""
        pass
    
    def run(self):
        """Continue counting down"""
        pass
    
    def delete(self):
        """Delete this timer"""
        pass
    
class Log:
    """
    """
        
    def addBinary(self, data, style = None):
        """
        """
        pass

    def addText(self, text, style = None):
        """
        """
        pass
    
    def addLine(self, text, style = None):
        """
        """
        pass

    def close(self):
        """
        """

class UI:
    """Template class for a glChess UI.
    """
    
    def __init__(self, feedback):
        """Constructor.
        
        'feedback' is the feedback object for this UI to report with (extends UIFeedback).
        """
        pass
    
    def addLogWindow(self, title, executable, description):
        pass
    
    def startAnimation(self):
        """Start the animation callback"""
        pass
    
    def watchFileDescriptor(self, fd):
        """Notify when a file descriptor is able to be read.
        
        'fd' is the file descriptor to watch (integer).
        
        When data is available onReadFileDescriptor() is called.
        """
        pass
    
    def writeFileDescriptor(self, fd):
        """Notify when a file descriptor can be written to.
        
        'fd' is the file descriptor to write (integer).
        
        When data can be written onWriteFileDescriptor is called.
        """
        pass
    
    def addTimer(self, feedback, duration):
        """Add a timer.
        
        'feedback' is an object containing methods to call for feedback (extends TimerFeedback).
        'duration' is the period to call this method at in seconds (integer).
        
        returns a timer object to control this timer (extends Timer).
        """
        return None

    def setView(self, title, feedback, isPlayable = True):
        """Set the view to display.
        
        'title' is the title for the view (string).
        'feedback' is a object to report view events with (extends ViewFeedback).
        'isPlayable' is True if this view can be played.
        
        Returns a view controller object (extends ViewController).
        """
        return None
    
    def addNetworkDialog(self, feedback):
        """
        'feedback' is a object to report view events with (extends NetworkFeedback).
        
        Returns a network controller object (excends NetworkController).
        """
        return None
    
    def reportGameLoaded(self, game):
        """Report a loaded game as required by onGameLoad().
        
        'game' is the game properties (Game).
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
        
    def close(self):
        """Report the application has ended"""
        pass
