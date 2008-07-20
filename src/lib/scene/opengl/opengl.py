import math
import os.path
from gettext import gettext as _

import cairo
from OpenGL.GL import *
from OpenGL.GLU import *

from glchess.defaults import *

import glchess.scene
import texture
import new_models
builtin_models = new_models

PIECE_MOVE_SPEED    = 50.0 # FIXME: Define units
BOARD_ROTATION_TIME = 0.8

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
BLACK_SQUARE_COLOURS = {None:                               (0.8, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_SELECTED:   (0.3, 1.0, 0.3),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   (0.3, 0.3, 1.0),
                        glchess.scene.HIGHLIGHT_THREATENED: (1.0, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   (1.0, 0.3, 0.3)}
WHITE_SQUARE_COLOURS = {None:                               (1.0, 1.0, 1.0),
                        glchess.scene.HIGHLIGHT_SELECTED:   (0.2, 1.0, 0.0),
                        glchess.scene.HIGHLIGHT_CAN_MOVE:   (0.2, 0.2, 0.8),
                        glchess.scene.HIGHLIGHT_THREATENED: (1.0, 0.8, 0.8),
                        glchess.scene.HIGHLIGHT_CAN_TAKE:   (1.0, 0.2, 0.2)}

class ChessPiece(glchess.scene.ChessPiece):
    """
    """    
    scene     = None
    
    # The piece to render
    chessSet  = None
    name      = None
    
    # The algebraic square location
    location  = ''
    
    # The OpenGL co-ordinate location
    pos       = None
    targetPos = None
    
    # Is the piece moving?
    moving    = False
    
    # Delete once moved?
    delete    = False
    
    def __init__(self, scene, chessSet, name, location, feedback):
        """
        """
        self.scene = scene
        self.feedback = feedback
        self.chessSet = chessSet
        self.name = name
        self.location = location
        self.pos = self.scene._coordToLocation(location)

    def move(self, coord, delete, animate = True):
        """Extends glchess.scene.ChessPiece"""
        self.delete = delete
        self.location = coord
        self.targetPos = self.scene._coordToLocation(coord)
        
        # If already there then delete
        if self.pos == self.targetPos:
            self.targetPos = None
            if delete:
                self.scene.pieces.remove(self)
                self.feedback.onDeleted()
                self.scene.feedback.onRedraw()
            return
            
        # If not currently moving then start
        if not self.moving:
            self.scene._animationQueue.append(self)
            self.moving = True
            
            # Start animation
            if self.scene.animating is False:
                self.scene.animating = True
                self.scene.feedback.startAnimation()
    
    def draw(self, state = 'default'):
        """
        """
        self.chessSet.drawPiece(self.name, state, self.scene)
        
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
        dz = self.targetPos[2] - self.pos[2]
        
        # Get movement step in each direction
        xStep = timeStep * PIECE_MOVE_SPEED
        if xStep > abs(dx):
            xStep = dx
        else:
            xStep *= cmp(dx, 0.0)
        yStep = timeStep * PIECE_MOVE_SPEED
        if yStep > abs(dy):
            yStep = dy
        else:
            yStep *= cmp(dy, 0.0)
        zStep = timeStep * PIECE_MOVE_SPEED
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
    viewportWidth    = 0
    viewportHeight   = 0
    viewportAspect   = 1.0
    
    animating        = False
    
    # Loading screen properties
    throbberEnabled  = False
    throbberAngle    = 0.0
    
    # The scene light position
    lightPos         = None

    # The board angle in degrees
    boardAngle       = 0.0
    oldBoardAngle    = 0.0
    targetBoardAngle = 0.0
    
    # OpenGL display list for the board and a flag to regenerate it
    boardList        = None
    regenerateBoard  = False
    
    # Texture objects for the board
    whiteTexture     = None
    blackTexture     = None

    # ...
    pieces           = None
    chessSets        = None
    piecesMoving     = False
    
    # Dictionary of co-ordinates to highlight
    highlights       = None
    
    _animationQueue  = []

    showNumbering = False
    numberingTexture = None

    def __init__(self, feedback):
        """Constructor for an OpenGL scene"""
        self.feedback = feedback
        self.lightPos = [100.0, 100.0, 100.0, 1.0]
        self.pieces = []
        self.highlights = {}
        self._animationQueue = []
        
        self.chessSets = {'white': builtin_models.WhiteBuiltinSet(), 'black': builtin_models.BlackBuiltinSet()}
        
        self.whiteTexture = texture.Texture(os.path.join(TEXTURE_DIR, 'board.png'),
                                            ambient = BOARD_AMBIENT, diffuse = BOARD_DIFFUSE,
                                            specular = BOARD_SPECULAR, shininess = BOARD_SHININESS)
        self.blackTexture = texture.Texture(os.path.join(TEXTURE_DIR, 'board.png'),
                                            ambient = BOARD_AMBIENT, diffuse = BOARD_DIFFUSE,
                                            specular = BOARD_SPECULAR, shininess = BOARD_SHININESS)

    def onRedraw(self):
        """This method is called when the scene needs redrawing"""
        pass
    
    def addChessPiece(self, chessSet, name, coord, feedback):
        """Add a chess piece model into the scene.
        
        'chessSet' is the name of the chess set (string).
        'name' is the name of the piece (string).
        'coord' is the the chess board location of the piece in LAN format (string).
        'feedback' is the feedback object (extends scene.ChessPieceFeedback).

        Returns a reference to this chess piece or raises an exception.
        """
        chessSet = self.chessSets[chessSet]
        piece = ChessPiece(self, chessSet, name, coord, feedback)
        self.pieces.append(piece)
        
        # Redraw the scene
        self.feedback.onRedraw()
        
        return piece

    def setBoardHighlight(self, coords):
        """Highlight a square on the board.
        
        'coords' is a dictionary of highlight types keyed by square co-ordinates.
                 The co-ordinates are a tuple in the form (file,rank).
                 If None the highlight will be cleared.
        """
        if coords is None:
            self.highlights = {}
        else:
            self.highlights = coords.copy()
            
        # Regenerate the optimised board model
        self.regenerateBoard = True

        self.feedback.onRedraw()

    def showBoardNumbering(self, showNumbering):
        """Extends glchess.scene.Scene"""
        self.showNumbering = showNumbering
        self.feedback.onRedraw()
    
    def reshape(self, width, height):
        """Resize the viewport into the scene.
        
        'width' is the width of the viewport in pixels.
        'height' is the width of the viewport in pixels.
        """
        self.viewportWidth = int(width)
        self.viewportHeight = int(height)
        self.viewportAspect = float(self.viewportWidth) / float(self.viewportHeight)
        self.feedback.onRedraw()

    def setBoardRotation(self, angle, animate = True):
        """Set the rotation on the board.
        
        'angle' is the angle the board should be drawn at in degress (float, [0.0, 360.0]).
        """
        self.targetBoardAngle = angle
        
        if not animate:
            self.oldBoardAngle = self.boardAngle = angle
            self.feedback.onRedraw()
            return
        
        if self.animating is False:
            self.animating = True
            self.feedback.startAnimation()

    def animate(self, timeStep):
        """Extends glchess.scene.Scene"""
        redraw1 = self.animateThrobber(timeStep)
        self.piecesMoving = self.animatePieces(timeStep)
        redraw2 = self.animateRotation(timeStep)
        if redraw1 or redraw2 or self.piecesMoving:
            self.animating = True
            self.feedback.onRedraw()
        else:
            self.animating = False
        return self.animating

    def render(self):
        """Render the scene.
        
        This requires an OpenGL context.
        """
        glClearColor(*BACKGROUND_COLOUR)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        # Set the projection for this scene
        self.setViewport()

        # Do camera and board rotation/translation
        glEnable(GL_DEPTH_TEST)
        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
        self.transformCamera()
        
        glLightfv(GL_LIGHT0, GL_AMBIENT, LIGHT_AMBIENT_COLOUR)
        glLightfv(GL_LIGHT0, GL_DIFFUSE, LIGHT_DIFFUSE_COLOUR)
        glLightfv(GL_LIGHT0, GL_SPECULAR, LIGHT_SPECULAR_COLOUR)
        glLightfv(GL_LIGHT0, GL_POSITION, self.lightPos)
        glEnable(GL_LIGHTING)
        glEnable(GL_LIGHT0)
        
        self.transformBoard()
    
        glEnable(GL_DEPTH_TEST)
        glEnable(GL_CULL_FACE)
        
        glEnable(GL_TEXTURE_2D)
        glEnable(GL_COLOR_MATERIAL)
        self.drawBoard()
        glDisable(GL_COLOR_MATERIAL)
        glDisable(GL_TEXTURE_2D)
        
        if self.showNumbering:
            self.drawNumbering()
        
        # WORKAROUND: Mesa is corrupting polygons on the bottom of the models
        # It could be because the depth buffer has a low bit depth?
        glClear(GL_DEPTH_BUFFER_BIT)
        
        if self.throbberEnabled:
            self.drawThrobber()
        else:
            self.drawPieces()
            
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

        # Create pixel picking region near cursor location
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPickMatrix(x, (float(viewport[3]) - y), 1.0, 1.0, viewport)
        gluPerspective(60.0, float(viewport[2]) / float(viewport[3]), 0, 1)

        glMatrixMode(GL_MODELVIEW)
        glLoadIdentity()
        self.transformCamera()

        # Draw board

        self.transformBoard()
        self.drawSquares()

        # Render and check for hits
        # Catch the exception in case we select more than we can fit in the selection buffer
        glFlush()
        try:
            records = glRenderMode(GL_RENDER)
        except GLerror:
            coord = None
        else:
            # Get the first record and use this as the selected square
            if len(records) > 0:
                (_, _, coord) = records[0]
            else:
                coord = None

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
        
    def animateThrobber(self, timeStep):
        """
        """
        if self.throbberEnabled is False:
            return False
        
        self.throbberAngle += timeStep * (math.pi * 2.0) / 2.0
        while self.throbberAngle > (math.pi * 2.0):
            self.throbberAngle -= 2.0 * math.pi
        return True
        
    def animateRotation(self, timeStep):
        """
        """
        if self.boardAngle == self.targetBoardAngle:
            return False
        
        # Wait unti pieces have stopped moving
        if self.piecesMoving:
            return False

        # Rotate board to the chosen angle
        length = abs(self.targetBoardAngle - self.oldBoardAngle)
        self.boardAngle += timeStep * length / BOARD_ROTATION_TIME
        while self.boardAngle > 360.0:
            self.boardAngle -= 360.0
        travelled = self.targetBoardAngle - self.boardAngle
        while travelled < 0.0:
            travelled += 360.0
            
        # If have moved through the remaining angle then clip to the target
        if travelled >= length:
            self.oldBoardAngle = self.boardAngle = self.targetBoardAngle

        return True
    
    def animatePieces(self, timeStep):
        """
        """
        if len(self._animationQueue) == 0:
            return False
        
        redraw = False
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

        if redraw:
            self.feedback.onRedraw()

        return len(self._animationQueue) > 0
            
    def drawThrobber(self):
        """
        """
        glDisable(GL_LIGHTING)
        glDisable(GL_DEPTH_TEST)
            
        # Orthographic projection with even scaling
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
            
        if self.viewportWidth > self.viewportHeight:
            h = 1.0
            w = 1.0 * self.viewportWidth / self.viewportHeight
        else:
            h = 1.0 * self.viewportHeight / self.viewportWidth
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
                
            angleDifference = self.throbberAngle - theta
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

    def setViewport(self):
        """Perform the projection matrix transformation for the current viewport"""
        glViewport(0, 0, self.viewportWidth, self.viewportHeight)
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        gluPerspective(60.0, self.viewportAspect, 0.1, 1000)

    def transformCamera(self):
        """Perform the camera matrix transformation"""
        gluLookAt(0.0, 90.0, 45.0,
                  0.0,  0.0, 5.0,
                  0.0,  1.0,  0.0)
                  
    def _makeNumberingTexture(self):
        WIDTH = 64
        HEIGHT = 64
        TEXTURE_WIDTH = WIDTH*16
        TEXTURE_HEIGHT = HEIGHT

        # Chess board columns (files) label marked for translation. Please translate to the first eight letters of your alphabet, or the most appropriate eight characters/symbols for labelling the columns of a chess board. 
        files = [_('a'), _('b'), _('c'), _('d'), _('e'), _('f'), _('g'), _('h')]
        # Chess board rows (ranks) label marked for translation. Please translate to the first eight numbers with your native number symbols, or the most appropriate eight numbers/symbols for labelling the rows of a chess board.
        ranks = [_('1'), _('2'), _('3'), _('4'), _('5'), _('6'), _('7'), _('8')]

        surface = cairo.ImageSurface(cairo.FORMAT_A8, TEXTURE_WIDTH, TEXTURE_HEIGHT)
        context = cairo.Context(surface)
        context.set_source_rgba(1.0, 1.0, 1.0, 1.0)
        context.select_font_face("sans-serif", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        context.set_font_size(WIDTH)
        (ascent, descent, x, x, x) = context.font_extents()
        scale = WIDTH / (ascent + descent)

        def drawCenteredText(x, y, scale, text):
            (w2, h2, w, h, _, _) = context.text_extents(text)
            matrix = context.get_matrix()
            context.translate(x, y)
            context.move_to(-w*scale/2, h*scale/2)
            context.scale(scale, scale)
            context.show_text(text)
            context.set_matrix(matrix)

        xoffset = WIDTH * 0.5
        yoffset = HEIGHT * 0.5
        for i in xrange(8):
            drawCenteredText(xoffset, yoffset, scale, files[i])
            drawCenteredText(xoffset + (WIDTH * 8), yoffset, scale, ranks[i])
            xoffset += WIDTH
        data = surface.get_data()

        t = glGenTextures(1)
        glBindTexture(GL_TEXTURE_2D, t)
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        
        try:
            gluBuild2DMipmaps(GL_TEXTURE_2D, GL_ALPHA, TEXTURE_WIDTH, TEXTURE_HEIGHT,
                              GL_ALPHA, GL_UNSIGNED_BYTE, str(data))
        except GLUerror, e:
            glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, TEXTURE_WIDTH, TEXTURE_HEIGHT, 0, GL_ALPHA, GL_UNSIGNED_BYTE, str(data))
            
        return t
    
    def drawNumbering(self):
        if self.numberingTexture is None:
            self.numberingTexture = self._makeNumberingTexture()
            
        TEXT_WIDTH = BOARD_BORDER * 0.8
        TEXT_OFFSET = (BOARD_BORDER + BOARD_CHAMFER) * 0.5
        offset = BOARD_BORDER + SQUARE_WIDTH * 0.5
        whiteZOffset = -TEXT_OFFSET
        blackZOffset = -BOARD_OUTER_WIDTH + TEXT_OFFSET
        leftOffset = TEXT_OFFSET
        rightOffset = BOARD_OUTER_WIDTH - TEXT_OFFSET

        def drawLabel(x, z, cell):
            w = 1.0 / 16
            l = cell / 16.0
            
            glPushMatrix()
            glTranslatef(x, 0.0, z)
            glRotatef(-self.boardAngle, 0.0, 1.0, 0.0)

            glBegin(GL_QUADS)            
            glTexCoord2f(l, 0.0)
            glVertex3f(-TEXT_WIDTH/2, 0.0, -TEXT_WIDTH/2)
            glTexCoord2f(l, 1.0)
            glVertex3f(-TEXT_WIDTH/2, 0.0, TEXT_WIDTH/2)
            glTexCoord2f(l + w, 1.0)
            glVertex3f(TEXT_WIDTH/2, 0.0, TEXT_WIDTH/2)
            glTexCoord2f(l + w, 0.0)
            glVertex3f(TEXT_WIDTH/2, 0.0, -TEXT_WIDTH/2)
            glEnd()
            
            glPopMatrix()

        glNormal3f(0.0, 1.0, 0.0)
        glDisable(GL_DEPTH_TEST)
        glEnable(GL_TEXTURE_2D)
        glEnable(GL_BLEND)
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
        glBindTexture(GL_TEXTURE_2D, self.numberingTexture)

        for i in xrange(8):
            drawLabel(leftOffset, -offset, i + 8)
            drawLabel(rightOffset, -offset, i + 8)
            drawLabel(offset, whiteZOffset, i)
            drawLabel(offset, blackZOffset, i)

            offset += SQUARE_WIDTH

        glEnable(GL_DEPTH_TEST)
        glDisable(GL_BLEND)
        glDisable(GL_TEXTURE_2D)

    def drawBoard(self):
        """Draw a chessboard"""
        # Use pre-rendered version if available
        if self.regenerateBoard is False and self.boardList is not None:
            glCallList(self.boardList)
            return
        
        # Attempt to store the board as a display list
        if self.boardList is None:
            list = glGenLists(1)
            if list != 0:
                self.boardList = list

        # If have a list store there
        if self.boardList is not None:
            glNewList(self.boardList, GL_COMPILE)
            
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
                    highlight = self.highlights[coord]
                except KeyError:
                    highlight = None
                
                if isBlack:
                    colour = BLACK_SQUARE_COLOURS[highlight]
                    self.whiteTexture.bind() #blackTexture
                else:
                    colour = WHITE_SQUARE_COLOURS[highlight]
                    self.whiteTexture.bind()

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
        
        if self.boardList is not None:
            glEndList()
            glCallList(self.boardList)
        
    def drawSquares(self):
        """Draw the board squares for picking"""
        
        # draw the floor squares
        for u in [0, 1, 2, 3, 4, 5, 6, 7]:
            glPushName(u)

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
            glPopName()
        
    def drawPieces(self):
        """Draw the pieces in the scene"""
        glEnable(GL_TEXTURE_2D)

        for piece in self.pieces:
            glPushMatrix()
            glTranslatef(piece.pos[0], piece.pos[1], piece.pos[2])

            # Draw the model
            piece.draw()

            glPopMatrix()
        
        glDisable(GL_TEXTURE_2D)

    def transformBoard(self):
        """Perform the board transform"""
        # Rotate the board
        glRotatef(self.boardAngle, 0.0, 1.0, 0.0)

        # Offset board so centre is (0.0,0.0)
        glTranslatef(-OFFSET, 0.0, OFFSET)
