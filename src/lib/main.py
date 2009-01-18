# -*- coding: utf-8 -*-
"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['Application']

import sys
import os
import errno
from gettext import gettext as _
import traceback
import time

import config
import ui
import gtkui
import game
import player
import chess.board
import chess.lan
import chess.pgn
import ai
import network
import display
import history

from defaults import *
       
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
    # The view watching this scene
    view           = None
    
    # The players in the game
    __movePlayer   = None
    __aiPlayers    = None

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
        
        self.fileName    = None
        self.inHistory   = False
        self.needsSaving = False
        
        # Call parent constructor
        game.ChessGame.__init__(self)

        self.view = display.View(self)
        self.view.controller = application.ui.controller.setView(name, self.view)
        self.view.updateRotation(animate = False)

        self.view.showMoveHints(config.get('show_move_hints') is True)
        self.view.showBoardNumbering(config.get('show_numbering') is True)
        self.view.showSmooth(config.get('show_3d_smooth') is True)        
        
        # Watch for piece moves with a player
        self.__movePlayer = player.MovePlayer(self)
        self.addSpectator(self.__movePlayer)
        
        self.date = time.strftime('%Y.%m.%d')

    def addAIPlayer(self, name, profile, level):
        """Create an AI player.
        
        'name' is the name of the player to create (string).
        'profile' is the the AI profile to use (ai.Profile).
        'level' is the difficulty level to use (string).
        
        Returns an AI player to use (game.ChessPlayer).
        """
        # Translators: Description of an AI player used in log window. %(name)s is replaced with
        # the name of the AI player. %(game)s is replaced with the name of the game the AI player
        # is in.
        description = _("'%(name)s' in '%(game)s'") % {'name': name, 'game': self.name}
        p = player.AIPlayer(self.application, name, profile, level, description)
        self.__aiPlayers.append(p)
        self.application.watchAIPlayer(p)
        return p

    def addHumanPlayer(self, name):
        """Create a human player.
        
        'name' is the name of the player to create.
        
        Returns a human player to use (game.ChessPlayer).
        """
        return player.HumanPlayer(self, name)

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
        
    def getHumanPlayer(self):
        """Get the human player.
        
        Returns the human player (HumanPlayer) or None if no human players.
        If both players are human the current player is returned.
        """
        c = self.getCurrentPlayer()
        if isinstance(c, player.HumanPlayer):
            return c
        white = self.getWhite()
        black = self.getWhite()
        if c is white:
            opponent = black
        else:
            opponent = white
        if isinstance(opponent, player.HumanPlayer):
            return opponent
        return None

    def currentPlayerIsHuman(self):
        """Test if the player to move is human.

        Returns True if the current player is human and able to move.
        """
        p = self.getCurrentPlayer()
        return isinstance(p, player.HumanPlayer) and p.isReadyToMove()

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
        p = self.getCurrentPlayer()
        if p is self.getWhite():
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
        p.move(move)

        # Notify move
        self.view.controller.setAttention(False)

    def toPGN(self, pgnGame):
        """Write the properties of this game into a PGN game.
        
        'pgnGame' is the game to write into (pgn.PGNGame). All the tags should be unset.
        """
        white = self.getWhite()
        black = self.getBlack()
        
        pgnGame.setTag(chess.pgn.TAG_EVENT, self.name)
        pgnGame.setTag(chess.pgn.TAG_WHITE, white.getName())
        pgnGame.setTag(chess.pgn.TAG_BLACK, black.getName())
        pgnGame.setTag(chess.pgn.TAG_DATE, self.date)

        results = {game.RESULT_WHITE_WINS: chess.pgn.RESULT_WHITE_WIN,
                   game.RESULT_BLACK_WINS: chess.pgn.RESULT_BLACK_WIN,
                   game.RESULT_DRAW:       chess.pgn.RESULT_DRAW}
        try:
            value = results[self.result]
        except KeyError:
            pass
        else:
            pgnGame.setTag(chess.pgn.TAG_RESULT, value)

        rules = {game.RULE_ABANDONMENT: chess.pgn.TERMINATE_ABANDONED,
                 game.RULE_TIMEOUT:     chess.pgn.TERMINATE_TIME_FORFEIT,
                 game.RULE_DEATH:       chess.pgn.TERMINATE_DEATH}
        try:
            value = rules[self.rule]
        except KeyError:
            pass
        else:
            pgnGame.setTag(chess.pgn.TAG_TERMINATION, value)

        if self.duration > 0:
            pgnGame.setTag(chess.pgn.TAG_TIME_CONTROL, str(self.duration))
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
            pgnMove = chess.pgn.PGNMove()
            pgnMove.move = m.sanMove
            pgnMove.nag = m.nag
            pgnMove.comment = m.comment
            pgnGame.addMove(pgnMove)

    def animate(self, timeStep):
        """
        """
        return self.view.scene.controller.animate(timeStep)
    
    def endMove(self, p):
        game.ChessGame.endMove(self, p)
        self.view.updateRotation()

    def remove(self):
        """Remove this game"""
        # Remove AI player windows
        for p in self.__aiPlayers:
            p.window.close()
            self.application.unwatchAIPlayer(p)

        # Stop the game
        self.abort()
        
        # Remove the game from the UI
        self.application._removeGame(self)
        self.view.controller.close()

    def setNeedsSaving(self, needsSaving):
        """
        """
        # Autosaved games don't need saving
        if self.inHistory:
            needsSaving = False

        if self.needsSaving == needsSaving:
            return
        self.needsSaving = needsSaving
        self.view.controller.setNeedsSaving(needsSaving)

    def save(self):
        """Save this game"""
        pgnGame = chess.pgn.PGNGame()
        self.toPGN(pgnGame)
        if self.inHistory:
            # Don't bother if haven't made any significant moves
            if len(self.getMoves()) < 2:
                return
            self.application.history.save(pgnGame, self.fileName)
        else:
            try:
                f = file(self.fileName, 'w')
                lines = pgnGame.getLines()
                for line in lines:
                    f.write(line + '\n')
                f.write('\n')
                f.close()
            except IOError, e:
                return e.strerror

        self.setNeedsSaving(False)
        self.application.logger.addLine('Saved game %s to %s' % (repr(self.name), self.fileName))
        
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
        
        self.splashscreen = display.Splashscreen(self)
        self.splashscreen.controller = self.controller.setView('', self.splashscreen, isPlayable = False)

        self.ggzConfig = network.GGZConfig()
        dialog = network.GGZNetworkDialog(self)
        self.networkDialog = dialog.controller = self.controller.addNetworkDialog(dialog)
        for server in self.ggzConfig.getServers():
            dialog.controller.addProfile(server, server.name)

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
            result = handler.read()
            if result is False:
                self.application.ioHandlers.pop(fd)
            return result

    def onWriteFileDescriptor(self, fd):
        """Called by ui.UIFeedback"""
        try:
            handler = self.application.ioHandlers[fd]
        except KeyError:
            return False
        else:
            result = handler.write()
            if result is False:
                self.application.ioHandlers.pop(fd)
            return result

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
        g = self.application.addLocalGame(game.name, game.white.name, w, game.black.name, b)
        if g is None:
            return
        g.inHistory = True
        self.application.logger.addLine('Starting game %s between %s (%s) and %s (%s). (%i moves)' % \
                                        (game.name,
                                         game.white.name, str(game.white.type),
                                         game.black.name, str(game.black.type), len(game.moves)))

        g.setTimer(game.duration, game.duration, game.duration)
        g.start(game.moves)
        
    def loadGame(self, path, configure):
        """Called by ui.UI"""
        try:
            p = chess.pgn.PGN(path, 1)
        except chess.pgn.Error, e:
            return e.message
        except IOError, e:
            return e.strerror
        
        # Use the first game
        self.application.addPGNGame(p[0], path, configure)
        
        return None

    def onNewNetworkGame(self):
        """Called by ui.UIFeedback"""
        self.networkDialog.setVisible(True)
        
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

    # The game in progress
    __game = None
    
    def __init__(self):
        """Constructor for glChess application"""
        self.__aiProfiles = {}
        self.ioHandlers = {}
        self.networkConnections = {}
       
        self.__detector = None#GameDetector(self)

        self.ui = UI(self)
        
        self.history = history.GameHistory()
        
        # Translators: Name of the log that displays application events
        title = _('Application Log')
        self.logger = self.ui.controller.addLogWindow(title, '', '')

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
        
    def watchAIPlayer(self, p):
        """
        """
        fd = p.fileno()
        if fd is not None:
            self.ioHandlers[fd] = p
            self.ui.controller.watchFileDescriptor(fd)

    def unwatchAIPlayer(self, p):
        """
        """
        fd = p.fileno()
        if fd is not None:
            self.ioHandlers.pop(fd)
            
    def addGame(self, name):
        if self.__game is not None:
            # Save the current game to the history
            if self.__game.inHistory:
                response = ui.SAVE_YES
            elif self.__game.needsSaving:
                response = self.ui.controller.requestSave('Save current game?')
            else:
                response = ui.SAVE_NO

            if response is ui.SAVE_YES:
                self.__game.save()
            elif response is ui.SAVE_ABORT:
                return None
        self.__game = ChessGame(self, name)
        return self.__game

    def addLocalGame(self, name, whiteName, whiteType, blackName, blackType):
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
        g = self.addGame(name)
        if g is None:
            return None

        msg = ''
        if whiteType is None:
            p = g.addHumanPlayer(whiteName)
        else:
            (profile, level) = whiteType
            p = g.addAIPlayer(whiteName, self.__aiProfiles[profile], level)
        g.setWhite(p)

        if blackType is None:
            p = g.addHumanPlayer(blackName)
        else:
            (profile, level) = blackType
            p = g.addAIPlayer(blackName, self.__aiProfiles[profile], level)
        g.setBlack(p)

        return g
    
    def addPGNGame(self, pgnGame, path, configure = False):
        """Add a PGN game.
        
        'pgnGame' is the game to add (chess.pgn.PGNGame).
        'path' is the path this game was loaded from (string or None).
        
        Returns the game object. Use game.start() to start the game.
        """
        gameProperties = ui.Game()

        gameProperties.path = path
        gameProperties.name = pgnGame.getTag(chess.pgn.TAG_EVENT)
        gameProperties.white.name = pgnGame.getTag(chess.pgn.TAG_WHITE)
        gameProperties.black.name = pgnGame.getTag(chess.pgn.TAG_BLACK)
        moves = []
        for pgnMove in pgnGame.getMoves():
            moves.append(pgnMove.move)
        gameProperties.moves = moves            

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
            self.ui.controller.reportGameLoaded(gameProperties)
            return

        newGame = self.addLocalGame(gameProperties.name, gameProperties.white.name, w, gameProperties.black.name, b)
        if newGame is None:
            return None
        newGame.date = pgnGame.getTag(chess.pgn.TAG_DATE)
        newGame.fileName = path
        if gameProperties.moves:
            newGame.start(gameProperties.moves)
        else:
            newGame.start()
            
        # Comment on each move
        # FIXME: This should be done through a method so the UI can update better
        moves = newGame.getMoves()
        pgnMoves = pgnGame.getMoves()
        for i in xrange(len(moves)):
            moves[i].comment = pgnMoves[i].comment
            moves[i].nag = pgnMoves[i].nag

        # Get the last player to resign if the file specifies it
        result = pgnGame.getTag(chess.pgn.TAG_RESULT, None)
        loser = None
        if result == chess.pgn.RESULT_DRAW:
            newGame.claimDraw()
            if newGame.result != game.RESULT_DRAW:
                newGame.endGame(game.RESULT_DRAW, game.RULE_AGREEMENT)
        elif result == chess.pgn.RESULT_INCOMPLETE:
            if newGame.result != game.RESULT_IN_PROGRESS:
                print "WARNING: PGN file specifies game in progress, glChess does't..."            
        elif result == chess.pgn.RESULT_WHITE_WIN:
            loser = newGame.getBlack()
        elif result == chess.pgn.RESULT_BLACK_WIN:
            loser = newGame.getWhite()
        if newGame.result == game.RESULT_IN_PROGRESS and loser is not None:
            loser.resign()

        duration = 0
        value = pgnGame.getTag(chess.pgn.TAG_TIME_CONTROL)
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
        
        # No need to save freshly loaded game
        newGame.setNeedsSaving(False)

        return newGame

    def start(self):
        """Run glChess.
        
        This method does not return.
        """
        self.logger.addLine('This is glChess %s' % VERSION)
        
        # Load AI profiles
        profiles = ai.loadProfiles()

        for p in profiles:
            p.detect()
            if p.path is not None:
                self.logger.addLine('Detected AI: %s at %s' % (p.name, p.path))
                self.addAIProfile(p)

        nArgs = len(sys.argv)

        # Load existing games
        if nArgs == 1:
            self.__autoload()
        
        # Load requested game
        elif nArgs == 2:
            path = sys.argv[1]
            import time
            self.logger.addLine('loading...')
            s = time.time()
            try:
                p = chess.pgn.PGN(path, 1)
            except chess.pgn.Error, e:
                # TODO: Pop-up dialog
                self.logger.addLine('Unable to open PGN file %s: %s' % (path, str(e)))
            except IOError, e:
                self.logger.addLine('Unable to open PGN file %s: %s' % (path, str(e)))
            else:
                # Use the first game
                if len(p) > 0:
                    g = self.addPGNGame(p[0], path)
            self.logger.addLine('loaded in %f seconds' % (time.time() - s))

        else:
            # FIXME: Should be in a dialog
            # Translators: Text displayed on the command-line if an unknown argument is passed
            print _('Usage: %s [game]') % sys.argv[0]
            sys.exit(0)

        # Start default game if no game present
        if self.__game is None and len(self.__aiProfiles) > 0:
            for p in profiles:
                if self.__aiProfiles.has_key(p.name):
                    aiName = p.name
                    break
            black = (aiName, 'easy')
            # Translators: Name of a human versus AI game. The %s is replaced with the name of the AI player
            gameName = _('Human versus %s') % aiName
            # Translators: Name of white player in a default game
            whiteName =  _('White')
            # Translators: Name of black player in a default game            
            blackName = _('Black')
            g = self.addLocalGame(gameName, whiteName, None, blackName, black)
            g.inHistory = True
            g.start()

        # Start UI (does not return)
        try:
            self.ui.controller.run()
        except:
            # FIXME: Isn't this done by bug-buddy?
            print _("""glChess has crashed. Please report this bug to http://bugzilla.gnome.org
Debug output:""")
            print traceback.format_exc()
            self.quit()
            sys.exit(1)
        
    def animate(self, timeStep):
        """
        """
        return self.__game.animate(timeStep)

    def quit(self):
        """Quit glChess"""
        if self.__game is not None:
            if self.__game.inHistory:
                response = ui.SAVE_YES
            elif self.__game.needsSaving:
                response = self.ui.controller.requestSave(_('Save game before closing?'))
            else:
                response = ui.SAVE_NO

            if response == ui.SAVE_YES:
                self.__game.save()
            elif response == ui.SAVE_ABORT:
                return

            # Abort current game (will delete AIs etc)
            self.__game.abort()

        # Notify the UI
        self.ui.controller.close()

        # Exit the application
        sys.exit()
        
    # Private methods

    def __autoload(self):
        """Restore games from the autosave file"""
        (pgnGame, fileName, inHistory) = self.history.getUnfinishedGame()
        if pgnGame is not None:
            g = self.addPGNGame(pgnGame, fileName)
            if g is not None:
                g.inHistory = inHistory

if __name__ == '__main__':
    app = Application()
    app.start()
