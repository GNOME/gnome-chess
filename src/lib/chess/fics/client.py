import re
import socket
import select

import style12
import telnet

PROMPT          = 'fics% '
PROMPT_LOGIN    = 'login: '

class Player:
    pass

class Game:
    pass

class Encoder:
    """
    """

class TelnetDecoder(telnet.Decoder):
    def __init__(self, decoder):
        self.decoder = decoder
        telnet.Decoder.__init__(self)

    def onData(self, data):
        self.decoder._processData(data)
        
    def onEndSubnegotiation(self):
        print 'onEndSubnegotiation()'
        
    def onNoOp(self):
        print 'onNoOp()'
    
    def onDataMark(self):
        print 'onDataMark()'
        
    def onBreak(self):
        print 'onBreak()'
        
    def onInterruptProcess(self):
        print 'onInterruptProcess()'
        
    def onAbortOutput(self):
        print 'onAbortOutput()'
        
    def onAreYouThere(self):
        print 'onAreYouThere()'
        
    def onEraseCharacter(self):
        print 'onEraseCharacter()'
        
    def onEraseLine(self):
        print 'onEraseLine()'
        
    def onGoAhead(self):
        print 'onGoAhead()'
        
    def onStartSubnegotiation(self):
        print 'onStartSubnegotiation()'
    
    def onWill(self, option):
        print 'onWill(%i)' % option
    
    def onWont(self, option):
        print 'onWont(%i)' % option
    
    def onDo(self, option):
        print 'onDo(%i)' % option
        
    def onDont(self, option):
        print 'onDont(%i)' % option
    
    def onUnknownCommand(self, command):
        print 'onUnknownCommand(%i)' % command
    
