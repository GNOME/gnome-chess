"""
"""

def decodeMessage(data):
    """
    """
    fields = []
    
    lines = data.split('\n')
    (sequenceNumber, messageType) = lines[0].split(' ')
    try:
        sequenceNumber = int(sequenceNumber)
    except ValueError:
        sequenceNumber = None
    
    fieldName = None
    fieldValue = None
    for line in lines[1:]:
        (name, value) = line.split('=', 1)
        if name == '~':
            assert(fieldName is not None)
            fieldValue += '\n' + value
        else:
            if fieldName is not None:
                fields.append((fieldName, fieldValue))
                    
            fieldName = name
            fieldValue = value
            
    if fieldName is not None:
        fields.append((fieldName, fieldValue))
        
    return (sequenceNumber, messageType, fields)

def encodeMessage(sequenceNumber, messageType, fields):
    """
    """
    data = str(sequenceNumber) + ' ' + messageType + '\n'
    
    for (name, value) in fields:
        data += name + '='
        lines = value.split('\n')
        data += lines[0]
        for line in lines[1:]:
            data += '\n~=' + line
        data += '\n'
    
    return data[:-1]

class OutgoingMessage:
    """
    """
    
    sequenceNumber = None
    data           = None
    
    def __init__(self, sequenceNumber, data):
        """
        """
        self.sequenceNumber = sequenceNumber
        self.data = data
        
class Sender:
    """
    """

    # Sequence number to mark message with
    __sequenceNumber = 0
    
    # Messages waiting to be sent
    __queuedMessages = None
    
    # Timout in seconds sending a message
    TIMEOUT = 1.0
    
    # Number of times to send a message until assuming the receiver has died
    RETRIES = 3

    def __init__(self):
        """Constructor"""
        self.__queuedMessages = []
        
    # Methods to extend
    
    def onOutgoingMessage(self, data):
        """Called when a message is generated to be sent.
        
        'data' is the raw message to send (string).
        """
        pass
    
    def startTimer(self):
        """Start the message retry timer.
        
        If the timer expires call retryMessage().
        """
        pass
    
    def stopTimer():
        """Stop the retry timer"""
        pass
    
    # Public methods
    
    def sendAcknowledge(self, sequenceNumber):
        """Send an acknowledge message.
        
        'sequenceNumber' is the sequence number of the message being acknowledged (int).
        """
        d = encodeMessage('*', 'ACK', [('seq', str(sequenceNumber))])
        self.onOutgoingMessage(d)
        
    def queueMessage(self, messageType, fields = []):
        """Queue a message for sending.
        
        'messageType' is the type of message (string).
        'fields' is a list of containing (name, value) pairs for message fields.
        """
        # Encode with the message header
        self.__sequenceNumber = (self.__sequenceNumber + 1) % 1000
        data = encodeMessage(self.__sequenceNumber, messageType, fields)
        
        self.__queuedMessages.append(OutgoingMessage(self.__sequenceNumber, data))
        
        # Send if no other queued messages
        if len(self.__queuedMessages) == 1:
            self.startTimer()
            self.onOutgoingMessage(data)
        
    def acknowledgeMessage(self, sequenceNumber):
        """Confirm a message has been received at the far end.
        
        'sequenceNumber' is the sequence number that has been acknowledged (int).
        """
        # If this matches the last message sent then remove it from the message queue
        if len(self.__queuedMessages) == 0:
            return
        if sequenceNumber != self.__queuedMessages[0].sequenceNumber:
            return
        self.__queuedMessages = self.__queuedMessages[1:]
        
        # Send the next message
        if len(self.__queuedMessages) > 0:
            self.startTimer()
            self.onOutgoingMessage(self.__queuedMessages[0].data)
        else:
            self.stopTimer()
            
    def retryMessage(self):
        """Resend the last message"""
        try:
            data = self.__queuedMessages[0].data
        except IndexError:
            return
        self.startTimer()
        self.onOutgoingMessage(data)

