# -*- coding: utf-8 -*-
__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

class CECPProtocol:
    """CECP protocol en/decoder."""
    
    NEWLINE             = '\n'
    MOVE_PREFIXS        = ['My move is: ', 'my move is ', 'move ']
    INVALID_MOVE_PREFIX = 'Illegal move: '
    RESIGN_PREFIX       = 'resign'
    RESIGN_ICS_PREFIX   = 'tellics resign'    
    DRAW_PREFIX         = 'offer draw'

    def __init__(self):
        """
        """
        self.__buffer = '' # Data being accumulated to be parsed
        # Go to simple interface mode
        self.onOutgoingData('xboard\n')
        
    # Methods to extend
    
    def onOutgoingData(self, data):
        """Called when there is data to send to the CECP engine.
        
        'data' is the data to give to the AI (string).
        """
        print 'OUT: ' + repr(data)
    
    def onUnknownLine(self, line):
        """Called when an unknown line is received from the CECP AI.
        
        'line' is the line that has not been decoded (string). There is
               no newline on the end of the string.
        """
        print 'Unknown CECP line: ' + line
    
    def onMove(self, move):
        """Called when the AI makes a move.
        
        'move' is the move the AI has decided to make (string).
        """
        print 'CECP move: ' + move
    
    def onIllegalMove(self, move):
        """Called when the AI rejects a move.
        
        'move' is the move the AI rejected (string).
        """
        print 'CECP illegal move: ' + move
        
    def onResign(self):
        """Called when the AI resigns"""
        print 'CECP AI resigns'
        
    def onDraw(self):
        """Called when the AI requests a draw"""
        print 'CECP AI calls a draw'
        
    def logText(self, text, style):
        print 'LOG: %s' % text
        
    # Public methods
    
    def sendSetSearchDepth(self, searchDepth):
        """Set the search depth for the AI.
        
        'searchDepth' is the number of moves to look ahead (integer).
        """
        # This is the CECP specified method
        self.onOutgoingData('sd %i\n' % int(searchDepth))
        
        # GNUchess uses this instead
        self.onOutgoingData('depth %i\n' % int(searchDepth))
        
    def sendSetPondering(self, aiPonders):
        """Enable/disable AI pondering.
        
        'aiPonders' is a flag to show if the AI thinks during opponent moves (True) or not (False).
        """
        if aiPonders:
            self.onOutgoingData('hard\n')
        else:
            self.onOutgoingData('easy\n')
    
    def sendMove(self, move):
        """Move for the current player.
        
        'move' is the move the current player has made (string).
        """
        self.onOutgoingData(move + '\n')
        
    def sendWait(self):
        """Stop the AI from automatically moving"""
        self.onOutgoingData('force\n')
        
    def sendUndo(self):
        """Undo the last move"""
        self.onOutgoingData('undo\n')
        
    def sendMovePrompt(self):
        """Get the AI to move for the current player"""
        self.onOutgoingData('go\n')
        
    def sendConventionalClock(self, moveCount, base, increment):
        """
        
        'moveCount' ???
        'base' ??? (seconds)
        'increment' ??? (seconds)
        """
        self.onOutgoingData('level %d %d:%02d %d:%02d\n' % (moveCount, base / 60, base % 60, increment / 60, increment % 60))

    def sendQuit(self):
        """Quit the engine"""
        # Send 'quit' starting with a newline in case there are some characters already sent
        self.onOutgoingData('\nquit\n')
    
    def registerIncomingData(self, data):
        """
        """
        self.__buffer += data
        self.__parseData()
        
    # Private methods
        
    def __parseData(self):
        while True:
            index = self.__buffer.find(self.NEWLINE)
            if index < 0:
                return
            
            line = self.__buffer[:index]
            self.__buffer = self.__buffer[index+1:]

            self.__parseLine(line)
    
    def __parseLine(self, line):
        for prefix in self.MOVE_PREFIXS:
            if line.startswith(prefix):
                move = line[len(prefix):]
                self.logText(line + '\n', 'move')
                self.onMove(move.strip())
                return

        if line.startswith(self.INVALID_MOVE_PREFIX):
            self.onIllegalMove(line[len(self.INVALID_MOVE_PREFIX):])
    
        elif line.startswith(self.RESIGN_PREFIX) or line.startswith(self.RESIGN_ICS_PREFIX):
            self.logText(line + '\n', 'move')
            self.onResign()
            return

        elif line.startswith(self.DRAW_PREFIX):
            self.logText(line + '\n', 'move')
            self.onDraw()
            return

        else:
            self.onUnknownLine(line)
            
        self.logText(line + '\n', 'input')

class Connection(CECPProtocol):
    """
    """
    
    def __init__(self):
        """
        """
        # Start protocol
        CECPProtocol.__init__(self)
        
    # Methods to extend
    
    def logText(self, text, style):
        """FIXME: define style
        """
        pass
    
    def onMove(self, move):
        """Called when the AI makes a move.
        
        'move' is the move the AI made (string).
        """
        print 'AI moves: ' + move

    # Public methods
    
    def start(self):
        """
        """
        pass
    
    def startGame(self):
        """
        """
        pass
    
    def configure(self, options = []):
        """
        """
        for option in options:
            self.onOutgoingData(option.value + '\n')

    def requestMove(self, whiteTime, blackTime, ownTime):
        """Request the AI moves for the current player"""
        # Set the clock
        if ownTime > 0:
            self.sendConventionalClock(0, ownTime / 1000, 0)
        
        # Prompt the AI to move
        self.sendMovePrompt()
        
    def undoMove(self):
        """Undo the last move made by this AI"""
        self.sendWait()
        self.sendUndo()

    def reportMove(self, move, isSelf):
        """Report the move the current player has made.
        
        'move' is the move to report (string).
        'isSelf' is a flag to say if the move is the move this AI made (True).
        """
        # Don't report the move we made
        if isSelf:
            return
        
        # Stop the AI from automatically moving
        self.sendWait()

        # Report the move
        self.sendMove(move)

    # Private methods

    def onUnknownLine(self, line):
        """Called by CECPProtocol"""
        pass#print 'Unknown CECP line: ' + line

    def onIllegalMove(self, move):
        """Called by CECPProtocol"""
        print 'CECP illegal move: ' + move
