import protocol
import xml.sax.saxutils

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

class Client:

    def __init__(self, feedback):
        self.feedback = feedback
        self.decoder = protocol.Decoder(self)
        self.commands = []
        self.sending = False
        self.games = {}
        self.rooms = {}
        self.tables = {}
        self.players = {}
        self.room = None

    def start(self):
        # Start session
        self.send("<?xml version='1.0' encoding='UTF-8'?>\n<SESSION>\n<LANGUAGE>en_NZ.UTF-8</LANGUAGE>")
        self.sendCommand("<LOGIN TYPE='guest'>\n<NAME>glchess-test</NAME>\n</LOGIN>");
        self.requestGames()
        self.requestRooms()
        
    def loggedIn(self):
        print 'logged in'

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
        self.games[gameId] = game

    def roomAdded(self, roomId, gameId, name, description, nPlayers):
        room = Room()
        room.id = roomId
        try:
            room.game = self.games[gameId]
        except KeyError:
            room.game = None
        room.name = name
        room.description = description
        room.nPlayers = int(nPlayers)
        self.rooms[roomId] = room
        self.feedback.roomAdded(room)

    def roomPlayersUpdate(self, roomId, nPlayers):
        room = self.rooms[roomId]
        room.nPlayers = int(nPlayers)
        self.feedback.roomUpdated(room)

    def tableAdded(self, roomId, tableId, gameId, status, nSeats, description):
        table = Table(int(nSeats))
        table.id = tableId
        table.room = self.rooms[roomId]
        table.game = self.games[gameId]
        table.status = status
        table.description = description
        self.tables[tableId] = table
        self.feedback.tableAdded(table)

    def tableStatusChanged(self, tableId, status):
        table = self.tables[tableId]
        table.status = status
        self.feedback.tableUpdated(table)

    def seatChanged(self, roomId, tableId, seatId, seatType, user):
        table = self.tables[tableId]
        if table.room.id != roomId:
            return
        seat = table.seats[int(seatId)]
        seat.type = seatType
        seat.user = user
        self.feedback.tableUpdated(table)

    def tableRemoved(self, tableId):
        table = self.tables.pop(tableId)
        self.feedback.tableRemoved(table)

    def playerAdded(self, name, playerType, tableId, perms, lag, room, fromRoom):
        player = Player()
        player.name = name
        player.type = playerType
        try:
            player.table = self.tables[tableId]
        except KeyError:
            player.table = None
        player.perms = perms
        player.lag = lag
        player.room = self.rooms[room]
        player.room.nPlayers += 1
        self.players[player.name] = player

        try:
            player.lastRoom = self.rooms[fromRoom]
        except KeyError:
            player.lastRoom = None
        else:
            player.lastRoom.nPlayers -= 1
            self.feedback.roomUpdated(player.lastRoom)

        self.feedback.roomUpdated(player.room)
        self.feedback.playerAdded(player)

    def playerRemoved(self, name, room, toRoom):
        player = self.players.pop(name)
        player.room.nPlayers -= 1
        player.lastRoom = player.room
        try:
            player.room = self.rooms[toRoom]
        except KeyError:
            player.room = None
        else:
            player.room.nPlayers += 1
            self.feedback.roomUpdated(player.room)
        
        self.feedback.roomUpdated(player.lastRoom)
        self.feedback.playerRemoved(player)

    def sendCommand(self, data, acknowledge = True):
        self.commands.append((data, acknowledge))
        if not self.sending:
            self.sendNextCommand()

    def registerIncomingData(self, data):
        self.decoder.feed(data)
        
    def send(self, data):
        self.feedback.onOutgoingData(data)
        
    def sendNextCommand(self):
        self.sending = False
        while len(self.commands) > 0:
            (command, acknowledge) = self.commands[0]
            self.commands = self.commands[1:]

            if command is None:
                pass

            self.send(command)
            self.sending = acknowledge
            if acknowledge:
                return
            
    def requestGames(self):
        self.sendCommand("<LIST TYPE='game' FULL='true'/>")

    def requestRooms(self):
        self.sendCommand("<LIST TYPE='room' FULL='true'/>")

    def requestTables(self):
        self.sendCommand("<LIST TYPE='table'/>")
        
    def requestPlayers(self):
        self.sendCommand("<LIST TYPE='player'/>")

    def joinRoom(self, room):
        if self.room is not None:
            self.room.nPlayers -= 1
            self.feedback.roomUpdated(self.room)

        self.room = room
        self.players = {}
        self.tables = {}
        room.nPlayers = 0
        self.sendCommand("<ENTER ROOM='%s'/>" % room.id)
        self.requestTables()
        self.requestPlayers()
        
        self.feedback.roomJoined(room) # FIXME: wait for the ack

    def joinTable(self, table):
        self.sendCommand("<JOIN TABLE='%s' SPECTATOR='false'/>" % table.id)

    def startTable(self, gameId, description, player):
        # Seat types are 'open', 'bot' or 'reserved' or 'player' (latter two have player name in them)
        command = "<LAUNCH>"
        command += "<TABLE GAME='%s' SEATS='2'>" % gameId
        command += "<DESC>%s</DESC>" % xml.sax.saxutils.escape(description)
        command += "<SEAT NUM='0' TYPE='reserved'>%s</SEAT>" % player
        command += "<SEAT NUM='1' TYPE='open'/>"
        command += "</TABLE>"
        command += "</LAUNCH>"
        self.sendCommand(command)

    def sendChat(self, text):
        self.sendCommand("<CHAT TYPE='normal'>%s</CHAT>" % xml.sax.saxutils.escape(text))

    def onChat(self, chatType, sender, text):
        self.feedback.onChat(chatType, sender, text)
        
    def onJoin(self, tableId, isSpectator):
        print 'Joined table %s' % tableId
