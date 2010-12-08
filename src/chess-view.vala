public class ChessView : Gtk.DrawingArea
{
    private ChessViewOptions _options;
    public ChessViewOptions options
    {
        get { return _options; }
        set
        {
            _options = value;
            _options.changed.connect (options_changed_cb);
            queue_draw ();
        }
    }

    private void options_changed_cb (ChessViewOptions options)
    {
        queue_draw ();
    }
}
