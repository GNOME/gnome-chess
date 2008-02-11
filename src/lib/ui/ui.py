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
    
    path = None
    
    duration = 0
    
    allowSpectators = False
    
    def __init__(self):
        self.white = Player()
        self.black = Player()
        self.moves = []
    
class NetworkFeedback:
    """Template class for feedback from a network game selector"""
    
    def setProfile(self, profile):
        assert(False)
    
    def joinRoom(self, room):
        assert(False)
    
    def joinTable(self, table):
        assert(False)
    
class NetworkController:
    """"""
    
    def setVisible(self, isVisible):
        assert(False)
    
    def addProfile(self, profile, name):
        assert(False)
    
    def setBusy(self, isBusy):
        assert(False)
    
    def addChat(self, user, channel, text):
        """Add chat 
        """
        assert(False)
    
    def addRoom(self, index, name, description, room, protocol):
        """Add a game room.
        
        'index' ???
        'name' is the name of the room (string).
        'description' is a description of the room (string).
        'room' is the room to add (user-defined)
        'protocol' ???
        """
        assert(False)

    def removeRoom(self, room):
        assert(False)
    
    def clearRooms(self):
        assert(False)
    
    def addTable(self, name, table):
        assert(False)

    def removeTable(self, table):
        assert(False)
    
    def clearTables(self):
        assert(False)
    
    def addPlayer(self, player, name, icon):
        assert(False)
    
    def removePlayer(self, player):
        assert(False)
    
    def clearPlayers(self):
        assert(False)

    def addAdvert(self, title, rating, advert):
        """Add a game advert.
        
        'title' is the title of the advert (string).
        'rating' is the rating for this game (string).
        'advert' is an object to key this advert with (user-defined).
        """
        assert(False)
        
    def removeAdvert(self, advert):
        """Remove a game advert.
        
        'advert' is an object that was passed into addAdvert().
        """
        assert(False)
    
    def requestGame(self, gameName):
        """Request this player joins a game.
        
        'gameName' is the name of the game this player requested to join (string).
        """
        assert(False)
    
class ViewFeedback:
    """Template class for feedback from a view object"""
    
    def showMoveHints(self, showHints):
        """Configure move hinting.
        
        'showHints' sets if move hints should be shown (boolean).
        """
        assert(False)
    
    def saveGame(self, path):
        """Called when the user requests the game in this view to be saved.
        
        'path' is the path to the file to save to (string).
        
        Returns the error that occured (string) or None if successful.
        """
        assert(False)
    
    def renderGL(self):
        """Render the scene using OpenGL"""
        assert(False)
    
    def renderCairoStatic(self, context):
        """Render the static elements of the scene.
        
        'context' is the cairo context to modify.
        
        Return False if the static elements have not changed otherwise True.
        """
        assert(False)
    
    def renderCairoDynamic(self, context):
        """Render the dynamic elements of the scene.
        
        'context' is the cairo context to modify.
        """
        assert(False)
    
    def reshape(self, width, height):
        """This method is called when the UI resizes the scene.
        
        'width' is the new width of the scene in pixels (integer).
        'height' is the new height of the scene in pixels (integer).
        """
        assert(False)
    
    def select(self, x, y):
        """This method is called when the UI selects a position on the scene.
        
        'x' is the horizontal pixel location when the user has selected (integer, 0 = left pixel).
        'y' is the vertical pixel location when the user has selected (integer, 0 = top pixel).
        """
        assert(False)
    
    def deselect(self, x, y):
        """This method is called when the UI deselects a position on the scene.
        
        'x' is the horizontal pixel location when the user has selected (integer, 0 = left pixel).
        'y' is the vertical pixel location when the user has selected (integer, 0 = top pixel).
        """
        assert(False)
    
    def setMoveNumber(self, moveNumber):
        """This method is called when the UI changes the move to render.
        
        'moveNumber' is the moveNumber to watch (integer, negative numbers index from latest move).
        """
        assert(False)

    def getFileName(self):
        """Get the file name to save to.
        
        Returns the file name (string) or None if game is not saved.
        """
        assert(False)

    def save(self, filename = None):
        """Save the game using this view.
        
        'filename' is the file to save to (string or None to save to last filename).
        """
        assert(False)
    
    def regsign(self):
        """Indicates the human player wants to resign"""
        assert(False)
    
    def claimDraw(self):
        """Indicates the human player wants to claim a draw"""
        assert(False)

class ViewController:
    """Template class for methods to control a view"""
    
    def setTitle(self, title):
        """Set the title for this view.
        
        'title' is the title to use (string).
        """
        assert(False)
        
    def setNeedsSaving(self, needsSaving):
        """Mark if this view needs saving.
        
        'needsSaving' True if this view needs saving.
        """
        assert(False)

    def addMove(self, move):
        """Register a move with this view.
        
        'move' is the move made (string).
        """
        assert(False)
    
    def render(self):
        """Request this view is redrawn"""
        assert(False)
    
    def setWhiteTimer(self, total, remaining):
        """Set the time remaining for the white player.
        
        'total' FIXME TODO
        'remaining' FIXME TODO
        """
        assert(False)

    def setBlackTimer(self, total, remaining):
        """Set the time remaining for the black player.
        
        'total' FIXME TODO
        'remaining' FIXME TODO
        """
        assert(False)

    def setAttention(self, requiresAttention):
        """Get the users attention for this view.
        
        'requiresAttention' is a flag to show if this view requires attention.
        """
        assert(False)

