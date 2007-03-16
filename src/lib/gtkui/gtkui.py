__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['GtkUI']

# TODO: Extend base UI classes?

import os
import sys
import time
import gettext

try:
    import pygtk
    pygtk.require('2.0')
except ImportError, err:
    print ("PyGTK not found. Please make sure it is installed properly and referenced in your PYTHONPATH environment variable.")

import gobject
import gtk
import gtk.glade
import gtk.gdk
import pango
try:
    import gnome, gnome.ui
except ImportError:
    haveGnomeSupport = False
else:
    haveGnomeSupport = True

from glchess.defaults import *

# Stop PyGTK from catching exceptions
os.environ['PYGTK_FATAL_EXCEPTIONS'] = '1'

import glchess.config
import glchess.ui
import glchess.chess.board
import dialogs
import chessview

def loadGladeFile(name, root = None):
    return gtk.glade.XML(os.path.join(GLADE_DIR, name), root, domain = DOMAIN)

class GtkGameNotebook(gtk.Notebook):
    """
    """
    
    glConfig          = None

    defaultView       = None
    views             = None
    viewsByWidget     = None
    
    def __init__(self, ui):
        """
        """
        self.ui = ui
        self.views = []
        self.viewsByWidget = {}
        
        gtk.Notebook.__init__(self)
        self.set_show_border(False)
        
        # Make the tabs scrollable so the area is not resized
        self.set_scrollable(True)
        
        # Configure openGL
        try:
            gtk.gdkgl
        except AttributeError:
            self.glConfig = None
        else:
            display_mode = (gtk.gdkgl.MODE_RGB | gtk.gdkgl.MODE_DEPTH | gtk.gdkgl.MODE_DOUBLE)
            try:
                self.glConfig = gtk.gdkgl.Config(mode = display_mode)
            except gtk.gdkgl.NoMatches:
                display_mode &= ~gtk.gdkgl.MODE_DOUBLE
                self.glConfig = gtk.gdkgl.Config(mode = display_mode)
            
        self.set_show_tabs(False)
        
    def setDefault(self, feedback):
        """
        """
        assert(self.defaultView is None)
        self.defaultView = chessview.GtkView(self.ui, '', feedback)
        page = self.append_page(self.defaultView.widget)
        self.set_current_page(page)
        
        self.__updateTabVisibleState()
        
        return self.defaultView

    def addView(self, title, feedback):
        """
        """
        view = chessview.GtkView(self.ui, title, feedback, moveFormat = self.ui.moveFormat)
        self.views.append(view)
        self.viewsByWidget[view.widget] = view
        page = self.append_page(view.widget)
        self.set_tab_label_text(view.widget, title)
        self.set_current_page(page)
        
        self.__updateTabVisibleState()
        
        return view
    
    def getView(self):
        """Get the currently selected view.
        
        Returns the view (GtkView) on this page or None if no view here.
        """
        # If splashscreen present then there is no view
        if len(self.viewsByWidget) == 0:
            return None
        
        num = self.get_current_page()
        if num < 0:
            return None
        widget = self.get_nth_page(num)
        return self.viewsByWidget[widget]
    
    def removeView(self, view):
        """Remove a view from the notebook.
        
        'view' is the view to remove.
        """
        self.remove_page(self.page_num(view.widget))
        self.views.remove(view)
        self.viewsByWidget.pop(view.widget)
        self.__updateTabVisibleState()

    def __updateTabVisibleState(self):
        """
        """
        # Only show tabs if there is more than one game
        self.set_show_tabs(len(self.viewsByWidget) > 1)
        
        # Show/hide the default view
        if len(self.viewsByWidget) == 0:
            self.defaultView.widget.show()
        else:
            self.defaultView.widget.hide()
        
class AIWindow:
    """
    """
    
    notebook    = None
    defaultPage = None
    
    # We keep track of the number of pages as there is a bug 
    # in GtkNotebook (Gnome bug #331785).
    pageCount   = 0
    
    def __init__(self, notebook):
        """
        """
        self.notebook = notebook
        self.defaultPage = notebook.get_nth_page(0)
    
    def addView(self, title, executable, description):
        """
        """
        # Hide the default page
        self.defaultPage.hide()
        self.notebook.set_show_tabs(True)
        
        self.pageCount += 1
        return AIView(self, title, executable, description)

