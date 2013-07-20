/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using GL;
using GLU;
using GLX;

private class ChessView3D : ChessView
{
    private GLX.Context context = (GLX.Context) null;
    private void *display;
    private Drawable drawable;

    private int border = 6;
    private int square_size;
    private TDSModel pawn_model;
    private TDSModel knight_model;
    private TDSModel bishop_model;
    private TDSModel rook_model;
    private TDSModel queen_model;
    private TDSModel king_model;
    private GLfloat[] board_vertices;
    private GLfloat[] board_normals;    
    private GLushort[] board_quads;

    private GLfloat SQUARE_WIDTH;
    private GLfloat BOARD_DEPTH;
    private GLfloat BOARD_BORDER;
    private GLfloat BOARD_CHAMFER;
    private GLfloat BOARD_INNER_WIDTH;
    private GLfloat BOARD_OUTER_WIDTH;
    private GLfloat OFFSET;
    
    private GLfloat white_piece_color[4];
    private GLfloat white_piece_specular[4];
    private GLfloat black_piece_color[4];
    private GLfloat black_piece_specular[4];

    private GLuint _board_texture = 0;
    private GLuint board_texture
    {
        get { if (_board_texture == 0) _board_texture = load_texture (Path.build_filename (PKGDATADIR, "textures", "board.png", null)); return _board_texture; }
    }

    private GLuint _numbering_texture = 0;
    private GLuint numbering_texture
    {
        get { if (_numbering_texture == 0) _numbering_texture = make_numbering_texture (); return _numbering_texture; }
    }

    private GLuint _piece_texture = 0;
    private GLuint piece_texture
    {
        get { if (_piece_texture == 0) _piece_texture = load_texture (Path.build_filename (PKGDATADIR, "textures", "piece.png", null)); return _piece_texture; }
    }

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
        realize.connect (realize_cb);
        unrealize.connect (unrealize_cb);

        white_piece_color = { 0.95f * 0.7f, 0.81f * 0.7f, 0.64f * 0.7f, 1.0f };
        white_piece_specular = { 0.95f, 0.81f, 0.64f, 1.0f };
        black_piece_color = { 0.62f * 0.7f, 0.45f * 0.7f, 0.28f * 0.7f, 1.0f };
        black_piece_specular = { 0.62f, 0.45f, 0.28f, 1.0f };

