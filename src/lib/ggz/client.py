# -*- coding: utf-8 -*-
import os
import protocol
import xml.sax.saxutils
import gettext

_ = gettext.gettext

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
    
    def setBusy(self, isBusy):
        """Called when the client is busy (unable to take requests)"""
        pass
    
    def onConnected(self):
        pass

    def onDisconnected(self, reason):
        pass
    
    def openChannel(self, feedback):
        """Open a channel to the GGZ server.
        
        'feedback' is the object to notify data received on this channel.
        """
        pass
    
    def getLogin(self):
        """Called when the login credentials are required.
        
        Returns the username and password to log in with.
        If the password is None then log in as guest.
        """
        return ('test', None)
    
    def getPassword(self, username):
        """Called when a password is required.
        
        'username' is the username the password is required for.
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
        (self.client.username, self.client.password) = self.client.feedback.getLogin()
        if self.client.password is None:
            self.client._loginGuest(self.client.username)
        else:
            self.client._login(self.client.username, self.client.password)
        
    def onResult(self, action, code):
        if action == 'login':
            if code == 'ok':
                self.client.setState(self.client.STATE_LIST_GAMES)
            else:
                if code == 'usr lookup':
                    # Translators: GGZ disconnection error when the supplied password is incorrect
                    self.client.close(_('Incorrect password'))
                    #FIXME: Prompt for a password
                    #self.client.setState(self.client.STATE_GET_PASSWORD)

                elif code == 'already logged in':
                    # Translators: GGZ disconnection error when the selected account is already in use
                    self.client.close(_('Account in use'))
                    #FIXME: If guest then prompt for a new user or mangle username until one can be found
                    
                elif code == 'wrong login type':
                    self.client.setState(self.client.STATE_GET_PASSWORD)
                
                else:
                    self.client.close(code)

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
        try:
            table = self._getTable(tableId)
        except KeyError:
            print "Unknown JOIN with TABLE='%s'" % tableId
            return
        self.client.setState(self.client.STATE_AT_TABLE)
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
        try:
            game = self._getGame(gameId, optional = True)
        except KeyError:
            print "Unknown ROOM ADD with GAME='%s'" % gameId
            return
        room = Room()
        room.id = roomId
        room.game = game
        room.name = name
        room.description = description
        room.nPlayers = int(nPlayers)
        self.client.rooms[roomId] = room
        self.client.feedback.roomAdded(room)

    def roomPlayersUpdate(self, roomId, nPlayers):
        try:
            room = self._getRoom(roomId)
        except KeyError:
            print "Unknown ROOM PLAYER UPDATE with ROOM='%s'" % roomId
            return
        room.nPlayers = int(nPlayers)
        self.client.feedback.roomUpdated(room)

    def tableAdded(self, roomId, tableId, gameId, status, nSeats, description): 
        try:
            room = self._getRoom(roomId)
            game = self._getGame(gameId)
        except KeyError:
            print "Unknown TABLE ADD with ROOM='%s' GAME='%s'" % (roomId, gameId)
            return
        table = Table(int(nSeats))
        table.id = tableId
        table.room = room
        table.game = game
        table.status = status
        table.description = description
        self.client.tables[tableId] = table
        self.client.feedback.tableAdded(table)

    def tableStatusChanged(self, tableId, status):
        try:
            table = self._getTable(tableId)
        except KeyError:
            print "Unknown TABLE STATUS with TABLE='%s'" % tableId
            return
        table.status = status
        self.client.feedback.tableUpdated(table)

    def seatChanged(self, roomId, tableId, seatId, seatType, user):
        try:
            table = self._getTable(tableId)
        except KeyError:
            print "Unknown SEAT CHANGE with TABLE='%s'" % tableId
            return
        if table.room.id != roomId:
            return
        seat = table.seats[int(seatId)]
        seat.type = seatType
        seat.user = user
        self.client.feedback.tableUpdated(table)

    def tableRemoved(self, tableId):
        try:
            table = self.client.tables.pop(tableId)
        except KeyError: 
            print "Unknown TABLE REMOVE with TABLE='%s'" % tableId           
            # We do not know of this table - this could occur if we receive a
            # table remove event before we get the table list.
            return
        self.client.feedback.tableRemoved(table)
        
    def onPlayerList(self, roomId, players):
        try:
            room = self._getRoom(roomId)
            for p in players:
                _ = self._getTable(p.tableId, optional = True)
        except KeyError: 
            print "Unknown PLAYER LIST with ROOM='%s'" % roomId
            return
        self.client.players = {}
        for p in players:
            player = Player()
            player.name = p.name
            player.type = p.type
            player.table = self._getTable(p.tableId, optional = True)
            player.perms = p.perms
            player.lag = p.lag
            player.room = room
            self.client.players[player.name] = player

        room.nPlayers = len(players)
        self.client.feedback.roomUpdated(room)

    def playerAdded(self, name, playerType, tableId, perms, lag, roomId, fromRoomId):
        try:
            room = self._getRoom(roomId, optional = True)
            lastRoom = self.client.rooms[fromRoomId]
            table = self._getTable(tableId, optional = True)
        except KeyError:
            print "Unknown PLAYER ADD with ROOM='%s' LASTROOM='%s' TABLE='%s'" % (roomId, fromRoomId, tableId)
            return
        player = Player()
        player.name = name
        player.type = playerType
        player.table = table
        player.perms = perms
        player.lag = lag
        player.room = room
        player.lastRoom = lastRoom
        self.client.players[player.name] = player

        if player.lastRoom is not None:
            player.lastRoom.nPlayers -= 1
            self.client.feedback.roomUpdated(player.lastRoom)
        if player.room is not None:
            player.room.nPlayers += 1
            self.client.feedback.roomUpdated(player.room)
        self.client.feedback.playerAdded(player)

    def playerRemoved(self, name, roomId, toRoomId):
        try:
            player = self.client.players.pop(name)
            room = self._getRoom(toRoomId, optional = True)
        except KeyError:
            print "Unknown PLAYER REMOVE with NAME='%s' ROOM='%s' TOROOM='%s'" % (name, roomId, toRoomId)
            # We do not know of this player - this could occur if we receive a
            # player remove event before we get the player list.
            return
            
        player.room.nPlayers -= 1
        player.lastRoom = player.room
        player.room = room
        if player.room is not None:
            player.room.nPlayers += 1
            self.client.feedback.roomUpdated(player.room)
        if player.lastRoom is not None:
            self.client.feedback.roomUpdated(player.lastRoom)
        self.client.feedback.playerRemoved(player)

    def closed(self, errno = 0):
        # Translators: GGZ disconnection error when the network link has broken. %s is the system provided error
        self.client.close(_('Connection closed: %s') % os.strerror(errno))
       
    def _getGame(self, gameId, optional = False):
        if optional and gameId == '-1':
            return None
        return self.client.games[gameId]

    def _getRoom(self, roomId, optional = False):
        if optional and roomId == '-1':
            return None
        return self.client.rooms[roomId]    
        
    def _getTable(self, tableId, optional = False):
        if optional and tableId == '-1':
            return None
        return self.client.tables[tableId]
    
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

    def onDisconnected(self, reason):
        print 'Disconnected: %s' % reason

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

    def closed(self, errno = 0):
        print 'SEVERE: GGZ channel closed'

class Client:
    
    STATE_DISCONNECTED        = 'DISCONNECTED'
    STATE_START_SESSION       = 'START_SESSION'
    STATE_LOGIN               = 'LOGIN'
    STATE_GET_PASSWORD        = 'GET_PASSWORD'    
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

    def close(self, error):
        self.disconnectionError = error
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
        elif state is self.STATE_GET_PASSWORD:
            self.feedback.getPassword(self.username)
        elif state is self.STATE_DISCONNECTED:
            self.feedback.onDisconnected(self.disconnectionError)
            self.mainChannel.controller.close()

    def start(self):
        assert(self.state is self.STATE_DISCONNECTED)
        self.mainChannel = MainChannel(self)
        self.mainChannel.controller = self.feedback.openChannel(self.mainChannel)
        
    def setPassword(self, password):
        assert(self.state is self.STATE_GET_PASSWORD)
        if password is None:
            # Translators: GGZ disconnection error when a password was required for the selected account
            self.close(_('A password is required'))
        else:
            self._login(self.username, password)
        
    def _login(self, username, password):
        assert(self.state is self.STATE_START_SESSION or self.state is self.STATE_GET_PASSWORD)
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
