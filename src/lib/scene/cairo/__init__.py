# -*- coding: utf-8 -*-
import os.path

import math
import cairo
import rsvg
import gobject
import gtk.gdk

import glchess.scene

from gettext import gettext as _

def parse_colour(colour):
    assert colour.startswith('#')
    assert len(colour) == 7
    r = int(colour[1:3], 16) / 255.
    g = int(colour[3:5], 16) / 255.
    b = int(colour[5:7], 16) / 255.
    return (r, g, b)

def blend_colour(colour_a, colour_b, alpha):
    a = parse_colour(colour_a)
    b = parse_colour(colour_b)
    r = a[0] * alpha + b[0] * (1 - alpha)
    g = a[1] * alpha + b[1] * (1 - alpha)
    b = a[2] * alpha + b[2] * (1 - alpha)
    return (r, g, b)

BORDER_COLOUR        = parse_colour('#2e3436')
NUMBERING_COLOUR     = parse_colour('#888a85')
BLACK_SQUARE_COLOURS = {None:                               parse_colour('#babdb6'),
                        glchess.scene.HIGHLIGHT_SELECTED:   parse_colour('#73d216'),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   parse_colour('#3465a4'),
                        glchess.scene.HIGHLIGHT_THREATENED: blend_colour('#af0000', '#babdb6', 0.2),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   blend_colour('#af0000', '#babdb6', 0.8)}
WHITE_SQUARE_COLOURS = {None:                               parse_colour('#eeeeec'),
                        glchess.scene.HIGHLIGHT_SELECTED:   parse_colour('#8ae234'),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   parse_colour('#204a87'),
                        glchess.scene.HIGHLIGHT_THREATENED: blend_colour('#cc0000', '#eeeeec', 0.2),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   blend_colour('#cc0000', '#eeeeec', 0.8)}
PIECE_COLOUR         = parse_colour('#000000')

class ChessPiece(glchess.scene.ChessPiece):
    """
    """

    def __init__(self, scene, name, coord, feedback, style='simple'):
        """
        """
        self.scene = scene
        self.feedback = feedback
        self.name = name
        self.coord = coord # Co-ordinate being moved to
        self.pos = self.__coordToLocation(coord) # Current position
        self.targetPos   = None
        self.moving = False
        self.delete = False # Delete once moved to location

        self.setStyle(style)
        
    def __coordToLocation(self, coord):
        """
        """
        rank = ord(coord[0]) - ord('a')
        file = ord(coord[1]) - ord('1')
        
        return (float(rank), float(file))

    def setStyle(self, style):
        self.style = style
        self.path = os.path.join(glchess.defaults.BASE_DIR, 'pieces', style, self.name + '.svg')
        try:
            self.svg = rsvg.Handle(file = self.path)
        except Exception as e:
            raise Exception('Error reading %s: %s' % (self.path, e))

    def move(self, coord, delete, animate = True):
        """Extends glchess.scene.ChessPiece"""
        if not coord:
            self.scene.pieces.remove(self)
            self.feedback.onDeleted()
            return
        
        self.coord = coord
        self.delete = delete
        self.targetPos = self.__coordToLocation(coord)

        redraw = (self.pos != self.targetPos) or delete

        # If not animating this move immediately
        if not animate:
            self.pos = self.targetPos
        
        # If already there then check for deletion
        if self.pos == self.targetPos:
            self.targetPos = None
            if delete:
                self.scene.pieces.remove(self)
                self.feedback.onDeleted()
            if redraw:
                self.scene.redrawStatic = True
                self.scene.feedback.onRedraw()
            return

        # If not currently moving then start
        if not self.moving:
            self.scene._animationQueue.append(self)
            self.moving = True

            # Remove piece from static scene
            self.scene.redrawStatic = True            
            
            # Start animation
            if self.scene.animating is False:
                self.scene.animating = True
                self.scene.feedback.startAnimation()

    def animate(self, timeStep):
        """
        
        Return True if the piece has moved otherwise False.
        """
        if self.targetPos is None:
            return False
        
        if self.pos == self.targetPos:
            self.targetPos = None
            if self.delete:
                self.scene.pieces.remove(self)
                self.feedback.onDeleted()
            return False
        
        # Get distance to target
        dx = self.targetPos[0] - self.pos[0]
        dy = self.targetPos[1] - self.pos[1]
        
        # Get movement step in each direction
        SPEED = 4.0 # FIXME
        xStep = timeStep * SPEED
        if xStep > abs(dx):
            xStep = dx
        else:
            xStep *= cmp(dx, 0.0)
        yStep = timeStep * SPEED
        if yStep > abs(dy):
            yStep = dy
        else:
            yStep *= cmp(dy, 0.0)

        # Move the piece
        self.pos = (self.pos[0] + xStep, self.pos[1] + yStep)
        return True
    
    def render(self, context):
        """
        """
        offset = self.scene.PIECE_BORDER
        matrix = context.get_matrix()
        x = (self.pos[0] - 4) * self.scene.squareSize
        y = (3 - self.pos[1]) * self.scene.squareSize

        context.translate(x, y)
        context.translate(self.scene.squareSize / 2, self.scene.squareSize / 2)
        context.rotate(-self.scene.angle)

        # If Face to Face mode is enabled, we rotate the black player's pieces by 180 degrees
        if self.scene.faceToFace and self.name.find('black') != -1:
            context.rotate(math.pi)
            offset = - offset - self.scene.pieceSize + self.scene.squareSize
        
        context.translate(-self.scene.squareSize / 2 + offset, -self.scene.squareSize / 2 + offset)
        context.scale(self.scene.pieceSize/self.svg.props.width, self.scene.pieceSize/self.svg.props.height)

        self.svg.render_cairo(context)
        context.set_matrix(matrix)

