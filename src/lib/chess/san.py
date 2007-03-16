"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['SANConverter']

# Examples of SAN moves:
#
# f4      (pawn move to f4)
# fxg3    (pawn on file f takes opponent on g3)
# Qh5     (queen moves to h5)
# Qh5+    (queen moves to h5 and puts opponent into check)
# Ned4    (knight on file e moves to d4)
# gxh8=Q# (pawn on g7 takes opponent in h8 promotes to queen and puts oponent into checkmate (smooth!))

# Notation for takes
SAN_TAKE   = 'x'

# Castling moves
SAN_CASTLE_SHORT = 'O-O'
SAN_CASTLE_LONG  = 'O-O-O'

RANKS = 'abcdefgh'
FILES = '12345678'

# Suffixes
SAN_PROMOTE   = '='

class Error(Exception):
    """
    """
    
    # Properties of the error
    __move = ''
    __description = ''
    
    def __init__(self, move, description):
        """Constructor for a SAN exception.
        
        'move' is the SAN move that generated the exception (string).
        'description' is the description of the exception that occured (string).
        """
        self.__move = str(move)
        self.__description = str(description)
        Exception.__init__(self)
    
    def __str__(self):
        """Convert the SAN exception to a string"""
        return 'Error parsing SAN move ' + repr(self.__move) + ': ' + self.__description

