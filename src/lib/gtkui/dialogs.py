__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
from gettext import gettext as _

import gobject
import gtk
import gtk.glade
import gtk.gdk

import gtkui
import glchess.ui

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
    def __init__(self, mainUI, aiModel, game = None):
        """Constructor for a new game dialog.
        
        'mainUI' is the main UI.
        'aiModel' is the AI models to use.
        'game' is the game properties to use (ui.Game).
        """
        self.__mainUI = mainUI
        self.game = game
        
        self.__checking = True
        self.__customName = False

        # Load the UI
        self.__gui = gtkui.loadGladeFile('new_game.glade', 'new_game_dialog')
        self.__gui.signal_autoconnect(self)

        self.window = self.__gui.get_widget('new_game_dialog')
        self.window.set_transient_for(mainUI.mainWindow)

        # Set style of error panel
        mainUI.setTooltipStyle(self.__gui.get_widget('info_box'))
        
        # Make all the labels the same width
        group = gtk.SizeGroup(gtk.SIZE_GROUP_HORIZONTAL)
        i = 1
        while True:
            widget = self.__gui.get_widget('label%i' % i)
            if widget is None:
                break
            group.add_widget(widget)
            i += 1

        # Make all the images the same width
        group = gtk.SizeGroup(gtk.SIZE_GROUP_HORIZONTAL)
        i = 1
        while True:
            widget = self.__gui.get_widget('image%i' % i)
            if widget is None:
                break
            group.add_widget(widget)
            i += 1
            
        # Create model for game time
        defaultTime = glchess.config.get('new_game_dialog/move_time')
        times = [(_('Unlimited'),       0),
                 (_('One minute'),     60),
                 (_('Five minutes'),  300),
                 (_('30 minutes'),   1800),
                 (_('One hour'),     3600),
                 (_('Custom'),         -1)]
        timeModel = gtk.ListStore(str, int)
        activeIter = None
        for (name, time) in times:
            iter = timeModel.append()
            if time == defaultTime:
                activeIter = iter
            timeModel.set(iter, 0, name, 1, time)

        widget = self.__gui.get_widget('time_combo')
        widget.set_model(timeModel)
        if activeIter is None:
            widget.set_active_iter(iter)
        else:
            widget.set_active_iter(activeIter)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)

        model = gtk.ListStore(str, int)
        units = [(_('seconds'),  1),
                 (_('minutes'), 60),
                 (_('hours'), 3600)]
        for (name, multiplier) in units:
            iter = model.append()
            model.set(iter, 0, name, 1, multiplier)

        # FIXME: Handle time units
        self.__gui.get_widget('custom_time_spin').set_value(defaultTime)

        widget = self.__gui.get_widget('custom_time_units_combo')
        widget.set_model(model)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)
        widget.set_active(0)

        # Create the model for difficulty options
        levelModel = gtk.ListStore(str, str, str)
        levels = [('easy',   _('Easy'),   'weather-few-clouds'),
                  ('normal', _('Normal'), 'weather-overcast'),
                  ('hard',   _('Hard'),   'weather-storm')]
        for (key, label, icon) in levels:
            iter = levelModel.append()
            levelModel.set(iter, 0, key, 1, icon, 2, label)

        # Set the difficulty settings
        for name in ['black_difficulty_combo', 'white_difficulty_combo']:
            widget = self.__gui.get_widget(name)
            if widget is None:
                continue
            
            widget.set_model(levelModel)
            
            cell = gtk.CellRendererPixbuf()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'icon-name', 1)
            
            cell = gtk.CellRendererText()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'text', 2)
            
            widget.set_active(1)

        # Make all the AI combo boxes use one list of AI types
        firstAIIndex = min(1, len(aiModel))
        for (name, index) in [('white_type_combo', 0), ('black_type_combo', firstAIIndex)]:
            widget = self.__gui.get_widget(name)
            if widget is None:
                continue
            
            widget.set_model(aiModel)
            
            cell = gtk.CellRendererPixbuf()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'icon-name', 1)
            
            cell = gtk.CellRendererText()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'text', 2)
            
            widget.set_active(index)

        # Configure AIs
        try:
            whiteType = glchess.config.get('new_game_dialog/white/type')
            whiteLevel = glchess.config.get('new_game_dialog/white/difficulty')
            blackType = glchess.config.get('new_game_dialog/black/type')
            blackLevel = glchess.config.get('new_game_dialog/black/difficulty')
        except glchess.config.Error:
            pass
        else:
            self.__setCombo('white_type_combo', whiteType)
            self.__setCombo('white_difficulty_combo', whiteLevel)
            self.__setCombo('black_type_combo', blackType)
            self.__setCombo('black_difficulty_combo', blackLevel)

        # Use supplied settings
        errorText = ''
        g = self.game
        if g is not None:
            self.__gui.get_widget('game_name_entry').set_text(g.name)
            self.__customName = True
            if not self.__setCombo('white_type_combo', g.white.type):
                errorText += _('Unable to find %s engine\n') % repr(g.white.type)
            self.__setCombo('white_difficulty_combo', g.white.level)
            if not self.__setCombo('black_type_combo', g.black.type):
                errorText += _('Unable to find %s engine\n') % repr(g.black.type)
            self.__setCombo('black_difficulty_combo', g.black.level)
            # TODO: Others
            
            # Change title for loaded games
            if g.path is not None:
                self.window.set_title(_('Configure loaded game (%i moves)') % len(g.moves))

        # Display warning if missing the AIs
        if len(errorText) > 0:
            self.__gui.get_widget('info_title_label').set_markup('<big><b>%s</b></big>' % _('Game settings changed'))
            self.__gui.get_widget('info_description_label').set_markup('<i>%s</i>' % errorText[:-1])
            self.__gui.get_widget('info_box').show()

        # Show the dialog
        self.window.present()
        self.__checking = False
        self.__testReady()
        
    # Private methods
    
    def __setCombo(self, comboName, key):
        """
        """
        widget = self.__gui.get_widget(comboName)
        iter = self.__getIter(widget.get_model(), key)
        if iter is None:
            return False
        else:
            widget.set_active_iter(iter)
            return True

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

    def __testReady(self):
        if self.__checking:
            return
        self.__checking = True
        ready = True

        # Must have a name for the game
        if self.__customName:
            name = self.__gui.get_widget('game_name_entry').get_text()
            if len(name) == 0:
                # Next time the something changes generate a name
                self.__customName = False
                ready = False

        # Name the game based on the players
        else:
            whiteName = self.__getComboData(self.__gui.get_widget('white_type_combo'), 2)
            blackName = self.__getComboData(self.__gui.get_widget('black_type_combo'), 2)
            format = _('%(white)s versus %(black)s')
            self.__gui.get_widget('game_name_entry').set_text(format % {'white': whiteName, 'black': blackName})

        # Disable difficulty for human players
        whiteType = self.__getComboData(self.__gui.get_widget('white_type_combo'), 0)
        blackType = self.__getComboData(self.__gui.get_widget('black_type_combo'), 0)
        self.__gui.get_widget('white_difficulty_combo').set_sensitive(whiteType != '')
        self.__gui.get_widget('black_difficulty_combo').set_sensitive(blackType != '')

        # Can only click OK if have enough information
        self.__gui.get_widget('start_button').set_sensitive(ready)
        self.__checking = False
        
    def __startGame(self):
        game = self.game
        if game is None:
            game = glchess.ui.Game()
        game.name = self.__gui.get_widget('game_name_entry').get_text()
        game.allowSpectators = True
        
        # Get the players
        game.white.type  = self.__getComboData(self.__gui.get_widget('white_type_combo'), 0)
        if game.white.type == '':
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

        game.duration = self.__getGameDuration()
            
        # Save properties
        glchess.config.set('new_game_dialog/move_time', game.duration)
        glchess.config.set('new_game_dialog/white/type', game.white.type)
        glchess.config.set('new_game_dialog/white/difficulty', game.white.level)
        glchess.config.set('new_game_dialog/black/type', game.black.type)
        glchess.config.set('new_game_dialog/black/difficulty', game.black.level)

        # Inform the child class
        self.__mainUI.feedback.onGameStart(game)
    
    def __getGameDuration(self):
        duration = self.__getComboData(self.__gui.get_widget('time_combo'), 1)
        if duration < 0:
            multiplier = self.__getComboData(self.__gui.get_widget('custom_time_units_combo'), 1)
            duration = self.__gui.get_widget('custom_time_spin').get_value_as_int() * multiplier
        return duration
        
    # Gtk+ signal handlers
    
    def _on_game_name_edited(self, widget):
        """Gtk+ callback"""
        if self.__checking:
            return
        self.__customName = True
        self.__testReady()

    def _on_time_changed(self, widget):
        """Gtk+ callback"""
        time = self.__getComboData(widget, 1)
        w = self.__gui.get_widget('custom_time_box')
        if time < 0:
            w.show()
        else:
            w.hide()

    def _on_properties_changed(self, widget, *data):
        """Gtk+ callback"""
        self.__testReady()

    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        if responseId == gtk.RESPONSE_OK:
            self.__startGame()
        dialog.destroy()

