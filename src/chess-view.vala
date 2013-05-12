public abstract class ChessView : Gtk.DrawingArea
{
    private ChessScene _scene;
    public ChessScene scene
    {
        get { return _scene; }
        set
        {
            _scene = value;
            _scene.changed.connect (scene_changed_cb);
            queue_draw ();
        }
    }

    private void scene_changed_cb (ChessScene scene)
    {
        queue_draw ();
    }
}
