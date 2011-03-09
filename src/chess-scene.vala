public class ChessModel
{
    public ChessPiece piece;
    public double x;
    public double y;
    public double target_x;
    public double target_y;
    public bool under_threat;
    public bool is_selected;

    public bool moving 
    {
        get { return x != target_x || y != target_y; }
    }

    public ChessModel (ChessPiece piece, double x, double y)
    {
        this.piece = piece;
        this.x = this.target_x = x;
        this.y = this.target_y = y;        
    }

    public bool move_to (double x, double y)
    {
        if (target_x == x && target_y == y)
            return false;

        target_x = x;
        target_y = y;

        return true;
    }

    public bool animate (double timestep)
    {
        if (!moving)
            return false;

        x = update_position (timestep, x, target_x);
        y = update_position (timestep, y, target_y);
        return true;
    }

    private double update_position (double timestep, double value, double target)
    {
        var distance = Math.fabs (target - value);
        var step = timestep * 4.0;

        if (step > distance)
            step = distance;

        if (target > value)
            return value + step;
        else
            return value - step;
    }
}

public class ChessScene : Object
{
    public List<ChessModel> pieces = null;
    private bool _can_move[64];

    public bool animating = false;
    private Timer animation_timer;
    private double animation_time;

    public signal void changed ();

    public int selected_rank = -1;
    public int selected_file = -1;

    private ChessGame? _game = null;
    public ChessGame? game
    {
        get { return _game; }
        set
        {
            _game = value;
            _move_number = -1;
            selected_rank = -1;
            selected_file = -1;
            _game.moved.connect (moved_cb);
            update_board ();
        }
    }

    public ChessPiece? get_selected_piece ()
    {
        if (game == null || selected_rank < 0)
            return null;
        return game.get_piece (selected_rank, selected_file, move_number);
    }

    private int _move_number = -1;
    public int move_number
    {
        get { return _move_number; }
        set
        {
            if (_move_number == value)
                return;
            _move_number = value;
            update_board ();
        }
    }

    private bool _show_numbering = true;
    public bool show_numbering
    {
         get { return _show_numbering; }
         set { _show_numbering = value; changed (); }
    }

    private bool _show_move_hints = true;
    public bool show_move_hints
    {
         get { return _show_move_hints; }
         set { _show_move_hints = value; changed (); }
    }

    private string _theme_name = "simple";
    public string theme_name
    {
        get { return _theme_name; }
        set { _theme_name = value; changed (); }
    }

    private bool _show_3d_smooth = false;
    public bool show_3d_smooth
    {
         get { return _show_3d_smooth; }
         set { _show_3d_smooth = value; changed (); }
    }

    private string _board_side = "human";
    public string board_side
    {
         get { return _board_side; }
         set { _board_side = value; changed (); }
    }

    public double board_angle
    {
         get
         {
             switch (board_side)
             {
             default:
             case "white":
             case "facetoface":
                 return 0.0;
             case "black":
                 return 180.0;
             case "human":
                 return 0.0; // FIXME
             case "current":
                 return game.current_player.color == Color.WHITE ? 0.0 : 180.0;
             }
         }
    }

    private string _move_format = "human";
    public string move_format
    {
        get { return _move_format; }
        set { _move_format = value; changed (); }
    }
    
    public ChessScene ()
    {
        animation_timer = new Timer ();
    }

    public void select_square (int file, int rank)
    {
        if (game == null)
            return;

        /* Can only control when showing the current move */
        if (move_number != -1)
            return;

        ChessPiece? piece = game.get_piece (rank, file, move_number);

        /* Deselect by clicking on the same square */
        if (file == selected_file && rank == selected_rank)
        {
            selected_rank = selected_file = -1;
        }
        /* Select new piece */
        else if (piece != null && piece.player == game.current_player)
        {
            selected_rank = rank;
            selected_file = file;
        }
        /* Move to this square */
        else if (selected_file != -1)
        {
            if (game.current_player.move_with_coords(selected_rank, selected_file, rank, file))
                selected_rank = selected_file = -1;            
        }
        
        update_board ();
        changed ();
    }

    private void moved_cb (ChessGame game, ChessMove move)
    {
        update_board ();
    }
    
    private ChessModel? find_model (ChessPiece piece)
    {
        foreach (var model in pieces)
            if (model.piece == piece)
                return model;
        return null;
    }

    private void update_board ()
    {
        if (game == null)
            return;

        var board_changed = false;
        var need_animation = false;
        List<ChessModel> new_pieces = null;
        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                var can_move = false;
                if (selected_rank >= 0 && move_number == -1 &&
                    game.current_player.move_with_coords (selected_rank, selected_file, rank, file, false))
                    can_move = true;
                _can_move[rank * 8 + file] = can_move;

                var piece = game.get_piece (rank, file, move_number);
                if (piece == null)
                    continue;
                var model = find_model (piece);
                if (model == null)
                {
                    model = new ChessModel (piece, (double) file, (double) rank);
                    board_changed = true;
                }
                model.under_threat = can_move;

                if (model.move_to ((double) file, (double) rank))
                {
                    board_changed = true;
                    need_animation = true;
                }

                if (move_number == -1 && rank == selected_rank && file == selected_file)
                    model.is_selected = true;
                else
                    model.is_selected = false;

                new_pieces.append (model);
            }
        }
        /* If only removed pieces then the lengths will be different */
        if (new_pieces.length () != pieces.length ())
            board_changed = true;

        if (!board_changed)
            return;
            
        /* Have to do this as Vala can't assign the value, and copy doesn't ref the objects */
        pieces = null;
        foreach (var model in new_pieces)
            pieces.append (model);
        changed ();

        if (need_animation && !animating)
        {
            animating = true;
            animation_timer.start ();
            animation_time = 0;
            game.add_hold ();

            /* Animate every 10ms (up to 100fps) */
            Timeout.add (10, animate_cb, Priority.DEFAULT_IDLE);
        }
    }

    public bool can_move (int rank, int file)
    {
        return _can_move[rank * 8 + file];
    }

    private bool animate_cb ()
    {
        /* Get the duration since the last tick */
        var old_time = animation_time;
        animation_time = animation_timer.elapsed ();
        var timestep = animation_time - old_time;

        var animate_count = 0;
        foreach (var model in pieces)
        {
            if (model.animate (timestep))
                animate_count++;
        }
        animating = animate_count > 0;

        changed ();

        if (animating)
            return true;

        animating = false;
        game.remove_hold ();
        return false;
    }
}
