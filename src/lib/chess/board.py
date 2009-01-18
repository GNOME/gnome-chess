# -*- coding: utf-8 -*-
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
>>> move = b.movePiece(board.WHITE, 'd1', 'd3')
If the move is not None then the internal state is updated and the
next player can move.
If the result is None then the request is ignored.

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

__all__ = ['ChessPiece', 'ChessBoard', 'Move']

import bitboard

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
    
    def __repr__(self):
        return '<%s>' % str(self)
    
class ChessPlayerState:
    """
    """
    # Flags to show if still able to castle
    canShortCastle = True
    canLongCastle  = True
    
    # Flag to show if this player is in check
    inCheck        = False
    
    def __init__(self, state = None):
        """
        """
        if state is None:
            return

        # Copy the exisiting state
        self.canShortCastle = state.canShortCastle
        self.canLongCastle = state.canLongCastle
        
    def __eq__(self, state):
        """Compare two states are equal"""
        if self.canShortCastle != state.canShortCastle:
            return False
        if self.canLongCastle != state.canLongCastle:
            return False
        return True
    
    def __ne__(self, state):
        return not self == state

class Move:
    """
    """
    # List of pieces that have moved
    # (start, end, piece)
    # state = None for new pieces
    # end = None for taken pieces
    moves  = []
    
    # The piece that was taken in this move or None if no victim
    victim = None

    # Flag to show if the opponent is in check
    opponentInCheck = False
    
    # Flag to show if the opponent can move
    opponentCanMove = False
    
    # Flag to show if this move has caused a three-fold repetition
    threeFoldRepetition = False
    
    # Flag to show if this is the fiftith move in a row
    # without a pawn being moved or a piece taken
    fiftyMoveRule = False

