import sys
import gettext
import traceback
import gobject
import gtk

import gtkui
import glchess.ui
import glchess.chess
import glchess.game

# Optionally use OpenGL support
# gtk.gtkgl throws RuntimeError when there is no OpenGL support
# It should really just throw ImportError
try:
    import gtk.gtkgl
    import OpenGL.GL
except (ImportError, RuntimeError):
    haveGLSupport = False
else:
    haveGLSupport = True

__all__ = ['GtkView']

pieceNames = {glchess.chess.board.PAWN:   gettext.gettext('pawn'),
              glchess.chess.board.ROOK:   gettext.gettext('rook'),
              glchess.chess.board.KNIGHT: gettext.gettext('knight'),
              glchess.chess.board.BISHOP: gettext.gettext('bishop'),
              glchess.chess.board.QUEEN:  gettext.gettext('queen'),
              glchess.chess.board.KING:   gettext.gettext('king')}

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
        # If the window is visible prepare it for redrawing
        area = gtk.gdk.Rectangle(0, 0, self.allocation.width, self.allocation.height)
        if self.window is not None:
            self.window.invalidate_rect(area, False)

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
            except OpenGL.GL.GLerror, e:
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
    ui               = None
    
    # The title of this view
    title            = None
    
    # The widget to render the scene to
    widget           = None
    
    # A Gtk+ tree model to store the move history
    moveModel        = None
    selectedMove     = -1
    
    # Flag to show if requesting attention
    requireAttention = False

    # The format to report moves in
    moveFormat     = 'human'
    
    def __init__(self, ui, title, feedback, isActive = True, moveFormat = 'human'):
        """Constructor for a view.
        
        'feedback' is the feedback object for this view (extends ui.ViewFeedback).
        'isActive' is a flag showing if this view can be controlled by the user (True) or not (False).
        'moveFormat' is the format name to display moves in (string).
        """
        self.ui = ui
        self.title = title
        self.feedback = feedback
        self.isActive = isActive
        self.moveFormat = moveFormat
        
        # The GTK+ elements
        self.gui = gtkui.loadGladeFile('chess_view.glade', 'chess_view')
        self.gui.signal_autoconnect(self)
        self.widget = self.gui.get_widget('chess_view')
        self.viewWidget = GtkViewArea(self)
        self.gui.get_widget('view_container').add(self.viewWidget)
        
        # Set the message panel to the tooltip style
        # (copied from Gedit)
        tooltip = gtk.Tooltips()
        tooltip.force_window()
        tooltip.tip_window.ensure_style()
        self.gui.get_widget('info_panel').set_style(tooltip.tip_window.get_style())
        
        # Make a model for navigation
        model = gtk.ListStore(gobject.TYPE_PYOBJECT, int, str)
        iter = model.append()
        model.set(iter, 0, None, 1, 0, 2, gettext.gettext('Game Start'))
        self.moveModel = model

        self.viewWidget.show_all()
        
    def _on_info_panel_expose_event(self, widget, event):
        """Gtk+ callback"""
        allocation = widget.allocation
        widget.style.paint_flat_box(widget.window, gtk.STATE_NORMAL, gtk.SHADOW_OUT, None, widget, "tooltip",
                                    allocation.x, allocation.y, allocation.width, allocation.height)

    def setMoveFormat(self, format):
        """Set the format to display the moves in.
        
        'format' is the format name to use (e.g. 'human', 'san'. Defaults to 'human')
        """
        self.moveFormat = format
        
        # Update the move list
        iter = self.moveModel.get_iter_first()
        while iter is not None:
            move = self.moveModel.get_value(iter, 0)
            if move is not None:
                string = self.generateMoveString(move)
                self.moveModel.set(iter, 2, string)
            iter = self.moveModel.iter_next(iter)
    
    # Extended methods
    
    def render(self):
        """Extends glchess.ui.ViewController"""
        self.viewWidget.redraw()

    def setAttention(self, requiresAttention):
        """Extends glchess.ui.ViewController"""
        if self.requireAttention == requiresAttention:
            return
        self.requireAttention = requiresAttention
        if requiresAttention:
            self.ui._incAttentionCounter(1)
        else:
            self.ui._incAttentionCounter(-1)
    
    def generateMoveString(self, move):
        """
        """
        if self.moveFormat == 'san':
            string = '%2i. ' % ((move.number - 1) / 2 + 1)
            if move.number % 2 == 0:
                string += '... '
            string += move.sanMove
            return string
        
        if self.moveFormat == 'lan':
            string = '%2i. ' % ((move.number - 1) / 2 + 1)
            if move.number % 2 == 0:
                string += '... '
            string += move.canMove
            return string
        
        colour = gettext.gettext('White')
        victimColour = gettext.gettext('Black')
        if move.number % 2 == 1:
            shortColour = 'a'
        else:
            shortColour = 'b'
            t = colour
            colour = victimColour
            victimColour = t
        string = '%2i%s.' % ((move.number - 1) / 2 + 1, shortColour)

        if move.sanMove.startswith('O-O-O'):
            string += ' %s castles long' % colour
        elif move.sanMove.startswith('O-O'):
            string += ' %s castles short' % colour
        elif move.victim is not None:
            string += ' %s %s at %s takes %s %s at %s' % \
                      (colour, pieceNames[move.piece.getType()],
                       move.start, victimColour, pieceNames[move.victim.getType()], move.end)
        else:
            string += ' %s %s moves from %s to %s' % (colour, pieceNames[move.piece.getType()], move.start, move.end)

        # FIXME: Promotion

        if move.opponentInCheck:
            if move.opponentCanMove:
                string += ' - ' + gettext.gettext('Check')
            else:
                string += ' - ' + gettext.gettext('Checkmate')
        elif not move.opponentCanMove:
            string += ' - ' + gettext.gettext('Stalemate')

        return string

    def addMove(self, move):
        """Extends glchess.ui.ViewController"""
        # FIXME: Make a '@ui' player who watches for these itself?
        iter = self.moveModel.append()
        string = self.generateMoveString(move)
        self.moveModel.set(iter, 0, move, 1, move.number, 2, string)
        
        # If is the current view and tracking the game select this
        if self.selectedMove == -1:
            self.ui._updateViewButtons()
        
    def endGame(self, game):
        # If game completed show this in the GUI
        if game.result is glchess.game.RESULT_WHITE_WINS:
            title = gettext.gettext('%s wins') % game.getWhite().getName()
        elif game.result is glchess.game.RESULT_BLACK_WINS:
            title = gettext.gettext('%s wins') % game.getBlack().getName()
        else:
            title = gettext.gettext('Game is drawn')

        description = ''
        if game.rule is glchess.game.RULE_CHECKMATE:
            description = gettext.gettext('Opponent is in check and cannot move (checkmate)')
        elif game.rule is glchess.game.RULE_STALEMATE:
            description = gettext.gettext('Opponent cannot move (stalemate)')
        elif game.rule is glchess.game.RULE_FIFTY_MOVES:
            description = gettext.gettext('No piece has been taken or pawn moved in the last fifty moves')
        elif game.rule is glchess.game.RULE_TIMEOUT:
            description = gettext.gettext('Opponent has run out of time')
        elif game.rule is glchess.game.RULE_THREE_FOLD_REPETITION:
            description = gettext.gettext('The same board state has occured three times (three fold repetition)')
        elif game.rule is glchess.game.RULE_INSUFFICIENT_MATERIAL:
            if game.result is glchess.game.RESULT_DRAW:
                description = gettext.gettext('Neither player can cause checkmate (insufficient material)')
            else:
                description = gettext.gettext('Opponent is unable to cause checkmate (insufficient material)')
        elif game.rule is glchess.game.RULE_RESIGN:
            description = gettext.gettext('One of the players has resigned')

        self.gui.get_widget('panel_title_label').set_markup('<big><b>%s</b></big>' % title)
        self.gui.get_widget('panel_description_label').set_markup('<i>%s</i>' % description)
        self.gui.get_widget('info_panel').show()
    
    def close(self):
        """Extends glchess.ui.ViewController"""
        if self.requireAttention:
            self.ui._incAttentionCounter(-1)
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
