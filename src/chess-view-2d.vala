private class ChessView2D : ChessView
{
    private int border = 6;
    private int square_size;
    private Cairo.ImageSurface? model_surface;
    private string loaded_theme_name = "";
    
    private double border_size
    {
        get { return square_size / 2; }
    }
    
    public ChessView2D ()
    {
        add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
    }

    public override bool configure_event (Gdk.EventConfigure event)
    {
        int short_edge = int.min (get_allocated_width (), get_allocated_height ());
            
        square_size = (int) Math.floor ((short_edge - 2 * border) / 9.0);

        return true;
    }

    private void render_piece (Cairo.Context c, string name, int offset)
    {
        Rsvg.Handle handle;
        try
        {
            handle = new Rsvg.Handle.from_file (Path.build_filename (Config.PKGDATADIR, "pieces", options.theme_name, name + ".svg", null));
        }
        catch (Error e)
        {
            stderr.printf ("Failed to load piece svg: %s", e.message);
            return;
        }
        c.save ();
        c.translate (square_size * offset, 0);
        c.scale ((double) square_size / handle.width, (double) square_size / handle.height);
        handle.render_cairo (c);
        c.restore ();
    }
    
    private void load_theme ()
    {
        /* Skip if already loaded */
        if (options.theme_name == loaded_theme_name && model_surface != null && square_size == model_surface.get_height ())
            return;

        model_surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, 12 * (int) square_size, square_size);

        var c = new Cairo.Context (model_surface);
        render_piece (c, "whitePawn", 0);
        render_piece (c, "whiteRook", 1);
        render_piece (c, "whiteKnight", 2);
        render_piece (c, "whiteBishop", 3);
        render_piece (c, "whiteQueen", 4);
        render_piece (c, "whiteKing", 5);
        render_piece (c, "blackPawn", 6);
        render_piece (c, "blackRook", 7);
        render_piece (c, "blackKnight", 8);
        render_piece (c, "blackBishop", 9);
        render_piece (c, "blackQueen", 10);
        render_piece (c, "blackKing", 11);
        loaded_theme_name = options.theme_name;
    }

    public override bool draw (Cairo.Context c)
    {
        load_theme ();

        c.translate (get_allocated_width () / 2, get_allocated_height () / 2);
        //c.scale (s, s);
        c.rotate (Math.PI * options.board_angle / 180.0);

        int bord_size = (int) Math.ceil (square_size * 4 + border_size);
        c.set_source_rgb (0x2e/255.0, 0x34/255.0, 0x36/255.0);
        c.rectangle (-bord_size, -bord_size, bord_size * 2, bord_size * 2);
        c.fill ();

        var selected_piece = options.get_selected_piece ();
        if (options.move_number != -1)
            selected_piece = null;
        int selected_offset = 0;
        if (selected_piece != null)
        {
            selected_offset = selected_piece.type;
            if (selected_piece.color == Color.BLACK)
                selected_offset += 6;
        }

        for (int file = 0; file < 8; file++)
        {
            for (int rank = 0; rank < 8; rank++)
            {
                int x = (int) ((file - 4) * square_size);
                int y = (int) ((3 - rank) * square_size);
                
                bool selected = false;
                if (options.move_number == -1 && options.selected_rank == rank && options.selected_file == file)
                    selected = true;

                c.rectangle (x, y, square_size, square_size);
                if ((file + rank) % 2 == 0)
                {
                    if (selected)
                        c.set_source_rgb (0x73/255.0, 0xd2/255.0, 0x16/255.0);
                    else
                        c.set_source_rgb (0xba/255.0, 0xbd/255.0, 0xb6/255.0);
                }
                else
                {
                    if (selected)
                        c.set_source_rgb (0x8a/255.0, 0xe2/255.0, 0x34/255.0);
                    else
                        c.set_source_rgb (0xee/255.0, 0xee/255.0, 0xec/255.0);
                }
                c.fill ();
            }
        }

        if (options.show_numbering)
        {
            string[] files = { "a", "b", "c", "d", "e", "f", "g", "h" };
            string[] ranks = { "8", "7", "6", "5", "4", "3", "2", "1" };

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
        }

        if (options.game == null)
            return true;

        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                c.save ();
                c.translate ((file - 4) * square_size, (3 - rank) * square_size);
                c.translate (square_size / 2, square_size / 2);
                c.rotate (-Math.PI * options.board_angle / 180.0);

                bool can_take = false;
                if (selected_piece != null && options.show_move_hints &&
                    selected_piece.player.move_with_coords (options.selected_rank, options.selected_file, rank, file, false))
                    can_take = true;

                /* Draw the piece in this square */
                ChessPiece? piece = options.game.get_piece (rank, file, options.move_number);
                if (piece != null)
                    draw_piece (c, piece, can_take ? 0.8 : 1.0);

                /* Draw shadow piece on squares that can be moved to */
                if (can_take)
                    draw_piece (c, selected_piece, 0.1);

                c.restore ();
            }
        }
 
        return true;
    }
    
    private void draw_piece (Cairo.Context c, ChessPiece piece, double alpha)
    {
        c.save ();

        if (options.board_side == "facetoface" && piece.color == Color.BLACK)
            c.rotate (Math.PI);
        c.translate (-square_size / 2, -square_size / 2);

        int offset = piece.type;
        if (piece.color == Color.BLACK)
            offset += 6;
        c.set_source_surface (model_surface, -offset * square_size, 0);
        c.rectangle (0, 0, square_size, square_size);
        c.clip ();
        c.paint_with_alpha (alpha);

        c.restore ();
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (options.game == null || event.button != 1)
            return false;

        int file = (int) Math.floor((event.x - 0.5 * get_allocated_width () + square_size * 4) / square_size);
        int rank = 7 - (int) Math.floor((event.y - 0.5 * get_allocated_height () + square_size * 4) / square_size);

        // FIXME: Use proper Cairo rotation matrix
        if (options.board_angle == 180.0)
        {
            rank = 7 - rank;
            file = 7 - file;
        }

        if (file < 0 || file >= 8 || rank < 0 || rank >= 8)
            return false;

        options.select_square (file, rank);

        return true;
    }
}
