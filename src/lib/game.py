"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import chess.board
import chess.san

# Game results
RESULT_IN_PROGRESS         = '*'
RESULT_WHITE_WINS          = '1-0'
RESULT_BLACK_WINS          = '0-1'
RESULT_DRAW                = '1/2-1/2'

# Reasons for the result
RULE_CHECKMATE             = 'CHECKMATE'
RULE_STALEMATE             = 'STALEMATE'
RULE_TIMEOUT               = 'TIMEOUT'
RULE_FIFTY_MOVES           = 'FIFTY_MOVES'
RULE_THREE_FOLD_REPETITION = 'THREE_FOLD_REPETITION'
RULE_INSUFFICIENT_MATERIAL = 'INSUFFICIENT_MATERIAL'
RULE_RESIGN                = 'RESIGN'
RULE_DEATH                 = 'DEATH'

class ChessMove:
    """
    """
    # The move number (game starts at 0)
    number     = 0
    
    # The player and piece that moved
    player     = None
    piece      = None
    
    # The piece that was promoted to (or None)
    promotion  = None
    
    # The victim piece (or None)
    victim     = None

    # The start and end position of the move
    start      = None
    end        = None
    
    # The move in CAN and SAN format
    canMove    = ''
    sanMove    = ''

    # The game result after this move
    opponentInCheck = False
    opponentCanMove = False
    
    # If this move can be used as a resignation
    fiftyMoveRule = False
    threeFoldRepetition = False
    
    # A comment about this move
    comment = ''

    # Numeric annotation glyph for move
    nag     = ''

class ChessPlayer:
    """
    """
    # The name of the player
    __name = None
    
    # The game this player is in
    __game = None

    # Flag to show if this player is able to move
    __readyToMove = False
    
    def __init__(self, name):
        """Constructor for a chess player.

        'name' is the name of the player.
        """
        self.__name = str(name)

    # Methods to extend

    def onPieceMoved(self, piece, start, end, delete):
        """Called when a chess piece is moved.
        
        'piece' is the piece that has been moved (chess.board.ChessPiece).
        'start' is the location the piece in LAN format (string) or None if the piece has been created.
        'end' is the location the piece has moved to in LAN format (string).
        'delete' is a flag to show if the piece should be deleted when it arrives there (boolean).
        """
        pass
    
    def onPlayerMoved(self, player, move):
        """Called when a player has moved.
        
        'player' is the player that has moved (ChessPlayer).
        'move' is the record for this move (ChessMove).
        """
        pass

    def onGameEnded(self, game):
        """Called when a chess game has ended.
        
        'game' is the game that has ended (Game).
        """
        pass
    
    def readyToMove(self):
        """FIXME
        """
        pass

    # Public methods

    def getName(self):
        """Get the name of this player.
        
        Returns the player name (string).
        """
        return self.__name
    
    def getGame(self):
        """Get the game this player is in.
        
        Returns the game (Game) or None if not in a game.
        """
        return self.__game
    
    def getRemainingTime(self):
        """Get the amount of time this player has remaining.
        
        Returns the amount of time in milliseconds.
        """
        if self is self.__game.getWhite():
            timer = self.__game.whiteTimer
        elif self is self.__game.getBlack():
            timer = self.__game.blackTimer
        else:
            return 0
        
        if timer is None:
            return 0
        else:
            return timer.controller.getRemaining()

    def isReadyToMove(self):
        """
        """
        return self.__readyToMove
    
    def canMove(self, start, end, promotionType = chess.board.QUEEN):
        """
        """
        return self.__game.canMove(self, start, end, promotionType)

    def move(self, move):
        """Move a piece.
        
        'move' is the move to make in Normal/Long/Standard Algebraic format (string).
        """
        self.__game.move(self, move)
        
    def endMove(self):
        """Complete this players turn"""
        self.__game.endMove(self)
        
    def resign(self):
        """Resign from the game"""
        self.__game.resign(self)
        
    def outOfTime(self):
        """Report this players timer has expired"""
        self.__game.outOfTime(self)
        
    def die(self):
        """Report this player has died"""
        self.__game.killPlayer(self)

    # Private methods
    
    def _setGame(self, game):
        """
        """
        self.__game = game
        
    def _setReadyToMove(self, readyToMove):
        if self.__readyToMove == readyToMove:
            return
        self.__readyToMove = readyToMove
        if readyToMove is True:
            self.readyToMove()

