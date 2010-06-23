# -*- coding: utf-8 -*-
from OpenGL.GL import *
from OpenGL.GLU import *
import gtk.gdk

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

        # OpenGL texture ID
        self.__texture = None

        try:
            self.image = gtk.gdk.pixbuf_new_from_file(fileName);
        except IOError, e:
            print 'Error loading texture file: %s: %s' % (fileName, e.strerror)
            self.image = None

    def __generate(self):
        """
        """
        if self.__texture is not None:
            return

        # Return null texture if failed to load data        
        if self.image is None:
            self.__texture = 0
            return
        
        # FIXME: Can fail
        texture = glGenTextures(1)
            
        glBindTexture(GL_TEXTURE_2D, texture)

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)

        format = {1: GL_LUMINANCE, 2: GL_LUMINANCE_ALPHA, 3: GL_RGB, 4: GL_RGBA}[self.image.get_n_channels()]
        data_type = {1: GL_BITMAP, 8: GL_UNSIGNED_BYTE, 16: GL_UNSIGNED_SHORT}[self.image.get_bits_per_sample()]

        # Generate mipmaps
        try:
            gluBuild2DMipmaps(GL_TEXTURE_2D,
                              GL_LUMINANCE,
                              self.image.get_width(),
                              self.image.get_height(),
                              format,
                              data_type,
                              self.image.get_pixels())
        except GLUerror, e:
            glTexImage2D(GL_TEXTURE_2D,
                         0, # Level
                         self.image.get_depth(),
                         self.image.get_width(),
                         self.image.get_height(),
                         0, # Border
                         data_type,
                         GL_UNSIGNED_BYTE,
                         self.image.get_pixels())

        del self.image
        self.__texture = texture

    def bind(self):
        """Bind this texture to the current surface.
        
        This requires an openGL context.
        """
        self.__generate()

        # Use texture
        glBindTexture(GL_TEXTURE_2D, self.__texture)
        
        # Use material properties
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, self.__ambient)
        glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, self.__diffuse)
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, self.__specular)
        glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, self.__emission)
        glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, self.__shininess)
