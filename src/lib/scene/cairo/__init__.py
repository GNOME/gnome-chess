import math

import glchess.scene

import pieces

BACKGROUND_COLOUR    = (0.53, 0.63, 0.75)
BORDER_COLOUR        = (0.808, 0.361, 0.0)#(0.757, 0.490, 0.067)#(0.36, 0.21, 0.05)
BLACK_SQUARE_COLOURS = {None: (0.8, 0.8, 0.8), glchess.scene.HIGHLIGHT_SELECTED: (0.3, 1.0, 0.3), glchess.scene.HIGHLIGHT_CAN_MOVE: (0.3, 0.3, 1.0)}
WHITE_SQUARE_COLOURS = {None: (1.0, 1.0, 1.0), glchess.scene.HIGHLIGHT_SELECTED: (0.2, 1.0, 0.0), glchess.scene.HIGHLIGHT_CAN_MOVE: (0.2, 0.2, 0.8)}
PIECE_COLOUR         = (0.0, 0.0, 0.0)

class ChessPiece(glchess.scene.ChessPiece):
    """
    """
    
    __scene = None
    name = None
    
    __targetPos = None
    pos         = None
    
    moving       = False
    
    def __init__(self, scene, name, startPos = (0.0, 0.0)):
        """
        """
        self.__scene = scene
        self.name = name
        self.pos = self.__coordToLocation(startPos)
        
    def __coordToLocation(self, coord):
        """
        """
        rank = ord(coord[0]) - ord('a')
        file = ord(coord[1]) - ord('1')
        
        return (float(rank), float(file))

    def move(self, coord):
        """Extends glchess.scene.ChessPiece"""
        self.__targetPos = self.__coordToLocation(coord)
        self.moving = True
        self.__scene._startAnimation()
    
    def draw(self, state = 'default'):
        """
        """
        pass
        
    def animate(self, timeStep):
        """
        
        Return True if the piece has moved otherwise False.
        """
        if self.__targetPos is None:
            return False
        
        if self.pos == self.__targetPos:
            self.__targetPos = None
            return False
        
        # Get distance to target
        dx = self.__targetPos[0] - self.pos[0]
        dy = self.__targetPos[1] - self.pos[1]
        
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
    
    def render(self, offset, context):
        """
        """
        x = offset[0] + self.pos[0] * self.__scene.squareSize + self.__scene.PIECE_BORDER
        y = offset[1] + (7 - self.pos[1]) * self.__scene.squareSize + self.__scene.PIECE_BORDER
        pieces.piece(self.name, context, self.__scene.pieceSize, x, y)
        context.fill()

