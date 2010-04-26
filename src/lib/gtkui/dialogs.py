# -*- coding: utf-8 -*-
__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
from gettext import gettext as _

import gobject
import gtk
import gtk.gdk

import gtkui
import glchess.ui
from glchess.i18n import C_

class GtkServerList:

    def __init__(self, gui):
        self.__gui = gui
        
        self.__servers = []
        view = gui.get_object('server_list')
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
        view = self.__gui.get_object('server_list')
        if view is None:
            return
        model = view.get_model()
        iter = model.append()
        model.set(iter, 0, name)
        model.set(iter, 1, game)
        
    def getSelected(self):
        """
        """
        view = self.__gui.get_object('server_list')
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
        view = self.__gui.get_object('server_list')
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
        self.__gui = gtkui.loadUIFile('new_game.ui')

        self.window = self.__gui.get_object('new_game_dialog')
        self.window.set_transient_for(mainUI.mainWindow)

        self.infobar = gtk.InfoBar()
        self.window.get_content_area().pack_start(self.infobar, False, True, 0)
        vbox = gtk.VBox()
        self.infobar.add(vbox)
        vbox.show()
        self.infoTitleLabel = gtk.Label()
        vbox.pack_start(self.infoTitleLabel, False, True, 0)
        self.infoTitleLabel.show()
        self.infoDescriptionLabel = gtk.Label()
        vbox.pack_start(self.infoDescriptionLabel, False, True, 0);
        self.infoDescriptionLabel.show()

        self.__gui.connect_signals(self)

        # Make all the labels the same width
        group = gtk.SizeGroup(gtk.SIZE_GROUP_HORIZONTAL)
        i = 1
        while True:
            widget = self.__gui.get_object('label%i' % i)
            if widget is None:
                break
            group.add_widget(widget)
            i += 1

        # Make all the images the same width
        group = gtk.SizeGroup(gtk.SIZE_GROUP_HORIZONTAL)
        i = 1
        while True:
            widget = self.__gui.get_object('image%i' % i)
            if widget is None:
                break
            group.add_widget(widget)
            i += 1
            
        # Create model for game time
        defaultTime = glchess.config.get('new_game_dialog/move_time')
                  # Translators: Time Combo: There is no time limit
        times = [(_('Unlimited'),       0),
                  # Translators: Time Combo: Game will last one minute
                 (_('One minute'),     60),
                  # Translators: Time Combo: Game will last five minutes
                 (_('Five minutes'),  300),
                  # Translators: Time Combo: Game will last 30 minutes
                 (_('30 minutes'),   1800),
                  # Translators: Time Combo: Game will last one hour
                 (_('One hour'),     3600),
                  # Translators: Time Combo: User will configure game duration
                 (_('Custom'),         -1)]
        timeModel = gtk.ListStore(str, int)
        activeIter = None
        for (name, time) in times:
            iter = timeModel.append()
            if time == defaultTime:
                activeIter = iter
            timeModel.set(iter, 0, name, 1, time)

        widget = self.__gui.get_object('time_combo')
        widget.set_model(timeModel)
        if activeIter is None:
            widget.set_active_iter(iter)
        else:
            widget.set_active_iter(activeIter)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)

        model = gtk.ListStore(str, int)
                  # Translators: Custom Time Combo: User specifying number of seconds for game duration
        units = [(_('seconds'),  1),
                  # Translators: Custom Time Combo: User specifying number of minutes for game duration
                 (_('minutes'), 60),
                  # Translators: Custom Time Combo: User specifying number of hours for game duration
                 (_('hours'), 3600)]
        for (name, multiplier) in units:
            iter = model.append()
            model.set(iter, 0, name, 1, multiplier)

        # FIXME: Handle time units
        self.__gui.get_object('custom_time_spin').set_value(defaultTime)

        widget = self.__gui.get_object('custom_time_units_combo')
        widget.set_model(model)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)
        widget.set_active(0)

        # Create the model for difficulty options
        levelModel = gtk.ListStore(str, str, str)
                  # Translators: AI Difficulty Combo: AI set to easy difficulty
        levels = [('easy',   _('Easy'),   'weather-few-clouds'),
                  # Translators: AI Difficulty Combo: AI set to normal diffuculty
                  ('normal', _('Normal'), 'weather-overcast'),
                  # Translators: AI Difficulty Combo: AI set to hard diffuculty
                  ('hard',   _('Hard'),   'weather-storm')]
        for (key, label, icon) in levels:
            iter = levelModel.append()
            levelModel.set(iter, 0, key, 1, icon, 2, label)

        # Set the difficulty settings
        for name in ['black_difficulty_combo', 'white_difficulty_combo']:
            widget = self.__gui.get_object(name)
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
            widget = self.__gui.get_object(name)
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
        errors = []
        g = self.game
        if g is not None:
            self.__gui.get_object('game_name_entry').set_text(g.name)
            self.__customName = True
            # Translators: Error displayed when unable to load a game due to
            # the require game engine not being available. %s is replaced with
            # the name of the missing engine.
            noEngineFormat = _('Unable to find %s engine')
            if not self.__setCombo('white_type_combo', g.white.type):
                errors.append(noEngineFormat % repr(g.white.type))
            self.__setCombo('white_difficulty_combo', g.white.level)
            if not self.__setCombo('black_type_combo', g.black.type):
                errors.append(noEngineFormat % repr(g.black.type))
            self.__setCombo('black_difficulty_combo', g.black.level)
            # TODO: Others
            
            # Change title for loaded games
            if g.path is not None:
                # Translators: New Game Dialog: Title of the dialog when continuing a loaded game
                self.window.set_title(_('Configure loaded game (%i moves)') % len(g.moves))

        # Display warning if missing the AIs
        if len(errors) > 0:
            # Translators: New Game Dialog: Title of error box when loaded game had AI engines missing
            self.infoTitleLabel.set_markup('<big><b>%s</b></big>' % _('Game settings changed'))
            self.infoDescriptionLabel.set_markup('<i>%s</i>' % '\n'.join(errors))
            self.infobar.get_object('info_box').show()

        # Show the dialog
        self.window.present()
        self.__checking = False
        self.__testReady()

    # Private methods
    
    def __setCombo(self, comboName, key):
        """
        """
        widget = self.__gui.get_object(comboName)
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
            name = self.__gui.get_object('game_name_entry').get_text()
            if len(name) == 0:
                # Next time something changes generate a name
                self.__customName = False
                ready = False

        # Name the game based on the players
        else:
            whiteName = self.__getComboData(self.__gui.get_object('white_type_combo'), 2)
            blackName = self.__getComboData(self.__gui.get_object('black_type_combo'), 2)
            # Translators: Default name for a new game. %(white) and %(black) are substituted for the names of the white and black players.
            format = _('%(white)s versus %(black)s')
            self.__gui.get_object('game_name_entry').set_text(format % {'white': whiteName, 'black': blackName})

        # Disable difficulty for human players
        whiteType = self.__getComboData(self.__gui.get_object('white_type_combo'), 0)
        blackType = self.__getComboData(self.__gui.get_object('black_type_combo'), 0)
        self.__gui.get_object('white_difficulty_combo').set_sensitive(whiteType != '')
        self.__gui.get_object('black_difficulty_combo').set_sensitive(blackType != '')

        # Can only click OK if have enough information
        self.__gui.get_object('start_button').set_sensitive(ready)
        self.__checking = False
        
    def __startGame(self):
        game = self.game
        if game is None:
            game = glchess.ui.Game()
        game.name = self.__gui.get_object('game_name_entry').get_text()
        game.allowSpectators = True
        
        # Get the players
        game.white.type  = self.__getComboData(self.__gui.get_object('white_type_combo'), 0)
        if game.white.type == '':
            # Translators: Default name for the white player
            game.white.name = _('White')
        else:
            game.white.name = self.__getComboData(self.__gui.get_object('white_type_combo'), 2)
        game.white.level = self.__getComboData(self.__gui.get_object('white_difficulty_combo'), 0)
        game.black.type  = self.__getComboData(self.__gui.get_object('black_type_combo'), 0)
        if game.black.type == '':
            # Translators: Default name for the black player
            game.black.name = _('Black')
        else:
            game.black.name = self.__getComboData(self.__gui.get_object('black_type_combo'), 2)
        game.black.level = self.__getComboData(self.__gui.get_object('black_difficulty_combo'), 0)

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
        duration = self.__getComboData(self.__gui.get_object('time_combo'), 1)
        if duration < 0:
            multiplier = self.__getComboData(self.__gui.get_object('custom_time_units_combo'), 1)
            duration = self.__gui.get_object('custom_time_spin').get_value_as_int() * multiplier
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
        w = self.__gui.get_object('custom_time_box')
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
        if self.__mainUI.newGameDialog is self:
            self.__mainUI.newGameDialog = None

