using GL;
using GLU;

private class ChessView3D : ChessView
{
    private int border = 6;
    private int square_size;
    private TDSModel pawn_model;
    private TDSModel knight_model;
    private TDSModel bishop_model;
    private TDSModel rook_model;
    private TDSModel queen_model;
    private TDSModel king_model;
    private GLfloat[] board_vertices;
    private GLushort[] board_quads;

    private GLfloat SQUARE_WIDTH;
    private GLfloat BOARD_DEPTH;
    private GLfloat BOARD_BORDER;
    private GLfloat BOARD_CHAMFER;
    private GLfloat BOARD_INNER_WIDTH;
    private GLfloat BOARD_OUTER_WIDTH;
    private GLfloat OFFSET;

    public ChessView3D ()
    {
        SQUARE_WIDTH = 10.0f;
        BOARD_DEPTH = 3.0f;
        BOARD_BORDER = 5.0f;
        BOARD_CHAMFER = 2.0f;
        BOARD_INNER_WIDTH = (SQUARE_WIDTH * 8.0f);
        BOARD_OUTER_WIDTH = (BOARD_INNER_WIDTH + BOARD_BORDER * 2.0f);
        OFFSET            = (BOARD_OUTER_WIDTH * 0.5f);

        add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
        var gl_config = new Gdk.GLConfig.by_mode (Gdk.GLConfigMode.RGB | Gdk.GLConfigMode.DEPTH | Gdk.GLConfigMode.DOUBLE | Gdk.GLConfigMode.ACCUM);
        Gtk.WidgetGL.set_gl_capability (this, gl_config, null, true, Gdk.GLRenderType.RGBA_TYPE);
        try
        {
            pawn_model = new TDSModel (File.new_for_path ("data/pawn.3ds"));
            knight_model = new TDSModel (File.new_for_path ("data/knight.3ds"));
            bishop_model = new TDSModel (File.new_for_path ("data/bishop.3ds"));
            rook_model = new TDSModel (File.new_for_path ("data/rook.3ds"));
            queen_model = new TDSModel (File.new_for_path ("data/queen.3ds"));
            king_model = new TDSModel (File.new_for_path ("data/king.3ds"));
        }
        catch (GLib.Error e)
        {
        }
        create_board ();
    }
    
    private void create_board ()
    {
        /* Board vertices
         * (lower 12-15 are under 8-11)
         *
         * a b c         d e f
         *
         * 8-----------------9  g
         * |\               /|
         * | 4-------------5 |  h
         * | |             | |
         * | | 0---------1 | |  i
         * | | |         | | |
         * | | |         | | |
         * | | 3---------2 | |  j
         * | |             | |
         * | 7-------------6 |  k
         * |/               \|
         * 11---------------10  l
         *
         *     |- board -|
         *        width
         */
        var a = 0.0f;
        var b = BOARD_CHAMFER;
        var c = BOARD_BORDER;
        var d = c + (SQUARE_WIDTH * 8.0f);
        var e = d + BOARD_BORDER - BOARD_CHAMFER;
        var f = d + BOARD_BORDER;
        var l = 0.0f;
        var k = -BOARD_CHAMFER;
        var j = -BOARD_BORDER;
        var i = j - (SQUARE_WIDTH * 8.0f);
        var h = i - BOARD_BORDER + BOARD_CHAMFER;
        var g = i - BOARD_BORDER;
        board_vertices = {c, 0.0f, i,  d, 0.0f, i,
                          d, 0.0f, j,  c, 0.0f, j,
                          b, 0.0f, h,  e, 0.0f, h,
                          e, 0.0f, k,  b, 0.0f, k,
                          a, -BOARD_CHAMFER, g,  f, -BOARD_CHAMFER, g,
                          f, -BOARD_CHAMFER, l,  a, -BOARD_CHAMFER, l,
                          a, -BOARD_DEPTH, g,  f, -BOARD_DEPTH, g,  f, -BOARD_DEPTH, l,  a, -BOARD_DEPTH, l};
        board_quads = {0, 1, 5, 4,  0, 4, 7, 3,  3, 7, 6, 2,  2, 6, 5, 1,
                      4, 5, 9, 8,  4, 8, 11, 7,  7, 11, 10, 6,  6, 10, 9, 5};
    }

    public override bool configure_event (Gdk.EventConfigure event)
    {
        int short_edge = int.min (allocation.width, allocation.height);

        square_size = (int) Math.floor ((short_edge - 2 * border) / 9.0);

        var drawable = Gtk.WidgetGL.get_gl_drawable (this);
        if (drawable.gl_begin (Gtk.WidgetGL.get_gl_context (this)))
        {
            glViewport (0, 0, (GLsizei) allocation.width, (GLsizei) allocation.height);
            drawable.gl_end ();
        }

        return true;
    }