class Decoder:
    """
    """
    
    buffer = ''
    
    longChat = None
    
    def __init__(self):
        """
        """
        self.telnetDecoder = TelnetDecoder(self)
        
        # Yuck, regular expression is just horrible. I plan to replace this with something readable
        # (that compiles to regexp if regexp is faster)
        
        #Press return to enter the server as "GuestVRDG":
        self.nameAssignPattern = re.compile('Press return to enter the server as "(\S+)":')
                
        #jibbjibb(U)(53): i like cheese
        self.chatPattern = re.compile('^(\S+)[(](\d+)[)]: (.*)$')
        #GuestTLNX(U) tells you: hello!
        self.tellPattern = re.compile('^(\S+)[(](\S+)[)] tells you: (.*)$')
        #'GuestTLNX(U)[26] says: hello'
        self.sayPattern = re.compile('^(\S+)[(](\S+)[)][[](\d+)[]] says: (.*)$')

        #Challenge: GuestKWWN (----) GuestDRJK (----) unrated blitz 2 12.
        self.challengePattern = re.compile('Challenge: (\S+) [(](\S{4})[)] \S+ [(]\S{4}[)] (\w+) (\w+) (\d+) (\d+)[.]$')
        
        # 19  716 milkhope            5  14 unrated blitz                  0-9999 mf
        # 41 1812 CrazyBeukiBot(C)    2  12 unrated blitz                  0-9999 
        # 50 1190 rauschdesign       10   0 unrated blitz      [white]     0-9999 f
        # 70 1157 stshot             12   1 unrated blitz                  0-1300
        self.seekPattern = re.compile('^\s*(\d+)\s+(\S{4}) (\S+)\s+(\d+)\s+(\d+) (\S+) (\S+)\s+(\S*)\s+(\d+)-\s*(\d+)\s*(\S*)$')
        
        #1 ad displayed.
        #9 ads displayed.
        self.endSeekPattern = re.compile('^(\d+) ads? displayed.$')
        
        #GuestJXJT (++++) seeking 0 1 unrated lightning ("play 15" to respond)
        self.announcePattern = re.compile('^(\S+) [(](\S{4})[)] seeking (\d+) (\d+) (\w+) (\w+)(.*) [(]"play (\d+)" to respond[)]$')

        #{Game 109 (GuestKSBS vs. GuestXKQX) Creating unrated blitz match.}
        #{Game 109 (GuestKSBS vs. GuestXKQX) GuestXKQX forfeits by disconnection} 1-0
        #{Game 109 (GuestXKQX vs. GuestKSBS) GuestKSBS resigns} 1-0
        self.gameResultPattern = re.compile('^{Game (\d+) [(](\S+) vs. (\S+)[)] (.+)}\s*(.*)$')

        # 1 (Exam.    0 Kupreichik     0 talpa     ) [ uu  0   0] W: 22
        # 2 2274 OldManII    ++++ Peshkin    [ bu  2  12]   2:34 -  1:47 (39-39) B:  3
        self.exampleGamePattern = re.compile('\s*(\d+) [(]Exam[.] (\S{4}) (\S+)\s+(\S{4}) (\S+)\s+ [)] [[]\s*(\S+)\s+(\d+)\s+(\d+)[]] ([WB]):\s+(\d+)$')
        self.gamePattern = re.compile('\s*(\d+) (\S{4}) (\S+)\s+(\S{4}) (\S+)\s+[[]\s*(\S+)\s+(\d+)\s+(\d+)[]]\s+(\d+):(\d+) -\s+(\d+):(\d+) [(](\d+)-(\d+)[)] ([WB]):\s+(\d+)$')
        
        #GuestDRJK, whom you were challenging, has departed.
        #Challenge to GuestDRJK withdrawn.
        
        self.patterns = [self.announcePattern, self.nameAssignPattern,
                         self.chatPattern, self.tellPattern, self.sayPattern,
                         self.challengePattern, self.gamePattern, self.exampleGamePattern, self.gameResultPattern,
                         self.seekPattern, self.endSeekPattern]
                         
    def onUnknownLine(self, text):
        """
        """
        pass

    def onLogin(self):
        """
        """
        pass
    
    def onPrompt(self):
        """
        """
        pass
    
    def onNameAssign(self, name):
        """
        """
        pass
    
    def onSeekClear(self):
        pass
    def onSeekAdd(self, number, game, player):
        pass
    def onSeekRemove(self, numbers):
        pass
    
    def onAnnounce(self, number, game, player):
        """
        """
        pass

    def onEndSeek(self, nSeeks):
        """
        """
        pass
    
    def onDynamicAnnounce(self, number, game, player):
        """
        """
        pass
    
    def onChallenge(self, game, player):
        """
        """
        pass
    
    def onGame(self, game, white, black):
        """
        """
        pass
    
    def onGameResult(self, game, white, black, text):
        """
        """
        pass
                
    def onChat(self, channel, playerName, text):
        """
        """
        pass

    def onMove(self, move):
        """
        """
        pass
    
    def parseLine(self, line):
        """
        """
        # Join continuing chat messages
        if self.longChat != None:
            # Remove leading space ('\   text')
            while line.startswith('\\'):
                line = line[1:]
            while line.startswith(' '):
                line = line[1:]
            self.longChat += line
            
            # Continues on the next line too
            if line[-1] == ' ':
                return (None, None)
            
            text = self.longChat
            self.longChat = None
            return (self.onChat, (self.longChatOptions[0], self.longChatOptions[1], text))
        
        # Look for lines
        for pattern in self.patterns:
            result = pattern.findall(line)
            if len(result) != 0:
                # Game in progress
                if pattern is self.gamePattern:
                    white = Player()
                    black = Player()
                    game = Game()
                    (game.number, white.rating, white.name, black.rating, black.name,
                     game.options, game.a, game.b, whiteMin, whiteSec,
                     blackMin, blackSec,
                     white.strength, black.strength,
                     game.colour, game.moveNumber) = result[0]
                    game.isExample = False
                    white.time = int(whiteMin) * 60 + int(whiteSec)
                    black.time = int(blackMin) * 60 + int(blackSec)
                    return (self.onGame, (game, white, black))
                
                elif pattern is self.exampleGamePattern:
                    white = Player()
                    black = Player()
                    game = Game()
                    (game.number, white.rating, white.name, black.rating, black.name,
                     game.options, game.a, game.b,
                     game.colour, game.moveNumber) = result[0]
                    game.isExample = True
                    return (self.onGame, (game, white, black))
                
                elif pattern is self.nameAssignPattern:
                    name = result
                    return (self.onNameAssign, (name, ))
                
                # Requested seek
                elif pattern is self.seekPattern:
                    player = Player()
                    game = Game()
                    (number,
                     player.rating, player.name,
                     game.a, game.b, game.rating, game.type, game.colour, game.minRating, game.maxRating, game.options) = result[0]
                    return (self.onAnnounce, (number, game, player))
                elif pattern is self.endSeekPattern:
                    (nSeeks, ) = result
                    return (self.onEndSeek, (int(nSeeks), ))
                # Dynamic seek
                if pattern is self.announcePattern:
                    player = Player()
                    game = Game()
                    (player.name, player.rating, game.a, game.b, game.rating, game.type, game.options, number) = result[0]
                    return (self.onDynamicAnnounce, (number, game, player))
                
                # Explicit challenge
                elif pattern is self.challengePattern:
                    player = Player()
                    game = Game()
                    (player.name, player.rating, game.rating, game.type, game.a, game.b) = result[0]
                    return (self.onChallenge, (game, player))
                
                # Game result
                elif pattern is self.gameResultPattern:
                    white = Player()
                    black = Player()
                    game = Game()
                    (game.number, white.name, black.name, text, game.result) = result[0]
                    if game.result == '':
                        game.result = '*'
                    return (self.onGameResult, (game, white, black, text))
                
                elif pattern is self.chatPattern:
                    (playerName, channel, text) = result[0]
                    if text[-1] == ' ':
                        self.longChat = text
                        self.longChatOptions = (channel, playerName)
                        return (None, None)
                    else:
                        return (self.onChat, (channel, playerName, text))
                
                elif pattern is self.tellPattern:
                    (playerName, rating, text) = result[0]
                    if text[-1] == ' ':
                        self.longChat = text
                        self.longChatOptions = ('', playerName)
                        return (None, None)
                    else:
                        return (self.onChat, ('', playerName, text))

                elif pattern is self.sayPattern:
                    (playerName, rating, game, text) = result[0]
                    if text[-1] == ' ':
                        self.longChat = text
                        self.longChatOptions = ('', playerName)
                        return (None, None)
                    else:
                        return (self.onChat, ('', playerName, text))

        # Game move
        if line.startswith('<12> '):
            try:
                move = style12.decode(line)
            except ValueError, e:
                print 'Invalid move: %s (%s)' % (line, str(e))
            else:
                return (self.onMove, (move,))

        elif line.startswith('<s> '):
            words = line.split()
            player = Player()
            game = Game()
            try:
                number = int(words[1])
            except (IndexError, ValueError):
                return (self.onUnknownLine, (line,))
            
            for word in words[2:]:
                try:
                    (name, value) = word.split('=', 1)
                except ValueError:
                    return (self.onUnknownLine, (line,))
                
                # FIXME: Accept errors
                if name == 'w':
                    player.name = value
                elif name == 'ti':
                    pass
                elif name == 'rt':
                    while not value[-1].isdigit():
                        value = value[:-1]
                    player.rating = int(value)
                elif name == 't':
                    game.time = int(value)
                elif name == 'i':
                    game.inc = int(value)
                elif name == 'r':
                    game.isRated = value != '0'
                elif name == 'tp':
                    game.type = value
                elif name == 'c':
                    game.colour = value
                elif name == 'rr':
                    (minRating, maxRating) = value.split('-', 1)
                    game.minRating = int(minRating)
                    game.maxRating = int(maxRating)
                elif name == 'a':
                    game.isAutomatic = value != '0'
                elif name == 'f':
                    game.formulaCheked = value != '0'

            return (self.onSeekAdd, (number, game, player))
            
        elif line.startswith('<sr> '):
            adverts = []
            for word in line.split()[1:]:
                try:
                    adverts.append(int(word))
                except ValueError:
                    return (self.onUnknownLine, (line,))

            return (self.onSeekRemove, (adverts,))

        elif line.startswith('<sc>'):
            return (self.onSeekClear, ())

        return (self.onUnknownLine, (line,))
    
    def parsePrompt(self, line):
        """
        """
        if line == PROMPT_LOGIN:
            return (self.onLogin, ())
        elif line == PROMPT:
            return (self.onPrompt, ())
        return (None, None)
    
    def registerIncomingData(self, data):
        """
        """
        self.telnetDecoder.registerIncomingData(data)
        
    def _processData(self, data):
        """
        """
        self.buffer += data
        
        callbacks = []
        while True:
            index = self.buffer.find('\n\r')
            if index < 0:
                break
            
            line = self.buffer[:index]
            self.buffer = self.buffer[index+2:]
            
            # Strip pesky prompt off the front
            if line.startswith(PROMPT):
                line = line[len(PROMPT):]
                callbacks.append((self.onPrompt, ()))
                if len(line) == 0:
                    continue

            (callback, data) = self.parseLine(line)
            if callback is not None:
                callbacks.append((callback, data))

        (callback, data) = self.parsePrompt(self.buffer)
        if callback is not None:
            callbacks.append((callback, data))
            
        for (callback, data) in callbacks:
            callback(*data)

