public class ChessEngineUCI : ChessEngine
{
    private char[] buffer;
    private string position_command;
    
    public ChessEngineUCI ()
    {
        buffer = new char[0];
        position_command = "position startpos";
        starting.connect (start_cb);
    }

    private void start_cb ()
    {
        write_line ("uci");
    }

    public override void start_game ()
    {
        write_line ("ucinewgame");
    }

    public override void request_move ()
    {
        write_line ("go wtime 30000 btime 30000");
    }

    public override void report_move (ChessMove move)
    {
        if (position_command == "position startpos")
            position_command += " moves";
        position_command += " " + move.lan;
        write_line (position_command);
    }

    public override void process_input (char[] data)
    {
        /* Copy new data */
        int current = buffer.length;
        buffer.resize ((int) (buffer.length + data.length));
        for (int i = 0; i < data.length; i++)
            buffer[current + i] = data[i];

        /* Parse lines */
        while (true)
        {
            int offset;

            for (offset = 0; offset < buffer.length && buffer[offset] != '\n'; offset++);
            if (offset >= buffer.length)
                return;

            buffer[offset] = '\0';
            string line = (string) buffer;

            debug ("Read from engine: '%s'", line);
            
            string[] tokens = line.split (" ");
            if (tokens.length > 0)
            {
                switch (tokens[0])
                {
                case "id":
                    break;

                case "uciok":
                    if (tokens.length != 1)
                        warning ("Unexpected arguments on uciok: %s", line);
                        
                    configure ();
                    break;

                case "readyok":
                    if (tokens.length != 1)
                        warning ("Unexpected arguments on readyok: %s", line);

                    ready = true;
                    break;

                case "bestmove":
                    if (tokens.length < 2)
                        warning ("No move with bestmove: %s", line);
                    debug ("Engine moves %s", tokens[1]);
                    moved (tokens[1]);
                    break;

                case "info":
                    break;

                case "option":
                    break;

                default:
                    warning ("Unknown command: '%s'", line);
                    break;
                }
            }

            buffer = buffer[offset+1:buffer.length];
        }
    }

    private void configure ()
    {
        //write_line ("setoption ...");
        write_line ("isready");
    }
}
