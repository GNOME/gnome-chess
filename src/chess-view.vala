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

    protected void draw_paused_overlay (Cairo.Context c)
    {
        c.save ();

        /* Have to be opaque since I haven't figured out how to hide the pieces in 3D view */
        c.set_source_rgba (0, 0, 0, 1);
        c.paint ();

        c.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        c.set_font_size (get_allocated_width () * 0.125);

        var text = _("Paused");
        Cairo.TextExtents extents;
        c.text_extents (text, out extents);
        c.move_to (-extents.width / 2.0, extents.height / 2.0);
        c.set_source_rgb (1, 1, 1);
        c.show_text (text);

        c.restore ();
    }
}
