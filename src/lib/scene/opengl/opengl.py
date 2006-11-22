import math
import os.path

from OpenGL.GL import *
from OpenGL.GLU import *

from glchess.defaults import *

import glchess.scene
import texture
import new_models
builtin_models = new_models

SQUARE_WIDTH      = 10.0
BOARD_DEPTH       = 3.0
BOARD_BORDER      = 5.0
BOARD_CHAMFER     = 2.0
BOARD_INNER_WIDTH = (SQUARE_WIDTH * 8.0)
BOARD_OUTER_WIDTH = (BOARD_INNER_WIDTH + BOARD_BORDER * 2.0)
OFFSET            = (BOARD_OUTER_WIDTH * 0.5)

LIGHT_AMBIENT_COLOUR  = (0.4, 0.4, 0.4, 1.0)
LIGHT_DIFFUSE_COLOUR  = (0.7, 0.7, 0.7, 1.0)
LIGHT_SPECULAR_COLOUR = (1.0, 1.0, 1.0, 1.0)

BOARD_AMBIENT   = (0.2, 0.2, 0.2, 1.0)
BOARD_DIFFUSE   = (0.8, 0.8, 0.8, 1.0)
BOARD_SPECULAR  = (1.0, 1.0, 1.0, 1.0)
BOARD_SHININESS = 128.0

BACKGROUND_COLOUR    = (0.53, 0.63, 0.75, 0.0)
BORDER_COLOUR        = (0.72, 0.33, 0.0)
BLACK_SQUARE_COLOURS = {None: (0.8, 0.8, 0.8), glchess.scene.HIGHLIGHT_SELECTED: (0.3, 1.0, 0.3), glchess.scene.HIGHLIGHT_CAN_MOVE: (0.3, 0.3, 1.0)}
WHITE_SQUARE_COLOURS = {None: (1.0, 1.0, 1.0), glchess.scene.HIGHLIGHT_SELECTED: (0.2, 1.0, 0.0), glchess.scene.HIGHLIGHT_CAN_MOVE: (0.2, 0.2, 0.8)}

class ChessPiece(glchess.scene.ChessPiece):
    """
    """    
    __scene = None
    
    __chessSet = None
    __name = None
    
    pos         = None
    __targetPos = None
    
    def __init__(self, scene, chessSet, name, startPos = (0.0, 0.0, 0.0)):
        """
        """
        self.__scene = scene
        self.__chessSet = chessSet
        self.__name = name
        self.pos = startPos

    def move(self, coord):
        """Extends glchess.scene.ChessPiece"""
        self.__targetPos = self.__scene._coordToLocation(coord)
        self.__scene._startAnimation()
    
    def draw(self, state = 'default'):
        """
        """
        self.__chessSet.drawPiece(self.__name, state, self.__scene)
        
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
        dz = self.__targetPos[2] - self.pos[2]
        
        # Get movement step in each direction
        SPEED = 50.0 # FIXME
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
        zStep = timeStep * SPEED
        if zStep > abs(dz):
            zStep = dz
        else:
            zStep *= cmp(dz, 0.0)
            
        # Move the piece
        self.pos = (self.pos[0] + xStep, self.pos[1] + yStep, self.pos[2] + zStep)
        return True

