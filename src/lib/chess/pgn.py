# -*- coding: utf-8 -*-
"""
Implement a PGN reader/writer.

See http://www.chessclub.com/help/PGN-spec
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import re

"""
; Example PGN file

[Event "F/S Return Match"]
[Site "Belgrade, Serbia JUG"]
[Date "1992.11.04"]
[Round "29"]
[White "Fischer, Robert J."]
[Black "Spassky, Boris V."]
[Result "1/2-1/2"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3
O-O 9. h3 Nb8 10. d4 Nbd7 11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15.
Nb1 h6 16. Bh4 c5 17. dxe5 Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21.
Nc4 Nxc4 22. Bxc4 Nb6 23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7
27. Qe3 Qg5 28. Qxg5 hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33.
f3 Bc8 34. Kf2 Bf5 35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5
40. Rd6 Kc5 41. Ra6 Nf2 42. g4 Bd3 43. Re6 1/2-1/2
"""

RESULT_INCOMPLETE = '*'
RESULT_WHITE_WIN  = '1-0'
RESULT_BLACK_WIN  = '0-1'
RESULT_DRAW       = '1/2-1/2'
results = {RESULT_INCOMPLETE: RESULT_INCOMPLETE,
           RESULT_WHITE_WIN: RESULT_WHITE_WIN,
           RESULT_BLACK_WIN: RESULT_BLACK_WIN,
           RESULT_DRAW: RESULT_DRAW}

"""The required tags in a PGN file (the seven tag roster, STR)"""
TAG_EVENT  = 'Event'
TAG_SITE   = 'Site'
TAG_DATE   = 'Date'
TAG_ROUND  = 'Round'
TAG_WHITE  = 'White'
TAG_BLACK  = 'Black'
TAG_RESULT = 'Result'

"""Optional tags"""
TAG_TIME         = 'Time'
TAG_FEN          = 'FEN'
TAG_WHITE_TYPE   = 'WhiteType'
TAG_WHITE_ELO    = 'WhiteElo'
TAG_BLACK_TYPE   = 'BlackType'
TAG_BLACK_ELO    = 'BlackElo'
TAG_TIME_CONTROL = 'TimeControl'
TAG_TERMINATION  = 'Termination'

# Values for the WhiteType and BlackType tag
PLAYER_HUMAN     = 'human'
PLAYER_AI        = 'program'

# Values for the Termination tag
TERMINATE_ABANDONED        = 'abandoned'
TERMINATE_ADJUDICATION     = 'adjudication'
TERMINATE_DEATH            = 'death'
TERMINATE_EMERGENCY        = 'emergency'
TERMINATE_NORMAL           = 'normal'
TERMINATE_RULES_INFRACTION = 'rules infraction'
TERMINATE_TIME_FORFEIT     = 'time forfeit'
TERMINATE_UNTERMINATED     = 'unterminated'

# Comments are bounded by ';' to '\n' or '{' to '}'
# Lines starting with '%' are ignored and are used as an extension mechanism
# Strings are bounded by '"' and '"' and quotes inside the strings are escaped with '\"'

# Token types
TOKEN_LINE_COMMENT = 'Line comment'
TOKEN_COMMENT      = 'Comment'
TOKEN_ESCAPED      = 'Escaped data'
TOKEN_PERIOD       = 'Period'
TOKEN_TAG_START    = 'Tag start'
TOKEN_TAG_END      = 'Tag end'
TOKEN_STRING       = 'String'
TOKEN_SYMBOL       = 'Symbol'
TOKEN_RAV_START    = 'RAV start'
TOKEN_RAV_END      = 'RAV end'
TOKEN_XML          = 'XML'
TOKEN_NAG          = 'NAG'

class Error(Exception):
    """PGN exception class"""
    pass

class PGNParser:
    """
    """
    
    STATE_IDLE       = 'IDLE'
    STATE_TAG_NAME   = 'TAG_NAME'
    STATE_TAG_VALUE  = 'TAG_VALUE'
    STATE_TAG_END    = 'TAG_END'
    STATE_MOVETEXT   = 'MOVETEXT'
    STATE_RAV        = 'RAV'
    STATE_XML        = 'XML'
    
    def __init__(self, maxGames = -1):
        expressions = ['\%.*',         # Escaped data
                       ';.*',          # Line comment
                       '\{',           # Comment start
                       '\".*\"',       # String
                       '[a-zA-Z0-9\*\_\+\#\=\:\-\/]+', # Symbol, '/' Not in spec but required from game draw and incomplete
                       '\[',           # Tag start
                       '\]',           # Tag end
                       '\$[0-9]{1,3}', # NAG
                       '\(',           # RAV start
                       '\)',           # RAV end
                       '\<.*\>',       # XML
                       '[.]+']         # Period(s)
        self.regexp = re.compile('|'.join(expressions))

        self.tokens = {';':  TOKEN_LINE_COMMENT,
                       '{':  TOKEN_COMMENT,
                       '[':  TOKEN_TAG_START,
                       ']':  TOKEN_TAG_END,
                       '"':  TOKEN_STRING,
                       '.':  TOKEN_PERIOD,
                       '$':  TOKEN_NAG,
                       '(':  TOKEN_RAV_START,
                       ')':  TOKEN_RAV_END,
                       '<':  TOKEN_XML,
                       '%':  TOKEN_ESCAPED}
        for c in '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ*':
            self.tokens[c] = TOKEN_SYMBOL

        self.games = []
        self.maxGames = maxGames
        self.comment = None

        self.state = self.STATE_IDLE
        self.game = PGNGame() # Game being assembled       
        self.tagName = None # The tag being assembled
        self.tagValue = None
        self.prevTokenIsMoveNumber = False
        self.currentMoveNumber = 0    
        self.ravDepth = 0     # The Recursive Annotation Variation (RAV) stack

    def _parseTokenMovetext(self, tokenType, data):
        """
        """
        if tokenType is TOKEN_SYMBOL:
            # Ignore tokens inside RAV
            if self.ravDepth != 0:
                return

            # See if this is a game terminate
            if results.has_key(data):
                self.games.append(self.game)
                self.game = PGNGame()
                self.prevTokenIsMoveNumber = False
                self.currentMoveNumber = 0    
                self.ravDepth = 0
                self.state = self.STATE_IDLE
            
            # Otherwise it is a move number or a move
            else:
                try:
                    moveNumber = int(data)
                except ValueError:
                    move = PGNMove()
                    move.number = self.currentMoveNumber
                    move.move = data
                    self.game.addMove(move)
                    self.currentMoveNumber += 1
                else:
                    self.prevTokenIsMoveNumber = True
                    expected = (self.currentMoveNumber / 2) + 1
                    if moveNumber != expected:
                        raise Error('Expected move number %i, got %i' % (expected, moveNumber))

        elif tokenType is TOKEN_NAG:
            # Ignore tokens inside RAV
            if self.ravDepth != 0:
                return
            
            move = self.game.getMove(self.currentMoveNumber)
            move.nag = data
            
        elif tokenType is TOKEN_PERIOD:
            # Ignore tokens inside RAV
            if self.ravDepth != 0:
                return           

            if self.prevTokenIsMoveNumber is False:
                raise Error('Unexpected period')

        elif tokenType is TOKEN_RAV_START:
            self.ravDepth += 1
            # FIXME: Check for RAV errors
            return
                
        elif tokenType is TOKEN_RAV_END:
            self.ravDepth -= 1
            # FIXME: Check for RAV errors
            return
               
        else:
            raise Error('Unknown token %s in movetext' % (str(tokenType)))
    
    def parseToken(self, tokenType, data):
        """
        """
        # Ignore all comments at any time
        if tokenType is TOKEN_LINE_COMMENT or tokenType is TOKEN_COMMENT:
            if self.currentMoveNumber > 0:
                move = self.game.getMove(self.currentMoveNumber)
                move.comment = data[1:-1]
            return
       
        if self.state is self.STATE_MOVETEXT:
            self._parseTokenMovetext(tokenType, data)
            
        elif self.state is self.STATE_IDLE:                
            if tokenType is TOKEN_TAG_START:
                self.state = self.STATE_TAG_NAME
                return

            elif tokenType is TOKEN_SYMBOL:
                self.whiteMove = None
                self.prevTokenIsMoveNumber = False
                self.ravDepth = 0
                self.state = self.STATE_MOVETEXT
                self._parseTokenMovetext(tokenType, data)
                
            elif tokenType is TOKEN_ESCAPED:
                pass

            else:
                raise Error('Unexpected token %s' % (str(tokenType)))

        if self.state is self.STATE_TAG_NAME:
            if tokenType is TOKEN_SYMBOL:
                self.tagName = data
                self.state = self.STATE_TAG_VALUE
            else:
                raise Error('Got a %s token, expecting a %s token' % (repr(tokenType), repr(TOKEN_SYMBOL)))

        elif self.state is self.STATE_TAG_VALUE:
            if tokenType is TOKEN_STRING:
                self.tagValue = data[1:-1]
                self.state = self.STATE_TAG_END
            else:
                raise Error('Got a %s token, expecting a %s token' % (repr(tokenType), repr(TOKEN_STRING)))

        elif self.state is self.STATE_TAG_END:
            if tokenType is TOKEN_TAG_END:
                self.game.setTag(self.tagName, self.tagValue)
                self.state = self.STATE_IDLE
            else:
                raise Error('Got a %s token, expecting a %s token' % (repr(tokenType), repr(TOKEN_TAG_END)))

    def parseLine(self, line):
        """Parse a line from a PGN file.
        
        Return an array of tokens extracted from the line.
        """
        while len(line) > 0:
            if self.comment is not None:
                end = line.find('}')
                if end < 0:
                    self.comment += line
                    return True
                else:
                    comment = self.comment + line[:end]
                    self.comment = None
                    self.parseToken(TOKEN_COMMENT, comment)
                    line = line[end+1:]
                continue
            
            for match in self.regexp.finditer(line):
                text = line[match.start():match.end()]
                if text == '{':
                    line = line[match.end():]
                    self.comment = ''
                    break
                else:
                    try:
                        tokenType = self.tokens[text[0]]
                    except KeyError:
                        raise Error("Unknown token %s" % repr(text))                        
                    self.parseToken(tokenType, text)

            if self.comment is None:
                return True
            
    def complete(self):
        if len(self.game.moves) > 0:
            self.games.append(self.game)
   
class PGNMove:
    """
    """
    #
    move       = ''
    
    #
    comment    = ''

    #
    nag        = ''

class PGNGame:
    """
    """

    # The seven tag roster in the required order (REFERENCE)
    _strTags = [TAG_EVENT, TAG_SITE, TAG_DATE, TAG_ROUND, TAG_WHITE, TAG_BLACK, TAG_RESULT]

    def __init__(self):
        # Set the default STR tags
        self.tagsByName = {}
        self.setTag(TAG_EVENT, '?')
        self.setTag(TAG_SITE, '?')
        self.setTag(TAG_DATE, '????.??.??')
        self.setTag(TAG_ROUND, '?')
        self.setTag(TAG_WHITE, '?')
        self.setTag(TAG_BLACK, '?')
        self.setTag(TAG_RESULT, '*')
        self.moves = []
        
    def getLines(self):
        lines = []
        
        # Get the names of the non STR tags
        otherTags = list(set(self.tagsByName).difference(self._strTags))

        # Write seven tag roster and the additional tags
        for name in self._strTags + otherTags:
            value = self.tagsByName[name]
            lines.append('['+ name + ' ' + self._makePGNString(value) + ']')

        lines.append('')
        
        # Insert numbers in-between moves
        tokens = []
        moveNumber = 0
        for m in self.moves:
            if moveNumber % 2 == 0:
                tokens.append('%i.' % (moveNumber / 2 + 1))
            moveNumber += 1
            tokens.append(m.move)
            if m.nag != '':
                tokens.append(m.nag)
            if m.comment != '':
                tokens.append('{' + m.comment + '}')
                
        # Add result token to the end
        tokens.append(self.tagsByName[TAG_RESULT])

        # Print moves keeping the line length to less than 256 characters (PGN requirement)
        line = ''
        for t in tokens:
            if line == '':
                x = t
            else:
                x = ' ' + t
            if len(line) + len(x) >= 80: #>= 256:
                lines.append(line)
                line = t
            else:
                line += x

        lines.append(line)
        return lines
        
    def setTag(self, name, value):
        """Set a PGN tag.
        
        'name' is the name of the tag to set (string).
        'value' is the value to set the tag to (string) or None to delete the tag.
        
        Tag names cannot contain whitespace.
        
        Deleting a tag that does not exist has no effect.
        
        Deleting a STR tag or setting one to an invalid value will raise an Error exception.
        """
        if self._isValidTagName(name) is False:
            raise Error('%s is an invalid tag name' % str(name))

        # If no value delete
        if value is None:
            # If is a STR tag throw an exception
            if self._strTags.has_key(name):
                raise Error('%s is a PGN STR tag and cannot be deleted' % name)
            
            # Delete the tag
            try:
                self._strTags.pop(name)
            except KeyError:
                pass
        
        # Otherwise set the tag to the new value
        else:
            # FIXME: Validate if it is a STR tag
            
            self.tagsByName[name] = value
    
    def getTag(self, name, default = None):
        """Get a PGN tag.
        
        'name' is the name of the tag to get (string).
        'default' is the default value to return if this valid is missing (user-defined).
        
        Return the value of the tag (string) or the default if the tag does not exist.
        """
        try:
            return self.tagsByName[name]
        except KeyError:
            return default
        
    def addMove(self, move):
        self.moves.append(move)

    def getMove(self, moveNumber):
        return self.moves[moveNumber - 1]
    
    def getMoves(self):
        return self.moves

    def __str__(self):
        string = ''
        for tag, value in self.tagsByName.iteritems():
            string += '%s = %s\n' % (tag, value)
        string += '\n'
        
        number = 1
        moves = self.moves
        while len(moves) >= 2:
            string += '%3i. %s %s\n' % (number, moves[0].move, moves[1].move)
            number += 1
            moves = moves[2:]
        if len(moves) > 0:
            string += '%3i. %s\n' % (number, moves[0].move)
            
        return string
    
    # Private methods    
    def _makePGNString(self, string):
        """Make a PGN string.
        
        'string' is the string to convert to a PGN string (string).
        
        All characters are valid and quotes are escaped with '\"'.
        
        Return the string surrounded with quotes. e.g. 'Mike "Dog" Smith' -> '"Mike \"Dog\" Smith"'
        """
        pgnString = string
        pgnString.replace('"', '\\"')
        return '"' + pgnString + '"'    

    def _isValidTagName(self, name):
        """Valid a PGN tag name.
        
        'name' is the tag name to validate (string).
        
        Tags can only contain the characters, a-Z A-Z and _.
        
        Return True if this is a valid tag name otherwise return False.
        """
        if name is None or len(name) == 0:
            return False

        validCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
        for c in name:
            if validCharacters.find(c) < 0:
                return False
        return True

class PGN:
    """
    """

    def __init__(self, fileName = None, maxGames = None):
        """Create a PGN reader/writer.
        
        'fileName' is the file to load the PGN from or None to generate an empty PGN file.
        'maxGames' is the maximum number of games to load from the file or None
                   to load the whole file. (int, Only applicable if a filename is supplied).
        """       
        self.__games = []

        if fileName is not None:
            self.__load(fileName, maxGames)
            
    def addGame(self):
        """Add a new game to the PGN file.
        
        Returns the PGNGame instance to modify"""
        game = PGNGame()
        self.__games.append(game)
        return game
    
    def getGame(self, index):
        """Get a game from the PGN file.
        
        'index' is the game index to get (integer, 0-N).
        
        Return this PGN game or raise an IndexError if no game with this index.
        """
        return self.__games[index]
    
    def save(self, fileName):
        """Save the PGN file.
        
        'fileName' is the name of the file to save to.
        """
        f = file(fileName, 'w')
        # FIXME: Set the newline characters to the correct type?
        
        # Sign it from glChess
        f.write('; PGN saved game generated by glChess\n')
        f.write('; http://glchess.sourceforge.net\n')

        for game in self.__games:
            f.write('\n')
            for line in game.getLines():
                f.write(line + '\n')
            
        f.close()
        
    def __len__(self):
        return len(self.__games)
        
    def __getitem__(self, index):
        return self.__games[index]

    def __getslice__(self, start, end):
        return self.__games[start:end]
    
    # Private methods

    def __load(self, fileName, maxGames = None):
        """
        """
        # Convert the file into PGN tokens
        f = file(fileName, 'r')
        p = PGNParser(maxGames)
        lineNumber = 0
        try:
            for line in f.readlines():
                lineNumber += 1                
                p.parseLine(line)
            p.complete()
        except Error, e:
            raise Error('Error on line %d: %s' % (lineNumber, str(e)))

        # Must be at least one game in the PGN file
        self.__games = p.games
        if len(self.__games) == 0:
            raise Error('Empty PGN file')

        # Tidy up
        f.close()

if __name__ == '__main__':
    import time

    def test(fileName, maxGames = None):
        s = time.time()
        p = PGN(fileName, maxGames)
        print time.time() - s
        number = 1
        games = p[:]
        #for game in games:
        #    print 'Game ' + str(number)
        #    print game
        #    print 
        #    number += 1

    #test('example.pgn')
    #test('rav.pgn')
    #test('wolga-benko.pgn', 3)
    
    #test('wolga-benko.pgn')
    #test('yahoo_chess.pgn')

    #p = PGN('example.pgn')
    #p.save('out.pgn')
