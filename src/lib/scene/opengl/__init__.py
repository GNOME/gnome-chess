# -*- coding: utf-8 -*-
try:
    import OpenGL.GL
    import OpenGL.GLU    
except ImportError:
    import glchess.scene
    
    class Piece(glchess.scene.ChessPiece):
        pass
    
    class Scene(glchess.scene.Scene):
        
        def __init__(self, feedback):
            pass
        
        def addChessPiece(self, chessSet, name, coord, feedback):
            return Piece()
else:
    # PyOpenGL 3.0 renamed GLError -> GLerror, support 2.0
    if not hasattr(OpenGL.GL, 'GLerror'):
        OpenGL.GL.GLerror = OpenGL.GLError
    if not hasattr(OpenGL.GLU, 'GLUerror'):
        OpenGL.GLU.GLUerror = OpenGL.GLU.GLUError        

    from opengl import *
