public enum Color
{
    WHITE,
    BLACK
}

public class ChessPlayer : GLib.Object
{
    public Color color;
    public signal void start_turn ();
    public signal bool do_move (string move, bool apply);
    public signal bool do_move_with_coords (int r0, int f0, int r1, int f1, bool apply);
    public signal bool do_resign ();
    public signal bool do_claim_draw ();

    public ChessPlayer (Color color)
    {
        this.color = color;
    }

    public bool move (string move, bool apply = true)
    {
        return do_move (move, apply);
    }

    public bool move_with_coords (int r0, int f0, int r1, int f1, bool apply = true)
    {
        return do_move_with_coords (r0, f0, r1, f1, apply);
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

    public ChessPiece (ChessPlayer player, PieceType type)
    {
        this.player = player;
        this.type = type;
    }
}

public class ChessMove
{
    public int number;
    public ChessPiece piece;
    public ChessPiece? moved_rook;
    public ChessPiece? victim;
    public int r0;
    public int f0;
    public int r1;
    public int f1;
    public string lan = "";
    public string san = "";
    public string human = "";
    
    public string fan
    {
        get
        {
            // FIXME: Translate the san move
            //♙♘♗♖♕♔
            //♟♞♝♜♛♚
            return san;
        }
    }

    public ChessMove copy ()
    {
        var move = new ChessMove ();
        move.number = number;
        move.piece = piece;
        move.moved_rook = moved_rook;
        move.victim = victim;
        move.r0 = r0;
        move.f0 = f0;
        move.r1 = r1;
        move.f1 = f1;
        move.lan = lan;        
        move.san = san;
        move.human = human;
        return move;
    }
}

public class ChessState
{
    public int number = 0;
    public ChessPlayer white;
    public ChessPlayer black;    
    public ChessPlayer current_player;

    public ChessPiece[,] board;
    public ChessMove? last_move = null;

    public ChessState ()
    {
        current_player = white = new ChessPlayer (Color.WHITE);
        black = new ChessPlayer (Color.BLACK);

        board = new ChessPiece[8,8];
        for (int file = 0; file < 8; file++)
            for (int rank = 0; rank < 8; rank++)
                board[rank, file] = null;

        add_piece (0, 0, white, PieceType.ROOK);
        add_piece (0, 1, white, PieceType.KNIGHT);
        add_piece (0, 2, white, PieceType.BISHOP);
        add_piece (0, 3, white, PieceType.QUEEN);
        add_piece (0, 4, white, PieceType.KING);
        add_piece (0, 5, white, PieceType.BISHOP);
        add_piece (0, 6, white, PieceType.KNIGHT);
        add_piece (0, 7, white, PieceType.ROOK);
        add_piece (7, 0, black, PieceType.ROOK);
        add_piece (7, 1, black, PieceType.KNIGHT);
        add_piece (7, 2, black, PieceType.BISHOP);
        add_piece (7, 3, black, PieceType.QUEEN);
        add_piece (7, 4, black, PieceType.KING);
        add_piece (7, 5, black, PieceType.BISHOP);
        add_piece (7, 6, black, PieceType.KNIGHT);
        add_piece (7, 7, black, PieceType.ROOK);
        for (int file = 0; file < 8; file++)
        {
            add_piece (1, file, white, PieceType.PAWN);
            add_piece (6, file, black, PieceType.PAWN);
        }
    }

    private void add_piece (int rank, int file, ChessPlayer player, PieceType type)
    {
        ChessPiece piece = new ChessPiece (player, type);
        board[rank, file] = piece;
    }
    
    public ChessState copy ()
    {
        ChessState state = new ChessState ();

        state.number = number;
        state.white = white;
        state.black = black;
        state.current_player = current_player;
        if (last_move != null)
            state.last_move = last_move.copy();
        for (int file = 0; file < 8; file++)
            for (int rank = 0; rank < 8; rank++)
                state.board[rank, file] = board[rank, file];

        return state;
    }

    public bool move (string move, bool apply = true)
    {
        int r0, f0, r1, f1;
        if (!decode_move (move, out r0, out f0, out r1, out f1))
            return false;
        return move_with_coords (r0, f0, r1, f1, apply);
    }

