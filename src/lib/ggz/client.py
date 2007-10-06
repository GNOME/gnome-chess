import protocol
import xml.sax.saxutils

class Channel:
    """
    """    
        
    def logXML(self, text):
        pass
        
    def logBinary(self, data):
        pass
    
    def connect(self, host, port):
        pass
    
    def send(self, data, isBinary = False):
        pass
    
    def close(self):
        pass
    
class ChannelFeedback:
    """
    """
    
    def registerIncomingData(self, data):
        pass

    def onSessionEnded(self):
        pass
    
    def closed(self, errno = 0):
        pass
    
class ClientFeedback:
    
    def setBusy(self):
        """Called when the client is busy (unable to take requests)"""
        pass
    
    def onConnected(self):
        pass

    def onDisconnected(self):
        pass
    
    
    def openChannel(self, feedback):
        """Open a channel to the GGZ server.
        
        'feedback' is the object to notify data received on this channel.
        """
        pass
    
    def getUsername(self):
        """Called when the username is required.
        
        Returns the username to log in with.
        """
        return 'test'
    
    def getPassword(self, username):
        """Called when a password is required.
        
        'username' is the username the password is required for.
        
        Returns the password for this user or None to abort login.
        """
        return None
    
    def onMOTD(self, motd):
        """Called when the message of the day is received.
        
        'motd' is the message received.
        """
        pass
    
    def roomAdded(self, room):
        """Called when a room is added.
        
        'room' the new room.
        """
        pass
    
    def roomUpdated(self, room):
        pass

    def roomJoined(self, room):
        pass
    

    def tableAdded(self, table):
        pass

    def tableUpdated(self, table):
        pass

    def tableRemoved(self, table):
        pass
    

    def playerAdded(self, player):
        pass

    def playerRemoved(self, player):
        pass
    
    
    def onChat(self, chatType, sender, text):
        pass

class Game:
    id = ''
    
    name = ''
    version = ''
    
    protocol_engine = ''
    protocol_version = ''
    
    nPlayers = 0
    
    author = ''
    url = ''

class Room:
    id = ''
    
    game = None
    
    nPlayers = 0

class Table:
    id = ''
    
    room = ''
    
    game = None
    
    status = ''
    
    description = ''
    
    def __init__(self, nSeats):
        self.seats = []
        for i in xrange(nSeats):
            seat = Seat()
            self.seats.append(seat)

class Seat:
    type = ''
    
    user = ''

class Player:
    name = ''
    
    type = ''
    
    table = None
    
    perms = 0
    
    lag = 0
    
    room = None
    lastRoom = None
    
