public enum Color
{
    WHITE,
    BLACK
}

public class ChessPlayer : Object
{
    public Color color;
    public signal void start_turn ();
    public signal bool do_move (string move, bool apply);
    public signal void do_undo ();
    public signal bool do_resign ();
    public signal bool do_claim_draw ();

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
    
    public bool claim_draw ()
    {
        return do_claim_draw ();
    }
}

public enum PieceType
{
    PAWN,
    ROOK,
    KNIGHT,
    BISHOP,
    QUEEN,
    KING
}

public class ChessPiece
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

public enum CheckState
{
    NONE,
    CHECK,
    CHECKMATE
}

public class ChessMove
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
        const string white_piece_names[] = {"", "♞", "♝", "♜", "♛", "♚"};
        const string black_piece_names[] = {"", "♘", "♗", "♖", "♕", "♔"};
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

public class ChessState
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
                if (!decode_piece_type (c.toupper (), out type))
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
            state.last_move = last_move.copy();
        for (int i = 0; i < 64; i++)
            state.board[i] = board[i];
        state.piece_masks[Color.WHITE] = piece_masks[Color.WHITE];
        state.piece_masks[Color.BLACK] = piece_masks[Color.BLACK];

        return state;
    }

    public bool equals (ChessState state)
    {
        /* Check first if there is the same layout of pieces (unlikely),
         * then the move castling and en-passant state are the same,
         * then finally that it is the same move */
        if (piece_masks[Color.WHITE] != state.piece_masks[Color.WHITE] ||
            piece_masks[Color.BLACK] != state.piece_masks[Color.BLACK] || 
            can_castle_kingside[Color.WHITE] != state.can_castle_kingside[Color.WHITE] ||
            can_castle_queenside[Color.WHITE] != state.can_castle_queenside[Color.WHITE] ||
            can_castle_kingside[Color.BLACK] != state.can_castle_kingside[Color.BLACK] ||
            can_castle_queenside[Color.BLACK] != state.can_castle_queenside[Color.BLACK] ||
            en_passant_index != state.en_passant_index ||
            (last_move != null) != (state.last_move != null) ||
            last_move.piece.type != state.last_move.piece.type ||
            last_move.r0 != state.last_move.r0 ||
            last_move.f0 != state.last_move.f0 ||
            last_move.r1 != state.last_move.r1 ||
            last_move.f1 != state.last_move.f1)
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
        bool ambiguous_rank = false;
        bool ambiguous_file = false;
        switch (piece.type)
        {
        case PieceType.PAWN:
            /* Check if taking an marched pawn */
            if (victim == null && end == en_passant_index)
            {
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
            last_move.moved_rook = board[rook_end];
        last_move.r0 = r0;
        last_move.f0 = f0;
        last_move.r1 = r1;
        last_move.f1 = f1;
        last_move.ambiguous_rank = ambiguous_rank;
        last_move.ambiguous_file = ambiguous_file;
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

    private bool is_in_check (ChessPlayer player)
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

public enum ChessResult
{
    IN_PROGRESS,
    WHITE_WON,
    BLACK_WON,
    DRAW
}

public enum ChessRule
{
    CHECKMATE,
    STALEMATE,
    FIFTY_MOVES,
    TIMEOUT,
    THREE_FOLD_REPETITION,
    INSUFFICIENT_MATERIAL,
    RESIGN,
    ABANDONMENT,
    DEATH
}

public class ChessGame
{
    public bool is_started;
    public ChessResult result;
    public ChessRule rule;
    public List<ChessState> move_stack;
    
    private int hold_count = 0;

    public const string STANDARD_SETUP = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

    public signal void started ();
    public signal void turn_started (ChessPlayer player);
    public signal void moved (ChessMove move);
    public signal void undo ();
    public signal void ended ();
    
    public ChessState current_state
    {
       get { return move_stack.data; }
    }

    public ChessPlayer white
    {
        get { return current_state.players[Color.WHITE]; }
    }
    public ChessPlayer black
    {
        get { return current_state.players[Color.BLACK]; }
    }
    public ChessPlayer current_player
    {
        get { return current_state.current_player; }
    }
    public ChessPlayer opponent
    {
        get { return current_state.opponent; }
    }
    private ChessClock? _clock;
    public ChessClock? clock
    {
        get { return _clock; }
        set
        {
            if (is_started)
                return;
            _clock = value;
        }
    }

    public ChessGame (string fen = STANDARD_SETUP, string[]? moves = null)
    {
        is_started = false;
        move_stack.prepend (new ChessState (fen));
        result = ChessResult.IN_PROGRESS;

        if (moves != null)
        {
            for (var i = 0; i < moves.length; i++)
            {
                if (!do_move (current_player, moves[i], true))
                    warning ("Invalid move %s", moves[i]);
            }
        }

        white.do_move.connect (move_cb);
        white.do_undo.connect (undo_cb);
        white.do_resign.connect (resign_cb);
        white.do_claim_draw.connect (claim_draw_cb);
        black.do_move.connect (move_cb);
        black.do_undo.connect (undo_cb);
        black.do_resign.connect (resign_cb);
        black.do_claim_draw.connect (claim_draw_cb);
    }

    private bool move_cb (ChessPlayer player, string move, bool apply)
    {
        if (!is_started)
            return false;

        return do_move (player, move, apply);
    }

    private bool do_move (ChessPlayer player, string? move, bool apply)
    {
        if (player != current_player)
            return false;

        var state = current_state.copy ();
        state.number++;
        if (!state.move (move, apply))
            return false;

        if (!apply)
            return true;

        move_stack.prepend (state);
        if (state.last_move.victim != null)
            state.last_move.victim.died ();
        state.last_move.piece.moved ();
        if (state.last_move.moved_rook != null)
            state.last_move.moved_rook.moved ();
        moved (state.last_move);
        complete_move ();

        return true;
    }

    public void add_hold ()
    {
        hold_count++;
    }

    public void remove_hold ()
    {
        return_if_fail (hold_count > 0);

        hold_count--;
        if (hold_count == 0)
            complete_move ();
    }

    private void complete_move ()
    {
        /* Wait until the hold is removed */
        if (hold_count > 0)
            return;
            
        ChessRule rule;
        var result = current_state.get_result (out rule);
        if (result != ChessResult.IN_PROGRESS)
        {
            stop (result, rule);
        }
        else
        {
            if (_clock != null)
                _clock.active_color = current_player.color;
            current_player.start_turn ();
            turn_started (current_player);
        }
    }

    private void undo_cb (ChessPlayer player)
    {
        /* If this players turn undo their opponents move first */
        if (player == current_player)
            undo_cb (opponent);

        /* Don't pop off starting move */
        if (move_stack.next == null)
            return;

        /* Pop off the move state and notify */
        move_stack.remove_link (move_stack);
        undo ();
    }

    private bool resign_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        if (player.color == Color.WHITE)
            stop (ChessResult.BLACK_WON, ChessRule.RESIGN);
        else
            stop (ChessResult.WHITE_WON, ChessRule.RESIGN);

        return true;
    }

    private bool claim_draw_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        if (current_state.halfmove_clock >= 100)
            stop (ChessResult.DRAW, ChessRule.FIFTY_MOVES);
        else if (is_three_fold_repeat ())
            stop (ChessResult.DRAW, ChessRule.THREE_FOLD_REPETITION);
        else
            return false;

        return true;
    }

    public void start ()
    {
        if (result != ChessResult.IN_PROGRESS)
            return;

        if (is_started)
            return;
        is_started = true;

        if (_clock != null)
        {
            _clock.expired.connect (clock_expired_cb);
            _clock.active_color = current_player.color;
            _clock.start ();
        }

        started ();
        current_player.start_turn ();
        turn_started (current_player);
    }

    private void clock_expired_cb (ChessClock clock)
    {
        if (current_player.color == Color.WHITE)
            stop (ChessResult.BLACK_WON, ChessRule.TIMEOUT);
        else
            stop (ChessResult.WHITE_WON, ChessRule.TIMEOUT);
    }

    public void abandon ()
    {
        if (!is_started)
            return;
        stop (ChessResult.DRAW, ChessRule.ABANDONMENT);
    }
    
    public ChessPiece? get_piece (int rank, int file, int move_number = -1)
    {
        if (move_number < 0)
            move_number += (int) move_stack.length ();

        var state = move_stack.nth_data (move_stack.length () - move_number - 1);

        return state.board[state.get_index (rank, file)];
    }

    public uint n_moves
    {
        get { return move_stack.length() - 1; }
    }

    private void stop (ChessResult result, ChessRule rule)
    {
        this.result = result;
        this.rule = rule;
        is_started = false;
        if (_clock != null)
            _clock.stop();
        ended ();
    }

    private bool is_three_fold_repeat ()
    {
        var count = 1;

        foreach (var state in move_stack.next)
        {
            if (current_state.equals (state))
            {
                count++;
                if (count >= 3)
                    return true;
            }
        }

        return false;
    }
}
