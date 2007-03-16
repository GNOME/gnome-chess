import sre

"""See: http://www.unix-ag.uni-kl.de/~chess/gicshelp/node197.html"""

COLOUR_BLACK = 'B'
COLOUR_WHITE = 'W'

RELATIONSHIP_PLAYING_OPPONENT_MOVE = '-1'
RELATIONSHIP_PLAYING_MY_MOVE       = '1'
RELATIONSHIP_OBSERVER_EXAMINED     = '-2'
RELATIONSHIP_OBSERVER              = '0'
RELATIONSHIP_EXAMINER              = '2'

#<12> rnbqkbnr pppppppp -------- -------- -------- -------- PPPPPPPP RNBQKBNR W -1 1 1 1 1 0 89 GuestGLQF GuestPSVJ 1 2 12 39 39 120 120 1 none (0:00) none 0 0 0

#<12> 
#rnbqkbnr 
#pppppppp 
#-------- 
#-------- 
#-------- 
#-------- 
#PPPPPPPP 
#RNBQKBNR 
#W 
#-1 
#1 
#1 
#1 
#1 
#0 
#89 
#GuestGLQF 
#GuestPSVJ 
#1 
#2 
#12 
#39 
#39 
#120 
#120 
#1 
#none 
#(0:00) 
#none 
#0 
#0 
#0
movePattern = sre.compile('<12> ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([prnbqkPRNBQK-]{8}) ' +
                          '([BW]{1}) ' +             # Colour to move
                          '([-]?\d+) ' +             # Pawn file or -1
                          '([01]{1}) ' +             # Can white short castle
                          '([01]{1}) ' +             # Can white long castle
                          '([01]{1}) ' +             # Can black short castle
                          '([01]{1}) ' +             # Can black long castle
                          '(\d+) ' +                 # Number of irreversable moves
                          '(\d+) ' +                 # Game number
                          '(.+) ' +                  # White name
                          '(.+) ' +                  # Black name
                          '([-]?\d+) ' +             # Relationship to game (-2, 2, -1, 1, 0)
                          '(\d+) ' +
                          '(\d+) ' +
                          '(\d+) ' +                 # White strength
                          '(\d+) ' +                 # Black strength
                          '(\d+) ' +                 # White time
                          '(\d+) ' +                 # Black black
                          '(\d+) ' +                 # Move number
                          '(.+) ' +                  # Move
                          '[(](\d+)[:](\d+)[)] ' +   # Move duration
                          '(.+) ' +                  # Pretty move
                          '([01]{1})' +
                          '([01]{1})' +
                          '([01]{1})')

def _decodeFile(string):
    # FIXME: Only allow 'prnbqkPRNBQK-'
    return string

def _decodeColour(string):
    if string == 'B' or string == 'W':
        return string
    raise ValueError()

def _decodeInteger(string):
    return int(string)

def _decodeUInteger(string):
    i = int(string)
    if i < 0:
        raise ValueError()
    return i

def _decodeTime(string):
    # FIXME: In form '(mm:ss)'
    return 0
          
def _decodeString(string):
    return string
          
def _decodeBoolean(string):
    if string == '0':
        return False
    if string == '1':
        return True
    raise ValueError()

fields = [_decodeFile, _decodeFile, _decodeFile, _decodeFile, _decodeFile, _decodeFile, _decodeFile, _decodeFile,
          _decodeColour, _decodeInteger,
          _decodeBoolean, _decodeBoolean, _decodeBoolean, _decodeBoolean,
          _decodeUInteger, _decodeUInteger,
          _decodeString, _decodeString,
          _decodeInteger,
          _decodeUInteger, _decodeUInteger,
          _decodeUInteger, _decodeUInteger,
          _decodeUInteger, _decodeUInteger,
          _decodeUInteger, _decodeString, _decodeTime, _decodeString,
          _decodeBoolean]

class Player:
    """
    """
    name = ''
    canCastleShort = False
    canCastleLong  = False
    strength = 0
    
    # Remaining time
    remaining = 0

class Move:
    """
    """
    # The state of the board
    board = None
    
    # The relationship of this reader to the game
    relationship = None
    
    # The game number
    gameNumber = 0
    startTime = 0 # s
    increment = 0 # ms
    
    # ?
    nReversibleMoves = 0
    
    # The player states
    white = None
    black = None
    
    # The previous move
    move       = ''
    movePretty = ''
    marchFile  = -1
    moveTime   = 0 # seconds
    
    # The number of the move to make
    moveNumber = 0
    colourToMove = None
    
    # ?
    flip = None

    def __init__(self):
        self.white = Player()
        self.black = Player()

def decode(line):
    """
    """
    tokens = line.split()[1:]
    if len(tokens) < len(fields):
        raise ValueError('Too few fields')

    out = []
    for i in xrange(len(fields)):
        try:
            out.append(fields[i](tokens[i]))
        except ValueError:
            raise ValueError('Invalid field: %s' % tokens[i])

    m = Move()
    (file1, file2, file3, file4, file5, file6, file7, file8,
     moveColour, pushFile,
     whiteCastleShort, whiteCastleLong, blackCastleShort, blackCastleLong,
     nIrreversableMoves, m.gameNumber,
     m.white.name, m.black.name,
     m.relationship,
     initialTime, incrementTime,
     m.white.strength, m.black.strength,
     m.white.remaining, m.black.remaining,
     m.moveNumber, m.move, m.moveTime, m.movePretty,
     orientation) = out
    m.board = (file1, file2, file3, file4, file5, file6, file7, file8)

    return m
