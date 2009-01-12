# -*- coding: utf-8 -*-
import os
import socket
import errno
import gettext

import ggz
import ui
import game

from defaults import *

_ = gettext.gettext

class GGZServer:
    def __init__(self, name):
        self.name = name

class GGZLine:
    TYPE_BLANK   = 'BLANK'
    TYPE_COMMENT = 'COMMENT'
    TYPE_SECTION = 'SECTION'
    TYPE_FIELD   = 'FIELD'
    TYPE_INVALID = 'INVALID'
    
    def __init__(self, text):
        self.text = text
        self.section = None
        try:
            self.decode(text)
        except ValueError, e:
            self.type = GGZLine.TYPE_INVALID
            print e

    def decode(self, text):
        content = text.strip()
        if len(content) == 0:
            self.type = GGZLine.TYPE_BLANK
        elif content[0] == '#':
            self.type = GGZLine.TYPE_COMMENT
        elif content[0] == '[':
            self.type = GGZLine.TYPE_SECTION
            if content[-1] != ']':
                raise ValueError('Invalid section line: %s' % repr(content))
            self.name = content[1:-1].strip()
            self.value = None
        else:
            self.type = GGZLine.TYPE_FIELD
            try:
                (name, value) = content.split('=', 1)
            except ValueError:
                raise ValueError('Invalid field line: %s' % repr(content))
            else:
                self.name = name.strip()
                self.value = value.strip()
            
    def setValue(self, value):
        assert(self.type is GGZLine.TYPE_FIELD)
        self.value = value
        self.text = '%s=%s' % (self.name, value)

class GGZConfig:
    
    TYPE_NORMAL = 0
    TYPE_GUEST  = 1
    TYPE_FIRST  = 2
    
    def __init__(self):
        try:
            f = file(GGZ_CONFIG_FILE)
            lines = f.readlines()
        except IOError:
            print 'Failed to load GGZ config: %s' % e.message
            lines = []
            
        self.lines = []

        section = None
        for text in lines:
            line = GGZLine(text)
            self.lines.append(line)

            if line.type is GGZLine.TYPE_SECTION:
                section = line.name
                line.section = section
            else:
                line.section = section

    def getField(self, section, name):
        for line in self.lines:
            if line.section != section or line.type is not GGZLine.TYPE_FIELD:
                continue
            if line.name == name:
                return line.value
        raise KeyError('No field %s in section %s' % (name, section))
    
    def setField(self, section, name, value):
        wasInSection = False
        inSection = False
        for (index, line) in enumerate(self.lines):
            wasInSection = inSection
            if line.section == section:
                inSection = True
                if line.type is GGZLine.TYPE_FIELD and line.name == name:
                    line.setValue(value)
                    return
            elif wasInSection and not inSection:
                self.lines.insert(index, GGZLine('%s=%s' % (name, value), section))
                return
    
    def removeSection(self, name):
        keptLines = []
        for line in self.lines:
            if line.section != name:
                keptLines.append(line)
        self.lines = keptLines
        
    def getServers(self):        
        try:
            value = self.getField('Servers', 'ProfileList')
        except KeyError, e:
            return []

        servers = []
        for n in value.replace('\\ ', '\x00').split(' '):
            name = n.replace('\x00', ' ')
            try:
                server = self.getServer(name)
            except KeyError, e:
                print e
            else:
                servers.append(server)
        return servers
    
    def getServer(self, name):
        server = GGZServer(name)

        try:
            server.host = self.getField(name, 'Host')
            server.port = int(self.getField(name, 'Port'))
            server.login = self.getField(name, 'Login')
            server.loginType = int(self.getField(name, 'Type'))
        except (KeyError, ValueError):
            raise KeyError('Missing/invalid basic configuration for server %s' % repr(server.name))
        
        try:
            server.password = self.getField(name, 'Password')
        except KeyError:
            server.password = None

        return server
                
    def save(self):
        lines = []
        for line in self.lines:
            lines.append(line.text)
        try:
            f = file(GGZ_CONFIG_FILE, 'w')
            f.writelines(lines)
        except IOError, e:
            print 'Failed to save GGZ config: %s' % e.message