class GtkLoadGameDialog:
    """
    """    
    def __init__(self, mainUI):
        """
        """
        self.__mainUI = mainUI
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('load_game.glade')
        self.__gui.signal_autoconnect(self)
        
        self.window = self.__gui.get_widget('game_load_dialog')
        self.window.set_transient_for(mainUI.mainWindow)
        
        # Set style of error panel
        mainUI.setTooltipStyle(self.__gui.get_widget('error_box'))
        
        fileChooser = self.__gui.get_widget('filechooserwidget')
        
        try:
            directory = str(glchess.config.get('load_directory'))
        except glchess.config.Error:
            pass
        else:
            fileChooser.set_current_folder(directory)

        # Filter out non PGN files by default
        pgnFilter = gtk.FileFilter()
        pgnFilter.set_name('PGN files')
        pgnFilter.add_pattern('*.pgn')
        fileChooser.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        allFilter.set_name('All files')
        allFilter.add_pattern('*')
        fileChooser.add_filter(allFilter)
        
        self.window.present()
        
    def __getFilename(self):
        """Get the currently selected filename.
        
        Returns the filename (string) or None if none selected.
        """
        return self.__gui.get_widget('filechooserwidget').get_filename()
    
    def _on_file_changed(self, widget):
        """Gtk+ callback"""
        name = self.__getFilename()
        if name is None:
            isFile = False
        else:
            isFile = os.path.isfile(name)
        self.__gui.get_widget('properties_button').set_sensitive(isFile)
        self.__gui.get_widget('open_button').set_sensitive(isFile)
        
    def _on_file_activated(self, widget):
        """Gtk+ callback"""
        self._on_response(self.window, gtk.RESPONSE_OK)

    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        chooser= self.__gui.get_widget('filechooserwidget')

        if responseId == gtk.RESPONSE_OK or responseId == gtk.RESPONSE_YES:
            folder = chooser.get_current_folder()
            if folder is not None:
                glchess.config.set('load_directory', folder)
            error = self.__mainUI.feedback.loadGame(self.__getFilename(), responseId == gtk.RESPONSE_YES)
            if error is not None:
                self.firstExpose = True
                self.__gui.get_widget('error_box').show()
                self.__gui.get_widget('error_title_label').set_markup('<big><b>%s</b></big>' % _('Unabled to load game'))
                self.__gui.get_widget('error_description_label').set_markup('<i>%s</i>' % error)
                return

        dialog.destroy()
        
