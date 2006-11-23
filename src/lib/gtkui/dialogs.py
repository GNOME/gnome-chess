__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os

import gobject
import gtk
import gtk.glade
import gtk.gdk

import gtkui
        
class GtkServerList:
    __gui = None

    def __init__(self, gui):
        self.__gui = gui
        
        self.__servers = []
        view = gui.get_widget('server_list')
        if view is not None:
            store = gtk.ListStore(str, gobject.TYPE_PYOBJECT)
            view.set_model(store)

            cell = gtk.CellRendererText()
            column = gtk.TreeViewColumn('name', cell)
            column.add_attribute(cell, 'text', 0)
            view.append_column(column)
        
    def add(self, name, game):
        """
        """
        view = self.__gui.get_widget('server_list')
        if view is None:
            return
        model = view.get_model()
        iter = model.append()
        model.set(iter, 0, name)
        model.set(iter, 1, game)
        
    def getSelected(self):
        """
        """
        view = self.__gui.get_widget('server_list')
        if view is None:
            return None
        selection = view.get_selection()
        (model, iter) = selection.get_selected()
        
        if iter is None:
            return None
        else:
            return model.get_value(iter, 1)
        
    def remove(self, game):
        """
        """
        view = self.__gui.get_widget('server_list')
        if view is None:
            return
        model = view.get_model()
        
        iter = model.get_iter_first()
        while iter is not None:
            if model.get_value(iter, 1) is game:
                break
            iter = model.iter_next(iter)
        
        if iter is not None:
            model.remove(iter)

class GtkNewGameDialog:
    """
    """    
    # The main UI and the ???
    __mainUI = None
    __gui = None
    
    __moves = None
    
    def __init__(self, mainUI, aiModel, gameName = None,
                 whiteName = None, blackName = None,
                 whiteAI = None, blackAI = None, moves = None):
        """Constructor for a new game dialog.
        
        'mainUI' is the main UI.
        'aiModel' is the AI models to use.
        'gameName' is the name of the game (string) or None if unknown.
        'whiteName' is the name of the white player (string) or None if unknown.
        'blackName' is the name of the white player (string) or None if unknown.
        'whiteAI' is the type of AI the white player is (string) or None if no AI.
        'blackAI' is the type of AI the black player is (string) or None if no AI.
        'moves' is a list of moves (strings) that the have already been made.
        """
        self.__mainUI = mainUI
        self.__moves = moves
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('new_game.glade', 'new_game_dialog', domain = 'glchess')
        self.__gui.signal_autoconnect(self)
        
        # Make all the AI combo boxes use one list of AI types
        for name in ['black_type_combo', 'white_type_combo']:
            widget = self.__gui.get_widget(name)
            if widget is None:
                continue
            
            widget.set_model(aiModel)
            
            cell = gtk.CellRendererPixbuf()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'pixbuf', 1)
            
            cell = gtk.CellRendererText()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'text', 2)
            
            widget.set_active(0)
            
        # Use the supplied properties
        if moves:
            self.__getWidget('new_game_dialog').set_title('Restore game (%i moves)' % len(moves))
        if gameName:
            self.__getWidget('game_name_entry').set_text(gameName)
            
        if whiteName:
            self.__getWidget('white_name_entry').set_text(whiteName)
        if blackName:
            self.__getWidget('black_name_entry').set_text(blackName)
            
        # Configure AIs
        if whiteAI:
            self.__getWidget('white_type_combo').set_active_iter(self.__getAIIter(aiModel, whiteAI))
        if blackAI:
            self.__getWidget('black_type_combo').set_active_iter(self.__getAIIter(aiModel, blackAI))
        
        # Show the dialog
        self.__getWidget('new_game_dialog').show()
        self.__testReady()
        
    # Private methods
    
    def __getAIIter(self, model, name):
        """Get an AI engine.
        
        'name' is the name of the AI engine to find.
        
        Return the iter for this AI or None if no AI of this name.
        """
        # FIXME: I'm sure there is a more efficient way of doing this...
        iter = model.get_iter_first()
        while True:
            if name == model.get_value(iter, 0):
                return iter
            
            iter = model.iter_next(iter)
            if iter is None:
                return None

    def __getWidget(self, name):
        """
        """
        return self.__gui.get_widget(name)
    
    def __getAIType(self, comboBox):
        """
        """
        model = comboBox.get_model()
        iter = comboBox.get_active_iter()
        if iter is None:
            return None
        
        data = model.get(iter, 0)
        return data[0]
    
    def __getWhitePlayer(self):
        """
        """
        name = self.__getWidget('white_name_entry').get_text()
        if len(name) == 0:
            return (None, None)
        aiType = self.__getAIType(self.__getWidget('white_type_combo'))
        return (name, aiType)

    def __getBlackPlayer(self):
        """
        """
        name = self.__getWidget('black_name_entry').get_text()
        if len(name) == 0:
            return (None, None)
        aiType = self.__getAIType(self.__getWidget('black_type_combo'))
        return (name, aiType)

    def __testReady(self):
        ready = True

        # Must have a name for the game
        name = self.__getWidget('game_name_entry').get_text()
        if len(name) == 0:
            ready = False
            
        # Must have two valid players
        white = self.__getWhitePlayer()
        black = self.__getBlackPlayer()
        if white is None or black is None:
            ready = False
                
        # Can only click OK if have enough information
        self.__getWidget('start_button').set_sensitive(ready)
        
    def __startGame(self):
        # FIXME: Game properties
        gameName = self.__getWidget('game_name_entry').get_text()
        allowSpectators = True

        # Get the players
        white = self.__getWhitePlayer()
        black = self.__getBlackPlayer()
        assert(white is not None)
        assert(black is not None)
            
        # Inform the child class
        self.__mainUI.onGameStart(gameName, allowSpectators, white[0], white[1], black[0], black[1], self.__moves)
        
    # Gtk+ signal handlers
    
    def _on_properties_changed(self, widget, *data):
        """Gtk+ callback"""
        self.__testReady()

    def _on_response(self, widget, response_id, data = None):
        """Gtk+ callback"""
        if response_id == gtk.RESPONSE_OK:
            self.__startGame()
        self.__getWidget('new_game_dialog').destroy()

