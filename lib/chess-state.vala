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

public enum CheckState
{
    NONE,
    CHECK,
    CHECKMATE
}

public class ChessState : Object
{
    public int number = 0;
    public ChessPlayer players[2];
    public ChessPlayer current_player;
    public ChessPlayer opponent
    {
        get { return current_player.color == Color.WHITE ? players[Color.BLACK] : players[Color.WHITE]; }
    }
    public bool can_castle_kingside[2];
    public bool can_castle_queenside[2];
    public int en_passant_index = -1;
    public CheckState check_state;
    public int halfmove_clock;

    public ChessPiece board[64];
    public ChessMove? last_move = null;

    /* Bitmap of all the pieces */
    private int64 piece_masks[2];

    private ChessState.empty ()
    {
    }

    // FIXME Enable or remove these exceptions.
    public ChessState (string fen)
    {
        players[Color.WHITE] = new ChessPlayer (Color.WHITE);
        players[Color.BLACK] = new ChessPlayer (Color.BLACK);
        for (int i = 0; i < 64; i++)
            board[i] = null;

        string[] fields = fen.split (" ");
        //if (fields.length != 6)
        //    throw new Error ("Invalid FEN string");

        /* Field 1: Piece placement */
        string[] ranks = fields[0].split ("/");
        //if (ranks.length != 8)
        //    throw new Error ("Invalid piece placement");
        for (int rank = 0; rank < 8; rank++)
        {
            var rank_string = ranks[7 - rank];
            for (int file = 0, offset = 0; file < 8 && offset < rank_string.length; offset++)
            {
                var c = rank_string[offset];
                if (c >= '1' && c <= '8')
                {
                    file += c - '0';
                    continue;
                }

                PieceType type;
                var color = c.isupper () ? Color.WHITE : Color.BLACK;
                /*if (!*/ decode_piece_type (c.toupper (), out type) //)
                    ;//throw new Error ("");

                int index = get_index (rank, file);
                ChessPiece piece = new ChessPiece (players[color], type);
                board[index] = piece;
                int64 mask = BitBoard.set_location_masks[index];
                piece_masks[color] |= mask;
                file++;
            }
        }

        /* Field 2: Active color */
        if (fields[1] == "w")
            current_player = players[Color.WHITE];
        else if (fields[1] == "b")
            current_player = players[Color.BLACK];
        //else
        //    throw new Error ("Unknown active color: %s", fields[1]);

        /* Field 3: Castling availability */
        if (fields[2] != "-")
        {
            for (int i = 0; i < fields[2].length; i++)
            {
                var c = fields[2][i];
                if (c == 'K')
                    can_castle_kingside[Color.WHITE] = true;
                else if (c == 'Q')
                    can_castle_queenside[Color.WHITE] = true;
                else if (c == 'k')
                    can_castle_kingside[Color.BLACK] = true;
                else if (c == 'q')
                    can_castle_queenside[Color.BLACK] = true;
                //else
                //    throw new Error ("");
            }
        }

        /* Field 4: En passant target square */
        if (fields[3] != "-")
        {
            //if (fields[3].length != 2)
            //    throw new Error ("");
            en_passant_index = get_index (fields[3][1] - '1', fields[3][0] - 'a');
        }

        /* Field 5: Halfmove clock */
        halfmove_clock = int.parse (fields[4]);

        /* Field 6: Fullmove number */
        number = (int.parse (fields[5]) - 1) * 2;
        if (current_player.color == Color.BLACK)
            number++;

        check_state = get_check_state (current_player);
    }

