# -*- coding: utf-8 -*-
__author__ = 'Robert Ancell <bob27@users.sourceforge.net>'
__license__ = 'GNU General Public License Version 2'
__copyright__ = 'Copyright 2005-2006  Robert Ancell'

import gtk
import pango

import gtkui
import glchess.ui

class LogWindow:
    """
    """
    
    notebook    = None
    defaultPage = None
    
    # We keep track of the number of pages as there is a bug 
    # in GtkNotebook (Gnome bug #331785).
    pageCount   = 0
    
    def __init__(self, notebook):
        """
        """
        self.notebook = notebook
        self.defaultPage = notebook.get_nth_page(0)
    
    def addView(self, title, executable, description):
        """
        """
        # Hide the default page
        self.defaultPage.hide()
        self.notebook.set_show_tabs(True)
        
        self.pageCount += 1
        return LogView(self, title, executable, description)

class LogView(glchess.ui.Log):
    """
    """
    
    __gui = None
    
    def __init__(self, window, title, executable, description):
        """
        """
        self.window = window
        self.__gui = gtkui.loadGladeFile('log.glade', 'log_table')
        self.__gui.get_widget('executable_label').set_text(executable)
        self.__gui.get_widget('game_label').set_text(description)

        # Add into the notebook
        self.root = self.__gui.get_widget('log_table')
        notebook = window.notebook
        notebook.append_page(self.root, gtk.Label(title))
                
        # Create styles for the buffer
        buffer = self.__gui.get_widget('comms_textview').get_buffer()
        buffer.create_tag('input', family='Monospace')
        buffer.create_tag('output', family='Monospace', weight = pango.WEIGHT_BOLD)
        buffer.create_tag('move', family='Monospace', foreground = 'blue')
        buffer.create_tag('info', family='Monospace', foreground = 'green')
        buffer.create_tag('error', family='Monospace', foreground = 'red')
        buffer.create_mark('end', buffer.get_end_iter())
        
    def addBinary(self, data, style = None):
        text = ''
        while len(data) > 0:
            bin = ''
            ascii = ''
            for i in xrange(8):
                try:
                    c = data[i]
                except IndexError:
                    bin   += '   '
                    ascii += ' '
                else:
                    o = ord(c)
                    bin += '%02X ' % o
                    if o >= 0x20 and o & 0x80 == 0:
                        ascii += c
                    else:
                        ascii += '.'
                if i == 3:
                    bin += ' '
                    ascii += ' '
            data = data[8:]
            text += '%s %s\n' % (bin, ascii)
        self.addText(text, style)

    def addText(self, text, style = None):
        """FIXME: Define style
        """
        view = self.__gui.get_widget('comms_textview')
        scroll = self.__gui.get_widget('comms_scrolled_window')
        buffer = view.get_buffer()
        mark = buffer.get_mark('end')
        adj = scroll.get_vadjustment()
        atBottom = adj.value >= adj.upper - adj.page_size
        if style is None:
            buffer.insert(buffer.get_iter_at_mark(mark), text)
        else:
            buffer.insert_with_tags_by_name(buffer.get_iter_at_mark(mark), text, style)
        if atBottom:
            view.scroll_mark_onscreen(mark)
            
    def addLine(self, text, style = None):
        self.addText('\n' + text, style)
        
    def close(self):
        """
        """
        self.window.pageCount -= 1
        self.window.notebook.remove_page(self.window.notebook.page_num(self.root))
        
        # Show the default page
        if self.window.pageCount == 0:
            self.window.defaultPage.show()
            self.window.notebook.set_show_tabs(False)