class Scene(glchess.scene.Scene):
    """
    """    
    BORDER = 6.0
    PIECE_BORDER = 0.0

    def __init__(self, feedback):
        """Constructor for a Cairo scene"""
        self.feedback        = feedback
        self.highlight       = {}
        self.pieces          = []
        self._animationQueue = []
        self.angle           = 0.0
        self.targetAngle     = 0.0
        self.animating       = False
        self.redrawStatic    = True
        self.showNumbering   = False
        self.faceToFace      = False
        try:
            pixbuf = gtk.gdk.pixbuf_new_from_file(os.path.join(glchess.defaults.SHARED_IMAGE_DIR, 'baize.png'))
            (self.background_pixmap, _) = pixbuf.render_pixmap_and_mask()
        except gobject.GError:
            self.background_pixmap = None

    def addChessPiece(self, chessSet, name, coord, feedback, style = 'simple'):
        """Add a chess piece model into the scene.
        
        'chessSet' is the name of the chess set (string).
        'name' is the name of the piece (string).
        'coord' is the the chess board location of the piece in LAN format (string).
        
        Returns a reference to this chess piece or raises an exception.
        """
        name = chessSet + name[0].upper() + name[1:]
        piece = ChessPiece(self, name, coord, feedback, style=style)
        self.pieces.append(piece)
        
        # Redraw the scene
        self.redrawStatic = True
        self.feedback.onRedraw()
        
        return piece

    def setBoardHighlight(self, coords):
        """Highlight a square on the board.
        
        'coords' is a dictionary of highlight types keyed by square co-ordinates.
                 The co-ordinates are a tuple in the form (file,rank).
                 If None the highlight will be cleared.
        """
        self.redrawStatic = True
        if coords is None:
            self.highlight = {}
        else:
            self.highlight = coords.copy()
        self.feedback.onRedraw()

    def showBoardNumbering(self, showNumbering):
        """Extends glchess.scene.Scene"""
        self.showNumbering = showNumbering
        self.redrawStatic = True
        self.feedback.onRedraw()

    def reshape(self, width, height):
        """Resize the viewport into the scene.
        
        'width' is the width of the viewport in pixels.
        'height' is the width of the viewport in pixels.
        """
        self.width = width
        self.height = height
        
        # Make the squares as large as possible while still pixel aligned
        shortEdge = min(self.width, self.height)
        self.squareSize = math.floor((shortEdge - 2.0*self.BORDER) / 9.0)
        self.pieceSize = self.squareSize - 2.0*self.PIECE_BORDER

        self.redrawStatic = True
        self.feedback.onRedraw()

    def setBoardRotation(self, angle, faceToFace = False, animate = True):
        """Extends glchess.scene.Scene"""
        # Convert from degrees to radians
        a = angle * math.pi / 180.0
        
        redraw = False

        if self.faceToFace != faceToFace:
            redraw = True
            self.faceToFace = faceToFace
        
        if self.angle == a:
            animate = False
        else:
            self.targetAngle = a
            if not animate:
                self.angle = a
                redraw = True

        # Start animation or redraw now
        if animate and self.animating is False:
            self.animating = True
            self.feedback.startAnimation()
        elif redraw:
            self.redrawStatic = True
            self.feedback.onRedraw()

    def setPiecesStyle(self, piecesStyle):
        for piece in self.pieces:
            piece.setStyle(piecesStyle)
        self.redrawStatic = True
        self.feedback.onRedraw()
    
    def animate(self, timeStep):
        """Extends glchess.scene.Scene"""
        if self.angle == self.targetAngle and len(self._animationQueue) == 0:
            return False

        redraw = False
        
        if self.angle != self.targetAngle:
            offset = self.targetAngle - self.angle
            if offset < 0:
                offset += 2 * math.pi
            step = timeStep * math.pi * 0.7
            if step > offset:
                self.angle = self.targetAngle
            else:
                self.angle += step
                if self.angle > 2 * math.pi:
                    self.angle -= 2 * math.pi
            self.redrawStatic = True
            redraw = True
        
        animationQueue = []
        for piece in self._animationQueue:
            if piece.animate(timeStep):
                piece.moving = True
                redraw = True
                assert(animationQueue.count(piece) == 0)
                animationQueue.append(piece)
            else:
                # Redraw static scene once pieces stop
                if piece.moving:
                    redraw = True
                    self.redrawStatic = True
                piece.moving = False

                # Notify higher classes
                piece.feedback.onMoved()

        self._animationQueue = animationQueue
        self.animating = len(self._animationQueue) > 0 or self.angle != self.targetAngle

        if redraw:
            self.feedback.onRedraw()

        return self.animating
    
    def __rotate(self, context):
        """
        """
        context.translate(self.width / 2, self.height / 2)
        
        # Shrink board so it is always visible:
        #
        # a  b
        # +-----------------+
        # |  |    ```----__ |
        # |  |             ||
        # | ,`            ,`|
        # | |      o      | |
        # |,`      c      | |
        # ||___          ,` |
        # |    ----...   |  |
        # +-----------------+
        #
        # To calculate the scaling factor compare lengths a-c and b-c
        #
        # Rotation angle (r) is angle between a-c and b-c.
        #
        # Make two triangles:
        #
        #   +------+-------+
        #    `.     \      |        r = angle rotated
        #      `.    \     |       r' = 45deg - r
        #        `.  y\    | z    z/x = cos(45) = 1/sqrt(2)
        #       x  `.  \   |      z/y = cos(r') = cos(45 - r)
        #            `.r\r'|
        #              `.\ |  s = y/x = 1 / (sqrt(2) * cos(45 - r)
        #                `\|
        #                              QED
        #
        # Finally clip the angles so the board does not expand
        # in the middle of the rotation.
        a = self.angle
        if a > math.pi:
            a -= math.pi
        if a > math.pi / 4:
            if a > math.pi * 3 / 4:
                a = math.pi / 4 - (a - (math.pi * 3 / 4))
            else:
                a = math.pi / 4
        s = 1.0 / (math.sqrt(2) * math.cos(math.pi / 4 - a))
        
        context.scale(s, s)
        
        context.rotate(self.angle);

    def renderStatic(self, context, background_color):
        """Render the static elements in a scene.
        """
        if self.redrawStatic is False:
            return False
        self.redrawStatic = False

        context.set_source_rgb(*background_color)
        context.paint()
        
        # Rotate board
        self.__rotate(context)
        
        # Draw border
        context.set_source_rgb(*BORDER_COLOUR)
        borderSize = math.ceil(self.squareSize * 4.5)
        context.rectangle(-borderSize, -borderSize, borderSize * 2, borderSize * 2)
        context.fill()

        # Draw numbering
        if self.showNumbering:
            context.set_source_rgb(*NUMBERING_COLOUR)
            context.set_font_size(self.squareSize * 0.4)
            context.select_font_face("sans-serif", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
            
            def drawCenteredText(x, y, text):
                (_, _, w, h, _, _) = context.text_extents('b')
                matrix = context.get_matrix()
                context.translate(x, y)
                context.rotate(-self.angle)
                context.move_to(-w/2, h/2)
                context.show_text(text)
                context.set_matrix(matrix)
            offset = 0
            for i in xrange(8):
                f = 'abcdefgh'[i]
                r = '87654321'[i]
                drawCenteredText(offset - self.squareSize * 3.5, -self.squareSize * 4.25, glchess.chess.translate_file(f))
                drawCenteredText(offset - self.squareSize * 3.5, self.squareSize * 4.25, glchess.chess.translate_file(f))
                drawCenteredText(-self.squareSize * 4.25, offset - self.squareSize * 3.5, glchess.chess.translate_rank(r))
                drawCenteredText(self.squareSize * 4.25, offset - self.squareSize * 3.5, glchess.chess.translate_rank(r))
                offset += self.squareSize
        
        # Draw squares
        for i in xrange(8):
            for j in xrange(8):
                x = (i - 4) * self.squareSize
                y = (3 - j) * self.squareSize
                
                coord = chr(ord('a') + i) + chr(ord('1') + j)
                try:
                    highlight = self.highlight[coord]
                except KeyError:
                    highlight = None
                
                context.rectangle(x, y, self.squareSize, self.squareSize)
                if (i + j) % 2 == 0:
                    colour = BLACK_SQUARE_COLOURS[highlight]
                else:
                    colour = WHITE_SQUARE_COLOURS[highlight]
                context.set_source_rgb(*colour)
                context.fill()
                
        context.set_source_rgb(*PIECE_COLOUR)
        for piece in self.pieces:
            if piece.moving:
                continue
            piece.render(context)
        
        return True

    def renderDynamic(self, context):
        """Render the dynamic elements in a scene.
        
        This requires a Cairo context.
        """
        # Rotate board
        self.__rotate(context)

        context.set_source_rgb(*PIECE_COLOUR)
        for piece in self.pieces:
            # If not rotating and piece not moving then was rendered in the static phase
            if self.angle == self.targetAngle and not piece.moving:
                continue
            piece.render(context)

    def getSquare(self, x, y):
        """Find the chess square at a given 2D location.
        
        'x' is the number of pixels from the left of the scene to select.
        'y' is the number of pixels from the bottom of the scene to select.
        
        Return the co-ordinate in LAN format (string) or None if no square at this point.
        """
        # FIXME: Should use cairo rotation matrix but we don't have a context here
        if self.angle != self.targetAngle:
            return None
        
        boardWidth = self.squareSize * 9.0
        offset = ((self.width - boardWidth) / 2.0 + self.squareSize * 0.5, (self.height - boardWidth) / 2.0 + self.squareSize * 0.5)
        
        rank = (x - offset[0]) / self.squareSize
        if rank < 0 or rank >= 8.0:
            return None
        rank = int(rank)

        file = (y - offset[1]) / self.squareSize
        if file < 0 or file >= 8.0:
            return None
        file = 7 - int(file)
        
        # FIXME: See above
        if self.angle == math.pi:
            rank = 7 - rank
            file = 7 - file

        # Convert from co-ordinates to LAN format
        rank = chr(ord('a') + rank)
        file = chr(ord('1') + file)

        return rank + file