class Receiver:
    """
    """
    # Expected sequence number to receive
    __expectedSequenceNumber = None

    __processing = False
    __queue = None
    
    def __init__(self):
        """Constructor"""
        self.__queue = []
    
    # Methods to extend
    
    def processMessage(self, messageType, fields):
        """Called when a message is available for processing.
        
        'messageType' is the message type (string).
        'fields' is a dictionary of field values keyed by field name.
        """
        pass
    
    # Public methods
    
    def filterMessage(self, sequenceNumber, messageType, fields):
        """Check the header fields on a message.
        
        'sequenceNumber' is the sequence number of the incoming message (int).
        'messageType' is the type of message (string).
        'fields' is a dictionary of field values keyed by field name.

        processMessage() is called if this message has the correct sequence number.
        """
        # Stop recursion
        if self.__processing:
            self.__queue.append((sequenceNumber, messageType, fields))
            return
        
        # Check sequence number matches
        if sequenceNumber is not None:
            expected = self.__expectedSequenceNumber
            if expected is not None and sequenceNumber != expected:
                return
            self.__expectedSequenceNumber = (sequenceNumber + 1) % 1000

        # Pass to higher level
        self.__processing = True
        self.processMessage(messageType, fields)
        self.__processing = False
        
        # Process any messages received while in the callback
        while len(self.__queue) > 0:
            (sequenceNumber, messageType, fields) = self.__queue[0]
            self.__queue = self.__queue[1:]
            self.filterMessage(sequenceNumber, messageType, fields)
        
class StateMachine(Receiver, Sender):
    """
    """
    
    def __init__(self):
        """Constructor"""
        Sender.__init__(self)
        Receiver.__init__(self)
        
    # Methods to extend

    def onOutgoingMessage(self, message):
        """Called when a message is generated to send.
        
        'message' is the message to send (string).
        """
        pass
    
    def processMessage(self, messageType, fields):
        """Called when a message is available for processing.
        
        'messageType' is the message type (string).
        'fields' is a dictionary of field values keyed by field name.
        """
        pass
    
    # Public methods
    
    def sendMessage(self, messageType, fields):
        """Send a message.
        
        'messageType' is the message type to send (string made up of A-Z).
        'fields' is a list of 2-tuples containing field names and values (strings).
        """
        self.queueMessage(messageType, fields)

    def registerIncomingMessage(self, message):
        """Register a received message.
        
        'message' is the raw received message (string).
        """
        (sequenceNumber, messageType, fields) = decodeMessage(message)
        fields = dict(fields)
        
        # FIXME: 'seq' could be an invalid integer
        if messageType == 'ACK':
            try:
                seq = int(fields['seq'])
            except (KeyError, ValueError):
                return
            self.acknowledgeMessage(seq)
            return
        
        # Acknowledge this message
        # FIXME: We should check its sequence number first
        self.sendAcknowledge(sequenceNumber)
        
        # Process it
        self.filterMessage(sequenceNumber, messageType, fields)

class Encoder:
    """
    """
    
    __sequenceNumber = 0
    
    def onOutgoingMessage(self, message):
        """
        """
        pass
    
    # Public methods
        
    def __sendMessage(self, messageType, fields = []):
        """
        """
        self.__sequenceNumber += 1
        if self.__sequenceNumber > 999:
            self.__sequenceNumber = 0
        d = encodeMessage(messageType, [('seq', str(self.__sequenceNumber)), ('src', self.__sourceAddress), ('dst', self.__destinationAddress)].join(fields))
        self.onOutgoingMessage(d)
        
    def sendAcknowledge(self):
        """
        """
        self.__sendMessage('ACK')
        
    def sendNotAcknowledge(self, error):
        """
        """
        self.__sendMessage('NACK', [('error', error)])
        
    def sendJoin(self, name, playerType):
        """
        """
        self.__sendMessage('JOIN', [('name', name), ('type', playerType)])
        
    def sendLeave(self, name, reason):
        """
        """
        self.__sendMessage('LEAVE', [('name', name), ('reason', reason)])
        
    def sendMove(self, player, move):
        """
        """
        self.__sendMessage('MOVE', [('player', player), ('move', move)])
        
    def sendGameAnnounce(self, name, result, white = None, black = None, spectators = [], player = None, moves = []):
        """
        """
        fields = [('name', name), ('result', result)]
        
        if white is not None:
            fields.append(('white', white))
        if black is not None:
            fields.append(('black', black))
        if player is not None:
            fields.append(('player', player))
        for player in spectators:
            fields.append(('spectator', player))
            
        for move in moves:
            fields.append(('move', move))
        
        self.__sendMessage('GAME', fields)
        
if __name__ == '__main__':
    x = encodeMessage('TEST', [('field1', 'value1'), ('long_field', 'This is a long message.\nBlah Blah\n\nAll done\n')])
    print x
    (t, f) = decodeMessage(x)
    print t
    print f

    x = encodeMessage('X', [])
    print x
    (t, f) = decodeMessage(x)
    print t
    print f
