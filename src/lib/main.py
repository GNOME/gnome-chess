"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['Application']

import sys
import os
import errno
import gettext
import traceback

import config
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

class MovePlayer(game.ChessPlayer):
    """This class provides a pseudo-player to watch for piece movements"""
    # The game to control
    __game = None
    
    waitForMoves = False

    def __init__(self, chessGame):
        """Constructor for a move player.
        
        'chessGame' is the game to make changes to (ChessGame).
        """
        self.__game = chessGame
        game.ChessPlayer.__init__(self, '@move')
        
    # Extended methods

    def onPieceMoved(self, piece, start, end, delete):
        """Called by chess.board.ChessPlayer"""
        if self.__game.view.moveNumber != -1:
            return
        p = self.__game.view.scene.movePiece(piece, end, delete, self.__game.isStarted())

        # If a player move notify when animation completes
        if self.__game.isStarted() and self.__game.view.moveNumber == -1 and start is not None and start != end:
            self.__game.view.scene.waitingPiece = p
        
    def onPlayerMoved(self, player, move):
        """Called by chess.board.ChessPlayer"""
        self.__game.needsSaving = True
        self.__game.view.controller.addMove(move)
        
        # Update clocks
        if player is self.__game.getWhite():
            if self.__game.wT is not None:
                self.__game.wT.controller.pause()
            if self.__game.bT is not None:
                self.__game.bT.controller.run()
        else:
            if self.__game.bT is not None:
                self.__game.bT.controller.pause()
            if self.__game.wT is not None:
                self.__game.wT.controller.run()
        
        # Complete move if not waiting for visual indication of move end
        if self.__game.view.moveNumber != -1:
            player.endMove()
            
    def onGameEnded(self, game):
        """Called by chess.board.ChessPlayer"""
        self.__game.view.controller.endGame(game)

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
        self.__game.view.controller.setAttention(True)

class AIPlayer(ai.Player):
    """
    """
    
    def __init__(self, application, name, profile, level, description):
        """
        """
        executable = profile.path
        for arg in profile.arguments[1:]:
            executable += ' ' + arg
        self.window = application.ui.controller.addAIWindow(profile.name, executable, description)
        ai.Player.__init__(self, name, profile, level)
        
    def logText(self, text, style):
        """Called by ai.Player"""
        self.window.addText(text, style)
    
class CairoPiece(scene.ChessPieceFeedback):
    """
    """
    
    model = None
    
    location = ''
    
    def __init__(self, scene, piece):
        self.scene = scene
        self.piece = piece

    def onDeleted(self):
        """Called by scene.ChessPieceFeedback"""
        self.scene.pieces.pop(self.piece)

    def onMoved(self):
        """Called by scene.ChessPieceFeedback"""
        # If waiting for this piece then end players turn
        if self.scene.waitingPiece is self:
            self.scene.game.view.pieceMoved()