class Scene(glchess.scene.Scene):
    """
    """
    __pieces     = None
    __highlights = None
    
    __animating = False
    __changed   = True
    
    BORDER = 6.0
    PIECE_BORDER = 2.0

    def __init__(self):
        """Constructor for a Cairo scene"""
        self.__highlight = {}
        self.__pieces = []
        
    def onRedraw(self):
        """This method is called when the scene needs redrawing"""
        pass
    
    def _startAnimation(self):
        """
        """
        self.__changed = True
        if self.__animating is False:
            self.__animating = True
            self.startAnimation()

    def addChessPiece(self, chessSet, name, coord):
        """Add a chess piece model into the scene.
        
        'chessSet' is the name of the chess set (string).
        'name' is the name of the piece (string).
        'coord' is the the chess board location of the piece in LAN format (string).
        
        Returns a reference to this chess piece or raises an exception.
        """
        name = chessSet + name[0].upper() + name[1:]
        piece = ChessPiece(self, name, coord)
        self.__pieces.append(piece)
        
        # Redraw the scene
        self.__changed = True
        self.onRedraw()
        
        return piece
    
    def removeChessPiece(self, piece):
        """Remove chess piece.
        
        'piece' is a chess piece instance as returned by addChessPiece().
        """
        self.__pieces.remove(piece)
        self.__changed = True
        self.onRedraw()

    def setBoardHighlight(self, coords):
        """Highlight a square on the board.
        
        'coords' is a dictionary of highlight types keyed by square co-ordinates.
                 The co-ordinates are a tuple in the form (file,rank).
                 If None the highlight will be cleared.
        """
        self.__changed = True
        if coords is None:
            self.__highlight = {}
        else:
            self.__highlight = coords.copy()
        self.onRedraw()
    
    def reshape(self, width, height):
        """Resize the viewport into the scene.
        
        'width' is the width of the viewport in pixels.
        'height' is the width of the viewport in pixels.
        """
        self.__changed = True
        self.width = width
        self.height = height
        
        shortEdge = min(self.width, self.height)
        self.squareSize = (shortEdge - 2.0*self.BORDER) / 9.0
        self.pieceSize = self.squareSize - 2.0*self.PIECE_BORDER
        
        boardWidth = self.squareSize * 9.0
        self.offset = ((self.width - boardWidth) / 2.0, (self.height - boardWidth) / 2.0)
        
        self.__changed = True
        self.onRedraw()
        
    def setBoardRotation(self, angle):
        """Set the rotation on the board.
        
        'angle' is the angle the board should be drawn at in degress (float, [0.0, 360.0]).
        """
        pass
        
    def animate(self, timeStep):
        """Extends glchess.scene.Scene"""
        redraw = False
        for piece in self.__pieces:
            if piece.animate(timeStep):
                piece.moving = True
                redraw = True
            else:
                # Redraw static scene once pieces stop
                if piece.moving:
                    redraw = True
                    self.__changed = True
                piece.moving = False
                
        # Redraw scene or stop animation
        if redraw:
            self.__animating = True
            self.onRedraw()
        else:
            self.__animating = False
        return self.__animating

    def renderStatic(self, context):
        """Render the static elements in a scene.
        """
        if self.__changed is False:
            return False
        self.__changed = False

        # Clear background
        context.set_source_rgb(*BACKGROUND_COLOUR)
        context.paint()
        
        # Draw border
        context.set_source_rgb(*BORDER_COLOUR)
        context.rectangle(self.offset[0], self.offset[1], self.squareSize * 9.0, self.squareSize * 9.0)
        context.fill()
        
        offset = (self.offset[0] + self.squareSize * 0.5, self.offset[1] + self.squareSize * 0.5)
        
        for i in xrange(8):
            for j in xrange(8):
                x = offset[0] + i * self.squareSize
                y = offset[1] + (7 - j) * self.squareSize
                
                coord = chr(ord('a') + i) + chr(ord('1') + j)
                try:
                    highlight = self.__highlight[coord]
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
        for piece in self.__pieces:
            if piece.moving:
                continue
            piece.render(offset, context)
        
        return True

    def renderDynamic(self, context):
        """Render the dynamic elements in a scene.
        
        This requires a Cairo context.
        """
        offset = (self.offset[0] + self.squareSize * 0.5, self.offset[1] + self.squareSize * 0.5)
        
        context.set_source_rgb(*PIECE_COLOUR)
        for piece in self.__pieces:
            if not piece.moving:
                continue
            piece.render(offset, context)
            
    def getSquare(self, x, y):
        """Find the chess square at a given 2D location.
        
        'x' is the number of pixels from the left of the scene to select.
        'y' is the number of pixels from the bottom of the scene to select.
        
        Return the co-ordinate in LAN format (string) or None if no square at this point.
        """
        offset = (self.offset[0] + self.squareSize * 0.5, self.offset[1] + self.squareSize * 0.5)
        
        rank = (x - offset[0]) / self.squareSize
        if rank < 0 or rank >= 8.0:
            return None
        rank = int(rank)

        file = (y - offset[1]) / self.squareSize
        if file < 0 or file >= 8.0:
            return None
        file = 7 - int(file)

        # Convert from co-ordinates to LAN format
        rank = chr(ord('a') + rank)
        file = chr(ord('1') + file)

        return rank + file

    # Private methods
    
