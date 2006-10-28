"""
"""

#avahi = __import__('avahi')
#dbus = __import__('dbus')
import avahi
import dbus

class RemoteGame:
    """
    """
    
    def __init__(self, name, address):
        """
        """
        self.name = name
        self.address = address
        
class GameReporter:
    """
    """
    
    def __init__(self, name, port):
        """Constructor.
        
        'name' is the name of the game started (string).
        'port' is the UDP/IP port the game is running on (integer).
        """
        self.name = name
        self.port = port
        
        # Connect to the Avahi server
        bus = dbus.SystemBus()
        self.server = dbus.Interface(bus.get_object(avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER), avahi.DBUS_INTERFACE_SERVER)

        # Register this service
        path = self.server.EntryGroupNew()
        group = dbus.Interface(bus.get_object(avahi.DBUS_NAME, path), avahi.DBUS_INTERFACE_ENTRY_GROUP)
        n = name
        index = 1
        while True:
            try:
                group.AddService(avahi.IF_UNSPEC, avahi.PROTO_INET, 0, n, '_glchess._udp', '', '', port, avahi.string_array_to_txt_array(['hi=gi']))
            except dbus.dbus_bindings.DBusException:
                index += 1
                n = name + ' (' + str(index) + ')'
            else:
                break
        group.Commit()

class GameDetector:
    """Class to detect glChess network games.
    """
    # The known about games
    __games       = None
    __gamesByName = None

    def __init__(self):
        """Constructor"""
        self.__games = []
        self.__gamesByName = {}
        
        # Connect to the Avahi server
        bus = dbus.SystemBus()
        self.server = dbus.Interface(bus.get_object(avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER), avahi.DBUS_INTERFACE_SERVER)

        # Listen for glChess servers
        # FIXME: Can raise a dbus_bindings.DBusException (local name collision)
        browser = self.server.ServiceBrowserNew(avahi.IF_UNSPEC, avahi.PROTO_INET, '_glchess._udp', '', 0)
        listener = dbus.Interface(bus.get_object(avahi.DBUS_NAME, browser), avahi.DBUS_INTERFACE_SERVICE_BROWSER)
        listener.connect_to_signal('ItemNew', self.__serviceDetected)
        listener.connect_to_signal('ItemRemove', self.__serviceRemoved)
        
    # Methods to extend
    
    def onGameDetected(self, game):
        """Called when a game is detected.
        
        'game' is the game that has been detected (RemoteGame).
        """
        pass
    
    def onGameRemoved(self, game):
        """Called when a game is removed.
        
        'game' is the game that has been removed (RemoteGame).
        """
        pass
        
    # Public methods
    
    def getGames(self):
        """Returns a list of games that are known of"""
        return self.__games[:]
        
    # Private methods
        
    def __serviceDetected(self, interface, protocol, name, stype, domain, flags):
        """D-Dbus callback"""
        # Get information on this service
        self.server.ResolveService(interface, protocol, name, stype, domain, avahi.PROTO_UNSPEC, dbus.UInt32(0),
                                   reply_handler = self.__serverResolved, error_handler = self.__resolveError)

    def __serverResolved(self, interface, protocol, name, stype, domain, host, aprotocol, address, port, txt, flags):
        """D-Dbus callback"""
        #print avahi.txt_array_to_string_array(txt)        
        print 'Game detected: ' + str(address) + ':' + str(port) + ' (' + name + ')'
        
        assert(not self.__gamesByName.has_key(name))
        
        game = RemoteGame(name, (address, port))
        self.__gamesByName[name] = game
        self.__games.append(game)
        
        self.onGameDetected(game)
        
    def __resolveError(self, error):
        """D-Dbus callback"""
        print 'Avahi/D-Bus error: ' + repr(error)
        
    def __serviceRemoved(self, interface, protocol, name, stype, domain, flags):
        """D-Dbus callback"""
        print 'Game removed: ' + str(name)
        game = self.__gamesByName.pop(name)
        self.__games.remove(game)
        
        self.onGameRemoved(game)