class GtkLoadGameDialog:
    """
    """

    def __init__(self, mainUI):
        """
        """
        self.__mainUI = mainUI
        
        # Load the UI
        self.__gui = gtkui.loadUIFile('load_game.ui')

        self.window = self.__gui.get_object('game_load_dialog')
        self.window.set_transient_for(mainUI.mainWindow)

        self.infobar = gtk.InfoBar()
        self.window.get_content_area().pack_start(self.infobar, False, True, 0)
        vbox = gtk.VBox()
        self.infobar.add(vbox)
        vbox.show()
        self.infoTitleLabel = gtk.Label()
        vbox.pack_start(self.infoTitleLabel, False, True, 0)
        self.infoTitleLabel.show()
        self.infoDescriptionLabel = gtk.Label()
        vbox.pack_start(self.infoDescriptionLabel, False, True, 0);
        self.infoDescriptionLabel.show()

        self.__gui.connect_signals(self)

        fileChooser = self.__gui.get_object('filechooserwidget')
        
        try:
            directory = str(glchess.config.get('load_directory'))
        except glchess.config.Error:
            pass
        else:
            fileChooser.set_current_folder(directory)

        # Filter out non PGN files by default
        pgnFilter = gtk.FileFilter()
        # Translators: Load Game Dialog: Name of filter to show only PGN files
        pgnFilter.set_name(_('PGN files'))
        pgnFilter.add_pattern('*.pgn')
        fileChooser.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        # Translators: Load Game Dialog: Name of filter to show all files
        allFilter.set_name(_('All files'))
        allFilter.add_pattern('*')
        fileChooser.add_filter(allFilter)
        
        self.window.present()
            
    def _on_file_activated(self, widget):
        """Gtk+ callback"""
        self._on_response(self.window, gtk.RESPONSE_OK)

    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        chooser = self.__gui.get_object('filechooserwidget')

        if responseId == gtk.RESPONSE_OK or responseId == gtk.RESPONSE_YES:
            folder = chooser.get_current_folder()
            if folder is not None:
                glchess.config.set('load_directory', folder)

            fileName = self.__gui.get_object('filechooserwidget').get_filename()
            if fileName is None:
                # Translators: Load Game Dialog: Message displayed when no file is selected
                error = _('Please select a file to load')
            else:
                error = self.__mainUI.feedback.loadGame(fileName, responseId == gtk.RESPONSE_YES)

            if error is not None:
                self.firstExpose = True
                self.infobar.set_message_type(gtk.MESSAGE_ERROR)
                # Translators: Title of error box when unable to load game
                self.infoTitleLabel.set_markup('<big><b>%s</b></big>' % _('Unabled to load game'))
                self.infoDescriptionLabel.set_markup('<i>%s</i>' % error)
                self.infobar.show()
                return

        dialog.destroy()
        if self.__mainUI.loadGameDialog is self:
            self.__mainUI.loadGameDialog = None
        
