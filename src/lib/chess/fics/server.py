# -*- coding: utf-8 -*-
import socket
import select
import random

import style12
import telnet

class TelnetDecoder(telnet.Decoder):
    def __init__(self, decoder):
        self.decoder = decoder
        telnet.Decoder.__init__(self)

    def onData(self, data):
        self.decoder._processData(data)

    def onInterruptProcess(self):
        self.decoder.connection.abort()
        
class Server:
    
    def __init__(self):
        """
        """
        self.clients = {}
        self.clientsByUserName = {}

        self.adverts = {}
        self.advertNumber = 1
        self.games = {}
        self.gameNumber = 1

    def addAdvert(self, client):
        """
        """
        advert = Advert(client)
        while True:
            number = self.advertNumber
            self.advertNumber += 1
            if self.advertNumber > 999:
                self.advertNumber = 1
            if not self.adverts.has_key(number):
                break;
        advert.number = number
        self.adverts[number] = advert
        client.adverts[number] = advert
        return advert

    def removeAdverts(self, adverts):
        """
        """
        for advert in adverts:
            advert.client.adverts.pop(advert.number)
            self.adverts.pop(advert.number)
        
        notifyLine = '\n<sr>'
        for advert in adverts:
            notifyLine += ' %i' % advert.number
        notifyLine += '\n'
        for client in self.clients.itervalues():
            if client.name is None:
                continue
            client.send(notifyLine)
            client.sendPrompt()

    def addGame(self, whiteClient, blackClient):
        """
        """
        game = Game(whiteClient, blackClient)
        while True:
            number = self.gameNumber
            self.gameNumber += 1
            if self.gameNumber > 999:
                self.gameNumber = 1
            if not self.games.has_key(number):
                break;
        game.number = number
        self.games[number] = game
        return game       

    def reportMove(self, game, move):
        """Report a move in a game.
        
        'game' is the game that the move is in (?)
        'move' is the move that has occurred (style12.Move)
        """
        pass
    
    def addConnection(self, connection):
        """
        """
        client = Client(self, connection)
        self.clients[connection] = client
        client.start()

    def registerIncomingData(self, connection, data):
        """
        """
        client = self.clients[connection]
        client.registerIncomingData(data)
    
    def connectionClosed(self, connection, reason):
        """
        """
        client = self.clients[connection]
        if client.name is not None:
            self.clientsByUserName.pop(client.name)
        self.clients.pop(connection)
    
    def onOutgoingData(self, connection, data):
        """
        """
        pass
    
class Challenge:
    """
    """
    
    def __init__(self, client):
        self.client = client
        
class Game:
    """
    """
    # Properties
    number = -1
    white  = None
    black  = None
    time   = 2
    inc    = 12
    matchType = 'pbu'
    
    # State
    toMove = None
    move   = 1
    
    def __init__(self, whiteClient, blackClient):
        """
        """
        self.white = whiteClient
        self.black = blackClient
        self.toMove = self.white
        
    def genGameLine(self):
        if self.toMove is self.white:
            colour = 'W'
        else:
            colour = 'B'
        if self.white.rating == 0:
            whiteRating = '++++'
        else:
            whiteRating = '%04i' % self.white.rating
        if self.black.rating == 0:
            blackRating = '++++'
        else:
            blackRating = '%04i' % self.black.rating
        return '%3i %s %s %s %s [%s %2i %3i] %s -%s (%2i-%2i) %s: %2i' % \
               (self.number,
                whiteRating, self.white.name.rjust(10),
                blackRating, self.black.name.rjust(10),
                self.matchType.rjust(3), self.time, self.inc,
                '1:36'.rjust(6), '2:33'.rjust(6),
                35, 35,
                colour, self.move)

