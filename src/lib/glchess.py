import sys

# Ignore any exceptions writing to stdout using print statements
class SafeStdout:
    def __init__(self):
        self.stdout = sys.stdout
    
    def fileno(self):
        return self.stdout.fileno()

    def write(self, data):
        try:
            self.stdout.write(data)
        except:
            pass

sys.stdout = SafeStdout()

import main
def start_game ():
    app = main.Application()
    app.start()
