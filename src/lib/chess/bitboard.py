
#
#
#      +---+---+---+---+---+---+---+---+
#    8 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
#      +---+---+---+---+---+---+---+---+
#    7 | . |   | . |   | . |   | . |   |
#      +---+---+---+---+---+---+---+---+
#    6 |   | . |   | . |   | . |   | . |
# r    +---+---+---+---+---+---+---+---+
# a  5 | . |   | . |   | . |   | . |   |
# n    +---+---+---+---+---+---+---+---+
# k  4 |   | . |   | . |   | . |   | . |
# s    +---+---+---+---+---+---+---+---+
#    3 | . |   | . |   | . |   | . |   |
#      +---+---+---+---+---+---+---+---+
#    2 |   | . |   | . |   | . |   | . |
#      +---+---+---+---+---+---+---+---+
#    1 |56 |57 |58 |59 |60 |61 |62 |63 |
#      +---+---+---+---+---+---+---+---+
#
#        a   b   c   d   e   f   g   h
#                    files

def getIndex(square):
    file = ord(square[0]) - ord('a')
    rank = ord(square[1]) - ord('1')
    return (7 - rank) * 8 + file

def getRankAndFile(index):
    file = index % 8
    rank = 7 - (index / 8)
    return (file, rank)

def reflectField(field):
    outField = 0
    for i in xrange(64):
        if field & LOCATIONS[i]:
            (file, rank) = getRankAndFile(i)
            outField |= LOCATIONS[rank * 8 + file]
    return outField

def reflectMoves(inMoves, outMoves):
    for i in xrange(64):
        (file, rank) = getRankAndFile(i)
        outMoves[rank * 8 + file] = reflectField(inMoves[i])

def printField(field):
    string = '+---+---+---+---+---+---+---+---+\n'
    rowCount = 0
    colour = ' '
    for l in LOCATIONS:
        if field & l:
            string += '|[%s]' % colour
        else:
            string += '| %s ' % colour
        rowCount += 1
        if rowCount == 8:
            rowCount = 0
            string += '|\n+---+---+---+---+---+---+---+---+\n'
        else:
            if colour == ' ':
                colour = '.'
            else:
                colour = ' '
    print string

LOCATIONS = [0x0000000000000001, 0x0000000000000002, 0x0000000000000004, 0x0000000000000008,
             0x0000000000000010, 0x0000000000000020, 0x0000000000000040, 0x0000000000000080,
             0x0000000000000100, 0x0000000000000200, 0x0000000000000400, 0x0000000000000800,
             0x0000000000001000, 0x0000000000002000, 0x0000000000004000, 0x0000000000008000,
             0x0000000000010000, 0x0000000000020000, 0x0000000000040000, 0x0000000000080000,
             0x0000000000100000, 0x0000000000200000, 0x0000000000400000, 0x0000000000800000,
             0x0000000001000000, 0x0000000002000000, 0x0000000004000000, 0x0000000008000000,
             0x0000000010000000, 0x0000000020000000, 0x0000000040000000, 0x0000000080000000,
             0x0000000100000000, 0x0000000200000000, 0x0000000400000000, 0x0000000800000000,
             0x0000001000000000, 0x0000002000000000, 0x0000004000000000, 0x0000008000000000,
             0x0000010000000000, 0x0000020000000000, 0x0000040000000000, 0x0000080000000000,
             0x0000100000000000, 0x0000200000000000, 0x0000400000000000, 0x0000800000000000,
             0x0001000000000000, 0x0002000000000000, 0x0004000000000000, 0x0008000000000000,
             0x0010000000000000, 0x0020000000000000, 0x0040000000000000, 0x0080000000000000,
             0x0100000000000000, 0x0200000000000000, 0x0400000000000000, 0x0800000000000000,
             0x1000000000000000, 0x2000000000000000, 0x4000000000000000, 0x8000000000000000]
             
