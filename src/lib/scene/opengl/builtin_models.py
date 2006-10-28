__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import math
from OpenGL.GL import *

import glchess.scene
import texture

from glchess.defaults import *

# HACK
import os.path
    
WHITE_BASE      = (0.95, 0.81, 0.64)
WHITE_AMBIENT   = (0.4*WHITE_BASE[0], 0.4*WHITE_BASE[1], 0.4*WHITE_BASE[2], 1.0)
WHITE_DIFFUSE   = (0.7*WHITE_BASE[0], 0.7*WHITE_BASE[1], 0.7*WHITE_BASE[2], 1.0)
WHITE_SPECULAR  = (1.0*WHITE_BASE[0], 1.0*WHITE_BASE[1], 1.0*WHITE_BASE[2], 1.0)
WHITE_SHININESS = 64.0

BLACK_BASE      = (0.62, 0.45, 0.28)
BLACK_AMBIENT   = (0.4*BLACK_BASE[0], 0.4*BLACK_BASE[1], 0.4*BLACK_BASE[2], 1.0)
BLACK_DIFFUSE   = (0.7*BLACK_BASE[0], 0.7*BLACK_BASE[1], 0.7*BLACK_BASE[2], 1.0)
BLACK_SPECULAR  = (1.0*BLACK_BASE[0], 1.0*BLACK_BASE[1], 1.0*BLACK_BASE[2], 1.0)
BLACK_SHININESS = 64.0

class BuiltinSet(glchess.scene.ChessSet):
    """
    """
    # The models
    __pawn   = None
    __rook   = None
    __knight = None
    __bishop = None
    __queen  = None
    __king   = None
    
    # A dictionary of models indexed by name
    __modelsByName = None
    
    # The rotation in degrees of pieces in the set (i.e. 0.0 for white and 180.0 for black)
    __rotation = 0.0
    
    __stateColours = None
    __defaultState = None
    
    # The display lists for each model
    __displayLists = None
    
    # The model texture
    __texture = None
    
    def __init__(self, textureFileName, ambient, diffuse, specular, shininess):
        self.__pawn = Pawn()
        self.__rook = Rook()
        self.__knight = Knight()
        self.__bishop = Bishop()
        self.__queen = Queen()
        self.__king = King()
        self.__modelsByName = {'pawn': self.__pawn,
                               'rook': self.__rook,
                               'knight': self.__knight,
                               'bishop': self.__bishop,
                               'queen': self.__queen,
                               'king': self.__king}
        self.__displayLists = {}
        self.__stateColours = {}
        self.__texture = texture.Texture(textureFileName, ambient = ambient, diffuse = diffuse,
                                         specular = specular, shininess = shininess)

    def setRotation(self, theta):
        """
        """
        self.__rotation = theta
        
    def addState(self, name, colour, default = False):
        """
        """
        self.__stateColours[name] = colour
        if default is True:
            self.__defaultState = colour

    def drawPiece(self, pieceName, state, context):
        """Draw a piece.
        
        'pieceName' is the piece name (string).
        'state' is the piece state (string).
        'context' is a reference to the openGL context being used (user-defined).
        
        If a context is provided then the models are rendered using display lists.
        """
        glRotatef(self.__rotation, 0.0, 1.0, 0.0)
        
        # Draw as white if textured
        if glGetBoolean(GL_TEXTURE_2D):
            glColor3f(1.0, 1.0, 1.0)
        else:
            try:
                colour = self.__stateColours[state]
            except KeyError:
                colour = self.__defaultState
            glColor3fv(colour)

        self.__texture.bind()
        
        # Render to a display list for optimisation
        # TODO: This lists should be able to be shared between colours and games
        try:
            list = self.__displayLists[pieceName]
        except KeyError:
            # Get model to render
            piece = self.__modelsByName[pieceName]
            
            # Attempt to make an optimised list, if none available just render normally
            list = self.__displayLists[pieceName] = glGenLists(1)
            if list == 0:
                piece.draw()
                return

            # Draw the model
            glNewList(list, GL_COMPILE)
            piece.draw()
            glEndList()

        # Draw pre-rendered model
        glCallList(list)
        