class Scene(glchess.scene.Scene):
    """
    """
    # The viewport dimensions
    __viewportWidth    = 0
    __viewportHeight   = 0
    __viewportAspect   = 1.0
    
    __animating        = False
    
    # Loading screen properties
    __throbberEnabled  = False
    __throbberAngle    = 0.0
    
    # The scene light position
    __lightPos         = None

    # The board angle in degrees
    __boardAngle       = 0.0
    __oldBoardAngle    = 0.0
    __targetBoardAngle = 0.0
    
    # OpenGL display list for the board and a flag to regenerate it
    __boardList        = None
    __regenerateBoard  = False
    
    # Texture objects for the board
    __whiteTexture     = None
    __blackTexture     = None

    # ...
    __pieces           = None
    __chessSets        = None
    __piecesMoving     = False
    
    # Dictionary of co-ordinates to highlight
    __highlights       = None

    def __init__(self):
        """Constructor for an OpenGL scene"""
        self.__lightPos = [100.0, 100.0, 100.0, 1.0]
        self.__pieces = []
        self.__highlights = {}
        
        self.__chessSets = {'white': builtin_models.WhiteBuiltinSet(), 'black': builtin_models.BlackBuiltinSet()}
        
        self.__whiteTexture = texture.Texture(os.path.join(TEXTURE_DIR, 'board.png'),
                                              ambient = BOARD_AMBIENT, diffuse = BOARD_DIFFUSE,
                                              specular = BOARD_SPECULAR, shininess = BOARD_SHININESS)
        self.__blackTexture = texture.Texture(os.path.join(TEXTURE_DIR, 'board.png'),
                                              ambient = BOARD_AMBIENT, diffuse = BOARD_DIFFUSE,
                                              specular = BOARD_SPECULAR, shininess = BOARD_SHININESS)
        
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
        chessSet = self.__chessSets[chessSet]
        piece = ChessPiece(self, chessSet, name, self._coordToLocation(coord))
        self.__pieces.append(piece)
        
        # Redraw the scene
        self.onRedraw()
        
        return piece
    
    def removeChessPiece(self, piece):
        """Remove chess piece.
        
        'piece' is a chess piece instance as returned by addChessPiece().
        """
        self.__pieces.remove(piece)
        self.onRedraw()

    def setBoardHighlight(self, coords):
        """Highlight a square on the board.
        
        'coords' is a dictionary of highlight types keyed by square co-ordinates.
                 The co-ordinates are a tuple in the form (file,rank).
                 If None the highlight will be cleared.
        """
        if coords is None:
            self.__highlights = {}
        else:
            self.__highlights = coords.copy()
            
        # Regenerate the optimised board model
        self.__regenerateBoard = True

        self.onRedraw()
    
    def reshape(self, width, height):
        """Resize the viewport into the scene.
        
        'width' is the width of the viewport in pixels.
        'height' is the width of the viewport in pixels.
        """
        self.__viewportWidth = int(width)
        self.__viewportHeight = int(height)
        self.__viewportAspect = float(self.__viewportWidth) / float(self.__viewportHeight)
        self.onRedraw()
        
    def setBoardRotation(self, angle):
        """Set the rotation on the board.
        
        'angle' is the angle the board should be drawn at in degress (float, [0.0, 360.0]).
        """
        self.__targetBoardAngle = angle
        self._startAnimation()

    def animate(self, timeStep):
        """Extends glchess.scene.Scene"""
        redraw1 = self.__animateThrobber(timeStep)
        self.__piecesMoving = self.__animatePieces(timeStep)
        redraw2 = self.__animateRotation(timeStep)
        if redraw1 or redraw2 or self.__piecesMoving:
            self.__animating = True
            self.onRedraw()
        else:
            self.__animating = False
        return self.__animating

    def render(self):
        """Render the scene.
        
        This requires an OpenGL context.
        """        
        glClearColor(*BACKGROUND_COLOUR)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        # Set the projection for this scene
        self.__setViewport()

        # Do camera and board rotation/translation
        glEnable(GL_DEPTH_TEST)
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
        self.__transformCamera()
        
        glLightfv(GL_LIGHT0, GL_AMBIENT, LIGHT_AMBIENT_COLOUR)
        glLightfv(GL_LIGHT0, GL_DIFFUSE, LIGHT_DIFFUSE_COLOUR)
        glLightfv(GL_LIGHT0, GL_SPECULAR, LIGHT_SPECULAR_COLOUR)
        glLightfv(GL_LIGHT0, GL_POSITION, self.__lightPos)
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        self.__transformBoard()
    
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_CULL_FACE)
        
        glEnable(GL_TEXTURE_2D)
        glEnable(GL_COLOR_MATERIAL)
        self.__drawBoard()
        glDisable(GL_COLOR_MATERIAL)
        glDisable(GL_TEXTURE_2D)
        
        # WORKAROUND: Mesa is corrupting polygons on the bottom of the models
        # It could be because the depth buffer has a low bit depth?
        glClear(GL_DEPTH_BUFFER_BIT)
        
        if self.__throbberEnabled:
            self.__drawThrobber()
        else:
            self.__drawPieces()

    def getSquare(self, x, y):
        """Find the chess square at a given 2D location.
        
        'x' is the number of pixels from the left of the scene to select.
        'y' is the number of pixels from the bottom of the scene to select.
        
        This requires an OpenGL context.
        
        Return the co-ordinate in LAN format (string) or None if no square at this point.
        """
        # FIXME: Don't rely on this? It seems to get corrupt when multiple games are started
        viewport = glGetIntegerv(GL_VIEWPORT)

        # Don't render to screen, just select
        # Selection buffer is large in case we select multiple squares at once (it generates an exception)
        glSelectBuffer(20)
        glRenderMode(GL_SELECT)

        glInitNames()
        glPushName(0)

        # Create pixel picking region near cursor location
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPickMatrix(x, (float(viewport[3]) - y), 1.0, 1.0, viewport)
        gluPerspective(60.0, float(viewport[2]) / float(viewport[3]), 0, 1)

        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
        self.__transformCamera()

        # Draw board

        self.__transformBoard()
        self.__drawSquares()

        # Render and check for hits
        # Catch the exception in case we select more than we can fit in the selection buffer
        glFlush()
        try:
            records = glRenderMode(GL_RENDER)
        except GLerror:
            records = None

        # Get the first record and use this as the selected square
        coord = None
        if records is not None:
            for record in records:
                coord = record[2]
                break

        # Reset projection matrix
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(60.0, float(viewport[2]) / float(viewport[3]), 0.1, 1000)
        
        if coord is None:
            return None
        
        # Convert from co-ordinates to LAN format
        rank = chr(ord('a') + coord[0])
        file = chr(ord('1') + coord[1])

        return rank + file

    # Private methods
    
    def _coordToLocation(self, coord):
        """
        """
        rank = ord(coord[0]) - ord('a')
        file = ord(coord[1]) - ord('1')
        x = BOARD_BORDER + float(rank) * SQUARE_WIDTH + 0.5 * SQUARE_WIDTH
        z = -(BOARD_BORDER + float(file) * SQUARE_WIDTH + 0.5 * SQUARE_WIDTH)
        
        return (x, 0.0, z)
        
    def __animateThrobber(self, timeStep):
        """
        """
        if self.__throbberEnabled is False:
            return False
        
        self.__throbberAngle += timeStep * (math.pi * 2.0) / 2.0
        while self.__throbberAngle > (math.pi * 2.0):
            self.__throbberAngle -= 2.0 * math.pi
        return True
        
    def __animateRotation(self, timeStep):
        """
        """
        if self.__boardAngle == self.__targetBoardAngle:
            return False
        
        # Wait unti pieces have stopped moving
        if self.__piecesMoving:
            return False

        # Rotate board to the chosen angle
        length = abs(self.__targetBoardAngle - self.__oldBoardAngle)
        self.__boardAngle += timeStep * length / 0.8
        while self.__boardAngle > 360.0:
            self.__boardAngle -= 360.0
        travelled = self.__targetBoardAngle - self.__boardAngle
        while travelled < 0.0:
            travelled += 360.0
            
        # If have moved through the remaining angle then clip to the target
        if travelled >= length:
            self.__oldBoardAngle = self.__boardAngle = self.__targetBoardAngle

        return True
    
    def __animatePieces(self, timeStep):
        """
        """
        active = False
        for piece in self.__pieces:
            if piece.animate(timeStep):
                active = True
        
        # If the throbber is enabled the pieces are hidden so don't redraw
        if active and not self.__throbberEnabled:
            return True
        return False
            
    def __drawThrobber(self):
        """
        """
        glDisable(GL_LIGHTING)
        glDisable(GL_DEPTH_TEST)
            
        # Orthographic projection with even scaling
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
            
        if self.__viewportWidth > self.__viewportHeight:
            h = 1.0
            w = 1.0 * self.__viewportWidth / self.__viewportHeight
        else:
            h = 1.0 * self.__viewportHeight / self.__viewportWidth
            w = 1.0
        gluOrtho2D(0, w, 0, h)
            
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
            
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        glColor4f(0.0, 0.0, 0.0, 0.75)
        glBegin(GL_QUADS)
        glVertex2f(-1.0, -1.0)
        glVertex2f(w + 1.0, -1.0)
        glVertex2f(w + 1.0, h + 1.0)
        glVertex2f(-1.0, h + 1.0)
        glEnd()
            
        NSECTIONS = 9
        RADIUS_OUT0 = 0.4
        RADIUS_OUT1 = 0.43
        RADIUS_OUT2 = 0.4
        RADIUS_IN0 = 0.25#0.1
        RADIUS_IN1 = 0.24#0.09
        RADIUS_IN2 = 0.25#0.1
        STEP_ANGLE = 2.0 * math.pi / float(NSECTIONS)
        HALF_WIDTH = 0.8 * (0.5 * STEP_ANGLE)

        glTranslatef(0.5 * w, 0.5 * h, 0.0)
        glBegin(GL_QUADS)
            
        for i in xrange(NSECTIONS):
            theta = 2.0 * math.pi * float(i) / float(NSECTIONS)
            leadTheta = theta + HALF_WIDTH
            lagTheta = theta - HALF_WIDTH
            x0 = math.sin(leadTheta)
            y0 = math.cos(leadTheta)
            x1 = math.sin(theta)
            y1 = math.cos(theta)
            x2 = math.sin(lagTheta)
            y2 = math.cos(lagTheta)
                
            angleDifference = self.__throbberAngle - theta
            if angleDifference > math.pi:
                angleDifference -= 2.0 * math.pi
            elif angleDifference < -math.pi:
                angleDifference += 2.0 * math.pi

            stepDifference = angleDifference / STEP_ANGLE
            if stepDifference > -0.5 and stepDifference < 0.5:
                x = 2.0 * abs(stepDifference)
                glColor4f(1.0, x, x, 0.6)
            else:
                glColor4f(1.0, 1.0, 1.0, 0.6)
                
            glVertex2f(RADIUS_IN0 * x0, RADIUS_IN0 * y0)
            glVertex2f(RADIUS_OUT0 * x0, RADIUS_OUT0 * y0)
            glVertex2f(RADIUS_OUT1 * x1, RADIUS_OUT1 * y1)
            glVertex2f(RADIUS_IN1 * x1, RADIUS_IN1 * y1)
                
            glVertex2f(RADIUS_IN1 * x1, RADIUS_IN1 * y1)
            glVertex2f(RADIUS_OUT1 * x1, RADIUS_OUT1 * y1)
            glVertex2f(RADIUS_OUT2 * x2, RADIUS_OUT2 * y2)
            glVertex2f(RADIUS_IN2 * x2, RADIUS_IN2 * y2)

        glEnd()
            
        glDisable(GL_BLEND)

    def __setViewport(self):
        """Perform the projection matrix transformation for the current viewport"""
        glViewport(0, 0, self.__viewportWidth, self.__viewportHeight)
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(60.0, self.__viewportAspect, 0.1, 1000)

    def __transformCamera(self):
        """Perform the camera matrix transformation"""
        gluLookAt(0.0, 90.0, 45.0,
                  0.0,  0.0, 5.0,
                  0.0,  1.0,  0.0)

    def __drawBoard(self):
        """Draw a chessboard"""        
        # Use pre-rendered version if available
        if self.__regenerateBoard is False and self.__boardList is not None:
            glCallList(self.__boardList)
            return
        
        # Attempt to store the board as a display list
        if self.__boardList is None:
            list = glGenLists(1)
            if list != 0:
                self.__boardList = list

        # If have a list store there
        if self.__boardList is not None:
            glNewList(self.__boardList, GL_COMPILE_AND_EXECUTE)
            
        # Board verticies
        # (lower 12-15 are under 8-11)
        #
        # a b c         d e f
        #
        # 8-----------------9  g
        # |\               /|
        # | 4-------------5 |  h
        # | |             | |
        # | | 0---------1 | |  i
        # | | |         | | |
        # | | |         | | |
        # | | 3---------2 | |  j
        # | |             | |
        # | 7-------------6 |  k
        # |/               \|
        # 11---------------10  l
        #
        #     |- board -|
        #        width

        # Draw the border
        glColor3f(*BORDER_COLOUR)

        # Top
        a = 0.0
        b = BOARD_CHAMFER
        c = BOARD_BORDER
        d = c + (SQUARE_WIDTH * 8.0)
        e = d + BOARD_BORDER - BOARD_CHAMFER
        f = d + BOARD_BORDER
        l = 0.0
        k = -BOARD_CHAMFER
        j = -BOARD_BORDER
        i = j - (SQUARE_WIDTH * 8.0)
        h = i - BOARD_BORDER + BOARD_CHAMFER
        g = i - BOARD_BORDER
        verticies = [(c, 0.0, i), (d, 0.0, i),
                     (d, 0.0, j), (c, 0.0, j),
                     (b, 0.0, h), (e, 0.0, h),
                     (e, 0.0, k), (b, 0.0, k),
                     (a, -BOARD_CHAMFER, g), (f, -BOARD_CHAMFER, g),
                     (f, -BOARD_CHAMFER, l), (a, -BOARD_CHAMFER, l),
                     (a, -BOARD_DEPTH, g), (f, -BOARD_DEPTH, g), (f, -BOARD_DEPTH, l), (a, -BOARD_DEPTH, l)]
        
        normals = [(0.0, 1.0, 0.0), (0.0, 0.0, -1.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (-1.0, 0.0, 0.0),
                   (0.0, 0.707, -0.707), (0.707, 0.707, 0.0), (0.0, 0.707, 0.707), (-0.707, 0.707, 0.0)]
        
        #textureCoords = [(0.0, 0.0), (
        
        quads = [(0, 1, 5, 4, 0), (1, 2, 6, 5, 0), (2, 3, 7, 6, 0), (3, 0, 4, 7, 0),
                 (4, 5, 9, 8, 5), (5, 6, 10, 9, 6), (6, 7, 11, 10, 7), (7, 4, 8, 11, 8),
                 (8, 9, 13, 12, 1), (9, 10, 14, 13, 2), (10, 11, 15, 14, 3), (11, 8, 12, 15, 4)]
        
        glDisable(GL_TEXTURE_2D)
        glBegin(GL_QUADS)
        for q in quads:
            glNormal3fv(normals[q[4]])
            #glTexCoord2fv(textureCoords[q[0]])
            glVertex3fv(verticies[q[0]])
            #glTexCoord2fv(textureCoords[q[1]])
            glVertex3fv(verticies[q[1]])
            #glTexCoord2fv(textureCoords[q[2]])
            glVertex3fv(verticies[q[2]])
            #glTexCoord2fv(textureCoords[q[3]])
            glVertex3fv(verticies[q[3]])
        glEnd()

        # Draw the squares
        glEnable(GL_TEXTURE_2D)
        for x in [0, 1, 2, 3, 4, 5, 6, 7]:
            for y in [0, 1, 2, 3, 4, 5, 6, 7]:
                isBlack = (x + (y % 2) + 1) % 2

                # Get the highlight type
                coord = chr(ord('a') + x) + chr(ord('1') + y)
                try:
                    highlight = self.__highlights[coord]
                except KeyError:
                    highlight = None
                
                if isBlack:
                    colour = BLACK_SQUARE_COLOURS[highlight]
                    self.__whiteTexture.bind() #blackTexture
                else:
                    colour = WHITE_SQUARE_COLOURS[highlight]
                    self.__whiteTexture.bind()

                x0 = BOARD_BORDER + (x * SQUARE_WIDTH)
                x1 = x0 + SQUARE_WIDTH
                z0 = BOARD_BORDER + (y * SQUARE_WIDTH)
                z1 = z0 + SQUARE_WIDTH

                glBegin(GL_QUADS)
                glNormal3f(0.0, 1.0, 0.0)
                glColor3fv(colour)
                glTexCoord2f(0.0, 0.0)
                glVertex3f(x0, 0.0, -z0)
                glTexCoord2f(1.0, 0.0)
                glVertex3f(x1, 0.0, -z0)
                glTexCoord2f(1.0, 1.0)
                glVertex3f(x1, 0.0, -z1)
                glTexCoord2f(0.0, 1.0)
                glVertex3f(x0, 0.0, -z1)
                glEnd()
        
        if self.__boardList is not None:
            glEndList()
            glCallList(self.__boardList)
        
    def __drawSquares(self):
        """Draw the board squares for picking"""

        # draw the floor squares
        for u in [0, 1, 2, 3, 4, 5, 6, 7]:
            glLoadName(u)

            for v in [0, 1, 2, 3, 4, 5, 6, 7]:
                glPushName(v)

                # Draw square
                glBegin(GL_QUADS)
                x0 = BOARD_BORDER + (u * SQUARE_WIDTH)
                x1 = x0 + SQUARE_WIDTH
                z0 = BOARD_BORDER + (v * SQUARE_WIDTH)
                z1 = z0 + SQUARE_WIDTH

                glVertex3f(x0, 0.0, -z0)
                glVertex3f(x1, 0.0, -z0)
                glVertex3f(x1, 0.0, -z1)
                glVertex3f(x0, 0.0, -z1)
                glEnd()

                glPopName()
        
    def __drawPieces(self):
        """Draw the pieces in the scene"""
        glEnable(GL_TEXTURE_2D)

        for piece in self.__pieces:
            glPushMatrix()
            glTranslatef(piece.pos[0], piece.pos[1], piece.pos[2])

            # Draw the model
            piece.draw()

            glPopMatrix()
        
        glDisable(GL_TEXTURE_2D)

    def __transformBoard(self):
        """Perform the board transform"""
        # Rotate the board
        glRotatef(self.__boardAngle, 0.0, 1.0, 0.0)

        # Offset board so centre is (0.0,0.0)
        glTranslatef(-OFFSET, 0.0, OFFSET)
