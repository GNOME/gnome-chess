public class ChessViewOptions : GLib.Object
{
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
            selected_rank = -1;
            selected_file = -1;
            changed ();
        }
    }

    public ChessPiece? get_selected_piece ()
    {
        if (game != null && selected_rank >= 0)
            return game.get_piece (selected_rank, selected_file, move_number);
        return null;
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
            changed ();
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

    private string _move_format = "human";
    public string move_format
    {
       get { return _move_format; }
       set { _move_format = value; changed (); }
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

        changed ();
    }
}