    public bool move_with_coords (int r0, int f0, int r1, int f1, bool apply = true, bool test_check = true)
    {
        /* Must be moving own piece */
        ChessPiece? piece = board[r0, f0];

        if (piece == null || piece.player != current_player)
            return false;

        /* Can't take own pieces */
        ChessPiece? victim = board[r1, f1];
        if (victim != null && victim.player == current_player)
            return false;

        /* Get rank relative to base rank */
        int rel_rank = r0;
        int rel_march = r1 - r0;
        if (piece.player.color == Color.BLACK)
        {
            rel_rank = 7 - rel_rank;
            rel_march = -rel_march;
        }

        /* Distance moved in each dimension */
        int file_distance = (f1 - f0).abs();
        int rank_distance = (r1 - r0).abs();

        /* Direction moved in each dimension */
        int rank_step = r1 - r0;
        if (rank_distance != 0)
            rank_step /= rank_distance;
        int file_step = f1 - f0;
        if (file_distance != 0)
            file_step /= file_distance;

        bool valid = false, check_inbetween = false;
        int rook_file = -1;
        switch (piece.type)
        {
        case PieceType.PAWN:
            /* Can move forward one, forward two from the base rank or
             * diagonally and take an opponent piece */
            valid = (victim == null && rel_march == 1 && file_distance == 0) ||
                    (victim == null && rel_march == 2 && file_distance == 0 && rel_rank == 1) ||
                    (victim != null && rel_march == 1 && file_distance == 1);

            // FIXME: Check en passant

            check_inbetween = true;
            break;
        case PieceType.ROOK:
            /* Can move horizontal or vertical */
            valid = file_distance == 0 ||
                    rank_distance == 0;
            check_inbetween = true;
            break;
        case PieceType.KNIGHT:
            /* Can move one square in one direction and two in the other */
            valid = file_distance * rank_distance == 2;
            break;
        case PieceType.BISHOP:
            /* Can move diagonal */
            valid = file_distance == rank_distance;
            check_inbetween = true;
            break;
        case PieceType.QUEEN:
            /* Can move horizontal, vertical or diagonal */
            valid = file_distance == 0 ||
                    rank_distance == 0 ||
                    file_distance == rank_distance;
            check_inbetween = true;
            break;
        case PieceType.KING:
            /* Can only move one square */
            valid = file_distance < 2 && rank_distance < 2;

            /* Castle move */
            if (file_distance == 2 && rank_distance == 0 && rel_rank == 0)
            {
                // FIXME: Check rook and king hasn't moved

                /* File the rook is on */
                rook_file = file_step > 0 ? 7 : 0; 

                /* Need space between king and rook */
                for (int f = f0 + file_step; f < 7 && f > 0; f += file_step)
                    if (board[r0, f] != null)
                        return false;

                // FIXME: Need to check if can get taken on square moved over

                valid = true;
            }
            break;
        }
        if (!valid)
            return false;

        /* Check if squares being moved over are free */
        if (check_inbetween)
        {
            int r = r0 + rank_step, f = f0 + file_step;
            for (; !(r == r1 & f == f1); r += rank_step, f += file_step)
                if (board[r, f] != null)
                    return false;
        }

        if (test_check)
        {
            /* Check if would put us into check */
            // FIXME: Check 2-3 squares if king was moved
            var state = copy ();
            state.move_with_coords (r0, f0, r1, f1, true, false);

            int king_rank = -1, king_file = -1;
            for (int file = 0; file < 8; file++)
                for (int rank = 0; rank < 8; rank++)
                {
                    var p = state.board[rank, file];
                    if (p != null && p.player == current_player && p.type == PieceType.KING)
                    {
                        king_rank = rank;
                        king_file = file;
                    }
                }
                
            /* See if any enemy pieces can take the king */
            for (int file = 0; file < 8; file++)
                for (int rank = 0; rank < 8; rank++)
                    if (state.move_with_coords (rank, file, king_rank, king_file, false, false))
                        return false;
        }

        if (!apply)
            return true;

        /* Move piece */
        board[r0, f0] = null;
        board[r1, f1] = piece;

        last_move = new ChessMove ();
        last_move.number = number;
        last_move.piece = piece;
        last_move.victim = victim;

        /* Move rook in castle */
        if (rook_file >= 0)
        {
            ChessPiece rook = board[r0, rook_file];
            board[r0, rook_file] = null;
            board[r0, f0 + file_step] = rook;
            last_move.moved_rook = rook;
        }

        if (current_player == white)
            current_player = black;
        else
            current_player = white;

        last_move.r0 = r0;
        last_move.f0 = f0;
        last_move.r1 = r1;
        last_move.f1 = f1;
        // FIXME: Promotion
        last_move.lan = "%c%d%c%d".printf ('a' + f0, r0 + 1, 'a' + f1, r1 + 1);
        // FIXME: Generate SAN move
        last_move.san = last_move.lan;

        return true;
    }

