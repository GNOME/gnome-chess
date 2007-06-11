import struct

class GGZChessFeedback:
            
    def onSeat(self, seatNum, version):
        pass
            
    def onPlayers(self, whiteType, whiteName, blackType, blackName):
        pass
                
    def onClockRequest(self):
        pass
    
    def onClock(self, mode, seconds):
        pass

    def onStart(self):
        pass
    
    def onMove(self, move):
        pass

class Chess:
    
    CLOCK_NONE      = 0
    CLOCK_CLIENT    = 1
    CLOCK_SERVERLAG = 2
    CLOCK_SERVER    = 3
    
    # Player codes (copied from GGZ_SEAT_*)
    GGZ_SEAT_NONE      = '\x00' # This seat does not exist */
    GGZ_SEAT_OPEN      = '\x01' # The seat is open (unoccupied).
    GGZ_SEAT_BOT       = '\x02' # The seat has a bot (AI) in it.
    GGZ_SEAT_PLAYER    = '\x03' # The seat has a regular player in it.
    GGZ_SEAT_RESERVED  = '\x04' # The seat is reserved for a player.
    GGZ_SEAT_ABANDONED = '\x05' # The seat is abandoned by a player.

    def sendClock(self, mode, seconds):
        return '\x04' + struct.pack('!I', (mode << 24) | (seconds & 0x00FFFFFF))

    def sendMove(self, move, time = None):
        cmd = '\x06' + struct.pack('!I', len(move)) + move
        if time is not None:
            cmd += struct.pack('!I', time)
        return cmd
    
    def sendStart(self):
        return '\x05'

    def __init__(self, feedback):
        self.feedback = feedback

        self.decodeMethod = None
        self.decodeMethods = {'\x01': self.decodeSeat,
                              '\x02': self.decodePlayers,
                              '\x03': self.decodeClockRequest,
                              '\x04': self.decodeClock,
                              '\x05': self.decodeStart,
                              # 6: Move request
                              '\x07': self.decodeMove,
                              '\x08': self.decodeGameEnd,
                              #9: Update request
                              '\x0a': self.decodeUpdate,
                              #11: server time update?
                              #12: self.decodeFlag,
                              '\x0d': self.decodeDraw}

    def decode(self, char):
        if self.decodeMethod is None:
            self.decodeMethod = self.decodeMethods[char]
            self.command = ''
        self.command += char
        self.decodeMethod()
        
    def getGGZString(self, buffer):
        if len(buffer) < 4:
            return (None, 0)
        (length,) = struct.unpack("!I", buffer[:4])
        if len(buffer) < length + 4:
            return (None, 0)
        
        string = buffer[4:length + 4]
        if string[-1] == '\x00':
            string = string[:-1]
        
        return (string, length + 4)

    def decodeSeat(self):
        # seat [01][num][version]
        if len(self.command) == 3:
            self.decodeMethod = None
            (num, version) = struct.unpack('!xBB', self.command)
            self.feedback.onSeat(num, version)
    
    def decodePlayers(self):
        # players [02][code1][name1(18)][code2][name2(18)]
        # name is ommitted if code == 01 (open)
        requiredLength = 2
        if len(self.command) < requiredLength:
            return
        
        whiteCode = self.command[1]
        if whiteCode == self.GGZ_SEAT_OPEN:
            requiredLength += 1
            whiteName = ''
        else:
            (whiteName, offset) = self.getGGZString(self.command[requiredLength:])
            if whiteName is None:
                return
            requiredLength += 1 + offset
        if len(self.command) < requiredLength:
            return

        blackCode = self.command[requiredLength - 1]
        if blackCode == self.GGZ_SEAT_OPEN:
            blackName = ''
        else:
            (blackName, offset) = self.getGGZString(self.command[requiredLength:])
            if blackName is None:
                return
            requiredLength += offset

        if len(self.command) >= requiredLength:
            self.decodeMethod = None
            self.feedback.onPlayers(whiteCode, whiteName, blackCode, blackName)
    
    def decodeClockRequest(self):
        # [3]
        self.decodeMethod = None
        self.feedback.onClockRequest()
        
    def decodeClock(self):
        # [4][mode][seconds]
        if len(self.command) == 5:
            (value,) = struct.unpack("!xI", self.command)
            mode = value >> 24
            seconds = value & 0x00FFFFFF
            self.feedback.onClock(mode, seconds)
            self.decodeMethod = None
        
    def decodeStart(self):
        # [5]
        self.decodeMethod = None
        self.feedback.onStart()

    def decodeMove(self):
        #    [07][move(8)]
        # or [07][move(8)][seconds]
        (move, _) = self.getGGZString(self.command[1:])
        if move is None:
            return
        self.decodeMethod = None
        self.feedback.onMove(move)
            
    def decodeGameEnd(self):
        # [08][result]
        if len(self.command) == 2:
            self.decodeMethod = None

    def decodeUpdate(self):
        # [0A][wtime][btime]
        if len(self.command) == 9:
            self.decodeMethod = None
            
    def decodeDraw(self):
        # [0D]
        self.decodeMethod = None