class ChessGameBoard(chess.board.ChessBoard):
    """
    """
    
    # Reference to the game
    __game = None
    
    def __init__(self, game):
        """
        """
        self.__game = game
        chess.board.ChessBoard.__init__(self)

    def onPieceMoved(self, piece, start, end, delete):
        """Called by chess.board.ChessBoard"""
        self.__game._onPieceMoved(piece, start, end, delete)

class ChessGameSANConverter(chess.san.SANConverter):
    """
    """
        
    __colourToSAN = {chess.board.WHITE: chess.san.SANConverter.WHITE,
                     chess.board.BLACK: chess.san.SANConverter.BLACK}
    __sanToColour = {}
    for (a, b) in __colourToSAN.iteritems():
        __sanToColour[b] = a
        
    __typeToSAN = {chess.board.PAWN:   chess.san.SANConverter.PAWN,
                   chess.board.KNIGHT: chess.san.SANConverter.KNIGHT,
                   chess.board.BISHOP: chess.san.SANConverter.BISHOP,
                   chess.board.ROOK:   chess.san.SANConverter.ROOK,
                   chess.board.QUEEN:  chess.san.SANConverter.QUEEN,
                   chess.board.KING:   chess.san.SANConverter.KING}
    __sanToType = {}
    for (a, b) in __typeToSAN.iteritems():
        __sanToType[b] = a
        
    __board = None
        
    def __init__(self, board):
        self.__board = board
        chess.san.SANConverter.__init__(self)
    
    def decodeSAN(self, colour, move):
        (start, end, result, promotionType) = chess.san.SANConverter.decodeSAN(self, self.__colourToSAN[colour], move)
        return (start, end, self.__sanToType[promotionType])
    
    def encodeSAN(self, start, end, promotionType):
        if promotionType is None:
            promotion = self.QUEEN
        else:
            promotion = self.__typeToSAN[promotionType]
        return chess.san.SANConverter.encode(self, start, end, promotion)

    def getPiece(self, location):
        """Called by chess.san.SANConverter"""
        piece = self.__board.getPiece(location)
        if piece is None:
            return None
        return (self.__colourToSAN[piece.getColour()], self.__typeToSAN[piece.getType()])
    
    def testMove(self, colour, start, end, promotionType, allowSuicide = False):
        """Called by chess.san.SANConverter"""
        move = self.__board.testMove(self.__sanToColour[colour], start, end, self.__sanToType[promotionType], allowSuicide)
        if move is None:
            return False
        
        if move.opponentInCheck:
            if not move.opponentCanMove:
                return chess.san.SANConverter.CHECKMATE
            return chess.san.SANConverter.CHECK
        return True

