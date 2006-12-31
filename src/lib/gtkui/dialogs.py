__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
import gettext

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
    # The main UI and the ???
    __mainUI = None
    __gui = None

    __customName = False
    __checking = False
    
    def __init__(self, mainUI, aiModel):
        """Constructor for a new game dialog.
        
        'mainUI' is the main UI.
        'aiModel' is the AI models to use.
        """
        self.__mainUI = mainUI
        
        # Load the UI
        self.__gui = gtkui.loadGladeFile('new_game.glade', 'new_game_dialog')
        self.__gui.signal_autoconnect(self)
        
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
        times = [(gettext.gettext('Unlimited'), 0),
                 (gettext.gettext('One minute'), 60),
                 (gettext.gettext('Five minutes'), 300),
                 (gettext.gettext('30 minutes'), 1800),
                 (gettext.gettext('One hour'), 3600),
                 (gettext.gettext('Custom'), -1)]
        timeModel = gtk.ListStore(str, int)
        for (name, time) in times:
            iter = timeModel.append()
            timeModel.set(iter, 0, name, 1, time)
        widget = self.__gui.get_widget('time_combo')
        widget.set_model(timeModel)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)
        widget.set_active(0)

        model = gtk.ListStore(str, int)
        units = [(gettext.gettext('seconds'), 1),
                 (gettext.gettext('minutes'), 60),
                 (gettext.gettext('hours'), 3600)]
        for (name, multiplier) in units:
            iter = model.append()
            model.set(iter, 0, name, 1, multiplier)
        widget = self.__gui.get_widget('custom_time_units_combo')
        widget.set_model(model)
        cell = gtk.CellRendererText()
        widget.pack_start(cell, False)
        widget.add_attribute(cell, 'text', 0)
        widget.set_active(0)

        # Create the model for difficulty options
        levelModel = gtk.ListStore(str, gtk.gdk.Pixbuf, str)
        levels = [('easy',   gettext.gettext('Easy'),   'weather-few-clouds'),
                  ('normal', gettext.gettext('Normal'), 'weather-overcast'),
                  ('hard',   gettext.gettext('Hard'),   'weather-storm')]
        iconTheme = gtk.icon_theme_get_default()
        for (key, label, iconName) in levels:
            try:
                icon = iconTheme.load_icon(iconName, 24, gtk.ICON_LOOKUP_USE_BUILTIN)
            except gobject.GError:
                icon = None
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
            widget.add_attribute(cell, 'pixbuf', 1)
            
            cell = gtk.CellRendererText()
            widget.pack_start(cell, False)
            widget.add_attribute(cell, 'text', 2)
            
            widget.set_active(1)

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

        # Configure AIs
        try:
            whiteType = glchess.config.get('new_game_dialog/white_type')
            whiteLevel = glchess.config.get('new_game_dialog/white_difficulty')
            blackType = glchess.config.get('new_game_dialog/black_type')
            blackLevel = glchess.config.get('new_game_dialog/black_difficulty')
        except glchess.config.Error:
            pass
        else:
            self.__setCombo('white_type_combo', whiteType)
            self.__setCombo('white_difficulty_combo', whiteLevel)
            self.__setCombo('black_type_combo', blackType)
            self.__setCombo('black_difficulty_combo', blackLevel)

        # Show the dialog
        self.__getWidget('new_game_dialog').show()
        self.__testReady()
        
    # Private methods
    
    def __setCombo(self, comboName, key):
        widget = self.__getWidget(comboName)
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
                
    def __getWidget(self, name):
        """
        """
        return self.__gui.get_widget(name)
    
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
            name = self.__getWidget('game_name_entry').get_text()
            if len(name) == 0:
                ready = False

        # Name the game based on the players
        else:
            whiteName = self.__getComboData(self.__getWidget('white_type_combo'), 2)
            blackName = self.__getComboData(self.__getWidget('black_type_combo'), 2)
            self.__getWidget('game_name_entry').set_text('%s versus %s' % (whiteName, blackName))
            
        # Disable difficulty for human players
        whiteType = self.__getComboData(self.__getWidget('white_type_combo'), 0)
        blackType = self.__getComboData(self.__getWidget('black_type_combo'), 0)
        self.__gui.get_widget('white_difficulty_combo').set_sensitive(whiteType != None)
        self.__gui.get_widget('black_difficulty_combo').set_sensitive(blackType != None)

        # Can only click OK if have enough information
        self.__getWidget('start_button').set_sensitive(ready)
        self.__checking = False
        
    def __startGame(self):
        # FIXME: Game properties
        gameName = self.__getWidget('game_name_entry').get_text()
        allowSpectators = True
        
        white = glchess.ui.Player()
        black = glchess.ui.Player()

        # Get the players
        white.type  = self.__getComboData(self.__getWidget('white_type_combo'), 0)
        if white.type is None:
            white.type = glchess.ui.HUMAN
            white.name = gettext.gettext('White')
        else:
            white.name = self.__getComboData(self.__getWidget('white_type_combo'), 2)
        white.level = self.__getComboData(self.__getWidget('white_difficulty_combo'), 0)
        black.type  = self.__getComboData(self.__getWidget('black_type_combo'), 0)
        if black.type is None:
            black.type = glchess.ui.HUMAN
            black.name = gettext.gettext('Black')
        else:
            black.name = self.__getComboData(self.__getWidget('black_type_combo'), 2)
        black.level = self.__getComboData(self.__getWidget('black_difficulty_combo'), 0)

        duration = self.__getComboData(self.__gui.get_widget('time_combo'), 1)
        if duration < 0:
            multplier = self.__getComboData(self.__gui.get_widget('custom_time_units_combo'), 1)
            duration = self.__getComboData(self.__gui.get_widget('custom_time_spin'), 1) * multiplier
            
        # Save properties
        glchess.config.set('new_game_dialog/white_type', white.type)
        glchess.config.set('new_game_dialog/white_difficulty', white.level)
        print repr(black.type)
        glchess.config.set('new_game_dialog/black_type', black.type)
        glchess.config.set('new_game_dialog/black_difficulty', black.level)

        # Inform the child class
        self.__mainUI.onGameStart(gameName, allowSpectators, duration, white, black)
        
    # Gtk+ signal handlers
    
    def _on_game_name_edited(self, widget, data = None):
        """Gtk+ callback"""
        if self.__checking:
            return
        self.__customName = len(widget.get_text()) != 0

    def _on_time_changed(self, widget, data = None):
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
        self.__gui = gtkui.loadGladeFile('load_game.glade')
        self.__gui.signal_autoconnect(self)
        
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
        # Save the directory we used
        dialog = self.__gui.get_widget('filechooserwidget')
        glchess.config.set('load_directory', dialog.get_current_folder())
        
        self.__mainUI.loadGame(self.__getFilename())
        self._on_close(widget, data)
        
    def _on_close(self, widget, data = None):
        """Gtk+ callback"""
        self.__gui.get_widget('game_load_dialog').destroy()

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
        self.__gui = gtkui.loadGladeFile('save_game.glade')
        self.__gui.signal_autoconnect(self)
        
        dialog = self.__gui.get_widget('dialog')
        
        try:
            directory = str(glchess.config.get('save_directory'))
        except glchess.config.Error:
            pass
        else:
            dialog.set_current_folder(directory)       
        
        # Filter out non PGN files by default
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
            
        # Save the directory we used
        dialog = self.__gui.get_widget('dialog')
        glchess.config.set('save_directory', dialog.get_current_folder())
        
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
        self.__gui = gtkui.loadGladeFile('error_dialog.glade')
        self.__gui.signal_autoconnect(self)
        
        self.__gui.get_widget('title_label').set_markup('<b><big>' + title + '</big></b>')
        self.__gui.get_widget('content_label').set_text(contents)
        
        dialog = self.__gui.get_widget('dialog').show_all()

    def _on_close(self, widget, data = None):
        """Gtk+ callback"""
        dialog = self.__gui.get_widget('dialog').destroy()
