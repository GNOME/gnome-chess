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

public class ChessView : Gtk.DrawingArea
{
    private int border = 6;
    private int square_size;
    private int selected_square_size;
    private Cairo.ImageSurface? model_surface;
    private Cairo.Surface? selected_model_surface;
    private string loaded_theme_name = "";

    private Gtk.GestureClick click_controller;          // for keeping in memory

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

    private double border_size
    {
        get { return square_size / 2; }
    }

    construct
    {
        size_allocate.connect (on_size_allocate);

        init_mouse ();
    }

    private inline void on_size_allocate (int width, int height)
    {
        int short_edge = int.min (width, height);       // TODO width or get_size() result?

        square_size = (int) Math.floor ((short_edge - 2 * border) / 9.0);
        var extra = square_size * 0.1;
        if (extra < 3)
            extra = 3;
        selected_square_size = square_size + 2 * (int) (extra + 0.5);
    }

    private void render_piece (Cairo.Context c1, Cairo.Context c2, string name, int offset)
    {
        Rsvg.Handle handle;
        try
        {
            handle = new Rsvg.Handle.from_file (Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, name + ".svg", null));
        }
        catch (Error e)
        {
            stderr.printf ("Failed to load piece svg: %s\n", e.message);
            return;
        }

        c1.save ();
        c1.translate (square_size * offset, 0);
        c1.scale ((double) square_size / handle.width, (double) square_size / handle.height);
        handle.render_cairo (c1);
        c1.restore ();

