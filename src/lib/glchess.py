import sys

# Ignore any exceptions writing to stdout using print statements
class SafeStdout:
    def fileno(self):
        global stdout
        return stdout.fileno()

    def write(self, data):
        global stdout
        try:
            stdout.write(data)
        except:
            pass

stdout = sys.stdout
sys.stdout = SafeStdout()

def start_game ():
	import main
	app = main.Application()
	app.start()
