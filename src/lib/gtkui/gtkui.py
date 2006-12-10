__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['GtkView', 'GtkUI']

# TODO: Extend base UI classes?

import os
import sys
import traceback
import time
import gettext

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

# Optionally use OpenGL support
try:
    import gtk.gtkgl
    import OpenGL
except ImportError:
    haveGLSupport = False
else:
    haveGLSupport = True

# Stop PyGTK from catching exceptions
os.environ['PYGTK_FATAL_EXCEPTIONS'] = '1'

import glchess.config
import glchess.ui
import dialogs

def loadGladeFile(name, root = None, domain = None):
    return gtk.glade.XML(os.path.join(GLADE_DIR, name), root, domain = domain)

class GtkViewArea(gtk.DrawingArea):
    """Custom widget to render an OpenGL scene"""
    # The view this widget is rendering
    view = None

    # Pixmaps to use for double buffering
    pixmap = None
    dynamicPixmap = None
    
    # Flag to show if this scene is to be rendered using OpenGL
    renderGL = False
    
    # TODO...
    __glDrawable = None
    
    def __init__(self, view):
        """
        """
        gtk.DrawingArea.__init__(self)
        
        self.view = view

        if haveGnomeSupport:
            gnome.program_init('glchess', VERSION,
                               properties={gnome.PARAM_APP_DATADIR: APP_DATA_DIR})

        # Allow notification of button presses
        self.add_events(gtk.gdk.BUTTON_PRESS_MASK | gtk.gdk.BUTTON_RELEASE_MASK | gtk.gdk.BUTTON_MOTION_MASK)
        
        # Make openGL drawable
        if hasattr(gtk, 'gtkgl'):
            gtk.gtkgl.widget_set_gl_capability(self, self.view.ui.notebook.glConfig)# FIXME:, share_list=glContext)

        # Connect signals
        self.connect('realize', self.__init)
        self.connect('configure_event', self.__configure)
        self.connect('expose_event', self.__expose)
        self.connect('button_press_event', self.__button_press)
        self.connect('button_release_event', self.__button_release)
        
    # Public methods
        
    def redraw(self):
        """Request this widget is redrawn"""
        #FIXME: Check this is valid
        self.window.invalidate_rect(self.allocation, False)

    def setRenderGL(self, renderGL):
        """Enable OpenGL rendering"""
        if not haveGLSupport:
            renderGL = False
        
        if self.renderGL == renderGL:
            return
        self.renderGL = renderGL
        self.redraw()
    
    # Private methods

    def __startGL(self):
        """Get the OpenGL context"""
        if not self.renderGL:
            return

        assert(self.__glDrawable is None)
        
        # Obtain a reference to the OpenGL drawable
        # and rendering context.
        glDrawable = gtk.gtkgl.widget_get_gl_drawable(self)
        glContext = gtk.gtkgl.widget_get_gl_context(self)

        # OpenGL begin.
        if not glDrawable.gl_begin(glContext):
            return
        
        self.__glDrawable = glDrawable

        if not self.view.ui.openGLInfoPrinted:
            print 'Using OpenGL:'
            print 'VENDOR=' + OpenGL.GL.glGetString(OpenGL.GL.GL_VENDOR)
            print 'RENDERER=' + OpenGL.GL.glGetString(OpenGL.GL.GL_RENDERER)
            print 'VERSION=' + OpenGL.GL.glGetString(OpenGL.GL.GL_VERSION)
            print 'EXTENSIONS=' + OpenGL.GL.glGetString(OpenGL.GL.GL_EXTENSIONS)
            self.view.ui.openGLInfoPrinted = True
        
    def __endGL(self):
        """Free the OpenGL context"""
        if not self.renderGL:
            return
        
        assert(self.__glDrawable is not None)
        self.__glDrawable.gl_end()
        self.__glDrawable = None
        
    def __init(self, widget):
        """Gtk+ signal"""
        if self.view.feedback is not None:
            self.view.feedback.reshape(widget.allocation.width, widget.allocation.height)
        
    def __configure(self, widget, event):
        """Gtk+ signal"""
        self.pixmap = gtk.gdk.Pixmap(widget.window, event.width, event.height)
        self.dynamicPixmap = gtk.gdk.Pixmap(widget.window, event.width, event.height)
        self.__startGL()
        if self.view.feedback is not None:
            self.view.feedback.reshape(event.width, event.height)
        self.__endGL()

    def __expose(self, widget, event):
        """Gtk+ signal"""
        if self.renderGL:
            self.__startGL()
        
            # Get the scene rendered
            try:
                if self.view.feedback is not None:
                    self.view.feedback.renderGL()
            except OpenGL.GLerror, e:
                print 'Rendering Error: ' + str(e)
                traceback.print_exc(file = sys.stdout)

            # Paint this
            if self.__glDrawable.is_double_buffered():
                self.__glDrawable.swap_buffers()
            else:
                glFlush()

            self.__endGL()
            
        else:
            context = self.pixmap.cairo_create()
            if self.view.feedback is not None:
                self.view.feedback.renderCairoStatic(context)
            
            # Copy the background to render the dynamic elements on top
            self.dynamicPixmap.draw_drawable(widget.get_style().white_gc, self.pixmap, 0, 0, 0, 0, -1, -1)
            context = self.dynamicPixmap.cairo_create()
        
            # Set a clip region for the expose event
            context.rectangle(event.area.x, event.area.y, event.area.width, event.area.height)
            context.clip()
           
            # Render the dynamic elements
            if self.view.feedback is not None:
                self.view.feedback.renderCairoDynamic(context)
                
            # Draw the window
            widget.window.draw_drawable(widget.get_style().white_gc, self.dynamicPixmap,
                                        event.area.x, event.area.y,
                                        event.area.x, event.area.y, event.area.width, event.area.height)

    def __button_press(self, widget, event):
        """Gtk+ signal"""
        self.__startGL()
        if self.view.feedback is not None:
            self.view.feedback.select(event.x, event.y)
        self.__endGL()
        
    def __button_release(self, widget, event):
        """Gtk+ signal"""
        self.__startGL()
        if self.view.feedback is not None:
            self.view.feedback.deselect(event.x, event.y)
        self.__endGL()
        