class WhiteBuiltinSet(BuiltinSet):
    """
    """
    
    def __init__(self):
        BuiltinSet.__init__(self, os.path.join(IMAGE_DIR, 'piece.png'), WHITE_AMBIENT, WHITE_DIFFUSE, WHITE_SPECULAR, WHITE_SHININESS)
        self.setRotation(180.0)
        self.addState('unselected', (0.9, 0.9, 0.9), default = True)

class BlackBuiltinSet(BuiltinSet):
    """
    """
    
    def __init__(self):
        BuiltinSet.__init__(self, os.path.join(IMAGE_DIR, 'piece.png'), BLACK_AMBIENT, BLACK_DIFFUSE, BLACK_SPECULAR, BLACK_SHININESS)
        self.addState('unselected', (0.2, 0.2, 0.2), default = True)

class SimpleModel:
    """
    """
    
    pos = None
    
    def start(self):
        pass
    
    def revolve(self, coords, divisions = 16, scale = 1.0, maxHeight = None):
        """
        """
        # Get the number of points

        # If less than two points, can not revolve
        if len(coords) < 2:
            raise TypeError() # FIXME

        # If the max_height hasn't been defined, find it
        if maxHeight is None:
            maxHeight = 0.0
            for coord in coords:
                if maxHeight < coord[1]:
                    maxHeight = coord[1]

        # Draw the revolution
        sin_ptheta = 0.0
        cos_ptheta = 1.0
        norm_ptheta = 0.0
        for division in range(1, divisions+1):
            theta = 2.0 * (float(division) * math.pi) / float(divisions)
            sin_theta = math.sin(theta)
            cos_theta = math.cos(theta)
            norm_theta = theta / (2.0 * math.pi)
            coord = coords[0]
            pradius = coord[0] * scale
            pheight = coord[1] * scale

            for coord in coords[1:]:
                radius = coord[0] * scale
                height = coord[1] * scale

                # Get the normalized lengths of the normal vector
                dradius = radius - pradius
                dheight = height - pheight
                length = math.sqrt(dradius * dradius + dheight * dheight)
                dradius /= length
                dheight /= length
                
                normal = (dheight, -dradius)
                
                # Rotate the normal
                n0 = (normal[0] * sin_ptheta, normal[1], normal[0] * cos_ptheta)
                n1 = (normal[0] * sin_theta, normal[1], normal[0] * cos_theta)
                
                #
                # |    |
                # |    |    _ height1
                # |    \
                # |     \
                # |      \  _ height0
                # |       |
                #
                #      |  |
                # 0    r1 r0
                
                #
                #   d +----------+ c - upper point
                #     |          |
                #     |          |
                #     |          |
                #     |          |
                #   a +----------+ b - lower point
                #
                #     |          |
                #  smaller     larger
                #   angle      angle
                a = (pradius * sin_ptheta, pheight, pradius * cos_ptheta)
                b = (pradius * sin_theta, pheight, pradius * cos_theta)
                c = (radius * sin_theta, height, radius * cos_theta)
                d = (radius * sin_ptheta, height, radius * cos_ptheta)
                
                # Texture co-ordinates (conical transformation)
                ta = self.__getTextureCoord(a, maxHeight)
                tb = self.__getTextureCoord(b, maxHeight)
                tc = self.__getTextureCoord(c, maxHeight)
                td = self.__getTextureCoord(d, maxHeight)

                # If only triangles required
                if c == d:
                    glBegin(GL_TRIANGLES)

                    glNormal3fv(n0)
                    glTexCoord2fv(ta)
                    glVertex3fv(a)

                    glNormal3fv(n1)
                    glTexCoord2fv(tb)
                    glVertex3fv(b)

                    # FIXME: should have an average normal
                    glTexCoord2fv(tc)
                    glVertex3fv(c)

                    glEnd()
                    
                if a == b:
                    glBegin(GL_TRIANGLES)

                    glNormal3fv(n0)
                    glTexCoord2fv(ta)
                    glVertex3fv(a)

                    glNormal3fv(n1)
                    glTexCoord2fv(tc)
                    glVertex3fv(c)

                    # FIXME: should have an average normal
                    glVertex3fv(td)
                    glVertex3fv(d)

                    glEnd()

                else:
                    # quads required
                    glBegin(GL_QUADS)
                    
                    glNormal3fv(n0)
                    glTexCoord2fv(ta)
                    glVertex3fv(a)
                    
                    glNormal3fv(n1)
                    glTexCoord2fv(tb)
                    glVertex3fv(b)

                    glNormal3fv(n1)
                    glTexCoord2fv(tc)
                    glVertex3fv(c)

                    glNormal3fv(n0)
                    glTexCoord2fv(td)
                    glVertex3fv(d)

                    glEnd()

                pradius = radius
                pheight = height
            
            sin_ptheta = sin_theta
            cos_ptheta = cos_theta
            norm_ptheta = norm_theta
    
    def __getTextureCoord(self, vertex, maxHeight):
        """
        """
        # FIXME: Change to a hemispherical projection so the top is not so flat
        
        # Conical transformation, get u and v based on vertex angle
        u = vertex[0]
        v = vertex[2]
        
        # Normalise 
        length = math.sqrt(u**2 + v**2)
        if length != 0.0:
            u /= length
            v /= length

        # Maximum height is in the middle of the texture, minimum on the boundary
        h = 1.0 - (vertex[1] / maxHeight)
        return (0.5 + 0.5 * h * u, 0.5 + 0.5 * h * v)
    
    def __drawVertex(self, vertex, maxHeight):
        glTexCoord2fv(self.__getTextureCoord(vertex, maxHeight))
        glVertex3fv(vertex)

    def drawTriangles(self, triangles, verticies, normals, maxHeight):
        """
        """
        glBegin(GL_TRIANGLES)
        for t in triangles:
            glNormal3fv(normals[t[0]])
            v = t[1]
            self.__drawVertex(verticies[v[0]], maxHeight)
            self.__drawVertex(verticies[v[1]], maxHeight)
            self.__drawVertex(verticies[v[2]], maxHeight)
        glEnd()
            
    def drawQuads(self, quads, verticies, normals, maxHeight):
        """
        """
        glBegin(GL_QUADS)
        for t in quads:
            glNormal3fv(normals[t[0]])
            v = t[1]
            self.__drawVertex(verticies[v[0]], maxHeight)
            self.__drawVertex(verticies[v[1]], maxHeight)
            self.__drawVertex(verticies[v[2]], maxHeight)
            self.__drawVertex(verticies[v[3]], maxHeight)
        glEnd()
    
    def end(self):
        pass
    
    def draw(self):
        """
        """
        pass
    
