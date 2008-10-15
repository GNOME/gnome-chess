# -*- coding: utf-8 -*-

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

__all__ = ['GtkUI']

# TODO: Extend base UI classes?

import os
import sys
import time
from gettext import gettext as _

import gobject
import gtk
import gtk.glade
import gtk.gdk
import cairo
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
import log
import chessview
import network

# Mark all windows with our icon
gtk.window_set_default_icon_name(ICON_NAME)

def loadGladeFile(name, root = None):
    return gtk.glade.XML(os.path.join(GLADE_DIR, name), root, domain = DOMAIN)

class GLibTimer(glchess.ui.Timer):
    """
    """
    
    # FIXME: time.time() is _not_ monotonic so this is not really safe at all...

    def __init__(self, ui, feedback, duration):
        self.ui        = ui
        self.feedback  = feedback
        self.tickTime  = 0
        self.reportedTickTime = 0
        
        self.timer     = None
        self.tickTimer = None
        self.startTime = None
        self.set(duration * 1000)
        
    def set(self, duration):
        """
        """
        if self.timer is not None:
            gobject.source_remove(self.timer)
        if self.tickTimer is not None:
            gobject.source_remove(self.tickTimer)
        self.duration = duration
        self.consumed = 0
        
        # Notified if the second has changed      
        
    def __consumed(self, now):
        # Total time - time at last start - time since start
        if self.startTime is None:
            return self.consumed
        else:
            return self.consumed + (now - self.startTime)
        
    def getRemaining(self):
        """Extends ui.Timer"""
        return self.duration - self.__consumed(int(1000 * time.time()))

    def pause(self):
        """Extends ui.Timer"""
        if self.timer is None:
            return
        
        # Calculate the amount of time to use when restarted
        self.consumed = self.__consumed(int(1000 * time.time()))
        
        # Remove timers
        gobject.source_remove(self.timer)
        if self.tickTimer is not None:
            gobject.source_remove(self.tickTimer)
        self.timer = None
        self.tickTimer = None
    
    def run(self):
        """Extends ui.Timer"""
        if self.timer is not None:
            return
        
        # Notify when all time runs out
        self.startTime = int(1000 * time.time())
        self.timer = gobject.timeout_add(self.duration - self.consumed, self.__expired)
        
        # Notify on the next second boundary
        self.__setSecondTimer(self.startTime)

    def __setSecondTimer(self, now):
        """Set a timer to expire on the next second boundary"""
        assert(self.tickTimer is None)
        
        # Round the remaining time up to the nearest second
        consumed = self.__consumed(now)
        t = 1000 * (consumed / 1000 + 1)
        if t <= self.reportedTickTime:
            self.tickTime = self.reportedTickTime + 1000
        else:
            self.tickTime = t
        
        # Notify on this time
        if self.tickTime > self.duration:
            self.tickTimer = None
        else:
            self.tickTimer = gobject.timeout_add(self.tickTime - consumed, self.__tick)

    def __expired(self):
        """Called by GLib main loop"""
        self.feedback.onTick(0)
        self.feedback.onExpired()
        if self.tickTimer is not None:
            gobject.source_remove(self.tickTimer)
        self.timer = None
        self.tickTimer = None
        return False

    def __tick(self):
        """Called by GLib main loop"""
        self.reportedTickTime = self.tickTime
        self.feedback.onTick((self.duration - self.tickTime) / 1000)
        self.tickTimer = None
        self.__setSecondTimer(int(1000 * time.time()))
        return False

    def delete(self):
        """Extends ui.Timer"""
        gobject.source_remove(self.timer)

