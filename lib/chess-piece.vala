/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2016 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum PieceType
{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING
}

public class ChessPiece : Object
{
    public ChessPlayer player;
    public PieceType type;

    public signal void moved ();
    public signal void promoted ();
    public signal void died ();

    public Color color
    {
        get { return player.color; }
    }

    public unichar symbol
    {
        get
        {
            unichar c = ' ';
            switch (type)
            {
            case PieceType.PAWN:
                c = 'p';
                break;
            case PieceType.ROOK:
                c = 'r';
                break;
            case PieceType.KNIGHT:
                c = 'n';
                break;
            case PieceType.BISHOP:
                c = 'b';
                break;
            case PieceType.QUEEN:
                c = 'q';
                break;
            case PieceType.KING:
                c = 'k';
                break;
            }
            if (player.color == Color.WHITE)
                c = c.toupper ();
            return c;
        }
    }

    public ChessPiece (ChessPlayer player, PieceType type)
    {
        this.player = player;
        this.type = type;
    }
}