class GtkView(glchess.ui.ViewController):
    """
    """
    # The UI this view belongs to
    ui            = None
    
    # The title of this view
    title         = None
    
    # The widget to render the scene to
    widget        = None
    
    # A Gtk+ tree model to store the move history
    moveModel    = None
    selectedMove = -1
    
    def __init__(self, ui, title, feedback, isActive = True):
        """Constructor for a view.
        
        'feedback' is the feedback object for this view (extends ui.ViewFeedback).
        'isActive' is a flag showing if this view can be controlled by the user (True) or not (False).
        """
        self.ui = ui
        self.title = title
        self.feedback = feedback
        self.isActive = isActive
        self.widget = GtkViewArea(self)

        # Make a model for navigation
        model = gtk.ListStore(int, str)
        iter = model.append()
        model.set(iter, 0, 0, 1, gettext.gettext('Game Start'))
        self.moveModel = model

        self.widget.show_all()
    
    # Extended methods
    
    def render(self):
        """Extends glchess.ui.ViewController"""
        self.widget.redraw()
        
    def addMove(self, move):
        """Extends glchess.ui.ViewController"""
        # FIXME: Make a '@ui' player who watches for these itself?
        iter = self.moveModel.append()
        string = '%2i. ' % ((move.number - 1) / 2 + 1)
        if move.number % 2 == 0:
            string += '... '
        string += move.sanMove
        self.moveModel.set(iter, 0, move.number, 1, string)
        
        # If is the current view and tracking the game select this
        if self.selectedMove == -1:
            self.ui._updateViewButtons()
    
    def close(self):
        """Extends glchess.ui.ViewController"""
        self.ui._removeView(self)
    
    # Public methods

    def _getModel(self):
        """
        """
        return (self.moveModel, self.selectedMove)
        
    def _setMoveNumber(self, moveNumber):
        """Set the move number this view requests.
        
        'moveNumber' is the move number to use (integer).
        """
        self.selectedMove = moveNumber
        if self.feedback is not None:
            self.feedback.setMoveNumber(moveNumber)

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
        self.defaultView = GtkView(self.ui, '', feedback)
        page = self.append_page(self.defaultView.widget)
        self.set_current_page(page)
        
        self.__updateTabVisibleState()
        
        return self.defaultView

    def addView(self, title, feedback):
        """
        """
        view = GtkView(self.ui, title, feedback)
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
        self.__gui = loadGladeFile('ai.glade', 'ai_table', domain = 'glchess')
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
            