class ChessBoardState:
    """
    """    
    # The move number 
    moveNumber      = 0
    
    # A dictionary of piece by location
    squares         = None
    
    # The dead pieces in the order they were killed
    casualties      = None
    
    # The move that got us to this state
    lastMove        = None
    
    # Pieces moved that got us to this state
    moves           = None

    # If the last move was a pawn march the location where it can be taken by en-passant
    enPassantSquare = None

    # The state of the players
    whiteState      = None
    blackState      = None
    
    # Counter of the number of moves taken made where no pawn has moved
    # and no piece has been taken
    fiftyMoveCount  = 0
    
    # Flag to show if the previous move has caused a three fold repition
    threeFoldRepetition = False

    # Bitboards
    whiteBitBoard = 0
    blackBitBoard = 0
    allBitBoard   = 0

    def __init__(self, lastState = None):
        """Constuctor for storing the state of a chess board.
        
        'lastState' is the previous board state
                    or a dictionary containing the initial state of the board
                    or None to start an empty board.

        Example:
            
        pawn = ChessPiece(WHITE, PAWN)
        ChessBoardState({'a2': pawn, ...})
        
        Note if a dictionary is provided the casualties will only record the pieces
        killed from this point onwards.
        """
        # Start empty
        if lastState is None:
            self.whiteBitBoard = 0
            self.blackBitBoard = 0
            self.allBitBoard = 0
            self.moveNumber = 0
            self.squares = {}
            self.casualties = []
            self.moves = []
            self.whiteState = ChessPlayerState()
            self.blackState = ChessPlayerState()
            
        # Use provided initial pieces
        elif type(lastState) is dict:
            self.moveNumber = 0
            self.squares = {}
            self.casualties = []
            self.moves = []            
            self.whiteBitBoard = 0
            self.blackBitBoard = 0
            self.allBitBoard = 0
            for coord, piece in lastState.iteritems():
                self.squares[coord] = piece
                field = bitboard.LOCATIONS[bitboard.getIndex(coord)]
                if piece.getColour() is WHITE:
                    self.whiteBitBoard |= field
                else:
                    self.blackBitBoard |= field
                self.allBitBoard |= field

            self.whiteState = ChessPlayerState()
            self.blackState = ChessPlayerState()

        # Copy exisiting state
        elif isinstance(lastState, ChessBoardState):
            self.whiteBitBoard = lastState.whiteBitBoard
            self.blackBitBoard = lastState.blackBitBoard
            self.allBitBoard = lastState.allBitBoard
            self.moveNumber = lastState.moveNumber + 1
            self.squares = lastState.squares.copy()
            self.casualties = lastState.casualties[:]
            self.lastMove = lastState.lastMove
            self.moves = lastState.moves[:]
            self.enPassantSquare = lastState.enPassantSquare
            self.whiteState = ChessPlayerState(lastState.whiteState)
            self.blackState = ChessPlayerState(lastState.blackState)
            self.fiftyMoveCount = lastState.fiftyMoveCount

        else:
            raise TypeError('ChessBoardState(oldState) or ChessBoardState({(0,0):pawn, ...})')
        
    def addPiece(self, location, colour, pieceType):
        # Create the piece
        piece = ChessPiece(colour, pieceType)

        # Put the piece in it's initial location
        assert(self.squares.has_key(location) is False)
        assert(type(location) == str)
        self.squares[location] = piece
        
        # Update the bitboards
        field = bitboard.LOCATIONS[bitboard.getIndex(location)]
        if colour is WHITE:
            self.whiteBitBoard |= field
        else:
            self.blackBitBoard |= field
        self.allBitBoard |= field

        return piece

    def getPiece(self, location):
        """Get the piece at a given location.
        
        'location' is the location in algebraic format (string).
        
        Return the piece at this location or None if there is no piece there.
        """
        assert(type(location) is str and len(location) == 2)
        try:
            return self.squares[location]
        except KeyError:
            return None
    
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
            if self.squareUnderAttack(colour, kingCoord):
                return True

        return False
    
    def squareUnderAttack(self, colour, location, requirePiece = True):
        """Check if a square is under attack according to FIDE chess rules (Article 3.1)
        
        'colour' is the colour considered to own this square.
        'location' is the location to check.
        'requirePiece' if True only considers this square under attack if there is a piece in it.
        
        Return True if there is an enemy piece that can attach this square.
        """
        if requirePiece and self.getPiece(location) is None:
            return False
        
        # See if any enemy pieces can take this king
        for enemyCoord, enemyPiece in self.squares.iteritems():
            # Ignore friendly pieces
            if enemyPiece.getColour() == colour:
                continue

            # See if this piece can take
            board = ChessBoardState(self)
            if board.movePiece(enemyPiece.getColour(), enemyCoord, location, testCheck = False, applyMove = False):
                return True
            
        return False

    def canMove(self, colour):
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
                    board = ChessBoardState(self)
                    if board.movePiece(colour, coord, rank + file, applyMove = False):
                        return True

        return False
    
    def _getSquareColour(self, coord):
        return {'a8': WHITE, 'b8': BLACK, 'c8': WHITE, 'd8': BLACK, 'e8': WHITE, 'f8': BLACK, 'g8': WHITE, 'h8': BLACK,
                'a7': BLACK, 'b7': WHITE, 'c7': BLACK, 'd7': WHITE, 'e7': BLACK, 'f7': WHITE, 'g7': BLACK, 'h7': WHITE,
                'a6': WHITE, 'b6': BLACK, 'c6': WHITE, 'd6': BLACK, 'e6': WHITE, 'f6': BLACK, 'g6': WHITE, 'h6': BLACK,
                'a5': BLACK, 'b5': WHITE, 'c5': BLACK, 'd5': WHITE, 'e5': BLACK, 'f5': WHITE, 'g5': BLACK, 'h5': WHITE,
                'a4': WHITE, 'b4': BLACK, 'c4': WHITE, 'd4': BLACK, 'e4': WHITE, 'f4': BLACK, 'g4': WHITE, 'h4': BLACK,
                'a3': BLACK, 'b3': WHITE, 'c3': BLACK, 'd3': WHITE, 'e3': BLACK, 'f3': WHITE, 'g3': BLACK, 'h3': WHITE,
                'a2': WHITE, 'b2': BLACK, 'c2': WHITE, 'd2': BLACK, 'e2': WHITE, 'f2': BLACK, 'g2': WHITE, 'h2': BLACK,
                'a1': BLACK, 'b1': WHITE, 'c1': BLACK, 'd1': WHITE, 'e1': BLACK, 'f1': WHITE, 'g1': BLACK, 'h1': WHITE}[coord]

    def sufficientMaterial(self):
        """Test if there are sufficient pieces to be able to perform checkmate.
        
        Return True if sufficient pieces to make checkmate or False otherwise.
        """
        knightCount = 0
        bishopCount = 0
        for coord, piece in self.squares.iteritems():
            pieceType = piece.getType()
            
            # Any pawns, rooks or queens can perform check
            if pieceType == PAWN or pieceType == ROOK or pieceType == QUEEN:
                return True

            # Multiple knights can check
            if pieceType == KNIGHT:
                knightCount += 1
                if knightCount > 1:
                    return True

            # Bishops on different colours can check
            if pieceType == BISHOP:
                bishopCount += 1 
                colour = self._getSquareColour(coord)
                if bishopCount > 1:
                    if colour != bishopSquareColour:
                        return True
                bishopSquareColour = colour

        return False
        
    allowedMoves = {WHITE: {PAWN:   bitboard.WHITE_PAWN_MOVES,
                            ROOK:   bitboard.ROOK_MOVES,
                            BISHOP: bitboard.BISHOP_MOVES,
                            KNIGHT: bitboard.KNIGHT_MOVES,
                            QUEEN:  bitboard.QUEEN_MOVES,
                            KING:   bitboard.WHITE_KING_MOVES},
                    BLACK: {PAWN:   bitboard.BLACK_PAWN_MOVES,
                            ROOK:   bitboard.ROOK_MOVES,
                            BISHOP: bitboard.BISHOP_MOVES,
                            KNIGHT: bitboard.KNIGHT_MOVES,
                            QUEEN:  bitboard.QUEEN_MOVES,
                            KING:   bitboard.BLACK_KING_MOVES}}
    
    def movePiece(self, colour, start, end, promotionType = QUEEN, testCheck = True, allowSuicide = False, applyMove = True):
        """Move a piece.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in algebraic format (string).
        'end' is a the location to move to in algebraic format (string).
        'promotionType' is the type of piece to promote to if required.
        'testCheck' is a flag to control if the opponent will be in check after this move.
        'allowSuicide' if True means a move is considered valid even
                       if it would put the moving player in check.
        'applyMove' is a flag to control if the move is applied to the board (True) or just tested (False).
        
        Returns the pieces moved in the form (result, moves).
        The moves are a list containing tuples of the form (piece, start, end). If a piece was removed
        'end' is None. If the result is successful the pieces on the board are modified.
        If the move is illegal None is returned.
        """
        assert(promotionType is not KING)
        assert(type(start) is str and len(start) == 2)
        assert(type(end) is str and len(end) == 2)

        # Get the piece to move
        try:
            piece = self.squares[start]
        except KeyError:
            return None
        if piece.getColour() is not colour:
            return None

        # BitBoard indexes
        startIndex = bitboard.getIndex(start)
        endIndex = bitboard.getIndex(end)
        
        # Check if this move is possible
        field = self.allowedMoves[colour][piece.getType()]
        if field[startIndex] & bitboard.LOCATIONS[endIndex] == 0:
            return None
            
        # Check if there are any pieces between the two moves
        # Note this only checks horizontal, vertical and diagonal moves so
        # has no effect on the knights
        if self.allBitBoard & bitboard.INBETWEEN_SQUARES[startIndex][endIndex]:
            return None

        # Get the players
        if colour is WHITE:
            enemyColour = BLACK
            playerState = self.whiteState
        elif colour is BLACK:
            enemyColour = WHITE
            playerState = self.blackState
        else:
            assert(False)
        
        # Copy the player state before it is changed
        originalPlayerState = ChessPlayerState(playerState)
        
        whiteBitBoard = self.whiteBitBoard
        blackBitBoard = self.blackBitBoard
        allBitBoard = self.allBitBoard

        # Check if moving onto another piece (must be enemy)
        try:
            target = self.squares[end]
            if target.getColour() == colour:
                return None
        except KeyError:
            target = None
        victim = target
        
        # Get the rank relative to this colour's start rank
        if colour == BLACK:
            baseFile = '8'
        else:
            baseFile = '1'
            
        # The new en-passant square
        enPassantSquare = None
        
        # A list of pieces that have been moved
        moves = []
        
        # Check move is valid:

        # King can move one square or castle
        if piece.getType() is KING:
            # Castling:
            shortCastle = ('e' + baseFile, 'g' + baseFile)
            longCastle  = ('e' + baseFile, 'c' + baseFile)
            if (start, end) == shortCastle or (start, end) == longCastle:
                # Cannot castle out of check
                if self.inCheck(colour):
                    return None

                # Cannot castle if required pieces have moved
                if end[0] == 'c':
                    if not playerState.canLongCastle:
                        return None
                    rookLocation = 'a' + baseFile
                    rookEndLocation = 'd' + baseFile
                else:
                    if not playerState.canShortCastle:
                        return None
                    rookLocation = 'h' + baseFile
                    rookEndLocation = 'f' + baseFile

                # Check rook is still there
                try:
                    rook = self.squares[rookLocation]
                except KeyError:
                    return None
                if rook is None or rook.getType() is not ROOK or rook.getColour() != piece.getColour():
                    return None

                # Check no pieces between the rook and king
                a = bitboard.getIndex(rookLocation)
                b = bitboard.getIndex(rookEndLocation)
                if self.allBitBoard & bitboard.INBETWEEN_SQUARES[a][b]:
                    return None
                
                # The square the king moves over cannot be attackable
                if self.squareUnderAttack(colour, rookEndLocation, requirePiece = False):
                    return None

                # Rook moves with the king
                moves.append((rook, rookLocation, rookEndLocation, False))

            # Can no longer castle once the king is moved
            playerState.canShortCastle = False
            playerState.canLongCastle = False
            
            moves.append((piece, start, end, False))
                
        # Rooks move orthogonal
        elif piece.getType() is ROOK:
            # Can no longer castle once have move the required rook
            if start == 'a' + baseFile:
                playerState.canLongCastle = False
            elif start == 'h' + baseFile:
                playerState.canShortCastle = False
            moves.append((piece, start, end, False))

        # On base rank pawns move on or two squares forwards.
        # Pawns take other pieces diagonally (1 square).
        # Pawns can take other pawns moving two ranks using 'en passant'.
        # Pawns are promoted on reaching the other side of the board.
        elif piece.getType() is PAWN:
            # Calculate the files that pawns start on and move over on marches
            if baseFile == '1':
                pawnFile  = '2'
                marchFile = '3'
                farFile   = '8'
            else:
                pawnFile  = '7'
                marchFile = '6'
                farFile   = '1'
                
            # When marching the square that is moved over can be taken by en-passant
            if (start[1] == '2' and end[1] == '4') or (start[1] == '7' and end[1] == '5'):
                enPassantSquare = start[0] + marchFile
    
            # Can only take when moving diagonally
            if start[0] != end[0]:
                # FIXME: Set victim
                # We either need a victim or be attacking the en-passant square
                if victim is None:
                    if end != self.enPassantSquare:
                        return None
                    
                    # Kill the pawn that moved
                    moves.append((self.lastMove[0], self.lastMove[2], self.lastMove[2], True))
            elif victim is not None:
                return None
            
            # Promote pawns when they hit the far rank
            if end[1] == farFile:
                # Delete the current piece and create a new piece
                moves.append((piece, start, end, True))
                moves.append((ChessPiece(colour, promotionType), None, end, False))
            else:
                moves.append((piece, start, end, False))

        # Other pieces are well behaved
        else:
            moves.append((piece, start, end, False))

        # Store this move
        oldLastMove = self.lastMove
        self.lastMove = (piece, start, end)
        oldEnPassantSquare = self.enPassantSquare
        self.enPassantSquare = enPassantSquare

        # Delete a victim
        if victim is not None:
            moves.append((victim, end, end, True))
            
        # Move the pieces:

        # Remove the moving pieces from the board
        for (p, s, e, d) in moves:
            if s is None:
                continue
            self.squares.pop(s)
            
            field = bitboard.LOCATIONS[bitboard.getIndex(s)]
            self.whiteBitBoard &= ~field
            self.blackBitBoard &= ~field
            self.allBitBoard &= ~field
                
        # Put pieces in their new locations
        for (p, s, e, d) in moves:
            if d:
                continue
            self.squares[e] = p

            field = bitboard.LOCATIONS[bitboard.getIndex(e)]
            if p.getColour() is WHITE:
                self.whiteBitBoard |= field
            else:
                self.blackBitBoard |= field
            self.allBitBoard |= field

        # Test for check and checkmate
        result = moves
        if testCheck:
            # Cannot move into check, if would be then undo move
            if self.inCheck(colour):
                applyMove = False
                result = None

        # Undo the moves if only a test
        if applyMove is False:
            # Empty any squares moved into
            for (p, s, e, d) in moves:
                if not d:
                    self.squares.pop(e)
                        
            # Put pieces back into their original locatons
            for (p, s, e, d) in moves:
                if s is not None:
                    self.squares[s] = p

            # Undo player state
            if colour == WHITE:
                self.whiteState = originalPlayerState
            else:
                self.blackState = originalPlayerState
            
            # Undo stored move and en-passant location
            self.lastMove = oldLastMove
            self.enPassantSquare = oldEnPassantSquare

            # Revert bitboards
            self.whiteBitBoard = whiteBitBoard
            self.blackBitBoard = blackBitBoard
            self.allBitBoard = allBitBoard
            
        else:
            self.moves = result
            
            # Remember the casualties
            if victim is not None:
                self.casualties.append(victim)

            # If a piece taken or a pawn moved 50 move count is reset
            if victim is not None or piece.getType() is PAWN:
                self.fiftyMoveCount = 0
            else:
                self.fiftyMoveCount += 1
                
        return result

    def __eq__(self, board):
        """Compare if two boards are the same"""
        if len(self.squares) != len(board.squares):
            return False

        if self.enPassantSquare != board.enPassantSquare:
            return False
        if self.whiteState != board.whiteState or self.blackState != board.blackState:
            return False
        
        for (coord, piece) in self.squares.iteritems():
            try:
                p = board.squares[coord]
            except KeyError:
                return False
            if piece.getType() is not p.getType() or piece.getColour() is not p.getColour():
                return False
            
        return True
    
    def __ne__(self, board):
        return not self == board
        
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
    def __init__(self, initialState = None):
        """Constructor for a chess board"""
        self.__inCallback = False
        if initialState is None:
            self.__resetBoard()
        else:
            self.__boardStates = [initialState]
        
    def onPieceMoved(self, piece, start, end, delete):
        """Called when a piece is moved on the chess board.
        
        'piece' is the piece being moved.
        'start' is the start location of the piece (tuple (file,rank) or None if the piece is being created.
        'end' is the end location of the piece (tuple (file,rank)
        'delete' is a flag to show if the piece should be deleted when it arrives there (boolean).
        """
        pass

    # Public methods

    def getPiece(self, location, moveNumber = -1):
        """Get the piece at a given location.
        
        'location' is the board location to check in algebraic format (string).
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

    def testMove(self, colour, start, end, promotionType = QUEEN, allowSuicide = False, moveNumber = -1):
        """Test if a move is allowed.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in algebraic format (string).
        'end' is a the location to move to in algebraic format (string).
        'allowSuicide' if True means a move is considered valid even
                       if it would put the moving player in check. This is
                       provided for SAN move calculation.
        
        Returns the same as movePiece() except the move is not recorded.
        """
        return self.movePiece(colour, start, end, promotionType = promotionType, allowSuicide = allowSuicide, test = True, moveNumber = moveNumber)
    
    def squareUnderAttack(self, colour, location, moveNumber = -1):
        state = self.__boardStates[moveNumber]
        return state.squareUnderAttack(colour, location)
    
    def sufficientMaterial(self, moveNumber = -1):
        """Test if there are sufficient pieces to be able to perform checkmate.
        
        Return True if sufficient pieces to make checkmate or False otherwise.
        """
        state = self.__boardStates[moveNumber]
        return state.sufficientMaterial()

    def movePiece(self, colour, start, end, promotionType = QUEEN, allowSuicide = False, test = False, moveNumber = -1):
        """Move a piece.
        
        'colour' is the colour of the player moving.
        'start' is a the location to move from in algebraic format (string).
        'end' is a the location to move to in algebraic format (string).
        'allowSuicide' if True means a move is considered valid even
                       if it would put the moving player in check. This is
                       provided for SAN move calculation.

        Return information about the move performed (Move) or None if the move is illegal.
        """
        assert(self.__inCallback is False)
        
        state = ChessBoardState(self.__boardStates[moveNumber])
        if not state.movePiece(colour, start, end, promotionType = promotionType, allowSuicide = False):
            return None

        victim = None
        for (piece, start, end, delete) in state.moves:
            # The victim is the enemy piece that has been deleted
            if delete and piece.getColour() != colour:
                victim = piece
            
            # Notify the child class of the moves
            if not test:
                self.__onPieceMoved(piece, start, end, delete)

        # Check if this board state has been repeated three times
        sameCount = 0
        for s in self.__boardStates:
            if state == s:
                sameCount += 1
                if sameCount >= 2:
                    state.threeFoldRepetition = True
                    break
                
        if colour is WHITE:
            opponentColour = BLACK
        else:
            opponentColour = WHITE

        # Push the board state
        if not test:
            self.__boardStates.append(state)
        move = Move()
        move.moves = state.moves
        move.victim = victim
        move.opponentInCheck = state.inCheck(opponentColour)
        move.opponentCanMove = state.canMove(opponentColour)
        move.threeFoldRepetition = state.threeFoldRepetition
        move.fiftyMoveRule = state.fiftyMoveCount >= 50
        return move
    
    def undo(self):
        """Undo the last move"""
        undoState = self.__boardStates[-1]
        self.__boardStates = self.__boardStates[:-1]

        # Undo the moves
        for (piece, start, end, delete) in undoState.moves:
            self.__onPieceMoved(piece, end, start, False)

    def __str__(self):
        """Returns a representation of the current board state"""
        return str(self.__boardStates[-1])
    
    # Private methods
    
    def __onPieceMoved(self, piece, start, end, delete):
        """
        """
        self.__inCallback = True
        self.onPieceMoved(piece, start, end, delete)
        self.__inCallback = False
    
    def __addPiece(self, state, colour, pieceType, location):
        """Add a piece into the board.
        
        'state' is the board state to add the piece into.
        'colour' is the colour of the piece.
        'pieceType' is the type of piece to add.
        'location' is the start location of the piece in algebraic format (string).
        """
        piece = state.addPiece(location, colour, pieceType)
        
        # Notify a child class the piece creation
        self.__onPieceMoved(piece, None, location, False)

    def __resetBoard(self):
        """Set up the chess board.
        
        Any exisiting states are deleted.
        The user will be notified of the piece deletions.
        """
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
                    expected = None
                x = ChessBoardState(s)
                b = ChessBoard(x)
                move = b.movePiece(colour, start, end)
                resultMatrix[end] = move
                
                isAllowed = validResults.__contains__(end)
                if (move is None and isAllowed) or (move is not None and not isAllowed):
                    print 'Unexpected result: ' + str(start) + '-' + str(end) # + ' is a ' + str(result) + ', should be ' + str(expected)
        
        out = ''
        for file in '87654321':
            out += '       +---+---+---+---+---+---+---+---+\n'
            out += '    ' + file + '  |'
            
            for rank in 'abcdefgh':
                coord = rank + file
                try:
                    move = resultMatrix[coord]
                except:
                    p = 'X'
                else:
                    if move is not None and move.opponentInCheck:
                        if move.opponentCanMove:
                            p = '+'
                        else:
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
    test_moves('Pawn', WHITE, 'e4', {'e4': PAWN}, {}, ['e5'])
    test_moves('Pawn on base rank', WHITE, 'e2', {'e2': PAWN}, {}, ['e3','e4'])
    
    # Test rook moves
    test_moves('Rook', WHITE, 'e4', {'e4': ROOK}, {},
               ['a4', 'b4', 'c4',
                'd4', 'f4', 'g4',
                'h4', 'e1', 'e2',
                'e3', 'e5', 'e6',
                'e7', 'e8'])

    # Test knight moves
    test_moves('Knight', WHITE, 'e4', {'e4': KNIGHT}, {},
               ['d6', 'f6', 'g5',
                'g3', 'f2', 'd2',
                'c3', 'c5'])
               
    # Test bishop moves
    test_moves('Bishop', WHITE, 'e4', {'e4': BISHOP}, {},
               ['a8', 'b7', 'c6',
                'd5', 'f3', 'g2',
                'h1', 'b1', 'c2',
                'd3', 'f5', 'g6',
                'h7'])
    
    # Test queen moves
    test_moves('Queen', WHITE, 'e4', {'e4': QUEEN}, {},
               ['a8', 'b7', 'c6',
                'd5', 'f3', 'g2',
                'h1', 'b1', 'c2',
                'd3', 'f5', 'g6',
                'h7', 'a4', 'b4',
                'c4', 'd4', 'f4',
                'g4', 'h4', 'e1',
                'e2', 'e3', 'e5',
                'e6', 'e7', 'e8'])
    
    # Test king moves
    test_moves('King', WHITE, 'e4', {'e4': KING}, {},
               ['d5', 'e5', 'f5',
                'd4', 'f4', 'd3',
                'e3', 'f3'])
                
    # Test pieces blocking moves
    test_moves('Blocking', WHITE, 'd4',
               {'d4': QUEEN, 'e4': PAWN, 'd6': KNIGHT, 'd2': ROOK, 'f6': BISHOP, 'e3': BISHOP,
                'b4':PAWN, 'b2': PAWN, 'a7': PAWN},
               {'d8': KNIGHT, 'c4': PAWN},
               ['b6', 'c5', 'd5',
                'e5', 'c4', 'c3',
                'd3'])
    
    # Test moving in/out of check
    test_moves('Moving into check', WHITE, 'e4', {'e4': KING}, {'e6': ROOK},
               ['d5', 'f5',
                'd4', 'f4',
                'd3', 'f3'])
    test_moves('Held in check', WHITE, 'e4', {'e4': KING}, {'f6': ROOK},
               ['d5', 'e5', 'd4',
                'd3', 'e3'])
    
    # Test putting opponent in check
    test_moves('Putting opponent in check', WHITE, 'd3', {'d3': BISHOP}, {'d7': KING, 'd6': ROOK},
               ['a6', 'b5', 'c4',
                'e2', 'f1', 'b1',
                'c2', 'e4', 'f5',
                'g6', 'h7']) # check=b5,f5
    
    # Test putting opponent into checkmate
    test_moves('Putting opponent into checkmate', WHITE, 'c1', {'c1': BISHOP, 'g1': ROOK, 'a7': ROOK}, {'h8': KING},
               ['b2', 'a3',
                'd2', 'e3', 'f4',
                'g5', 'h6']) # checkmate=b2
    #FIXME
                
    # Test putting own player in check by putting oppononent in check (i.e. can't move)
    test_moves('Cannot put opponent in check if we would go into check',
               WHITE, 'd3', {'d2': KING, 'd3': BISHOP}, {'d7': KING, 'd6': ROOK}, [])

    # Test castling
    test_moves('Castle1', WHITE, 'e1', {'e1': KING, 'a1': ROOK}, {},
               ['d2', 'e2', 'f2',
                'd1', 'f1', 'c1'])
    test_moves('Castle2', BLACK, 'e8', {}, {'e8': KING, 'h8': ROOK},
               ['d7', 'e7', 'f7',
                'd8', 'f8', 'g8'])
    
    # Test castling while in check
    test_moves('Castle in check1', BLACK, 'e8', {'f1': ROOK}, {'e8': KING, 'h8': ROOK},
               ['d7', 'e7', 'd8'])
    test_moves('Castle in check2', BLACK, 'e8', {'e1': ROOK}, {'e8': KING, 'h8': ROOK},
               ['d7', 'd8',
                'f7', 'f8'])
    test_moves('Castle in check3', BLACK, 'e8', {'h1': ROOK}, {'e8': KING, 'h8': ROOK},
               ['d7', 'e7', 'f7',
                'd8', 'f8', 'g8'])
               
    # Test en-passant
    #FIXME
    
