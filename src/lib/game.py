"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import chess.board
import chess.san

class ChessMove:
    """
    """
    # The move number (game starts at 0)
    number     = 0
    
    # The player and piece that moved
    player     = None
    piece      = None

    # The start and end position of the move
    start      = None
    end        = None
    
    # The move in CAN and SAN format
    canMove    = ''
    sanMove    = ''

    # The overall game result of this move
    result = None

class ChessPlayer:
    """
    """
    # The name of the player
    __name = None
    __type = None
    
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

    def onPieceMoved(self, piece, start, end):
        """Called when a chess piece is moved.
        
        'piece' is the piece that has been moved (chess.board.ChessPiece).
        'start' is the location the piece in LAN format (string) or None if the piece has been created.
        'end' is the location the piece has moved to in LAN format (string) or None if the piece has been deleted.
        """
        pass
    
    def onPlayerMoved(self, player, move):
        """Called when a player has moved.
        
        'player' is the player that has moved (ChessPlayer).
        'move' is the record for this move (ChessMove).
        """
        pass
    
    def onGameEnded(self, winningPlayer = None):
        """Called when a chess game has ended.
        
        'winningPlayer' is the player that won or None if the game was a draw.
        """
        pass

    # Public methods

    def getName(self):
        """Get the name of this player.
        
        Returns the player name (string).
        """
        return self.__name

    def readyToMove(self):
        """
        """
        return self.__readyToMove
    
    def canMove(self, start, end, promotionType = chess.board.QUEEN):
        """
        """
        return self.__game.canMove(self, start, end, promotionType)

    def move(self, move):
        """
        """
        self.__game.move(self, move)
        
    # Private methods
    
    def _setGame(self, game):
        """
        """
        self.__game = game
        
    def _setReadyToMove(self, readyToMove):
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

    def onPieceMoved(self, piece, start, end):
        """Called by chess.board.ChessBoard"""
        self.__game._onPieceMoved(piece, start, end)

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
        
    __resultToSAN = {chess.board.MOVE_RESULT_ILLEGAL: False,
                     chess.board.MOVE_RESULT_ALLOWED: True,
                     chess.board.MOVE_RESULT_OPPONENT_CHECK: chess.san.SANConverter.CHECK,
                     chess.board.MOVE_RESULT_OPPONENT_CHECKMATE: chess.san.SANConverter.CHECKMATE}
        
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
        moveResult = self.__board.testMove(self.__sanToColour[colour], start, end, self.__sanToType[promotionType], allowSuicide)
        
        return self.__resultToSAN[moveResult]

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

    # Flag to show if calling a player and the queued up moves
    __notifyingPlayer = False
    __queuedMoves = None
    
    __moves = None
    
    def __init__(self):
        """Game constructor"""
        self.__players = []
        self.__spectators = []
        self.__board = ChessGameBoard(self)
        self.__sanConverter = ChessGameSANConverter(self.__board)
        self.__moves = []
        
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
    
    def addSpectator(self, player):
        """Add a spectator to the game.
        
        'player' is the player spectating.
        
        This can be called after the game has started.
        """
        self.__spectators.append(player)
        self.__connectPlayer(player)
        
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
        
        # Set initial state
        self.__queuedMoves = []
        self.__currentPlayer = self.__whitePlayer
        
        # Load starting moves
        try:
            for move in moves:
                self.move(self.__currentPlayer, move)
        except chess.san.Error, e:
            print e
            
        self.__started = True
        
        # Get the next player to move
        self.__currentPlayer._setReadyToMove(True)
        
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

        moveResult = self.__board.testMove(colour, start, end, promotionType = promotionType)
         
        return moveResult is not chess.board.MOVE_RESULT_ILLEGAL
    
    def move(self, player, move):
        """Get a player to make a move.
        
        'player' is the player making the move.
        'move' is the move to make in SAN or LAN format (string).
        """
        self.__queuedMoves.append((player, move))
        
        # Don't process if still finishing the last move
        if self.__notifyingPlayer:
            return
        
        while True:
            try:
                (movingPlayer, move) = self.__queuedMoves.pop(0)
            except IndexError:
                return

            if movingPlayer is not self.__currentPlayer:
                print 'Player attempted to move out of turn'
            else:
                self.__notifyingPlayer = True
                self._move(movingPlayer, move)
                self.__notifyingPlayer = False
            
    def _move(self, player, move):
        """
        """
        if self.__currentPlayer is self.__whitePlayer:
            nextPlayer = self.__blackPlayer
            colour = chess.board.WHITE
        else:
            nextPlayer = self.__whitePlayer
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
            
        if moveResult is chess.board.MOVE_RESULT_ILLEGAL:
            print 'Illegal move: ' + str(move)
            return
            
        move = ChessMove()
        if len(self.__moves) == 0:
            move.number = 1
        else:
            move.number = self.__moves[-1].number + 1
        move.player  = self.__currentPlayer
        move.start   = start
        move.end     = end
        move.canMove = canMove
        move.sanMove = sanMove
        move.result  = moveResult
        self.__moves.append(move)

        # This player has now moved
        self.__currentPlayer._setReadyToMove(False)
            
        # Inform other players of the result
        for player in self.__players:
            player.onPlayerMoved(self.__currentPlayer, move)
            
        # Notify the next player they can move
        self.__currentPlayer = nextPlayer
        if self.__started is True:
            nextPlayer._setReadyToMove(True)

    def getMoves(self):
        """
        """
        return self.__moves[:]
    
    def end(self):
        """End the game"""
        # Inform players
        for player in self.__players:
            player.onGameEnded()

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
                player.onPieceMoved(piece, None, coord)
                
    def _onPieceMoved(self, piece, start, end):
        """Called by the chess board"""
        
        # Notify all players of creations and deletions
        # NOTE: Normal moves are done above since the SAN moves are calculated before the move...
        # FIXME: Change this so the SAN moves are done afterwards...
        for player in self.__players:
            player.onPieceMoved(piece, start, end)

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
    