class Pawn(SimpleModel):
    """
    """
    
    # The co-ordinates of the revolution that makes the model
    __revolveCoords = [(3.5, 0.0), (3.5, 2.0), (2.5, 3.0), (2.5, 4.0), (1.5, 6.0), (1.0, 8.8),
                       (1.8, 8.8), (1.0, 9.2), (2.0, 11.6), (1.0, 13.4), (0.0, 13.4)]
                       
    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        pass

    def draw(self):
        self.revolve(self.__revolveCoords)
        
class Rook(SimpleModel):
    """
    """
    
    # The co-ordinates of the revolution that makes the model
    __revolveCoords = [(3.8, 0.0), (3.8, 2.0), (2.6, 5.0), (2.0, 10.2), (2.8, 10.2), (2.8, 13.6), (2.2, 13.6), (2.2, 13.0), (0.0, 13.0)]
                       
    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        pass

    def draw(self):
        self.revolve(self.__revolveCoords)
        
class Knight(SimpleModel):
    """
    """
    
    __maxHeight = 0.0
    
    # The co-ordinates of the revolution that makes the model
    __revolveCoords = [(4.1, 0.0), (4.1, 2.0), (2.0, 3.6), (2.0, 4.8), (2.6, 5.8)]
    
    # The other polygons
    __verticies = [(2.6, 5.8, 2.6), (-2.6, 5.8, 2.6), (-2.6, 5.8, -0.8), (2.6, 5.8, -0.8),
                   (0.8, 16.2, 4.0), (1.0, 16.8, 3.4), (-1.0, 16.8, 3.4), (-0.80, 16.2, 4.0),
                   (1.0, 16.8, 3.0), (-1.0, 16.8, 3.0), (0.5, 16.8, 1.6), (-0.5, 16.8, 1.6),
                   (1.0, 16.8, 0.20), (-1.0, 16.8, 0.20), (1.0, 16.8, -0.20), (-1.0, 16.8, -0.20),
                   (0.4, 16.8, -1.1), (-0.4, 16.8, -1.1), (1.0, 16.8, -2.0), (-1.0, 16.8, -2.0),
                   (1.0, 16.8, -4.4), (-1.0, 16.8, -4.4), (1.0, 15.0, -4.4), (-1.0, 15.0, -4.4),
                   (0.55, 14.8, -2.8), (-0.55, 14.8, -2.8), (-1.0, 14.0, 1.3), (-1.2, 13.8, 2.4),
                   (-0.8, 16.8, 0.20), (-1.2, 13.8, 0.20), (-0.82666667, 16.6, 0.20), (-1.0, 16.6, -0.38),
                   (-0.88, 16.2, 0.20), (-1.0, 16.2, -0.74), (-1.2, 13.6, -0.20), (-1.0, 15.8, -1.1),
                   (-0.6, 14.0, -1.4), (1.2, 13.8, 2.4), (1.0, 14.0, 1.3), (1.2, 13.8, 0.20),
                   (0.8, 16.8, 0.20), (0.82666667, 16.6, 0.20), (1.0, 16.6, -0.38), (1.2, 13.6, -0.20),
                   (1.0, 16.2, -0.74), (0.88, 16.2, 0.20), (0.6, 14.0, -1.4), (1.0, 15.8, -1.1),
                   (0.8, 16.4, -0.56), (0.61333334, 16.4, 0.20), (-0.61333334, 16.4, 0.20), (-0.8, 16.4, -0.56),
                   (0.35, 17.8, -0.8), (0.35, 17.8, -4.4), (-0.35, 17.8, -4.4), (-0.35, 17.8, -0.8),
                   (0.35, 16.8, -0.8), (0.35, 16.8, -4.4), (-0.35, 16.8, -4.4), (-0.35, 16.8, -0.8),
                   (0.0, 15.0, -3.6), (0.0, 7.8, -4.0), (-0.5, 13.8, 0.4), (-2.0, 8.8, 4.0),
                   (2.0, 8.8, 4.0), (0.5, 13.8, 0.4), (-1.4, 12.2, -0.4), (-1.1422222222, 12.2, -2.2222222222),
                   (1.4, 12.2, -0.4), (1.1422222222, 12.2, -2.2222222222), (1.44, 5.8, -2.6), (-1.44, 5.8, -2.6),
                   (0.0, 14.0, 4.0), (-0.45, 13.8, -0.20), (0.45, 13.8, -0.20)]
    __normals = [(0.0, -1.0, 0.0), (0.0, 0.707107, 0.707107), (0.0, 1.0, 0.0), (0.0, 0.0, -1.0),
                 (-0.933878, 0.128964, -0.333528), (-0.966676, 0.150427, 0.207145), (-0.934057, 0.124541, -0.334704), (-0.970801, -0.191698, -0.144213),
                 (-0.97561, 0.219512, 0.0), (0.933878, 0.128964, -0.333528), (0.966676, 0.150427, 0.207145), (0.934057, 0.124541, -0.334704),
                 (0.970801, -0.191698, -0.144213), (0.97561, -0.219512, 0.0), (0.598246, 0.797665, 0.076372), (0.670088, -0.714758, 0.200256),
                 (-0.598246, 0.797665, 0.076372), (-0.670088, -0.714758, 0.200256), (1.0, 0.0, 0.0), (-1.0, 0.0, 0.0),
                 (0.0, 0.0, 1.0), (0.0, -0.853282, 0.52145), (0.0, -0.98387, -0.178885), (-0.788443, 0.043237, -0.613587),
                 (0.788443, 0.043237, -0.613587), (0.0, 0.584305, 0.811534), (0.0, -0.422886, 0.906183), (-0.969286, 0.231975, -0.081681),
                 (-0.982872, 0.184289, 0.0), (0.969286, 0.231975, -0.081681), (0.982872, 0.184289, 0.0), (0.81989, -0.220458, -0.528373),
                 (0.0, -0.573462, -0.819232), (-0.819890, -0.220459, -0.528373), (-0.752714, -0.273714, 0.59875), (-0.957338, 0.031911, 0.287202),
                 (-0.997785, 0.066519, 0.0), (0.752714, -0.273714, 0.59875), (0.957338, 0.031911, 0.287202), (0.997785, 0.066519, 0.0),
                 (0.0, -0.992278, 0.124035), (-0.854714, 0.484047, 0.187514), (-0.853747, 0.515805, -0.0711460), (0.854714, 0.484047, 0.187514),
                 (0.853747, 0.515805, -0.0711460), (0.252982, -0.948683, -0.189737), (0.257603, -0.966012, 0.021467), (0.126745, -0.887214, 0.443607),
                 (-0.252982, -0.948683, -0.189737), (-0.257603, -0.966012, 0.021467), (-0.126745, -0.887214, 0.443607), (0.000003, -0.668965, 0.743294),
                 (-0.000003, -0.668965, 0.743294), (-0.997484, 0.070735, 0.004796), (-0.744437, 0.446663, -0.496292), (0.997484, 0.070735, 0.004796),
                 (0.744437, 0.446663, -0.496292)]
    __triangles = ((31, (3, 70, 61)), (32, (70, 71, 61)), (33, (2, 61, 71)), (20, (72, 4, 7)),
                   (34, (72, 7, 27)), (35, (27, 7, 6)), (36, (27, 6, 9)), (37, (72, 37, 4)),
                   (38, (37, 5, 4)), (39, (37, 8, 5)), (40, (72, 27, 37)), (41, (36, 66, 73)),
                   (42, (73, 66, 62)), (43, (46, 74, 68)), (44, (74, 65, 68)), (45, (46, 43, 74)),
                   (46, (65, 74, 43)), (47, (65, 43, 39)), (48, (36, 73, 34)), (49, (62, 34, 73)),
                   (50, (62, 29, 34)), (3, (45, 49, 41)), (51, (44, 42, 48)), (3, (32, 30, 50)),
                   (52, (33, 51, 31)), (53, (17, 19, 35)), (54, (15, 17, 35)), (55, (16, 47, 18)),
                   (56, (14, 47, 16)))
    __quads = ((0, (0, 1, 2, 3)), (1, (4, 5, 6, 7)), (2, (5, 8, 9, 6)), (2, (8, 10, 11, 9)),
               (2, (10, 12, 13, 11)), (2, (12, 14, 15, 13)), (2, (14, 16, 17, 15)), (2, (16, 18, 19, 17)),
               (2, (18, 20, 21, 19)), (3, (21, 20, 22, 23)), (3, (23, 22, 24, 25)), (4, (9, 11, 26, 27)),
               (5, (11, 28, 29, 26)), (6, (30, 28, 15, 31)), (6, (29, 32, 33, 34)), (6, (34, 33, 35, 36)),
               (7, (19, 25, 36, 35)), (8, (19, 21, 23, 25)), (9, (8, 37, 38, 10)), (10, (10, 38, 39, 40)),
               (11, (41, 42, 14, 40)), (11, (39, 43, 44, 45)), (11, (43, 46, 47, 44)), (12, (18, 47, 46, 24)),
               (13, (18, 24, 22, 20)), (14, (45, 44, 48, 49)), (15, (49, 48, 42, 41)), (16, (32, 50, 51, 33)),
               (17, (50, 30, 31, 51)), (2, (52, 53, 54, 55)), (18, (52, 56, 57, 53)), (19, (55, 54, 58, 59)),
               (20, (52, 55, 59, 56)), (3, (53, 57, 58, 54)), (21, (26, 29, 39, 38)), (22, (26, 38, 37, 27)),
               (23, (2, 25, 60, 61)), (24, (3, 61, 60, 24)), (25, (62, 63, 64, 65)), (26, (63, 1, 0, 64)),
               (27, (62, 66, 1, 63)), (28, (66, 67, 2, 1)), (28, (25, 67, 66, 36)), (29, (65, 64, 0, 68)),
               (30, (68, 0, 3, 69)), (30, (24, 46, 68, 69)))

    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        self.__maxHeight = 0.0
        for v in self.__verticies:
            if v[1] > self.__maxHeight:
                self.__maxHeight = v[1]

    def draw(self):
        self.revolve(self.__revolveCoords, maxHeight = self.__maxHeight)
        self.drawTriangles(self.__triangles, self.__verticies, self.__normals, self.__maxHeight)
        self.drawQuads(self.__quads, self.__verticies, self.__normals, self.__maxHeight)

