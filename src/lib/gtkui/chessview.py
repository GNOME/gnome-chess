# -*- coding: utf-8 -*-
import sys
from gettext import gettext as _
import traceback
import gobject
import gtk

import gtkui
import glchess.ui
import glchess.chess
import glchess.game
import glchess.config

# Optionally use OpenGL support
openGLErrors = []
haveGLDepthSupport = True
haveGLAccumSupport = True
try:
    import OpenGL.GL
except:
    # Translators: Error message displayed when 3D mode is not available due to no Python OpenGL libraries
    openGLErrors.append(_('No Python OpenGL support'))
try:
    import gtk.gtkgl
    import gtk.gdkgl
except:
    # Translators: Error message displayed when 3D mode is not available due to no Python GTKGLExt libraries
    openGLErrors.append(_('No Python GTKGLExt support'))
else:
    display_mode = (gtk.gdkgl.MODE_RGB | gtk.gdkgl.MODE_DEPTH | gtk.gdkgl.MODE_DOUBLE | gtk.gdkgl.MODE_ACCUM)
    try:
        glConfig = gtk.gdkgl.Config(mode = display_mode)
    except gtk.gdkgl.NoMatches:
        display_mode &= ~gtk.gdkgl.MODE_DOUBLE
        display_mode &= ~gtk.gdkgl.MODE_ACCUM
        haveGLAccumSupport = False
        haveGLDepthSupport = False
        try:
            glConfig = gtk.gdkgl.Config(mode = display_mode)
        except gtk.gdkgl.NoMatches:
            # Translators: Error message displayed when 3D mode is not available due to their 3D drivers not being able to provide a suitable display mode
            openGLErrors.append(_('OpenGL libraries do not support required display mode'))
haveGLSupport = len(openGLErrors) == 0

__all__ = ['GtkView']

class GtkViewArea(gtk.DrawingArea):
    """Custom widget to render an OpenGL scene"""
    
    def __init__(self, view):
        """
        """
        gtk.DrawingArea.__init__(self)

        # Pixmaps to use for double buffering
        self.pixmap = None
        self.dynamicPixmap = None

        self.renderGL = False # Flag to show if this scene is to be rendered using OpenGL
        self.__glDrawable = None
        self.view = view

        # Allow notification of button presses
        self.add_events(gtk.gdk.BUTTON_PRESS_MASK | gtk.gdk.BUTTON_RELEASE_MASK | gtk.gdk.BUTTON_MOTION_MASK)
        
        # Make openGL drawable
        if haveGLSupport:
            gtk.gtkgl.widget_set_gl_capability(self, glConfig)# FIXME:, share_list=glContext)

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

        # Check were able to get context
        if glDrawable is None or glContext is None:
            return

        # OpenGL begin (can fail)
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
        if self.__glDrawable is None or not self.renderGL:
            return
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
        try:
            self.__startGL()
            if self.view.feedback is not None:
                self.view.feedback.reshape(event.width, event.height)
            self.__endGL()
        except:
            glchess.config.set('show_3d', False)
            raise

    def __expose(self, widget, event):
        """Gtk+ signal"""
        gc = self.style.bg_gc[self.state]
        c = gc.get_colormap().query_color(gc.foreground.pixel)
        color = (c.red_float, c.green_float, c.blue_float)

        if self.renderGL:
            try:
                self.__startGL()
                if self.__glDrawable is None:
                    return

                # Get the scene rendered
                try:
                    if self.view.feedback is not None:
                        self.view.feedback.renderGL(color)
                except OpenGL.GL.GLerror, e:
                    print 'Rendering Error: ' + str(e)
                    traceback.print_exc(file = sys.stdout)

                # Paint this
                if self.__glDrawable.is_double_buffered():
                    self.__glDrawable.swap_buffers()
                else:
                    OpenGL.GL.glFlush()

                self.__endGL()
            except:
                glchess.config.set('show_3d', False)
                raise

        else:
            context = self.pixmap.cairo_create()
            if self.view.feedback is not None:
                self.view.feedback.renderCairoStatic(context, color)
            
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
        if event.button != 1:
            return
        try:
            self.__startGL()
            if self.view.feedback is not None:
                self.view.feedback.select(event.x, event.y)
            self.__endGL()
        except:
            glchess.config.set('show_3d', False)
            raise
        
    def __button_release(self, widget, event):
        """Gtk+ signal"""
        if event.button != 1:
            return
        try:
            self.__startGL()
            if self.view.feedback is not None:
                self.view.feedback.deselect(event.x, event.y)
            self.__endGL()
        except:
            glchess.config.set('show_3d', False)
            raise

