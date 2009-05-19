# -*- coding: utf-8 -*-
from OpenGL.GL import *
from OpenGL.GLU import *
import png
import array

class Texture:
    """
    """
    
    def __init__(self, fileName,
                 ambient  = (0.2, 0.2, 0.2, 1.0),
                 diffuse  = (0.8, 0.8, 0.8, 1.0),
                 specular = (0.0, 0.0, 0.0, 1.0),
                 emission = (0.0, 0.0, 0.0, 1.0),
                 shininess = 0.0):
        """Constructor for an openGL texture.
        
        'fileName' is the name of the image file to use for the texture (string).
        
        An IOError is raised if the file does not exist.
        This does not need an openGL context.
        """
        self.__ambient = ambient
        self.__diffuse = diffuse
        self.__specular = specular
        self.__emission = emission
        self.__shininess = shininess

        # Texture data
        self.__data   = None
        self.__format = GL_RGB
        self.__width  = None
        self.__height = None

        # OpenGL texture ID
        self.__texture = None

        try:
            self.__loadPIL(fileName)
        except ImportError:
            self.__loadPNG(fileName)

    def __loadPNG(self, fileName):
        """
        """
        try:
            reader = png.Reader(fileName)
        except IOError, e:
            print 'Error loading texture file: %s: %s' % (fileName, e.strerror)
            self.__data = None
            return

        try:
            (width, height, data, metaData) = reader.read()
        except png.Error, e:
            print 'Error parsing PNG file %s: %s' % (fileName, e.message)
            self.__data = None
            return
        
        self.__width = width
        self.__height = height
        self.__data = array.array('B', data).tostring()

        if metaData['has_alpha']:
            self.__format = GL_RGBA
        else:
            self.__format = GL_RGB

    def __loadPIL(self, fileName):
        """
        """
        import Image
        
        # Load the image file
        try:
            image = Image.open(fileName)
        except IOError, e:
            print 'Error loading texture file: %s: %s' % (fileName, e.strerror)
            self.__data = None
            return            

        # Crop the image so it has height/width a multiple of 2
        width = image.size[0]
        height = image.size[1]
        w = 1
        while 2*w <= width:
            w *= 2
        h = 1
        while 2*h <= height:
            h *= 2
        (self.__width, self.__height) = (w, h)
        image = image.crop((0, 0, w, h))

        # Convert to a format that OpenGL can access
        self.__data = image.tostring('raw', 'RGB', 0, -1)
        self.__format = GL_RGB

    def __generate(self):
        """
        """
        # Return null texture if failed to load data
        if self.__data is None:
            return 0
        
        # FIXME: Can fail
        texture = glGenTextures(1)
            
        glBindTexture(GL_TEXTURE_2D, texture)

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)

        # Generate mipmaps
        try:
            gluBuild2DMipmaps(GL_TEXTURE_2D, GL_LUMINANCE, self.__width, self.__height, self.__format, GL_UNSIGNED_BYTE, self.__data)
        except GLUerror, e:
            glTexImage2D(GL_TEXTURE_2D,
                         0,                # Level
                         3,                # Depth
                         self.__width,     # Width
                         self.__height,    # Height
                         0,                # Border
                         self.__format,    # Format
                         GL_UNSIGNED_BYTE, # Type
                         self.__data)
        
        return texture
    
    def bind(self):
        """Bind this texture to the current surface.
        
        This requires an openGL context.
        """
        if self.__texture is None:
            self.__texture = self.__generate()
            self.__data = None

        # Use texture
        glBindTexture(GL_TEXTURE_2D, self.__texture)
        
        # Use material properties
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, self.__ambient)
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, self.__diffuse)
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, self.__specular)
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, self.__emission)
        glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, self.__shininess)