    private void accFrustum (GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat near, GLfloat far,
                             GLfloat pixdx, GLfloat pixdy, GLfloat eyedx, GLfloat eyedy, GLfloat focus)
    {
        var xwsize = right - left;
        var ywsize = top - bottom;
        var dx = -(pixdx * xwsize / allocation.width + eyedx * near/focus);
        var dy = -(pixdy * ywsize / allocation.height + eyedy * near/focus);

        glFrustum (left + dx, right + dx, bottom + dy, top + dy, near, far);
        glTranslatef (-eyedx, -eyedy, 0.0f);
    }

    private void accPerspective (GLfloat fovy, GLfloat aspect,
                                 GLfloat near, GLfloat far,
                                 GLfloat pixdx, GLfloat pixdy,
                                 GLfloat eyedx, GLfloat eyedy, GLfloat focus)
    {
        var fov2 = ((fovy * (GLfloat) Math.PI) / 180.0f) / 2.0f;
        var top = near / ((GLfloat) Math.cos (fov2) / (GLfloat) Math.sin (fov2));
        var bottom = -top;
        var right = top * aspect;
        var left = -right;
        accFrustum (left, right, bottom, top, near, far, pixdx, pixdy, eyedx, eyedy, focus);
    }

    public override bool draw (Cairo.Context c)
    {
        var drawable = Gtk.WidgetGL.get_gl_drawable (this);
        GLfloat[] jitters = {0.0033922635f, 0.3317967229f, 0.2806016275f, -0.2495619123f, -0.273817106f, -0.086844639f};

        if (!drawable.gl_begin (Gtk.WidgetGL.get_gl_context (this)))
            return true;

        var n_passes = 1;
        if (options.show_3d_smooth)
        {
            glClear (GL_ACCUM_BUFFER_BIT);
            n_passes = 3;
        }

        for (var i = 0; i < n_passes; i++)
        {
            var bg = style.bg[state];
            glClearColor (bg.red / 65535.0f, bg.green / 65535.0f, bg.blue / 65535.0f, 1.0f);
            glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            glEnable (GL_DEPTH_TEST);

            glMatrixMode (GL_PROJECTION);
            glLoadIdentity ();
            if (options.show_3d_smooth)
                accPerspective (60.0f, (float) allocation.width / allocation.height, 0.1f, 1000, jitters[i*2], jitters[i*2+1], 0, 0, 1);
            else
                gluPerspective (60.0f, (float) allocation.width / allocation.height, 0.1f, 1000);

            glMatrixMode(GL_MODELVIEW);
            transform_camera ();

            GLfloat[] pos = { 100.0f, 100.0f, 100.0f, 1.0f };
            glLightfv (GL_LIGHT0, GL_POSITION, pos);
            glEnable (GL_LIGHTING);
            glEnable (GL_LIGHT0);

            draw_board ();
            draw_pieces ();

            if (options.show_3d_smooth)
                glAccum (GL_ACCUM, 1.0f / n_passes);
        }

        if (options.show_3d_smooth)
            glAccum (GL_RETURN, 1);

        if (drawable.is_double_buffered ())
            drawable.swap_buffers ();
        else
            glFlush ();

        drawable.gl_end ();

        return true;
    }

    private void draw_board ()
    {
        glPushMatrix ();
        glTranslatef(-OFFSET, 0.0f, OFFSET);

        glEnable (GL_COLOR_MATERIAL);
        glColor3f (0x2e / 255f, 0x34 / 255f, 0x36 / 255f);
        glNormal3f (0.0f, 1.0f, 0.0f);
        glEnableClientState (GL_VERTEX_ARRAY);
        glVertexPointer (3, GL_FLOAT, 0, board_vertices);
        glDrawElements (GL_QUADS, (GLsizei) board_quads.length, GL_UNSIGNED_SHORT, board_quads);
        glDisableClientState (GL_VERTEX_ARRAY);

        var selected_piece = options.get_selected_piece ();

        glNormal3f (0.0f, 1.0f, 0.0f);
        for (var rank = 0; rank < 8; rank++)
            for (var file = 0; file < 8; file++)
            {
                bool selected = false;
                bool hinted = false;
                if (options.move_number == -1 && options.selected_rank == rank && options.selected_file == file)
                    selected = true;
                else if (options.move_number == -1 && options.show_move_hints && selected_piece != null && selected_piece.player.move_with_coords (options.selected_rank, options.selected_file, rank, file, false))
                    hinted = true;

                if ((file + rank) % 2 == 0)
                {
                    if (selected)
                        glColor3f (0x73 / 255f, 0xd2 / 255f, 0x16 / 255f);
                    else if (hinted)
                        glColor3f (0x34 / 255f, 0x65 / 255f, 0xa4 / 255f);
                    else
                        glColor3f (0xee / 255f, 0xee / 255f, 0xec / 255f);
                }
                else
                {
                    if (selected)
                        glColor3f (0x8a / 255f, 0xe2 / 255f, 0x34 / 255f);
                    else if (hinted)
                        glColor3f (0x20 / 255f, 0x4a / 255f, 0x87 / 255f);
                    else
                        glColor3f (0xba / 255f, 0xbd / 255f, 0xb6 / 255f);
                }

                glBegin (GL_QUADS);
                GLfloat x0 = BOARD_BORDER + (file * SQUARE_WIDTH);
                GLfloat x1 = x0 + SQUARE_WIDTH;
                GLfloat z0 = BOARD_BORDER + (rank * SQUARE_WIDTH);
                GLfloat z1 = z0 + SQUARE_WIDTH;

                glVertex3f(x0, 0.0f, -z0);
                glVertex3f(x1, 0.0f, -z0);
                glVertex3f(x1, 0.0f, -z1);
                glVertex3f(x0, 0.0f, -z1);
                glEnd ();
            }
        glDisable (GL_COLOR_MATERIAL);
        glPopMatrix ();
    }
    
