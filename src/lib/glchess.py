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

def start_game ():
    import main
    app = main.Application()
    app.start()