class GtkSaveGameDialog:
    """
    """
    def __init__(self, mainUI, view, path = None):
        """
        """
        self.__mainUI = mainUI
        self.__view = view
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('save_game.glade')
        self.__gui.signal_autoconnect(self)
        
        # Set style of error panel
        mainUI.setTooltipStyle(self.__gui.get_widget('error_box'))

        self.window = self.__gui.get_widget('save_dialog')
        self.window.set_transient_for(mainUI.mainWindow)
        chooser = self.__gui.get_widget('filechooser')
        
        try:
            directory = str(glchess.config.get('save_directory'))
        except glchess.config.Error:
            pass
        else:
            chooser.set_current_folder(directory)       
        
        # Filter out non PGN files by default
        pgnFilter = gtk.FileFilter()
        pgnFilter.set_name('PGN files')
        pgnFilter.add_pattern('*.pgn')
        chooser.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        allFilter.set_name('All files')
        allFilter.add_pattern('*')
        chooser.add_filter(allFilter)
        
        if path is not None:
            chooser.set_current_name(path)
        
    def _on_file_activated(self, widget):
        """Gtk+ callback"""
        self._on_response(self.window, gtk.RESPONSE_OK)

    def __setError(self, title, content):
        """
        """
        self.firstExpose = True
        self.__gui.get_widget('error_box').show()
        self.__gui.get_widget('error_title_label').set_markup('<big><b>%s</b></big>' % title)
        self.__gui.get_widget('error_description_label').set_markup('<i>%s</i>' % content)
        
    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        chooser = self.__gui.get_widget('filechooser')
        
        if responseId == gtk.RESPONSE_OK:
            # Append .pgn to the end if not provided
            fname = chooser.get_filename()
            if fname is None:
                self.__setError(_('Please enter a file name'), '')
                return
            if fname[-4:].lower() != '.pgn':
                fname += '.pgn'

            # Save the directory we used
            folder = chooser.get_current_folder()
            if folder is not None:
                glchess.config.set('save_directory', folder)

            error = self.__mainUI._saveView(self.__view, fname)
            if error is not None:
                self.__setError(_('Unabled to save game'), error)
                return
        else:
            self.__mainUI._saveView(self.__view, None)

        dialog.destroy()