    private void draw_pieces ()
    {
        if (options.game == null)
            return;

        glEnable (GL_COLOR_MATERIAL);
        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                ChessPiece? piece = options.game.get_piece (rank, file, options.move_number);
                if (piece == null)
                    continue;

                switch (piece.player.color)
                {
                case Color.WHITE:
                    glColor3f (0.8f, 0.8f, 0.8f);
                    break;
                case Color.BLACK:
                    glColor3f (0.2f, 0.2f, 0.2f);
                    break;
                }

                glPushMatrix ();
                glTranslatef ((file - 4) * SQUARE_WIDTH + SQUARE_WIDTH / 2, 0.0f, (4 - rank) * SQUARE_WIDTH - SQUARE_WIDTH / 2);

                switch (piece.type)
                {
                case PieceType.PAWN:
                    pawn_model.render ();
                    break;
                case PieceType.ROOK:
                    rook_model.render ();
                    break;
                case PieceType.KNIGHT:
                    knight_model.render ();
                    break;
                case PieceType.BISHOP:
                    bishop_model.render ();
                    break;
                case PieceType.QUEEN:
                    queen_model.render ();
                    break;
                case PieceType.KING:
                    king_model.render ();
                    break;
                }

                glPopMatrix ();
            }
        }

        glDisable (GL_COLOR_MATERIAL);
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (options.game == null || event.button != 1)
            return false;

        var drawable = Gtk.WidgetGL.get_gl_drawable (this);

        if (!drawable.gl_begin (Gtk.WidgetGL.get_gl_context (this)))
            return true;

        /* Don't render to screen, just select */
        GLuint buffer[20];
        glSelectBuffer((GLsizei) buffer.length, buffer);
        glRenderMode(GL_SELECT);

        glInitNames();

        /* Create pixel picking region near cursor location */
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        GLint[] viewport = {0, 0, (GLint) allocation.width, (GLint) allocation.height};
        gluPickMatrix(event.x, ((float) allocation.height - event.y), 1.0, 1.0, viewport);
        gluPerspective(60.0, (float) allocation.width / (float) allocation.height, 0, 1);

        /* Draw the squares that can be selected */
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        transform_camera();
        glTranslatef(-OFFSET, 0.0f, OFFSET);
        for (var rank = 0; rank < 8; rank++)
        {
            glPushName(rank);

            for (var file = 0; file < 8; file++)
            {
                glPushName(file);

                glBegin(GL_QUADS);
                var x0 = BOARD_BORDER + (file * SQUARE_WIDTH);
                var x1 = x0 + SQUARE_WIDTH;
                var z0 = BOARD_BORDER + (rank * SQUARE_WIDTH);
                var z1 = z0 + SQUARE_WIDTH;

                glVertex3f(x0, 0.0f, -z0);
                glVertex3f(x1, 0.0f, -z0);
                glVertex3f(x1, 0.0f, -z1);
                glVertex3f(x0, 0.0f, -z1);
                glEnd();

                glPopName();
            }
            glPopName();
        }

        /* Render and check for hits */
        glFlush();
        var n_hits = glRenderMode(GL_RENDER);

        if (n_hits > 0)
        {
            var rank = buffer[3];
            var file = buffer[4];
            options.select_square (file, rank);
        }

        drawable.gl_end ();

        return true;
    }

    private void transform_camera ()
    {
        glLoadIdentity();
        gluLookAt(0.0, 80.0, 40.0,
                  0.0,  0.0, 5.0,
                  0.0,  1.0,  0.0);
    }
}
