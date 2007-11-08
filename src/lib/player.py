__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import game
import ai

class MovePlayer(game.ChessPlayer):
    """This class provides a pseudo-player to watch for piece movements"""

    def __init__(self, chessGame):
        """Constructor for a move player.
        
        'chessGame' is the game to make changes to (ChessGame).
        """
        self.__game = chessGame
        game.ChessPlayer.__init__(self, '@move')
        
    # Extended methods
        
    def onPlayerMoved(self, p, move):
        """Called by chess.board.ChessPlayer"""
        self.__game.needsSaving = True

        # Update clocks
        if p is self.__game.getWhite():
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
            p.endMove()
            
        self.__game.view.controller.addMove(move)

    def onGameEnded(self, game):
        """Called by chess.board.ChessPlayer"""
        self.__game.needsSaving = True
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
        self.window = application.ui.controller.addLogWindow(profile.name, executable, description)
        ai.Player.__init__(self, name, profile, level)
        
    def logText(self, text, style):
        """Called by ai.Player"""
        self.window.addText(text, style)