class Bishop(SimpleModel):
    """
    """
    
    # The co-ordinates of the revolution that makes the model
    
    __revolveCoords = [(4.0, 0.0), (4.0, 2.0), (2.5, 3.0), (2.5, 4.0), (1.5, 7.0), (1.2, 9.4), (2.5, 9.4), (1.7, 11.0), 
                       (1.7, 12.2), (2.2, 13.2), (2.2, 14.8), (1.0, 16.0), (0.8, 17.0), (1.2, 17.7), (0.8, 18.4), (0.0, 18.4)]

    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        pass

    def draw(self):
        self.revolve(self.__revolveCoords)

class Queen(SimpleModel):
    """
    """
    
    # The co-ordinates of the revolution that makes the model
    
    __revolveCoords = [(4.8, 0.0), (4.8, 2.2), (3.4, 4.0), (3.4, 5.0), (1.8, 8.0), (1.4, 11.8), (2.9, 11.8),
                       (1.8, 13.6), (1.8, 15.2), (2.0, 17.8), (2.7, 19.2), (2.4, 20.0), (1.7, 20.0),
                       (0.95, 20.8), (0.7, 20.8), (0.9, 21.4), (0.7, 22.0), (0.0, 22.0)]
                       
    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        pass

    def draw(self):
        self.revolve(self.__revolveCoords)

