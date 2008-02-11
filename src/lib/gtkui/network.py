import gettext

import gobject
import gtk
import pango

import gtkui
import glchess.ui

_ = gettext.gettext

class GtkNetworkGameDialog(glchess.ui.NetworkController):
    """
    """
    # The main UI and the ???
    __mainUI = None
    __gui = None

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
        
        self.profileModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str)
        iter = self.profileModel.append()
        self.profileModel.set(iter, 0, None, 1, 'Disconnected')
        
        widget = self.__gui.get_widget('server_combo')
        widget.set_model(self.profileModel)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 1)
        #FIXME: delay this: widget.set_active_iter(iter)

        # room object, index, name, num players, description, font weight, font style, icon_name
        self.roomModel = gtk.TreeStore(gobject.TYPE_PYOBJECT, int, str, str, str, int, int, str)
        self.firstNonChessIter = None
        self.roomIters = {}
        view = self.__gui.get_widget('room_list')
        view.set_model(self.roomModel)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('#'), cell)
        column.add_attribute(cell, 'text', 3)
        view.append_column(column)
        cell = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'icon-name', 7)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Room'), cell)
        column.add_attribute(cell, 'text', 2)
        column.add_attribute(cell, 'weight', 5)
        column.add_attribute(cell, 'style', 6)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Description'), cell)
        column.add_attribute(cell, 'text', 4)
        #view.append_column(column)
        view.connect('row-activated', self._on_room_changed)

        # player, name, icon
        self.playerModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str, str)
        view = self.__gui.get_widget('player_list')
        view.set_model(self.playerModel)
        cell = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'icon-name', 2)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Player'), cell)
        column.add_attribute(cell, 'text', 1)
        view.append_column(column)

        # table, number, seats, description, seat model, can connect
        self.tableModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str, str, str, gobject.TYPE_PYOBJECT, gobject.TYPE_BOOLEAN)
        self.tableIters = {}
        
        view = self.__gui.get_widget('table_list')
        view.get_selection().connect('changed', self._on_table_selected)
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

        view = self.__gui.get_widget('seat_list')
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn(_('Seat'), cell)
        column.add_attribute(cell, 'text', 2)
        view.append_column(column)
        column = gtk.TreeViewColumn(_('Player'), cell)
        column.add_attribute(cell, 'text', 3)
        column.add_attribute(cell, 'style', 4)
        view.append_column(column)
        
        self.__loadThrobber()

        # Create styles for the buffer
        buffer = self.__gui.get_widget('chat_textview').get_buffer()
        buffer.create_tag('motd', family='Monospace', foreground = 'red')
        buffer.create_tag('chat', family='Monospace')
        #buffer.create_tag('output', family='Monospace', weight = pango.WEIGHT_BOLD)
        #buffer.create_tag('move', family='Monospace', foreground = 'blue')
        buffer.create_tag('info', family='Monospace', foreground = 'gray')
        #buffer.create_tag('error', family='Monospace', foreground = 'red')
        buffer.create_mark('end', buffer.get_end_iter())
        
        mainUI.setTooltipStyle(self.__gui.get_widget('info_panel'))

    # Extended methods
        
    def setVisible(self, isVisible):
        """Called by glchess.ui.NetworkController"""
        widget = self.__gui.get_widget('network_game_dialog')
        if isVisible:
            widget.show()
        else:
            widget.hide()
            
    def setSensitive(self, isSensitive):
        widget = self.__gui.get_widget('controls_box')
        widget.set_sensitive(isSensitive)

    def setError(self, title, description):
        self.__gui.get_widget('info_panel_title').set_markup('<big><b>%s</b></big>' % title)
        self.__gui.get_widget('info_panel_description').set_markup('<i>%s</i>' % description)
        self.__gui.get_widget('info_panel').show()
        
    def clearError(self):
        self.__gui.get_widget('info_panel').hide()

    def addProfile(self, profile, name):
        """Called by glchess.ui.UIController"""
        iter = self.profileModel.append()
        self.profileModel.set(iter, 0, profile, 1, name)

    def setBusy(self, isBusy):
        """Called by glchess.ui.UIController"""
        if self._throbberTimer is not None:
            gobject.source_remove(self._throbberTimer)
            self._throbberTimer = None
        
        # Display animating frames if busy or idle frame if not
        if isBusy:
            self._throbberFrame = 1
            self._throbberTimer = gobject.timeout_add(25, self._updateThrobber)
        else:
            self._throbberFrame = 0
        self._updateThrobber()

    def addRoom(self, index, name, nPlayers, description, room, protocol):
        """Called by glchess.ui.UIController"""
        try:
            (icon, isSupported) = {None:       ('stock_people', True),
                                   'Chess':    ('gnome-glchess', True),
                                   'Reversi':  ('gnome-iagno', False),
                                   'GGZCards': ('gnome-aisleriot', False),
                                   'Gnect':    ('gnome-gnect', False),
                                   'Gnibbles': ('gnome-gnibbles', False),
                                   'Freeciv':  ('civclient', False)}[protocol]
        except KeyError:
            isSupported = False
            icon = None
            
        if isSupported:
            iter = self.roomModel.insert_before(None, self.firstNonChessIter)
            style = pango.STYLE_NORMAL
        else:
            iter = self.roomModel.append(None)
            if self.firstNonChessIter is None:
                self.firstNonChessIter = iter
            style = pango.STYLE_ITALIC

        self.roomIters[room] = iter
        self.roomModel.set(iter, 0, room, 1, index, 2, name, 3, nPlayers, 4, description, 5, pango.WEIGHT_NORMAL, 6, style, 7, icon)

    def enterRoom(self, room):
        """Called by glchess.ui.UIController"""
        for (r, iter) in self.roomIters.iteritems():
            if r is room:
                weight = pango.WEIGHT_BOLD
            else:
                weight = pango.WEIGHT_NORMAL
            self.roomModel.set(iter, 5, weight)

    def updateRoom(self, room, nPlayers):
        try:
            iter = self.roomIters[room]
        except KeyError:
            print 'Unknown room!'
            return
        self.roomModel.set(iter, 3, nPlayers)
    
    def removeRoom(self, room):
        """Called by glchess.ui.UIController"""
        iter = self.roomModel.get_iter_first()
        while iter is not None:
            if table is self.roomModel.get_value(iter, 0):
                self.roomModel.remove(iter)
                return
            iter = self.roomModel.iter_next(iter)

    def clearRooms(self):
        """Called by glchess.ui.UIController"""
        self.firstNonChessIter = None
        self.roomIters = {}
        self.roomModel.clear()
    
    def updateTable(self, table, name, seats, description, canConnect):
        """Called by glchess.ui.UIController"""
        try:
            iter = self.tableIters[table]
            seatModel = self.tableModel.get_value(iter, 4)
        except KeyError:
            iter = self.tableModel.append()
            self.tableIters[table] = iter
            seatModel = gtk.ListStore(int, str, str, str, int) # number, type, name, occupant, font style
        self.tableModel.set(iter, 0, table, 1, name, 2, seats, 3, description, 4, seatModel, 5, canConnect)

    def updateSeat(self, table, number, type, name):
        """Called by glchess.ui.UIController"""
        iter = self.tableIters[table]
        seatModel = self.tableModel.get_value(iter, 4)
        iter = seatModel.get_iter_first()
        while iter is not None:
            if number == seatModel.get_value(iter, 0):
                break
            iter = seatModel.iter_next(iter)
        if iter is None:
            iter = seatModel.append()
            
        if number == 0:
            seatName = _('White')
        elif number == 1:
            seatName = _('Black')
        else:
            seatName = _('Spectator')

        style = pango.STYLE_ITALIC
        occupant = name
        if type == 'player':
            style = pango.STYLE_NORMAL
        elif type == 'reserved':
            occupant = _('Reserved for %s' % name)
        elif type == 'open':
            occupant = _('Seat empty')
        elif type == 'bot':
            occupant = _('AI (%s)' % name)

        seatModel.set(iter, 0, number, 1, type, 2, seatName, 3, occupant, 4, style)

    def removeTable(self, table):
        """Called by glchess.ui.UIController"""
        iter = self.tableIters[table]
        self.tableModel.remove(iter)
            
    def joinTable(self, table):
        """Called by glchess.ui.UIController"""
        gameFrame = self.__gui.get_widget('game_frame')
        roomFrame = self.__gui.get_widget('room_frame')
        if table is None:
            gameFrame.hide()
            roomFrame.show()
        else:
            iter = self.tableIters[table]
            
            seatModel = self.tableModel.get_value(iter, 4)
            self.__gui.get_widget('seat_list').set_model(seatModel)
            
            name = self.tableModel.get_value(iter, 3)
            self.__gui.get_widget('game_name_label').set_text(name)
            roomFrame.hide()
            gameFrame.show()

    def clearTables(self):
        """Called by glchess.ui.UIController"""
        self.tableIters = {}
        self.tableModel.clear()

    def addPlayer(self, player, name, icon):
        """Called by glchess.ui.UIController"""
        iter = self.playerModel.append()
        self.playerModel.set(iter, 0, player, 1, name, 2, icon)

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
        view = self.__gui.get_widget('chat_textview')
        scroll = self.__gui.get_widget('chat_scroll_window')
        adj = scroll.get_vadjustment()
        atBottom = adj.value >= adj.upper - adj.page_size
        buffer = view.get_buffer()
        mark = buffer.get_mark('end')
        buffer.insert_with_tags_by_name(buffer.get_iter_at_mark(mark), text, style)
        if atBottom:
            view.scroll_mark_onscreen(mark)

    def close(self):
        """Called by glchess.ui.UIController"""
        self.__gui.get_widget('network_game_dialog').hide()        

    # Private methods
    
    def __loadThrobber(self):
        self._throbberTimer = None
        theme = gtk.icon_theme_get_default()
        size = 32
        self._throbberFrames = []
        
        icon = theme.load_icon('process-idle', size, 0)
        if icon is not None:
            self._throbberFrames.append(icon)

        icon = theme.load_icon('process-working', size, 0)
        if icon is not None:
            # If a smaller icon was received than expected then use that size
            height = icon.get_height()
            width = icon.get_width()
            size = min(size, height, width)

            for i in xrange(height / size):
                for j in xrange(width / size):
                    frame = icon.subpixbuf(j * size, i * size, size, size)
                    self._throbberFrames.append(frame)
                
        # Display idle frame
        self._throbberFrame = 0
        self._updateThrobber()

    def _updateThrobber(self):
        widget = self.__gui.get_widget('throbber_image')
        try:
            icon = self._throbberFrames[self._throbberFrame]
        except IndexError:
            pass
        else:
            widget.set_from_pixbuf(icon)
        
        # Move to next frame restarting animation after idle frame
        self._throbberFrame += 1
        if self._throbberFrame >= len(self._throbberFrames):
            self._throbberFrame = 1
        return True
    
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
    
    def _on_table_selected(self, selection):
        (model, iter) = selection.get_selected()
        if iter is None:
            isSensitive = False
        else:
            isSensitive = model.get_value(iter, 5)

        widget = self.__gui.get_widget('table_join_button')
        widget.set_sensitive(isSensitive)
        
    def _on_table_list_activated():
        pass
    
    def _on_server_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        (profile,) = model.get(iter, 0)
        self.feedback.setProfile(profile)
    
    def _on_chat_entry_activate(self, widget):
        """Gtk+ callback"""
        text = widget.get_text()
        widget.set_text('')
        self.feedback.sendChat(text)
        
    def _on_delete(self, widget, event):
        # Hide; don't delete this window
        return True

    def _on_response(self, widget, response_id):
        """Gtk+ callback"""
        self.__gui.get_widget('network_game_dialog').hide()

    def _on_room_changed(self, widget, path, column):
        """Gtk+ callback"""
        # FIXME: Only if allowed to enter room (state machine)
        model = self.__gui.get_widget('room_list').get_model()
        iter = model.get_iter(path)
        if iter is None:
            return True
        room = model.get_value(iter, 0)
        if room is not None:
            self.feedback.enterRoom(room)
        return True

    def _on_table_join_button_clicked(self, widget):
        """Gtk+ callback"""
        (model, iter) = self.__gui.get_widget('table_list').get_selection().get_selected()
        if iter is None:
            return
        table = model.get_value(iter, 0)
        self.feedback.joinTable(table)

    def _on_table_leave_button_clicked(self, widget):
        """Gtk+ callback"""
        self.feedback.leaveTable()

    def _on_table_new_button_clicked(self, widget):
        """Gtk+ callback"""
        self.feedback.startTable()
