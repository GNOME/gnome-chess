# -*- coding: utf-8 -*-
import gettext

import gobject
import gtk
import pango

import gtkui
import glchess.ui

_ = gettext.gettext

class GtkNetworkAddDialog:

    def __init__(self, networkDialog, parent):
        self.__networkDialog = networkDialog

        # Load the UI
        self.__gui = gtkui.loadUIFile('network_new_server.ui')
        self.__gui.connect_signals(self)
        
        self.__gui.get_object('add_account_dialog').set_transient_for(parent)
        
        # FIXME: Hard-coded servers       
        # name, host, port
        self.serverModel = gtk.ListStore(str, str, int)
        # Translators: Add Network Profile Dialog: Connect to the GGZ Gaming Zone server (the default)
        self.serverModel.set(self.serverModel.append(), 0, _("GGZ Gaming Zone"), 1, "gnome.ggzgamingzone.org", 2, 5688)
        # Translators: Add Network Profile Dialog: Use a custom server
        self.serverModel.set(self.serverModel.append(), 0, _("Custom"), 1, "", 2, 5688)
        
        widget = self.__gui.get_object('server_combo')
        widget.set_model(self.serverModel)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)
        widget.set_model(self.serverModel)
        widget.set_active(0)

    def setVisible(self, isVisible):
        widget = self.__gui.get_object('add_account_dialog')
        if isVisible:
            widget.present()
        else:
            widget.hide()
            self.clear()
            
    def clear(self):
        self.__gui.get_object('server_combo').set_active(0)
        self.__gui.get_object('username_entry').set_text('')        
            
    def _on_server_changed(self, widget):
        widget = self.__gui.get_object('server_combo')
        model = widget.get_model()
        iter = widget.get_active_iter()
        (host,) = model.get(iter, 1)
        (port,) = model.get(iter, 2)
        self.__gui.get_object('host_entry').set_text(host)
        self.__gui.get_object('port_spin').set_value(port)
        table = self.__gui.get_object('custom_server_table')
        if host == '':
            table.show()
        else:
            table.hide()
            
    def have_data(self):
        username = self.__gui.get_object('username_entry').get_text()
        host = self.__gui.get_object('host_entry').get_text()
        return username != '' and host != ''

    def _on_input_changed(self, widget):
        self.__gui.get_object('add_button').set_sensitive(self.have_data())

    def _on_username_activate(self, widget):
        if self.have_data():
            self._on_response(None, gtk.RESPONSE_OK)

    def _on_response(self, widget, response_id):
        username = self.__gui.get_object('username_entry').get_text()
        host = self.__gui.get_object('host_entry').get_text()
        port = self.__gui.get_object('port_spin').get_value_as_int()
        name = '%s@%s' % (username, host) # FIXME
        
        if response_id == gtk.RESPONSE_OK:
            profile = self.__networkDialog.feedback.addProfile((name, username, host, port))
            self.__networkDialog.addProfile(profile, profile.name, useNow = True)
        
        self.__gui.get_object('add_account_dialog').hide()
        self.clear()
            
    def _on_delete(self, widget, event):
        # Hide; don't delete this window
        return True