    public ChessState copy ()
    {
        ChessState state = new ChessState.empty ();

        state.number = number;
        state.players[Color.WHITE] = players[Color.WHITE];
        state.players[Color.BLACK] = players[Color.BLACK];
        state.current_player = current_player;
        state.can_castle_kingside[Color.WHITE] = can_castle_kingside[Color.WHITE];
        state.can_castle_queenside[Color.WHITE] = can_castle_queenside[Color.WHITE];
        state.can_castle_kingside[Color.BLACK] = can_castle_kingside[Color.BLACK];
        state.can_castle_queenside[Color.BLACK] = can_castle_queenside[Color.BLACK];
        state.en_passant_index = en_passant_index;
        state.check_state = check_state;
        if (last_move != null)
            state.last_move = last_move.copy ();
        for (int i = 0; i < 64; i++)
            state.board[i] = board[i];
        state.piece_masks[Color.WHITE] = piece_masks[Color.WHITE];
        state.piece_masks[Color.BLACK] = piece_masks[Color.BLACK];
        state.halfmove_clock = halfmove_clock;

        return state;
    }

    public bool equals (ChessState state)
    {
        /*
         * Check first if there is the same layout of pieces (unlikely),
         * then that the same player is on move, then that the move castling
         * and en-passant state are the same.  This follows the rules for
         * determining threefold repetition:
         *
         * https://en.wikipedia.org/wiki/Threefold_repetition
         */
        if (piece_masks[Color.WHITE] != state.piece_masks[Color.WHITE] ||
            piece_masks[Color.BLACK] != state.piece_masks[Color.BLACK] ||
            current_player.color != state.current_player.color ||
            can_castle_kingside[Color.WHITE] != state.can_castle_kingside[Color.WHITE] ||
            can_castle_queenside[Color.WHITE] != state.can_castle_queenside[Color.WHITE] ||
            can_castle_kingside[Color.BLACK] != state.can_castle_kingside[Color.BLACK] ||
            can_castle_queenside[Color.BLACK] != state.can_castle_queenside[Color.BLACK] ||
            en_passant_index != state.en_passant_index)
            return false;

        /* Finally check the same piece types are present */
        for (int i = 0; i < 64; i++)
        {
            if (board[i] != null && board[i].type != state.board[i].type)
                return false;
        }

        return true;
    }

    public string get_fen ()
    {
        var value = new StringBuilder ();

        for (int rank = 7; rank >= 0; rank--)
        {
            int skip_count = 0;
            for (int file = 0; file < 8; file++)
            {
                var p = board[get_index (rank, file)];
                if (p == null)
                    skip_count++;
                else
                {
                    if (skip_count > 0)
                    {
                        value.append_printf ("%d", skip_count);
                        skip_count = 0;
                    }
                    value.append_printf ("%c", (int) p.symbol);
                }
            }
            if (skip_count > 0)
                value.append_printf ("%d", skip_count);
            if (rank != 0)
                value.append_c ('/');
        }

        value.append_c (' ');
        if (current_player.color == Color.WHITE)
            value.append_c ('w');
        else
            value.append_c ('b');

        value.append_c (' ');
        if (can_castle_kingside[Color.WHITE])
            value.append_c ('K');
        if (can_castle_queenside[Color.WHITE])
            value.append_c ('Q');
        if (can_castle_kingside[Color.BLACK])
            value.append_c ('k');
        if (can_castle_queenside[Color.BLACK])
            value.append_c ('q');
        if (!(can_castle_kingside[Color.WHITE] | can_castle_queenside[Color.WHITE] | can_castle_kingside[Color.BLACK] | can_castle_queenside[Color.BLACK]))
            value.append_c ('-');

        value.append_c (' ');
        if (en_passant_index >= 0)
            value.append_printf ("%c%d", 'a' + get_file (en_passant_index), get_rank (en_passant_index) + 1);
        else
            value.append_c ('-');

        value.append_c (' ');
        value.append_printf ("%d", halfmove_clock);

        value.append_c (' ');
        if (current_player.color == Color.WHITE)
            value.append_printf ("%d", number / 2);
        else
            value.append_printf ("%d", number / 2 + 1);

        return value.str;
    }

    public int get_index (int rank, int file)
    {
        return rank * 8 + file;
    }

    public int get_rank (int index)
    {
        return index / 8;
    }

    public int get_file (int index)
    {
        return index % 8;
    }

