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

public class ChessMove : Object
{
    public int number;
    public ChessPiece piece;
    public ChessPiece? promotion_piece;
    public ChessPiece? moved_rook;
    public ChessPiece? victim;
    public int r0;
    public int f0;
    public int r1;
    public int f1;
    public bool ambiguous_rank;
    public bool ambiguous_file;
    public CheckState check_state;

    public string get_lan ()
    {
        if (moved_rook != null)
        {
            if (f1 > f0)
                return "O-O";
            else
                return "O-O-O";
        }

        var builder = new StringBuilder ();
        if (victim != null)
            builder.append_printf ("%c%dx%c%d", 'a' + f0, r0 + 1, 'a' + f1, r1 + 1);
        else
            builder.append_printf ("%c%d-%c%d", 'a' + f0, r0 + 1, 'a' + f1, r1 + 1);

        const char promotion_symbols[] = {' ', 'R', 'N', 'B', 'Q', 'K'};
        if (promotion_piece != null)
            builder.append_printf ("=%c", promotion_symbols[promotion_piece.type]);

        switch (check_state)
        {
        case CheckState.CHECK:
            builder.append_c ('+');
            break;
        case CheckState.CHECKMATE:
            builder.append_c ('#');
            break;
        }

        return builder.str;
    }

    public string get_san ()
    {
        const string piece_names[] = {"", "R", "N", "B", "Q", "K"};
        return make_san ((string[]) piece_names);
    }

    public string get_fan ()
    {
        const string white_piece_names[] = {"", "♖", "♘", "♗", "♕", "♔"};
        const string black_piece_names[] = {"", "♜", "♞", "♝", "♛", "♚"};
        if (piece.color == Color.WHITE)
            return make_san ((string[]) white_piece_names);
        else
            return make_san ((string[]) black_piece_names);
    }

    private string make_san (string[] piece_names)
    {
        if (moved_rook != null)
        {
            if (f1 > f0)
                return "O-O";
            else
                return "O-O-O";
        }

        var builder = new StringBuilder ();
        builder.append (piece_names[piece.type]);
        if (ambiguous_file)
            builder.append_printf ("%c", 'a' + f0);
        if (ambiguous_rank)
            builder.append_printf ("%d", r0 + 1);
        if (victim != null)
            builder.append ("x");
        builder.append_printf ("%c%d", 'a' + f1, r1 + 1);

        if (promotion_piece != null)
            builder.append_printf ("=%s", piece_names[promotion_piece.type]);

        switch (check_state)
        {
        case CheckState.CHECK:
            builder.append_c ('+');
            break;
        case CheckState.CHECKMATE:
            builder.append_c ('#');
            break;
        }

        return builder.str;
    }

    /* Move suitable for a chess engine (CECP/UCI) */
    public string get_engine ()
    {
        var builder = new StringBuilder ();
        const char promotion_symbols[] = {' ', 'r', 'n', 'b', 'q', ' '};
        if (promotion_piece != null)
            builder.append_printf ("%c%d%c%d%c", 'a' + f0, r0 + 1, 'a' + f1, r1 + 1, promotion_symbols[promotion_piece.type]);
        else
            builder.append_printf ("%c%d%c%d", 'a' + f0, r0 + 1, 'a' + f1, r1 + 1);
        return builder.str;
    }

    public ChessMove copy ()
    {
        var move = new ChessMove ();
        move.number = number;
        move.piece = piece;
        move.promotion_piece = promotion_piece;
        move.moved_rook = moved_rook;
        move.victim = victim;
        move.r0 = r0;
        move.f0 = f0;
        move.r1 = r1;
        move.f1 = f1;
        move.ambiguous_rank = ambiguous_rank;
        move.ambiguous_file = ambiguous_file;
        move.check_state = check_state;
        return move;
    }
}