class AIView:
    """
    """
    
    __gui = None
    
    def __init__(self, window, title, executable, description):
        """
        """
        self.window = window
        self.__gui = loadGladeFile('ai.glade', 'ai_table')
        self.__gui.get_widget('executable_label').set_text(executable)
        self.__gui.get_widget('game_label').set_text(description)

        # Add into the notebook
        self.root = self.__gui.get_widget('ai_table')
        notebook = window.notebook
        notebook.append_page(self.root, gtk.Label(title))
                
        # Create styles for the buffer
        buffer = self.__gui.get_widget('comms_textview').get_buffer()
        buffer.create_tag('input', family='Monospace')
        buffer.create_tag('output', family='Monospace', weight = pango.WEIGHT_BOLD)
        buffer.create_tag('move', family='Monospace', foreground = 'blue')
        buffer.create_tag('info', family='Monospace', foreground = 'green')
        buffer.create_tag('error', family='Monospace', foreground = 'red')

    def addText(self, text, style):
        """FIXME: Define style
        """
        buffer = self.__gui.get_widget('comms_textview').get_buffer()
        buffer.insert_with_tags_by_name(buffer.get_end_iter(), text, style)
        
    def close(self):
        """
        """
        self.window.pageCount -= 1
        self.window.notebook.remove_page(self.window.notebook.page_num(self.root))
        
        # Show the default page
        if self.window.pageCount == 0:
            self.window.defaultPage.show()
            self.window.notebook.set_show_tabs(False)