    private bool decode_piece_type (unichar c, out PieceType type)
    {
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

    private bool decode_move (string move, out int r0, out int f0, out int r1, out int f1)
    {
        int i = 0;
        
        if (move.has_prefix ("O-O-O"))
        {
            if (current_player == white)
                r0 = r1 = 0;
            else
                r0 = r1 = 7;
            f0 = 4;
            f1 = 2;
            i += (int) "O-O-O".length;
        }
        else if (move.has_prefix ("O-O"))
        {
            if (current_player == white)
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
            if (move[i] == 'x')
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
                i++;
            PieceType promotion_type;
            if (decode_piece_type (move[i], out promotion_type))
                i++;

            /* Don't have a destination to move to */
            if (r1 < 0 || f1 < 0)
            {
                GLib.debug ("Move %s missing destination", move);
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
                        var piece = board[rank,file];
                        if (piece == null || piece.type != type || piece.player != current_player)
                            continue;

                        /* See if can move here */
                        if (!this.move_with_coords (rank, file, r1, f1, false))
                            continue;

                        /* Duplicate match */
                        if (match_rank >= 0)
                        {
                            GLib.debug ("Move %s is ambiguous", move);
                            return false;
                        }

                        match_rank = rank;
                        match_file = file;
                    }
                }

                if (match_rank < 0)
                {
                    GLib.debug ("Move %s has no matches", move);
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
            GLib.debug ("Move %s has unexpected characters", move);
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
    public GLib.List<ChessState> move_stack;

    public signal void started ();
    public signal void turn_started (ChessPlayer player);
    public signal void moved (ChessMove move);
    public signal void ended ();

    public ChessPlayer white
    {
        get { return move_stack.data.white; }
    }
    public ChessPlayer black
    {
        get { return move_stack.data.black; }
    }
    public ChessPlayer current_player
    {
        get { return move_stack.data.current_player; }
    }

    public ChessGame ()
    {
        is_started = false;
        move_stack.prepend (new ChessState ());
        result = ChessResult.IN_PROGRESS;

        white.do_move.connect (move_cb);
        white.do_move_with_coords.connect (move_with_coords_cb);
        white.do_resign.connect (resign_cb);
        white.do_claim_draw.connect (claim_draw_cb);
        black.do_move.connect (move_cb);
        black.do_move_with_coords.connect (move_with_coords_cb);
        black.do_resign.connect (resign_cb);
        black.do_claim_draw.connect (claim_draw_cb);
    }

    private bool move_cb (ChessPlayer player, string move, bool apply)
    {
        return do_move (player, move, -1, -1, -1, -1, apply);
    }

    private bool move_with_coords_cb (ChessPlayer player, int r0, int f0, int r1, int f1, bool apply)
    {
        return do_move (player, null, r0, f0, r1, f1, apply);
    }

    private bool do_move (ChessPlayer player, string? move, int r0, int f0, int r1, int f1, bool apply)
    {
        if (!is_started)
            return false;
        if (player != current_player)
            return false;

        var state = move_stack.data.copy ();
        state.number++;
        if (move != null)
        {
            if (!state.move (move, apply))
                return false;
        }
        else
        {
            if (!state.move_with_coords (r0, f0, r1, f1, apply))
                return false;
        }

        if (!apply)
            return true;

        move_stack.prepend (state);
        if (state.last_move.victim != null)
            state.last_move.victim.died ();
        state.last_move.piece.moved ();
        if (state.last_move.moved_rook != null)
            state.last_move.moved_rook.moved ();
        moved (state.last_move);

        current_player.start_turn ();
        turn_started (current_player);

        return true;
    }

    private bool resign_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        if (player == white)
            stop (ChessResult.BLACK_WON, ChessRule.RESIGN);
        else
            stop (ChessResult.WHITE_WON, ChessRule.RESIGN);

        return true;
    }

    private bool claim_draw_cb (ChessPlayer player)
    {
        if (!is_started)
            return false;

        // FIXME: Check if can

        stop (ChessResult.DRAW, ChessRule.FIFTY_MOVES);

        return true;
    }

    public void start ()
    {
        if (is_started)
            return;
        is_started = true;

        reset ();

        started ();
        current_player.start_turn ();
        turn_started (current_player);
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
    
        return state.board[rank, file];
    }

    public uint n_moves
    {
        get { return move_stack.length() - 1; }
    }

    private void reset ()
    {
        result = ChessResult.IN_PROGRESS;
        var state = move_stack.data;
        move_stack = null;
        move_stack.prepend (state);
    }

    private void stop (ChessResult result, ChessRule rule)
    {
        this.result = result;
        this.rule = rule;
        is_started = false;
        ended ();
    }
}