class ChessGame:
    """
    """    
    # The players and spectators in the game
    __players = None
    __whitePlayer = None
    __blackPlayer = None
    __spectators = None
    
    # The board to move on
    __board = None
    
    # SAN en/decoders
    __sanConverter = None
    
    # The game state (started and player to move)
    __started = False
    __currentPlayer = None
    
    __moves = None
    
    __inCallback = False
    __queuedCalls = None
    
    result  = RESULT_IN_PROGRESS
    rule    = None
    
    whiteTimer = None
    blackTimer = None
    
    def __init__(self):
        """Game constructor"""
        self.__players = []
        self.__spectators = []
        self.__board = ChessGameBoard(self)
        self.__sanConverter = ChessGameSANConverter(self.__board)
        self.__moves = []
        self.__queuedCalls = []
        
    def getAlivePieces(self, moveNumber = -1):
        """Get the alive pieces on the board.
        
        'moveNumber' is the move to get the pieces from (integer).
        
        Returns a dictionary of the alive pieces (board.ChessPiece) keyed by location.
        Raises an IndexError exception if moveNumber is invalid.
        """
        return self.__board.getAlivePieces(moveNumber)
    
    def getDeadPieces(self, moveNumber = -1):
        """Get the dead pieces from the game.
        
        'moveNumber' is the move to get the pieces from (integer).
        
        Returns a list of the pieces (board.ChessPiece) in the order they were killed.
        Raises an IndexError exception if moveNumber is invalid.
        """
        return self.__board.getDeadPieces(moveNumber)
    
    def setTimers(self, whiteTimer, blackTimer):
        """
        """
        self.whiteTimer = whiteTimer
        self.blackTimer = blackTimer

    def setWhite(self, player):
        """Set the white player in the game.
        
        'player' is the player to use as white.
        
        If the game has started or there is a white player an exception is thrown.
        """
        assert(self.__started is False)
        assert(self.__whitePlayer is None)
        self.__whitePlayer = player
        self.__connectPlayer(player)

    def getWhite(self):
        """Returns the current white player (player.Player)"""
        return self.__whitePlayer
    
    def setBlack(self, player):
        """Set the black player in the game.
        
        'player' is the player to use as black.
        
        If the game has started or there is a black player an exception is thrown.
        """
        assert(self.__started is False)
        assert(self.__blackPlayer is None)
        self.__blackPlayer = player
        self.__connectPlayer(player)
        
    def getBlack(self):
        """Returns the current white player (player.Player)"""
        return self.__blackPlayer
    
    def getCurrentPlayer(self):
        """Get the player to move"""
        return self.__currentPlayer
    
    def addSpectator(self, player):
        """Add a spectator to the game.
        
        'player' is the player spectating.
        
        This can be called after the game has started.
        """
        self.__spectators.append(player)
        self.__connectPlayer(player)

    def isStarted(self):
        """Returns True if the game has been started"""
        return self.__started
        
    def start(self, moves = []):
        """Start the game.
        
        'moves' is a list of moves to start with.
        
        If there is no white or black player then an exception is raised.
        """
        assert(self.__whitePlayer is not None and self.__blackPlayer is not None)
        
        # Disabled for now
        #import network
        #self.x = network.GameReporter('Test Game', 12345)
        #print 'Reporting'

        # Load starting moves
        self.__currentPlayer = self.__whitePlayer
        for move in moves:
            self.move(self.__currentPlayer, move)
            if self.__currentPlayer is self.__whitePlayer:
                self.__currentPlayer = self.__blackPlayer
            else:
                self.__currentPlayer = self.__whitePlayer

        self.__started = True
        
        self.startLock()
        
        # Get the next player to move
        self.__currentPlayer._setReadyToMove(True)

        self.endLock()
        
    def getSquareOwner(self, coord):
        """TODO
        """
        piece = self.__board.getPiece(coord)
        if piece is None:
            return None
        
        colour = piece.getColour()
        if colour is chess.board.WHITE:
            return self.__whitePlayer
        elif colour is chess.board.BLACK:
            return self.__blackPlayer
        else:
            return None
        
    def canMove(self, player, start, end, promotionType):
        """Test if a player can move.
        
        'player' is the player making the move.
        'start' is the location to move from in LAN format (string).
        'end' is the location to move from in LAN format (string).
        'promotionType' is the piece type to promote pawns to. FIXME: Make this a property of the player
        
        Return True if can move, otherwise False.
        """
        if player is not self.__currentPlayer:
            return False
        
        if player is self.__whitePlayer:
            colour = chess.board.WHITE
        elif player is self.__blackPlayer:
            colour = chess.board.BLACK
        else:
            assert(False)

        move = self.__board.testMove(colour, start, end, promotionType = promotionType)

        return move is not None
    
    def move(self, player, move):
        """Get a player to make a move.
        
        'player' is the player making the move.
        'move' is the move to make in SAN or LAN format (string).
        """
        if self.__inCallback:
            self.__queuedCalls.append((self.move, (player, move)))
            return
        
        self.startLock()
        
        if player is not self.__currentPlayer:
            print 'Player attempted to move out of turn'
        else:
            self._move(player, move)

        self.endLock()
        
    def startLock(self):
        assert(self.__inCallback is False)
        self.__inCallback = True
        
    def endLock(self):
        self.__inCallback = False
        while len(self.__queuedCalls) > 0:
            (call, args) = self.__queuedCalls[0]
            self.__queuedCalls = self.__queuedCalls[1:]
            call(*args)

    def _move(self, player, move):
        """
        """
        if self.__currentPlayer is self.__whitePlayer:
            colour = chess.board.WHITE
        else:
            colour = chess.board.BLACK

        # If move is SAN process it as such
        try:
            (start, end, _, _, promotionType, _) = chess.lan.decode(colour, move)
        except chess.lan.DecodeError, e:
            try:
                (start, end, promotionType) = self.__sanConverter.decodeSAN(colour, move)
            except chess.san.Error, e:
                print 'Invalid move: ' + move
                return

        # Only use promotion type if a pawn move to far file
        victim = self.__board.getPiece(end)
        piece = self.__board.getPiece(start)
        promotion = None
        if piece is not None and piece.getType() is chess.board.PAWN:
            if colour is chess.board.WHITE:
                if end[1] == '8':
                    promotion = promotionType
            else:
                if end[1] == '1':
                    promotion = promotionType

        # Re-encode for storing and reporting
        sanMove = self.__sanConverter.encodeSAN(start, end, promotionType)
        canMove = chess.lan.encode(colour, start, end, promotionType = promotion)
        moveResult = self.__board.movePiece(colour, start, end, promotionType)

        if moveResult is None:
            print 'Illegal move: ' + str(move)
            return

        m = ChessMove()
        if len(self.__moves) == 0:
            m.number = 1
        else:
            m.number = self.__moves[-1].number + 1
        m.player              = self.__currentPlayer
        m.piece               = piece
        m.victim              = victim
        m.start               = start
        m.end                 = end
        m.canMove             = canMove
        m.sanMove             = sanMove
        m.opponentInCheck     = moveResult.opponentInCheck
        m.opponentCanMove     = moveResult.opponentCanMove
        m.fiftyMoveRule       = moveResult.fiftyMoveRule
        m.threeFoldRepetition = moveResult.threeFoldRepetition
        #FIXME: m.comment             = move.comment
        #FIXME: m.nag                 = move.nag

        self.__moves.append(m)

        # This player has now moved
        self.__currentPlayer._setReadyToMove(False)

        # Inform other players of the result
        for player in self.__players:
            player.onPlayerMoved(self.__currentPlayer, m)

        # Check if the game has ended
        result = RESULT_IN_PROGRESS
        if not m.opponentCanMove:
            if self.__currentPlayer is self.__whitePlayer:
                result = RESULT_WHITE_WINS
            else:
                result = RESULT_BLACK_WINS
            if m.opponentInCheck:
                rule = RULE_CHECKMATE
            else:
                result = RESULT_DRAW
                rule = RULE_STALEMATE
        
        if result is not RESULT_IN_PROGRESS:
            self.endGame(result, rule)

    def endMove(self, player):
        """
        """
        if self.__inCallback:
            self.__queuedCalls.append((self.endMove, (player,)))
            return
        
        if player is not self.__currentPlayer:
            print 'Player attempted to move out of turn'
            return
        if player.move is None:
            print "Ending move when haven't made one"
            return

        if self.__currentPlayer is self.__whitePlayer:
            self.__currentPlayer = self.__blackPlayer
        else:
            self.__currentPlayer = self.__whitePlayer
        
        self.startLock()

        # Notify the next player they can move
        if self.__started is True:
            self.__currentPlayer._setReadyToMove(True)

        self.endLock()

    def resign(self, player):
        """Get a player to resign.
        
        'player' is the player resigning.
        """
        if player is not self.__currentPlayer:
            print 'Player attempted to resign out of turn'
            return

        # See if the resignation can be done without requesting
        rule = RULE_RESIGN
        try:
            move = self.__moves[-1]
        except IndexError:
            pass
        else:
            if move.fiftyMoveRule:
                rule = RULE_FIFTY_MOVES
            elif move.threeFoldRepetition:
                rule = RULE_THREE_FOLD_REPETITION

        self.endGame(RESULT_DRAW, rule)
        
    def killPlayer(self, player):
        """Report a player has died
        
        'player' is the player that has died.
        """
        if player is self.__whitePlayer:
            result = RESULT_BLACK_WINS
        elif player is self.__blackPlayer:
            result = RESULT_WHITE_WINS       
        self.endGame(result, RULE_DEATH)

    def outOfTime(self, player):
        """Report a player's timer has expired"""
        if player is self.__whitePlayer:
            result = RESULT_BLACK_WINS
        elif player is self.__blackPlayer:
            result = RESULT_WHITE_WINS
        else:
            assert(False)
        self.endGame(result, RULE_TIMEOUT)
        
    def endGame(self, result, rule):
        self.result = result
        self.rule = rule
        for player in self.__players:
            player.onGameEnded(self)

    def getMoves(self):
        """
        """
        return self.__moves

    def abort(self):
        """End the game"""
        # Inform players
        for player in self.__players:
            player.onGameEnded(self)

    # Private methods:

    def __connectPlayer(self, player):
        """Add a player into the game.
        
        'player' is the player to add.
        
        The player will be notified of the current state of the board.
        """
        self.__players.append(player)
        player._setGame(self)
        
        # Notify the player of the current state
        # FIXME: Make the board iteratable...
        for file in '12345678':
            for rank in 'abcdefgh':
                coord = rank + file
                piece = self.__board.getPiece(coord)
                if piece is None:
                    continue

                # These are moves from nowhere to their current location
                player.onPieceMoved(piece, None, coord, False)

    def _onPieceMoved(self, piece, start, end, delete):
        """Called by the chess board"""
        
        # Notify all players of creations and deletions
        # NOTE: Normal moves are done above since the SAN moves are calculated before the move...
        # FIXME: Change this so the SAN moves are done afterwards...
        for player in self.__players:
            player.onPieceMoved(piece, start, end, delete)

class NetworkChessGame(ChessGame):
    """
    """
    
    def move(self, player, move):
        """Get a player to make a move.
        
        'player' is the player making the move.
        'move' is the move to make. It can be of the form:
               A coordinate move in the form ((file0, rank0), (file1, rank1), promotionType) ((int, int), (int, int), chess.board.PIECE_TYPE) or
               A SAN move (string).
        """
        # Send to the server
        
            
if __name__ == '__main__':
    game = ChessGame()
    
    import pgn
    
    p = pgn.PGN('black.pgn')
    g = p.getGame(0)

    class PGNPlayer(ChessPlayer):
        __moveNumber = 1
        
        __isWhite = True
        
        def __init__(self, isWhite):
            self.__isWhite = isWhite
        
        def readyToMove(self):
            if self.__isWhite:
                move = g.getWhiteMove(self.__moveNumber)
            else:
                move = g.getBlackMove(self.__moveNumber)
            self.__moveNumber += 1
            self.move(move)
            
    white = PGNPlayer(True)
    black = PGNPlayer(False)
    
    game.setWhite(white)
    game.setBlack(black)
    
    game.start()
