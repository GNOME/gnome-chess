/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2014 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class ChessEngineUCI : ChessEngine
{
    private char[] buffer;
    private string moves;
    private string[] options;
    private string go_options;
    private bool waiting_for_move;

    public ChessEngineUCI (string binary, string[] args, uint delay_seconds, string[] options, string[] go_options)
    {
        base (binary, args, delay_seconds);
        this.options = options;
        this.go_options = string.joinv (" ", go_options);
        buffer = new char[0];
        moves = "";
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
        if (moves != "")
            write_line ("position startpos moves" + moves);
        else
            write_line ("position startpos");
        waiting_for_move = true;
        write_line ("go wtime 30000 btime 30000 %s".printf (go_options));
    }

    public override void report_move (ChessMove move)
    {
        moves += " " + move.get_engine ();
    }

    public override void do_undo ()
    {
        if (waiting_for_move)
            write_line ("stop");
        waiting_for_move = false;
        moves = moves.slice (0, moves.last_index_of (" "));
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

                    /*
                     * GNU Chess likes to report a move after receiving a stop command,
                     * and the UCI spec does not seem to prohibit this, so just discard
                     * the move if we were not expecting it. This commonly occurs when
                     * the game is over, or after performing undo.
                     */
                    if (waiting_for_move)
                    {
                        debug ("Engine moves %s", tokens[1]);
                        waiting_for_move = false;
                        moved (tokens[1]);
                    }
                    else
                    {
                        debug ("Discarding engine move %s during human's turn", tokens[1]);
                    }
                    break;
                }
            }

            buffer = buffer[offset+1:buffer.length];
        }
    }

    private void configure ()
    {
        foreach (var o in options)
        {
            var line = o.split (" ");
            var option_value = line[line.length - 1];
            line = line[0:line.length-1];
            var option_name = string.joinv (" ", line);
            write_line ("setoption name %s value %s".printf (option_name, option_value));
        }
        write_line ("isready");
    }
}