class MainChannel(ChannelFeedback, protocol.ParserFeedback):
    def __init__(self, client):
        self.client = client
        self.decoder = protocol.Decoder(self)

    def registerIncomingData(self, data):
        self.controller.logXML(data)
        while len(data) > 0:
            data = self.decoder.feed(data)

    def send(self, data, isBinary = False):
        self.controller.send(data, isBinary)

    def onConnected(self):
        assert(self.client.state is self.client.STATE_DISCONNECTED)
        self.client.feedback.onConnected()
        self.client.setState(self.client.STATE_START_SESSION)
        self.send("<?xml version='1.0' encoding='UTF-8'?>\n")
        self.send("<SESSION>\n")
        self.send("<LANGUAGE>en_NZ.UTF-8</LANGUAGE>\n")
        self.client.username = self.client.feedback.getUsername()
        password = self.client.feedback.getPassword(self.client.username)
        if password:
            self.client._login(self.client.username, password)
        else:
            self.client._loginGuest(self.client.username)
        
    def onResult(self, action, code):
        if action == 'login':
            if code == 'ok':
                self.client.setState(self.client.STATE_LIST_GAMES)
            else:
                if code == 'usr lookup':
                    self.client.setState(self.client.STATE_START_SESSION)
                    password = self.client.feedback.getPassword(self.client.username)
                    if password is not None:
                        self.client._login(self.client.username, password)
                        return
                    print 'Failed to login: Require password'

                elif code == 'already logged in':
                    print 'Failed to login: Already logged in'

                else:
                    print 'Failed to login: %s' % code
                    
                self.client.setState(self.client.STATE_DISCONNECTED)

        elif action == 'enter':
            if code != 'ok':
                print 'Failed to enter room'
                self.client.setState(self.client.STATE_READY)
                return
            
            if self.client.room is not None:
                self.client.room.nPlayers -= 1
                self.client.feedback.roomUpdated(self.client.room)
                
            room = self.client.enteringRoom

            self.client.room = room
            self.client.players = {}
            self.client.tables = {}
            room.nPlayers = 0
            self.client.setState(self.client.STATE_LIST_TABLES)

        elif action == 'list':
            if self.client.state is self.client.STATE_LIST_GAMES:
                self.client.setState(self.client.STATE_LIST_ROOMS)
                
            elif self.client.state is self.client.STATE_LIST_ROOMS:
                for room in self.client.rooms.itervalues():
                    if room.game is None:
                        break
                # FIXME: Check have valid room, otherwise go to room 0
                
                self.client.setState(self.client.STATE_ENTERING_ROOM)
                self.client.enteringRoom = room
                self.send("<ENTER ROOM='%s'/>\n" % room.id)
                
            elif self.client.state is self.client.STATE_LIST_TABLES:
                self.client.setState(self.client.STATE_LIST_PLAYERS)
                
            elif self.client.state is self.client.STATE_LIST_PLAYERS:
                self.client.setState(self.client.STATE_READY)
                self.client.feedback.roomEntered(self.client.enteringRoom)

        elif action == 'chat':
            pass# FIXME: could be AT_TABLE self.client.setState(self.client.STATE_READY)

        elif action == 'launch':
            self.client.setState(self.client.STATE_READY)
            
        elif action == 'join':
            if code == 'ok':
                self.client.setState(self.client.STATE_AT_TABLE)
            elif code == 'table full':
                print 'Failed to join table: table full'
                self.client.setState(self.client.STATE_READY)
            else:
                print 'Unknown join result: %s' % action
                
        elif action == 'leave':
            if code == 'ok':
                self.client.setState(self.client.STATE_READY)
                pass # TODO
            else:
                print 'Unknown leave result: %s' % action

        else:
            print 'Unknown result: %s %s' % (action, code)

    def onMOTD(self, motd):
        self.client.feedback.onMOTD(motd)

    def onChat(self, chatType, sender, text):
        self.client.feedback.onChat(chatType, sender, text)
        
    def onJoin(self, tableId, isSpectator):
        self.client.setState(self.client.STATE_AT_TABLE)
        table = self.client.tables[tableId]
        g = self.client.feedback.onJoin(table, isSpectator, self.client.channel)
        self.client.channel.setGame(g)
        
    def onLeave(self, reason):
        self.client.feedback.onLeave(reason)
        
    def gameAdded(self, gameId, name, version, author, url, numPlayers, protocol_engine, protocol_version):
        game = Game()
        game.id = gameId
        game.name = name
        game.version = version
        game.author = author
        game.url = url
        game.numPlayers = numPlayers # FIXME: Make min/max (e.g. can be '1..3')
        game.protocol_engine = protocol_engine
        game.protocol_version = protocol_version
        self.client.games[gameId] = game

    def roomAdded(self, roomId, gameId, name, description, nPlayers):
        room = Room()
        room.id = roomId
        try:
            room.game = self.client.games[gameId]
        except KeyError:
            room.game = None
        room.name = name
        room.description = description
        room.nPlayers = int(nPlayers)
        self.client.rooms[roomId] = room
        self.client.feedback.roomAdded(room)

    def roomPlayersUpdate(self, roomId, nPlayers):
        room = self.client.rooms[roomId]
        room.nPlayers = int(nPlayers)
        self.client.feedback.roomUpdated(room)

    def tableAdded(self, roomId, tableId, gameId, status, nSeats, description):
        table = Table(int(nSeats))
        table.id = tableId
        table.room = self.client.rooms[roomId]
        table.game = self.client.games[gameId]
        table.status = status
        table.description = description
        self.client.tables[tableId] = table
        self.client.feedback.tableAdded(table)

    def tableStatusChanged(self, tableId, status):
        table = self.client.tables[tableId]
        table.status = status
        self.client.feedback.tableUpdated(table)

    def seatChanged(self, roomId, tableId, seatId, seatType, user):
        table = self.client.tables[tableId]
        if table.room.id != roomId:
            return
        seat = table.seats[int(seatId)]
        seat.type = seatType
        seat.user = user
        self.client.feedback.tableUpdated(table)

    def tableRemoved(self, tableId):
        table = self.client.tables.pop(tableId)
        self.client.feedback.tableRemoved(table)
        
    def onPlayerList(self, room, players):
        self.client.players = {}
        r = self.client.rooms[room]
        for p in players:
            player = Player()
            player.name = p.name
            player.type = p.type
            try:
                player.table = self.client.tables[p.table]
            except KeyError:
                player.table = None
            player.perms = p.perms
            player.lag = p.lag
            player.room = r
            self.client.players[player.name] = player

        r.nPlayers = len(players)
        self.client.feedback.roomUpdated(r)

    def playerAdded(self, name, playerType, tableId, perms, lag, room, fromRoom):
        player = Player()
        player.name = name
        player.type = playerType
        try:
            player.table = self.client.tables[tableId]
        except KeyError:
            player.table = None
        player.perms = perms
        player.lag = lag
        player.room = self.client.rooms[room]
        player.room.nPlayers += 1
        self.client.players[player.name] = player

        try:
            player.lastRoom = self.client.rooms[fromRoom]
        except KeyError:
            player.lastRoom = None
        else:
            player.lastRoom.nPlayers -= 1
            self.client.feedback.roomUpdated(player.lastRoom)

        self.client.feedback.roomUpdated(player.room)
        self.client.feedback.playerAdded(player)

    def playerRemoved(self, name, room, toRoom):
        player = self.client.players.pop(name)
        player.room.nPlayers -= 1
        player.lastRoom = player.room
        try:
            player.room = self.client.rooms[toRoom]
        except KeyError:
            player.room = None
        else:
            player.room.nPlayers += 1
            self.client.feedback.roomUpdated(player.room)
        
        self.client.feedback.roomUpdated(player.lastRoom)
        self.client.feedback.playerRemoved(player)
            
    def closed(self, errno = 0):
        print 'SEVERE: GGZ connection closed: error %d' % errno
        self.client.setState(self.client.STATE_DISCONNECTED)
        
