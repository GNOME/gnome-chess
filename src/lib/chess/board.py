"""Module implementing the chess rules.

To use create an instance of the chess board:
>>> b = board.ChessBoard()

Board locations can be represented in two forms:
o A 2-tuple containing the file and rank as integers (see below).
o A string with the location in SAN format.

e.g. The black king is on the square (4,7) or 'e8'.

The chess board with rank and file numbers:

             Black Pieces

   +---+---+---+---+---+---+---+---+
7  |<R>|<N>|<B>|<Q>|<K>|<B>|<N>|<R>|
   +---+---+---+---+---+---+---+---+
6  |<P>|<P>|<P>|<P>|<P>|<P>|<P>|<P>|
   +---+---+---+---+---+---+---+---+
5  |   | . |   | . |   | . |   | . |
   +---+---+---+---+---+---+---+---+
4  | . |   | . |   | . |   | . |   |
   +---+---+---+---+---+---+---+---+
3  |   | . |   | . |   | . |   | . |
   +---+---+---+---+---+---+---+---+
2  | . |   | . |   | . |   | . |   |
   +---+---+---+---+---+---+---+---+
1  |-P-|-P-|-P-|-P-|-P-|-P-|-P-|-P-|
   +---+---+---+---+---+---+---+---+
0  |-R-|-N-|-B-|-Q-|-K-|-B-|-N-|-R-|
   +---+---+---+---+---+---+---+---+
     0   1   2   3   4   5   6   7
     
             White Pieces
             
Pieces are moved by:
>>> result = b.movePiece(board.WHITE, 'd1', 'd3')
If the result is not MOVE_RESULT_ILLEGAL then the internal
state is updated and the next player can move.
If the result is MOVE_RESULT_ILLEGAL then the request is ignored.

A move can be checked if it is legal first by:
>>> result = b.testMove(board.WHITE, 'd1', 'd3')
The returns the same values as movePiece() except the internal state
is never updated.

The location of pieces can be checked using:
>>> piece = b.getPiece('e1')
>>> pieces = b.getAlivePieces()
>>> casualties = b.getDeadPieces()
The locations are always in the 2-tuple format.
These methods return references to the ChessPiece objects on the board.

The history of the game can be retrieved by passing a move number to
the get*() methods. This number is the move count from the game start.
It also supports negative indexing:
0  = board before game starts
1  = board after white's first move
2  = board after black's first move
-1 = The last move
e.g.
To get the white pieces after whites second move.
>>> pieces = b.getAlivePieces(3)

The ChessPiece objects are static per board. Thus references can be compared
between move 0 and move N. Note promoted pieces are a new piece object.

When any piece is moved onPieceMoved() method is called. If the ChessBoard
class is extended this signal can be picked up by the user. If movePiece()
or testMove() is called while in this method an exception is raised.
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['ChessPiece', 'ChessBoard']

# The two players
WHITE = 'White'
BLACK = 'Black'

# The piece types
PAWN   = 'P'
ROOK   = 'R'
KNIGHT = 'N'
BISHOP = 'B'
QUEEN  = 'Q'
KING   = 'K'

# Move results
MOVE_RESULT_ILLEGAL            = 'Illegal move'
MOVE_RESULT_OPPONENT_CHECK     = 'Opponent put into check'
MOVE_RESULT_OPPONENT_CHECKMATE = 'Opponent put into checkmate'
MOVE_RESULT_ALLOWED            = 'Valid move'

class ChessPiece:
    """An object representing a chess piece"""
    
    # The colour of the piece
    __colour = None
    
    # The type of the piece (pawn, knight ...) 
    __type = None
    
    def __init__(self, colour, type):
        """Constructor for a chess piece.
        
        'colour' is the piece colour (WHITE or BLACK).
        'type' is the piece type (PAWN, ROOK, KNIGHT, BISHOP, QUEEN or KING).
        """
        self.__colour = colour
        self.__type = type
        
    def getColour(self):
        """Get the colour of this piece.
        
        Returns WHITE or BLACK.
        """
        return self.__colour
    
    def getType(self):
        """Get the type of this piece.
        
        Returns PAWN, ROOK, KNIGHT, BISHOP, QUEEN or KING.
        """
        return self.__type
    
    def __str__(self):
        """Returns a string representation of this piece"""
        return self.__colour + ' ' + self.__type
    
class ChessPlayerState:
    """
    """
    
    # Flags to show if still able to castle
    canShortCastle = True
    canLongCastle = True
    
    def __init__(self, state = None):
        """
        """
        if state is None:
            return

        # Copy the exisiting state
        self.canShortCastle = state.canShortCastle
        self.canLongCastle = state.canLongCastle

class ChessBoardState:
    """
    """    
    # The move number 
    moveNumber = 0
    
    # A dictionary of piece by location
    squares = None
    
    # The dead pieces in the order they were killed
    casualties = None
    
    # The move that got us to this state
    lastMove = None

    # If the last move was a pawn martch The location where it can be taken by en-passant
    enPassantSquare = None

    # The state of the players
    whiteState = None
    blackState = None

    def __init__(self, lastState = None):
        """Constuctor for storing the state of a chess board.
        
        'lastState' is the previous board state
                    or a dictionary containing the initial state of the board
                    or None to start an empty board.

        Example:
            
        pawn = ChessPiece(WHITE, PAWN)
        ChessBoardState({'a2'': pawn, ...})
        
        Note if a dictionary is provided the casualties will only record the pieces
        killed from this point onwards.
        """
        # Start empty
        if lastState is None:
            self.moveNumber = 0
            self.squares = {}
            self.casualties = []
            self.whiteState = ChessPlayerState()
            self.blackState = ChessPlayerState()
            
        # Use provided initial pieces
        elif type(lastState) is dict:
            self.moveNumber = 0
            self.squares = {}
            self.casualties = []
            for coord, piece in lastState.iteritems():
                self.squares[coord] = piece
            self.whiteState = ChessPlayerState()
            self.blackState = ChessPlayerState()

        # Copy exisiting state
        elif isinstance(lastState, ChessBoardState):
            self.moveNumber = lastState.moveNumber + 1
            self.squares = lastState.squares.copy()
            self.casualties = lastState.casualties[:]
            self.lastMove = lastState.lastMove
            self.enPassantSquare = lastState.enPassantSquare
            self.whiteState = ChessPlayerState(lastState.whiteState)
            self.blackState = ChessPlayerState(lastState.blackState)

        else:
            raise TypeError('ChessBoardState(oldState) or ChessBoardState({(0,0):pawn, ...})')

    def getPiece(self, location):
        """Get the piece at a given location.
        
        'location' is the location in LAN format (string).
        
        Return the piece at this location or None if there is no piece there.
        """
        assert(type(location) is str and len(location) == 2)
        try:
            return self.squares[location]
        except KeyError:
            return None

    def __range(self, start, end):
        """
        """
        startNum = ord(start)
        endNum = ord(end)
        rangeString = ''
        if startNum > endNum:
            step = -1
            a = startNum
            b = endNum - 1
        else:
            step = 1
            a = startNum
            b = endNum + 1
        for i in xrange(a, b, step):
            rangeString += chr(i)
        return rangeString
    
    def __checkOrtho(self, rankRange, fileRange):
        """Check if the space between two squares is empty.
        
        'start' is the first square in the form (file,rank).
        'end' is the last square in the form (file,rank).
        
        Return True if the squares between these two are empty and the move is a
        valid orthogonal move.
        """
        if len(rankRange) == 1:
            for file in fileRange[1:-1]:
                coord = rankRange[0] + file
                if self.squares.has_key(coord):
                    return False
            
        elif len(fileRange) == 1:
            for rank in rankRange[1:-1]:
                coord = rank + fileRange[0]
                if self.squares.has_key(coord):
                    return False
            
        else:
            return False

        return True

    def __checkDiag(self, rankRange, fileRange):
        # For diagonal moves change in co-ordinates must be identical
        if len(rankRange) != len(fileRange):
            return False
        
        # Check the squares between the start and end moves
        for i in xrange(1, len(rankRange) - 1):
            coord = rankRange[i] + fileRange[i]
            if self.squares.has_key(coord):
                return False
        
        return True
    
    def inCheck(self, colour):
        """Test if the player with the given colour is in check.
        
        'colour' is the colour of the player to check.
        
        Return True if they are in check (or checkmate) or False otherwise.
        """
        # Find the location of this players king(s)
        for kingCoord, king in self.squares.iteritems():
            # Not our king
            if king.getType() != KING or king.getColour() != colour:
                continue
            
            # See if any enemy pieces can take this king
            for enemyCoord, enemyPiece in self.squares.iteritems():
                # Ignore friendly pieces
                if enemyPiece.getColour() == colour:
                    continue
                    
                # See if this piece can take the king
                (result, moves) = self.movePiece(enemyPiece.getColour(), enemyCoord, kingCoord,
                                                 testCheck = False, testCheckMate = False,
                                                 applyMove = False)
                if result is not MOVE_RESULT_ILLEGAL:
                    return True

        return False
    
    def inCheckMate(self, colour):
        """Test if the player with the given colour is in checkmate.
        
        'colour' is the colour of the player to check.
        
        Return True if they are in checkmate or False otherwise.
        """
        # If can move any of their pieces then not in checkmate
        for coord, piece in self.squares.iteritems():
            # Only check pieces of the given colour
            if piece.getColour() != colour:
                continue

            # See if this piece can be moved anywhere
            for rank in 'abcdefgh':
                for file in '12345678':
                    (result, moves) = self.movePiece(colour, coord, rank + file,
                                                     testCheckMate = False, applyMove = False)
                    if result is not MOVE_RESULT_ILLEGAL:
                        return False
        return True
    
    def movePiece(self, colour, start, end, promotionType = QUEEN, testCheck = True, testCheckMate = True, allowSuicide = False, applyMove = True):
        """Move a piece.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in LAN format (string).
        'end' is a the location to move to in LAN format (string).
        'promotionType' is the type of piece to promote to if required.
        'testCheck' is a flag to control if the opponent will be in check after this move.
        'testCheckMate' is a flag to control if the opponent will be in checkmate after this move.
        'allowSuicide' if True means a move is considered valid even
                       if it would put the moving player in check.
        'applyMove' is a flag to control if the move is applied to the board (True) or just tested (False).
        
        Return a tuple containing the result of this move and the pieces moved in the form (result, moves).
        The moves are a list containing tuples of the form (piece, start, end). If a piece was removed
        'end' is None. If the result is successful the pieces on the board are modified.
        """
        assert(promotionType is not KING)
        assert(type(start) is str and len(start) == 2)
        assert(type(end) is str and len(end) == 2)
        
        # A list of pieces that have been moved
        moves = []
        
        # Get the piece to move
        try:
            piece = self.squares[start]
        except KeyError:
            return (MOVE_RESULT_ILLEGAL, None)
        if piece.getColour() is not colour:
            return (MOVE_RESULT_ILLEGAL, None)
        
        # Get the players
        if piece.getColour() is WHITE:
            enemyColour = BLACK
            playerState = self.whiteState
        elif piece.getColour() is BLACK:
            enemyColour = WHITE
            playerState = self.blackState
        else:
            assert(False)
        
        # Copy the player state before it is changed
        originalPlayerState = ChessPlayerState(playerState)

        # Check if moving onto another piece (must be enemy)
        try:
            target = self.squares[end]
            if target.getColour() == piece.getColour():
                return (MOVE_RESULT_ILLEGAL, None)
        except KeyError:
            target = None
        victim = target
        
        # Get the range of rank and files being moved over
        rankRange = self.__range(start[0], end[0])
        fileRange = self.__range(start[1], end[1])
        assert(len(rankRange) >= 1)
        assert(len(fileRange) >= 1)

        # Get the rank relative to this colour's start rank
        if piece.getColour() == BLACK:
            baseFile = '8'
        else:
            baseFile = '1'
            
        # The new en-passant square
        enPassantSquare = None

        # Check move is valid:
        
        # King can move one square or castle
        if piece.getType() is KING:
            # Castling:
            shortCastle = ('e' + baseFile, 'g' + baseFile)
            longCastle  = ('e' + baseFile, 'c' + baseFile)
            if (playerState.canShortCastle and (start, end) == shortCastle) or (playerState.canLongCastle and (start, end) == longCastle):
                if end[0] == 'c':
                    rookLocation = 'a' + baseFile
                    rookEndLocation = 'd' + baseFile
                    kingRanks = 'cd'
                else:
                    rookLocation = 'h' + baseFile
                    rookEndLocation = 'f' + baseFile
                    kingRanks = 'fg'

                # Check rook is still there
                try:
                    rook = self.squares[rookLocation]
                except KeyError:
                    return (MOVE_RESULT_ILLEGAL, None)
                if rook is None or rook.getType() is not ROOK or rook.getColour() != piece.getColour():
                    return (MOVE_RESULT_ILLEGAL, None)

                # Check no pieces between the rook and king
                for rank in kingRanks:
                    if self.squares.has_key(rank + start[1]):
                        return (MOVE_RESULT_ILLEGAL, None)

                # Test if in check on any of the squares the king moves
                # through by filling these squares with cloned kings
                for rank in kingRanks:
                    self.squares[rank + start[1]] = piece
                inCheck =  self.inCheck(piece.getColour())
                for rank in kingRanks:
                    self.squares.pop(rank + start[1])

                if inCheck:
                    return (MOVE_RESULT_ILLEGAL, None)

                # Move rook and record so can be undone
                moves.append((rook, rookLocation, rookEndLocation))

            # Otherwise can only move one square
            else:
                if len(rankRange) > 2 or len(fileRange) > 2:
                    return (MOVE_RESULT_ILLEGAL, None)
                
            # Can no longer castle if moved the king
            playerState.canShortCastle = False
            playerState.canLongCastle = False
            
            moves.append((piece, start, end))
                
        # Queen moves orthogonal or diagonal
        elif piece.getType() is QUEEN:
            if (not self.__checkOrtho(rankRange, fileRange)) and (not self.__checkDiag(rankRange, fileRange)):
                return (MOVE_RESULT_ILLEGAL, None)
            moves.append((piece, start, end))

        # Rooks move orthogonal
        elif piece.getType() is ROOK:
            if not self.__checkOrtho(rankRange, fileRange):
                return (MOVE_RESULT_ILLEGAL, None)
            
            # Can no longer castle once have move the required rook
            if start == 'a' + baseFile:
                playerState.canLongCastle = False
            elif start == 'h' + baseFile:
                playerState.canShortCastle = False
            moves.append((piece, start, end))

        # Bishops move diagonal
        elif piece.getType() is BISHOP:
            if not self.__checkDiag(rankRange, fileRange):
                return (MOVE_RESULT_ILLEGAL, None)
            moves.append((piece, start, end))

        # Knights can move through other pieces
        elif piece.getType() is KNIGHT:
            if (len(rankRange) - 1) * (len(fileRange) - 1) != 2:
                return (MOVE_RESULT_ILLEGAL, None)
            moves.append((piece, start, end))

        # On base rank pawns move on or two squares forwards.
        # Pawns take other pieces diagonally (1 square).
        # Pawns can take other pawns moving two ranks using 'en passant'.
        # Pawns are promoted on reaching the other side of the board.
        elif piece.getType() is PAWN:
            # Pawns must move forwards
            if colour is WHITE:
                if end[1] < start[1]:
                    return (MOVE_RESULT_ILLEGAL, None)
            elif start[1] < end[1]:
                return (MOVE_RESULT_ILLEGAL, None)

            # Calculate the files that pawns start on and move over on marches
            if baseFile == '1':
                pawnFile  = '2'
                marchFile = '3'
                farFile   = '8'
            else:
                pawnFile  = '7'
                marchFile = '6'
                farFile   = '1'
            
            # Moving one square forwards with nothing in the way
            if len(rankRange) == 1 and len(fileRange) == 2 and victim is None:
                pass

            # Moving two squares forward from start rank (march)
            elif len(rankRange) == 1 and start[1] == pawnFile and len(fileRange) == 3 and victim is None:
                # If two steps check nothing inbetween
                if not self.__checkOrtho(rankRange, fileRange):
                    return (MOVE_RESULT_ILLEGAL, None)
                
                # The square we moved over can be attacked by en-passant
                enPassantSquare = start[0] + marchFile
    
            # Moving diagonally forwards to take another piece
            elif len(rankRange) == 2 and len(fileRange) == 2:
                # We either need a victim or be attacking the en-passant square
                if victim is None:
                    if end != self.enPassantSquare:
                        return (MOVE_RESULT_ILLEGAL, None)
                    
                    # Kill the pawn that moved
                    moves.append((self.lastMove[0], self.lastMove[2], None))

            else:
                return (MOVE_RESULT_ILLEGAL, None)
            
            # Promote pawns when they hit the far rank
            if end[1] == farFile:
                # Delete the current piece and create a new piece
                moves.append((piece, start, None))
                moves.append((ChessPiece(piece.getColour(), promotionType), None, end))
            else:
                moves.append((piece, start, end))

        # Unknown piece
        else:
            assert(False)
            
        # Store this move
        oldLastMove = self.lastMove
        self.lastMove = (piece, start, end)
        oldEnPassantSquare = self.enPassantSquare
        self.enPassantSquare = enPassantSquare

        # Delete a victim
        if victim is not None:
            moves.append((victim, end, None))
            
        # Move the pieces:

        # Remove the moving pieces from the board
        for (p, s, e) in moves:
            if s is not None:
                self.squares.pop(s)
                
        # Put pieces in their new locations
        for (p, s, e) in moves:
            if e is not None:
                self.squares[e] = p

        # Test for check and checkmate
        result = MOVE_RESULT_ALLOWED
        if testCheck:
            # Cannot move into check, if would be then undo move
            if self.inCheck(piece.getColour()):
                applyMove = False
                result = MOVE_RESULT_ILLEGAL
            # Test if the oponent is in check
            else:
                if self.inCheck(enemyColour):
                    if testCheckMate and self.inCheckMate(enemyColour):
                        result = MOVE_RESULT_OPPONENT_CHECKMATE
                    else:
                        result = MOVE_RESULT_OPPONENT_CHECK

        # Undo the moves if only a test
        if applyMove is False:
            # Empty any squares moved into
            for (p, s, e) in moves:
                if e is not None:
                    self.squares.pop(e)
                        
            # Put pieces back into their original locatons
            for (p, s, e) in moves:
                if s is not None:
                    self.squares[s] = p

            # Undo player state
            if piece.getColour() == WHITE:
                self.whiteState = originalPlayerState
            else:
                self.blackState = originalPlayerState
            
            # Undo stored move and en-passant location
            self.lastMove = oldLastMove
            self.enPassantSquare = oldEnPassantSquare
            
        else:
            # Remember the casualties
            if victim is not None:
                self.casualties.append(victim)
        
        return (result, moves)
        
    def __str__(self):
        """Covert the board state to a string"""
        out = ''
        blackSquare = False
        for file in '87654321':
            out += '       +---+---+---+---+---+---+---+---+\n'
            out += '    ' + file + '  |'
            blackSquare = not blackSquare
            
            for rank in 'abcdefgh':
                blackSquare = not blackSquare
                try:
                    piece = self.squares[rank + file]
                except:
                    piece = None
                if piece is None:
                    # Checkerboard
                    if blackSquare:
                        out += ' . '
                    else:
                        out += '   '
                else:
                    s = piece.getType()
                    if piece.getColour() is WHITE:
                        s = '-' + s + '-'
                    elif piece.getColour() is BLACK:
                        s = '<' + s + '>'
                    else:
                        assert(False)
                    out += s
                
                out += '|'
        
            out += '\n'
        
        out += "       +---+---+---+---+---+---+---+---+\n"
        out += "         a   b   c   d   e   f   g   h"
        
        return out

class ChessBoard:
    """An object representing a chess board.
    
    This class contains a chess board and all its previous states.
    """
    # Pieces on the chess board
    __pieces = None
    
    # A list of board states
    __boardStates = None
    
    # Flag to stop methods being called from inside a callback.
    __inCallback = True
    
    def __init__(self):
        """Constructor for a chess board"""
        self.__pieces = []
        self.__boardStates = []
        self.__resetBoard()
        
    def onPieceMoved(self, piece, start, end):
        """Called when a piece is moved on the chess board.
        
        'piece' is the piece being moved.
        'start' is the start location of the piece (tuple (file,rank) or None if the piece is being created.
        'end' is the end location of the piece (tuple (file,rank) or None if the piece is being created.
        """
        pass

    # Public methods
        
    def getPiece(self, location, moveNumber = -1):
        """Get the piece at a given location.
        
        'location' is the board location to check in LAN format (string).
        'moveNumber' is the move to get the pieces from (integer).
        
        Return the piece (ChessPiece) at this location or None if there is no piece there.
        Raises an IndexError exception if moveNumber is invalid.
        """
        return self.__boardStates[moveNumber].getPiece(location)
    
    def getAlivePieces(self, moveNumber = -1):
        """Get the alive pieces on the board.
        
        'moveNumber' is the move to get the pieces from (integer).
        
        Returns a dictionary of the alive pieces (ChessPiece) keyed by location.
        Raises an IndexError exception if moveNumber is invalid.
        """
        state = self.__boardStates[moveNumber]
        return state.squares.copy()
    
    def getDeadPieces(self, moveNumber = -1):
        """Get the dead pieces from the game.
        
        'moveNumber' is the move to get the pieces from (integer).
        
        Returns a list of the pieces (ChessPiece) in the order they were killed.
        Raises an IndexError exception if moveNumber is invalid.
        """
        state = self.__boardStates[moveNumber]
        return state.casualties[:]
    
    def testMove(self, colour, start, end, promotionType = QUEEN, allowSuicide = False):
        """Test if a move is allowed.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in LAN format (string).
        'end' is a the location to move to in LAN format (string).
        'allowSuicide' if True means a move is considered valid even
                       if it would put the moving player in check. This is
                       provided for SAN move calculation.
        
        Return the move result (MOVE_RESULT_*)
        """
        assert(self.__inCallback is False)
        
        state = ChessBoardState(self.__boardStates[-1])
        (result, moves) = state.movePiece(colour, start, end, promotionType = promotionType, allowSuicide = allowSuicide, applyMove = False)
        return result
        
    def movePiece(self, colour, start, end, promotionType = QUEEN):
        """Move a piece.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in LAN format (string).
        'end' is a the location to move to in LAN format (string).
        
        Return the result of the move (MOVE_RESULT_*).
        """
        assert(self.__inCallback is False)
        
        state = ChessBoardState(self.__boardStates[-1])
        (result, moves) = state.movePiece(colour, start, end, promotionType = promotionType)
        if result is MOVE_RESULT_ILLEGAL:
            return result
        
        # Notify the child class of the moves
        for (piece, start, end) in moves:
            self.__onPieceMoved(piece, start, end)

        # Push the board state
        self.__boardStates.append(state)
        return result

    def __str__(self):
        """Returns a representation of the current board state"""
        return str(self.__boardStates[-1])
    
    # Private methods
    
    def __onPieceMoved(self, piece, start, end):
        """
        """
        self.__inCallback = True
        self.onPieceMoved(piece, start, end)
        self.__inCallback = False
    
    def __addPiece(self, state, colour, pieceType, location):
        """Add a piece into the board.
        
        'state' is the board state to add the piece into.
        'colour' is the colour of the piece.
        'pieceType' is the type of piece to add.
        'location' is the start location of the piece in LAN format (string).
        """
        # Create the piece
        piece = ChessPiece(colour, pieceType)
        self.__pieces.append(piece)
        
        # Put the piece in it's initial location
        assert(state.squares.has_key(location) is False)
        assert(type(location) == str)
        state.squares[location] = piece

        # Notify a child class the piece creation
        self.__onPieceMoved(piece, None, location)

    def __resetBoard(self):
        """Set up the chess board.
        
        Any exisiting states are deleted.
        The user will be notified of the piece deletions.
        """
        # Delete any existing pieces
        for piece in self.__pieces:
            self.__onPieceMoved(piece, piece.getLocation(), None) # FIXME: getLocation() not defined
        self.__pieces = []

        # Make the board
        initialState = ChessBoardState()
        self.__boardStates = [initialState]
        
        # Populate the board
        secondRank = [('a', ROOK), ('b', KNIGHT), ('c', BISHOP), ('d', QUEEN),
                      ('e', KING), ('f', BISHOP), ('g', KNIGHT), ('h', ROOK)]
        for (rank, piece) in secondRank:
            # Add a second rank and pawn for each piece
            self.__addPiece(initialState, WHITE, piece, rank + '1')
            self.__addPiece(initialState, WHITE, PAWN,  rank + '2')
            self.__addPiece(initialState, BLACK, piece, rank + '8')
            self.__addPiece(initialState, BLACK, PAWN,  rank + '7')
    
if __name__ == '__main__':
    p = ChessPiece(WHITE, QUEEN)
    print p
    print repr(p)
    
    def test_moves(name, colour, start, whitePieces, blackPieces, validResults):
        print name + ':'
        board = {}
        for coord, piece in whitePieces.iteritems():
            board[coord] = ChessPiece(WHITE, piece)
        for coord, piece in blackPieces.iteritems():
            board[coord] = ChessPiece(BLACK, piece)
        s = ChessBoardState(board)
        resultMatrix = {}
        for rank in 'abcdefgh':
            for file in '12345678':
                end = rank + file
                try:
                    expected = validResults[end]
                except:
                    expected = MOVE_RESULT_ILLEGAL
                x = ChessBoardState(s)
                (result, moves) = x.movePiece(colour, start, end)
                resultMatrix[end] = result
                if result != expected:
                    print 'Unexpected result: ' + str(start) + '-' + str(end) + ' is a ' + str(result) + ', should be ' + str(expected)
        
        out = ''
        for file in '87654321':
            out += '       +---+---+---+---+---+---+---+---+\n'
            out += '    ' + file + '  |'
            
            for rank in 'abcdefgh':
                coord = rank + file
                try:
                    result = resultMatrix[coord]
                except:
                    result = None

                if result is MOVE_RESULT_ILLEGAL:
                    p = 'X'
                elif result is MOVE_RESULT_OPPONENT_CHECK:
                    p = '+'
                elif result is MOVE_RESULT_OPPONENT_CHECKMATE:
                    p = '#'
                else:
                    p = ' '
                    
                piece = s.getPiece(rank + file)
                if piece is not None:
                    p = piece.getType()

                piece = s.getPiece(rank + file)

                if piece is None:
                    box = ' ' + p + ' ' 
                else:
                    if piece.getColour() is BLACK:
                        box = '=' + p + '='
                    elif piece.getColour() is WHITE:
                        box = '-' + p + '-'
                
                out += box + '|'
        
            out += '\n'
        
        out += "       +---+---+---+---+---+---+---+---+\n"
        out += "         a   b   c   d   e   f   g   h\n"
        print out
                    
    c = ChessBoard()
    
    result = """       +---+---+---+---+---+---+---+---+
    8  |<R>|<N>|<B>|<Q>|<K>|<B>|<N>|<R>|
       +---+---+---+---+---+---+---+---+
    7  |<P>|<P>|<P>|<P>|<P>|<P>|<P>|<P>|
       +---+---+---+---+---+---+---+---+
    6  |   | . |   | . |   | . |   | . |
       +---+---+---+---+---+---+---+---+
    5  | . |   | . |   | . |   | . |   |
       +---+---+---+---+---+---+---+---+
    4  |   | . |   | . |   | . |   | . |
       +---+---+---+---+---+---+---+---+
    3  | . |   | . |   | . |   | . |   |
       +---+---+---+---+---+---+---+---+
    2  |-P-|-P-|-P-|-P-|-P-|-P-|-P-|-P-|
       +---+---+---+---+---+---+---+---+
    1  |-R-|-N-|-B-|-Q-|-K-|-B-|-N-|-R-|
       +---+---+---+---+---+---+---+---+
         a   b   c   d   e   f   g   h"""

    if str(c) != result:
        print 'Got:'
        print str(c)
        
        print 
        print 'Expected:'
        print result
    print str(c)

    # Test pawn moves
    test_moves('Pawn', WHITE, 'e4', {'e4': PAWN}, {}, {'e5': MOVE_RESULT_ALLOWED})
    test_moves('Pawn on base rank', WHITE, 'e2', {'e2': PAWN}, {}, {'e3': MOVE_RESULT_ALLOWED, 'e4': MOVE_RESULT_ALLOWED})
    
    # Test rook moves
    test_moves('Rook', WHITE, 'e4', {'e4': ROOK}, {},
               {'a4': MOVE_RESULT_ALLOWED, 'b4': MOVE_RESULT_ALLOWED, 'c4': MOVE_RESULT_ALLOWED,
                'd4': MOVE_RESULT_ALLOWED, 'f4': MOVE_RESULT_ALLOWED, 'g4': MOVE_RESULT_ALLOWED,
                'h4': MOVE_RESULT_ALLOWED, 'e1': MOVE_RESULT_ALLOWED, 'e2': MOVE_RESULT_ALLOWED,
                'e3': MOVE_RESULT_ALLOWED, 'e5': MOVE_RESULT_ALLOWED, 'e6': MOVE_RESULT_ALLOWED,
                'e7': MOVE_RESULT_ALLOWED, 'e8': MOVE_RESULT_ALLOWED})

    # Test knight moves
    test_moves('Knight', WHITE, 'e4', {'e4': KNIGHT}, {},
               {'d6': MOVE_RESULT_ALLOWED, 'f6': MOVE_RESULT_ALLOWED, 'g5': MOVE_RESULT_ALLOWED,
                'g3': MOVE_RESULT_ALLOWED, 'f2': MOVE_RESULT_ALLOWED, 'd2': MOVE_RESULT_ALLOWED,
                'c3': MOVE_RESULT_ALLOWED, 'c5': MOVE_RESULT_ALLOWED})
               
    # Test bishop moves
    test_moves('Bishop', WHITE, 'e4', {'e4': BISHOP}, {},
               {'a8': MOVE_RESULT_ALLOWED, 'b7': MOVE_RESULT_ALLOWED, 'c6': MOVE_RESULT_ALLOWED,
                'd5': MOVE_RESULT_ALLOWED, 'f3': MOVE_RESULT_ALLOWED, 'g2': MOVE_RESULT_ALLOWED,
                'h1': MOVE_RESULT_ALLOWED, 'b1': MOVE_RESULT_ALLOWED, 'c2': MOVE_RESULT_ALLOWED,
                'd3': MOVE_RESULT_ALLOWED, 'f5': MOVE_RESULT_ALLOWED, 'g6': MOVE_RESULT_ALLOWED,
                'h7': MOVE_RESULT_ALLOWED})
    
    # Test queen moves
    test_moves('Queen', WHITE, 'e4', {'e4': QUEEN}, {},
               {'a8': MOVE_RESULT_ALLOWED, 'b7': MOVE_RESULT_ALLOWED, 'c6': MOVE_RESULT_ALLOWED,
                'd5': MOVE_RESULT_ALLOWED, 'f3': MOVE_RESULT_ALLOWED, 'g2': MOVE_RESULT_ALLOWED,
                'h1': MOVE_RESULT_ALLOWED, 'b1': MOVE_RESULT_ALLOWED, 'c2': MOVE_RESULT_ALLOWED,
                'd3': MOVE_RESULT_ALLOWED, 'f5': MOVE_RESULT_ALLOWED, 'g6': MOVE_RESULT_ALLOWED,
                'h7': MOVE_RESULT_ALLOWED, 'a4': MOVE_RESULT_ALLOWED, 'b4': MOVE_RESULT_ALLOWED,
                'c4': MOVE_RESULT_ALLOWED, 'd4': MOVE_RESULT_ALLOWED, 'f4': MOVE_RESULT_ALLOWED,
                'g4': MOVE_RESULT_ALLOWED, 'h4': MOVE_RESULT_ALLOWED, 'e1': MOVE_RESULT_ALLOWED,
                'e2': MOVE_RESULT_ALLOWED, 'e3': MOVE_RESULT_ALLOWED, 'e5': MOVE_RESULT_ALLOWED,
                'e6': MOVE_RESULT_ALLOWED, 'e7': MOVE_RESULT_ALLOWED, 'e8': MOVE_RESULT_ALLOWED})
    
    # Test king moves
    test_moves('King', WHITE, 'e4', {'e4': KING}, {},
               {'d5': MOVE_RESULT_ALLOWED, 'e5': MOVE_RESULT_ALLOWED, 'f5': MOVE_RESULT_ALLOWED,
                'd4': MOVE_RESULT_ALLOWED, 'f4': MOVE_RESULT_ALLOWED, 'd3': MOVE_RESULT_ALLOWED,
                'e3': MOVE_RESULT_ALLOWED, 'f3': MOVE_RESULT_ALLOWED})
                
    # Test pieces blocking moves
    test_moves('Blocking', WHITE, 'd4',
               {'d4': QUEEN, 'e4': PAWN, 'd6': KNIGHT, 'd2': ROOK, 'f6': BISHOP, 'e3': BISHOP,
                'b4':PAWN, 'b2': PAWN, 'a7': PAWN},
               {'d8': KNIGHT, 'c4': PAWN},
               {'b6': MOVE_RESULT_ALLOWED, 'c5': MOVE_RESULT_ALLOWED, 'd5': MOVE_RESULT_ALLOWED,
                'e5': MOVE_RESULT_ALLOWED, 'c4': MOVE_RESULT_ALLOWED, 'c3': MOVE_RESULT_ALLOWED,
                'd3': MOVE_RESULT_ALLOWED})
    
    # Test moving in/out of check
    test_moves('Moving into check', WHITE, 'e4', {'e4': KING}, {'e6': ROOK},
               {'d5': MOVE_RESULT_ALLOWED, 'f5': MOVE_RESULT_ALLOWED,
                'd4': MOVE_RESULT_ALLOWED, 'f4': MOVE_RESULT_ALLOWED,
                'd3': MOVE_RESULT_ALLOWED, 'f3': MOVE_RESULT_ALLOWED})
    test_moves('Held in check', WHITE, 'e4', {'e4': KING}, {'f6': ROOK},
               {'d5': MOVE_RESULT_ALLOWED, 'e5': MOVE_RESULT_ALLOWED, 'd4': MOVE_RESULT_ALLOWED,
                'd3': MOVE_RESULT_ALLOWED, 'e3': MOVE_RESULT_ALLOWED})
    
    # Test putting opponent in check
    test_moves('Putting opponent in check', WHITE, 'd3', {'d3': BISHOP}, {'d7': KING, 'd6': ROOK},
               {'a6': MOVE_RESULT_ALLOWED, 'b5': MOVE_RESULT_OPPONENT_CHECK, 'c4': MOVE_RESULT_ALLOWED,
                'e2': MOVE_RESULT_ALLOWED, 'f1': MOVE_RESULT_ALLOWED, 'b1': MOVE_RESULT_ALLOWED,
                'c2': MOVE_RESULT_ALLOWED, 'e4': MOVE_RESULT_ALLOWED, 'f5': MOVE_RESULT_OPPONENT_CHECK,
                'g6': MOVE_RESULT_ALLOWED, 'h7': MOVE_RESULT_ALLOWED})
    
    # Test putting opponent into checkmate
    test_moves('Putting opponent into checkmate', WHITE, 'c1', {'c1': BISHOP, 'g1': ROOK, 'a7': ROOK}, {'h8': KING},
               {'b2': MOVE_RESULT_OPPONENT_CHECKMATE, 'a3': MOVE_RESULT_ALLOWED,
                'd2': MOVE_RESULT_ALLOWED, 'e3': MOVE_RESULT_ALLOWED, 'f4': MOVE_RESULT_ALLOWED,
                'g5': MOVE_RESULT_ALLOWED, 'h6': MOVE_RESULT_ALLOWED})
    #FIXME
                
    # Test putting own player in check by putting oppononent in check (i.e. can't move)
    test_moves('Cannot put opponent in check if we would go into check',
               WHITE, 'd3', {'d2': KING, 'd3': BISHOP}, {'d7': KING, 'd6': ROOK}, {})

    # Test castling
    test_moves('Castle1', WHITE, 'e1', {'e1': KING, 'a1': ROOK}, {},
               {'d2': MOVE_RESULT_ALLOWED, 'e2': MOVE_RESULT_ALLOWED, 'f2': MOVE_RESULT_ALLOWED,
                'd1': MOVE_RESULT_ALLOWED, 'f1': MOVE_RESULT_ALLOWED, 'c1': MOVE_RESULT_ALLOWED})
    test_moves('Castle2', BLACK, 'e8', {}, {'e8': KING, 'h8': ROOK},
               {'d7': MOVE_RESULT_ALLOWED, 'e7': MOVE_RESULT_ALLOWED, 'f7': MOVE_RESULT_ALLOWED,
               'd8': MOVE_RESULT_ALLOWED, 'f8': MOVE_RESULT_ALLOWED, 'g8': MOVE_RESULT_ALLOWED})
    
    # Test castling while in check
    test_moves('Castle in check1', BLACK, 'e8', {'f1': ROOK}, {'e8': KING, 'h8': ROOK},
               {'d7': MOVE_RESULT_ALLOWED, 'e7': MOVE_RESULT_ALLOWED, 'd8': MOVE_RESULT_ALLOWED})
    test_moves('Castle in check2', BLACK, 'e8', {'e1': ROOK}, {'e8': KING, 'h8': ROOK},
               {'d7': MOVE_RESULT_ALLOWED, 'd8': MOVE_RESULT_ALLOWED,
                'f7': MOVE_RESULT_ALLOWED, 'f8': MOVE_RESULT_ALLOWED})
    test_moves('Castle in check3', BLACK, 'e8', {'h1': ROOK}, {'e8': KING, 'h8': ROOK},
               {'d7': MOVE_RESULT_ALLOWED, 'e7': MOVE_RESULT_ALLOWED, 'f7': MOVE_RESULT_ALLOWED,
               'd8': MOVE_RESULT_ALLOWED, 'f8': MOVE_RESULT_ALLOWED, 'g8': MOVE_RESULT_ALLOWED})
               
    # Test en-passant
    #FIXME
    
