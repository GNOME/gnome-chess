# -*- coding: utf-8 -*-

class Decoder:
    """
    """
    
    buffer = ''
    processing = False

    def __init__(self):
        self.commands = {240: (self.onEndSubnegotiation, False),
                         241: (self.onNoOp, False),
                         242: (self.onDataMark, False),
                         243: (self.onBreak, False),
                         244: (self.onInterruptProcess, False),
                         245: (self.onAbortOutput, False),
                         246: (self.onAreYouThere, False),
                         247: (self.onEraseCharacter, False),
                         248: (self.onEraseLine, False),
                         249: (self.onGoAhead, False),
                         250: (self.onStartSubnegotiation, False),
                         251: (self.onWill, True),
                         252: (self.onWont, True),
                         253: (self.onDo, True),
                         254: (self.onDont, True)}
    
    def onData(self, data):
        """Called when data from the telnet stream is decoded.
        
        'data' is the data inside the telnet stream (str).
        """
        pass
    
    def onEndSubnegotiation(self):
        pass
    
    def onNoOp(self):
        pass
    
    def onDataMark(self):
        pass
    
    def onBreak(self):
        pass
    
    def onInterruptProcess(self):
        pass
    
    def onAbortOutput(self):
        pass
    
    def onAreYouThere(self):
        pass
    
    def onEraseCharacter(self):
        pass
    
    def onEraseLine(self):
        pass
    
    def onGoAhead(self):
        pass
    
    def onStartSubnegotiation(self):
        pass
    
    def onWill(self, option):
        pass
    
    def onWont(self, option):
        pass
    
    def onDo(self, option):
        pass

    def onDont(self, option):
        pass
    
    def onUnknownCommand(self, command):
        pass
    
    def registerIncomingData(self, data):
        """Register data received from a telnet device.
        
        'data' is the received data (str).
        """
        if self.processing:
            self.buffer += data
            return
        self.processing = True
        
        d = self.buffer + data
        self.buffer = ''
        while True:
            # Process any data registered while in this method
            d += self.buffer
            if len(d) == 0:
                break
            
            index = d.find('\xff')
            if index < 0:
                self.onData(d)
                break

            # Use the data up to this point
            text = d[:index]
            if len(text) > 0:
                self.onData(text)
            
            # Try and get the command
            try:
                command = ord(d[index+1])
            except IndexError:
                self.buffer = d[index:]
                break

            # Special case - repeated 0xFF is just 0xFF
            if command == 255:
                self.onData('\xff')
                d = d[index+2:]
                continue
            
            # Look for the command
            try:
                (method, hasParameter) = self.commands[command]
            except KeyError:
                self.onUnknownCommand(command)
                d = d[index+2:]
                continue

            if hasParameter:
                try:
                    parameter = ord(d[index+2])
                except IndexError:
                    self.buffer = d[index:]
                    break
                method(parameter)
                d = d[index+3:]
            else:
                method()
                d = d[index+2:]
            
        self.processing = False
        
if __name__ == '__main__':
    class D(Decoder):
        def onData(self, data):
            print 'onData(' + repr(data) + ')'
            
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
    
    d = D()
    d.registerIncomingData('A telnet\xff\xff string \xff\xf3 with a break and a DO 6 \xff\xfd\x06. Fun innit?')

    d.registerIncomingData('ABC\xff')
    d.registerIncomingData('\xf3DEF')
    
    d.registerIncomingData('ABC\xff')
    d.registerIncomingData('\xfd')
    d.registerIncomingData('\x0aDEF')