class GameChannel(ChannelFeedback, protocol.ParserFeedback):
    
    def __init__(self, client, command):
        self.client = client
        self.command = command
        self.inSession = True
        self.decoder = protocol.Decoder(self)
        self.buffer = ''
        self.game = None
        
    def setGame(self, game):
        self.game = game
        if len(self.buffer) > 0:
            self.game.registerIncomingData(self.buffer)
        self.buffer = ''

    def registerIncomingData(self, data):
        while self.inSession and len(data) > 0:
            remainder = self.decoder.feed(data)
            self.controller.logXML(data[:len(data) - len(remainder)])
            data = remainder

        if len(data) == 0:
            return
        
        self.controller.logBinary(data)

        if self.game is None:
            self.buffer += data
        else:
            self.game.registerIncomingData(data)

    def onDisconnected(self):
        print '!'

    def send(self, data, isBinary = False):
        self.controller.send(data, isBinary)

    def onConnected(self):
        self.send("<?xml version='1.0' encoding='UTF-8'?>\n")
        self.send("<SESSION>\n")
        self.send("<LANGUAGE>en_NZ.UTF-8</LANGUAGE>\n")
        self.send("<CHANNEL ID='%s' /></SESSION>\n" % self.client.username)
        
    def onSessionEnded(self):
        self.inSession = False
        self.client.mainChannel.send(self.command)

    def closed(self):
        print 'SEVERE: GGZ channel closed'

