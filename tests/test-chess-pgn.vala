/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

class GlChess
{
    static int test_count = 0;
    static int failure_count = 0;

    private static void test_pgn_file (string data, string moves)
    {
        test_count++;

        PGN file;
        try
        {
            file = new PGN.from_string (data);
        }
        catch (PGNError e)
        {
            stderr.printf ("%d. FAIL %s\n", test_count, e.message);
            failure_count++;
            return;
        }

        var game = file.games.nth_data (0);
        var move_string = "";
        foreach (var move in game.moves)
            move_string += "%s ".printf (move);
        move_string = move_string.strip ();

        if (move_string == moves)
            stderr.printf ("%d. PASS\n", test_count);
        else
        {
            failure_count++;
            stderr.printf ("%d. FAIL got moves '%s', expected '%s'\n", test_count, move_string, moves);
        }
    }

    public static int main (string[] args)
    {
        /* Simple file in export format */
        test_pgn_file ("[Event \"?\"]\n" +
                       "[Site \"?\"]\n" +
                       "[Date \"????.??.??\"]\n" +
                       "[Round \"?\"]\n" +
                       "[White \"\"]\n" +
                       "[Black \"\"]\n" +
                       "[Result \"*\"]\n" +
                       "\n" +
                       "1. *\n",
                       "");

        /* No tags */
        test_pgn_file ("1. e1 *\n", "e1");

        /* No move numbers */
        test_pgn_file ("e1 *\n", "e1");

        /* No move result */
        test_pgn_file ("e1\n", "e1");

        /* No trailing newline */
        test_pgn_file ("e1", "e1");

        /* Carriage returns instead of newlines */
        test_pgn_file ("[Event \"?\"]\r" +
                       "\r" +
                       "1. d4 *\r",
                       "d4");

        /* Comments */
        test_pgn_file ("; Line comment 1\n" +
                       "[Event \"?\"]\n" +
                       "; Line comment 2\n" +
                       "\n" +
                       "1. e4 {First Move} e5 {Multi\n" +
                       "line\n" +
                       "comment} 2. Nc3 {More comments} * {Comment about game end}\n",
                       "e4 e5 Nc3");

        /* Format used by Yahoo Chess */
        test_pgn_file (";Title: Yahoo! Chess Game\n" +
                       ";White: roovis\n" +
                       ";Black: ladyjones96\n" +
                       ";Date: Fri Oct 19 12:51:54 GMT 2007\n" +
                       "\n" +
                       "1. e2-e4 e7-e5\n",
                       "e2-e4 e7-e5");

        /* Recursive Annotation Variation */
        test_pgn_file ("1.Ra8+ (1.Bxd6+ Kb7 2.Rc7+ Kb8 (2...Kb6 3.Ra6#) 3.Rd7+ Kc8 4.Rc1# (4.Ra8#))",
                       "Ra8+");

        /* Numeric Annotation Glyph */
        test_pgn_file ("e4 e5 $1 Nc3 $2",
                       "e4 e5 Nc3");

        stdout.printf ("%d/%d tests successful\n", test_count - failure_count, test_count);

        return failure_count;
    }
}
