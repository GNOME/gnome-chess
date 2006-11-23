"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['Application']

import sys
import os
import gettext
import traceback

import ui
import gtkui
import scene.cairo
import scene.opengl
import scene.human
import game
import chess.board
import chess.lan
import ai
from defaults import *

#import dbus.glib
#import network

import chess.pgn

class Config:
    """
    """    
    __directory = None
    
    def __init__(self):
        """Constructor for a confgiuration object"""
        self.__directory = os.path.expanduser('~/.glchess')
        
        # Create the directory if it does not exist
        if not os.path.exists(self.__directory):
            os.mkdir(self.__directory)
        else:
            assert(os.path.isdir(self.__directory))

    def getAutosavePath(self):
        """Get the path to the autosave file"""
        return self.__directory + '/autosave.pgn'

class MovePlayer(game.ChessPlayer):
    """This class provides a pseudo-player to watch for piece movements"""
    # The game to control
    __game = None
    
    # A dictionary of pieces added into the scene
    __pieces = None

    def __init__(self, chessGame):
        """Constructor for a move player.
        
        'chessGame' is the game to make changes to (ChessGame).
        """
        self.__game = chessGame
        game.ChessPlayer.__init__(self, '@move')
        
    # Extended methods

    def onPieceMoved(self, piece, start, end):
        """Called by chess.board.ChessPlayer"""
        self.__game.scene._movePiece(piece, start, end)
        self.__game.cairoScene._movePiece(piece, start, end)
        
    def onPlayerMoved(self, player, move):
        """Called by chess.board.ChessPlayer"""
        self.__game._onPlayerMoved(player, move)

class HumanPlayer(game.ChessPlayer):
    """
    """    
    __game = None
    
    def __init__(self, chessGame, name):
        """Constructor.
        
        'chessGame' is the game this player is in (game.ChessGame).
        'name' is the name of this player (string).
        """
        game.ChessPlayer.__init__(self, name)
        self.__game = chessGame
        
    def readyToMove(self):
        # FIXME: ???
        self.__game.scene.setHumanPlayer(self)
        self.__game.cairoScene.setHumanPlayer(self)

class AIPlayer(ai.Player):
    """
    """
    
    def __init__(self, application, name, profile, description):
        """
        """
        executable = profile.path
        for arg in profile.arguments[1:]:
            executable += ' ' + arg
        self.window = application.ui.addAIWindow(profile.name, executable, description)
        ai.Player.__init__(self, name, profile)
        
    def logText(self, text, style):
        """Called by ai.Player"""
        self.window.addText(text, style)