class Client:
    
    STATE_DISCONNECTED        = 'DISCONNECTED'
    STATE_START_SESSION       = 'START_SESSION'
    STATE_LOGIN               = 'LOGIN'
    STATE_LIST_GAMES          = 'LIST_GAMES'
    STATE_LIST_ROOMS          = 'LIST_ROOMS'
    STATE_READY               = 'READY'
    STATE_JOIN_TABLE_CHANNEL  = 'JOIN_TABLE_CHANNEL'
    STATE_JOIN_TABLE          = 'JOIN_TABLE'
    STATE_START_TABLE_CHANNEL = 'START_TABLE_CHANNEL'
    STATE_START_TABLE         = 'START_TABLE'
    STATE_AT_TABLE            = 'AT_TABLE'
    STATE_LEAVE_TABLE         = 'LEAVE_TABLE'
    STATE_ENTERING_ROOM       = 'ENTERING_ROOM'
    STATE_LIST_TABLES         = 'LIST_TABLES'
    STATE_LIST_PLAYERS        = 'LIST_PLAYERS'

    def __init__(self, feedback):
        self.feedback = feedback
        self.commands = []
        self.sending = False
        self.games = {}
        self.rooms = {}
        self.tables = {}
        self.players = {}
        self.room = None
        self.state = self.STATE_DISCONNECTED
        
    def isReady(self):
        """Check if ready for new requests.
        
        Returns True if can make a new request.
        """
        return self.state is self.STATE_READY

    def close(self):
        self.setState(self.STATE_DISCONNECTED)
        
    def isBusy(self):
        return not (self.state is self.STATE_READY or self.state is self.STATE_AT_TABLE or self.state is self.STATE_DISCONNECTED)

    def setState(self, state):
        print 'Changing state from %s to %s' % (self.state, state)
        self.state = state

        self.feedback.setBusy(self.isBusy())
        
        if state is self.STATE_LIST_GAMES:
            self.mainChannel.send("<LIST TYPE='game' FULL='true'/>\n")
        elif state is self.STATE_LIST_ROOMS:
            self.mainChannel.send("<LIST TYPE='room' FULL='true'/>\n")
        elif state is self.STATE_LIST_TABLES:
            self.mainChannel.send("<LIST TYPE='table'/>\n")
        elif state is self.STATE_LIST_PLAYERS:
            self.mainChannel.send("<LIST TYPE='player'/>\n")
        elif state is self.STATE_DISCONNECTED:
            self.feedback.onDisconnected()
            self.mainChannel.controller.close()

    def start(self):
        assert(self.state is self.STATE_DISCONNECTED)
        self.mainChannel = MainChannel(self)
        self.mainChannel.controller = self.feedback.openChannel(self.mainChannel)
        
    def _login(self, username, password):
        assert(self.state is self.STATE_START_SESSION)
        self.setState(self.STATE_LOGIN)
        username = xml.sax.saxutils.escape(username)
        password = xml.sax.saxutils.escape(password)
        self.mainChannel.send("<LOGIN TYPE='normal'><NAME>%s</NAME><PASSWORD>%s</PASSWORD></LOGIN>\n" % (username, password));
        
    def _loginGuest(self, username):
        assert(self.state is self.STATE_START_SESSION)
        self.setState(self.STATE_LOGIN)
        username = xml.sax.saxutils.escape(username)
        self.mainChannel.send("<LOGIN TYPE='guest'><NAME>%s</NAME></LOGIN>\n" % username);
        
    def _loginNew(self, username, password, email):
        assert(self.state is self.STATE_START_SESSION)
        self.setState(self.STATE_LOGIN)
        username = xml.sax.saxutils.escape(username)
        password = xml.sax.saxutils.escape(password)
        email = xml.sax.saxutils.escape(email)
        self.mainChannel.send("<LOGIN TYPE='first'><NAME>%s</NAME><PASSWORD>%s</PASSWORD><EMAIL>%s</EMAIL></LOGIN>\n" % (username, password, email));
        
    def enterRoom(self, room):
        if self.state is self.STATE_AT_TABLE:
            print 'At table'
            return
        else:
            assert(self.state is self.STATE_READY)
        self.setState(self.STATE_ENTERING_ROOM)
        self.enteringRoom = room
        self.mainChannel.send("<ENTER ROOM='%s'/>\n" % room.id)
        
    def startTable(self, gameId, description, player):
        if self.state is not self.STATE_READY:
            print 'Unable to start table'
            return
        self.setState(self.STATE_START_TABLE)
        
        # Seat types are 'open', 'bot' or 'reserved' or 'player' (latter two have player name in them)
        command = "<LAUNCH>\n"
        command += "<TABLE GAME='%s' SEATS='2'>\n" % gameId
        command += "<DESC>%s</DESC>\n" % xml.sax.saxutils.escape(description)
        command += "<SEAT NUM='0' TYPE='reserved'>%s</SEAT>\n" % player
        command += "<SEAT NUM='1' TYPE='open'/>\n"
        command += "</TABLE>\n"
        command += "</LAUNCH>\n"
        
        self.channel = GameChannel(self, command)
        self.channel.controller = self.feedback.openChannel(self.channel)
        
    def joinTable(self, table):
        if self.state is self.STATE_AT_TABLE:
            print 'Already at table'
            return
        
        assert(self.state is self.STATE_READY)
        self.setState(self.STATE_JOIN_TABLE)
        
        command = "<JOIN TABLE='%s' SPECTATOR='false'/>\n" % table.id
        self.channel = GameChannel(self, command)
        self.channel.controller = self.feedback.openChannel(self.channel)
        
    def leaveTable(self):
        assert(self.state is self.STATE_AT_TABLE)
        self.setState(self.STATE_LEAVE_TABLE)
        self.mainChannel.send("<LEAVE FORCE='true'/>\n")
        
    def sendChat(self, text):
        self.mainChannel.send("<CHAT TYPE='normal'>%s</CHAT>\n" % xml.sax.saxutils.escape(text))