class GtkLoadGameDialog:
    """
    """    
    __mainUI = None
    __gui = None
    
    def __init__(self, mainUI):
        """
        """
        self.__mainUI = mainUI
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('load_game.glade', domain = 'glchess')
        self.__gui.signal_autoconnect(self)
        
        fileChooser = self.__gui.get_widget('filechooserwidget')
        
        # Filter out non PGN files by default
        pgnFilter = gtk.FileFilter()
        pgnFilter.set_name('PGN files')
        pgnFilter.add_pattern('*.pgn')
        fileChooser.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        allFilter.set_name('All files')
        allFilter.add_pattern('*')
        fileChooser.add_filter(allFilter)
        
        dialog = self.__gui.get_widget('game_load_dialog')
        dialog.show()
        
    def __getFilename(self):
        """Get the currently selected filename.
        
        Returns the filename (string) or None if none selected.
        """
        return self.__gui.get_widget('filechooserwidget').get_filename()
    
    def _on_file_changed(self, widget, data = None):
        """Gtk+ callback"""
        name = self.__getFilename()
        if name is None:
            isFile = False
        else:
            isFile = os.path.isfile(name)
        self.__gui.get_widget('open_button').set_sensitive(isFile)
        self.__gui.get_widget('properties_button').set_sensitive(isFile)
        
    def _on_load_game(self, widget, data = None):
        """Gtk+ callback"""
        self.__mainUI.loadGame(self.__getFilename(), False)
        self._on_close(widget, data)
    
    def _on_configure_game(self, widget, data = None):
        """Gtk+ callback"""
        self.__mainUI.loadGame(self.__getFilename(), True)
        self._on_close(widget, data)
        
    def _on_close(self, widget, data = None):
        """Gtk+ callback"""
        self.__gui.get_widget('game_load_dialog').destroy()