class GtkNetworkGameDialog(glchess.ui.NetworkController):
    """
    """

    def __init__(self, mainUI, feedback):
        """Constructor for a new game dialog.
        
        'mainUI' is the main UI.
        'feedback' is the object to feedback events with.
        """
        self.__mainUI = mainUI
        self.feedback = feedback

        # Load the UI
        self.__gui = gtkui.loadUIFile('network_game.ui')
        self.__gui.connect_signals(self)
        
        # Selected profile
        self.__profile = None
        
        self.profileModel = gtk.ListStore(gobject.TYPE_PYOBJECT, gobject.TYPE_PYOBJECT, str)
        # Translators: Server Combo Box: Not connected to a server
        self.profileModel.set(self.profileModel.append(), 0, None, 1, self._set_profile, 2, _('Disconnected'))
        self.profileModelSuffixCount = 0
        self.profileModel.set(self.profileModel.append(), 1, None)
        self.profileModelSuffixCount += 1
        # Translators: Server Combo Box: Add new profile
        self.profileModel.set(self.profileModel.append(), 0, None, 1, self._new_profile, 2, _('New profile...'))
        self.profileModelSuffixCount += 1

        widget = self.__gui.get_object('server_combo')
        widget.set_model(self.profileModel)
        widget.set_active(0)
        widget.set_row_separator_func(self._is_profile_model_separator)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 2)

        # room object, index, name, num players, description, font weight, font style, icon_name
        self.roomModel = gtk.TreeStore(gobject.TYPE_PYOBJECT, int, str, str, str, int, int, str)
        self.firstNonChessIter = None
        self.roomIters = {}
        view = self.__gui.get_object('room_list')
        view.set_model(self.roomModel)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'text', 3)
        view.append_column(column)
        cell = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'icon-name', 7)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'text', 2)
        column.add_attribute(cell, 'weight', 5)
        column.add_attribute(cell, 'style', 6)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'text', 4)
        #view.append_column(column)
        view.connect('row-activated', self._on_room_changed)

        # player, name, icon
        self.playerModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str, str)
        view = self.__gui.get_object('player_list')
        view.set_model(self.playerModel)
        cell = gtk.CellRendererPixbuf()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'icon-name', 2)
        view.append_column(column)
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn('', cell)
        column.add_attribute(cell, 'text', 1)
        view.append_column(column)

        # table, number, seats, description, seat model, can connect
        self.tableModel = gtk.ListStore(gobject.TYPE_PYOBJECT, str, str, str, gobject.TYPE_PYOBJECT, gobject.TYPE_BOOLEAN)
        self.tableIters = {}
        
        view = self.__gui.get_object('table_list')
        view.get_selection().connect('changed', self._on_table_selected)
        view.set_model(self.tableModel)
        
        cell = gtk.CellRendererText()
        # Translators: Available GGZ Tables: Table name column title
        column = gtk.TreeViewColumn(_('Table'), cell)
        column.add_attribute(cell, 'text', 1)
        view.append_column(column)
        cell = gtk.CellRendererText()
        # Translators: Available GGZ Tables: Seat status column title
        column = gtk.TreeViewColumn(_('Seats'), cell)
        column.add_attribute(cell, 'text', 2)
        view.append_column(column)
        cell = gtk.CellRendererText()
        # Translators: Available GGZ Tables: Table description column title        
        column = gtk.TreeViewColumn(_('Description'), cell)
        column.add_attribute(cell, 'text', 3)
        view.append_column(column)

        view = self.__gui.get_object('seat_list')
        cell = gtk.CellRendererText()
        # Translators: Current GGZ Table: Seat name column title
        column = gtk.TreeViewColumn(_('Seat'), cell)
        column.add_attribute(cell, 'text', 2)
        view.append_column(column)
        # Translators: Current GGZ Table: Player name column title        
        column = gtk.TreeViewColumn(_('Player'), cell)
        column.add_attribute(cell, 'text', 3)
        column.add_attribute(cell, 'style', 4)
        view.append_column(column)
        
        self.__loadThrobber()

        # Create styles for the buffer
        buffer = self.__gui.get_object('chat_textview').get_buffer()
        buffer.create_tag('motd', family='Monospace', foreground = 'red')
        buffer.create_tag('chat', family='Monospace')
        #buffer.create_tag('output', family='Monospace', weight = pango.WEIGHT_BOLD)
        #buffer.create_tag('move', family='Monospace', foreground = 'blue')
        buffer.create_tag('info', family='Monospace', foreground = 'gray')
        #buffer.create_tag('error', family='Monospace', foreground = 'red')
        buffer.create_mark('end', buffer.get_end_iter())
        
        mainUI.setTooltipStyle(self.__gui.get_object('info_panel'))
        self.__addProfileDialog = GtkNetworkAddDialog(self, self.__gui.get_object('network_game_dialog'))

    # Extended methods
        
    def setVisible(self, isVisible):
        """Called by glchess.ui.NetworkController"""
        widget = self.__gui.get_object('network_game_dialog')
        if isVisible:
            widget.present()
            
            # Prompt for new profile if none configured
            # FIXME: Make this clearer this is the count of non-profile elements in the combo
            if len(self.profileModel) <= (self.profileModelSuffixCount + 1):
                self.__addProfileDialog.setVisible(True)
        else:
            self.__addProfileDialog.setVisible(False)
            self.__editProfileDialog.setVisible(False)            
            widget.hide()
            
    def setSensitive(self, isSensitive):
        widget = self.__gui.get_object('controls_box')
        widget.set_sensitive(isSensitive)

    def setError(self, title, description):
        self.__gui.get_object('info_panel_title').set_markup('<big><b>%s</b></big>' % title)
        self.__gui.get_object('info_panel_description').set_markup('<i>%s</i>' % description)
        self.__gui.get_object('info_panel').show()
        
    def clearError(self):
        self.__gui.get_object('info_panel').hide()

    def addProfile(self, profile, name, useNow = False):
        """Called by glchess.ui.UIController"""
        iter = self.profileModel.insert(len(self.profileModel) - self.profileModelSuffixCount)
        self.profileModel.set(iter, 0, profile, 1, self._set_profile, 2, name)        
        if self.__profile is None and useNow:
            self.__gui.get_object('server_combo').set_active_iter(iter)

    def setBusy(self, isBusy):
        """Called by glchess.ui.UIController"""
        if self._throbberTimer is not None:
            gobject.source_remove(self._throbberTimer)
            self._throbberTimer = None

        # Disable room buttons when busy
        widget = self.__gui.get_object('room_button_box')
        widget.set_sensitive(not isBusy)
        
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
            if room is self.roomModel.get_value(iter, 0):
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
            # Translators: GGZ seat is occupied by the white player
            seatName = _('White')
        elif number == 1:
            # Translators: GGZ seat is occupied by the black player            
            seatName = _('Black')
        else:
            # Translators: GGZ seat is occupied by a spectator
            seatName = _('Spectator')

        style = pango.STYLE_ITALIC
        occupant = name
        if type == 'player':
            style = pango.STYLE_NORMAL
        elif type == 'reserved':
            # Translators: GGZ seat status: This seat is reserved. %s is replaced with
            # the name of the player the seat is reserved for.
            occupant = _('Reserved for %s') % name
        elif type == 'open':
            # Translators: GGZ seat status: This seat is not taken
            occupant = _('Seat empty')
        elif type == 'bot':
            # Translators: GGZ seat status: This seat contains an AI player.
            # %s is replaced with the name of the AI.
            occupant = _('AI (%s)') % name

        seatModel.set(iter, 0, number, 1, type, 2, seatName, 3, occupant, 4, style)

    def removeTable(self, table):
        """Called by glchess.ui.UIController"""
        iter = self.tableIters[table]
        self.tableModel.remove(iter)
            
    def joinTable(self, table):
        """Called by glchess.ui.UIController"""
        gameFrame = self.__gui.get_object('game_frame')
        roomFrame = self.__gui.get_object('room_frame')
        if table is None:
            gameFrame.hide()
            roomFrame.show()
        else:
            iter = self.tableIters[table]
            
            seatModel = self.tableModel.get_value(iter, 4)
            self.__gui.get_object('seat_list').set_model(seatModel)
            
            name = self.tableModel.get_value(iter, 3)
            self.__gui.get_object('game_name_label').set_text(name)
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
        view = self.__gui.get_object('chat_textview')
        scroll = self.__gui.get_object('chat_scroll_window')
        adj = scroll.get_vadjustment()
        atBottom = adj.value >= adj.upper - adj.page_size
        buffer = view.get_buffer()
        mark = buffer.get_mark('end')
        buffer.insert_with_tags_by_name(buffer.get_iter_at_mark(mark), text, style)
        if atBottom:
            view.scroll_mark_onscreen(mark)

    def clearText(self):
        buffer = self.__gui.get_object('chat_textview').get_buffer()
        buffer.delete(buffer.get_start_iter(), buffer.get_end_iter())

    def close(self):
        """Called by glchess.ui.UIController"""
        self.__gui.get_object('network_game_dialog').hide()        

    # Private methods
    
    def __loadThrobber(self):
        self._throbberTimer = None
        theme = gtk.icon_theme_get_default()
        size = 32
        self._throbberFrames = []
        
        try:
            icon = theme.load_icon('process-idle', size, 0)
        except gobject.GError:
            pass
        else:
            self._throbberFrames.append(icon)

        try:
            icon = theme.load_icon('process-working', size, 0)
        except gobject.GError:
            pass
        else:
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
        widget = self.__gui.get_object('throbber_image')
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
        widget = self.__gui.get_object(comboName)
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
        game.name = self.__gui.get_object('game_name_entry').get_text()
        game.allowSpectators = True
        
        # Get the players
        game.white.type  = self.__getComboData(self.__gui.get_object('white_type_combo'), 0)
        if game.white.type == '':
            game.white.name = _('White')
        else:
            game.white.name = self.__getComboData(self.__gui.get_object('white_type_combo'), 2)
        game.white.level = self.__getComboData(self.__gui.get_object('white_difficulty_combo'), 0)
        game.black.type  = self.__getComboData(self.__gui.get_object('black_type_combo'), 0)
        if game.black.type == '':
            game.black.name = _('Black')
        else:
            game.black.name = self.__getComboData(self.__gui.get_object('black_type_combo'), 2)
        game.black.level = self.__getComboData(self.__gui.get_object('black_difficulty_combo'), 0)

        game.duration = self.__getComboData(self.__gui.get_object('time_combo'), 1)
        if game.duration < 0:
            multiplier = self.__getComboData(self.__gui.get_object('custom_time_units_combo'), 1)
            game.duration = self.__getComboData(self.__gui.get_object('custom_time_spin'), 1) * multiplier
            
        # Save properties
        glchess.config.set('new_game_dialog/white/type', game.white.type)
        glchess.config.set('new_game_dialog/white/difficulty', game.white.level)
        glchess.config.set('new_game_dialog/black/type', game.black.type)
        glchess.config.set('new_game_dialog/black/difficulty', game.black.level)

        # Inform the child class
        self.__mainUI.feedback.onGameStart(game)
        
    def _is_profile_model_separator(self, model, iter):
        return model.get(iter, 1)[0] is None

    def _set_profile(self, profile):
        if profile != self.__profile:
            self.__profile = profile
            self.feedback.setProfile(profile)
            
    def __selectActiveProfile(self):
        iter = self.profileModel.get_iter_first()
        while iter is not None:
            if self.__profile == self.profileModel.get_value(iter, 0):
                break
            iter = self.profileModel.iter_next(iter)
        self.__gui.get_object('server_combo').set_active_iter(iter)

    def _new_profile(self, profile):
        self.__selectActiveProfile()
        self.__addProfileDialog.setVisible(True)
        
    # Gtk+ signal handlers
    
    def _on_table_selected(self, selection):
        (model, iter) = selection.get_selected()
        if iter is None:
            isSensitive = False
        else:
            isSensitive = model.get_value(iter, 5)

        widget = self.__gui.get_object('table_join_button')
        widget.set_sensitive(isSensitive)
        
    def _on_table_list_activated(self):
        pass
    
    def _on_server_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        (method,) = model.get(iter, 1)
        (profile,) = model.get(iter, 0)
        method(profile)

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
        self.__gui.get_object('network_game_dialog').hide()

    def _on_room_changed(self, widget, path, column):
        """Gtk+ callback"""
        # FIXME: Only if allowed to enter room (state machine)
        model = self.__gui.get_object('room_list').get_model()
        iter = model.get_iter(path)
        if iter is None:
            return True
        room = model.get_value(iter, 0)
        if room is not None:
            self.feedback.enterRoom(room)
        return True

    def _on_table_join_button_clicked(self, widget):
        """Gtk+ callback"""
        (model, iter) = self.__gui.get_object('table_list').get_selection().get_selected()
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