class King(SimpleModel):
    """
    """
    
    __maxHeight = 0.0
    
    # The co-ordinates of the revolution that makes the model
    
    __revolveCoords = [(5.0, 0.0), (5.0, 2.0), (3.5, 3.0), (3.5, 4.6), (2.0, 7.6), (1.4, 12.6), (3.0, 12.6),
                       (2.0, 14.6), (2.0, 15.6), (2.8, 19.1), (1.6, 19.7), (1.6, 20.1), (0.0, 20.1)]
                       
    __verticies = [(-0.3, 20.1, 0.351), (0.3, 20.1, 0.35), (0.3, 23.1, 0.35), (-0.3, 23.1, 0.35),
                   (-0.9, 21.1, 0.35), (-0.3, 21.1, 0.35), (-0.3, 22.1, 0.35), (-0.9, 22.1, 0.35),
                   (0.9, 21.1, 0.35), (0.9, 22.1, 0.35), (0.3, 22.1, 0.35), (0.3, 21.1, 0.35),
                   (0.3, 20.1, -0.35), (-0.3, 20.1, -0.35), (-0.3, 23.1, -0.35), (0.3, 23.1, -0.35),
                   (-0.3, 21.1, -0.35), (-0.9, 21.1, -0.35), (-0.9, 22.1, -0.35), (-0.3, 22.1, -0.35),
                   (0.3, 21.1, -0.35), (0.3, 22.1, -0.35), (0.9, 22.1, -0.35), (0.9, 21.1, -0.35),
                   (-0.3, 20.1, 0.35), (-0.3, 22.1, 0.3), (-0.3, 23.1, 0.3), (-0.3, 23.1, -0.3),
                   (-0.3, 22.1, -0.3)]
    __normals = [(0.0, 0.0, 1.0), (0.0, 0.0, -1.0), (-1.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)]
    __quads = [(0, (0, 1, 2, 3)), (0, (4, 5, 6, 7)), (0, (8, 9, 10, 11)), (1, (12, 13, 14, 15)),
               (1, (16, 17, 18, 19)), (1, (20, 21, 22, 23)), (2, (4, 7, 18, 17)), (2, (24, 5, 16, 13)),
               (2, (25, 26, 27, 28)), (3, (23, 22, 9, 8)), (3, (12, 20, 11, 1)), (3, (21, 15, 2, 10)),
               (4, (18, 7, 6, 19)), (4, (21, 10, 9, 22)), (4, (14, 3, 2, 15))]

    def __init__(self):
        self.pos = (0.0, 0.0, 0.0)
        self.__maxHeight = 0.0
        for v in self.__verticies:
            if v[1] > self.__maxHeight:
                self.__maxHeight = v[1]

    def draw(self):
        self.revolve(self.__revolveCoords, maxHeight = self.__maxHeight)
        self.drawQuads(self.__quads, self.__verticies, self.__normals, self.__maxHeight)
