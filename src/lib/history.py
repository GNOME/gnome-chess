__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import os
import errno

import chess.pgn
from defaults import *

class GameHistory:
    
    def getUnfinishedGame(self):
        g = None
        try:
            f = file(UNFINISHED_FILE, 'r')
            lines = f.readlines()
            f.close()

            lines.reverse()
            index = 0
            for line in lines:
                fname = line.strip()
                try:
                    p = chess.pgn.PGN(fname, 1)
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
                print 'Failed to read unfinished list'
                return None
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
            print 'Failed to read unfinished list'
            
        return g

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
        fname = os.path.join(directory, date)
        while os.path.exists(fname):
            count += 1
            fname = os.path.join(directory, '%s-%d' % (date, count))
        
        return fname
    
    def save(self, g):
        """Save a game in the history.
        
        'g' is the game to save
        """
        fname = self._getFilename(g)

        lines = g.getLines()
        try:
            f = file(fname, 'w')
            for line in lines:
                f.write(line + '\n')
            f.write('\n')
            f.close()
        except IOError, e:
            # FIXME: This should be in a dialog
            self.logger.addLine('Unable to autosave to %s: %s' % (fname, str(e)))
            
        # Update unfinished list
        result = g.getTag(chess.pgn.TAG_RESULT)
        try:
            f = file(UNFINISHED_FILE, 'r')
            lines = f.readlines()
            f.close()
            
            f = file(UNFINISHED_FILE, 'w')
            for line in lines:
                l = line.strip()
                if l == fname and result != chess.pgn.RESULT_INCOMPLETE:
                    continue
                f.write(l + '\n')
            if result == chess.pgn.RESULT_INCOMPLETE:
                f.write(fname + '\n')
            f.close()
        except IOError:
            print 'Failed to update unfinished list'
