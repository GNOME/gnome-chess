/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

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