class UIFeedback:
    """Template class for feedback from a UI"""
    
    def onAnimate(self, timeStep):
        """Called when an animation tick occurs.
        
        'timeStep' is the time between the last call to this method in seconds (float).
        
        Return True if animation should continue otherwise False
        """
        assert(False)

    def onReadFileDescriptor(self, fd):
        """Called when a file descriptor is able to be read.
        
        'fd' is the file descriptor with available data to read (integer).
        
        Return False when finished otherwise True.
        """
        assert(False)

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
        assert(False)
    
    def loadGame(self, path):
        """Called when a game is loaded.
        
        'path' is the path to the game to load (string).
        
        Returns the error that occured (string) or None if successful.
        """
        assert(False)

    def onNewNetworkGame(self):
        """
        """
        assert(False)

    def onQuit(self):
        """Called when the user quits the program"""
        assert(False)
    
class TimerFeedback:
    """
    """
    
    def onTick(self, time):
        """Called when the timer hits a one second boundary.
        
        'time' is the boundary time in seconds.
        """
        assert(False)
    
    def onExpired(self):
        """Called when this timer expires"""
        assert(False)
    
class Timer:
    """
    """
    
    def getRemaining(self):
        """Get the amount of time remaining on this clock.
        
        returns the amount of time in milliseconds (int)
        """
        assert(False)
       
    def pause(self):
        """Stop this timer from counting down"""
        assert(False)
    
    def run(self):
        """Continue counting down"""
        assert(False)
    
    def delete(self):
        """Delete this timer"""
        assert(False)
    
class Log:
    """
    """
        
    def addBinary(self, data, style = None):
        """
        """
        assert(False)

    def addText(self, text, style = None):
        """
        """
        assert(False)
    
    def addLine(self, text, style = None):
        """
        """
        assert(False)

    def close(self):
        """
        """
        assert(False)
        
SAVE_YES   = 'SAVE_YES'
SAVE_NO    = 'SAVE_NO'
SAVE_ABORT = 'SAVE_ABORT'

class UI:
    """Template class for a glChess UI.
    """
    
    def __init__(self, feedback):
        """Constructor.
        
        'feedback' is the feedback object for this UI to report with (extends UIFeedback).
        """
        assert(False)
    
    def addLogWindow(self, title, executable, description):
        assert(False)
    
    def startAnimation(self):
        """Start the animation callback"""
        assert(False)
    
    def watchFileDescriptor(self, fd):
        """Notify when a file descriptor is able to be read.
        
        'fd' is the file descriptor to watch (integer).
        
        When data is available onReadFileDescriptor() is called.
        """
        assert(False)

    def unwatchFileDescriptor(self, fd):
        assert(False)
        
    def writeFileDescriptor(self, fd):
        """Notify when a file descriptor can be written to.
        
        'fd' is the file descriptor to write (integer).
        
        When data can be written onWriteFileDescriptor is called.
        """
        assert(False)
    
    def addTimer(self, feedback, duration):
        """Add a timer.
        
        'feedback' is an object containing methods to call for feedback (extends TimerFeedback).
        'duration' is the period to call this method at in seconds (integer).
        
        returns a timer object to control this timer (extends Timer).
        """
        assert(False)

    def setView(self, title, feedback, isPlayable = True):
        """Set the view to display.
        
        'title' is the title for the view (string).
        'feedback' is a object to report view events with (extends ViewFeedback).
        'isPlayable' is True if this view can be played.
        
        Returns a view controller object (extends ViewController).
        """
        assert(False)
    
    def addNetworkDialog(self, feedback):
        """
        'feedback' is a object to report view events with (extends NetworkFeedback).
        
        Returns a network controller object (excends NetworkController).
        """
        assert(False)
    
    def reportGameLoaded(self, game):
        """Report a loaded game as required by onGameLoad().
        
        'game' is the game properties (Game).
        """
        assert(False)
    
    def addNetworkGame(self, name, game):
        """Report a detected network game.
        
        'name' is the name of the network game (string).
        'game' is the game detected (user-defined).
        """
        assert(False)
    
    def removeNetworkGame(self, game):
        """Report a network game as terminated.
        
        'game' is the game that has removed (as registered with addNetworkGame()).
        """
        assert(False)
    
    def requestSave(self, title):
        """Request a game is saved.
        
        'title' is the request to make to the user.
        
        Returns SAVE_YES, SAVE_NO or SAVE_ABORT.
        """
        assert(False)
        
    def close(self):
        """Report the application has ended"""
        assert(False)