    public bool move (string move, bool apply = true)
    {
        int r0, f0, r1, f1;
        PieceType promotion_type;

        if (!decode_move (current_player, move, out r0, out f0, out r1, out f1, out promotion_type))
            return false;

        if (!move_with_coords (current_player, r0, f0, r1, f1, promotion_type, apply))
            return false;

        return true;
    }

    public bool move_with_coords (ChessPlayer player,
                                  int r0, int f0, int r1, int f1,
                                  PieceType promotion_type = PieceType.QUEEN,
                                  bool apply = true, bool test_check = true)
    {
        // FIXME: Make this use indexes to be faster
        var start = get_index (r0, f0);
        var end = get_index (r1, f1);

        var color = player.color;
        var opponent_color = color == Color.WHITE ? Color.BLACK : Color.WHITE;

        /* Must be moving own piece */
        var piece = board[start];
        if (piece == null || piece.player != player)
            return false;

        /* Check valid move */
        int64 end_mask = BitBoard.set_location_masks[end];
        int64 move_mask = BitBoard.move_masks[color * 64*6 + piece.type * 64 + start];
        if ((end_mask & move_mask) == 0)
            return false;

        /* Check no pieces in the way */
        int64 over_mask = BitBoard.over_masks[start * 64 + end];
        if ((over_mask & (piece_masks[Color.WHITE] | piece_masks[Color.BLACK])) != 0)
            return false;

        /* Get victim of move */
        var victim = board[end];
        var victim_index = end;

        /* Can't take own pieces */
        if (victim != null && victim.player == player)
            return false;

        /* Check special moves */
        int rook_start = -1, rook_end = -1;
        bool is_promotion = false;
        bool en_passant = false;
        bool ambiguous_rank = false;
        bool ambiguous_file = false;
        switch (piece.type)
        {
        case PieceType.PAWN:
            /* Check if taking an marched pawn */
            if (victim == null && end == en_passant_index)
            {
                en_passant = true;
                victim_index = get_index (r1 == 2 ? 3 : 4, f1);
                victim = board[victim_index];
            }

            /* If moving diagonally there must be a victim */
            if (f0 != f1)
            {
                if (victim == null)
                    return false;
            }
            else
            {
                /* If moving forward can't take enemy */
                if (victim != null)
                    return false;
            }
            is_promotion = r1 == 0 || r1 == 7;

            /* Always show the file of a pawn capturing */
            if (victim != null)
                ambiguous_file = true;
            break;
        case PieceType.KING:
            /* If moving more than one square must be castling */
            if ((f0 - f1).abs () > 1)
            {
                /* File the rook is on */
                rook_start = get_index (r0, f1 > f0 ? 7 : 0);
                rook_end = get_index (r0, f1 > f0 ? f1 - 1 : f1 + 1);

                /* Check if can castle */
                if (f1 > f0)
                {
                    if (!can_castle_kingside[color])
                        return false;
                }
                else
                {
                    if (!can_castle_queenside[color])
                        return false;
                }

                var rook = board[rook_start];
                if (rook == null || rook.type != PieceType.ROOK || rook.color != color)
                    return false;

                /* Check rook can move */
                int64 rook_over_mask = BitBoard.over_masks[rook_start * 64 + rook_end];
                if ((rook_over_mask & (piece_masks[Color.WHITE] | piece_masks[Color.BLACK])) != 0)
                    return false;

                /* Can't castle when in check */
                if (check_state == CheckState.CHECK)
                    return false;

                /* Square moved across can't be under attack */
                if (!move_with_coords (player, r0, f0, get_rank (rook_end), get_file (rook_end), PieceType.QUEEN, false, true))
                    return false;
            }
            break;
        default:
            break;
        }

        if (!apply && !test_check)
            return true;

        /* Check if other pieces of the same type can make this move - this is required for SAN notation */
        if (apply)
        {
            for (int i = 0; i < 64; i++)
            {
                /* Ignore our move */
                if (i == start)
                    continue;

                /* Check for a friendly piece of the same type */
                var p = board[i];
                if (p == null || p.player != player || p.type != piece.type)
                    continue;

                /* If more than one piece can move then the rank and/or file are ambiguous */
                var r = get_rank (i);
                var f = get_file (i);
                if (move_with_coords (player, r, f, r1, f1, PieceType.QUEEN, false))
                {
                    if (r != r0)
                        ambiguous_rank = true;
                    if (f != f0)
                        ambiguous_file = true;
                }
            }
        }

        var old_white_mask = piece_masks[Color.WHITE];
        var old_black_mask = piece_masks[Color.BLACK];
        var old_white_can_castle_kingside = can_castle_kingside[Color.WHITE];
        var old_white_can_castle_queenside = can_castle_queenside[Color.WHITE];
        var old_black_can_castle_kingside = can_castle_kingside[Color.BLACK];
        var old_black_can_castle_queenside = can_castle_queenside[Color.BLACK];
        var old_en_passant_index = en_passant_index;
        var old_halfmove_clock = halfmove_clock;

        /* Update board */
        board[start] = null;
        piece_masks[Color.WHITE] &= BitBoard.clear_location_masks[start];
        piece_masks[Color.BLACK] &= BitBoard.clear_location_masks[start];
        if (victim != null)
        {
            board[victim_index] = null;
            piece_masks[Color.WHITE] &= BitBoard.clear_location_masks[victim_index];
            piece_masks[Color.BLACK] &= BitBoard.clear_location_masks[victim_index];
        }
        if (is_promotion)
            board[end] = new ChessPiece (player, promotion_type);
        else
            board[end] = piece;
        piece_masks[color] |= end_mask;
        piece_masks[opponent_color] &= BitBoard.clear_location_masks[end];
        if (rook_start >= 0)
        {
            var rook = board[rook_start];
            board[rook_start] = null;
            piece_masks[color] &= BitBoard.clear_location_masks[rook_start];
            board[rook_end] = rook;
            piece_masks[color] |= BitBoard.set_location_masks[rook_end];
        }

        /* Can't castle once king has moved */
        if (piece.type == PieceType.KING)
        {
            can_castle_kingside[color] = false;
            can_castle_queenside[color] = false;
        }
        /* Can't castle once rooks have moved */
        else if (piece.type == PieceType.ROOK)
        {
            int base_rank = color == Color.WHITE ? 0 : 7;
            if (r0 == base_rank)
            {
                if (f0 == 0)
                    can_castle_queenside[color] = false;
                else if (f0 == 7)
                    can_castle_kingside[color] = false;
            }
        }
        /* Can't castle once the rooks have been captured */
        else if (victim != null && victim.type == PieceType.ROOK)
        {
            int base_rank = opponent_color == Color.WHITE ? 0 : 7;
            if (r1 == base_rank)
            {
                if (f1 == 0)
                    can_castle_queenside[opponent_color] = false;
                else if (f1 == 7)
                    can_castle_kingside[opponent_color] = false;
            }
        }

        /* Pawn square moved over is vulnerable */
        if (piece.type == PieceType.PAWN && over_mask != 0)
            en_passant_index = get_index ((r0 + r1) / 2, f0);
        else
            en_passant_index = -1;

        /* Reset halfmove count when pawn moved or piece taken */
        if (piece.type == PieceType.PAWN || victim != null)
            halfmove_clock = 0;
        else
            halfmove_clock++;

        /* Test if this move would leave that player in check */
        bool result = true;
        if (test_check && is_in_check (player))
            result = false;

        /* Undo move */
        if (!apply || !result)
        {
            board[start] = piece;
            board[end] = null;
            if (victim != null)
                board[victim_index] = victim;
            if (rook_start >= 0)
            {
                var rook = board[rook_end];
                board[rook_start] = rook;
                board[rook_end] = null;
            }
            piece_masks[Color.WHITE] = old_white_mask;
            piece_masks[Color.BLACK] = old_black_mask;
            can_castle_kingside[Color.WHITE] = old_white_can_castle_kingside;
            can_castle_queenside[Color.WHITE] = old_white_can_castle_queenside;
            can_castle_kingside[Color.BLACK] = old_black_can_castle_kingside;
            can_castle_queenside[Color.BLACK] = old_black_can_castle_queenside;
            en_passant_index = old_en_passant_index;
            halfmove_clock = old_halfmove_clock;

            return result;
        }

        current_player = color == Color.WHITE ? players[Color.BLACK] : players[Color.WHITE];
        check_state = get_check_state (current_player);

        last_move = new ChessMove ();
        last_move.number = number;
        last_move.piece = piece;
        if (is_promotion)
            last_move.promotion_piece = board[end];
        last_move.victim = victim;
        if (rook_end >= 0)
            last_move.castling_rook = board[rook_end];
        last_move.r0 = r0;
        last_move.f0 = f0;
        last_move.r1 = r1;
        last_move.f1 = f1;
        last_move.ambiguous_rank = ambiguous_rank;
        last_move.ambiguous_file = ambiguous_file;
        last_move.en_passant = en_passant;
        last_move.check_state = check_state;

        return true;
    }