        double_buffered = false;
        try
        {
            pawn_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "pawn.3ds", null)));
            knight_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "knight.3ds", null)));
            bishop_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "bishop.3ds", null)));
            rook_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "rook.3ds", null)));
            queen_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "queen.3ds", null)));
            king_model = new TDSModel (File.new_for_path (Path.build_filename (PKGDATADIR, "pieces", "3d", "king.3ds", null)));
        }
        catch (Error e)
        {
        }
        create_board ();
    }

    private bool start_gl ()
    {
        GLX.Context null_context = (GLX.Context) null;
        if (context == null_context)
            return false;
        return glXMakeCurrent (display, drawable, context);
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
                          a, -BOARD_DEPTH, g,  f, -BOARD_DEPTH, g,
                          f, -BOARD_DEPTH, l,  a, -BOARD_DEPTH, l};
        board_normals = { 0.0f, 1.0f, 0.0f,  0.0f, 0.0f, -1.0f,
                          1.0f, 0.0f, 0.0f,  0.0f, 0.0f, 1.0f,
                         -1.0f, 0.0f, 0.0f,  0.0f, 0.707f, -0.707f,
                          0.707f, 0.707f, 0.0f,  0.0f, 0.707f,  0.707f,
                         -0.707f, 0.707f, 0.0f };
        board_quads = {0, 1, 5, 4, 0,  1, 2, 6, 5, 0,  2, 3, 7, 6, 0,  3, 0, 4, 7, 0,
                       4, 5, 9, 8, 5,  5, 6, 10, 9, 6,  6, 7, 11, 10, 7,  7, 4, 8, 11, 8,
                       8, 9, 13, 12, 1,  9, 10, 14, 13, 2,  10, 11, 15, 14, 3,  11, 8, 12, 15, 4};
    }

    private void realize_cb ()
    {
         int[] attributes = { GLX_RGBA,
                              GLX_RED_SIZE, 1,
                              GLX_GREEN_SIZE, 1,
                              GLX_BLUE_SIZE, 1,
                              GLX_DOUBLEBUFFER,
                              GLX_DEPTH_SIZE, 1,
                              GLX_ACCUM_RED_SIZE, 1,
                              GLX_ACCUM_GREEN_SIZE, 1,
                              GLX_ACCUM_BLUE_SIZE, 1,
                              0 }; /* NOTE: Should be None (from X11) but that is a pointer and Vala doesn't like that */
        drawable = Gdk.X11Window.get_xid (get_window ());
        display = Gdk.X11Display.get_xdisplay (get_window ().get_display ());
        var screen = Gdk.X11Screen.get_screen_number (get_screen ());
        var visual = glXChooseVisual (display, screen, attributes);
        if (visual == null)
            warning ("Failed to get GLX visual on display %p, screen %d", display, screen);
        else
        {
            context = glXCreateContext (display, visual, null, true);
            GLX.Context null_context = (GLX.Context) null;
            if (context == null_context)
                warning ("Failed to create GLX context");
        }
    }

    private void unrealize_cb ()
    {
        GLX.Context null_context = (GLX.Context) null;
        if (context == null_context)
            return;
    
        /* Wait for any pending GL calls to end */
        if (drawable == glXGetCurrentDrawable ())
        {
            glXWaitGL ();
            glXMakeCurrent (display, X.None, (GLX.Context) null);
        }

        glXDestroyContext (display, context);
    }

    public override bool configure_event (Gdk.EventConfigure event)
    {
        int short_edge = int.min (get_allocated_width (), get_allocated_height ());

        square_size = (int) Math.floor ((short_edge - 2 * border) / 9.0);

        if (start_gl ())
            glViewport (0, 0, (GLsizei) get_allocated_width (), (GLsizei) get_allocated_height ());

        return true;
    }

    private void accFrustum (GLfloat left, GLfloat right, GLfloat bottom, GLfloat top, GLfloat near, GLfloat far,
                             GLfloat pixdx, GLfloat pixdy, GLfloat eyedx, GLfloat eyedy, GLfloat focus)
    {
        var xwsize = right - left;
        var ywsize = top - bottom;
        var dx = -(pixdx * xwsize / get_allocated_width () + eyedx * near/focus);
        var dy = -(pixdy * ywsize / get_allocated_height () + eyedy * near/focus);

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
        GLfloat[] jitters = {0.0033922635f, 0.3317967229f, 0.2806016275f, -0.2495619123f, -0.273817106f, -0.086844639f};

        if (!start_gl ())
            return true;

        var n_passes = 1;
        if (scene.show_3d_smooth)
        {
            glClear (GL_ACCUM_BUFFER_BIT);
            n_passes = 3;
        }

        for (var i = 0; i < n_passes; i++)
        {
            var bg = style.bg[get_state ()];
            glClearColor (bg.red / 65535.0f, bg.green / 65535.0f, bg.blue / 65535.0f, 1.0f);
            glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            glEnable (GL_DEPTH_TEST);

            glMatrixMode (GL_PROJECTION);
            glLoadIdentity ();
            if (scene.show_3d_smooth)
                accPerspective (60.0f, (float) get_allocated_width () / get_allocated_height (), 0.1f, 1000, jitters[i*2], jitters[i*2+1], 0, 0, 1);
            else
                gluPerspective (60.0f, (float) get_allocated_width () / get_allocated_height (), 0.1f, 1000);

            glMatrixMode (GL_MODELVIEW);
            transform_camera ();

            GLfloat[] pos = { 100.0f, 100.0f, 100.0f, 1.0f };
            glLightfv (GL_LIGHT0, GL_POSITION, pos);
            glEnable (GL_LIGHTING);
            glEnable (GL_LIGHT0);

            glPushMatrix ();
            glRotatef ((GLfloat) scene.board_angle, 0.0f, 1.0f, 0.0f);
            glTranslatef (-OFFSET, 0.0f, OFFSET);

            draw_board ();
            if (scene.show_numbering)
                draw_numbering ();
            draw_pieces ();

            glPopMatrix ();

            if (scene.show_3d_smooth)
                glAccum (GL_ACCUM, 1.0f / n_passes);
        }

        if (scene.show_3d_smooth)
            glAccum (GL_RETURN, 1);

        glXSwapBuffers (display, drawable);

        return true;
    }

    private void draw_board ()
    {
        glEnable (GL_COLOR_MATERIAL);
        glColor3f (0x2e / 255f, 0x34 / 255f, 0x36 / 255f);
        glBegin (GL_QUADS);
        for (int i = 0; i < board_quads.length; i += 5)
        {
            var j = board_quads[i+4] * 3;
            glNormal3f (board_normals[j], board_normals[j+1], board_normals[j+2]);
            j = board_quads[i] * 3;
            glVertex3f (board_vertices[j], board_vertices[j+1], board_vertices[j+2]);
            j = board_quads[i+1] * 3;
            glVertex3f (board_vertices[j], board_vertices[j+1], board_vertices[j+2]);
            j = board_quads[i+2] * 3;
            glVertex3f (board_vertices[j], board_vertices[j+1], board_vertices[j+2]);
            j = board_quads[i+3] * 3;
            glVertex3f (board_vertices[j], board_vertices[j+1], board_vertices[j+2]);
        }
        glEnd ();

        glEnable (GL_TEXTURE_2D);
        glBindTexture (GL_TEXTURE_2D, board_texture);
        glNormal3f (0.0f, 1.0f, 0.0f);
        for (var rank = 0; rank < 8; rank++)
            for (var file = 0; file < 8; file++)
            {
                if ((file + rank) % 2 == 0)
                    glColor3f (0xba / 255f, 0xbd / 255f, 0xb6 / 255f);
                else
                    glColor3f (0xee / 255f, 0xee / 255f, 0xec / 255f);

                glBegin (GL_QUADS);
                GLfloat x0 = BOARD_BORDER + (file * SQUARE_WIDTH);
                GLfloat x1 = x0 + SQUARE_WIDTH;
                GLfloat z0 = BOARD_BORDER + (rank * SQUARE_WIDTH);
                GLfloat z1 = z0 + SQUARE_WIDTH;

                glTexCoord2f (0.0f, 0.0f);
                glVertex3f (x0, 0.0f, -z0);
                glTexCoord2f (1.0f, 0.0f);
                glVertex3f (x1, 0.0f, -z0);
                glTexCoord2f (1.0f, 1.0f);
                glVertex3f (x1, 0.0f, -z1);
                glTexCoord2f (0.0f, 1.0f);
                glVertex3f (x0, 0.0f, -z1);
                glEnd ();
            }

        glDisable (GL_TEXTURE_2D);
        glDisable (GL_COLOR_MATERIAL);
    }

    private void draw_numbering ()
    {
        var text_width = BOARD_BORDER * 0.7f;
        var text_offset = (BOARD_BORDER + BOARD_CHAMFER) * 0.5f;
        var offset = BOARD_BORDER + SQUARE_WIDTH * 0.5f;
        var white_z_offset = -text_offset;
        var black_z_offset = -BOARD_OUTER_WIDTH + text_offset;
        var left_offset = text_offset;
        var right_offset = BOARD_OUTER_WIDTH - text_offset;

        glDisable (GL_DEPTH_TEST);
        glEnable (GL_TEXTURE_2D);
        glEnable (GL_COLOR_MATERIAL);
        glEnable (GL_BLEND);
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glBindTexture (GL_TEXTURE_2D, numbering_texture);
        glColor3f (1, 1, 1); // FIXME
        glNormal3f (0.0f, 1.0f, 0.0f);

        for (int i = 0 ; i < 8; i++)
        {
            draw_label (left_offset, -offset, text_width, i + 8);
            draw_label (right_offset, -offset, text_width, i + 8);
            draw_label (offset, white_z_offset, text_width, i);
            draw_label (offset, black_z_offset, text_width, i);

            offset += SQUARE_WIDTH;
        }

        glDisable (GL_BLEND);
        glDisable (GL_COLOR_MATERIAL);
        glDisable (GL_TEXTURE_2D);
    }

    private void draw_label (GLfloat x, GLfloat z, GLfloat width, int cell)
    {
        GLfloat w = 1.0f / 16;
        GLfloat l = cell / 16.0f;

        glPushMatrix ();
        glTranslatef (x, 0.0f, z);

        glBegin (GL_QUADS);
        if (scene.board_angle == 180.0)
        {
            glTexCoord2f (l + w, 1.0f);
            glVertex3f (-width/2, 0.0f, -width/2);
            glTexCoord2f (l + w, 0.0f);
            glVertex3f (-width/2, 0.0f, width/2);
            glTexCoord2f (l, 0.0f);
            glVertex3f (width/2, 0.0f, width/2);
            glTexCoord2f (l, 1.0f);
            glVertex3f (width/2, 0.0f, -width/2);
        }
        else
        {
            glTexCoord2f (l, 0.0f);
            glVertex3f (-width/2, 0.0f, -width/2);
            glTexCoord2f (l, 1.0f);
            glVertex3f (-width/2, 0.0f, width/2);
            glTexCoord2f (l + w, 1.0f);
            glVertex3f (width/2, 0.0f, width/2);
            glTexCoord2f (l + w, 0.0f);
            glVertex3f (width/2, 0.0f, -width/2);
        }
        glEnd ();

        glPopMatrix ();
    }

    private void draw_pieces ()
    {
        if (scene.game == null)
            return;

        glEnable (GL_DEPTH_TEST);
        glEnable (GL_TEXTURE_2D);
        glBindTexture (GL_TEXTURE_2D, piece_texture);

        /* Draw the pieces */
        foreach (var model in scene.pieces)
        {
            glPushMatrix ();
            glTranslatef (BOARD_BORDER + (GLfloat) model.x * SQUARE_WIDTH + SQUARE_WIDTH / 2,
                          0.0f,
                          -(BOARD_BORDER + (GLfloat) model.y * SQUARE_WIDTH + SQUARE_WIDTH / 2));

            /* Raise the selected piece up */
            if (model.is_selected)
                glTranslatef (0.0f, SQUARE_WIDTH * 0.4f, 0.0f);

            render_piece (model.piece);

            glPopMatrix ();
        }

        /* Draw shadow piece on squares that can be moved to */
        for (int rank = 0; rank < 8; rank++)
        {
            for (int file = 0; file < 8; file++)
            {
                if (scene.show_move_hints && scene.can_move (rank, file))
                {
                    glPushMatrix ();
                    glTranslatef (BOARD_BORDER + file * SQUARE_WIDTH + SQUARE_WIDTH / 2,
                                  0.0f,
                                  -(BOARD_BORDER + rank * SQUARE_WIDTH + SQUARE_WIDTH / 2));

                    glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                    glEnable (GL_BLEND);
                    glDisable (GL_DEPTH_TEST);
                    render_piece (scene.get_selected_piece (), 0.1f);
                    glEnable (GL_DEPTH_TEST);
                    glDisable (GL_BLEND);

                    glPopMatrix ();
                }
            }
        }

        glDisable (GL_TEXTURE_2D);
    }

    private void render_piece (ChessPiece piece, GLfloat alpha = 1.0f)
    {
        white_piece_color[3] = alpha;
        black_piece_color[3] = alpha;

        if (piece.player.color == Color.WHITE)
        {
            glMaterialfv (GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, white_piece_color);
            glMaterialfv (GL_FRONT_AND_BACK, GL_SPECULAR, white_piece_specular);
        }
        else
        {
            glMaterialfv (GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, black_piece_color);
            glMaterialfv (GL_FRONT_AND_BACK, GL_SPECULAR, black_piece_specular);
        }
        const GLfloat black[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        glMaterialfv (GL_FRONT_AND_BACK, GL_EMISSION, black);
        glMaterialf (GL_FRONT_AND_BACK, GL_SHININESS, 64.0f);

        if (piece.player.color == Color.BLACK)
            glRotatef (180.0f, 0.0f, 1.0f, 0.0f);

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
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (scene.game == null || event.button != 1)
            return false;

        if (!start_gl ())
            return true;

        /* Don't render to screen, just select */
        GLuint buffer[20];
        glSelectBuffer ((GLsizei) buffer.length, buffer);
        glRenderMode (GL_SELECT);

        glInitNames ();

        /* Create pixel picking region near cursor location */
        glMatrixMode (GL_PROJECTION);
        glLoadIdentity ();
        GLint[] viewport = {0, 0, (GLint) get_allocated_width (), (GLint) get_allocated_height ()};
        gluPickMatrix (event.x, ((float) get_allocated_height () - event.y), 1.0, 1.0, viewport);
        gluPerspective (60.0, (float) get_allocated_width () / (float) get_allocated_height (), 0, 1);

        /* Draw the squares that can be selected */
        glMatrixMode (GL_MODELVIEW);
        glLoadIdentity ();
        transform_camera ();
        glRotatef ((GLfloat) scene.board_angle, 0.0f, 1.0f, 0.0f);
        glTranslatef (-OFFSET, 0.0f, OFFSET);
        for (var rank = 0; rank < 8; rank++)
        {
            glPushName (rank);

            for (var file = 0; file < 8; file++)
            {
                glPushName (file);

                glBegin(GL_QUADS);
                var x0 = BOARD_BORDER + (file * SQUARE_WIDTH);
                var x1 = x0 + SQUARE_WIDTH;
                var z0 = BOARD_BORDER + (rank * SQUARE_WIDTH);
                var z1 = z0 + SQUARE_WIDTH;

                glVertex3f (x0, 0.0f, -z0);
                glVertex3f (x1, 0.0f, -z0);
                glVertex3f (x1, 0.0f, -z1);
                glVertex3f (x0, 0.0f, -z1);
                glEnd ();

                glPopName ();
            }
            glPopName ();
        }

        /* Render and check for hits */
        glFlush ();
        var n_hits = glRenderMode (GL_RENDER);

        if (n_hits > 0)
        {
            var rank = (int) buffer[3];
            var file = (int) buffer[4];
            scene.select_square (file, rank);
        }

        return true;
    }

    private void transform_camera ()
    {
        glLoadIdentity();
        gluLookAt(0.0, 80.0, 40.0,
                  0.0,  0.0, 5.0,
                  0.0,  1.0,  0.0);
    }

    private GLuint load_texture (string filename)
    {
        Gdk.Pixbuf pixbuf;
        try
        {
            pixbuf = new Gdk.Pixbuf.from_file (filename);
        }
        catch (Error e)
        {
            warning ("Error loading texture %s: %s", filename, e.message);
            return 0;
        }

        GLenum format;
        if (pixbuf.n_channels == 1)
            format = GL_LUMINANCE;
        else if (pixbuf.n_channels == 3)
            format = GL_RGB;
        else if (pixbuf.n_channels == 4)
            format = GL_RGBA;
        else
        {
            warning ("Unknown format image");
            return 0;
        }

        GLuint textures[1];
        glGenTextures (1, textures);
        var t = textures[0];
        glBindTexture (GL_TEXTURE_2D, t);
        glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (GLint) GL_REPEAT);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (GLint) GL_REPEAT);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (GLint) GL_LINEAR);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (GLint) GL_LINEAR);

        gluBuild2DMipmaps (GL_TEXTURE_2D, (GLint) pixbuf.n_channels, (GLsizei) pixbuf.width, (GLsizei) pixbuf.height,
                           format, GL_UNSIGNED_BYTE, pixbuf.pixels);
        // FIXME: How to check if failed
        //    glTexImage2D (GL_TEXTURE_2D, 0, pixbuf.n_channels, (GLsizei) pixbuf.width, (GLsizei) pixbuf.height, 0, format, GL_UNSIGNED_BYTE, pixbuf.pixels);
            
        return t;       
    }

    private GLuint make_numbering_texture ()
    {
        int width = 64, height = 64;
        var texture_width = width * 16;
        var texture_height = height;

        var surface = new Cairo.ImageSurface (Cairo.Format.A8, texture_width, texture_height);
        var c = new Cairo.Context (surface);
        c.set_source_rgba (1.0, 1.0, 1.0, 1.0);
        c.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        c.set_font_size (width);
        Cairo.FontExtents extents;
        c.font_extents (out extents);
        var scale = width / (extents.height + extents.descent);

        var yoffset = height * 0.5;
        var xoffset = width * 0.5;
        for (int i = 0; i < 8; i++)
        {
            var f = "%c".printf ('a' + i);
            var r = "%c".printf ('1' + i);
            draw_centered_text (c, xoffset, yoffset, scale, f);
            draw_centered_text (c, xoffset + (width * 8), yoffset, scale, r);
            xoffset += width;
        }

        GLuint textures[1];
        glGenTextures (1, textures);
        var t = textures[0];
        glBindTexture (GL_TEXTURE_2D, t);
        glPixelStorei (GL_UNPACK_ALIGNMENT, 1);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (GLint) GL_REPEAT);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (GLint) GL_REPEAT);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (GLint) GL_LINEAR);
        glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (GLint) GL_LINEAR);

        gluBuild2DMipmaps (GL_TEXTURE_2D, (GLint) GL_ALPHA, (GLsizei) texture_width, (GLsizei) texture_height,
                           GL_ALPHA, GL_UNSIGNED_BYTE, surface.get_data ());
        // FIXME: How to check if failed
        //    glTexImage2D (GL_TEXTURE_2D, 0, GL_ALPHA, texture_width, texture_height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, surface.get_data ());
            
        return t;
    }
    
    private void draw_centered_text (Cairo.Context c, double x, double y, double scale, string text)
    {
        Cairo.TextExtents char_extents;
        c.text_extents (text, out char_extents);
        /* Don't want the letters to be centered vertically. */
        Cairo.TextExtents fake_extents;
        c.text_extents ("abcdefgh", out fake_extents);
        c.save ();
        c.translate (x, y);
        c.move_to (-char_extents.width*scale/2, fake_extents.height*scale/2);
        c.scale (scale, scale);
        c.show_text (text);
        c.restore ();
    }
}