class SANConverter:
    """
    
    Define file and rank
    """
    
    # Piece colours
    WHITE = 'White'
    BLACK = 'Black'
    
    # SAN piece types
    PAWN   = 'P'
    KNIGHT = 'N'
    BISHOP = 'B'
    ROOK   = 'R'
    QUEEN  = 'Q'
    KING   = 'K'
    __pieceTypes = PAWN + KNIGHT + BISHOP + ROOK + QUEEN + KING
    
    # Valid promotion types
    __promotionTypes = PAWN + KNIGHT + BISHOP + ROOK + QUEEN
    
    # Move results
    CHECK     = '+'
    CHECKMATE = '#'
    
    def __init__(self):
        """Constructor"""
        pass
    
    # Methods to extend
    
    def getPiece(self, location):
        """Get a piece from the chess board.
        
        'location' is the location to get the piece from (string, e.g. 'a1', h8').
        
        Return a tuple containing (colour, type) or None if no piece at this location.
        """
        return None
    
    def testMove(self, colour, start, end, promotionType, allowSuicide = False):
        """Test if a move is valid.
        
        'colour' is the colour of the player making the move (self.WHITE or self.BLACK).
        'start' is the board location to move from (string, e.g. 'a1', 'h8').
        'end' is the board location to move to (string, e.g. 'a1', 'h8').
        'promotionType' is the piece type to promote to (self.[PAWN|KNIGHT|BISHOP|ROOK|QUEEN]).
        'allowSuicide' is a flag to show if the move should be disallowed (False) or
                       allowed (True) if it would put the moving player into check.

        Return False if the move is dissallowed or
               self.CHECK if the move puts the opponent into check or
               self.CHECKMATE if the move puts the opponent into checkmate or
               True if the move is allowed and does not put the opponent into check.
        """
        pass
    
    def decodeSAN(self, colour, san):
        """Decode a SAN move.
        
        'colour' is the colour of the player making the move (self.WHITE or self.BLACK).
        'san' is the SAN description of the move (string).
        
        Returns the move this SAN describes in the form (start, end, promotionType).
        'start' is the square to move from (string, e.g. 'a1', 'h8').
        'end' is the square to move to (string, e.g. 'a1', 'h8').
        'promotionType' is the piece to promote to (self.[KNIGHT|BISHOP|ROOK|QUEEN]).
        If the move is invalid then an Error expection is raised.
        """
        copy = san[:]
        
        # Look for check hints
        expectedResult = True
        if copy[-1] == self.CHECK or copy[-1] == self.CHECKMATE:
            expectedResult = copy[-1]
            copy = copy[:-1]

        # Extract promotions
        promotionType = self.QUEEN
        if copy[-2] == SAN_PROMOTE:
            promotionType = copy[-1]
            copy = copy[:-2]
            if self.__promotionTypes.find(promotionType) < 0:
                raise Error(san, 'Invalid promotion type ' + promotionType)
            
        # Some people miss out the '='
        elif self.__promotionTypes.find(copy[-1]) >= 0:
            promotionType = copy[-1]
            copy = copy[:-1]

        # Check for castling moves
        if colour is self.WHITE:
            baseFile = '1'
        else:
            baseFile = '8'
        # FIXME: Update moveResult and compare against expectedResult
        if copy == SAN_CASTLE_SHORT:
            return ('e' + baseFile, 'g' + baseFile, expectedResult, promotionType)
        elif copy == SAN_CASTLE_LONG:
            return ('e' + baseFile, 'c' + baseFile, expectedResult, promotionType)

        # Get the destination (the last two characters before the suffix)
        end = copy[-2:]
        copy = copy[:-2]
        if RANKS.find(end[0]) < 0 or FILES.find(end[1]) < 0:
            raise Error(san, 'Invalid destination: ' + end)

        # Check if is a take move (use try in case there are no more characters)
        isTake = False
        try:
            if copy[-1] == SAN_TAKE:
                isTake = True
                copy = copy[:-1]
        except:
            pass

        # The first character is the piece type (or pawn if not specified)
        pieceType = self.PAWN
        if len(copy) > 0:
            if self.__pieceTypes.find(copy[0]) >= 0:
                pieceType = copy[0]
                copy = copy[1:]

        # Get the rank of the source piece (if supplied)
        rank = None
        if len(copy) > 0:
            if RANKS.find(copy[0]) >= 0:
                rank = copy[0]
                copy = copy[1:]

        # Get the file of the source piece (if supplied)
        file = None
        if len(copy) > 0:
            if FILES.find(copy[0]) >= 0:
                file = copy[0]
                copy = copy[1:]

        # There should be no more characters
        if len(copy) != 0:
            raise Error(san, 'Unexpected extra characters: ' + copy)
    
        # If have both rank and file for source then we have the move completely defined
        moveResult = None
        move = None
        if rank is not None and file is not None:
            start = rank + file
            moveResult = self.testMove(colour, start, end, promotionType = promotionType)
            move = (start, end)
        else:
            # Try and find a piece that matches the source one
            if file is None:
                fileRange = FILES
            else:
                fileRange = file
            if rank is None:
                rankRange = RANKS
            else:
                rankRange = rank
            
            for file in fileRange:
                for rank in rankRange:
                    start = rank + file
                
                    # Only test our pieces
                    piece = self.getPiece(start)
                    if piece is None:
                        continue
                    if piece[0] != colour or piece[1] != pieceType:
                        continue

                    # If move is valid this is a possible move
                    # FIXME: Check the crafty case in reverse (i.e. suicidal moves)
                    result = self.testMove(colour, start, end, promotionType = promotionType)
                    if result is False:
                        continue
                
                    # Multiple matches
                    if moveResult is not None:
                        raise Error(san, 'Move is ambiguous, at least ' + str(move) + ' and ' + str([start, end]) + ' are possible')
                    moveResult = result
                    move = [start, end]

        # Failed to find a match
        if moveResult is None:
            raise Error(san, 'Not a valid move')

        return (move[0], move[1], expectedResult, promotionType)

    def encode(self, start, end, promotionType = QUEEN):
        """Convert glChess co-ordinate move to SAN notation.

        'start' is the square to move from (string, e.g. 'a1', 'h8').
        'end' is the square to move to (string, e.g. 'a1', 'h8').
        'promotionType' is the piece used for pawn promotion (if necesasary).
        
        Return the move in SAN notation or None if unable to convert.
        """
        piece = self.getPiece(start)
        if piece is None:
            return None
        (pieceColour, pieceType) = piece
        victim = self.getPiece(end)

        # Test the move is valid
        if self.testMove(pieceColour, start, end, promotionType) is False:
            return None

        # Check for castling
        if pieceType is self.KING:
            # Castling
            if pieceColour is self.WHITE:
                baseFile = '1'
            else:
                baseFile = '8'
            shortCastle = ('e' + baseFile, 'g' + baseFile)
            longCastle = ('e' + baseFile, 'c' + baseFile)
            # FIXME: Add check result
            if (start, end) == shortCastle:
                return SAN_CASTLE_SHORT
            elif (start, end) == longCastle:
                return SAN_CASTLE_LONG

        # Try and describe this piece with the minimum of information
        file = '?'
        rank = '?'
    
        # Pawns always explicitly provide rank when taking
        if pieceType is self.PAWN and victim is not None:
            rank = start[0]

        # First try no rank or file, then just file, then just rank, then both
        result = self.__isUnique(pieceColour, pieceType, rank + file, end, promotionType)
        if result is None:
            # Try with rank
            rank = start[0]
            file = '?'
            result = self.__isUnique(pieceColour, pieceType, rank + '?', end, promotionType)

            if result is None:
                # Try with file
                rank = '?'
                file = start[1]
                result = self.__isUnique(pieceColour, pieceType, '?' + file, end, promotionType)

                if result is None:
                    # Try with rank and file
                    result = self.__isUnique(pieceColour, pieceType, rank + file, end, promotionType)
            
                    # This move is illegal
                    if result is None:
                        return None

        # Store the piece that is being moved, note pawns are not marked
        san = ''
        if pieceType is not self.PAWN:
            san += pieceType

        # Disambiguations
        if rank != '?':
            san += rank
        if file != '?':
            san += file
                
        # Mark if taking a piece
        if victim is not None:
            san += SAN_TAKE

        # Write target co-ordinate
        san += end

        # If a pawn promotion record the type
        if pieceColour is self.WHITE:
            promotionFile = '8'
        else:
            promotionFile = '1'
        if pieceType == self.PAWN and end[1] == promotionFile:
            san += SAN_PROMOTE + promotionType

        # Record if this is a check/checkmate move
        if result is self.CHECK:
            san += self.CHECK
        elif result is self.CHECKMATE:
            san += self.CHECKMATE

        return san
    
    def __isUnique(self, colour, pieceType, start, end, promotionType = QUEEN):
        """Test if a move is unique.
    
        'colour' is the piece colour being moved. (self.WHITE or self.BLACK).
        'pieceType' is the type of the piece being moved (self.[PAWN|KNIGHT|BISHOP|ROOK|QUEEN|KING]).
        'start' is the start location of the move (tuple (file, rank). rank and file can be None).
        'end' is the end point of the move (tuple (file,rank)).
        'promotionType' is the piece type to promote pawns to (self.[PAWN|KNIGHT|BISHOP|ROOK|QUEEN]).
    
        Return the result of self.testMove() if a unique move is found otherwise None.
        """
        lastResult = None
    
        # Work out what ranges to iterate over
        if start[0] == '?':
            rankRange = RANKS
        else:
            rankRange = start[0]
        if start[1] == '?':
            fileRange = FILES
        else:
            fileRange = start[1]
    
        for file in fileRange:
            for rank in rankRange:
                # Check if there is a piece of this type and colour at this location
                p = self.getPiece(rank + file)
                if p is None:
                    continue
                if p[1] != pieceType or p[0] != colour:
                    continue

                # If move is valid this is a possible move
                # NOTE: We check moves that would be suicide for us otherwise crafty claims they
                # are ambiguous, the PGN specification says we don't need to disambiguate if only
                # one non-suicidal move is available.
                # (8.2.3.4: Disambiguation) */
                result = self.testMove(colour, rank + file, end, promotionType = promotionType, allowSuicide = True)
                if result is not False:
                    # If multiple matches then not unique (duh!)
                    if lastResult != None:
                        return None
                    lastResult = result

        # Return the result of the move
        return lastResult