class GtkPreferencesDialog:
    """
    """
    def __init__(self, mainUI):
        """Constructor for the preferences dialog.
        
        'mainUI' is the main UI.
        """
        # Load the UI
        self.__gui = gtkui.loadGladeFile('preferences.glade', 'preferences')
        self.__gui.signal_autoconnect(self)
        
        self.__gui.get_widget('preferences').set_transient_for(mainUI.mainWindow)

        # Load preferences for move_format
        moveFormat = glchess.config.get('move_format')
        moveModel = gtk.ListStore(str, str)
        widget = self.__gui.get_widget('move_format_combo')
        widget.set_model(moveModel)
        move_formats = [('human', _('Human')),
                        ('lan', _('Long Algebraic')),
                        ('san', _('Standard Algebraic'))]
        for (key, label) in move_formats:
            iter = moveModel.append()
            if key == moveFormat:
                widget.set_active_iter(iter)
            moveModel.set(iter, 0, label, 1, key)

        # Load preferences for board orientation
        boardView = glchess.config.get('board_view')
        boardModel = gtk.ListStore(str, str)
        widget = self.__gui.get_widget('board_combo')
        widget.set_model(boardModel)
        view_list = [('white', _('White Side')),
                     ('black', _('Black Side')),
                     ('human', _('Human Side')),
                     ('current', _('Current Player'))]
        for (key, label) in view_list:
            iter = boardModel.append()
            if key == boardView:
                widget.set_active_iter(iter)
            boardModel.set(iter, 0, label, 1, key)

        # Load preferences for promotion type
        promotionType = glchess.config.get('promotion_type')
        promotionModel = gtk.ListStore(str, str)
        widget = self.__gui.get_widget('promotion_type_combo')
        widget.set_model(promotionModel)
        promotion_list = [('queen', _('Queen')),
                          ('knight', _('Knight')),
                          ('rook', _('Rook')),
                          ('bishop', _('Bishop'))]
        for (key, label) in promotion_list:
            iter = promotionModel.append()
            if key == promotionType:
                widget.set_active_iter(iter)
            promotionModel.set(iter, 0, label, 1, key)

        # Load preferences for View settings.
        pref = glchess.config.get('show_3d')
        widget = self.__gui.get_widget('show_3d')
        widget.set_active(pref)

        pref = glchess.config.get('show_toolbar')
        widget = self.__gui.get_widget('show_toolbar')
        widget.set_active(pref)

        pref = glchess.config.get('show_history')
        widget = self.__gui.get_widget('show_history')
        widget.set_active(pref)

        pref = glchess.config.get('show_move_hints')
        widget = self.__gui.get_widget('show_move_hints')
        widget.set_active(pref)

        pref = glchess.config.get('show_numbering')
        widget = self.__gui.get_widget('show_numbering')
        widget.set_active(pref)

    def setVisible(self, isVisible):
        window = self.__gui.get_widget('preferences')
        if isVisible:
            window.present()
        else:
            window.hide()

    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        self.setVisible(False)
        
    def _on_delete(self, dialog, event):
        """Gtk+ callback"""
        self.setVisible(False)
        return True

    def _on_move_format_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('move_format', data[0])

    def _on_board_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('board_view', data[0])

    def _on_promotion_type_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('promotion_type', data[0])

    def _on_3d_view_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_3d', widget.get_active())

    def _on_show_toolbar_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_toolbar', widget.get_active())

    def _on_show_history_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_history', widget.get_active())

    def _on_move_hints_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_move_hints', widget.get_active())

    def _on_board_numbering_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_numbering', widget.get_active())