class GGZChannel(ggz.Channel):
    def __init__(self, ui, feedback):
        self.buffer = ''
        self.ui = ui
        self.feedback = feedback
        self.socket = None
        self.fd = -1
        
    def logXML(self, text):
        self.logWindow.addText(text, 'input')

    def logBinary(self, data):
        self.logWindow.addBinary(data, 'input')

    def connect(self, host, port):
        self.close()
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.fd = self.socket.fileno()
        self.socket.setblocking(False)
        self.ui.application.ioHandlers[self.fd] = self
        self.ui.controller.watchFileDescriptor(self.fd)
        
        try:
            self.socket.connect((host, port))
        except socket.error, e:
            # FIXME: Abort/retry if error
            if e.args[0] == errno.EINPROGRESS:
                print 'connecting...'
            else:
                print e
                
        name = '%s:%d' % (host, port)
        self.logWindow = self.ui.controller.addLogWindow(name, name, name)
    
    def send(self, data, isBinary = False):
        if isBinary:
            self.logWindow.addBinary(data, 'output')
        else:
            self.logWindow.addText(data, 'output')
            
        self.buffer += data
        try:
            nSent = self.socket.send(self.buffer)
        except socket.error:
            nSent = 0
        self.buffer = self.buffer[nSent:]
        
    def close(self):
        if self.socket is None:
            return
        self.ui.controller.unwatchFileDescriptor(self.fd)
        self.socket.close()
        self.socket = None
        self.fd = -1
        
    def read(self):
        try:
            (data, address) = self.socket.recvfrom(65535)
        except socket.error, e:
            try:
                self.socket.close()
            except socket.error:
                pass
            self.feedback.closed(e.args[0])
            return False
        else:
            if len(data) == 0:
                self.feedback.closed()
                return False
            self.feedback.registerIncomingData(data)
        return True

class GGZConnection(ggz.ClientFeedback):

    def __init__(self, dialog):
        self.dialog = dialog
        self.profile = dialog.profile
        self.client = ggz.Client(self)
        self.commands = []
        self.sending = False
        self.players = {}
        self.actions = []
        
    def _getPlayerIcon(self, player):
        try:
            return {'guest':  'stock_person',
                    'normal': 'stock_person',
                    'admin':  'stock_person', # FIXME
                    'bot':    'stock_notebook'}[player.type]
        except KeyError:
            return ''
        
    def _performAction(self, method, args):
        if self.client.isBusy():
            self.actions.insert(0, (method, args))
        else:
            method(*args)

    def close(self):
        self.client.close('')

    def setBusy(self, isBusy):
        self.dialog.controller.setBusy(isBusy)
        
        # Perform next queued action
        if not isBusy and len(self.actions) > 0:
            (method, args) = self.actions.pop()
            method(*args)

    def onConnected(self):
        self.dialog.controller.setSensitive(True)
        self.dialog.controller.clearError()

    def onDisconnected(self, reason):
        self.dialog.controller.setError(_('Disconnected from server'), reason)
        self.dialog.controller.setSensitive(False)

    def openChannel(self, feedback):
        print 'Open Channel'
        self.setBusy(True)
        socket = GGZChannel(self.dialog.ui, feedback)
        socket.connect(self.profile.host, self.profile.port)
        return socket

    def getLogin(self):
        return (self.profile.login, self.profile.password)
    
    def getPassword(self, username):
        self.client.setPassword(self.profile.password)
        
    def onMOTD(self, motd):
        self.dialog.controller.addText(motd, 'motd')

    def roomAdded(self, room):
        isChess = room.game is None or (room.game.protocol_engine == 'Chess' and room.game.protocol_version == '3')
        if room.game is None:
            protocol = None
        else:
            protocol = room.game.protocol_engine
        self.dialog.controller.addRoom(int(room.id), room.name, room.nPlayers, room.description, room, protocol)

    def roomUpdated(self, room):
        self.dialog.controller.updateRoom(room, room.nPlayers)

    def roomEntered(self, room):
        self.room = room
        self.dialog.controller.clearPlayers()
        self.dialog.controller.clearTables()
        
        for player in self.client.players.itervalues():
            self.dialog.controller.addPlayer(player, player.name, self._getPlayerIcon(player))
        for table in self.client.tables.itervalues():
            self.tableAdded(table)

        self.dialog.controller.enterRoom(room)

    def tableAdded(self, table):
        self.tableUpdated(table)

    def tableUpdated(self, table):
        if table.room != self.room:
            return
        description = table.description
        if len(description) == 0:
            description = _('No description')
        nUsed = 0
        for seat in table.seats:
            if seat.type == 'bot' or seat.user != '':
                nUsed += 1

        # Can connect to Chess tables with free spaces
        isChess = table.room.game is not None and table.room.game.protocol_engine == 'Chess'
        canConnect = isChess and nUsed != len(table.seats)

        self.dialog.controller.updateTable(table, '%s' % table.id, '%i/%i' % (nUsed, len(table.seats)), description, canConnect)
        for (i, seat) in enumerate(table.seats):
            self.dialog.controller.updateSeat(table, i, seat.type, seat.user)

    def tableRemoved(self, table):
        if table.room == self.room:
            self.dialog.controller.removeTable(table)

    def onJoin(self, table, isSpectator, channel):
        self.dialog.controller.joinTable(table)
        g = GGZChess(self.dialog.game, channel)
        return g

    def onLeave(self, reason):
        print 'Leave table: %s' % reason
        self.dialog.controller.joinTable(None)

    def playerAdded(self, player):
        self.dialog.controller.addPlayer(player, player.name, self._getPlayerIcon(player))

    def playerRemoved(self, player):
        self.dialog.controller.removePlayer(player)

    def onChat(self, chatType, sender, text):
        self.dialog.controller.addText('\n%s: %s' % (sender, text), 'chat')

