try:
    import OpenGL.GL
except ImportError:
    import glchess.scene
    
    class Piece(glchess.scene.ChessPiece):
        pass
    
    class Scene(glchess.scene.Scene):
        
        def __init__(self):
            pass
        
        def addChessPiece(self, chessSet, name, coord):
            return Piece()
else:
    from opengl import *