class GtkUI(glchess.ui.UI):
    """
    """
    # The Gtk+ GUI
    _gui               = None
    
    # The time stored for animation
    __lastTime         = None
    __animationTimer   = None
    
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

    whiteTimeString    = '∞'
    blackTimeString    = '∞'
    
    # The window width and height when unmaximised and not fullscreen
    width              = None
    height             = None
    isFullscreen       = False
    isMaximised        = False
    
    view               = None

    def __init__(self, feedback):
        """Constructor for a GTK+ glChess GUI"""
        if haveGnomeSupport:
            gnome.program_init('glchess', VERSION,
                               properties={gnome.PARAM_APP_DATADIR: APP_DATA_DIR})

        self.feedback = feedback
        self._watches = {}
        self.__networkGames = {}
        self.newGameDialog = None
        self.loadGameDialog = None
        self.__saveGameDialogs = {}
        self.__joinGameDialogs = []
        
        # Set the message panel to the tooltip style
        # (copied from Gedit)
        # In Gtk+ 2.11+ (I think) tip_window is now private so skip if it's not there (bug #459740)
        tooltip = gtk.Tooltips()
        tooltip.force_window()
        if hasattr(tooltip, 'tip_window') and tooltip.tip_window != None:
            tooltip.tip_window.ensure_style()
            self._tooltipStyle = tooltip.tip_window.get_style()
        else:
            self._tooltipStyle = None
        self._tooltipWidgetsDrawn = {}
        
        self._gui = loadGladeFile('glchess.glade')
        self._gui.signal_autoconnect(self)
        
        self.mainWindow = self._gui.get_widget('glchess_app')
        
        # Workaround as Glade 2 always overrides the system style for toolbars
        self.__getWidget('toolbar').unset_style()
        
        # Create the model for the player types
        self.__playerModel = gtk.ListStore(str, str, str)
        iter = self.__playerModel.append()
        self.__playerModel.set(iter, 0, '', 1, 'stock_person', 2, _('Human'))
        
        self.__logWindow = log.LogWindow(self._gui.get_widget('log_notebook'))
        
        # Make preferences dialog
        self.preferences = dialogs.GtkPreferencesDialog(self)

        # Balance space on each side of the history combo
        group = gtk.SizeGroup(gtk.SIZE_GROUP_BOTH)
        group.add_widget(self.__getWidget('left_nav_box'))
        group.add_widget(self.__getWidget('right_nav_box'))

        # History combo displays text data
        combo = self.__getWidget('history_combo')
        cell = gtk.CellRendererText()
        combo.pack_start(cell, False)
        combo.add_attribute(cell, 'text', 2)

        # Disble help support
        if haveGnomeSupport:
            self._gui.get_widget('menu_help').show()
        
        self._updateViewButtons()
        
        # Watch for config changes
        for key in ['show_toolbar', 'show_history', 'fullscreen',
                    'show_3d', 'show_comments', 'show_numbering',
                    'show_move_hints',
                    'width', 'height',
                    'move_format', 'promotion_type', 'board_view',
                    'enable_networking']:
            glchess.config.watch(key, self.__applyConfig)

    # Public methods
    
    def setTooltipStyle(self, widget):
        """Set a widget to be in the tooltip style.
        
        'widget' is the widget to modify.
        """
        if self._tooltipStyle is None:
            return
        widget.set_style(self._tooltipStyle)
        widget.connect("expose_event", self._on_tooltip_expose_event)
        widget.queue_draw()

    def _on_tooltip_expose_event(self, widget, event):
        """Gtk+ callback"""
        allocation = widget.allocation
        widget.style.paint_flat_box(widget.window, gtk.STATE_NORMAL, gtk.SHADOW_OUT, None, widget, "tooltip",
                                    allocation.x, allocation.y, allocation.width, allocation.height)
                                    
        # The first draw is corrupt for me so draw it twice.
        # Bonus points to anyone who tracks down the problem and fixes it
        if not self._tooltipWidgetsDrawn.has_key(widget):
            self._tooltipWidgetsDrawn[widget] = True
            widget.queue_draw()
    
    def watchFileDescriptor(self, fd):
        """Extends ui.UI"""
        self._watches[fd] = gobject.io_add_watch(fd, gobject.IO_IN | gobject.IO_PRI | gobject.IO_HUP | gobject.IO_ERR, self.__readData)
        
    def unwatchFileDescriptor(self, fd):
        """Extends ui.UI"""
        gobject.source_remove(self._watches.pop(fd))
        
    def writeFileDescriptor(self, fd):
        """Extends ui.UI"""
        gobject.io_add_watch(fd, gobject.IO_OUT, self.__writeData)
        
    def addTimer(self, feedback, duration):
        """Extends ui.UI"""
        return GLibTimer(self, feedback, duration)

    def __timerExpired(self, method):
        method()
        return True

    def __readData(self, fd, condition):
        #print (fd, condition)
        return self.feedback.onReadFileDescriptor(fd)

    def __writeData(self, fd, condition):
        #print (fd, condition)
        return self.feedback.onWriteFileDescriptor(fd)

    def addAIEngine(self, name):
        """Register an AI engine.
        
        'name' is the name of the engine.
        TODO: difficulty etc etc
        """
        iter = self.__playerModel.append()
        self.__playerModel.set(iter, 0, name, 1, 'stock_notebook', 2, name)
        
        # Get the human to play against this AI
        if self.__defaultBlackAI is None:
            self.__defaultBlackAI = name

    def setView(self, title, feedback, isPlayable = True):
        """Extends ui.UI"""
        moveFormat = glchess.config.get('move_format')
        showComments = glchess.config.get('show_comments')
        self.view = chessview.GtkView(self, feedback, moveFormat = moveFormat, showComments = showComments)
        self.view.setTitle(title)
        self.view.isPlayable = isPlayable
        self.view.viewWidget.setRenderGL(self.__renderGL)
        viewport = self.__getWidget('game_viewport')
        child = viewport.get_child()
        if child is not None:
            viewport.remove(child)
        viewport.add(self.view.widget)

        # Set toolbar/menu buttons to state for this game
        self._updateViewButtons()
        
        # Update timers
        if self.view is not None:
            self.setTimers(self.view.whiteTime, self.view.blackTime)

        return self.view

    def updateTitle(self):
        """
        """
        # Set the window title to the name of the game
        if self.view is not None and len(self.view.title) > 0:
            if self.view.needsSaving:
                # Translators: This is the window title when playing a game that needs saving
                title = _('Chess - *%(game_name)s') % {'game_name': self.view.title}
            else:
                # Translators: This is the window title when playing a game that is saved
                title = _('Chess - %(game_name)s') % {'game_name': self.view.title}
        else:
            # Translators: This is the window title when not playing a game
            title = _('Chess')            
        self.mainWindow.set_title(title)

    def addLogWindow(self, title, executable, description):
        """
        """
        return self.__logWindow.addView(title, executable, description)
    
    def setTimers(self, whiteTime, blackTime):
        """
        """
        if whiteTime is None:
            whiteString = _('∞')
        else:
            t = whiteTime[1]
            whiteString = '%i:%02i' % (t / 60, t % 60)
        if blackTime is None:
            blackString = _('∞')
        else:
            t = blackTime[1]
            blackString = '%i:%02i' % (t / 60, t % 60)
            
        if whiteString != self.whiteTimeString:
            self.whiteTimeString = whiteString
            self._gui.get_widget('white_time_label').queue_draw()
        if blackString != self.blackTimeString:
            self.blackTimeString = blackString
            self._gui.get_widget('black_time_label').queue_draw()

    def run(self):
        """Run the UI.
        
        This method will not return.
        """        
        # Load configuration
        for name in ['show_toolbar', 'show_history', 'show_3d',
                     'show_comments', 'show_numbering', 'show_move_hints',
                     'move_format', 'promotion_type', 'board_view', 'maximised',
                     'enable_networking']:
            try:
                value = glchess.config.get(name)
            except glchess.config.Error:
                pass
            else:
                self.__applyConfig(name, value)
        self.__resize()
        
        self.mainWindow.show()

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
        dialog = network.GtkNetworkGameDialog(self, feedback, self.__playerModel)
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
            
    def requestSave(self, title):
        """Extends glchess.ui.UI"""
        dialog = gtk.MessageDialog(flags = gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                                   type = gtk.MESSAGE_WARNING,
                                   message_format = title)
        dialog.format_secondary_text(_("If you don't save the changes to this game will be permanently lost")
        dialog.add_button(_('Close _without saving'), gtk.RESPONSE_OK)
        dialog.add_button(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT)
        dialog.add_button(gtk.STOCK_SAVE, gtk.RESPONSE_ACCEPT)

        response = dialog.run()
        dialog.destroy()
        if response == gtk.RESPONSE_ACCEPT:
            return glchess.ui.SAVE_YES
        elif response == gtk.RESPONSE_OK:
            return glchess.ui.SAVE_NO
        else:
            return glchess.ui.SAVE_ABORT

    def close(self):
        """Extends glchess.ui.UI"""
        # Save the window size
        if self.width is not None:
            glchess.config.set('width', self.width)
        if self.height is not None:
            glchess.config.set('height', self.height)

    # Protected methods
    
    def _incAttentionCounter(self, offset):
        """
        """
        self.__attentionCounter += offset
        self.__updateAttention()
        
    def __updateAttention(self):
        """
        """
        widget = self.mainWindow
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

    # Private methods

    def __resize(self):
        try:
            width = glchess.config.get('width')
            height = glchess.config.get('height')
        except glchess.config.Error:
            return
        
        self.mainWindow.resize(width, height)

    def __applyConfig(self, name, value):
        """
        """
        if name == 'width' or name == 'height':
            self.__resize()
            return

        # Show/hide the toolbar
        if name == 'show_toolbar':
            toolbar = self.__getWidget('toolbar')
            if value is True:
                toolbar.show()
            else:
                toolbar.hide()
                
        elif name == 'enable_networking':
            menuItem = self.__getWidget('menu_play_online_item')
            toolbarButton = self.__getWidget('play_online_button')
            if value is True:
                menuItem.show()
                toolbarButton.show()
            else:
                menuItem.hide()
                toolbarButton.hide()
            
        # Show/hide the history
        elif name == 'show_history':
            box = self.__getWidget('navigation_box')
            if value is True:
                box.show()
            else:
                box.hide()
                
        # Maximised mode
        elif name == 'maximised':
            window = self.mainWindow
            if value is True:
                window.maximize()
            else:
                window.unmaximize()

        # Fullscreen mode
        elif name == 'fullscreen':
            window = self.mainWindow
            if value is True:
                window.fullscreen()
            else:
                window.unfullscreen()

        # Enable/disable OpenGL rendering
        elif name == 'show_3d':            
            if value and not chessview.haveGLSupport:
                title = _('Unable to enable 3D mode')
                errors = '\n'.join(chessview.openGLErrors)
                description = _("""You are unable to play in 3D mode due to the following problems:
%(errors)s

Please contact your system administrator to resolve these problems, until then you will be able to play chess in 2D mode.""") % {'errors': errors}
                dialog = gtk.MessageDialog(type = gtk.MESSAGE_WARNING, message_format = title)
                dialog.format_secondary_text(description)
                dialog.add_button(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE)
                dialog.run()
                dialog.destroy()
                glchess.config.set('show_3d', False)
                value = False
            self.__renderGL = value
            self.__getWidget('menu_view_3d').set_active(value)
            self.view.viewWidget.setRenderGL(value)
                
        elif name == 'show_comments':
            self.view.setShowComments(value)

        elif name == 'show_move_hints':
            self.view.feedback.showMoveHints(value)

        elif name == 'show_numbering':
            self.view.feedback.showBoardNumbering(value)

        elif name == 'move_format':
            self.view.setMoveFormat(value)
                
        elif name == 'promotion_type':
            pass
    
        elif name == 'board_view':
            pass

        else:
            assert(False), 'Unknown config item: %s' % name

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
        assert(widget is not None), 'Unable to find widget: %s' % name
        return widget

    def _on_white_time_paint(self, widget, event):
        """Gtk+ callback"""
        self.__drawTime(self.whiteTimeString, widget, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))

    def _on_black_time_paint(self, widget, event):
        """Gtk+ callback"""
        self.__drawTime(self.blackTimeString, widget, (1.0, 1.0, 1.0), (0.0, 0.0, 0.0))

    def __drawTime(self, text, widget, fg, bg):
        """
        """
        if widget.state == gtk.STATE_INSENSITIVE:
            alpha = 0.5
        else:
            alpha = 1.0
        context = widget.window.cairo_create()
        context.set_source_rgba(bg[0], bg[1], bg[2], alpha)
        context.paint()
        
        (_, _, w, h) = widget.get_allocation()
        
        context.set_source_rgba(fg[0], fg[1], fg[2], alpha)
        context.select_font_face('fixed', cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        context.set_font_size(0.6 * h)
        (x_bearing, y_bearing, width, height, _, _) = context.text_extents(text)
        context.move_to((w - width) / 2 - x_bearing, (h - height) / 2 - y_bearing)
        context.show_text(text)
        
        # Resize to fit text
        widget.set_size_request(int(width) + 6, -1)

    def _on_toggle_3d_clicked(self, widget):
        """Gtk+ callback"""
        if widget.get_active():
            value = True
        else:
            value = False
        glchess.config.set('show_3d', value)

    def _on_show_logs_clicked(self, widget):
        """Gtk+ callback"""
        window = self._gui.get_widget('log_window')
        if widget.get_active():
            window.present()
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
        
        if moveNumber == len(model) - 1:
            moveNumber = -1

        # Disable buttons when at the end
        haveMoves = len(model) > 1
        for widget in ('first_move_button', 'prev_move_button'):
            self.__getWidget(widget).set_sensitive(haveMoves and moveNumber != 0)
        for widget in ('last_move_button', 'next_move_button'):
            self.__getWidget(widget).set_sensitive(haveMoves and moveNumber != -1)

        self.view._setMoveNumber(moveNumber)

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

    def _updateViewButtons(self):
        """
        """
        enable = self.view is not None and self.view.isPlayable
        for widget in ('save_game_button', 'menu_save_item', 'menu_save_as_item'):
            self.__getWidget(widget).set_sensitive(enable)

        combo = self.__getWidget('history_combo')
        if self.view is None:
            if combo.get_model() != None:
                combo.set_model(None)
        else:
            (model, selected) = self.view._getModel()
            combo.set_model(model)
            if selected < 0:
                selected = len(model) + selected
            combo.set_active(selected)
        self.__getWidget('navigation_box').set_sensitive(enable)
        
        enable = enable and self.view.gameResult is None
        '''FIXME! for widget in ('menu_resign', 'resign_button', 'menu_claim_draw'):
            self.__getWidget(widget).set_sensitive(enable)'''

    def _on_new_game_button_clicked(self, widget):
        """Gtk+ callback"""
        if self.newGameDialog:
            self.newGameDialog.window.present()
        else:
            self.newGameDialog = dialogs.GtkNewGameDialog(self, self.__playerModel)

    def _on_join_game_button_clicked(self, widget):
        """Gtk+ callback"""
        self.feedback.onNewNetworkGame()

    def _on_open_game_button_clicked(self, widget):
        """Gtk+ callback"""
        if self.loadGameDialog:
            self.loadGameDialog.window.present()
        else:
            self.loadGameDialog = dialogs.GtkLoadGameDialog(self)
        
    def _on_save_game_button_clicked(self, widget):
        """Gtk+ callback"""
        if self.view.feedback.getFileName() is not None:
            self.view.feedback.save()
            return
        
        try:
            dialog = self.__saveGameDialogs[self.view]
        except KeyError:
            dialog = self.__saveGameDialogs[self.view] = dialogs.GtkSaveGameDialog(self, self.view)
        dialog.window.present()

    def _on_save_as_game_button_clicked(self, widget):
        """Gtk+ callback"""
        try:
            dialog = self.__saveGameDialogs[self.view]
        except KeyError:
            dialog = self.__saveGameDialogs[self.view] = dialogs.GtkSaveGameDialog(self, self.view, self.view.feedback.getFileName())
        dialog.window.present()

    def _on_resign_clicked(self, widget):
        """Gtk+ callback"""
        self.view.feedback.resign()

    def _on_claim_draw_clicked(self, widget):
        """Gtk+ callback"""
        if self.view.feedback.claimDraw():
            return
        dialog = gtk.MessageDialog(flags = gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                                   type = gtk.MESSAGE_WARNING,
                                   message_format = _("Unable to claim draw"))
        dialog.format_secondary_text(_("""You may claim a draw when:
a) The board has been in the same state three times (Three fold repetition)
b) Fifty moves have occured where no pawn has moved and no piece has been captured (50 move rule)"""))
        dialog.add_button(gtk.STOCK_CLOSE, gtk.RESPONSE_ACCEPT)
        dialog.run()
        dialog.destroy()

    def _on_preferences_clicked(self, widget):
        """Gtk+ callback"""
        self.preferences.setVisible(True)

    def _on_help_clicked(self, widget):
        """Gtk+ callback"""
        try:
            gnome.help_display('glchess')
        except gobject.GError, e:
            # TODO: This should be a pop-up dialog
            print _('Unable to display help: %s') % str(e)

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
        dialog.set_transient_for(self.mainWindow)
        dialog.set_name(APPNAME)
        dialog.set_version(VERSION)
        dialog.set_copyright(COPYRIGHT)
        dialog.set_license(LICENSE[0] + '\n\n' + LICENSE[1] + '\n\n' +LICENSE[2])
        dialog.set_wrap_license(True)
        dialog.set_comments(DESCRIPTION)
        dialog.set_authors(AUTHORS)
        dialog.set_artists(ARTISTS)
        dialog.set_translator_credits(_("translator-credits"))
        dialog.set_website(WEBSITE)
        dialog.set_website_label(WEBSITE_LABEL)
        dialog.set_logo_icon_name(ICON_NAME)
        dialog.connect('response', self._on_glchess_about_dialog_close)
        dialog.show()
        
    def _on_glchess_about_dialog_close(self, widget, event):
        """Gtk+ callback"""
        self.__aboutDialog.destroy()
        self.__aboutDialog = None
        return False
        
    def _on_log_window_delete_event(self, widget, event):
        """Gtk+ callback"""
        self._gui.get_widget('menu_view_logs').set_active(False)
        
        # Stop the event - the window will be closed by the menu event
        return True
    
    def _on_resize(self, widget, event):
        """Gtk+ callback"""
        if self.isMaximised or self.isFullscreen:
            return
        self.width = event.width
        self.height = event.height

    def _on_window_state_changed(self, widget, event):
        """Gtk+ callback"""
        if event.changed_mask & gtk.gdk.WINDOW_STATE_MAXIMIZED:
            self.isMaximised = event.new_window_state & gtk.gdk.WINDOW_STATE_MAXIMIZED != 0
            glchess.config.set('maximised', self.isMaximised)
            
        if event.changed_mask & gtk.gdk.WINDOW_STATE_FULLSCREEN:
            self.isFullscreen = event.new_window_state & gtk.gdk.WINDOW_STATE_FULLSCREEN != 0
            if self.isFullscreen:
                self._gui.get_widget('menu_fullscreen').hide()
                self._gui.get_widget('menu_leave_fullscreen').show()
            else:
                self._gui.get_widget('menu_leave_fullscreen').hide()
                self._gui.get_widget('menu_fullscreen').show()

    def _on_close_window(self, widget, event):
        """Gtk+ callback"""
        self.feedback.onQuit()
        return True
        
    def _on_menu_quit(self, widget):
        """Gtk+ callback"""
        self.feedback.onQuit()

if __name__ == '__main__':
    ui = GtkUI()
    ui.run()
