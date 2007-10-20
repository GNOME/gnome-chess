"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import board

CHECK        = '+'
CHECKMATE    = '#'

# Notation for takes
MOVE         = '-'
TAKE         = 'x'

# Castling moves
CASTLE_SHORT = 'o-o'
CASTLE_LONG  = 'o-o-o'

# Characters used to describe pieces
_typeToLAN = {board.PAWN:   'p',
              board.KNIGHT: 'n',
              board.BISHOP: 'b',
              board.ROOK:   'r',
              board.QUEEN:  'q',
              board.KING:   'k'}
_lanToType = {}
for (pieceType, character) in _typeToLAN.iteritems():
    _lanToType[character] = pieceType

class DecodeError(Exception):
    """
    """
    pass
        
def _checkLocation(location):
    """
    """
    if len(location) != 2:
        raise DecodeError('Invalid length location')
    if location[0] < 'a' or location[0] > 'h':
        raise DecodeError('Invalid rank')
    if location[1] < '0' or location[1] > '8':
        raise DecodeError('Invalid file')
    return location

def decode(colour, move):
    """Decode a long algebraic format move.
    
    'colour' is the colour of the player making the move (board.WHITE or board.BLACK).
    'move' is the move description (string).

    Returns a tuple containing (start, end, piece, moveType, promotionType, result)
    'start' is the location being moved from (string, e.g. 'a1', 'h8').
    'end' is the location being moved to (string, e.g. 'a1', 'h8').
    'piece' is the piece being moved (board.PAWN, board.ROOK, ... or None if not specified).
    'moveType' is a flag to show if this move takes an oppoenent piece (MOVE, TAKE or None if not specified).
    'promotionType' is the piece type to promote to (board.ROOK, board.KNIGHT, ... or None if not specified).
    'check' is the result after the move (CHECK, CHECKMATE or None if not specified).
    
    Raises DecodeError if the move is unable to be decoded.
    """
    pieceType     = None
    promotionType = None
    moveType      = None
    result        = None
    
    move = move.lower()

    if colour is board.WHITE:
        baseFile = '1'
    else:
        baseFile = '8'
    if move == CASTLE_SHORT:
        return ('e' + baseFile, 'g' + baseFile, None, None, None, None)
    elif move == CASTLE_LONG:
        return ('e' + baseFile, 'c' + baseFile, None, None, None, None)

    # First character can be the piece types
    if len(move) < 1:
        raise DecodeError('Too short')
    try:
        pieceType = _lanToType[move[0]]
    except KeyError:
        pieceType = None
    else:
        move = move[1:]

    if len(move) < 2:
        raise DecodeError('Too short')
    try:
        start = _checkLocation(move[:2])
    except DecodeError, e:
        if pieceType is None:
            raise e
        # Perhaps the first character wasn't a piece type
        else:
            move = _typeToLAN[pieceType] + move
            start = _checkLocation(move[:2])
            pieceType = None
    move = move[2:]
        
    if len(move) < 1:
        raise DecodeError('Too short')
    if move[0] == MOVE or move[0] == TAKE:
        moveType = move[0]
        move = move[1:]

    if len(move) < 2:
        raise DecodeError('Too short')
    end = _checkLocation(move[:2])
    move = move[2:]

    # Look for promotion type, note this can be in upper or lower case
    if len(move) > 0:
        if move[0] == '=':
            if len(move) < 2:
                raise DecodeError('Too short')
            try:
                promotionType = _lanToType[move[1]]
            except KeyError:
                raise DecodeError('Unknown promotion type')
            move = move[2:]
        else:
            try:
                promotionType = _lanToType[move[0]]
            except KeyError:
                pass
            else:
                move = move[1:]

    if len(move) == 1:
        if move == CHECK or move == CHECKMATE:
            result = move
            move = ''
    elif len(move) == 2:
        if move == '++':
            result = CHECKMATE
            move = ''

    if len(move) != 0:
        raise DecodeError('Extra characters')
    
    return (start, end, pieceType, moveType, promotionType, result)

def encode(colour, start, end, piece = None, moveType = None, promotionType = None, result = None):
    """Encode a long algebraic format move.
        
    'start' is the location being moved from (string, e.g. 'a1', 'h8').
    'end' is the location being moved to (string, e.g. 'a1', 'h8').
    'piece' is the piece being moved (board.PAWN, board.ROOK, ... or None if not specified).
    'moveType' is a flag to show if this move takes an oppoenent piece (MOVE, TAKE or None if not specified).
    'promotionType' is the piece type to promote to (board.ROOK, board.KNIGHT, ... or None if not specified).
    'check' is the result after the move (CHECK, CHECKMATE or None if not specified).
        
    Returns a string describing this move.
    """
    try:
        _checkLocation(start)
        _checkLocation(end)
    except DecodeError:
        raise TypeError("Invalid values for 'start' and 'end'")
        
    string = ''
        
    # Report the piece being moved
    if piece is not None:
        string += _typeToLAN[piece]
            
    # Report the source location
    string += start
        
    # Report if this is a move or a take
    if moveType != None:
        string += moveType

    # Report the target location
    string += end
        
    # Report the promotion type
    # FIXME: Only report if a pawn promotion
    if promotionType != None:
        if False: # FIXME: What to name this flag?
            string += '='
        string += _typeToLAN[promotionType].lower()

    # Report the check result
    if result is not None:
        string += result

    return string