if __name__ == '__main__':
    class P(Decoder):
        
        sentStyle = False
    
        def __init__(self):
            Decoder.__init__(self)
            self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.s.connect(('freechess.org', 23))
        
        def send(self, data):
            self.s.send(data)
            
        def onLogin(self):
            self.send('guest\n')
            
        def onPrompt(self):
            if not self.sentStyle:
                self.send('style 12\n')
                #self.send('set open 0\n') # Don't support being challenged yet
                self.send('games\n')
                self.send('sought\n')
                self.sentStyle = True
                
        def onNameAssign(self, name):
            print 'Assigned name: %s' % repr(name)
            self.send('\n')
            
        def onAnnounce(self, number, game, player):
            print 'ANNOUNCE: PLAYER=%s (%s)' % (player.name, number)
            
        def onDynamicAnnounce(self, number, game, player):
            print 'ANNOUNCE*: PLAYER=%s (%s)' % (player.name, number)
            
        def onChallenge(self, game, player):
            print 'CHALLENGE: PLAYER=' + player.name
            self.send('accept\n')
        
        def onGame(self, game, white, black):
            print 'GAME: #%s, %s vs %s' % (game.number, white.name, black.name)
                
        def onGameResult(self, game, white, black, text):
            print 'GAME_RESULT: #%s, %s (%s)' % (game.number, game.result, text)

        def onChat(self, channel, playerName, text):
            print 'CHAT: channel=%s name=%s: %s' % (channel, playerName, text)
        
        def onMove(self, move):
            print 'MOVE: ' + str(move)

        def run(self):
            while True:
                (data, address) = self.s.recvfrom(65535)
                self.registerIncomingData(data)

    p = P()
    p.run()
    