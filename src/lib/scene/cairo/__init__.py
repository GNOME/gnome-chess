import math
import cairo

import glchess.scene

import pieces

from gettext import gettext as _

BACKGROUND_COLOUR    = (0.53, 0.63, 0.75)
BORDER_COLOUR        = (0.808, 0.361, 0.0)#(0.757, 0.490, 0.067)#(0.36, 0.21, 0.05)
NUMBERING_COLOUR     = (249.0/255, 172.0/255, 109.0/255)#(249.0/255, 132.0/255, 38.0/255)
BLACK_SQUARE_COLOURS = {None:                               (0.8, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_SELECTED:   (0.3, 1.0, 0.3),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   (0.3, 0.3, 0.8),
                        glchess.scene.HIGHLIGHT_THREATENED: (1.0, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   (1.0, 0.3, 0.3)}
WHITE_SQUARE_COLOURS = {None:                               (1.0, 1.0, 1.0),
                        glchess.scene.HIGHLIGHT_SELECTED:   (0.2, 1.0, 0.0),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   (0.2, 0.2, 0.8),
                        glchess.scene.HIGHLIGHT_THREATENED: (1.0, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   (1.0, 0.2, 0.2)}
PIECE_COLOUR         = (0.0, 0.0, 0.0)

class ChessPiece(glchess.scene.ChessPiece):
    """
    """
    scene       = None
    name        = None
    
    # Co-ordinate being moved to
    coord       = None
    
    targetPos   = None
    
    # Current position
    pos         = None
    moving      = False

    # Delete once moved to location
    delete      = False
    
    def __init__(self, scene, name, coord, feedback):
        """
        """
        self.scene = scene
        self.feedback = feedback
        self.name = name
        self.coord = coord
        self.pos = self.__coordToLocation(coord)
        
    def __coordToLocation(self, coord):
        """
        """
        rank = ord(coord[0]) - ord('a')
        file = ord(coord[1]) - ord('1')
        
        return (float(rank), float(file))

    def move(self, coord, delete, animate = True):
        """Extends glchess.scene.ChessPiece"""
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
        matrix = context.get_matrix()
        x = (self.pos[0] - 4) * self.scene.squareSize
        y = (3 - self.pos[1]) * self.scene.squareSize
        context.translate(x, y)
        context.translate(self.scene.squareSize / 2, self.scene.squareSize / 2)
        context.rotate(-self.scene.angle)
        context.translate(-self.scene.squareSize / 2, -self.scene.squareSize / 2)
        pieces.piece(self.name, context, self.scene.pieceSize, 0, 0)
        context.fill()
        context.set_matrix(matrix)

class Scene(glchess.scene.Scene):
    """
    """
    feedback    = None
    
    pieces      = None
    highlights  = None
    
    angle       = 0.0
    targetAngle = 0.0
    
    animating     = False
    redrawStatic  = True

    showNumbering = False
    
    _animationQueue = None
    
    BORDER = 6.0
    PIECE_BORDER = 2.0

    def __init__(self, feedback):
        """Constructor for a Cairo scene"""
        self.feedback = feedback
        self.highlight = {}
        self.pieces = []
        self._animationQueue = []
    
    def addChessPiece(self, chessSet, name, coord, feedback):
        """Add a chess piece model into the scene.
        
        'chessSet' is the name of the chess set (string).
        'name' is the name of the piece (string).
        'coord' is the the chess board location of the piece in LAN format (string).
        
        Returns a reference to this chess piece or raises an exception.
        """
        name = chessSet + name[0].upper() + name[1:]
        piece = ChessPiece(self, name, coord, feedback)
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
        
        shortEdge = min(self.width, self.height)
        self.squareSize = (shortEdge - 2.0*self.BORDER) / 9.0
        self.pieceSize = self.squareSize - 2.0*self.PIECE_BORDER

        self.redrawStatic = True
        self.feedback.onRedraw()

    def setBoardRotation(self, angle, animate = True):
        """Extends glchess.scene.Scene"""
        # Convert from degrees to radians
        a = angle * math.pi / 180.0
        
        if self.angle == a:
            return
        self.targetAngle = a
        
        if not animate:
            self.angle = a
            self.feedback.onRedraw()
            return

        # Start animation
        if self.animating is False:
            self.animating = True
            self.feedback.startAnimation()            

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

    def renderStatic(self, context):
        """Render the static elements in a scene.
        """
        if self.redrawStatic is False:
            return False
        self.redrawStatic = False

        # Clear background
        context.set_source_rgb(*BACKGROUND_COLOUR)
        context.paint()
        
        # Rotate board
        self.__rotate(context)
        
        # Draw border
        context.set_source_rgb(*BORDER_COLOUR)
        context.rectangle(-self.squareSize * 4.5, -self.squareSize * 4.5, self.squareSize * 9.0, self.squareSize * 9.0)
        context.fill()

        # Draw numbering
        if self.showNumbering:
            offset = 0
            context.set_source_rgb(*NUMBERING_COLOUR)
            context.set_font_size(self.squareSize * 0.4)
            context.select_font_face("sans-serif", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
	    # Chess board columns (files) label marked for translation. 
            files = [_('a'), _('b'), _('c'), _('d'), _('e'), _('f'), _('g'), _('h')]
	    # Chess board rows (ranks) label marked for translation.
            ranks = [_('8'), _('7'), _('6'), _('5'), _('4'), _('3'), _('2'), _('1')]
            def drawCenteredText(x, y, text):
                (_, _, w, h, _, _) = context.text_extents('b')
                matrix = context.get_matrix()
                context.translate(x, y)
                context.rotate(-self.angle)
                context.move_to(-w/2, h/2)
                context.show_text(text)
                context.set_matrix(matrix)
            for i in xrange(8):
                drawCenteredText(offset - self.squareSize * 3.5, -self.squareSize * 4.25, files[i])
                drawCenteredText(offset - self.squareSize * 3.5, self.squareSize * 4.25, files[i])
                drawCenteredText(-self.squareSize * 4.25, offset - self.squareSize * 3.5, ranks[i])
                drawCenteredText(self.squareSize * 4.25, offset - self.squareSize * 3.5, ranks[i])
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

    # Private methods
    