class SaveDialog:
    """
    """

    def __init__(self, ui):
        """Constructor"""
        self.ui = ui
        self.model = gtk.ListStore(gobject.TYPE_PYOBJECT, gobject.TYPE_BOOLEAN, str)
        
        self.view = ui._gui.get_widget('save_games_treeview')
        self.view.set_model(self.model)
        
        selection = self.view.get_selection()
        selection.set_mode(gtk.SELECTION_NONE)

        cell = gtk.CellRendererToggle()
        cell.set_property('activatable', True)
        cell.connect('toggled', self._toggle_cb)
        column = gtk.TreeViewColumn('Save', cell)
        column.add_attribute(cell, 'active', 1)
        self.view.append_column(column)
        
        cell = gtk.CellRendererText()
        column = gtk.TreeViewColumn('Game', cell)
        column.add_attribute(cell, 'text', 2)
        self.view.append_column(column)
        
    def setViews(self, views):
        """
        """
        self.model.clear()
        for view in views:
            iter = self.model.append()
            self.model.set(iter, 0, view, 1, True, 2, view.title)

    def setVisible(self, isVisible):
        """
        """
        widget = self.ui._gui.get_widget('save_dialog')
        if isVisible:
            widget.show_all()
        else:
            widget.hide()
            
    def _toggle_cb(self, widget, path, data = None):
        """Gtk+ callback"""
        self.model[path][1] = not self.model[path][1]

