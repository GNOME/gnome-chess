"""
"""

__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import glchess.scene

class SceneHumanInput:
    """
    """
    # Flag to control if human input is enabled
    __inputEnabled = True

    # The selected square to move from
    __startSquare = None
    
    __showHints       = True
    
    def __init__(self):
        """Constructor for a scene with human selectable components"""
        pass
    
    # Methods to extend
    
    def onRedraw(self):
        """This method is called when the scene needs redrawing"""
        pass
        
    def playerIsHuman(self):
        """Check if the current player is a human.
        
        Return True the current player is human else False.
        """
        return False
    
    def getSquare(self, x, y):
        """Find the chess square at a given 2D location.
        
        'x' is the number of pixels from the left of the scene to select.
        'y' is the number of pixels from the bottom of the scene to select.
        
        Return the co-ordinate as a tuple in the form (file,rank) or None if
        no square at this point.
        """
        pass

    def squareIsFriendly(self, coord):
        """Check if a given square contains a friendly piece.
        
        Return True if this square contains a friendly piece.
        """
        return False
    
    def canMove(self, start, end):
        """Check if a move is valid.
        
        'start' is the location to move from in LAN format (string).
        'end' is the location to move from in LAN format (string).
        """
        return False
    
    def moveHuman(self, start, end):
        """Called when a human player moves.
        
        'start' is the location to move from in LAN format (string).
        'end' is the location to move from in LAN format (string).
        """
        pass
    
    # Public methods
    
    def enableHumanInput(self, inputEnabled):
        """Enable/disable human input.
        
        'inputEnabled' is a flag to show if human input is enabled (True) or disabled (False).
        """
        if inputEnabled is False:
            self.__selectSquare(None)
        self.__inputEnabled = inputEnabled
        self.updateHighlight(None)
        
    def showMoveHints(self, showHints):
        """
        """
        pass # FIXME

    def select(self, x, y):
        """
        """
        if self.__inputEnabled is False:
            return
        
        # Only bother if the current player is human
        if self.playerIsHuman() is False:
            return
        
        # Get the selected square
        coord = self.getSquare(x, y)
        if coord is None:
            return
        
        # Deselect when clicking on piece a second time
        if self.__startSquare == coord:
            self.__selectSquare(None)
            return

        # If this is a friendly piece then select it
        if self.squareIsFriendly(coord):
            self.__selectSquare(coord)

        else:
            # If we have already selected a start move try
            # and move to this square
            if self.__startSquare is not None:
                self.__move(self.__startSquare, coord)

        # Redraw the scene
        self.onRedraw()
        
        return coord

    def deselect(self, x, y):
        """
        """
        if self.__inputEnabled is False:
            return
        
        # Only bother if the current player is human
        if self.playerIsHuman() is False:
            return
        
        # Get the selected square
        coord = self.getSquare(x, y)
        if coord is None:
            return
        
        # Attempt to move here
        if self.__startSquare is not None and self.__startSquare != coord:
            self.__move(self.__startSquare, coord)
        
        # Redraw the scene
        self.onRedraw()
        
        return coord
    
    # Private methods
    
    def __selectSquare(self, coord):
        if self.__startSquare == coord:
            return
        self.__startSquare = coord
        self.updateHighlight(coord)
    
    def __move(self, start, end):
        """Attempt to make a move.
        
        ...
        """
        if self.canMove(start, end) is False:
            return
        self.__selectSquare(None)
        self.moveHuman(start, end)