class Advert:
    """
    """
    number = -1
    client = None
    time = 2
    inc = 12
    rated = False
    colour = None
    variant = 'standard'
    autoStart = True
    checkFormula = False
    minRating = 0
    maxRating = 9999
    
    def __init__(self, client):
        self.client = client
    
    def getVariant(self):
        # Can only modify standard games
        if self.variant != 'standard':
            return self.variant
        
        # Get the name of the game as specified by FICS
        expectedDuration = self.time + (2 * self.inc / 3)
        if expectedDuration < 3:
            return 'lightning'
        elif expectedDuration < 15:
            return 'blitz'
        else:
            return 'standard'
        
    def genSoughtLine(self):
        # 76 ++++ murcon             10   0 unrated blitz      [black]     0-1100 f
        #--- |||| ----------------- ||| ||| ------------------ -------- |||| ||||
        gameProps = '%3i %3i' % (self.time, self.inc)
        if self.rated:
            rating = 'rated'
        else:
            rating = 'unrated'
        gameProps += ' ' + (rating + ' ' + self.getVariant()).ljust(18)
        if self.colour is None:
            gameProps += ' ' * 9
        else:
            gameProps += (' [' + self.colour + ']').ljust(9)
        if self.client.rating == 0:
            rating = '++++'
        else:
            rating = '%04i' % self.client.rating
        line = '%3i %s %s %s %4i-%4i' % (self.number, rating, self.client.name.ljust(17), gameProps, self.minRating, self.maxRating)
        if self.checkFormula:
            line += ' f'
        return line
        
    def genSeekLine(self):
        #murcon (++++) seeking 10 0 unrated blitz [black] f ("play 76" to respond)
        gameProps = '%i %i' % (self.time, self.inc)
        if self.rated:
            gameProps += ' rated'
        else:
            gameProps += ' unrated'
        gameProps += ' ' + self.getVariant()
        if self.colour is not None:
            gameProps += ' [' + self.colour + ']'
        if self.checkFormula:
            self.variant += ' f'
        if self.client.rating == 0:
            rating = '++++'
        else:
            rating = '%04i' % self.client.rating
        return '%s (%s) seeking %s ("play %i" to respond)' % (self.client.name, rating, gameProps, self.number)
    
    def genSeekMessage(self):
        if self.rated:
            rated = 'r'
        else:
            rated = 'u'
        if self.colour is None:
            colour = '?'
        else:
            colour = 'w' # FIXME: B
        if self.autoStart:
            automatic = 't'
        else:
            automatic = 'f'
        if self.checkFormula:
            formulaChecked = 't'
        else:
            formulaChecked = 'f'
        # FIXME: rating flags
        return '<s> %i w=%s ti=%02X rt=%i t=%i i=%i r=%s tp=%s c=%s rr=%i-%i a=%s f=%s' % \
               (self.number, self.client.name, self.client.titles, self.client.rating,
                self.time, self.inc, rated, self.getVariant(),
                colour, self.minRating, self.maxRating, automatic, formulaChecked)