class GtkUI(glchess.ui.UI):
    """
    """
    # The Gtk+ GUI
    _gui              = None
    
    # The time stored for animation
    __lastTime        = None
    __animationTimer  = None

    # The notebook containing games
    notebook        = None
    
    # The Gtk+ list model of the available player types
    __playerModel     = None
    
    # The about dialog open
    __aboutDialog     = None
    
    # Dictionary of save game dialogs keyed by view
    __saveGameDialogs = None
    
    __renderGL        = False
    openGLInfoPrinted = False

    # TODO
    __joinGameDialogs = None
    __networkGames    = None
    
    __defaultWhiteAI  = None
    __defaultBlackAI  = None
    
    def __init__(self):
        """Constructor for a GTK+ glChess GUI"""
        self.__networkGames = {}
        self.__saveGameDialogs = {}
        self.__joinGameDialogs = []
        
        self._gui = loadGladeFile('glchess.glade', domain = 'glchess')
        self._gui.signal_autoconnect(self)

        # Make a notebook for the games
        self.notebook = GtkGameNotebook(self)
        self.notebook.connect_after('switch-page', self._on_view_changed)
        self.__getWidget('game_viewport').add(self.notebook)
        self.notebook.show_all()
        
        # Create the model for the player types
        self.__playerModel = gtk.ListStore(gobject.TYPE_PYOBJECT, gtk.gdk.Pixbuf, str)
        iconTheme = gtk.icon_theme_get_default()
        try:
            icon = iconTheme.load_icon('stock_people', 24, gtk.ICON_LOOKUP_USE_BUILTIN)
        except gobject.GError:
            icon = None
        iter = self.__playerModel.append()
        self.__playerModel.set(iter, 0, None, 1, icon, 2, gettext.gettext('Human'))
        # FIXME: Add spectators for network games
        
        self.__aiWindow = AIWindow(self._gui.get_widget('ai_notebook'))
        
        combo = self.__getWidget('history_combo')
        cell = gtk.CellRendererText()
        combo.pack_start(cell, False)
        combo.add_attribute(cell, 'text', 1)

        self.defaultViewController = self.notebook.setDefault(None)
        
        # Disable OpenGL support
        if not hasattr(gtk, 'gtkgl'):
            self._gui.get_widget('menu_view_3d').set_sensitive(False)
        
        self.defaultViewController.widget.setRenderGL(self.__renderGL)

        self.saveDialog = SaveDialog(self)
        
        # Watch for config changes
        glchess.config.watch('show_toolbar', self.__applyConfig)
        glchess.config.watch('show_history', self.__applyConfig)
        glchess.config.watch('fullscreen', self.__applyConfig)
        glchess.config.watch('show_3d', self.__applyConfig)
        glchess.config.watch('width', self.__applyConfig)
        glchess.config.watch('height', self.__applyConfig)

    # Public methods
    
    def watchFileDescriptor(self, fd):
        """Extends ui.UI"""
        gobject.io_add_watch(fd, gobject.IO_IN, self.__readData)

    def __readData(self, fd, condition):
        return self.onReadFileDescriptor(fd)

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
        view.widget.setRenderGL(self.__renderGL)
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
        for name in ['show_toolbar', 'show_history', 'show_3d']:
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

    def reportError(self, title, error):
        """Extends glchess.ui.UI"""
        dialogs.GtkErrorDialog(title, error)
        
    def reportGameLoaded(self, gameName = None,
                         whiteName = None, blackName = None,
                         whiteAI = None, blackAI = None, moves = None):
        """Extends glchess.ui.UI"""
        dialogs.GtkNewGameDialog(self, self.__playerModel, gameName = gameName,
                                 whiteName = whiteName, whiteAI = whiteAI,
                                 blackName = blackName, blackAI = blackAI, moves = moves)
                                 
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

    def _saveView(self, view, path):
        """
        """
        self.__saveGameDialogs.pop(view)
        if path is None:
            return
        
        if view.feedback is not None:
            view.feedback.save(path)
            
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
            self.__renderGL = value
            menuItem = self.__getWidget('menu_view_3d')
            menuItem.set_active(self.__renderGL)
            self.notebook.defaultView.widget.setRenderGL(self.__renderGL)
            for view in self.notebook.views:
                view.widget.setRenderGL(self.__renderGL)
        
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
        animating = self.onAnimate(step)
        if not animating:
            self.__animationTimer = None
        
        # Keep/delete timer
        return animating

    def __getWidget(self, name):
        return self._gui.get_widget(name)
    
    def _on_show_toolbar_clicked(self, widget, data = None):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_toolbar', value)

    def _on_show_history_clicked(self, widget, data = None):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_history', value)

    def _on_toggle_3d_clicked(self, widget, data = None):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_3d', value)

    def _on_show_ai_stats_clicked(self, widget, data = None):
        """Gtk+ callback"""
        window = self._gui.get_widget('ai_window')
        if widget.get_active():
            window.show()
        else:
            window.hide()

    def _on_history_combo_changed(self, widget, data = None):
        """Gtk+ callback"""
        model = widget.get_model()
        iter = widget.get_active_iter()
        if iter is None:
            return
        
        # Get the move number
        moveNumber = model.get_value(iter, 0)
        
        string = 'Show move number: ' + str(moveNumber)
        if moveNumber == len(model) - 1:
            string += ' (latest)'
            moveNumber = -1
        
        view = self.notebook.getView()
        if view is not None:
            view._setMoveNumber(moveNumber)
        
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

    def _on_history_start_clicked(self, widget, data = None):
        """Gtk+ callback"""
        self.__selectMoveNumber(0)

    def _on_history_previous_clicked(self, widget, data = None):
        """Gtk+ callback"""
        self.__selectMoveNumberRelative(-1)

    def _on_history_next_clicked(self, widget, data = None):
        """Gtk+ callback"""
        self.__selectMoveNumberRelative(1)

    def _on_history_latest_clicked(self, widget, data = None):
        """Gtk+ callback"""
        self.__selectMoveNumber(-1)

    def _on_view_changed(self, widget, page, pageNum, data = None):
        """Gtk+ callback"""
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

    def _on_new_game_button_clicked(self, widget, data = None):
        """Gtk+ callback"""
        
        dialogs.GtkNewGameDialog(self, self.__playerModel, whiteAI = self.__defaultWhiteAI, blackAI = self.__defaultBlackAI)

    def _on_join_game_button_clicked(self, widget, data = None):
        """Gtk+ callback"""
        # Create the dialog
        dialog = dialogs.GtkJoinGameDialog(self, self.__playerModel)
        self.__joinGameDialogs.append(dialog)
        # FIXME: Remove from this list when they dissapear
        
        # Add the detected games into the dialog
        for (game, name) in self.__networkGames.iteritems():
            dialog.addNetworkGame(name, game)

    def _on_open_game_button_clicked(self, widget, data = None):
        """Gtk+ callback"""
        dialogs.GtkLoadGameDialog(self)
        
    def _on_save_game_button_clicked(self, widget, data = None):
        """Gtk+ callback"""
        view = self.notebook.getView()
        
        if view.feedback.getFileName() is not None:
            view.feedback.save()
        elif not self.__saveGameDialogs.has_key(view):
            self.__saveGameDialogs[view] = dialogs.GtkSaveGameDialog(self, view)
            
    def _on_save_as_game_button_clicked(self, widget, data = None):
        view = self.notebook.getView()
        if not self.__saveGameDialogs.has_key(view):
            self.__saveGameDialogs[view] = dialogs.GtkSaveGameDialog(self, view, view.feedback.getFileName())

    def _on_end_game_button_clicked(self, widget, data = None):
        """Gtk+ callback"""
        view = self.notebook.getView()
        assert(view is not None)
        if view.feedback is not None:
            view.feedback.close()

    def _on_help_clicked(self, widget, data = None):
        """Gtk+ callback"""
        gnome.help_display('glchess')

    def _on_view_fullscreen_clicked(self, widget, data = None):
        """Gtk+ callback"""
        glchess.config.set('fullscreen', True)
        
    def _on_view_unfullscreen_clicked(self, widget, data = None):
        """Gtk+ callback"""
        glchess.config.set('fullscreen', False)

    def _on_about_clicked(self, widget, data = None):
        """Gtk+ callback"""
        if self.__aboutDialog is not None:
            return
        
        dialog = self.__aboutDialog = gtk.AboutDialog()
        dialog.set_name(APPNAME)
        dialog.set_version(VERSION)
        dialog.set_copyright(COPYRIGHT)
        dialog.set_license(LICENSE)
        dialog.set_wrap_license(True)
        dialog.set_comments(DESCRIPTION)
        dialog.set_authors(AUTHORS)
        dialog.set_artists(ARTISTS)
        dialog.set_translator_credits(TRANSLATORS)
        dialog.set_website(WEBSITE)
        dialog.set_website_label(WEBSITE_LABEL)
        dialog.set_logo_icon_name('glchess')
        dialog.set_translator_credits(TRANSLATORS)
        dialog.connect('response', self._on_glchess_about_dialog_close)
        dialog.show()
        
    def _on_glchess_about_dialog_close(self, widget, data = None):
        """Gtk+ callback"""
        self.__aboutDialog.destroy()
        self.__aboutDialog = None
        return False
        
    def _on_ai_window_delete_event(self, widget, data = None):
        """Gtk+ callback"""
        self._gui.get_widget('menu_view_ai').set_active(False)
        
        # Stop the event - the window will be closed by the menu event
        return True
   
    def _on_save_dialog_response(self, widget, response_id, data = None):
        """Gtk+ callback"""
        self.saveDialog.setVisible(False)
        
        if response_id != gtk.RESPONSE_OK:
            return
        
        # Save the requested games
        for (view, save, _) in self.saveDialog.model:
            if save:
                view.feedback.save()

        self.onQuit()
        
    def _on_save_dialog_delete(self, widget, data = None):
        """Gtk+ callback"""
        # Leave it to use to hide the dialog
        return True
    
    def _on_resize(self, widget, event, data = None):
        """Gtk+ callback"""
        glchess.config.set('width', event.width)
        glchess.config.set('height', event.height)

    def _on_quit(self, widget, data = None):
        """Gtk+ callback"""
        # Check if any views need saving
        viewsToSave = []
        for view in self.notebook.views:
            if view.feedback.needsSaving():
                viewsToSave.append(view)
             
        if len(viewsToSave) == 0:
            self.onQuit()
        else:
            self.saveDialog.setViews(viewsToSave)
            self.saveDialog.setVisible(True)

        # Don't close the window, we will do it ourself
        return True

if __name__ == '__main__':
    ui = GtkUI()
    ui.run()
