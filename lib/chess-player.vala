/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2014 Robert Ancell
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum Color
{
    WHITE,
    BLACK
}

public class ChessPlayer : Object
{
    public Color color;
    public signal bool do_move (string move, bool apply);
    public signal void do_undo ();
    public signal bool do_resign ();
    public signal void do_claim_draw ();

    private bool _local_human = false;
    public bool local_human
    {
        get { return _local_human; }
        set
        {
            _local_human = value;
        }
    }

    public ChessPlayer (Color color)
    {
        this.color = color;
    }

    public bool move (string move, bool apply = true)
    {
        return do_move (move, apply);
    }

    public bool move_with_coords (int r0, int f0, int r1, int f1,
        bool apply = true, PieceType promotion_type = PieceType.QUEEN)
    {
        string move = "%c%d%c%d".printf ('a' + f0, r0 + 1, 'a' + f1, r1 + 1);

        switch (promotion_type)
        {
        case PieceType.QUEEN:
            /* Default is queen so don't add anything */
            break;
        case PieceType.KNIGHT:
            move += "=N";
            break;
        case PieceType.ROOK:
            move += "=R";
            break;
        case PieceType.BISHOP:
            move += "=B";
            break;
        default:
            break;
        }

        return do_move (move, apply);
    }

    public void undo ()
    {
        do_undo ();
    }

    public bool resign ()
    {
        return do_resign ();
    }

    public void claim_draw ()
    {
        do_claim_draw ();
    }
}