KNIGHT_MOVES = [0xFFFFFFFFFFFFFFFF] * 64
WHITE_PAWN_MOVES = KNIGHT_MOVES[:]
WHITE_PAWN_TAKES = KNIGHT_MOVES[:]
BLACK_PAWN_MOVES = KNIGHT_MOVES[:]
BLACK_PAWN_TAKES = KNIGHT_MOVES[:]
ROOK_MOVES = KNIGHT_MOVES[:]
BISHOP_MOVES = KNIGHT_MOVES[:]
KNIGHT_MOVES = KNIGHT_MOVES[:]
QUEEN_MOVES = KNIGHT_MOVES[:]
WHITE_KING_MOVES = KNIGHT_MOVES[:]
BLACK_KING_MOVES = KNIGHT_MOVES[:]

INBETWEEN_SQUARES = [None] * 64
for i in xrange(64):
    INBETWEEN_SQUARES[i] = [0L] * 64

def genMoves():    
    for start in xrange(64):
        (f0, r0) = getRankAndFile(start)
        pawnField = 0
        pawnTakeField = 0
        rookField = 0
        bishopField = 0
        knightField = 0
        queenField = 0
        kingField = 0

        for end in xrange(64):
            # Ignore null move
            if end == start:
                continue

            (f1, r1) = getRankAndFile(end)
            endField = LOCATIONS[end]
            
            ibField = 0
            # Vertical, horizontal or diagonal
            if f0 == f1 or r0 == r1 or abs(f0 - f1) == abs(r0 - r1):
                fstep = cmp(f1, f0)
                rstep = cmp(r1, r0)
                file = f0 + fstep
                rank = r0 + rstep
                count = max(abs(f0 - f1), abs(r0 - r1)) - 1
                for i in xrange(count):
                    ibField |= LOCATIONS[(7 - rank) * 8 + file]
                    file += fstep
                    rank += rstep
                
            INBETWEEN_SQUARES[start][end] = ibField

            # Pawn moves
            if f0 == f1:
                if r1 - r0 == 1:
                    pawnField |= endField
                # March
                if r0 == 1 and r1 == 3:
                    pawnField |= endField
                    
            # Pawn takes
            if abs(f0 - f1) == 1 and r1 - r0 == 1:
                pawnField |= endField
                pawnTakeField |= endField
            
            # Knight moves
            if abs(f0 - f1) * abs(r0 - r1) == 2:
                knightField |= endField
                
            # Do diagonals
            if abs(f0 - f1) == abs(r0 - r1):
                bishopField |= endField
                queenField |= endField
        
            # Do orthogonals
            if abs(f0 - f1) * abs(r0 - r1) == 0:
                rookField |= endField
                queenField |= endField

            # Standard king
            if abs(f0 - f1) <= 1 and abs(r0 - r1) <= 1:
                kingField |= endField
                
            # Castling
            if r0 == r1 and r0 == 0 and f0 == 4 and abs(f0 - f1) == 2:
                kingField |= endField

        WHITE_PAWN_MOVES[start] = pawnField
        WHITE_PAWN_TAKES[start] = pawnTakeField
        ROOK_MOVES[start] = rookField
        BISHOP_MOVES[start] = bishopField
        KNIGHT_MOVES[start] = knightField
        QUEEN_MOVES[start] = queenField
        WHITE_KING_MOVES[start] = kingField

    reflectMoves(WHITE_PAWN_MOVES, BLACK_PAWN_MOVES)
    reflectMoves(WHITE_PAWN_TAKES, BLACK_PAWN_TAKES)
    reflectMoves(WHITE_KING_MOVES, BLACK_KING_MOVES)

    move = 60
    #printField(WHITE_PAWN_MOVES[move])
    #printField(WHITE_PAWN_TAKES[move])
    #printField(BLACK_PAWN_MOVES[move])
    #printField(BLACK_PAWN_TAKES[move])
    #printField(ROOK_MOVES[move])
    #printField(BISHOP_MOVES[move])
    #printField(KNIGHT_MOVES[move])
    #printField(QUEEN_MOVES[move])
    #printField(WHITE_KING_MOVES[move])

genMoves()