class SceneCairo(scene.cairo.Scene, scene.human.SceneHumanInput):
    """
    """
    # The game this scene is rendering
    __game = None
    
    # TODO
    __moveNumber   = -1
    __pieceModels  = None
    
    # The current human player or None if not a player in play
    __humanPlayer = None

    def __init__(self, chessGame):
        """
        """
        self.__game = chessGame
        self.__pieceModels = {}

        # Call parent constructors
        scene.human.SceneHumanInput.__init__(self)
        scene.cairo.Scene.__init__(self)

    def setHumanPlayer(self, player):
        """TODO
        """
        self.__humanPlayer = player
        
        # Animate the board
        if player is self.__game.getWhite():
            self.setBoardRotation(0.0)
        elif player is self.__game.getBlack():
            self.setBoardRotation(180.0)
        else:
            assert(False), 'Human player is not white or black'

    def setMoveNumber(self, moveNumber):
        """Set the move number to watch.

        'moveNumber' is the move to watch (integer).
        """
        if self.__moveNumber == moveNumber:
            return
        self.__moveNumber = moveNumber
        
        # Lock the scene if not tracking the game
        self.enableHumanInput(moveNumber == -1)
        
        # Get the state of this scene
        piecesByLocation = self.__game.getAlivePieces(moveNumber)
        
        # Remove any models not present
        requiredPieces = piecesByLocation.values()
        for (piece, model) in self.__pieceModels.items():
            try:
                requiredPieces.index(piece)
            except ValueError:
                self.__pieceModels.pop(piece)
                self.removeChessPiece(model)
        
        # Move the models in the scene
        for (location, piece) in piecesByLocation.iteritems():
            self.__movePiece(piece, location)
            
    def _movePiece(self, piece, start, end):
        """TODO
        """
        # Only allow then watching the active game
        if self.__moveNumber == -1:
            self.__movePiece(piece, end)

    def __movePiece(self, piece, location):
        """
        """
        # Get the model for this piece creating one if it doesn't exist
        try:
            model = self.__pieceModels[piece]
        except KeyError:
            # No need to create if didn't exist anyway
            if location is None:
                return
            
            # Make the new model
            pieceName = {chess.board.PAWN: 'pawn', chess.board.ROOK: 'rook', chess.board.KNIGHT: 'knight',
                         chess.board.BISHOP: 'bishop', chess.board.QUEEN: 'queen', chess.board.KING: 'king'}[piece.getType()]
            chessSet = {chess.board.WHITE: 'white', chess.board.BLACK: 'black'}[piece.getColour()]
            model = self.addChessPiece(chessSet, pieceName, location)
            self.__pieceModels[piece] = model
            
        # Delete or move the model
        if location is None:
            self.__pieceModels.pop(piece)
            self.removeChessPiece(model)
        else:
            model.move(location)

    # Extended methods

    def onRedraw(self):
        """Called by scene.cairo.Scene"""
        if self.__game.view.activeScene is self and self.__game.view is not None:
            self.__game.view.controller.render()

    def startAnimation(self):
        """Called by scene.cairo.Scene"""
        self.__game.application.ui.startAnimation()

    def playerIsHuman(self):
        """Called by scene.human.SceneHumanInput"""
        return self.__humanPlayer is not None

    def squareIsFriendly(self, coord):
        """Called by scene.human.SceneHumanInput"""
        owner = self.__game.getSquareOwner(coord)
        if owner is None:
            return False
        return owner is self.__humanPlayer
    
    def canMove(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        if self.__humanPlayer is None:
            return False

        return self.__humanPlayer.canMove(start, end) # FIXME: Promotion type
    
    def moveHuman(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        player = self.__humanPlayer
        self.__humanPlayer = None
        if player is self.__game.getWhite():
            colour = chess.board.WHITE
        else:
            colour = chess.board.BLACK
        move = chess.lan.encode(colour, start, end, promotionType = chess.board.QUEEN) # FIXME: Promotion type
        player.move(move)

class SceneOpenGL(scene.opengl.Scene, scene.human.SceneHumanInput):
    """
    """
    # The game this scene is rendering
    __game = None
    
    # TODO
    __moveNumber   = -1
    __pieceModels  = None
    
    # The current human player or None if not a player in play
    __humanPlayer = None

    def __init__(self, chessGame):
        """Constructor for a glChess scene.
        
        'chessGame' is the game the scene is rendering (game.ChessGame).
        """
        self.__game = chessGame
        self.__pieceModels = {}

        # Call parent constructors
        scene.human.SceneHumanInput.__init__(self)
        scene.opengl.Scene.__init__(self)

    def setHumanPlayer(self, player):
        """TODO
        """
        self.__humanPlayer = player
        
        # Animate the board
        if player is self.__game.getWhite():
            self.setBoardRotation(0.0)
        elif player is self.__game.getBlack():
            self.setBoardRotation(180.0)
        else:
            assert(False), 'Human player is not white or black'
            
    def setMoveNumber(self, moveNumber):
        """Set the move number to watch.

        'moveNumber' is the move to watch (integer).
        """
        if self.__moveNumber == moveNumber:
            return
        self.__moveNumber = moveNumber
        
        # Lock the scene if not tracking the game
        self.enableHumanInput(moveNumber == -1)
        
        # Get the state of this scene
        piecesByLocation = self.__game.getAlivePieces(moveNumber)
        
        # Remove any models not present
        requiredPieces = piecesByLocation.values()
        for (piece, model) in self.__pieceModels.items():
            try:
                requiredPieces.index(piece)
            except ValueError:
                self.__pieceModels.pop(piece)
                self.removeChessPiece(model)
        
        # Move the models in the scene
        for (location, piece) in piecesByLocation.iteritems():
            self.__movePiece(piece, location)
            
    def _movePiece(self, piece, start, end):
        """TODO
        """
        # Ignore if not watching the active game
        if self.__moveNumber != -1:
            return
        
        self.__movePiece(piece, end)
        
    def __movePiece(self, piece, location):
        """
        """
        # Get the model for this piece creating one if it doesn't exist
        try:
            model = self.__pieceModels[piece]
        except KeyError:
            # No need to create if didn't exist anyway
            if location is None:
                return
            
            # Make the new model
            pieceName = {chess.board.PAWN: 'pawn', chess.board.ROOK: 'rook', chess.board.KNIGHT: 'knight',
                         chess.board.BISHOP: 'bishop', chess.board.QUEEN: 'queen', chess.board.KING: 'king'}[piece.getType()]
            chessSet = {chess.board.WHITE: 'white', chess.board.BLACK: 'black'}[piece.getColour()]
            model = self.addChessPiece(chessSet, pieceName, location)
            self.__pieceModels[piece] = model
            
        # Delete or move the model
        if location is None:
            self.__pieceModels.pop(piece)
            self.removeChessPiece(model)
        else:
            model.move(location)

    # Extended methods

    def onRedraw(self):
        """Called by scene.opengl.Scene"""
        if self.__game.view.activeScene is self and self.__game.view is not None:
            self.__game.view.controller.render()

    def startAnimation(self):
        """Called by scene.opengl.Scene"""
        self.__game.application.ui.startAnimation()

    def playerIsHuman(self):
        """Called by scene.human.SceneHumanInput"""
        return self.__humanPlayer is not None

    def squareIsFriendly(self, coord):
        """Called by scene.human.SceneHumanInput"""
        owner = self.__game.getSquareOwner(coord)
        if owner is None:
            return False
        return owner is self.__humanPlayer
    
    def canMove(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        if self.__humanPlayer is None:
            return False

        return self.__humanPlayer.canMove(start, end) # FIXME: Promotion type
    
    def moveHuman(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        player = self.__humanPlayer
        self.__humanPlayer = None
        if player is self.__game.getWhite():
            colour = chess.board.WHITE
        else:
            colour = chess.board.BLACK
        move = chess.lan.encode(colour, start, end, promotionType = chess.board.QUEEN) # FIXME: Promotion type
        player.move(move)

class Splashscreen(ui.ViewFeedback):
    """
    """    
    application = None
    scene       = None
    
    def __init__(self, application):
        """Constructor.
        
        'application' is ???
        """
        self.application = application
        self.cairoScene = scene.cairo.Scene()
        self.scene = scene.opengl.Scene()

    def renderGL(self):
        """Called by ui.ViewFeedback"""
        self.scene.render()
        
    def renderCairoStatic(self, context):
        """Called by ui.ViewFeedback"""
        return self.cairoScene.renderStatic(context)
        
    def renderCairoDynamic(self, context):
        """Called by ui.ViewFeedback"""
        self.cairoScene.renderDynamic(context)
    
    def reshape(self, width, height):
        """Called by ui.View"""
        self.scene.reshape(width, height)
        self.cairoScene.reshape(width, height)
        
class View(ui.ViewFeedback):
    """
    """
    # The game this view is rendering
    game        = None
    
    # TEMP: The scene to render (switches between OpenGL and Cairo).
    activeScene = None
    
    # The controller object for this view
    controller  = None
    
    def __init__(self, game):
        """Constructor.
        
        'game' is ???
        """
        self.game = game
        
    def renderGL(self):
        """Called by ui.ViewFeedback"""
        self.activeScene = self.game.scene
        self.activeScene.render()
        
    def renderCairoStatic(self, context):
        """Called by ui.ViewFeedback"""
        self.activeScene = self.game.cairoScene
        return self.activeScene.renderStatic(context)
        
    def renderCairoDynamic(self, context):
        """Called by ui.ViewFeedback"""
        self.activeScene.renderDynamic(context)

    def reshape(self, width, height):
        """Called by ui.ViewFeedback"""
        self.game.scene.reshape(width, height)
        self.game.cairoScene.reshape(width, height)
    
    def select(self, x, y):
        """Called by ui.ViewFeedback"""
        self.activeScene.select(x, y)
    
    def deselect(self, x, y):
        """Called by ui.ViewFeedback"""
        self.activeScene.deselect(x, y)
    
    def setMoveNumber(self, moveNumber):
        """Called by ui.ViewFeedback"""
        self.game.scene.setMoveNumber(moveNumber)
        self.game.cairoScene.setMoveNumber(moveNumber)
        
    def save(self, fileName = None):
        """Called by ui.ViewFeedback"""
        if fileName is None:
            fileName = self.game.fileName
            assert(fileName is not None)

        try:
            f = file(fileName, 'w')
        except IOError, e:
            self.reportError('Unable to save PGN file ' + fileName, str(e))
            return
        
        print 'Saving game ' + repr(self.game.name) + ' to ' + fileName

        pgnGame = chess.pgn.PGNGame()
        self.game.toPGN(pgnGame)
            
        lines = pgnGame.getLines()
        for line in lines:
            f.write(line + '\n')
        f.write('\n')
        f.close()
        
        self.game.fileName = fileName
        self.game.needsSaving = False
        
    def getFileName(self):
        """Called by ui.ViewFeedback"""
        return self.game.fileName
        
    def needsSaving(self):
        """Called by ui.ViewFeedback"""
        return self.game.needsSaving and (self.game.fileName is not None)

    def close(self):
        """Called by ui.ViewFeedback"""
        # The user requests the game to end, for now we just do it
        self.game.remove()

class ChessGame(game.ChessGame):
    """
    """
    # Link back to the main application
    application    = None
    
    # The name of the game
    name           = None
    
    # The scene for this game
    scene          = None
    
    # The view watching this scene
    view            = None
    
    # The players in the game
    __movePlayer   = None
    __aiPlayers    = None
    __humanPlayers = None
    
    # The file this is saved to
    fileName       = None
    needsSaving    = True

    def __init__(self, application, name):
        """Constructor for a chess game.
        
        'application' is a reference to the glChess application.
        'name' is the name of the game (string).
        """
        self.application = application
        self.name = name
        self.__aiPlayers = []
        self.__humanPlayers = []
        
        # Call parent constructor
        game.ChessGame.__init__(self)

        # Create a scene to render to
        self.scene = SceneOpenGL(self)
        self.cairoScene = SceneCairo(self)
        self.view = View(self)
        self.view.controller = application.ui.addView(name, self.view)
        
        # Watch for piece moves with a player
        self.__movePlayer = MovePlayer(self)
        self.addSpectator(self.__movePlayer)

    def addAIPlayer(self, name, profile):
        """Create an AI player.
        
        'name' is the name of the player to create (string).
        'profile' is the the AI profile to use (ai.Profile).
        
        Returns an AI player to use (game.ChessPlayer).
        """
        description = "'" + name + "' in '" + self.name + "'"
        player = AIPlayer(self.application, name, profile, description)
        self.__aiPlayers.append(player)
        self.application.watchAIPlayer(player)
        return player
    
    def addHumanPlayer(self, name):
        """Create a human player.
        
        'name' is the name of the player to create.
        
        Returns a human player to use (game.ChessPlayer).
        """
        player = HumanPlayer(self, name)
        self.__humanPlayers.append(player)
        return player

    def playerIsHuman(self, player):
        """Test if a player is human.
        
        'player' is the player to check (game.ChessPlayer).
        
        Returns True if this is a human player in this game otherwise False.
        """
        try:
            if self.__humanPlayers.index(player) < 0:
                return False
            else:
                return True
        except ValueError:
            return False

    def toPGN(self, pgnGame):
        """Write the properties of this game into a PGN game.
        
        'pgnGame' is the game to write into (pgn.PGNGame). All the tags should be unset.
        """
        white = self.getWhite()
        black = self.getBlack()
        
        pgnGame.setTag(pgnGame.PGN_TAG_EVENT, self.name)
        pgnGame.setTag(pgnGame.PGN_TAG_WHITE, white.getName())
        pgnGame.setTag(pgnGame.PGN_TAG_BLACK, black.getName())

        if isinstance(white, ai.Player):
            pgnGame.setTag('WhiteAI', white.getProfile().name)
        if isinstance(black, ai.Player):
            pgnGame.setTag('BlackAI', black.getProfile().name)

        moves = self.getMoves()
        while len(moves) > 0:
            if len(moves) == 1:
                pgnGame.addMove(moves[0].sanMove, None)
                break
            else:
                pgnGame.addMove(moves[0].sanMove, moves[1].sanMove)
                moves = moves[2:]

    def animate(self, timeStep):
        """
        """
        animating1 = self.scene.animate(timeStep)
        animating2 = self.cairoScene.animate(timeStep)
        return animating1 or animating2
            
    def remove(self):
        """Remove this game"""
        # Remove AI player windows
        for player in self.__aiPlayers:
            player.window.close()
            self.application.unwatchAIPlayer(player)

        # End the game
        self.end()
        
        # Remove the game from the UI
        self.application._removeGame(self)
        self.view.controller.close()

    # Private methods
    
    def _onPlayerMoved(self, player, move):
        """FIXME: Rename this
        """
        self.needsSaving = True
        self.view.controller.addMove(move)

class UI(gtkui.GtkUI):
    """
    """    
    __application = None
    
    splashscreen = None
    
    def __init__(self, application):
        """
        """
        self.__application = application
        gtkui.GtkUI.__init__(self)
        
        self.splashscreen = Splashscreen(self)
        self.setDefaultView(self.splashscreen)
        
    def onAnimate(self, timeStep):
        """Called by UI"""
        return self.__application.animate(timeStep)
    
    def onReadFileDescriptor(self, fd):
        """Called by UI"""
        try:
            player = self.__application.aiPlayers[fd]
        except KeyError:
            return False
        else:
            player.read()
            return True

    def onGameStart(self, gameName, allowSpectators, whiteName, whiteType, blackName, blackType, moves = None):
        """Called by UI"""
        g = self.__application.addGame(gameName, whiteName, whiteType, blackName, blackType)
        print 'Starting game ' + gameName + ' between ' + whiteName + '(' + str(whiteType) + ') and ' + blackName + '(' + str(blackType) + ')'
        if moves:
            g.start(moves)
        else:
            g.start()
        
    def loadGame(self, path, returnResult):
        """Called by ui.UI"""
        try:
            p = chess.pgn.PGN(path, 1)
        except chess.pgn.Error, e:
            self.reportError('Unable to open PGN file ' + path, str(e))
            return
        
        # Use the first game
        pgnGame = p[0]
        
        if returnResult is True:
            whiteAI = pgnGame.getTag('WhiteAI')
            blackAI = pgnGame.getTag('BlackAI')
            msg = ''
            if whiteAI and self.__application.getAIProfile(whiteAI) is None:
                msg += "AI '" + whiteAI + "' is not installed, white player is now human"
                whiteAI = None
            if blackAI and self.__application.getAIProfile(blackAI) is None:
                if msg != '':
                    msg += '\n'
                msg += "AI '" + blackAI + "' is not installed, black player is now human"
                blackAI = None

            self.reportGameLoaded(gameName = pgnGame.getTag(pgnGame.PGN_TAG_EVENT),
                                  whiteName = pgnGame.getTag(pgnGame.PGN_TAG_WHITE),
                                  blackName = pgnGame.getTag(pgnGame.PGN_TAG_BLACK),
                                  whiteAI = whiteAI, blackAI = blackAI,
                                  moves = pgnGame.getMoves())
                                  
            if len(msg) > 0:
                self.reportError('Game modified', msg)
        else:
            self.__application.addPGNGame(pgnGame, path)

    def onGameJoin(self, localName, localType, game):
        """Called by UI"""
        print 'Joining game ' + str(game) + ' as ' + localName + '(' + str(localType) + ')'

    def onQuit(self):
        """Called by UI"""
        self.__application.quit()

#class GameDetector(network.GameDetector):
#    """
#    """
#    def __init__(self, app):
#        """
#        """
#        self.__app = app
#        network.GameDetector.__init__(self)
#    
#    def onGameDetected(self, game):
#        """Called by network.GameDetector"""
#        self.__app.ui.addNetworkGame(game.name, game)
#    
#    def onGameRemoved(self, game):
#        """Called by network.GameDetector"""
#        self.__app.ui.removeNetworkGame(game)

class Application:
    """
    """
    # The configuration
    __config = None

    # The glChess UI
    ui = None
    
    # The AI types
    __aiProfiles = None
    
    # AI players keyed by file descriptor
    aiPlayers = None
    
    # The network game detector
    __detector = None
    
    # The games present
    __games = None
    
    def __init__(self):
        """Constructor for glChess application"""
        self.__aiProfiles = {}
        self.__games = []
        self.aiPlayers = {}
        
        self.__config = Config()
        
        self.__detector = None#GameDetector(self)

        self.ui = UI(self)
        
    def addAIProfile(self, profile):
        """Add a new AI profile into glChess.
        
        'profile' is the profile to add (ai.Profile).
        """
        name = profile.name
        assert(self.__aiProfiles.has_key(name) is False)
        self.__aiProfiles[name] = profile
        self.ui.addAIEngine(name)

    def getAIProfile(self, name):
        """Get an installed AI profile.
        
        'name' is the name of the profile to get (string).
        
        Return the profile (ai.Profile) or None if it does not exist.
        """
        try:
            return self.__aiProfiles[name]
        except KeyError:
            return None
        
    def watchAIPlayer(self, player):
        """
        """
        self.aiPlayers[player.fileno()] = player
        self.ui.watchFileDescriptor(player.fileno())

    def unwatchAIPlayer(self, player):
        """
        """
        self.aiPlayers.pop(player.fileno())

    def addGame(self, name, whiteName, whiteType, blackName, blackType):
        """Add a chess game into glChess.
        
        'name' is the name of the game (string).
        'whiteName' is the name of the white player (string).
        'whiteType' is the AI profile to use for white (string) or None if white is human.
        'blackName' is the name of the black player (string).
        'blackType' is the AI profile to use for black (string) or None if black is human.
        
        Returns the game object. Use game.start() to start the game.
        """
        # Create the game
        g = ChessGame(self, name)
        self.__games.append(g)

        msg = ''
        if whiteType is None:
            player = g.addHumanPlayer(whiteName)
        else:
            try:
                profile = self.__aiProfiles[whiteType]
                player = g.addAIPlayer(whiteName, profile)
            except KeyError:
                msg += "AI '" + whiteType + "' is not installed, white player is now human"
                player = g.addHumanPlayer(whiteName)
        g.setWhite(player)

        if blackType is None:
            player = g.addHumanPlayer(blackName)
        else:
            try:
                profile = self.__aiProfiles[blackType]
                player = g.addAIPlayer(blackName, profile)
            except KeyError:
                msg += "AI '" + blackType + "' is not installed, black player is now human"
                player = g.addHumanPlayer(blackName)
        g.setBlack(player)
                
        if len(msg) > 0:
            self.ui.reportError('Game modified', msg)

        return g
    
    def addPGNGame(self, pgnGame, path):
        """Add a PGN game.
        
        'pgnGame' is the game to add (chess.pgn.PGNGame).
        'path' is the path this game was loaded from (string or None).
        
        Returns the game object. Use game.start() to start the game.
        """
        g = self.addGame(pgnGame.getTag(pgnGame.PGN_TAG_EVENT),
                         pgnGame.getTag(pgnGame.PGN_TAG_WHITE),
                         pgnGame.getTag('WhiteAI'),
                         pgnGame.getTag(pgnGame.PGN_TAG_BLACK),
                         pgnGame.getTag('BlackAI'))
        g.fileName = path
        moves = pgnGame.getMoves()
        if moves:
            g.start(moves)
        else:
            g.start()
            
        # No change from when loaded
        g.needsSaving = False

        return g

    def addMove(self, view, move):
        # TEMP
        self.ui.addMove(view, move)

    def start(self):
        """Run glChess.
        
        This method does not return.
        """
        print 'This is glChess ' + VERSION
        
        # Load AI profiles
        profiles = ai.loadProfiles()

        for p in profiles:
            p.detect()
            if p.path is not None:
                print 'Detected AI: ' + p.name + ' at ' + p.path
                self.addAIProfile(p)

        nArgs = len(sys.argv)

        # Load existing games
        if nArgs == 1:
            self.__autoload()
        
        # Load requested games
        for path in sys.argv[1:]:
            try:
                p = chess.pgn.PGN(path, 1)
            except chess.pgn.Error, e:
                # TODO: Pop-up dialog
                print e
            else:
                # Use the first game
                if len(p) > 0:
                    g = self.addPGNGame(p[0], path)

        # Start UI (does not return)
        try:
            self.ui.run()
        except:
            print 'glChess has crashed. Please report this bug to http://glchess.sourceforge.net'
            print 'Debug output:'
            print traceback.format_exc()
            self.quit()
            sys.exit(1)
        
    def animate(self, timeStep):
        """
        """
        animating = False
        for g in self.__games:
            if g.animate(timeStep):
                animating = True
        return animating

    def quit(self):
        """Quit glChess"""
        # Save any games not saved to a file
        self.__autosave()
        
        # End current games (will delete AIs etc)
        for game in self.__games[:]:
            game.end()

        # Exit the application
        sys.exit()
        
    # Private methods
    
    def _removeGame(self, g):
        """
        """
        self.__games.remove(g)

    def __autoload(self):
        """Restore games from the autosave file"""
        path = self.__config.getAutosavePath()
        print 'Auto-loading from ' + path + '...'
        
        try:
            p = chess.pgn.PGN(path)
            games = p[:]
        except chess.pgn.Error, e:
            print 'Invalid autoload file ' + path + ': ' + str(e)
            games = []
        except IOError, e:
            print 'Unable to autoload from ' + path + ': ' + str(e)
            games = []
            
        # Delete the file once loaded
        try:
            os.unlink(path)
        except OSError:
            pass

        # Restore each game
        for pgnGame in games:
            self.addPGNGame(pgnGame, None)
    
    def __autosave(self):
        """Save any open games to the autosave file"""
        if len(self.__games) == 0:
            return
        
        fname = self.__config.getAutosavePath()
        print 'Auto-saving to ' + fname + '...'
        
        f = file(fname, 'a')
        for g in self.__games:
            # Ignore games that are saved to a file
            if g.fileName is not None:
                continue
            
            pgnGame = chess.pgn.PGNGame()
            g.toPGN(pgnGame)
            
            lines = pgnGame.getLines()
            for line in lines:
                f.write(line + '\n')
            f.write('\n')
        f.close()

if __name__ == '__main__':
    app = Application()
    app.start()
