import gettext

import gobject
import gtk

import gtkui
import glchess.ui

_ = gettext.gettext

class GtkNetworkGameDialog(glchess.ui.NetworkController):
    """
    """
    # The main UI and the ???
    __mainUI = None
    __gui = None

    __customName = False
    __checking = False

    def __init__(self, mainUI, feedback, aiModel):
        """Constructor for a new game dialog.
        
        'mainUI' is the main UI.
        'feedback' is the object to feedback events with.
        'aiModel' is the AI models to use.
        """
        self.__mainUI = mainUI
        self.feedback = feedback

        # Load the UI
        self.__gui = gtkui.loadGladeFile('network_game.glade', 'network_game_dialog')
        self.__gui.signal_autoconnect(self)

        self.roomModel = gtk.TreeStore(gobject.TYPE_PYOBJECT, int, str, str, str)
        self.otherRoomIter = None
        view = self.__gui.get_widget('room_list')
        view.set_model(self.roomModel)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Room'), cell)
        column.add_attribute(cell, 'text', 2)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Players'), cell)
        column.add_attribute(cell, 'text', 3)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Description'), cell)
        column.add_attribute(cell, 'text', 4)
        #view.append_column(column)
        
        selection = view.get_selection()
        selection.connect('changed', self._on_room_changed)

        self.playerModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str)
        view = self.__gui.get_widget('player_list')
        view.set_model(self.playerModel)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Player'), cell)
        column.add_attribute(cell, 'text', 1)
        view.append_column(column)

        self.tableModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str, str, str)
        view = self.__gui.get_widget('table_list')
        view.set_model(self.tableModel)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Table'), cell)
        column.add_attribute(cell, 'text', 1)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Seats'), cell)
        column.add_attribute(cell, 'text', 2)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Description'), cell)
        column.add_attribute(cell, 'text', 3)
        view.append_column(column)
        
        selection = view.get_selection()
        selection.connect('changed', self._on_table_changed)

        # Create styles for the buffer
        buffer = self.__gui.get_widget('chat_textview').get_buffer()
        buffer.create_tag('chat', family='Monospace')
        #buffer.create_tag('output', family='Monospace', weight = pango.WEIGHT_BOLD)
        #buffer.create_tag('move', family='Monospace', foreground = 'blue')
        buffer.create_tag('info', family='Monospace', foreground = 'gray')
        #buffer.create_tag('error', family='Monospace', foreground = 'red')

        # Show the dialog
        self.__gui.get_widget('network_game_dialog').show()

    # Extended methods

    def addRoom(self, index, name, nPlayers, description, room, isChess = True):
        """Called by glchess.ui.UIController"""
        if isChess:
            iter = self.roomModel.insert_before(None, self.otherRoomIter)
        else:
            if self.otherRoomIter is None:
                self.otherRoomIter = self.roomModel.append(None)
                self.roomModel.set(self.otherRoomIter, 0, None, 1, -1, 2, _('Non-chess rooms'), 3, '', 4, '')
            parent = self.otherRoomIter
            iter = self.roomModel.append(self.otherRoomIter)

        self.roomModel.set(iter, 0, room, 1, index, 2, name, 3, nPlayers, 4, description)

    def updateRoom(self, room, nPlayers):
        iter = self.roomModel.get_iter_first()
        while iter is not None:
            if room is self.roomModel.get_value(iter, 0):
                break
            iter = self.roomModel.iter_next(iter)
        if iter is not None:
            self.roomModel.set(iter, 3, nPlayers)
    
    def removeRoom(self, room):
        """Called by glchess.ui.UIController"""
        iter = self.roomModel.get_iter_first()
        while iter is not None:
            if table is self.roomModel.get_value(iter, 0):
                self.roomModel.remove(iter)
                return
            iter = self.roomModel.iter_next(iter)
    
    def updateTable(self, table, name, seats, description):
        """Called by glchess.ui.UIController"""
        iter = self.tableModel.get_iter_first()
        while iter is not None:
            if table is self.tableModel.get_value(iter, 0):
                break
            iter = self.tableModel.iter_next(iter)
        if iter is None:
            iter = self.tableModel.append()
        self.tableModel.set(iter, 0, table, 1, name, 2, seats, 3, description)

    def removeTable(self, table):
        """Called by glchess.ui.UIController"""
        iter = self.tableModel.get_iter_first()
        while iter is not None:
            if table is self.tableModel.get_value(iter, 0):
                self.tableModel.remove(iter)
                return
            iter = self.tableModel.iter_next(iter)

    def clearTables(self):
        """Called by glchess.ui.UIController"""
        self.tableModel.clear()

    def addPlayer(self, name, player):
        """Called by glchess.ui.UIController"""
        iter = self.playerModel.append()
        self.playerModel.set(iter, 0, player, 1, name)

    def removePlayer(self, player):
        """Called by glchess.ui.UIController"""
        iter = self.playerModel.get_iter_first()
        while iter is not None:
            if player is self.playerModel.get_value(iter, 0):
                self.playerModel.remove(iter)
                return
            iter = self.playerModel.iter_next(iter)
    
    def clearPlayers(self):
        """Called by glchess.ui.UIController"""
        self.playerModel.clear()
    
    def addText(self, text, style):
        """Called by glchess.ui.UIController"""
        buffer = self.__gui.get_widget('chat_textview').get_buffer()
        buffer.insert_with_tags_by_name(buffer.get_end_iter(), text, style)

    def close(self):
        """Called by glchess.ui.UIController"""
        self.__gui.get_widget('network_game_dialog').hide()        

    # Private methods
    
    def __setCombo(self, comboName, key):
        widget = self.__gui.get_widget(comboName)
        iter = self.__getIter(widget.get_model(), key)
        if iter is not None:
            widget.set_active_iter(iter)
    
    def __getIter(self, model, key, default = None):
        """
        """
        iter = model.get_iter_first()
        while iter:
            if model.get_value(iter, 0) == key:
                return iter

            iter = model.iter_next(iter)
        return default
                
    def __getComboData(self, comboBox, index):
        """
        """
        model = comboBox.get_model()
        iter = comboBox.get_active_iter()
        if iter is None:
            return None
        
        data = model.get(iter, index)
        return data[0]
       
    def __startGame(self):
        game = glchess.ui.Game()
        game.name = self.__gui.get_widget('game_name_entry').get_text()
        game.allowSpectators = True
        
        # Get the players
        game.white.type  = self.__getComboData(self.__gui.get_widget('white_type_combo'), 0)
        if game.white.type is '':
            game.white.name = _('White')
        else:
            game.white.name = self.__getComboData(self.__gui.get_widget('white_type_combo'), 2)
        game.white.level = self.__getComboData(self.__gui.get_widget('white_difficulty_combo'), 0)
        game.black.type  = self.__getComboData(self.__gui.get_widget('black_type_combo'), 0)
        if game.black.type == '':
            game.black.name = _('Black')
        else:
            game.black.name = self.__getComboData(self.__gui.get_widget('black_type_combo'), 2)
        game.black.level = self.__getComboData(self.__gui.get_widget('black_difficulty_combo'), 0)

        game.duration = self.__getComboData(self.__gui.get_widget('time_combo'), 1)
        if game.duration < 0:
            multplier = self.__getComboData(self.__gui.get_widget('custom_time_units_combo'), 1)
            game.duration = self.__getComboData(self.__gui.get_widget('custom_time_spin'), 1) * multiplier
            
        # Save properties
        glchess.config.set('new_game_dialog/white/type', game.white.type)
        glchess.config.set('new_game_dialog/white/difficulty', game.white.level)
        glchess.config.set('new_game_dialog/black/type', game.black.type)
        glchess.config.set('new_game_dialog/black/difficulty', game.black.level)

        # Inform the child class
        self.__mainUI.feedback.onGameStart(game)
        
    # Gtk+ signal handlers
    
    def _on_game_name_edited(self, widget):
        """Gtk+ callback"""
        if self.__checking:
            return
        self.__customName = len(widget.get_text()) != 0

    def _on_chat_entry_activate(self, widget):
        """Gtk+ callback"""
        text = widget.get_text()
        widget.set_text('')
        self.feedback.sendChat(text)

    def _on_response(self, widget, response_id):
        """Gtk+ callback"""
        if response_id == gtk.RESPONSE_OK:
            self.__startGame()
        self.__gui.get_widget('new_game_dialog').destroy()

    def _on_room_changed(self, widget):
        """Gtk+ callback"""
        (model, iter) = self.__gui.get_widget('room_list').get_selection().get_selected()
        if iter is None:
            return
        room = model.get_value(iter, 0)
        if room is not None:
            self.feedback.joinRoom(room)

    def _on_table_changed(self, widget):
        """Gtk+ callback"""
        (model, iter) = self.__gui.get_widget('table_list').get_selection().get_selected()
        if iter is None:
            return
        table = model.get_value(iter, 0)
        self.feedback.joinTable(table)
        
    def _on_table_join_button_clicked(self, widget):
        """Gtk+ callback"""
        pass

    def _on_table_new_button_clicked(self, widget):
        """Gtk+ callback"""
        self.feedback.startTable()