    public ChessResult get_result (out ChessRule rule)
    {
        rule = ChessRule.CHECKMATE;
        if (check_state == CheckState.CHECKMATE)
        {
            if (current_player.color == Color.WHITE)
            {
                rule = ChessRule.CHECKMATE;
                return ChessResult.BLACK_WON;
            }
            else
            {
                rule = ChessRule.CHECKMATE;
                return ChessResult.WHITE_WON;
            }
        }

        if (!can_move (current_player))
        {
            rule = ChessRule.STALEMATE;
            return ChessResult.DRAW;
        }

        if (last_move != null && last_move.victim != null && !have_sufficient_material ())
        {
            rule = ChessRule.INSUFFICIENT_MATERIAL;
            return ChessResult.DRAW;
        }

        return ChessResult.IN_PROGRESS;
    }

    private CheckState get_check_state (ChessPlayer player)
    {
        if (is_in_check (player))
        {
            if (is_in_checkmate (player))
                return CheckState.CHECKMATE;
            else
                return CheckState.CHECK;
        }
        return CheckState.NONE;
    }

    public bool is_in_check (ChessPlayer player)
    {
        var opponent = player.color == Color.WHITE ? players[Color.BLACK] : players[Color.WHITE];

        /* Is in check if any piece can take the king */
        for (int king_index = 0; king_index < 64; king_index++)
        {
            var p = board[king_index];
            if (p != null && p.player == player && p.type == PieceType.KING)
            {
                /* See if any enemy pieces can take the king */
                for (int start = 0; start < 64; start++)
                {
                    if (move_with_coords (opponent,
                                          get_rank (start), get_file (start),
                                          get_rank (king_index), get_file (king_index),
                                          PieceType.QUEEN, false, false))
                        return true;
                }
            }
        }

        return false;
    }