        c2.save ();
        c2.translate (selected_square_size * offset, 0);
        c2.scale ((double) selected_square_size / handle.width, (double) selected_square_size / handle.height);
        handle.render_cairo (c2);
        c2.restore ();
    }

    private void load_theme (Cairo.Context c)
    {
        /* Skip if already loaded */
        if (scene.theme_name == loaded_theme_name && model_surface != null && square_size == model_surface.get_height ())
            return;

        model_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, 12 * square_size, square_size);
        selected_model_surface = new Cairo.Surface.similar (c.get_target (), Cairo.Content.COLOR_ALPHA, 12 * selected_square_size, selected_square_size);

        var c1 = new Cairo.Context (model_surface);
        var c2 = new Cairo.Context (selected_model_surface);
        render_piece (c1, c2, "whitePawn", 0);
        render_piece (c1, c2, "whiteRook", 1);
        render_piece (c1, c2, "whiteKnight", 2);
        render_piece (c1, c2, "whiteBishop", 3);
        render_piece (c1, c2, "whiteQueen", 4);
        render_piece (c1, c2, "whiteKing", 5);
        render_piece (c1, c2, "blackPawn", 6);
        render_piece (c1, c2, "blackRook", 7);
        render_piece (c1, c2, "blackKnight", 8);
        render_piece (c1, c2, "blackBishop", 9);
        render_piece (c1, c2, "blackQueen", 10);
        render_piece (c1, c2, "blackKing", 11);

        loaded_theme_name = scene.theme_name;
    }

    public override bool draw (Cairo.Context c)
    {
        load_theme (c);

        c.translate (get_allocated_width () / 2, get_allocated_height () / 2);
        //c.scale (s, s);
        c.rotate (Math.PI * scene.board_angle / 180.0);

        int board_size = (int) Math.ceil (square_size * 4 + border_size);
        c.set_source_rgb (0x2e/255.0, 0x34/255.0, 0x36/255.0);
        c.rectangle (-board_size, -board_size, board_size * 2, board_size * 2);
        c.fill ();

        for (int file = 0; file < 8; file++)
        {
            for (int rank = 0; rank < 8; rank++)
            {
                int x = (int) ((file - 4) * square_size);
                int y = (int) ((3 - rank) * square_size);

                c.rectangle (x, y, square_size, square_size);
                if ((file + rank) % 2 == 0)
                    c.set_source_rgb (0xba/255.0, 0xbd/255.0, 0xb6/255.0);
                else
                    c.set_source_rgb (0xee/255.0, 0xee/255.0, 0xec/255.0);
                c.fill ();
            }
        }

        if (scene.show_numbering)
        {
            /* Files are centered individiual glyph width and combined glyph height,
             * ranks are centered on individual glyph widths and heights */

            c.set_source_rgb (0x88/255.0, 0x8a/255.0, 0x85/255.0);
            c.set_font_size (border_size * 0.6);
            c.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);

            Cairo.TextExtents extents;
            c.text_extents ("abcdefgh", out extents);
            double y_offset = (square_size / 2 - extents.height) / 2 + extents.height + extents.y_bearing;
            double top = -(square_size * 4 + y_offset);
            double bottom = square_size * 4 + border_size - y_offset;

            double file_offset = -(square_size * 3.5);
            double rank_offset = -(square_size * 3.5);

            string[] files;
            string[] ranks;

            Cairo.Matrix matrix = c.get_matrix ();

            if (scene.board_angle == 180.0)
            {
                files = { "h", "g", "f", "e", "d", "c", "b", "a" };
                ranks = { "1", "2", "3", "4", "5", "6", "7", "8" };

                matrix.scale (-1, -1);
            }
            else
            {
                files = { "a", "b", "c", "d", "e", "f", "g", "h" };
                ranks = { "8", "7", "6", "5", "4", "3", "2", "1" };
            }

            c.save ();
            c.set_matrix (matrix);

            for (int i = 0; i < 8; i++)
            {
                c.text_extents (ranks[i], out extents);

                /* Black file */
                c.save ();
                c.move_to (file_offset - extents.width / 2, top);
                c.show_text (files[i]);
                c.restore ();

                /* White file */
                c.save ();
                c.move_to (file_offset - extents.width / 2, bottom);
                c.show_text (files[i]);
                c.restore ();

                c.text_extents (ranks[i], out extents);
                y_offset = -(extents.y_bearing + extents.height / 2);

                /* Left rank */
                c.save ();
                c.move_to (-((double) square_size * 4 + border_size - (border_size - extents.width) / 2), rank_offset + y_offset);
                c.show_text (ranks[i]);
                c.restore ();

                /* Right rank */
                c.save ();
                c.move_to ((double) square_size * 4 + (border_size - extents.width) / 2, rank_offset + y_offset);
                c.show_text (ranks[i]);
                c.restore ();

                file_offset += square_size;
                rank_offset += square_size;
            }

            c.restore ();
        }

        /* Draw pause overlay */
        if (scene.game.should_show_paused_overlay)
        {
            c.rotate (Math.PI * scene.board_angle / 180.0);
            draw_paused_overlay (c);
            return true;
        }

        /* Draw the pieces */
        foreach (var model in scene.pieces)
        {
            c.save ();
            c.translate ((model.x - 4) * square_size, (3 - model.y) * square_size);
            c.translate (square_size / 2, square_size / 2);
            c.rotate (-Math.PI * scene.board_angle / 180.0);

            draw_piece (c,
                        model.is_selected ? selected_model_surface : model_surface,
						model.is_selected ? selected_square_size : square_size,
                        model.piece, model.under_threat && scene.show_move_hints ? 0.8 : 1.0);

            c.restore ();
        }

        /* Draw shadow piece on squares that can be moved to */
        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                if (scene.show_move_hints && scene.can_move (rank, file))
                {
                    c.save ();
                    c.translate ((file - 4) * square_size, (3 - rank) * square_size);
                    c.translate (square_size / 2, square_size / 2);
                    c.rotate (-Math.PI * scene.board_angle / 180.0);

                    draw_piece (c, model_surface, square_size, scene.get_selected_piece (), 0.1);

                    c.restore ();
                }
            }
        }

        return true;
    }

    private void draw_piece (Cairo.Context c, Cairo.Surface surface, int size, ChessPiece piece, double alpha)
    {
        c.translate (-size / 2, -size / 2);

        int offset = piece.type;
        if (piece.color == Color.BLACK)
            offset += 6;
        c.set_source_surface (surface, -offset * size, 0);
        c.rectangle (0, 0, size, size);
        c.clip ();
        c.paint_with_alpha (alpha);
    }

    private inline void init_mouse ()
    {
        click_controller = new Gtk.GestureClick ();
        click_controller.pressed.connect (on_click);
        add_controller (click_controller);
    }

    private inline void on_click (Gtk.GestureClick _click_controller, int n_press, double event_x, double event_y)
    {
        uint button = _click_controller.get_button ();
        if (scene.game == null || button != Gdk.BUTTON_PRIMARY || scene.game.should_show_paused_overlay)
            return;

        // If the game is over, disable selection of pieces
        if (scene.game.result != ChessResult.IN_PROGRESS)
            return;

        int file = (int) Math.floor ((event_x - 0.5 * get_allocated_width () + square_size * 4) / square_size);
        int rank = 7 - (int) Math.floor ((event_y - 0.5 * get_allocated_height () + square_size * 4) / square_size);

        // FIXME: Use proper Cairo rotation matrix
        if (scene.board_angle == 180.0)
        {
            rank = 7 - rank;
            file = 7 - file;
        }

        if (file < 0 || file >= 8 || rank < 0 || rank >= 8)
            return;

        scene.select_square (file, rank);
    }

    private void scene_changed_cb (ChessScene scene)
    {
        queue_draw ();
    }

    protected void draw_paused_overlay (Cairo.Context c)
    {
        c.save ();

        c.set_source_rgba (0, 0, 0, 0.75);
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