class GtkUI(glchess.ui.UI):
    """
    """
    # The Gtk+ GUI
    _gui               = None
    
    # The time stored for animation
    __lastTime         = None
    __animationTimer   = None
    
    # Timers
    timers             = None

    # The notebook containing games
    notebook           = None

    # The Gtk+ list model of the available player types
    __playerModel      = None

    # The about dialog open
    __aboutDialog      = None

    # Dictionary of save game dialogs keyed by view
    __saveGameDialogs  = None

    __renderGL         = False
    openGLInfoPrinted  = False

    # TODO
    __joinGameDialogs  = None
    __networkGames     = None
    
    __defaultWhiteAI   = None
    __defaultBlackAI   = None

    __attentionCounter = 0

    moveFormat         = 'human'

    def __init__(self, feedback):
        """Constructor for a GTK+ glChess GUI"""
        if haveGnomeSupport:
            gnome.program_init('glchess', VERSION,
                               properties={gnome.PARAM_APP_DATADIR: APP_DATA_DIR})

        self.feedback = feedback
        self.__networkGames = {}
        self.__saveGameDialogs = {}
        self.__joinGameDialogs = []
        self.timers = {}

        # Set the message panel to the tooltip style
        # (copied from Gedit)
        tooltip = gtk.Tooltips()
        tooltip.force_window()
        tooltip.tip_window.ensure_style()
        self.tooltipStyle = tooltip.tip_window.get_style()
        
        self._gui = loadGladeFile('glchess.glade')
        self._gui.signal_autoconnect(self)
        
        # Create mappings between the promotion radio buttons and the promotion types
        self.__promotionTypeByRadio = {}
        self.__promotionRadioByType = {}
        for piece in ['queen', 'knight', 'rook', 'bishop']:
            widget = self.__getWidget('promotion_%s_radio' % piece)
            self.__promotionTypeByRadio[widget] = piece
            self.__promotionRadioByType[piece] = widget

        # Make a notebook for the games
        self.notebook = GtkGameNotebook(self)
        self.notebook.connect_after('switch-page', self._on_view_changed)
        self.__getWidget('game_viewport').add(self.notebook)
        self.notebook.show_all()
        
        # Create the model for the player types
        self.__playerModel = gtk.ListStore(str, gtk.gdk.Pixbuf, str)
        iconTheme = gtk.icon_theme_get_default()
        try:
            icon = iconTheme.load_icon('stock_people', 24, gtk.ICON_LOOKUP_USE_BUILTIN)
        except gobject.GError:
            icon = None
        iter = self.__playerModel.append()
        self.__playerModel.set(iter, 0, '', 1, icon, 2, gettext.gettext('Human'))
        #try:
        #    icon = iconTheme.load_icon(gtk.STOCK_NETWORK, 24, gtk.ICON_LOOKUP_USE_BUILTIN)
        #except gobject.GError:
        #    icon = None
        #iter = self.__playerModel.append()
        #self.__playerModel.set(iter, 0, None, 1, icon, 2, gettext.gettext('Network'))
        
        self.__aiWindow = AIWindow(self._gui.get_widget('ai_notebook'))
        
        combo = self.__getWidget('history_combo')
        cell = gtk.CellRendererText()
        combo.pack_start(cell, False)
        combo.add_attribute(cell, 'text', 2)

        self.defaultViewController = self.notebook.setDefault(None)

        # Disble help support
        if haveGnomeSupport:
            self._gui.get_widget('menu_help').show()
        
        self.defaultViewController.viewWidget.setRenderGL(self.__renderGL)

        self.saveDialog = dialogs.SaveDialog(self)
        
        # Watch for config changes
        for key in ['show_toolbar', 'show_history', 'fullscreen', 'show_3d', 'show_move_hints', 'width', 'height', 'move_format', 'promotion_type']:
            glchess.config.watch(key, self.__applyConfig)

    # Public methods
    
    def watchFileDescriptor(self, fd):
        """Extends ui.UI"""
        gobject.io_add_watch(fd, gobject.IO_IN, self.__readData)
        
    def addTimer(self, method, timeUsec):
        """Extends ui.UI"""
        timer = gobject.timeout_add(timeUsec / 1000, self.__timerExpired, method)
        self.timers[method] = timer

    def __timerExpired(self, method):
        method()
        return True

    def removeTimer(self, method):
        """Extends ui.UI"""
        timer = self.timers.pop(method)
        gobject.source_remove(timer)

    def __readData(self, fd, condition):
        return self.feedback.onReadFileDescriptor(fd)

    def addAIEngine(self, name):
        """Register an AI engine.
        
        'name' is the name of the engine.
        TODO: difficulty etc etc
        """
        iconTheme = gtk.icon_theme_get_default()
        try:
            icon = iconTheme.load_icon('stock_notebook', 24, gtk.ICON_LOOKUP_USE_BUILTIN)
        except gobject.GError:
            icon = None
        iter = self.__playerModel.append()
        self.__playerModel.set(iter, 0, name, 1, icon, 2, name)
        
        # Get the human to play against this AI
        if self.__defaultBlackAI is None:
            self.__defaultBlackAI = name
        
    def setDefaultView(self, feedback):
        """Extends ui.UI"""
        self.defaultViewController.feedback = feedback
        return self.defaultViewController
        
    def addView(self, title, feedback):
        """Extends ui.UI"""
        view = self.notebook.addView(title, feedback)
        view.viewWidget.setRenderGL(self.__renderGL)
        return view

    def addAIWindow(self, title, executable, description):
        """
        """
        return self.__aiWindow.addView(title, executable, description)

    def run(self):
        """Run the UI.
        
        This method will not return.
        """        
        # Load configuration
        for name in ['show_toolbar', 'show_history', 'show_3d', 'show_move_hints', 'move_format', 'promotion_type']:
            try:
                value = glchess.config.get(name)
            except glchess.config.Error:
                pass
            else:
                self.__applyConfig(name, value)
        self.__resize()
        
        self._gui.get_widget('glchess_app').show()

        # Apply the fullscreen flag after the window has been shown otherwise
        # gtk.Window.unfullscreen() stops working if the window is set to fullscreen
        # before being shown. I haven't been able to reproduce this in the simple
        # case (GTK+ 2.10.6-0ubuntu3).
        self.__applyConfig('fullscreen', glchess.config.get('fullscreen'))
        
        gtk.main()
        
    # Extended methods

    def reportGameLoaded(self, game):
        """Extends glchess.ui.UI"""
        dialogs.GtkNewGameDialog(self, self.__playerModel, game)

    def addNetworkDialog(self, feedback):
        """Extends glchess.ui.UI"""
        # Create the dialog
        dialog = dialogs.GtkNetworkGameDialog(self, feedback, self.__playerModel)
        self.__joinGameDialogs.append(dialog)
        
        # Add the detected games into the dialog
        #for (game, name) in self.__networkGames.iteritems():
        #    dialog.addNetworkGame(name, game)
        
        return dialog
                                 
    def addNetworkGame(self, name, game):
        """Extends glchess.ui.UI"""
        self.__networkGames[game] = name
        
        # Update the open dialogs
        for dialog in self.__joinGameDialogs:
            dialog.addNetworkGame(name, game)

    def removeNetworkGame(self, game):
        """Extends glchess.ui.UI"""
        self.__networkGames.pop(game)

        # Update the open dialogs
        for dialog in self.__joinGameDialogs:
            dialog.removeNetworkGame(game)

    # Protected methods
    
    def _incAttentionCounter(self, offset):
        """
        """
        self.__attentionCounter += offset
        self.__updateAttention()
        
    def __updateAttention(self):
        """
        """
        widget = self._gui.get_widget('glchess_app')
        widget.set_urgency_hint(self.__attentionCounter != 0 and not widget.is_active())
        
    def _on_focus_changed(self, widget, event):
        """Gtk+ callback"""
        self.__updateAttention()

    def _saveView(self, view, path):
        """
        """
        if path is None:
            error = None
        else:
            error = view.feedback.save(path)

        if error is not None:
            return error        
        self.__saveGameDialogs.pop(view)

    def _removeView(self, view):
        """Remove a view from the UI.
        
        'view' is the view to remove.
        """
        self.notebook.removeView(view)
        self._updateViewButtons()

    # Private methods

    def __resize(self):
        try:
            width = glchess.config.get('width')
            height = glchess.config.get('height')
        except glchess.config.Error:
            return
        
        self._gui.get_widget('glchess_app').resize(width, height)

    def __applyConfig(self, name, value):
        """
        """
        if name == 'width' or name == 'height':
            self.__resize()
            return

        # Show/hide the toolbar
        if name == 'show_toolbar':
            toolbar = self.__getWidget('toolbar')
            menu = self.__getWidget('menu_view_toolbar')
            if value is True:
                menu.set_active(True)
                toolbar.show()
            else:
                menu.set_active(False)
                toolbar.hide()
            
        # Show/hide the history
        elif name == 'show_history':
            box = self.__getWidget('navigation_box')
            menu = self.__getWidget('menu_view_history')
            if value is True:
                menu.set_active(True)
                box.show()
            else:
                menu.set_active(False)
                box.hide()
                
        # Fullscreen mode
        elif name == 'fullscreen':
            window = self._gui.get_widget('glchess_app')
            if value is True:
                window.fullscreen()
                self._gui.get_widget('menu_fullscreen').hide()
                self._gui.get_widget('menu_leave_fullscreen').show()
            else:
                window.unfullscreen()
                self._gui.get_widget('menu_leave_fullscreen').hide()
                self._gui.get_widget('menu_fullscreen').show()

        # Enable/disable OpenGL rendering
        elif name == 'show_3d':            
            if value and not chessview.haveGLSupport:
                self._gui.get_widget('3d_support_dialog').show()
                glchess.config.set('show_3d', False)
                value = False
            self.__renderGL = value
            menuItem = self.__getWidget('menu_view_3d')
            menuItem.set_active(self.__renderGL)
            self.notebook.defaultView.viewWidget.setRenderGL(self.__renderGL)
            for view in self.notebook.views:
                view.viewWidget.setRenderGL(self.__renderGL)
                
        elif name == 'show_move_hints':
            menuItem = self.__getWidget('menu_view_move_hints')
            menuItem.set_active(value)
            for view in self.notebook.views:
                view.feedback.showMoveHints(value)
        
        elif name == 'move_format':
            self._gui.get_widget('menu_movef_%s' % value).set_active(True)
            self.moveFormat = value
            for view in self.notebook.views:
                view.setMoveFormat(value)
                
        elif name == 'promotion_type':
            try:
                radio = self.__promotionRadioByType[value]
            except KeyError:
                glchess.config.default('promotion_type')
            else:
                radio.set_active(True)
        
    def startAnimation(self):
        """Start the animation callback"""
        if self.__animationTimer is None:
            self.__lastTime = time.time()
            self.__animationTimer = gobject.timeout_add(10, self.__animate)

    def __animate(self):
        # Get the timestep, if it is less than zero or more than a second
        # then the system clock was probably changed.
        now = time.time()
        step = now - self.__lastTime
        if step < 0.0:
            step = 0.0
        elif step > 1.0:
            step = 1.0
        self.__lastTime = now
        
        # Animate!
        animating = self.feedback.onAnimate(step)
        if not animating:
            self.__animationTimer = None
        
        # Keep/delete timer
        return animating

    def __getWidget(self, name):
        widget = self._gui.get_widget(name)
        assert(widget is not None)
        return widget
    
    def _on_show_toolbar_clicked(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_toolbar', value)

    def _on_show_history_clicked(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_history', value)

    def _on_toggle_3d_clicked(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_3d', value)

    def _on_toggle_move_hints_clicked(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_move_hints', value)       

    def _on_show_ai_stats_clicked(self, widget):
        """Gtk+ callback"""
        window = self._gui.get_widget('ai_window')
        if widget.get_active():
            window.show()
        else:
            window.hide()

    def _on_history_combo_changed(self, widget):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        
        # Get the move number
        moveNumber = model.get_value(iter, 1)
        
        string = 'Show move number: ' + str(moveNumber)
        if moveNumber == len(model) - 1:
            string += ' (latest)'
            moveNumber = -1
        
        view = self.notebook.getView()
        if view is not None:
            view._setMoveNumber(moveNumber)
            
    def _on_menu_movef_human_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('move_format', 'human')

    def _on_menu_movef_lan_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('move_format', 'lan')

    def _on_menu_movef_san_activate(self, widget):
        """Gtk+ callback"""
        glchess.config.set('move_format', 'san')
        
    def _on_promotion_type_changed(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            glchess.config.set('promotion_type', self.__promotionTypeByRadio[widget])
        
    def __selectMoveNumber(self, moveNumber):
        """FIXME
        """
        combo = self.__getWidget('history_combo')
        
        # Limit moves to the maximum value
        maxNumber = len(combo.get_model())

        # Allow negative indexing
        if moveNumber < 0:
            moveNumber = maxNumber + moveNumber
        if moveNumber < 0:
            moveNumber = 0
        if moveNumber >= maxNumber:
            moveNumber = maxNumber - 1
        
        combo.set_active(moveNumber)

    def __selectMoveNumberRelative(self, offset):
        """FIXME
        """
        combo = self.__getWidget('history_combo')
        selected = combo.get_active()
        maxNumber = len(combo.get_model())
        new = selected + offset
        if new < 0:
            new = 0
        elif new >= maxNumber:
            new = maxNumber - 1
        self.__selectMoveNumber(new)

    def _on_history_start_clicked(self, widget):
        """Gtk+ callback"""
        self.__selectMoveNumber(0)

    def _on_history_previous_clicked(self, widget):
        """Gtk+ callback"""
        self.__selectMoveNumberRelative(-1)

    def _on_history_next_clicked(self, widget):
        """Gtk+ callback"""
        self.__selectMoveNumberRelative(1)

    def _on_history_latest_clicked(self, widget):
        """Gtk+ callback"""
        self.__selectMoveNumber(-1)

    def _on_view_changed(self, widget, page, pageNum):
        """Gtk+ callback"""
        # Set the window title to the name of the game
        view = self.notebook.getView()
        title = gettext.gettext('Chess')
        if view is not None:
            title += " - %s" % view.title
        self._gui.get_widget('glchess_app').set_title(title)
        
        # Set toolbar/menu buttons to state for this game
        self._updateViewButtons()
    
    def _updateViewButtons(self):
        """
        """
        view = self.notebook.getView()
        enableWidgets = (view is not None) and view.isActive
        self.__getWidget('end_game_button').set_sensitive(enableWidgets)
        self.__getWidget('save_game_button').set_sensitive(enableWidgets)
        self.__getWidget('menu_save_item').set_sensitive(enableWidgets)
        self.__getWidget('menu_save_as_item').set_sensitive(enableWidgets)
        self.__getWidget('menu_end_game_item').set_sensitive(enableWidgets)

        combo = self.__getWidget('history_combo')
        if view is None:
            if combo.get_model() != None:
                combo.set_model(None)
        else:
            (model, selected) = view._getModel()
            combo.set_model(model)
            if selected < 0:
                selected = len(model) + selected
            combo.set_active(selected)
        self.__getWidget('navigation_box').set_sensitive(enableWidgets)

    def _on_new_game_button_clicked(self, widget):
        """Gtk+ callback"""
        dialogs.GtkNewGameDialog(self, self.__playerModel)

    def _on_join_game_button_clicked(self, widget):
        """Gtk+ callback"""
        self.feedback.onNewNetworkGame()

    def _on_open_game_button_clicked(self, widget):
        """Gtk+ callback"""
        dialogs.GtkLoadGameDialog(self)
        
    def _on_save_game_button_clicked(self, widget):
        """Gtk+ callback"""
        view = self.notebook.getView()
        
        if view.feedback.getFileName() is not None:
            view.feedback.save()
        elif not self.__saveGameDialogs.has_key(view):
            self.__saveGameDialogs[view] = dialogs.GtkSaveGameDialog(self, view)
            
    def _on_save_as_game_button_clicked(self, widget):
        """Gtk+ callback"""
        view = self.notebook.getView()
        if not self.__saveGameDialogs.has_key(view):
            self.__saveGameDialogs[view] = dialogs.GtkSaveGameDialog(self, view, view.feedback.getFileName())

    def _on_end_game_button_clicked(self, widget):
        """Gtk+ callback"""
        view = self.notebook.getView()
        assert(view is not None)
        if view.feedback is not None:
            view.feedback.close()

    def _on_help_clicked(self, widget):
        """Gtk+ callback"""
        gnome.help_display('glchess')

    def _on_view_fullscreen_clicked(self, widget):
        """Gtk+ callback"""
        glchess.config.set('fullscreen', True)
        
    def _on_view_unfullscreen_clicked(self, widget):
        """Gtk+ callback"""
        glchess.config.set('fullscreen', False)
        
    def _on_3d_support_dialog_delete_event(self, widget, event):
        """Gtk+ callback"""
        # Stop the dialog from deleting itself
        return True

    def _on_3d_support_dialog_response(self, widget, responseId):
        """Gtk+ callback"""
        if self.__aboutDialog is not None:
            return
        widget.hide()
        return False

    def _on_about_clicked(self, widget):
        """Gtk+ callback"""
        if self.__aboutDialog is not None:
            return
        
        dialog = self.__aboutDialog = gtk.AboutDialog()
        dialog.set_name(APPNAME)
        dialog.set_version(VERSION)
        dialog.set_copyright(COPYRIGHT)
        dialog.set_license(LICENSE[0] + '\n\n' + LICENSE[1] + '\n\n' +LICENSE[2])
        dialog.set_wrap_license(True)
        dialog.set_comments(DESCRIPTION)
        dialog.set_authors(AUTHORS)
        dialog.set_artists(ARTISTS)
        string = ''
        for t in TRANSLATORS:
            string += t + '\n'
        dialog.set_translator_credits(string[:-1])
        dialog.set_website(WEBSITE)
        dialog.set_website_label(WEBSITE_LABEL)
        dialog.set_logo_icon_name('glchess')
        dialog.connect('response', self._on_glchess_about_dialog_close)
        dialog.show()
        
    def _on_glchess_about_dialog_close(self, widget, event):
        """Gtk+ callback"""
        self.__aboutDialog.destroy()
        self.__aboutDialog = None
        return False
        
    def _on_ai_window_delete_event(self, widget, event):
        """Gtk+ callback"""
        self._gui.get_widget('menu_view_ai').set_active(False)
        
        # Stop the event - the window will be closed by the menu event
        return True
   
    def _on_save_dialog_response(self, widget, responseId):
        """Gtk+ callback"""
        self.saveDialog.setVisible(False)
        
        if responseId != gtk.RESPONSE_OK:
            return
        
        # Save the requested games
        for (view, save, _) in self.saveDialog.model:
            if save:
                view.feedback.save()

        self.feedback.onQuit()
        
    def _on_save_dialog_delete(self, widget, event):
        """Gtk+ callback"""
        # Leave it to use to hide the dialog
        return True
    
    def _on_resize(self, widget, event):
        """Gtk+ callback"""
        glchess.config.set('width', event.width)
        glchess.config.set('height', event.height)

    def _on_close_window(self, widget, event):
        """Gtk+ callback"""
        self._quit()
        
    def _on_menu_quit(self, widget):
        """Gtk+ callback"""
        self._quit()
        
    def _quit(self):
        # Check if any views need saving
        viewsToSave = []
        for view in self.notebook.views:
            if view.feedback.needsSaving():
                viewsToSave.append(view)
             
        if len(viewsToSave) == 0:
            self.feedback.onQuit()
        else:
            self.saveDialog.setViews(viewsToSave)
            self.saveDialog.setVisible(True)

        # Don't close the window, we will do it ourself
        return True

if __name__ == '__main__':
    ui = GtkUI()
    ui.run()