    private bool is_in_checkmate (ChessPlayer player)
    {
        /* Is in checkmate if no pieces can move */
        for (int piece_index = 0; piece_index < 64; piece_index++)
        {
            var p = board[piece_index];
            if (p != null && p.player == player)
            {
                for (int end = 0; end < 64; end++)
                {
                    if (move_with_coords (player,
                                          get_rank (piece_index), get_file (piece_index),
                                          get_rank (end), get_file (end),
                                          PieceType.QUEEN, false, true))
                        return false;
                }
            }
        }

        return true;
    }

    private bool can_move (ChessPlayer player)
    {
        bool have_pieces = false;

        for (int start = 0; start < 64; start++)
        {
            var p = board[start];
            if (p != null && p.player == player)
            {
                have_pieces = true;

                /* See if can move anywhere */
                for (int end = 0; end < 64; end++)
                {
                    if (move_with_coords (player,
                                          get_rank (start), get_file (start),
                                          get_rank (end), get_file (end),
                                          PieceType.QUEEN, false, true))
                        return true;
                }
            }
        }

        /* Only mark as stalemate if have at least one piece */
        if (have_pieces)
            return false;
        else
            return true;
    }

    public bool have_sufficient_material ()
    {
        var white_knight_count = 0;
        var white_bishop_count = 0;
        var white_bishop_on_white_square = false;
        var white_bishop_on_black_square = false;
        var black_knight_count = 0;
        var black_bishop_count = 0;
        var black_bishop_on_white_square = false;
        var black_bishop_on_black_square = false;

        for (int i = 0; i < 64; i++)
        {
            var p = board[i];
            if (p == null)
                continue;

            /* Any pawns, rooks or queens can perform checkmate */
            if (p.type == PieceType.PAWN || p.type == PieceType.ROOK || p.type == PieceType.QUEEN)
                return true;

            /* Otherwise, count the minor pieces for each colour... */
            if (p.type == PieceType.KNIGHT)
            {
                if (p.color == Color.WHITE)
                    white_knight_count++;
                else
                    black_knight_count++;
            }

            if (p.type == PieceType.BISHOP)
            {
                var color = Color.BLACK;
                if ((i + i/8) % 2 != 0)
                    color = Color.WHITE;

                if (p.color == Color.WHITE)
                {
                    if (color == Color.WHITE)
                        white_bishop_on_white_square = true;
                    else
                        white_bishop_on_black_square = true;
                    white_bishop_count++;
                }
                else
                {
                    if (color == Color.WHITE)
                        black_bishop_on_white_square = true;
                    else
                        black_bishop_on_black_square = true;
                    black_bishop_count++;
                }
            }

            /*
             * We count the following positions as insufficient:
             *
             * 1) king versus king
             * 2) king and bishop versus king
             * 3) king and knight versus king
             * 4) king and bishop versus king and bishop with the bishops on the same color. (Any
             *    number of additional bishops of either color on the same color of square due to
             *    underpromotion do not affect the situation.)
             *
             * From: https://en.wikipedia.org/wiki/Draw_(chess)#Draws_in_all_games
             *
             * Note also that this follows FIDE rules, not USCF rules. E.g. K+N+N vs. K cannot be
             * forced, so it's not counted as a draw.
             *
             * This is also what CECP engines will be expecting:
             *
             * "Note that (in accordance with FIDE rules) only KK, KNK, KBK and KBKB with all
             * bishops on the same color can be claimed as draws on the basis of insufficient mating
             * material. The end-games KNNK, KBKN, KNKN and KBKB with unlike bishops do have mate
             * positions, and cannot be claimed. Complex draws based on locked Pawn chains will not
             * be recognized as draws by most interfaces, so do not claim in such positions, but
             * just offer a draw or play on."
             *
             * From: http://www.open-aurec.com/wbforum/WinBoard/engine-intf.html
             *
             * (In contrast, UCI seems to expect the interface to handle draws itself.)
             */

            /* Two knights versus king can checkmate (though not against an optimal opponent) */
            if (white_knight_count > 1 || black_knight_count > 1)
                return true;

            /* Bishop and knight versus king can checkmate */
            if (white_bishop_count > 0 && white_knight_count > 0)
                return true;
            if (black_bishop_count > 0 && black_knight_count > 0)
                return true;

            /* King and bishops versus king can checkmate as long as the bishops are on both colours */
            if (white_bishop_on_white_square && white_bishop_on_black_square)
                return true;
            if (black_bishop_on_white_square && black_bishop_on_black_square)
                return true;

            /* King and minor piece vs. King and knight is surprisingly not a draw */
            if ((white_bishop_count > 0 || white_knight_count > 0) && black_knight_count > 0)
                return true;
            if ((black_bishop_count > 0 || black_knight_count > 0) && white_knight_count > 0)
                return true;

            /* King and bishop can checkmate vs. king and bishop if bishops are on opposite colors */
            if (white_bishop_count > 0 && black_bishop_count > 0)
            {
                if (white_bishop_on_white_square && black_bishop_on_black_square)
                    return true;
                else if (white_bishop_on_black_square && black_bishop_on_white_square)
                    return true;
            }
        }

        return false;
    }