class Client:
    """
    """
    buffer = ''

    name = None
    rating = 0
    
    titles = 0x00
    TITLE_UNREGISTERED               = 0x01
    TITLE_COMPUTER                   = 0x02
    TITLE_GRAND_MASTER               = 0x04
    TITLE_INTERNATIONAL_MASTER       = 0x08
    TITLE_FIDE_MASTER                = 0x10
    TITLE_WOMAN_GRAND_MASTER         = 0x20
    TITLE_WOMAN_INTERNATIONAL_MASTER = 0x40
    TITLE_WOMAN_FIDE_MASTER          = 0x80

    LOGIN_SCREEN = 'MINI-FICS SERVER\n'
    
    STATE_LOGIN         = 'LOGIN'
    STATE_PASSWORD      = 'PASSWORD'
    STATE_NULL_PASSWORD = 'NULL_PASSWORD'
    STATE_POST_LOGIN    = 'POST_LOGIN'
    STATE_MAIN          = 'MAIN'
    STATE_GAME          = 'GAME'
    state = STATE_LOGIN
    
    def __init__(self, server, connection):
        """
        """
        self.server = server
        self.connection = connection
        self.adverts = {}
        self.telnetDecoder = TelnetDecoder(self)
    
    def checkPassword(self, user, password):
        """
        """
        return True
    
    def registerIncomingData(self, data):
        """
        """
        self.telnetDecoder.registerIncomingData(data)

    def _processData(self, data):
        """
        """
        self.buffer += data
        
        while True:
            index = self.buffer.find('\n')
            if index < 0:
                return
            line = self.buffer[:index]
            self.buffer = self.buffer[index + 1:]
            if line[-1] == '\r':
                line = line[:-1]
            self.processLine(line)

    def send(self, data):
        self.server.onOutgoingData(self.connection, data)

    def start(self):
        """
        """
        self.send(self.LOGIN_SCREEN)
        self.setState(self.STATE_LOGIN)
        
    def setState(self, state):
        if state is self.STATE_LOGIN:
            self.send('login: ')
        elif state is self.STATE_PASSWORD:
            self.send('password: ')
        elif state is self.STATE_POST_LOGIN:
            self.send('**** Starting FICS session as %s ****\n' % self.name)
            self.send('<sc>\n')
            for ad in self.server.adverts.itervalues():
                self.send(ad.genSeekMessage() + '\n')
        elif state is self.STATE_MAIN:
            self.sendPrompt()
        self.state = state
        
    def sendPrompt(self):
        self.send('fics% ')

    def generateGuestLogin(self):
        # Get a unique name
        while True:
            name = 'Guest'
            for i in xrange(4):
                name += random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
            if not self.server.clientsByUserName.has_key(name):
                break

        return name

    def processLine(self, line):
        state = self.state
        if state is self.STATE_LOGIN:
            if line == '':
                self.setState(self.STATE_LOGIN)
            elif line == 'guest':
                self.name = self.generateGuestLogin()
                self.send('Press return to enter the server as "%s":\n' % self.name)
                self.setState(self.STATE_NULL_PASSWORD)
            else:
                if line.isalpha():
                    self.name = line
                    self.setState(self.STATE_PASSWORD)
                else:
                    self.send('Sorry, names can only consist of lower and upper case letters.  Try again.\n')
                    self.setState(self.STATE_LOGIN)
            
        elif state is self.STATE_NULL_PASSWORD:
            self.server.clientsByUserName[self.name] = self
            self.setState(self.STATE_POST_LOGIN)
            self.setState(self.STATE_MAIN)
        
        elif state is self.STATE_PASSWORD:
            if self.checkPassword(self.name, line):
                self.server.clientsByUserName[self.name] = self
                self.setState(self.STATE_POST_LOGIN)
                self.setState(self.STATE_MAIN)
            else:
                self.setState(self.STATE_LOGIN)

        elif state is self.STATE_MAIN:
            args = line.split(None, 1)
            if len(args) > 0:
                command = args[0]
                if len(args) == 1:
                    line = ''
                else:
                    line = args[1]
                self.processCommand(command, line)
            self.setState(self.STATE_MAIN)
        
    def processCommand(self, command, line):
        args = line.split()
        if command == 'quit' and len(args) == 0:
            self.quit()

        elif command == 'sought':
            for ad in self.server.adverts.itervalues():
                self.send(ad.genSoughtLine() + '\n')
                 
            if len(self.server.adverts) == 1:
                self.send('1 ad displayed.\n')
            else:
                self.send('%i ads displayed.\n' % len(self.server.adverts))
        
        elif command == 'match' and len(args) == 1:
            user = args[0]
            try:
                client = self.server.clientsByUserName[user]
            except KeyError:
                pass
            else:
                advert = Challenge(self)
                advertLine = '?' # FIXME
                self.send('Issuing: %s.' % advertLine)
                client.send('\n')
                client.send('Challenge: %s.\n' % advertLine)
                client.send('You can "accept" or "decline", or propose different parameters.\n')
                client.sendPrompt()
        
        elif command == 'accept' and len(args) == 0:
            pass
            
        elif command == 'decline' and len(args) == 0:
            pass
        
        elif command == 'seek':
            #Usage: seek [time inc] [rated|unrated] [white|black] [crazyhouse] [suicide]
            #            [wild #] [auto|manual] [formula] [rating-range]
            for arg in args:
                pass
            
            advert = self.server.addAdvert(self)
            
            # Notify all clients
            notifyLine = '\n' + advert.genSeekMessage() + '\n'
            for client in self.server.clients.itervalues():
                if client.name is None:
                    continue
                client.send(notifyLine)
                client.sendPrompt()
                
        elif command == 'play' and len(args) == 1:
            try:
                advert = self.server.adverts[int(args[0])]
            except ValueError:
                user = args[0]
                try:
                    client = self.server.clientsByUserName[user]
                except KeyError:
                    self.send('%s is not logged in.\n' % user)
                    return
                else:
                    advert = None # TODO: use first client.adverts
            except KeyError:
                self.send('That seek is not available.\n')
                return
            else:
                client = advert.client
            
            # Remove this advert
            self.server.removeAdverts([advert])
            
            # Make a game
            game = self.server.addGame(self, client)

        elif command == 'tell' or command == 't':
            (user, text) = line.split(None, 1)
            
            if user.isalpha():
                # TODO: Could also be a channel
                try:
                    client = self.server.clientsByUserName[user]
                except KeyError:
                    self.send('%s is not logged in.\n' % user)
                else:
                    self.send('(told %s)\n' % user)
                    # FIXME: What it (U) ?
                    client.send('\n')
                    client.send('%s(U) tells you: %s\n' % (self.name, text))
            else:
                self.send('%s is not a valid handle.\n' % repr(user))

            self.sendPrompt()
                
        elif command == 'say':
            text = line
        
        else:
            self.send('%s: Command not found.\n' % command)

if __name__ == '__main__':

    class Connection:
        def __init__(self, server, socket):
            self.server = server
            self.socket = socket
            
        def read(self):
            (data, _) = self.socket.recvfrom(65535)
            if len(data) == 0:
                self.abort()
            else:
                print repr(data)
                self.server.registerIncomingData(self, data)

        def quit(self):
            pass
        
        def abort(self):
            self.server.fds.remove(self.socket.fileno())
            self.server.connections.pop(self.socket.fileno())
            self.socket.close()
        
    class S(Server):
        def __init__(self):
            self.connections = {}
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                self.socket.bind(('', 6666))
            except socket.error:
                self.socket.bind(('', 6667))
            self.socket.listen(10)
            self.fds = [self.socket.fileno()]
            Server.__init__(self)
            
        def onOutgoingData(self, connection, data):
            connection.socket.send(data)
        
        def run(self):
            import select
            while True:
                print '!'
                (fds, _, _) = select.select(self.fds, [], [])
                print fds
                for fd in fds:
                    if fd == self.socket.fileno():
                        try:
                            (s, _) = self.socket.accept()
                        except socket.error, e:
                            print e
                        else:
                            self.fds.append(s.fileno())
                            c = Connection(self, s)
                            self.connections[s.fileno()] = c
                            self.addConnection(c)

                    else:
                        c = self.connections[fd]
                        c.read()

    s = S()
    s.run()
