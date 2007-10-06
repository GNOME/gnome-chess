import sys
from gettext import gettext as _
import traceback
import gobject
import gtk

import gtkui
import glchess.ui
import glchess.chess
import glchess.game

# Optionally use OpenGL support
try:
    import gtk.gtkgl
    import OpenGL.GL
except:
    haveGLSupport = False
else:
    haveGLSupport = True

__all__ = ['GtkView']

pieceNames = {glchess.chess.board.PAWN:   _('pawn'),
              glchess.chess.board.ROOK:   _('rook'),
              glchess.chess.board.KNIGHT: _('knight'),
              glchess.chess.board.BISHOP: _('bishop'),
              glchess.chess.board.QUEEN:  _('queen'),
              glchess.chess.board.KING:   _('king')}

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
            gtk.gtkgl.widget_set_gl_capability(self, self.view.ui.glConfig)# FIXME:, share_list=glContext)

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
            vendor     = OpenGL.GL.glGetString(OpenGL.GL.GL_VENDOR)
            renderer   = OpenGL.GL.glGetString(OpenGL.GL.GL_RENDERER)
            version    = OpenGL.GL.glGetString(OpenGL.GL.GL_VERSION)
            extensions = OpenGL.GL.glGetString(OpenGL.GL.GL_EXTENSIONS)
            print 'Using OpenGL:'
            print 'VENDOR=%s' % vendor
            print 'RENDERER=%s' % renderer
            print 'VERSION=%s' % version
            print 'EXTENSIONS=%s' % extensions
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
    
    showComments     = False
    editingComment   = False
    
    gameResult       = None
    
    # Flag to show if requesting attention
    requireAttention = False

    # The format to report moves in
    moveFormat       = 'human'

    whiteTime        = None
    blackTime        = None
    
    def __init__(self, ui, title, feedback, isActive = True, moveFormat = 'human', showComments = False):
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
        self.showComments = showComments
        
        # The GTK+ elements
        self.gui = gtkui.loadGladeFile('chess_view.glade', 'chess_view')
        self.gui.signal_autoconnect(self)
        self.widget = self.gui.get_widget('chess_view')
        self.viewWidget = GtkViewArea(self)
        self.gui.get_widget('view_container').add(self.viewWidget)

        self.ui.setTooltipStyle(self.gui.get_widget('info_panel'))

        # Make a model for navigation (move object, number, description) 
        model = gtk.ListStore(gobject.TYPE_PYOBJECT, int, str)
        iter = model.append()
        model.set(iter, 0, None, 1, 0, 2, _('Game Start'))
        self.moveModel = model
        
        # Tabs are enabled to make editing the UI easier
        self.gui.get_widget('comment_notebook').set_show_tabs(False)
        
        self.updateInfoPanel()

        self.widget.show()
        self.viewWidget.show_all()
        
    def _on_comment_edit_button_toggled(self, widget):
        """Gtk+ callback"""
        label = self.gui.get_widget('panel_description_label')
        entry = self.gui.get_widget('comment_text')
        buffer = entry.get_buffer()
        
        move = self._getCurrentMove()
        
        # FIXME
        if move is None:
            return
        
        self.editingComment = widget.get_active()
        if self.editingComment:
            buffer.set_text(move.comment)
            entry.grab_focus()
            page = 1
        else:
            comment = buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter())
            
            # FIXME: This should be notified so the game is considered modified for saving purposes
            # self.feedback.setComment(move, comment)

            move.comment = comment
            label.set_text(comment)
            buffer.set_text('')
            page = 0
        self.gui.get_widget('comment_notebook').set_current_page(page)

    def _getCurrentMove(self):
        if self.selectedMove == -1:
            iter = self.moveModel.get_iter_from_string(str(len(self.moveModel) - 1))
        else:
            iter = self.moveModel.get_iter_from_string(str(self.selectedMove))
        return self.moveModel.get_value(iter, 0)

    def updateInfoPanel(self):
        """
        """
        showPanel = False
        
        panel = self.gui.get_widget('info_panel')
        titleLabel = self.gui.get_widget('panel_title_label')
        descriptionLabel = self.gui.get_widget('panel_description_label')
        
        move = self._getCurrentMove()
        if self.gameResult is not None:
            (title, description) = self.gameResult
            titleLabel.set_markup('<big><b>%s</b></big>' % title)
            descriptionLabel.set_markup('<i>%s</i>' % description)
            showPanel = True

        editToggle = self.gui.get_widget('comment_edit_toggle')
        if self.showComments:
            # Show the comments
            if move is None:
                titleLabel.set_markup('<big><b>%s</b></big>' % _('Game start'))
            else:
                titleLabel.set_markup('<big><b>%s</b></big>' % self.generateMoveString(move))
            
            comment = _('No comment')
            if move is not None and len(move.comment) > 0:
                comment = move.comment

            descriptionLabel.set_markup('<i>%s</i>' % comment)
            editToggle.show()
            showPanel = True
        else:
            editToggle.hide()

        if showPanel:
            panel.show()
        else:
            panel.hide()

    def setShowComments(self, showComments):
        """Enable comments on this view.
        
        'showComments' is true when move comments are visible.
        """
        self.showComments = showComments
        self.updateInfoPanel()

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
        
    def setWhiteTime(self, total, current):
        """Extends glchess.ui.ViewController"""
        self.whiteTime = (total, current)
        if self.ui.view is self:
            self.ui.setTimers(self.whiteTime, self.blackTime)

    def setBlackTime(self, total, current):
        """Extends glchess.ui.ViewController"""
        self.blackTime = (total, current)
        if self.ui.view is self:
            self.ui.setTimers(self.whiteTime, self.blackTime)

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
        subs = {'movenum': (move.number - 1) / 2 + 1,
                'move_can': move.canMove, 'move_san': move.sanMove,
                'piece': pieceNames[move.piece.getType()],
                'start': move.start, 'end': move.end}
        if move.victim is not None:
            subs['victim_piece'] = pieceNames[move.victim.getType()]
        subs['colour'] = _('White')
        subs['victim_colour'] = _('Black')
        if move.number % 2 == 1:
            subs['short_colour'] = 'a'
        else:
            subs['short_colour'] = 'b'
            t = subs['colour']
            subs['colour'] = subs['victim_colour']
            subs['victim_colour'] = t
        
        if self.moveFormat == 'san':
            if move.number % 2 == 0:
                return '%(movenum)2i. ... %(move_san)s' % subs
            else:
                return '%(movenum)2i. %(move_san)s' % subs

        if self.moveFormat == 'lan':
            string = '%(movenum)2i. ' % subs
            if move.number % 2 == 0:
                return '%(movenum)2i. ... %(move_can)s' % subs
            else:
                return '%(movenum)2i. %(move_can)s' % subs
            
        status = None
        if move.opponentInCheck:
            if move.opponentCanMove:
                status = _('Check')
            else:
                status = _('Checkmate')
        elif not move.opponentCanMove:
            status = _('Stalemate')
        if status is not None:
            subs['suffix'] = _(' - %(check_status)s') % {'check_status': status}
        else:
            subs['suffix'] = ''

        if move.sanMove.startswith('O-O-O'):
            string = _('%(movenum)2i%(short_colour)s. %(colour)s castles long%(suffix)s') % subs
        elif move.sanMove.startswith('O-O'):
            string = _('%(movenum)2i%(short_colour)s. %(colour)s castles short%(suffix)s') % subs
        elif move.victim is not None:
            string = _('%(movenum)2i%(short_colour)s. %(colour)s %(piece)s at %(start)s takes %(victim_colour)s %(victim_piece)s at %(end)s%(suffix)s') % subs
        else:
            string = _('%(movenum)2i%(short_colour)s. %(colour)s %(piece)s moves from %(start)s to %(end)s%(suffix)s') % subs

        # FIXME: Promotion

        return string

    def addMove(self, move):
        """Extends glchess.ui.ViewController"""        
        # FIXME: Make a '@ui' player who watches for these itself?
        iter = self.moveModel.append()
        string = self.generateMoveString(move)
        self.moveModel.set(iter, 0, move, 1, move.number, 2, string)

        # If is the current view and tracking the game select this
        if self.selectedMove == -1:
            # If editing comments don't stay on current move
            if self.editingComment:
                self._setMoveNumber(move.number - 1)
                return
            
            self.ui._updateViewButtons()

    def endGame(self, game):
        # If game completed show this in the GUI
        if game.result is glchess.game.RESULT_WHITE_WINS:
            title = _('%s wins') % game.getWhite().getName()
        elif game.result is glchess.game.RESULT_BLACK_WINS:
            title = _('%s wins') % game.getBlack().getName()
        else:
            title = _('Game is drawn')

        description = ''
        if game.rule is glchess.game.RULE_CHECKMATE:
            description = _('Opponent is in check and cannot move (checkmate)')
        elif game.rule is glchess.game.RULE_STALEMATE:
            description = _('Opponent cannot move (stalemate)')
        elif game.rule is glchess.game.RULE_FIFTY_MOVES:
            description = _('No piece has been taken or pawn moved in the last fifty moves')
        elif game.rule is glchess.game.RULE_TIMEOUT:
            description = _('Opponent has run out of time')
        elif game.rule is glchess.game.RULE_THREE_FOLD_REPETITION:
            description = _('The same board state has occured three times (three fold repetition)')
        elif game.rule is glchess.game.RULE_INSUFFICIENT_MATERIAL:
            if game.result is glchess.game.RESULT_DRAW:
                description = _('Neither player can cause checkmate (insufficient material)')
            else:
                description = _('Opponent is unable to cause checkmate (insufficient material)')
        elif game.rule is glchess.game.RULE_RESIGN:
            description = _('One of the players has resigned')
        elif game.rule is glchess.game.RULE_DEATH:
            description = _('One of the players has died')

        self.gameResult = (title, description)
        self.updateInfoPanel()
    
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
        self.updateInfoPanel()
