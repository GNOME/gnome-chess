__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
import errno

import chess.pgn
from defaults import *

class GameHistory:
    
    def __init__(self):
        try:
            os.makedirs(HISTORY_DIR)
        except OSError, e:
            if e.errno != errno.EEXIST:
                print 'Failed to make history directory: %s' % e.strerror
    
    def getUnfinishedGame(self):
        """Get the last game that is unfinished.
        
        Returns the (PGN game, fileName) or (None, None) if no unfinished games.
        """
        g = None
        fileName = None
        try:
            f = file(UNFINISHED_FILE, 'r')
            lines = f.readlines()
            f.close()

            lines.reverse()
            index = 0
            for line in lines:
                fileName = line.strip()
                try:
                    p = chess.pgn.PGN(fileName, 1)
                except chess.pgn.Error, e:
                    print e.description
                    continue
                except IOError, e:
                    print e.strerror
                    continue
                else:
                    g = p[0]
                    break
                index += 1
        except IOError, e:
            if e.errno != errno.ENOENT:
                print e.errno
                print 'Failed to read unfinished list'
                return (None, None)
            lines = []
        else:
            lines = lines[index:]

        # Write the list back
        try:
            f = file(UNFINISHED_FILE, 'w')
            lines.reverse()
            f.writelines(lines)
            f.close()
        except IOError:
            print 'Failed to write unfinished list'

        return (g, fileName)

    def load(self, date):
        return
    
    def _getFilename(self, game):
        date = game.getTag(chess.pgn.TAG_DATE)
        try:
            (year, month, day) = date.split('.')
        except ValueError:
            directory = HISTORY_DIR
        else:
            directory = os.path.join(HISTORY_DIR, year, month, day)

        # Create the directory
        try:
            os.makedirs(directory)
        except OSError, e:
            if e.errno != errno.EEXIST:
                return None # FIXME

        # Get a unique name for the file
        count = 0
        fileName = os.path.join(directory, date)
        while os.path.exists(fileName):
            count += 1
            fileName = os.path.join(directory, '%s-%d' % (date, count))
        
        return fileName
    
    def save(self, g, fileName):
        """Save a game in the history.
        
        'g' is the game to save
        'fileName' is the history file to write to or None to create a new one
        """
        if fileName is None:
            fileName = self._getFilename(g)

        lines = g.getLines()
        try:
            f = file(fileName, 'w')
            for line in lines:
                f.write(line + '\n')
            f.write('\n')
            f.close()
        except IOError, e:
            # FIXME: This should be in a dialog
            print 'Unable to autosave to %s: %s' % (fileName, str(e))
            
        # Update unfinished list
        result = g.getTag(chess.pgn.TAG_RESULT)
        try:
            f = file(UNFINISHED_FILE, 'r')
            lines = f.readlines()
            f.close()
            
            f = file(UNFINISHED_FILE, 'w')
            for line in lines:
                l = line.strip()
                if l == fileName and result != chess.pgn.RESULT_INCOMPLETE:
                    continue
                f.write(l + '\n')
            if result == chess.pgn.RESULT_INCOMPLETE:
                f.write(fileName + '\n')
            f.close()
        except IOError:
            print 'Failed to update unfinished list'