class GtkJoinGameDialog:
    """
    """    
    # The main UI and the ???
    __mainUI     = None
    __gui        = None
    
    __serverList = None
    
    __moves      = None
    
    def __init__(self, mainUI, aiModel, gameName = None,
                 localName = None, localAI = None, moves = None):
        """Constructor for a join game dialog.
        
        'mainUI' is the main UI.
        'aiModel' is the AI models to use.
        'gameName' is the name of the game (string) or None if unknown.
        'localName' is the name of the local player (string) or None if unknown.
        'localAI' is the type of AI the local player is (string) or None if no AI.
        'moves' is a list of moves (strings) that the have already been made.
        """
        self.__mainUI = mainUI
        self.__moves = moves
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('new_game.glade', 'join_game_dialog', domain = 'glchess')
        
        # Make all the AI combo boxes use one list of AI types
        combo = self.__gui.get_widget('local_type_combo')
        combo.set_model(aiModel)
        cell = gtk.CellRendererPixbuf()
        combo.pack_start(cell, False)
        combo.add_attribute(cell, 'pixbuf', 1)
        cell = gtk.CellRendererText()
        combo.pack_start(cell, False)
        combo.add_attribute(cell, 'text', 2)
        combo.set_active(0)
            
        # Use the supplied properties
        if moves:
            self.__getWidget('join_game_dialog').set_title('Restore game (%i moves)' % len(moves))
        if gameName:
            self.__getWidget('game_name_entry').set_text(gameName)
            
        # Configure local player
        if localName:
            self.__getWidget('local_name_entry').set_text(whiteName)
        if localAI:
            # FIXME
            self.__getWidget('local_ai_type_combo').set_active_iter(self.__getAIIter(aiModel, localAI))

        # ...
        self.__serverList = GtkServerList(self.__gui)
        view = self.__getWidget('server_list')
        if view is not None:
            selection = view.get_selection()
            selection.connect('changed', self._on_properties_changed)

        # Show the dialog
        self.__gui.signal_autoconnect(self)
        self.__getWidget('join_game_dialog').show()
        self.__testReady()
        
    def addNetworkGame(self, name, game):
        """
        """
        self.__serverList.add(name, game)
        # FIXME: Update?
        
    def removeNetworkGame(self, game):
        """
        """
        self.__serverList.remove(game)
        # FIXME: Update?

    # Private methods
    
    def __getAIIter(self, model, name):
        """Get an AI engine.
        
        'name' is the name of the AI engine to find.
        
        Return the iter for this AI or None if no AI of this name.
        """
        # FIXME: I'm sure there is a more efficient way of doing this...
        iter = model.get_iter_first()
        while True:
            if name == model.get_value(iter, 0):
                return iter
            
            iter = model.iter_next(iter)
            if iter is None:
                return None

    def __getWidget(self, name):
        """
        """
        return self.__gui.get_widget(name)
    
    def __getAIType(self, comboBox):
        """
        """
        model = comboBox.get_model()
        iter = comboBox.get_active_iter()
        if iter is None:
            return None
        
        data = model.get(iter, 0)
        return data[0]
  
    def __getLocalPlayer(self):
        """
        """
        name = self.__getWidget('local_name_entry').get_text()
        if len(name) == 0:
            return (None, None)
        aiType = self.__getAIType(self.__getWidget('local_type_combo'))
        return (name, aiType)

    def __testReady(self):
        ready = True
        # Must have a selected server
        if self.__serverList.getSelected() is None:
            ready = False
            
        # Must have a valid local player
        player = self.__getLocalPlayer()
        if player is None:
            ready = False
                
        # FIXME: Some games do not allow spectators

        # Can only click OK if have enough information
        self.__getWidget('join_button').set_sensitive(ready)
        
    def __startGame(self):
        player = self.__getLocalPlayer()
        assert(player is not None)

        # Joining a server
        server = self.__serverList.getSelected()
        assert(server is not None)
        self.__mainUI.onGameJoin(player[0], player[1], server)
        
    # Gtk+ signal handlers

    def _on_find_servers_button_clicked(self, widget, data=None):
        """Gtk+ callback"""
        host = self.__getWidget('server_entry').get_text()
        if host == '':
            self.__mainUI.onNetworkServerSearch()
        else:
            self.__mainUI.onNetworkServerSearch(host)

    def _on_search_server_entry_changed(self, widget, data=None):
        """Gtk+ callback"""
        # FIXME: Change colour back to default
        pass
    
    def _on_properties_changed(self, widget, *data):
        """Gtk+ callback"""
        self.__testReady()

    def _on_response(self, widget, response_id, data = None):
        """Gtk+ callback"""
        if response_id == gtk.RESPONSE_OK:
            self.__startGame()
        self.__getWidget('join_game_dialog').destroy()

class GtkSaveGameDialog:
    """
    """    
    # The main UI
    __mainUI = None

    # The view that is being saved
    __view = None
    
    # The GUI
    __gui = None
    
    def __init__(self, mainUI, view, path = None):
        """
        """
        self.__mainUI = mainUI
        self.__view = view
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('save_game.glade', domain = 'glchess')
        self.__gui.signal_autoconnect(self)
        
        # Filter out non PGN files by default
        dialog = self.__gui.get_widget('dialog')
        pgnFilter = gtk.FileFilter()
        pgnFilter.set_name('PGN files')
        pgnFilter.add_pattern('*.pgn')
        dialog.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        allFilter.set_name('All files')
        allFilter.add_pattern('*')
        dialog.add_filter(allFilter)
        
        if path is not None:
            dialog.set_current_name(path)
        
    def _on_save(self, widget, data = None):
        """Gtk+ callback"""
        dialog = self.__gui.get_widget('dialog')
        
        # Append .pgn to the end if not provided
        fname = dialog.get_filename()
        if fname[-4:].lower() != '.pgn':
            fname += '.pgn'
        
        self.__mainUI._saveView(self.__view, fname)
        dialog.destroy()

    def _on_close(self, widget, data = None):
        """Gtk+ callback"""
        dialog = self.__gui.get_widget('dialog')
        dialog.destroy()
        self.__mainUI._saveView(self.__view, None)

class GtkErrorDialog:
    """
    """    
    __gui = None
    
    def __init__(self, title, contents):
        """
        """
        self.__gui = gtkui.loadGladeFile('error_dialog.glade', domain = 'glchess')
        self.__gui.signal_autoconnect(self)
        
        self.__gui.get_widget('title_label').set_markup('<b><big>' + title + '</big></b>')
        self.__gui.get_widget('content_label').set_text(contents)
        
        dialog = self.__gui.get_widget('dialog').show_all()

    def _on_close(self, widget, data = None):
        """Gtk+ callback"""
        dialog = self.__gui.get_widget('dialog').destroy()