class SceneCairo(scene.SceneFeedback, scene.human.SceneHumanInput):
    """
    """
    controller = None
    
    # The game this scene is rendering
    game = None
    
    # TODO
    moveNumber   = None
    pieces       = None
    
    # FIXME: Abort when scenes changed
    waitingPiece = None

    def __init__(self, chessGame):
        """
        """
        self.controller = scene.cairo.Scene(self)
        self.game = chessGame
        self.pieces = {}
        scene.human.SceneHumanInput.__init__(self)
        
    def getPieces(self):
        return self.pieces.values()

    def movePiece(self, piece, location, delete, animate):
        """
        """
        # Get the model for this piece creating one if it doesn't exist
        try:
            p = self.pieces[piece]
        except KeyError:
            # Make the new model
            pieceName = {chess.board.PAWN: 'pawn', chess.board.ROOK: 'rook', chess.board.KNIGHT: 'knight',
                         chess.board.BISHOP: 'bishop', chess.board.QUEEN: 'queen', chess.board.KING: 'king'}[piece.getType()]
            chessSet = {chess.board.WHITE: 'white', chess.board.BLACK: 'black'}[piece.getColour()]
            p = CairoPiece(self, piece)
            p.model = self.controller.addChessPiece(chessSet, pieceName, location, p)
            self.pieces[piece] = p

        # Move the model
        p.location = location
        p.model.move(location, delete, animate)
        
        return p

    # Extended methods

    def onRedraw(self):
        """Called by scene.cairo.Scene"""
        if self.game.view.controller is not None:
            self.game.view.controller.render()

    def startAnimation(self):
        """Called by scene.cairo.Scene"""
        self.game.application.ui.controller.startAnimation()
        
    def getSquare(self, x, y):
        """Called by scene.human.SceneHumanInput"""
        return self.controller.getSquare(x, y)

    def setBoardHighlight(self, coords):
        """Called by scene.human.SceneHumanInput"""
        self.controller.setBoardHighlight(coords)

    def playerIsHuman(self):
        """Called by scene.human.SceneHumanInput"""
        return self.game.currentPlayerIsHuman()

    def squareIsFriendly(self, coord):
        """Called by scene.human.SceneHumanInput"""
        return self.playerIsHuman() and self.game.squareIsFriendly(coord)
    
    def canMove(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        return self.playerIsHuman() and self.game.getCurrentPlayer().canMove(start, end) # FIXME: Promotion type
    
    def moveHuman(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        self.game.moveHuman(start, end)
        
class OpenGLPiece(scene.ChessPieceFeedback):
    """
    """
    
    model = None
    
    location = ''
    
    def __init__(self, scene, piece):
        self.scene = scene
        self.piece = piece

    def onDeleted(self):
        """Called by scene.ChessPieceFeedback"""
        self.scene.pieces.pop(self.piece)

    def onMoved(self):
        """Called by scene.ChessPieceFeedback"""
        # If waiting for this piece then end players turn
        if self.scene.waitingPiece is self:
            self.scene.waitingPiece = None
            self.scene.game.getCurrentPlayer().endMove()

class SceneOpenGL(scene.SceneFeedback, scene.human.SceneHumanInput):
    """
    """
    # The game this scene is rendering
    game          = None
    
    # TODO
    pieces        = None
    
    # FIXME: Abort when scenes changed
    waitingPiece = None

    def __init__(self, chessGame):
        """Constructor for a glChess scene.
        
        'chessGame' is the game the scene is rendering (game.ChessGame).
        """
        self.game = chessGame
        self.pieces = {}

        # Call parent constructors
        scene.human.SceneHumanInput.__init__(self)
        self.controller = scene.opengl.Scene(self)

    def getPieces(self):
        return self.pieces.values()
        
    def movePiece(self, piece, location, delete, animate):
        """
        """
        # Get the model for this piece creating one if it doesn't exist
        try:
            p = self.pieces[piece]
        except KeyError:
            # Make the new model
            pieceName = {chess.board.PAWN: 'pawn', chess.board.ROOK: 'rook', chess.board.KNIGHT: 'knight',
                         chess.board.BISHOP: 'bishop', chess.board.QUEEN: 'queen', chess.board.KING: 'king'}[piece.getType()]
            chessSet = {chess.board.WHITE: 'white', chess.board.BLACK: 'black'}[piece.getColour()]
            p = OpenGLPiece(self, piece)
            p.model = self.controller.addChessPiece(chessSet, pieceName, location, p)
            self.pieces[piece] = p
            
        # Move the model
        p.location = location
        p.model.move(location, delete)

        return p

    # Extended methods

    def onRedraw(self):
        """Called by scene.opengl.Scene"""
        if self.game.view.controller is not None:
            self.game.view.controller.render()

    def startAnimation(self):
        """Called by scene.opengl.Scene"""
        self.game.application.ui.controller.startAnimation()
        
    def getSquare(self, x, y):
        """Called by scene.human.SceneHumanInput"""
        return self.controller.getSquare(x, y)

    def setBoardHighlight(self, coords):
        """Called by scene.human.SceneHumanInput"""
        self.controller.setBoardHighlight(coords)

    def playerIsHuman(self):
        """Called by scene.human.SceneHumanInput"""
        return self.game.currentPlayerIsHuman()

    def squareIsFriendly(self, coord):
        """Called by scene.human.SceneHumanInput"""
        return self.playerIsHuman() and self.game.squareIsFriendly(coord)
    
    def canMove(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        return self.playerIsHuman() and self.game.getCurrentPlayer().canMove(start, end) # FIXME: Promotion type
    
    def moveHuman(self, start, end):
        """Called by scene.human.SceneHumanInput"""
        self.game.moveHuman(start, end)

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
        self.cairoScene = scene.cairo.Scene(self)
        self.scene = scene.opengl.Scene(self)
        
    def onRedraw(self):
        """
        """
        # FIXME: Need for scene.cairo.Scene

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
    
    # The scene for this view
    scene       = None
    
    # The controller object for this view
    controller  = None
    
    moveNumber  = None
    
    def __init__(self, game):
        """Constructor.
        
        'game' is ???
        """
        self.game = game
        
        # Use a Cairo scene by default - it will be replaced by an OpenGL one if that is the requested view
        # I wanted to remove this but then scene is None and there are a number of issues...
        # This should be cleaned up
        self.scene = SceneCairo(game)
        config.watch('board_view', self.__onBoardViewChanged)
        self.updateRotation()

    def __onBoardViewChanged(self, key, value):
        self.updateRotation()

    def updateRotation(self):
        """
        """
        # Get the angle to face
        player = self.game.getCurrentPlayer()
        if player is self.game.getWhite():
            rotation = 0.0
        elif player is self.game.getBlack():
            rotation = 180.0
        
        # Decide if we should face this angle
        boardView = config.get('board_view')
        if boardView == 'white':
            rotation = 0.0
        elif boardView == 'black':
            rotation = 180.0
        elif boardView == 'human':
            if not isinstance(player, HumanPlayer):
                return

        self.scene.controller.setBoardRotation(rotation)

    def pieceMoved(self):
        """
        """
        if self.scene.waitingPiece is None:
            return
        self.scene.waitingPiece = None
        self.game.getCurrentPlayer().endMove()

    def showMoveHints(self, showHints):
        """Called by ui.UIFeedback"""
        self.scene.showMoveHints(showHints)

    def showBoardNumbering(self, showNumbering):
        """Called by ui.UIFeedback"""
        self.scene.controller.showBoardNumbering(showNumbering)

    def updateScene(self, sceneClass):
        """
        """
        if isinstance(self.scene, sceneClass):
            return
        self.pieceMoved()
        self.scene = sceneClass(self.game)
        self.reshape(self.width, self.height)
        self.setMoveNumber(self.moveNumber)
        
    def renderGL(self):
        """Called by ui.ViewFeedback"""
        self.updateScene(SceneOpenGL)
        self.scene.controller.render()

    def renderCairoStatic(self, context):
        """Called by ui.ViewFeedback"""
        self.updateScene(SceneCairo)
        return self.scene.controller.renderStatic(context)
        
    def renderCairoDynamic(self, context):
        """Called by ui.ViewFeedback"""
        self.updateScene(SceneCairo)
        self.scene.controller.renderDynamic(context)

    def reshape(self, width, height):
        """Called by ui.ViewFeedback"""
        self.width = width
        self.height = height
        self.scene.controller.reshape(width, height)
    
    def select(self, x, y):
        """Called by ui.ViewFeedback"""
        self.scene.select(x, y)
    
    def deselect(self, x, y):
        """Called by ui.ViewFeedback"""
        self.scene.deselect(x, y)
    
    def setMoveNumber(self, moveNumber):
        """Called by ui.ViewFeedback"""
        self.moveNumber = moveNumber
        
        # Lock the scene if not tracking the game
        self.scene.enableHumanInput(moveNumber == -1)
        
        # Get the state of this scene
        piecesByLocation = self.game.getAlivePieces(moveNumber)
        
        # Remove any models not present
        requiredPieces = piecesByLocation.values()
        for piece in self.scene.getPieces():
            try:
                requiredPieces.index(piece.piece)
            except ValueError:
                piece.model.move(piece.location, True)
        
        # Move the models in the scene
        for (location, piece) in piecesByLocation.iteritems():
            self.scene.movePiece(piece, location, False, True)
        
        # Can't wait for animation if not looking at the latest move
        if moveNumber != -1:
            self.pieceMoved()

    def save(self, fileName = None):
        """Called by ui.ViewFeedback"""
        if fileName is None:
            fileName = self.game.fileName
            assert(fileName is not None)

        try:
            f = file(fileName, 'w')
        except IOError, e:
            return e.args[1]
        
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
        
class PlayerTimer(ui.TimerFeedback):
    """
    """

    def __init__(self, game, colour, duration):
        self.game = game
        self.colour = colour
        self.duration = duration
        self.controller = game.application.ui.controller.addTimer(self, duration)
    
    def onTick(self, t):
        """Called by ui.TimerFeedback"""
        if self.colour is chess.board.WHITE:
            self.game.view.controller.setWhiteTime(self.duration, t)
        else:
            self.game.view.controller.setBlackTime(self.duration, t)

    def onExpired(self):
        """Called by ui.TimerFeedback"""
        if self.colour is chess.board.WHITE:
            self.game.getWhite().outOfTime()
        else:
            self.game.getBlack().outOfTime()

class ChessGame(game.ChessGame):
    """
    """
    # Link back to the main application
    application    = None
    
    # The name of the game
    name           = None

    # The view watching this scene
    view           = None
    
    # The players in the game
    __movePlayer   = None
    __aiPlayers    = None
    
    # The file this is saved to
    fileName       = None
    needsSaving    = True

    # Mapping between piece names and promotion types
    __promotionMapping = {'queen': chess.board.QUEEN, 'knight': chess.board.KNIGHT, 'bishop': chess.board.BISHOP, 'rook': chess.board.ROOK}
    
    # TEMP
    duration = 0
    wT = None
    bT = None

    def __init__(self, application, name):
        """Constructor for a chess game.
        
        'application' is a reference to the glChess application.
        'name' is the name of the game (string).
        """
        self.application = application
        self.name = name
        self.__aiPlayers = []
        
        # Call parent constructor
        game.ChessGame.__init__(self)

        self.view = View(self)
        self.view.controller = application.ui.controller.addView(name, self.view)
        
        self.view.showMoveHints(config.get('show_move_hints') is True)
        
        # Watch for piece moves with a player
        self.__movePlayer = MovePlayer(self)
        self.addSpectator(self.__movePlayer)

    def addAIPlayer(self, name, profile, level):
        """Create an AI player.
        
        'name' is the name of the player to create (string).
        'profile' is the the AI profile to use (ai.Profile).
        'level' is the difficulty level to use (string).
        
        Returns an AI player to use (game.ChessPlayer).
        """
        description = "'" + name + "' in '" + self.name + "'"
        player = AIPlayer(self.application, name, profile, level, description)
        self.__aiPlayers.append(player)
        self.application.watchAIPlayer(player)
        return player
    
    def addHumanPlayer(self, name):
        """Create a human player.
        
        'name' is the name of the player to create.
        
        Returns a human player to use (game.ChessPlayer).
        """
        player = HumanPlayer(self, name)
        return player
    
    def setTimer(self, duration, whiteTime, blackTime):
        self.duration = duration
        if duration <= 0:
            return

        self.view.controller.setWhiteTime(duration, whiteTime)
        self.view.controller.setBlackTime(duration, blackTime)

        self.wT = PlayerTimer(self, chess.board.WHITE, whiteTime)
        self.bT = PlayerTimer(self, chess.board.BLACK, blackTime)
        self.wT.controller.run()
        
        self.setTimers(self.wT, self.bT)

    def currentPlayerIsHuman(self):
        """Test if a player is human.
        
        'player' is the player to check (game.ChessPlayer).
        
        Returns True if this is a human player in this game otherwise False.
        """
        return isinstance(self.getCurrentPlayer(), HumanPlayer)
        
    def squareIsFriendly(self, coord):
        """
        """
        owner = self.getSquareOwner(coord)
        if owner is None:
            return False
        return owner is self.getCurrentPlayer()
        
    def moveHuman(self, start, end):
        """
        """
        assert(self.currentPlayerIsHuman())
        player = self.getCurrentPlayer()
        if player is self.getWhite():
            colour = chess.board.WHITE
        else:
            colour = chess.board.BLACK

        # Use configured promotion type
        try:
            promotionType = self.__promotionMapping[config.get('promotion_type')]
        except KeyError:
            promotionType = chess.board.QUEEN

        # Make the move
        move = chess.lan.encode(colour, start, end, promotionType = promotionType)
        player.move(move)

        # Notify move
        self.view.controller.setAttention(False)

    def toPGN(self, pgnGame):
        """Write the properties of this game into a PGN game.
        
        'pgnGame' is the game to write into (pgn.PGNGame). All the tags should be unset.
        """
        white = self.getWhite()
        black = self.getBlack()
        
        pgnGame.setTag(pgnGame.PGN_TAG_EVENT, self.name)
        pgnGame.setTag(pgnGame.PGN_TAG_WHITE, white.getName())
        pgnGame.setTag(pgnGame.PGN_TAG_BLACK, black.getName())

        results = {game.RESULT_WHITE_WINS: chess.pgn.PGNToken.GAME_TERMINATE_WHITE_WIN,
                   game.RESULT_BLACK_WINS: chess.pgn.PGNToken.GAME_TERMINATE_BLACK_WIN,
                   game.RESULT_DRAW:       chess.pgn.PGNToken.GAME_TERMINATE_DRAW}
        try:
            value = results[self.result]
        except KeyError:
            pass
        else:
            pgnGame.setTag(pgnGame.PGN_TAG_RESULT, value)

        rules = {game.RULE_RESIGN:  pgnGame.PGN_TERMINATE_ABANDONED,
                 game.RULE_TIMEOUT: pgnGame.PGN_TERMINATE_TIME_FORFEIT,
                 game.RULE_DEATH:   pgnGame.PGN_TERMINATE_DEATH}
        try:
            value = rules[self.rule]
        except KeyError:
            pass
        else:
            pgnGame.setTag(pgnGame.PGN_TAG_TERMINATION, value)

        if self.duration > 0:
            pgnGame.setTag(pgnGame.PGN_TAG_TIME_CONTROL, str(self.duration))
        if self.wT is not None:
            pgnGame.setTag('WhiteTime', str(self.wT.controller.getRemaining()))
        if self.bT is not None:
            pgnGame.setTag('BlackTime', str(self.bT.controller.getRemaining()))

        # FIXME: AI levels
        if isinstance(white, ai.Player):
            (profile, level) = white.getProfile()
            pgnGame.setTag('WhiteAI', profile)
            pgnGame.setTag('WhiteLevel', level)
        if isinstance(black, ai.Player):
            (profile, level) = black.getProfile()
            pgnGame.setTag('BlackAI', profile)
            pgnGame.setTag('BlackLevel', level)

        moves = self.getMoves()
        for m in moves:
            pgnGame.addMove(m.sanMove)

    def animate(self, timeStep):
        """
        """
        return self.view.scene.controller.animate(timeStep)
    
    def endMove(self, player):
        game.ChessGame.endMove(self, player)
        self.view.updateRotation()

    def remove(self):
        """Remove this game"""
        # Remove AI player windows
        for player in self.__aiPlayers:
            player.window.close()
            self.application.unwatchAIPlayer(player)

        # Stop the game
        self.abort()
        
        # Remove the game from the UI
        self.application._removeGame(self)
        self.view.controller.close()
        
class Advert:
    pass
        
class FICSConnection(chess.fics.Decoder):
    
    def __init__(self, dialog):
        self.dialog = dialog
        self.messageQueue = []
        self.havePrompt = False
        self.adverts = {}
        chess.fics.Decoder.__init__(self)

    def send(self, message):
        if self.havePrompt:
            self.dialog.socket.send(message)
            self.havePrompt = False
        else:
            self.messageQueue.append(message)

    def onUnknownLine(self, text):
        self.dialog.controller.addText(text + '\n', 'info')

    def onPrompt(self):
        if len(self.messageQueue) > 0:
            message = self.messageQueue[0]
            self.messageQueue = self.messageQueue[1:]
            self.dialog.socket.send(message)
            self.havePrompt = False
        else:
            self.havePrompt = True

    def onLogin(self):
        self.dialog.socket.send('guest\n')
        self.dialog.controller.addText('Logging in as guest...\n', 'info')

    def onNameAssign(self, name):
        self.dialog.controller.addText('Assigned name %s\n' % name, 'info')
        self.dialog.socket.send('\n')
        self.send('set seek 0\n')
        self.send('iset seekremove 1\n')
        self.send('iset seekinfo 1\n')
        self.send('iset lock 1\n')
        self.send('style 12\n')
        
    def onSeekClear(self):
        for advert in self.adverts.iteritems():
            if not advert.hidden:
                self.dialog.controller.removeAdvert(advert)
        self.adverts = {}
    
    def onSeekAdd(self, number, game, player):
        assert(not self.adverts.has_key(number))
        advert = Advert()
        self.adverts[number] = advert
        advert.hidden = True
        for variant in ['untimed', 'standard', 'blitz', 'lightning']:
            if game.type == variant:
                advert.hidden = False
                break

        advert.number = number
        advert.game = game
        advert.player = player
        if not advert.hidden:
            self.dialog.controller.addAdvert(player.name, player.rating, game.type, advert)       
        
    def onSeekRemove(self, numbers):
        # NOTE: Ignore removes for ads we don't know about (they were hidden because we didn't meet the requirements)
        for number in numbers:
            try:
                advert = self.adverts.pop(number)
            except KeyError:
                pass
            else:
                if not advert.hidden:
                    self.dialog.controller.removeAdvert(advert)

    def onAnnounce(self, number, game, player):
        new = False
        try:
            advert = self.adverts[number]
        except KeyError:
            advert = Advert()
            self.adverts[number] = advert
            advert.hidden = True
            for variant in ['untimed', 'standard', 'blitz', 'lightning']:
                if game.type == variant:
                    advert.hidden = False
                    break
            new = True

        advert.number = number
        advert.game = game
        advert.player = player
        if new and not advert.hidden:
            self.dialog.controller.addAdvert(player.name, player.rating, game.type, advert)

    def onEndSeek(self, nSeeks):
        # Delete expired seeks
        expired = []
        for (number, advert) in self.adverts.iteritems():
            if advert.marker != self.advertMarker:
                expired.append(advert)
        for advert in expired:
            self.adverts.pop(advert.number)
            if not advert.hidden:
                self.dialog.controller.removeAdvert(advert)

        if len(self.adverts) != nSeeks:
            print 'WARNING: There should be %i seeks, we have only %i' % (nSeeks, len(self.adverts))

        self.advertMarker = not self.advertMarker

    def onChallenge(self, game, player):
        self.dialog.controller.addText('%s(%s) challenges you to a %s match\n' % (player.name, player.rating, game.type), 'info')
        self.dialog.challengeGame = game
        self.dialog.challengePlayer = player
        self.dialog.controller.requestGame(player.name)
        
    def onChat(self, channel, playerName, text):
        self.dialog.controller.addText('%s: %s\n' % (playerName, text), 'chat')
        
class NetworkDialog(ui.NetworkFeedback):
    """
    """
    
    def __init__(self, ui):
        self.ui = ui
        
        import socket
        
        self.decoder = FICSConnection(self)
        
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ui.application.ioHandlers[self.socket.fileno()] = self
        ui.controller.watchFileDescriptor(self.socket.fileno())
        
        self.socket.connect(('freechess.org', 23))
        
    def read(self):
        (data, address) = self.socket.recvfrom(65535)
        self.decoder.registerIncomingData(data)
        return True
        
    def sendCommand(self, command):
        # TODO: Validate the command
        self.decoder.send(command + '\n')
        
    def acceptGame(self):
        self.controller.addText('Accepting challenge from %s\n' % self.challengePlayer.name, 'info')
        self.decoder.send('accept\n')
        
    def declineGame(self):
        self.controller.addText('Declining challenge from %s\n' % self.challengePlayer.name, 'info')
        self.decoder.send('decline\n')

class UI(ui.UIFeedback):
    """
    """    
    application = None
    
    splashscreen = None
    
    controller = None
    
    def __init__(self, application):
        """
        """
        self.controller = gtkui.GtkUI(self)
        self.application = application
        
        self.splashscreen = Splashscreen(self)
        self.controller.setDefaultView(self.splashscreen)

    def onAnimate(self, timeStep):
        """Called by ui.UIFeedback"""
        return self.application.animate(timeStep)
    
    def onReadFileDescriptor(self, fd):
        """Called by ui.UIFeedback"""
        try:
            handler = self.application.ioHandlers[fd]
        except KeyError:
            return False
        else:
            return handler.read()

    def onGameStart(self, game):
        """Called by ui.UIFeedback"""
        if game.white.type == '':
            w = None
        else:
            w = (game.white.type, game.white.level)
        if game.black.type == '':
            b = None
        else:
            b = (game.black.type, game.black.level)
        g = self.application.addGame(game.name, game.white.name, w, game.black.name, b)
        print 'Starting game %s between %s (%s) and %s (%s). (%i moves)' % \
              (game.name, game.white.name, str(game.white.type), game.black.name, str(game.black.type), len(game.moves))

        g.setTimer(game.duration, game.duration, game.duration)
        g.start(game.moves)
        
    def loadGame(self, path, configure):
        """Called by ui.UI"""
        try:
            p = chess.pgn.PGN(path, 1)
        except chess.pgn.Error, e:
            return e.description
        
        # Use the first game
        self.application.addPGNGame(p[0], path, configure)
        
        return None

    def onNewNetworkGame(self):
        """Called by ui.UIFeedback"""
        dialog = NetworkDialog(self)
        controller = self.controller.addNetworkDialog(dialog)
        dialog.controller = controller

    def onQuit(self):
        """Called by ui.UIFeedback"""
        self.application.quit()

class Application:
    """
    """
    # The glChess UI
    ui = None
    
    # The AI types
    __aiProfiles = None
    
    # Objects with IO keyed by file descriptor
    ioHandlers = None
    
    # Network connections keyed by file descriptor
    networkConnections = None
    
    # The network game detector
    __detector = None
    
    # The games present
    __games = None
    
    def __init__(self):
        """Constructor for glChess application"""
        self.__aiProfiles = {}
        self.__games = []
        self.ioHandlers = {}
        self.networkConnections = {}

        try:
            os.mkdir(DATA_DIR)
        except OSError:
            pass
        assert(os.path.isdir(DATA_DIR))
        
        self.__detector = None#GameDetector(self)

        self.ui = UI(self)
        
    def addAIProfile(self, profile):
        """Add a new AI profile into glChess.
        
        'profile' is the profile to add (ai.Profile).
        """
        name = profile.name
        assert(self.__aiProfiles.has_key(name) is False)
        self.__aiProfiles[name] = profile
        self.ui.controller.addAIEngine(name)

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
        self.ioHandlers[player.fileno()] = player
        self.ui.controller.watchFileDescriptor(player.fileno())

    def unwatchAIPlayer(self, player):
        """
        """
        self.ioHandlers.pop(player.fileno())

    def addGame(self, name, whiteName, whiteType, blackName, blackType):
        """Add a chess game into glChess.
        
        'name' is the name of the game (string).
        'whiteName' is the name of the white player (string).
        'whiteType' is a 2-tuple containing the AI profile name and difficulty level (str, str) or None for human players.
        'blackName' is the name of the black player (string).
        'blackType' is a 2-tuple containing the AI profile name and difficulty level (str, str) or None for human players.
        
        Returns the game object. Use game.start() to start the game.
        """
        # FIXME: Replace arguments with player objects
        
        # Create the game
        g = ChessGame(self, name)
        self.__games.append(g)

        msg = ''
        if whiteType is None:
            player = g.addHumanPlayer(whiteName)
        else:
            (profile, level) = whiteType
            player = g.addAIPlayer(whiteName, self.__aiProfiles[profile], level)
        g.setWhite(player)

        if blackType is None:
            player = g.addHumanPlayer(blackName)
        else:
            (profile, level) = blackType
            player = g.addAIPlayer(blackName, self.__aiProfiles[profile], level)
        g.setBlack(player)

        return g
    
    def addPGNGame(self, pgnGame, path, configure = False):
        """Add a PGN game.
        
        'pgnGame' is the game to add (chess.pgn.PGNGame).
        'path' is the path this game was loaded from (string or None).
        
        Returns the game object. Use game.start() to start the game.
        """
        gameProperties = ui.Game()

        gameProperties.path = path
        gameProperties.name = pgnGame.getTag(pgnGame.PGN_TAG_EVENT)
        gameProperties.white.name = pgnGame.getTag(pgnGame.PGN_TAG_WHITE)
        gameProperties.black.name = pgnGame.getTag(pgnGame.PGN_TAG_BLACK)
        gameProperties.moves = pgnGame.getMoves()
        
        missingEngines = False
        gameProperties.white.type = pgnGame.getTag('WhiteAI', '')
        if gameProperties.white.type == '':
            w = None
        else:
            if not self.__aiProfiles.has_key(gameProperties.white.type):
                missingEngines = True
            gameProperties.white.level = pgnGame.getTag('WhiteLevel')
            if gameProperties.white.level is None:
                gameProperties.white.level = 'normal'
            w = (gameProperties.white.type, gameProperties.white.level)

        gameProperties.black.type = pgnGame.getTag('BlackAI', '')
        if gameProperties.black.type == '':
            b = None
        else:
            if not self.__aiProfiles.has_key(gameProperties.black.type):
                missingEngines = True
            gameProperties.black.level = pgnGame.getTag('BlackLevel')
            if gameProperties.black.level is None:
                gameProperties.black.level = 'normal'
            b = (gameProperties.black.type, gameProperties.black.level)

        # If some of the properties were invalid display the new game dialog
        if missingEngines or configure:
            self.ui.controller.reportGameLoaded(game)
            return

        newGame = self.addGame(gameProperties.name, gameProperties.white.name, w, gameProperties.black.name, b)
        newGame.fileName = path
        if gameProperties.moves:
            newGame.start(gameProperties.moves)
        else:
            newGame.start()

        # Get the last player to resign if the file specifies it
        result = pgnGame.getTag(pgnGame.PGN_TAG_RESULT, None)
        if result == chess.pgn.PGNToken.GAME_TERMINATE_DRAW:
            if newGame.result == game.RESULT_IN_PROGRESS:
                newGame.getCurrentPlayer().resign()
            elif newGame.result != game.RESULT_DRAW:
                print 'PGN file specifies draw, glChess expects a win'
        elif result == chess.pgn.PGNToken.GAME_TERMINATE_WHITE_WIN:
            print 'FIXME: Handle white win in PGN'
        elif result == chess.pgn.PGNToken.GAME_TERMINATE_BLACK_WIN:
            print 'FIXME: Handle black win in PGN'

        duration = 0
        value = pgnGame.getTag(pgnGame.PGN_TAG_TIME_CONTROL)
        if value is not None:
            timers = value.split(':')
            try:
                duration = int(timers[0])
            except ValueError:
                print 'Unknown time control: ' + value
                
        value = pgnGame.getTag('WhiteTime', duration * 1000)
        try:
            whiteTime = int(value)
        except ValueError:
            whiteTime = duration
        value = pgnGame.getTag('BlackTime', duration * 1000)
        try:
            blackTime = int(value)
        except ValuError:
            blackTime = duration
        newGame.setTimer(duration, whiteTime / 1000, blackTime / 1000)

        # No change from when loaded
        newGame.needsSaving = False

        return newGame

    def addMove(self, view, move):
        # TEMP
        self.ui.controller.addMove(view, move)

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
            import time
            print 'loading...'
            s = time.time()
            try:
                p = chess.pgn.PGN(path, 1)
            except chess.pgn.Error, e:
                # TODO: Pop-up dialog
                print 'Unable to open PGN file ' + path + ':' + str(e)
            else:
                # Use the first game
                if len(p) > 0:
                    g = self.addPGNGame(p[0], path)
            print 'loaded in %f seconds' % (time.time() - s)

        # Start UI (does not return)
        try:
            self.ui.controller.run()
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
        # Notify the UI
        self.ui.controller.close()
        
        # Save any games not saved to a file
        self.__autosave()
        
        # Abort current games (will delete AIs etc)
        for game in self.__games[:]:
            game.abort()

        # Exit the application
        sys.exit()
        
    # Private methods
    
    def _removeGame(self, g):
        """
        """
        self.__games.remove(g)

    def __autoload(self):
        """Restore games from the autosave file"""
        path = AUTOSAVE_FILE
        
        try:
            p = chess.pgn.PGN(path)
            games = p[:]
        except chess.pgn.Error, e:
            print 'Ignoring invalid autoload file %s: %s' % (path, str(e))
            return
        except IOError, e:
            # The file doesn't have to exist...
            if e.errno != errno.ENOENT:
                print 'Unable to autoload from %s: %s' % (path, str(e))
            return
        
        print 'Auto-loading from ' + path + '...'
            
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
        
        fname = AUTOSAVE_FILE
        print 'Auto-saving to ' + fname + '...'
        
        try:
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
        except IOError, e:
            # FIXME: This should be in a dialog
            print 'Unable to autosave to %s: %s' % (fname, str(e))

if __name__ == '__main__':
    app = Application()
    app.start()