if __name__ == '__main__':
    
    import chess_board
    
    class TestConverter(SANConverter):
        """
        """
        
        __colourToSAN = {chess_board.WHITE: SANConverter.WHITE, chess_board.BLACK: SANConverter.BLACK}
        __sanToColour = {}
        for (a, b) in __colourToSAN.iteritems():
            __sanToColour[b] = a
        
        __typeToSAN = {chess_board.PAWN: SANConverter.PAWN,
                       chess_board.KNIGHT: SANConverter.KNIGHT,
                       chess_board.BISHOP: SANConverter.BISHOP,
                       chess_board.ROOK: SANConverter.ROOK,
                       chess_board.QUEEN: SANConverter.QUEEN,
                       chess_board.KING: SANConverter.KING}
        __sanToType = {}
        for (a, b) in __typeToSAN.iteritems():
            __sanToType[b] = a
        
        __board = None
        
        def __init__(self, board):
            self.__board = board
            
        def testEncode(self, start, end):
            print str((start, end)) + ' => ' + str(self.encode(start, end))
            
        def testDecode(self, colour, san):
            try:
                result = self.decodeSAN(colour, san)
                print san.ljust(7) + ' => ' + str(result)
            except Error, e:
                print san.ljust(7) + ' !! ' + str(e)
        
        def getPiece(self, file, rank):
            """Called by SANConverter"""
            piece = self.__board.getPiece((file, rank))
            if piece is None:
                return None
            return (self.__colourToSAN[piece.getColour()], self.__typeToSAN[piece.getType()])

        def testMove(self, colour, start, end, promotionType, allowSuicide = False):
            """Called by SANConverter"""
            moveResult = self.__board.testMove(self.__sanToColour[colour], ((start, end)), self.__sanToType[promotionType], allowSuicide)
            
            return {chess_board.MOVE_RESULT_ILLEGAL: False,
                    chess_board.MOVE_RESULT_ALLOWED: True,
                    chess_board.MOVE_RESULT_OPPONENT_CHECK: self.CHECK,
                    chess_board.MOVE_RESULT_OPPONENT_CHECKMATE: self.CHECKMATE}[moveResult]

    b = chess_board.ChessBoard()
    c = TestConverter(b)
    
    print b
    c.testEncode((1,1), (1,2))
    c.testEncode((1,0), (2,2))
    
    c.testDecode(c.WHITE, 'c3')    # Simple pawn move
    c.testDecode(c.WHITE, 'Pc3')   # Explicit pawn move
    c.testDecode(c.WHITE, 'c4')    # Pawn march
    c.testDecode(c.WHITE, 'Nc3')   # Non-pawn move
    c.testDecode(c.WHITE, 'Qd3')   # Invalid move
    c.testDecode(c.WHITE, 'Qd3=X') # Invalid promotion type
    c.testDecode(c.WHITE, 'x3')    # Invalid destination
    c.testDecode(c.WHITE, 'ic3')   # Extra characters
    # TODO: Ambiguous move
    print b
    