class GtkView(glchess.ui.ViewController):
    """
    """

    def __init__(self, ui, feedback, moveFormat = 'human', showComments = False):
        """Constructor for a view.
        
        'feedback' is the feedback object for this view (extends ui.ViewFeedback).
        'moveFormat' is the format name to display moves in (string).
        """
        self.ui = ui
        self.feedback = feedback
        self.moveFormat = moveFormat
        self.showComments = showComments
        self.editingComment = False
        self.hasFile = False
        self.selectedMove = -1
        self.requireAttention = False
        self.gameResult = None
        self.whiteTime = None
        self.blackTime = None
        self.title = ''
        self.needsSaving = False
        
        # The GTK+ elements
        self.widget = gtk.VBox()

        self.infobar = gtk.VBox()
        self.titleLabel = gtk.Label("")
        self.infobar.pack_start(self.titleLabel, False, True, 0)
        self.descriptionLabel = gtk.Label("")
        self.infobar.pack_start(self.descriptionLabel, True, True, 0)
        self.widget.pack_start(self.infobar, False, True, 0)

        self.viewWidget = GtkViewArea(self)
        self.widget.pack_start(self.viewWidget, True, True, 0)

        self.widget.show_all()

        # Make a model for navigation (move object, number, description) 
        model = gtk.ListStore(gobject.TYPE_PYOBJECT, int, str)
        iter = model.append()
        # Translators: Move History Combo: Go to the start of the game
        model.set(iter, 0, None, 1, 0, 2, _('Game Start'))
        self.moveModel = model

        self.updateInfoBar()

        self.widget.show()
        self.viewWidget.show_all()
        
        self.ui.updateTitle()

    def updateInfoBar(self):
        """
        """
        move = self._getCurrentMove()
        if self.gameResult is not None:
            (title, description) = self.gameResult
            self.titleLabel.set_markup('<big><b>%s</b></big>' % title)
            self.descriptionLabel.set_markup('<i>%s</i>' % description)
            self.infobar.show()
        else:
            self.infobar.hide()            

    def setShowComments(self, showComments):
        """Enable comments on this view.
        
        'showComments' is true when move comments are visible.
        """
        self.showComments = showComments
        self.updateInfoBar()

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
    
    def setTitle(self, title):
        """Extends glchess.ui.ViewController"""
        self.title = title
        if self.ui.view is self:
            self.ui.updateTitle()

    def setNeedsSaving(self, needsSaving):
        """Extends glchess.ui.ViewController"""
        if self.needsSaving == needsSaving:
            return
        self.needsSaving = needsSaving
        if self.ui.view is self:
            self.ui.updateTitle()

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
            
    def setHasFile(self, hasFile):
        """Extends glchess.ui.ViewController"""
        self.hasFile = hasFile
        self.ui._updateViewButtons()
            
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
        moveNumber = (move.number - 1) / 2 + 1
        WHITE  = glchess.chess.board.WHITE
        BLACK  = glchess.chess.board.BLACK
        colour = {0: BLACK, 1: WHITE}[move.number % 2]
        
        # Note SAN format is intentionally not translated
        if self.moveFormat == 'san':
            if move.number % 2 == 0:
                format = '%(movenum)2i. ... %(move_san)s'
            else:
                format = '%(movenum)2i. %(move_san)s'
            return format % {'movenum': moveNumber, 'move_san': glchess.chess.translate_notation(move.sanMove)}
        
        # Note FAN format is intentionally not translated
        if self.moveFormat == 'fan':
            if move.number % 2 == 0:
                format = '%(movenum)2i. ... %(move_san)s'
            else:
                format = '%(movenum)2i. %(move_san)s'
            return format % {'movenum': moveNumber, 'move_san': glchess.chess.translate_figurine_notation(colour, move.sanMove)}

        # Note LAN format is intentionally not translated
        if self.moveFormat == 'lan':
            if move.number % 2 == 0:
                format = '%(movenum)2i. ... %(move_can)s'
            else:
                format = '%(movenum)2i. %(move_can)s'
            return format % {'movenum': moveNumber, 'move_can': glchess.chess.translate_notation(move.canMove)}

        PAWN   = glchess.chess.board.PAWN
        ROOK   = glchess.chess.board.ROOK
        KNIGHT = glchess.chess.board.KNIGHT
        BISHOP = glchess.chess.board.BISHOP
        QUEEN  = glchess.chess.board.QUEEN
        KING   = glchess.chess.board.KING

        if move.sanMove.startswith('O-O-O'):
                           # Translators: Human Move String: Description of the white player making a long castle
            description = {WHITE: _('White castles long'),
                           # Translators: Human Move String: Description of the black player making a long castle
                           BLACK: _('Black castles long')}[colour]
        elif move.sanMove.startswith('O-O'):
                           # Translators: Human Move String: Description of the white player making a short castle
            description = {WHITE: _('White castles short'),
                           # Translators: Human Move String: Description of the black player making a short castle
                           BLACK: _('Black castles short')}[colour]
        else:
            # Note there are no move formats for pieces taking kings and this is not allowed in Chess rules
                            # Translators: Human Move String: Description of a white pawn moving from %(start)s to %(end)s, e.g. 'c2 to c4'
            descriptions = {(WHITE, PAWN,   None):   _('White pawn moves from %(start)s to %(end)s'),
                            (WHITE, PAWN,   PAWN):   _('White pawn at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, PAWN,   ROOK):   _('White pawn at %(start)s takes the black rook at %(end)s'),
                            (WHITE, PAWN,   KNIGHT): _('White pawn at %(start)s takes the black knight at %(end)s'),
                            (WHITE, PAWN,   BISHOP): _('White pawn at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, PAWN,   QUEEN):  _('White pawn at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a white rook moving from %(start)s to %(end)s, e.g. 'a1 to a5'
                            (WHITE, ROOK,   None):   _('White rook moves from %(start)s to %(end)s'),
                            (WHITE, ROOK,   PAWN):   _('White rook at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, ROOK,   ROOK):   _('White rook at %(start)s takes the black rook at %(end)s'),
                            (WHITE, ROOK,   KNIGHT): _('White rook at %(start)s takes the black knight at %(end)s'),
                            (WHITE, ROOK,   BISHOP): _('White rook at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, ROOK,   QUEEN):  _('White rook at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a white knight moving from %(start)s to %(end)s, e.g. 'b1 to c3'
                            (WHITE, KNIGHT, None):   _('White knight moves from %(start)s to %(end)s'),
                            (WHITE, KNIGHT, PAWN):   _('White knight at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, KNIGHT, ROOK):   _('White knight at %(start)s takes the black rook at %(end)s'),
                            (WHITE, KNIGHT, KNIGHT): _('White knight at %(start)s takes the black knight at %(end)s'),
                            (WHITE, KNIGHT, BISHOP): _('White knight at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, KNIGHT, QUEEN):  _('White knight at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a white bishop moving from %(start)s to %(end)s, e.g. 'f1 to b5'
                            (WHITE, BISHOP, None):   _('White bishop moves from %(start)s to %(end)s'),
                            (WHITE, BISHOP, PAWN):   _('White bishop at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, BISHOP, ROOK):   _('White bishop at %(start)s takes the black rook at %(end)s'),
                            (WHITE, BISHOP, KNIGHT): _('White bishop at %(start)s takes the black knight at %(end)s'),
                            (WHITE, BISHOP, BISHOP): _('White bishop at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, BISHOP, QUEEN):  _('White bishop at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a white queen moving from %(start)s to %(end)s, e.g. 'd1 to d4'
                            (WHITE, QUEEN,  None):   _('White queen moves from %(start)s to %(end)s'),
                            (WHITE, QUEEN,  PAWN):   _('White queen at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, QUEEN,  ROOK):   _('White queen at %(start)s takes the black rook at %(end)s'),
                            (WHITE, QUEEN,  KNIGHT): _('White queen at %(start)s takes the black knight at %(end)s'),
                            (WHITE, QUEEN,  BISHOP): _('White queen at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, QUEEN,  QUEEN):  _('White queen at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a white king moving from %(start)s to %(end)s, e.g. 'e1 to f1'
                            (WHITE, KING,   None):   _('White king moves from %(start)s to %(end)s'),
                            (WHITE, KING,   PAWN):   _('White king at %(start)s takes the black pawn at %(end)s'),
                            (WHITE, KING,   ROOK):   _('White king at %(start)s takes the black rook at %(end)s'),
                            (WHITE, KING,   KNIGHT): _('White king at %(start)s takes the black knight at %(end)s'),
                            (WHITE, KING,   BISHOP): _('White king at %(start)s takes the black bishop at %(end)s'),
                            (WHITE, KING,   QUEEN):  _('White king at %(start)s takes the black queen at %(end)s'),
                            # Translators: Human Move String: Description of a black pawn moving from %(start)s to %(end)s, e.g. 'c8 to c6'
                            (BLACK, PAWN,   None):   _('Black pawn moves from %(start)s to %(end)s'),
                            (BLACK, PAWN,   PAWN):   _('Black pawn at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, PAWN,   ROOK):   _('Black pawn at %(start)s takes the white rook at %(end)s'),
                            (BLACK, PAWN,   KNIGHT): _('Black pawn at %(start)s takes the white knight at %(end)s'),
                            (BLACK, PAWN,   BISHOP): _('Black pawn at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, PAWN,   QUEEN):  _('Black pawn at %(start)s takes the white queen at %(end)s'),
                            # Translators: Human Move String: Description of a black rook moving from %(start)s to %(end)s, e.g. 'a8 to a4'
                            (BLACK, ROOK,   None):   _('Black rook moves from %(start)s to %(end)s'),
                            (BLACK, ROOK,   PAWN):   _('Black rook at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, ROOK,   ROOK):   _('Black rook at %(start)s takes the white rook at %(end)s'),
                            (BLACK, ROOK,   KNIGHT): _('Black rook at %(start)s takes the white knight at %(end)s'),
                            (BLACK, ROOK,   BISHOP): _('Black rook at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, ROOK,   QUEEN):  _('Black rook at %(start)s takes the white queen at %(end)s'),
                            # Translators: Human Move String: Description of a black knight moving from %(start)s to %(end)s, e.g. 'b8 to c6'
                            (BLACK, KNIGHT, None):   _('Black knight moves from %(start)s to %(end)s'),
                            (BLACK, KNIGHT, PAWN):   _('Black knight at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, KNIGHT, ROOK):   _('Black knight at %(start)s takes the white rook at %(end)s'),
                            (BLACK, KNIGHT, KNIGHT): _('Black knight at %(start)s takes the white knight at %(end)s'),
                            (BLACK, KNIGHT, BISHOP): _('Black knight at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, KNIGHT, QUEEN):  _('Black knight at %(start)s takes the white queen at %(end)s'),
                            # Translators: Human Move String: Description of a black bishop moving from %(start)s to %(end)s, e.g. 'f8 to b3'
                            (BLACK, BISHOP, None):   _('Black bishop moves from %(start)s to %(end)s'),
                            (BLACK, BISHOP, PAWN):   _('Black bishop at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, BISHOP, ROOK):   _('Black bishop at %(start)s takes the white rook at %(end)s'),
                            (BLACK, BISHOP, KNIGHT): _('Black bishop at %(start)s takes the white knight at %(end)s'),
                            (BLACK, BISHOP, BISHOP): _('Black bishop at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, BISHOP, QUEEN):  _('Black bishop at %(start)s takes the white queen at %(end)s'),
                            # Translators: Human Move String: Description of a black queen moving from %(start)s to %(end)s, e.g. 'd8 to d5'
                            (BLACK, QUEEN,  None):   _('Black queen moves from %(start)s to %(end)s'),
                            (BLACK, QUEEN,  PAWN):   _('Black queen at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, QUEEN,  ROOK):   _('Black queen at %(start)s takes the white rook at %(end)s'),
                            (BLACK, QUEEN,  KNIGHT): _('Black queen at %(start)s takes the white knight at %(end)s'),
                            (BLACK, QUEEN,  BISHOP): _('Black queen at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, QUEEN,  QUEEN):  _('Black queen at %(start)s takes the white queen at %(end)s'),
                            # Translators: Human Move String: Description of a black king moving from %(start)s to %(end)s, e.g. 'e8 to f8'
                            (BLACK, KING,   None):   _('Black king moves from %(start)s to %(end)s'),
                            (BLACK, KING,   PAWN):   _('Black king at %(start)s takes the white pawn at %(end)s'),
                            (BLACK, KING,   ROOK):   _('Black king at %(start)s takes the white rook at %(end)s'),
                            (BLACK, KING,   KNIGHT): _('Black king at %(start)s takes the white knight at %(end)s'),
                            (BLACK, KING,   BISHOP): _('Black king at %(start)s takes the white bishop at %(end)s'),
                            (BLACK, KING,   QUEEN):  _('Black king at %(start)s takes the white queen at %(end)s')}

            pieceType = move.piece.getType()                            
            if move.victim is not None:
                victimType = move.victim.getType()
            else:
                victimType = None
            start = glchess.chess.translate_coordinate(move.start)
            end = glchess.chess.translate_coordinate(move.end)            

            description = descriptions[colour, pieceType, victimType] % {'start': start, 'end': end}

        CHECK     = 'CHECK'
        CHECKMATE = 'CHECKMATE'
        STALEMATE = 'STALEMATE'
        status = None
        if move.opponentInCheck:
            if move.opponentCanMove:
                status = CHECK
            else:
                status = CHECKMATE
        elif not move.opponentCanMove:
            status = STALEMATE

                        # Translators: Human Move String: White player has made move %(description) and the opponent is in check
        formatString = {(WHITE, CHECK):      _('%(movenum)2iw. %(description)s (Check)'),
                        # Translators: Human Move String: White player has made move %(description) and the opponent is in checkmate
                        (WHITE, CHECKMATE):  _('%(movenum)2iw. %(description)s (Checkmate)'),        
                        # Translators: Human Move String: White player has made move %(description) and the opponent is in stalemate
                        (WHITE, STALEMATE):  _('%(movenum)2iw. %(description)s (Stalemate)'),
                        # Translators: Human Move String: White player has made move %(description) and the opponent is not in check or mate        
                        (WHITE, None):       _('%(movenum)2iw. %(description)s'),
                        # Translators: Human Move String: Black player has made move %(description) and the opponent is in check
                        (BLACK, CHECK):      _('%(movenum)2ib. %(description)s (Check)'),
                        # Translators: Human Move String: Black player has made move %(description) and the opponent is in checkmate
                        (BLACK, CHECKMATE):  _('%(movenum)2ib. %(description)s (Checkmate)'),
                        # Translators: Human Move String: Black player has made move %(description) and the opponent is in stalemate
                        (BLACK, STALEMATE):  _('%(movenum)2ib. %(description)s (Stalemate)'),
                        # Translators: Human Move String: Black player has made move %(description) and the opponent is not in check or mate
                        (BLACK, None):       _('%(movenum)2ib. %(description)s')}[colour, status]

        # FIXME: Promotion

        return formatString % {'movenum': moveNumber, 'description': description}

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

    def undoMove(self):
        """Extends glchess.ui.ViewController"""
        iter = self.moveModel.iter_nth_child(None, len(self.moveModel) - 1)
        self.moveModel.remove(iter)
        self.selectedMove = -1
        self.ui._updateViewButtons()        

    def endGame(self, game):
        # Translators: Message displayed when a player wins. The %s is substituted with the winning player's name
        format = _('%s wins')
        
        # If game completed show this in the GUI
        if game.result is glchess.game.RESULT_WHITE_WINS:
            title = format % game.getWhite().getName()
        elif game.result is glchess.game.RESULT_BLACK_WINS:
            title = format % game.getBlack().getName()
        else:
            # Translators: Message displayed when a game is drawn
            title = _('Game is drawn')

        description = ''
        if game.rule is glchess.game.RULE_CHECKMATE:
            # Translators: Message displayed when the game ends due to a player being checkmated
            description = _('Opponent is in check and cannot move (checkmate)')
        elif game.rule is glchess.game.RULE_STALEMATE:
            # Translators: Message displayed when the game terminates due to a stalemate
            description = _('Opponent cannot move (stalemate)')
        elif game.rule is glchess.game.RULE_FIFTY_MOVES:
            # Translators: Message displayed when the game is drawn due to the fifty move rule
            description = _('No piece has been taken or pawn moved in the last fifty moves')
        elif game.rule is glchess.game.RULE_TIMEOUT:
            # Translators: Message displayed when the game ends due to one player's clock stopping
            description = _('Opponent has run out of time')
        elif game.rule is glchess.game.RULE_THREE_FOLD_REPETITION:
            # Translators: Message displayed when the game is drawn due to the three-fold-repitition rule
            description = _('The same board state has occurred three times (three fold repetition)')
        elif game.rule is glchess.game.RULE_INSUFFICIENT_MATERIAL:
            # Translators: Message displayed when the game is drawn due to the insufficient material rule
            description = _('Neither player can cause checkmate (insufficient material)')
        elif game.rule is glchess.game.RULE_RESIGN:
            if game.result is glchess.game.RESULT_WHITE_WINS:
                # Translators: Message displayed when the game ends due to the black player resigning
                description = _('The black player has resigned')
            elif game.result is glchess.game.RESULT_BLACK_WINS:
                # Translators: Message displayed when the game ends due to the white player resigning
                description = _('The white player has resigned')
            else:
                assert(False)
        elif game.rule is glchess.game.RULE_ABANDONMENT:
            # Translators: Message displayed when a game is abandoned
            description = _('The game has been abandoned')                
        elif game.rule is glchess.game.RULE_DEATH:
            # Translators: Message displayed when the game ends due to a player dying
            description = _('One of the players has died')

        self.gameResult = (title, description)
        self.updateInfoBar()
        self.ui._updateViewButtons()
    
    def close(self):
        """Extends glchess.ui.ViewController"""
        if self.requireAttention:
            self.ui._incAttentionCounter(-1)
        self.ui._removeView(self)
    
    # Public methods
    
    def _getCurrentMove(self):
        if self.selectedMove == -1:
            iter = self.moveModel.get_iter_from_string(str(len(self.moveModel) - 1))
        else:
            iter = self.moveModel.get_iter_from_string(str(self.selectedMove))
        return self.moveModel.get_value(iter, 0)

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
        self.updateInfoBar()