class GGZChess:
    """
    """
    
    def __init__(self, game, channel):
        self.game = game
        self.channel = channel
        self.protocol = ggz.Chess(self)

    def registerIncomingData(self, data):
        for o in data:
            self.protocol.decode(o)

    def onSeat(self, seatNum, version):
        self.seatNum = seatNum
        print ('onSeat', seatNum, version)
        
    def seatIsFull(self, seatType):
        return seatType == self.protocol.GGZ_SEAT_PLAYER or seatType == self.protocol.GGZ_SEAT_BOT

    def onPlayers(self, whiteType, whiteName, blackType, blackName):
        print ('onPlayers', whiteType, whiteName, blackType, blackName)
        self.whiteName = whiteName
        self.blackName = blackName

    def onClockRequest(self):
        print ('onTimeRequest',)
        self.channel.send(self.protocol.sendClock(self.protocol.CLOCK_NONE, 0), True)
    
    def onClock(self, mode, seconds):
        print ('onClock', mode, seconds)

    def onStart(self):
        print ('onStart',)
        # Create remote player
        if self.seatNum == 0:
            name = self.blackName
        else:
            name = self.whiteName
        self.remotePlayer = game.ChessPlayer(name)
        self.remotePlayer.onPlayerMoved = self.onPlayerMoved # FIXME: HACK HACK HACK!

        p = self.game.addHumanPlayer('Human')
        if self.seatNum == 0:
            self.game.setWhite(p)
            self.game.setBlack(self.remotePlayer)
        else:
            self.game.setWhite(self.remotePlayer)
            self.game.setBlack(p)

        self.game.start()

    def onPlayerMoved(self, player, move):
        #FIXME: HACK HACK HACK!
        if player is not self.remotePlayer:
            self.channel.send(self.protocol.sendMove(move.canMove.upper()), True)

    def onMove(self, move):
        print ('onMove', move)
        # FIXME: Only remote players should be used
        self.remotePlayer.move(move.lower())

class GGZNetworkDialog(ui.NetworkFeedback):
    """
    """
    
    def __init__(self, ui):
        self.ui = ui
        self.buffer = ''
        self.profile = None
        self.decoder = None

    def setProfile(self, profile):
        """Called by ui.NetworkFeedback"""
        if profile is None:
            name = '(none)'
        else:
            name = profile.name
        print 'Profile=%s' % name #FIXME Make proper log

        if self.decoder is not None:
            self.decoder.close()
        self.decoder = None

        self.controller.clearError()       
        self.controller.setSensitive(False)
        self.controller.clearRooms()
        self.controller.clearPlayers()
        self.controller.clearTables()
        self.controller.clearText()
        
        self.profile = profile
        if profile is None:
            return
       
        self.decoder = GGZConnection(self)
        self.decoder.client.start()
    
    def enterRoom(self, room):
        """Called by ui.NetworkFeedback"""
        print 'Entering room %s' % room.id
        self.decoder._performAction(self.decoder.client.enterRoom, (room,))
        
    def _addGame(self):
        self.game = self.ui.application.addGame('Network Game')
        if self.game is None:
            # FIXME: Notify user game aborted
            return False
        return True
        
    def startTable(self):
        """Called by ui.NetworkFeedback"""
        if self.decoder.room.game is None:
            return
        
        if not self._addGame():
            return
        
        print 'Starting table'
        self.decoder.client.startTable(self.decoder.room.game.id, '', self.profile.login)

    def joinTable(self, table):
        """Called by ui.NetworkFeedback"""
        if not self._addGame():
            return
        
        print 'Starting table %s' % table.id
        self.decoder.client.joinTable(table)

    def leaveTable(self):
        """Called by ui.NetworkFeedback"""
        self.decoder.client.leaveTable()

    def sendChat(self, text):
        """Called by ui.NetworkFeedback"""
        self.decoder.client.sendChat(text)