class GtkSaveGameDialog:
    """
    """

    def __init__(self, mainUI, view, path = None):
        """
        """
        self.__mainUI = mainUI
        self.__view = view
        
        # Load the UI
        self.__gui = gtkui.loadUIFile('save_game.ui')

        self.window = self.__gui.get_object('save_dialog')
        self.window.set_transient_for(mainUI.mainWindow)
        
        self.infobar = gtk.InfoBar()
        self.window.get_content_area().pack_start(self.infobar, False, True, 0)
        vbox = gtk.VBox()
        self.infobar.add(vbox)
        vbox.show()
        self.infoTitleLabel = gtk.Label()
        vbox.pack_start(self.infoTitleLabel, False, True, 0)
        self.infoTitleLabel.show()
        self.infoDescriptionLabel = gtk.Label()
        vbox.pack_start(self.infoDescriptionLabel, False, True, 0);
        self.infoDescriptionLabel.show()

        self.__gui.connect_signals(self)
        
        chooser = self.__gui.get_object('filechooser')
        
        try:
            directory = str(glchess.config.get('save_directory'))
        except glchess.config.Error:
            pass
        else:
            chooser.set_current_folder(directory)       
        
        # Filter out non PGN files by default
        pgnFilter = gtk.FileFilter()
        # Translators: Save Game Dialog: Name of filter to show only PGN files
        pgnFilter.set_name(_('PGN files'))
        pgnFilter.add_pattern('*.pgn')
        chooser.add_filter(pgnFilter)
        
        allFilter = gtk.FileFilter()
        # Translators: Save Game Dialog: Name of filter to show all files
        allFilter.set_name(_('All files'))
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
        self.infobar.set_message_type(gtk.MESSAGE_ERROR)
        self.infoTitleLabel.set_markup('<big><b>%s</b></big>' % title)
        self.infoDescriptionLabel.set_markup('<i>%s</i>' % content)
        self.infobar.show()
        
    def _on_response(self, dialog, responseId):
        """Gtk+ callback"""
        chooser = self.__gui.get_object('filechooser')
        
        if responseId == gtk.RESPONSE_OK:
            # Append .pgn to the end if not provided
            fname = chooser.get_filename()
            if fname is None:
                # Translators: Save Game Dialog: Error displayed when no file name entered
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
                # Translators: Save Game Dialog: Error title when unable to save game
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
        self.__gui = gtkui.loadUIFile('preferences.ui')
        self.__gui.connect_signals(self)
        
        self.__gui.get_object('preferences').set_transient_for(mainUI.mainWindow)

        # Make model for move format
        moveModel = gtk.ListStore(str, str)
        widget = self.__gui.get_object('move_format_combo')
        widget.set_model(moveModel)
                        # Translators: Move Format Combo: Moves shown in human descriptive notation
        move_formats = [('human', _('Human')),
                        # Translators: Move Format Combo: Moves shown in standard algebraic notation (SAN)
                        ('san', _('Standard Algebraic')),
                        # Translators: Move Format Combo: Moves shown in standard figurine algebraic notation (FAN)
                        ('fan', _('Figurine')),
                        # Translators: Move Format Combo: Moves shown in long algebraic notation (LAN)
                        ('lan', _('Long Algebraic'))]
        for (key, label) in move_formats:
            iter = moveModel.append()
            moveModel.set(iter, 0, label, 1, key)

        # Make model for board orientation
        boardModel = gtk.ListStore(str, str)
        widget = self.__gui.get_object('board_combo')
        widget.set_model(boardModel)
                     # Translators: Board Side Combo: Camera will face white player's side
        view_list = [('white', _('White Side')),
                     # Translators: Board Side Combo: Camera will face black player's side
                     ('black', _('Black Side')),
                     # Translators: Board Side Combo: Camera will face human player's side
                     ('human', _('Human Side')),
                     # Translators: Board Side Combo: Camera will face current player's side
                     ('current', _('Current Player')),
                     # Translators: Board Side Combo: Board will be drawn suitable for players on each side of screen, e.g. handhelds
                     ('facetoface', _('Face to Face'))]
        for (key, label) in view_list:
            iter = boardModel.append()
            boardModel.set(iter, 0, label, 1, key)

        # Make modelfor promotion type
        promotionModel = gtk.ListStore(str, str)
        widget = self.__gui.get_object('promotion_type_combo')
        widget.set_model(promotionModel)
                          # Translators: Promotion Combo: Promote to a queen
        promotion_list = [('queen',  C_('chess-piece', 'Queen')),
                          # Translators: Promotion Combo: Promote to a knight
                          ('knight', C_('chess-piece', 'Knight')),
                          # Translators: Promotion Combo: Promote to a rook
                          ('rook',   C_('chess-piece', 'Rook')),
                          # Translators: Promotion Combo: Promote to a bishop
                          ('bishop', C_('chess-piece', 'Bishop'))]
        for (key, label) in promotion_list:
            iter = promotionModel.append()
            promotionModel.set(iter, 0, label, 1, key)
            
        # Make model for piece styles
        pieceStyleModel = gtk.ListStore(str, str)
        widget = self.__gui.get_object('piece_style_combo')
        widget.set_model(pieceStyleModel)
                     # Translators: a simple piece set will be used in 2d mode
        view_list = [('simple', _('Simple')),
                     # Translators: a fancy piece set will be used in 2d mode
                     ('fancy',  _('Fancy'))]
        for (key, label) in view_list:
            iter = pieceStyleModel.append()
            pieceStyleModel.set(iter, 0, label, 1, key)

        # Watch for config changes
        for key in ['show_3d', 'show_3d_smooth', 'piece_style', 'show_toolbar',
                    'show_history', 'show_move_hints', 'show_numbering',
                    'move_format', 'board_view', 'promotion_type']:
            glchess.config.watch(key, self.__applyConfig)
            try:
                value = glchess.config.get(key)
            except glchess.config.Error:
                pass
            else:
                self.__applyConfig(key, value)
        
    def __applyConfig(self, name, value):
        """
        """        
        if name == 'show_3d':
            self.__gui.get_object('show_3d').set_active(value)
            self.__gui.get_object('show_3d_smooth').set_sensitive(value)            
            self.__gui.get_object('piece_style_combo').set_sensitive(not value)            

        elif name == 'show_3d_smooth':
            self.__gui.get_object('show_3d_smooth').set_active(value)
            
        elif name == 'piece_style':
            widget = self.__gui.get_object('piece_style_combo')
            for row in widget.get_model():
                if row[1] == value:
                    widget.set_active_iter(row.iter)
                
        elif name == 'show_toolbar':
            self.__gui.get_object('show_toolbar').set_active(value)
                
        elif name == 'show_history':
            self.__gui.get_object('show_history').set_active(value)

        elif name == 'show_move_hints':
            self.__gui.get_object('show_move_hints').set_active(value)

        elif name == 'show_numbering':
            self.__gui.get_object('show_numbering').set_active(value)

        elif name == 'move_format':
            widget = self.__gui.get_object('move_format_combo')
            for row in widget.get_model():
                if row[1] == value:
                    widget.set_active_iter(row.iter)
                
        elif name == 'promotion_type':
            widget = self.__gui.get_object('promotion_type_combo')
            for row in widget.get_model():
                if row[1] == value:
                    widget.set_active_iter(row.iter)
    
        elif name == 'board_view':
            widget = self.__gui.get_object('board_combo')
            for row in widget.get_model():
                if row[1] == value:
                    widget.set_active_iter(row.iter)

        else:
            assert(False), 'Unknown config item: %s' % name

    def setVisible(self, isVisible):
        window = self.__gui.get_object('preferences')
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

    def _on_piece_style_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('piece_style', data[0])

    def _on_move_format_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('move_format', data[0])

    def _on_board_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('board_view', data[0])

    def _on_promotion_type_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        data = model.get(iter, 1)
        if data[0] is not None:
            glchess.config.set('promotion_type', data[0])

    def _on_3d_view_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_3d', widget.get_active())
        
    def _on_3d_smooth_toggled(self, widget):
        """Gtk+ callback"""
        glchess.config.set('show_3d_smooth', widget.get_active())        

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
