import board
import pgn
import lan
import san
import fics

import gettext
_ = gettext.gettext

                 # Translators: The first file on the chess board. Do not translate the 'chess-file|' text
_fileStrings = {'a': _('chess-file|a'),
                 # Translators: The second file on the chess board. Do not translate the 'chess-file|' text
                'b': _('chess-file|b'),
                 # Translators: The third file on the chess board. Do not translate the 'chess-file|' text                
                'c': _('chess-file|c'),
                 # Translators: The fourth file on the chess board. Do not translate the 'chess-file|' text                
                'd': _('chess-file|d'),
                 # Translators: The fifth file on the chess board. Do not translate the 'chess-file|' text                
                'e': _('chess-file|e'),
                 # Translators: The sixth file on the chess board. Do not translate the 'chess-file|' text                
                'f': _('chess-file|f'),
                 # Translators: The seventh file on the chess board. Do not translate the 'chess-file|' text                
                'g': _('chess-file|g'),
                 # Translators: The eigth file on the chess board. Do not translate the 'chess-file|' text                
                'h': _('chess-file|h')}
_fileMap = {}
for (key, f) in _fileStrings.iteritems():
    try:
        _fileMap[key] = f.split('|', 1)[1]
    except IndexError:
        _fileMap[key] = f

                 # Translators: The first rank on the chess board. Do not translate the 'chess-rank|' text
_rankStrings = {'1': _('chess-rank|1'),
                 # Translators: The second rank on the chess board. Do not translate the 'chess-rank|' text                
                '2': _('chess-rank|2'),
                 # Translators: The third rank on the chess board. Do not translate the 'chess-rank|' text
                '3': _('chess-rank|3'),
                 # Translators: The fourth rank on the chess board. Do not translate the 'chess-rank|' text
                '4': _('chess-rank|4'),
                 # Translators: The fifth rank on the chess board. Do not translate the 'chess-rank|' text                
                '5': _('chess-rank|5'),
                 # Translators: The sixth rank on the chess board. Do not translate the 'chess-rank|' text                
                '6': _('chess-rank|6'),
                 # Translators: The seventh rank on the chess board. Do not translate the 'chess-rank|' text                
                '7': _('chess-rank|7'),
                 # Translators: The eigth rank on the chess board. Do not translate the 'chess-rank|' text                
                '8': _('chess-rank|8')}
                
_rankMap = {}
for (key, r) in _rankStrings.iteritems():
    try:
        _rankMap[key] = r.split('|', 1)[1]
    except IndexError:
        _rankMap[key] = r

                 # Translators: The notation form of a pawn.
                 # See http://en.wikipedia.org/wiki/Algebraic_chess_notation#Figurine_Algebraic_Notation for translations.
                 # Do not translate the 'chess-notation|' text.
_pieceStrings = {'P': _('chess-notation|P'),
                 # Translators: The notation form of a knight. Do not translate the 'chess-notation|' text
                 'N': _('chess-notation|N'),
                 # Translators: The notation form of a bishop. Do not translate the 'chess-notation|' text
                 'B': _('chess-notation|B'),
                 # Translators: The notation form of a rook. Do not translate the 'chess-notation|' text                
                 'R': _('chess-notation|R'),
                 # Translators: The notation form of a queen. Do not translate the 'chess-notation|' text
                 'Q': _('chess-notation|Q'),
                 # Translators: The notation form of a king. Do not translate the 'chess-notation|' text                
                 'K': _('chess-notation|K')}
                 
_pieceMap = {}
for (key, r) in _pieceStrings.iteritems():
    try:
        _pieceMap[key] = r.split('|', 1)[1]
    except IndexError:
        _pieceMap[key] = r

_notationMap = {}
_notationMap.update(_fileMap)
_notationMap.update(_rankMap)
_notationMap.update(_pieceMap)    
        
def translate_file(file):
    """Get the translated form of a file.
    
    'file' is the file to translate ('a'-'h')
    
    Returns a string representing this file.
    """
    return _fileMap[file]

def translate_rank(rank):
    """Get the translated form of a rank.
    
    'rank' is the rank to translate ('1'-'8')
    
    Returns a string representing this rank.
    """
    return _rankMap[rank]

def translate_coordinate(coordinate):
    """Get the translated form of a chess board coordinate.
    
    'coordinate' is the coordinate to translate ('a1'-'h8')
    
    Returns a string representing this position.
    """
    # FIXME: Assumes files are always before ranks. Should probably make all
    # 64 coordinates translatable to be strictly translatable
    return _fileMap[coordinate[0]] + _rankMap[coordinate[1]]

def translate_notation(notation):
    """Get the translated form of a chess move in LAN or SAN notation
    
    'notation' is the notation to translate (e.g. 'Nxc6', 'f2f4').
    
    Returns a translated form of this notation.
    """
    out = ''
    for c in notation:
        try:
            out += _notationMap[c]
        except KeyError:
            out += c
    return out