    private bool decode_piece_type (unichar c, out PieceType type)
    {
        type = PieceType.PAWN;
        switch (c)
        {
        case 'P':
            type = PieceType.PAWN;
            return true;
        case 'R':
            type = PieceType.ROOK;
            return true;
        case 'N':
            type = PieceType.KNIGHT;
            return true;
        case 'B':
            type = PieceType.BISHOP;
            return true;
        case 'Q':
            type = PieceType.QUEEN;
            return true;
        case 'K':
            type = PieceType.KING;
            return true;
        default:
            return false;
        }
    }

    private bool decode_move (ChessPlayer player, string move, out int r0, out int f0, out int r1, out int f1, out PieceType promotion_type)
    {
        int i = 0;

        promotion_type = PieceType.QUEEN;
        if (move.has_prefix ("O-O-O"))
        {
            if (player.color == Color.WHITE)
                r0 = r1 = 0;
            else
                r0 = r1 = 7;
            f0 = 4;
            f1 = 2;
            i += (int) "O-O-O".length;
        }
        else if (move.has_prefix ("O-O"))
        {
            if (player.color == Color.WHITE)
                r0 = r1 = 0;
            else
                r0 = r1 = 7;
            f0 = 4;
            f1 = 6;
            i += (int) "O-O".length;
        }
        else
        {
            PieceType type = PieceType.PAWN;
            if (decode_piece_type (move[i], out type))
                i++;

            r0 = f0 = r1 = f1 = -1;
            if (move[i] >= 'a' && move[i] <= 'h')
            {
                f1 = (int) (move[i] - 'a');
                i++;
            }
            if (move[i] >= '1' && move[i] <= '8')
            {
                r1 = (int) (move[i] - '1');
                i++;
            }
            if (move[i] == 'x' || move[i] == '-')
                i++;
            if (move[i] >= 'a' && move[i] <= 'h')
            {
                f0 = f1;
                f1 = (int) (move[i] - 'a');
                i++;
            }
            if (move[i] >= '1' && move[i] <= '8')
            {
                r0 = r1;
                r1 = (int) (move[i] - '1');
                i++;
            }
            if (move[i] == '=')
            {
                i++;
                if (decode_piece_type (move[i], out promotion_type))
                    i++;
            }
            else if (move[i] != '\0')
            {
                switch (move[i])
                {
                case 'q':
                case 'Q':
                    promotion_type = PieceType.QUEEN;
                    i++;
                    break;
                case 'n':
                case 'N':
                    promotion_type = PieceType.KNIGHT;
                    i++;
                    break;
                case 'r':
                case 'R':
                    promotion_type = PieceType.ROOK;
                    i++;
                    break;
                case 'b':
                case 'B':
                    promotion_type = PieceType.BISHOP;
                    i++;
                    break;
                }
            }

            /* Don't have a destination to move to */
            if (r1 < 0 || f1 < 0)
            {
                debug ("Move %s missing destination", move);
                return false;
            }

            /* Find source piece */
            if (r0 < 0 || f0 < 0)
            {
                int match_rank = -1, match_file = -1;

                for (int file = 0; file < 8; file++)
                {
                    if (f0 >= 0 && file != f0)
                        continue;

                    for (int rank = 0; rank < 8; rank++)
                    {
                        if (r0 >= 0 && rank != r0)
                            continue;

                        /* Only check this players pieces of the correct type */
                        var piece = board[get_index (rank, file)];
                        if (piece == null || piece.type != type || piece.player != player)
                            continue;

                        /* See if can move here */
                        if (!this.move_with_coords (player, rank, file, r1, f1, PieceType.QUEEN, false))
                            continue;

                        /* Duplicate match */
                        if (match_rank >= 0)
                        {
                            debug ("Move %s is ambiguous", move);
                            return false;
                        }

                        match_rank = rank;
                        match_file = file;
                    }
                }

                if (match_rank < 0)
                {
                    debug ("Move %s has no matches", move);
                    return false;
                }

                r0 = match_rank;
                f0 = match_file;
            }
        }

        if (move[i] == '+')
            i++;
        else if (move[i] == '#')
            i++;

        if (move[i] != '\0')
        {
            debug ("Move %s has unexpected characters", move);
            return false;
        }

        return true;
    }
}
