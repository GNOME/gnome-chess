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
_typeToLAN = {board.PAWN:   'P',
              board.KNIGHT: 'N',
              board.BISHOP: 'B',
              board.ROOK:   'R',
              board.QUEEN:  'Q',
              board.KING:   'K'}
_lanToType = {}
for (pieceType, character) in _typeToLAN.iteritems():
    _lanToType[character] = pieceType
    _lanToType[character.lower()] = pieceType # English pieces are sometimes written in lowercase

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
    
    m = move
    
    if colour is board.WHITE:
        baseFile = '1'
    else:
        baseFile = '8'
    if m == CASTLE_SHORT:
        return ('e' + baseFile, 'g' + baseFile, None, None, None, None)
    elif m == CASTLE_LONG:
        return ('e' + baseFile, 'c' + baseFile, None, None, None, None)

    # First character can be the piece types
    if len(m) < 1:
        raise DecodeError('Too short')
    try:
        pieceType = _lanToType[m[0]]
    except KeyError:
        pieceType = None
    else:
        m = m[1:]

    if len(m) < 2:
        raise DecodeError('Too short')
    try:
        start = _checkLocation(m[:2])
    except DecodeError, e:
        if pieceType is None:
            raise e
        # Perhaps the first character wasn't a piece type
        m = move
        start = _checkLocation(m[:2])
        pieceType = None
    m = m[2:]
        
    if len(m) < 1:
        raise DecodeError('Too short')
    if m[0] == MOVE or m[0] == TAKE:
        moveType = m[0]
        m = m[1:]

    if len(m) < 2:
        raise DecodeError('Too short')
    end = _checkLocation(m[:2])
    m = m[2:]

    # Look for promotion type, note this can be in upper or lower case
    if len(m) > 0:
        if m[0] == '=':
            if len(m) < 2:
                raise DecodeError('Too short')
            try:
                promotionType = _lanToType[m[1]]
            except KeyError:
                raise DecodeError('Unknown promotion type')
            m = m[2:]
        else:
            try:
                promotionType = _lanToType[m[0]]
            except KeyError:
                pass
            else:
                m = m[1:]

    if len(m) == 1:
        if m == CHECK or m == CHECKMATE:
            result = m
            m = ''
    elif len(m) == 2:
        if m == '++':
            result = CHECKMATE
            m = ''

    if len(m) != 0:
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
