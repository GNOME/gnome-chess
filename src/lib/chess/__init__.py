# -*- coding: utf-8 -*-
import board
import pgn
import lan
import san
import fics

from glchess.i18n import C_

             # Translators: The first file on the chess board
_fileMap = {'a': C_('chess-file', 'a'),
             # Translators: The second file on the chess board
            'b': C_('chess-file', 'b'),
             # Translators: The third file on the chess board
            'c': C_('chess-file', 'c'),
             # Translators: The fourth file on the chess board
            'd': C_('chess-file', 'd'),
             # Translators: The fifth file on the chess board
            'e': C_('chess-file', 'e'),
             # Translators: The sixth file on the chess board
            'f': C_('chess-file', 'f'),
             # Translators: The seventh file on the chess board
            'g': C_('chess-file', 'g'),
             # Translators: The eigth file on the chess board
            'h': C_('chess-file', 'h')}

             # Translators: The first rank on the chess board
_rankMap = {'1': C_('chess-rank', '1'),
             # Translators: The second rank on the chess board
            '2': C_('chess-rank', '2'),
             # Translators: The third rank on the chess board
            '3': C_('chess-rank', '3'),
             # Translators: The fourth rank on the chess board
            '4': C_('chess-rank', '4'),
             # Translators: The fifth rank on the chess board
            '5': C_('chess-rank', '5'),
             # Translators: The sixth rank on the chess board
            '6': C_('chess-rank', '6'),
             # Translators: The seventh rank on the chess board
            '7': C_('chess-rank', '7'),
             # Translators: The eigth rank on the chess board
            '8': C_('chess-rank', '8')}

             # Translators: The notation form of a pawn.
             # See http://en.wikipedia.org/wiki/Algebraic_chess_notation#Figurine_Algebraic_Notation for translations.
_pieceMap = {'P': C_('chess-notation', 'P'),
             # Translators: The notation form of a knight
             'N': C_('chess-notation', 'N'),
             # Translators: The notation form of a bishop
             'B': C_('chess-notation', 'B'),
             # Translators: The notation form of a rook
             'R': C_('chess-notation', 'R'),
             # Translators: The notation form of a queen
             'Q': C_('chess-notation', 'Q'),
             # Translators: The notation form of a king
             'K': C_('chess-notation', 'K')}

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

_figurineMap = {(board.WHITE, 'P'): '♙', (board.WHITE, 'N'): '♘', (board.WHITE, 'B'): '♗',
                (board.WHITE, 'R'): '♖', (board.WHITE, 'Q'): '♕', (board.WHITE, 'K'): '♔',
                (board.BLACK, 'P'): '♟', (board.BLACK, 'N'): '♞', (board.BLACK, 'B'): '♝',
                (board.BLACK, 'R'): '♜', (board.BLACK, 'Q'): '♛', (board.BLACK, 'K'): '♚'}

def translate_figurine_notation(colour, notation):
    """Get the translated form of a chess move in FAN notation
    
    'colour' is the colour of the player making the move (board.WHITE or board.BLACK).
    'notation' is the notation to translate (e.g. 'Nxc6', 'f2f4').
    
    Returns a translated form of this notation.
    """
    out = ''
    isTake = False
    oppositeColour = {board.WHITE: board.BLACK, board.BLACK: board.WHITE}[colour]
    for c in notation:
        try:
            if isTake:
                out += _figurineMap[(oppositeColour, c)]
            else:
                out += _figurineMap[(colour, c)]                
        except KeyError:
            out += c
        isTake = (c == 'x')
    return out
