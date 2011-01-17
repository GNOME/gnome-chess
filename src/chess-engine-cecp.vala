public class ChessEngineCECP : ChessEngine
{
    private char[] buffer;
    private bool moving = false;
    private string[] options;

    public ChessEngineCECP (string[] options)
    {
        this.options = options;
        starting.connect (start_cb);
    }
    
    private void start_cb ()
    {
        write_line ("xboard");
        foreach (var o in options)
            write_line (o);
        ready = true;
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

            string[] move_prefixes = { "My move is: ", "my move is ", "move " };
            foreach (string prefix in move_prefixes)
            {
                if (line.has_prefix (prefix))
                {
                    string move = line[prefix.length:line.length];
                    debug ("Engine moves %s", move);
                    moving = true;
                    moved (move);
                }
            }

            if (line.has_prefix ("Illegal move: "))
            {
            }
            else if (line == "resign" || line == "tellics resign")
            {
            }
            else if (line == "offer draw")
            {
            }

            buffer = buffer[offset+1:buffer.length];
        }
    }

    public override void start_game ()
    {
    }

    public override void request_move ()
    {
        write_line ("go");
    }

    public override void report_move (ChessMove move)
    {
        /* Don't repeat the engines move back to it */
        if (!moving)
        {
            /* Stop the AI from automatically moving in response to this one */
            write_line ("force");
            write_line (move.engine);
        }
        moving = false;
    }
}
