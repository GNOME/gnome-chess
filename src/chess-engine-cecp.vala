/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class ChessEngineCECP : ChessEngine
{
    private char[] buffer;
    private bool moving = false;
    private string[] options;

    public ChessEngineCECP (string binary, string[] args, string[] options)
    {
        base (binary, args);
        this.options = options;
        starting.connect (start_cb);
    }
    
    private void start_cb ()
    {
        write_line ("xboard");
        write_line ("random");
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

            string[] move_prefixes = { "My move is: ", "My move is : ", "my move is ", "move " };
            foreach (string prefix in move_prefixes)
            {
                if (line.has_prefix (prefix))
                {
                    string move = line[prefix.length:line.length];
                    debug ("Engine moves %s", move);
                    moving = true;
                    moved (move.strip());
                }
            }

            if (line == "resign" || line == "tellics resign" ||
                     (line.has_prefix ("1-0 {") && line.contains("resign")) ||
                     (line.has_prefix ("0-1 {") && line.contains("resign")))
            {
                resigned ();
            }
            else if (line.has_prefix ("Illegal move: "))
            {
                stop ();
                error ();
            }
            else if (line.has_prefix ("1-0") || line.has_prefix ("0-1"))
            {
                /* The engine thinks the game is over and will not play on. */
                stop ();
            }
            else if (line == "game is a draw" ||
                     line == "draw" ||
                     line == "Draw" ||
                     line.has_prefix ("1/2-1/2"))
            {
                claim_draw ();
            }
            else if (line == "offer draw")
            {
                offer_draw ();
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
            write_line (move.get_engine ());
        }
        moving = false;
    }

    public override void undo ()
    {
        /*
         * We're undoing only the most recent move here, so there's no need to
         * call Undo twice, or to use fanciness like the remove command. This
         * function will be called twice if we need to undo two moves in a row.
         *
         * force is not necessary for GNUChess or Phalanx, but it's required by
         * CECP and most other engines will move again immediately without it
         * (leading to an apparent AI hang).
         */
        write_line ("force");
        write_line ("undo");
    }
}
