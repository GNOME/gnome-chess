# -*- coding: utf-8 -*-

class StateMachine:
    """
    """
    
    STATE_IDLE = 'IDLE'
    STATE_CONNECTING = 'CONNECTING'
    
    def __init__(self):
        """
        """
        self.options = {}
        self.__queuedCommands = []
        self.buffer = ''
        self.__haveMoves = False
        self.__readyToConfigure = False    
        self.__ready            = False
        self.__inCallback       = False
        self.__queuedCommands   = None
        self.__positionCommand = 'position startpos'
        
    def logText(self, text, style):
        """
        """
        pass
        
    def onOutgoingData(self, data):
        """
        """
        pass

    def onMove(self, move):
        """Called when the AI makes a move.
        
        'move' is the move the AI has decided to make (string).
        """
        print 'UCI move: ' + move
        
    def registerIncomingData(self, data):
        """
        """
        self.__inCallback = True
        self.buffer += data
        while True:
            index = self.buffer.find('\n')
            if index < 0:
                break
            line = self.buffer[:index]
            self.buffer = self.buffer[index + 1:]
            self.parseLine(line)
        self.__inCallback = False
        
        if self.__options is not None and self.__readyToConfigure:
            options = self.__options
            self.__options = None
            self.configure(options)

        # Send queued commands once have OK
        if len(self.__queuedCommands) > 0 and self.__ready:
            commands = self.__queuedCommands
            self.__queuedCommands = []
            for c in commands:
                self.__sendCommand(c)
                
    def __sendCommand(self, command):
        """
        """
        if self.__ready and not self.__inCallback:
            self.onOutgoingData(command + '\n')
        else:
            self.__queuedCommands.append(command)

    def start(self):
        """
        """
        self.onOutgoingData('uci\n')
        
    def startGame(self):
        """
        """
        self.__sendCommand('ucinewgame')
        self.__sendCommand(self.__positionCommand)

    def configure(self, options = []):
        """
        """
        if not self.__readyToConfigure:
            self.__options = options
            return

        for option in options:
            if not hasattr(option, 'name'):
                print 'Ignoring unnamed UCI option'
                continue
            if option.value == '':
                continue
            self.onOutgoingData('setoption ' + option.name + ' value ' + option.value + '\n')
        self.onOutgoingData('isready\n')

    def requestMove(self, whiteTime, blackTime, ownTime):
        """
        """
        # Some AI's don't work unless assigned some time
        # TODO: which ones? I think Glaurung had issues
        if whiteTime == 0:
            whiteTime = 30000
        if blackTime == 0:
            blackTime = 30000
            
        self.__sendCommand('go wtime %d btime %d' % (whiteTime, blackTime))
        
    def undoMove(self):
        """
        """
        self.__sendCommand('stop');
        (self.__positionCommand, _) = self.__positionCommand.rsplit(" ", 1)
        if self.__positionCommand.endswith(' moves'):
            self.__haveMoves = False
            self.__positionCommand = 'position startpos'
        self.__sendCommand(self.__positionCommand)        

    def reportMove(self, move, isSelf):
        """
        """
        if not self.__haveMoves:
            self.__positionCommand += ' moves'
        self.__haveMoves = True
        self.__positionCommand += ' ' + move
        self.__sendCommand(self.__positionCommand)

    def parseLine(self, line):
        """
        """
        words = line.split()
        
        while True:
            if len(words) == 0:
                self.logText(line + '\n', 'input')
                return
            
            style = self.parseCommand(words[0], words[1:])
            if style is not None:
                self.logText(line + '\n', style)
                return

            print 'WARNING: Unknown command: ' + repr(words[0])
            words = words[1:]

    def parseCommand(self, command, args):
        """
        """
        if command == 'id':
            return 'info'
        
        elif command == 'uciok':
            if len(args) != 0:
                print 'WARNING: Arguments on uciok: ' + str(args)
            self.__readyToConfigure = True
            return 'info'
        
        elif command == 'readyok':
            if len(args) != 0:
                print 'WARNING: Arguments on readyok: ' + str(args)
            self.__ready = True
            return 'info'
        
        elif command == 'bestmove':
            if len(args) == 0:
                print 'WARNING: No move with bestmove'
                return 'error'
            else:
                move = args[0]
                self.onMove(move)
                
                # TODO: Check for additional ponder information
                return 'move'
        
        elif command == 'info':
            return 'info'
        
        elif command == 'option':
            return 'info'
        
        return None
