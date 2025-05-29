/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2024 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

[GtkTemplate (ui = "/org/gnome/Chess/ui/chess-window.ui")]
public class ChessWindow : Adw.ApplicationWindow
{
    public ChessView view
    {
        get; private set;
    }

    public ChessScene scene
    {
        get { return view.scene; }
    }

    public ChessGame? game
    {
        get { return scene.game; }
    }

    private ChessApplication app;

    [GtkChild]
    private unowned Adw.ToastOverlay toast_overlay;
    [GtkChild]
    private unowned Gtk.Button pause_resume_button;
    [GtkChild]
    private unowned Gtk.DropDown history_dropdown;
    [GtkChild]
    private unowned Gtk.StringList history_model;
    [GtkChild]
    private unowned Gtk.Box clock_box;
    [GtkChild]
    private unowned Gtk.DrawingArea white_time_label;
    [GtkChild]
    private unowned Gtk.DrawingArea black_time_label;

    public ChessWindow (ChessApplication app)
    {
        this.app = app;

        var scene = new ChessScene ();
        scene.changed.connect (() => update_history_panel ());

        view = new ChessView (scene);
        toast_overlay.set_child (view);

        update_pause_resume_button ();

        white_time_label.set_draw_func (draw_white_time_label);
        black_time_label.set_draw_func (draw_black_time_label);

        var list_factory = history_dropdown.get_factory ();
        var button_factory = new Gtk.SignalListItemFactory ();

        button_factory.setup.connect (history_dropdown_button_setup_cb);
        button_factory.bind.connect (history_dropdown_button_bind_cb);

        history_dropdown.set_factory (button_factory);
        history_dropdown.set_list_factory (list_factory);
    }

    public void update_game_status (string? title = null, string? info = null)
    {
        this.title = title != null ? title : app.compute_current_title ();

        string toast = info;
        if (toast == null)
            toast = app.compute_status_info ();
        if (toast != null)
            toast_overlay.add_toast (new Adw.Toast (toast));
    }

    public void update_pause_resume_button ()
    {
        var game = scene.game;

        if (game != null && game.clock == null)
            pause_resume_button.hide ();
        else
            pause_resume_button.show ();

        if (game != null && game.is_paused)
        {
            pause_resume_button.icon_name = "media-playback-start-symbolic";
            pause_resume_button.tooltip_text = _("Unpause the game");
        }
        else
        {
            pause_resume_button.icon_name = "media-playback-pause-symbolic";
            pause_resume_button.tooltip_text = _("Pause the game");
        }
    }

    public void update_history_panel ()
    {
        if (game == null)
            return;

        var move_number = scene.move_number;
        var n_moves = (int) game.n_moves;
        if (move_number < 0)
            move_number += 1 + n_moves;

        if (n_moves > 0 && move_number != 0 && !game.is_paused)
            app.enable_action (HISTORY_GO_FIRST_ACTION_NAME);
        else
            app.disable_action (HISTORY_GO_FIRST_ACTION_NAME);

        if (move_number > 0 && !game.is_paused)
            app.enable_action (HISTORY_GO_PREVIOUS_ACTION_NAME);
        else
            app.disable_action (HISTORY_GO_PREVIOUS_ACTION_NAME);

        if (move_number < n_moves && !game.is_paused)
            app.enable_action (HISTORY_GO_NEXT_ACTION_NAME);
        else
            app.disable_action (HISTORY_GO_NEXT_ACTION_NAME);

        if (n_moves > 0 && move_number != n_moves && !game.is_paused)
            app.enable_action (HISTORY_GO_LAST_ACTION_NAME);
        else
            app.disable_action (HISTORY_GO_LAST_ACTION_NAME);

        history_dropdown.sensitive = !game.is_paused;

        /* Set move text for all moves (it may have changed format) */
        int i = 0;
        string[] moves = new string[n_moves];
        foreach (var state in game.move_stack)
        {
            var move = state.last_move;
            moves[i++] = move != null ? get_move_text (move) : null;
        }

        history_dropdown.set_selected (move_number);
    }

    public void set_clock_visible (bool visible)
    {
        clock_box.visible = visible;
    }

    /* Compute the largest possible size the timer label might ever want to take.
     * The size of the characters may vary by font, but one digit will always
     * be the largest.
     */
    private int compute_time_label_width_request (Cairo.Context c)
        ensures (result > 0)
    {
        Cairo.TextExtents extents;
        double max = 0;

        c.text_extents ("000∶00", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("111∶11", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("222∶22", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("333∶33", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("444∶44", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("555∶55", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("666∶66", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("777∶77", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("888∶88", out extents);
        max = (max > extents.width ? max : extents.width);
        c.text_extents ("999∶99", out extents);
        max = (max > extents.width ? max : extents.width);

        /* Leave a little bit of room to the sides. */
        return (int) Math.ceil (max) + 6;
    }

    private void draw_time (Gtk.Widget widget, Cairo.Context c, int width, int height, string text, double[] fg, double[] bg)
    {
        /* We need to draw text on our cairo context to properly compute our
         * required size. But the only place we are able to access the cairo
         * context is here, the draw function. And we are not allowed to set our
         * size inside the draw function. So the best we can do is schedule the
         * size computation and queue draw again when that's done.
         */
        if (widget.width_request == -1)
        {
            Idle.add(() => {
                widget.set_size_request (compute_time_label_width_request (c), -1);
                widget.queue_draw ();
                return Source.REMOVE;
            });
            return;
        }

        double alpha = 1.0;
        if ((widget.get_state_flags () & Gtk.StateFlags.INSENSITIVE) != 0)
            alpha = 0.5;
        c.set_source_rgba (bg[0], bg[1], bg[2], alpha);
        c.paint ();

        var pango_context = Pango.cairo_create_context (c);
        Pango.cairo_context_set_font_options (pango_context, get_font_options ());
        var layout = new Pango.Layout (pango_context);
        layout.set_font_description (Pango.FontDescription.from_string ("Sans Bold 14"));
        layout.set_text (text, -1);

        // https://docs.microsoft.com/en-us/typography/opentype/spec/features_pt#tnum
        var attributes = new Pango.AttrList ();
        attributes.insert (new Pango.AttrFontFeatures ("tnum=1"));
        layout.set_attributes (attributes);

        int layout_width;
        int layout_height;
        layout.get_size (out layout_width, out layout_height);
        layout_width /= Pango.SCALE;
        layout_height /= Pango.SCALE;
        c.move_to ((widget.get_width () - layout_width) / 2,
                   (widget.get_height () - layout_height) / 2);
        c.set_source_rgba (fg[0], fg[1], fg[2], alpha);
        Pango.cairo_show_layout (c, layout);
    }

    private string make_clock_text (ChessClock? clock, Color color)
        requires (clock != null)
    {
        int time;
        if (color == Color.WHITE)
            time = clock.white_remaining_seconds;
        else
            time = clock.black_remaining_seconds;

        if (time >= 60)
            return "%d:%02d".printf (time / 60, time % 60);
        else
            return ":%02d".printf (time);
    }

    private void draw_white_time_label (Gtk.DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (scene.game.clock, Color.WHITE), { 0.0, 0.0, 0.0 }, { 1.0, 1.0, 1.0 });
    }

    private void draw_black_time_label (Gtk.DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (scene.game.clock, Color.BLACK), { 1.0, 1.0, 1.0 }, { 0.0, 0.0, 0.0 });
    }

    private void history_dropdown_button_setup_cb (Gtk.SignalListItemFactory factory, Object object) {
        unowned var list_item = object as Gtk.ListItem;

        list_item.child = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };
    }

    private void history_dropdown_button_bind_cb (Gtk.SignalListItemFactory factory, Object object) {
        unowned var list_item = object as Gtk.ListItem;
        unowned var string_object = list_item.item as Gtk.StringObject;
        unowned var label = list_item.child as Gtk.Label;

        label.label = string_object.string;
    }

    [GtkCallback]
    private void history_dropdown_selection_changed_cb ()
    {
        var move_number = (int) history_dropdown.get_selected ();
        if (move_number == Gtk.INVALID_LIST_POSITION)
            return;

        if (game == null || move_number == game.n_moves)
            scene.move_number = -1;
        else
            scene.move_number = move_number;
    }

    public string get_move_text (ChessMove move)
    {
        /* Note there are no move formats for pieces taking kings and this is not allowed in Chess rules */
        const string human_descriptions[] = {/* Human Move String: Description of a white pawn moving from %1$s to %2s, e.g. 'c2 to c4' */
                                             N_("White pawn moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white pawn at %1$s capturing a pawn at %2$s */
                                             N_("White pawn at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white pawn at %1$s capturing a rook at %2$s */
                                             N_("White pawn at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white pawn at %1$s capturing a knight at %2$s */
                                             N_("White pawn at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white pawn at %1$s capturing a bishop at %2$s */
                                             N_("White pawn at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white pawn at %1$s capturing a queen at %2$s */
                                             N_("White pawn at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a white rook moving from %1$s to %2$s, e.g. 'a1 to a5' */
                                             N_("White rook moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white rook at %1$s capturing a pawn at %2$s */
                                             N_("White rook at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white rook at %1$s capturing a rook at %2$s */
                                             N_("White rook at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white rook at %1$s capturing a knight at %2$s */
                                             N_("White rook at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white rook at %1$s capturing a bishop at %2$s */
                                             N_("White rook at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white rook at %1$s capturing a queen at %2$s" */
                                             N_("White rook at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a white knight moving from %1$s to %2$s, e.g. 'b1 to c3' */
                                             N_("White knight moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white knight at %1$s capturing a pawn at %2$s */
                                             N_("White knight at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white knight at %1$s capturing a rook at %2$s */
                                             N_("White knight at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white knight at %1$s capturing a knight at %2$s */
                                             N_("White knight at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white knight at %1$s capturing a bishop at %2$s */
                                             N_("White knight at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white knight at %1$s capturing a queen at %2$s */
                                             N_("White knight at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a white bishop moving from %1$s to %2$s, e.g. 'f1 to b5' */
                                             N_("White bishop moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white bishop at %1$s capturing a pawn at %2$s */
                                             N_("White bishop at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white bishop at %1$s capturing a rook at %2$s */
                                             N_("White bishop at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white bishop at %1$s capturing a knight at %2$s */
                                             N_("White bishop at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white bishop at %1$s capturing a bishop at %2$s */
                                             N_("White bishop at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white bishop at %1$s capturing a queen at %2$s */
                                             N_("White bishop at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a white queen moving from %1$s to %2$s, e.g. 'd1 to d4' */
                                             N_("White queen moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white queen at %1$s capturing a pawn at %2$s */
                                             N_("White queen at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white queen at %1$s capturing a rook at %2$s */
                                             N_("White queen at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white queen at %1$s capturing a knight at %2$s */
                                             N_("White queen at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white queen at %1$s capturing a bishop at %2$s */
                                             N_("White queen at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white queen at %1$s capturing a queen at %2$s */
                                             N_("White queen at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a white king moving from %1$s to %2$s, e.g. 'e1 to f1' */
                                             N_("White king moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a white king at %1$s capturing a pawn at %2$s */
                                             N_("White king at %1$s takes the black pawn at %2$s"),
                                             /* Human Move String: Description of a white king at %1$s capturing a rook at %2$s */
                                             N_("White king at %1$s takes the black rook at %2$s"),
                                             /* Human Move String: Description of a white king at %1$s capturing a knight at %2$s */
                                             N_("White king at %1$s takes the black knight at %2$s"),
                                             /* Human Move String: Description of a white king at %1$s capturing a bishop at %2$s */
                                             N_("White king at %1$s takes the black bishop at %2$s"),
                                             /* Human Move String: Description of a white king at %1$s capturing a queen at %2$s */
                                             N_("White king at %1$s takes the black queen at %2$s"),
                                             /* Human Move String: Description of a black pawn moving from %1$s to %2$s, e.g. 'c8 to c6' */
                                             N_("Black pawn moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black pawn at %1$s capturing a pawn at %2$s */
                                             N_("Black pawn at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black pawn at %1$s capturing a rook at %2$s */
                                             N_("Black pawn at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black pawn at %1$s capturing a knight at %2$s */
                                             N_("Black pawn at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black pawn at %1$s capturing a bishop at %2$s */
                                             N_("Black pawn at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black pawn at %1$s capturing a queen at %2$s */
                                             N_("Black pawn at %1$s takes the white queen at %2$s"),
                                             /* Human Move String: Description of a black rook moving from %1$s to %2$s, e.g. 'a8 to a4' */
                                             N_("Black rook moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black rook at %1$s capturing a pawn at %2$s */
                                             N_("Black rook at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black rook at %1$s capturing a rook at %2$s */
                                             N_("Black rook at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black rook at %1$s capturing a knight at %2$s */
                                             N_("Black rook at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black rook at %1$s capturing a bishop at %2$s */
                                             N_("Black rook at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black rook at %1$s capturing a queen at %2$s */
                                             N_("Black rook at %1$s takes the white queen at %2$s"),
                                             /* Human Move String: Description of a black knight moving from %1$s to %2$s, e.g. 'b8 to c6' */
                                             N_("Black knight moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black knight at %1$s capturing a pawn at %2$s */
                                             N_("Black knight at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black knight at %1$s capturing a rook at %2$s */
                                             N_("Black knight at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black knight at %1$s capturing a knight at %2$s */
                                             N_("Black knight at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black knight at %1$s capturing a bishop at %2$s */
                                             N_("Black knight at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black knight at %1$s capturing a queen at %2$s */
                                             N_("Black knight at %1$s takes the white queen at %2$s"),
                                             /* Human Move String: Description of a black bishop moving from %1$s to %2$s, e.g. 'f8 to b3' */
                                             N_("Black bishop moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black bishop at %1$s capturing a pawn at %2$s */
                                             N_("Black bishop at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black bishop at %1$s capturing a rook at %2$s */
                                             N_("Black bishop at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black bishop at %1$s capturing a knight at %2$s */
                                             N_("Black bishop at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black bishop at %1$s capturing a bishop at %2$s */
                                             N_("Black bishop at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black bishop at %1$s capturing a queen at %2$s */
                                             N_("Black bishop at %1$s takes the white queen at %2$s"),
                                             /* Human Move String: Description of a black queen moving from %1$s to %2$s, e.g. 'd8 to d5' */
                                             N_("Black queen moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black queen at %1$s capturing a pawn at %2$s */
                                             N_("Black queen at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black queen at %1$s capturing a rook at %2$s */
                                             N_("Black queen at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black queen at %1$s capturing a knight at %2$s */
                                             N_("Black queen at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black queen at %1$s capturing a bishop at %2$s */
                                             N_("Black queen at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black queen at %1$s capturing a queen at %2$s */
                                             N_("Black queen at %1$s takes the white queen at %2$s"),
                                             /* Human Move String: Description of a black king moving from %1$s to %2$s, e.g. 'e8 to f8' */
                                             N_("Black king moves from %1$s to %2$s"),
                                             /* Human Move String: Description of a black king at %1$s capturing a pawn at %2$s */
                                             N_("Black king at %1$s takes the white pawn at %2$s"),
                                             /* Human Move String: Description of a black king at %1$s capturing a rook at %2$s */
                                             N_("Black king at %1$s takes the white rook at %2$s"),
                                             /* Human Move String: Description of a black king at %1$s capturing a knight at %2$s */
                                             N_("Black king at %1$s takes the white knight at %2$s"),
                                             /* Human Move String: Description of a black king at %1$s capturing a bishop at %2$s */
                                             N_("Black king at %1$s takes the white bishop at %2$s"),
                                             /* Human Move String: Description of a black king at %1$s capturing a queen at %2$s" */
                                             N_("Black king at %1$s takes the white queen at %2$s")};

        var move_text = "";
        switch (scene.move_format)
        {
        case "human":
            if (move.castling_rook != null)
            {
                if (move.f0 < move.f1 && move.r0 == 0)
                    move_text = _("White castles kingside");
                else if (move.f1 < move.f0 && move.r0 == 0)
                    move_text = _("White castles queenside");
                else if (move.f0 < move.f1 && move.r0 == 7)
                    move_text = _("Black castles kingside");
                else if (move.f1 < move.f0 && move.r0 == 7)
                    move_text = _("Black castles queenside");
                else
                    assert_not_reached ();
            }
            else
            {
                int index;
                if (move.victim == null)
                    index = 0;
                else
                    index = move.victim.type + 1;
                index += move.piece.type * 6;
                if (move.piece.player.color == Color.BLACK)
                    index += 36;

                var start = "%c%d".printf ('a' + move.f0, move.r0 + 1);
                var end = "%c%d".printf ('a' + move.f1, move.r1 + 1);
                var template = _(human_descriptions[index]);
                if (move.en_passant)
                {
                    if (move.r0 < move.r1)
                    {   /* Human Move String: Description of a white pawn at %1$s capturing a pawn at %2$s en passant */
                        template = _("White pawn at %1$s takes the black pawn at %2$s en passant");
                    }
                    else
                    {   /* Human Move String: Description of a black pawn at %1$s capturing a pawn at %2$s en passant */
                        template = _("Black pawn at %1$s takes white pawn at %2$s en passant");
                    }
                }
                move_text = template.printf (start, end);
            }
            break;

        case "san":
            move_text = move.get_san ();
            break;

        case "fan":
            move_text = move.get_fan ();
            break;

        default:
        case "lan":
            move_text = move.get_lan ();
            break;
        }

        return "%u%c. %s".printf ((move.number + 1) / 2, move.number % 2 == 0 ? 'b' : 'a', move_text);
    }

    public void start_game ()
    {
        /* Delete everything from history. */
        history_model.splice (0, history_model.n_items, null);
        history_model.append (_("Game Start"));
        history_dropdown.set_selected (0);

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();

        if (game.clock != null)
        {
            game.clock.tick.connect (() => {
                white_time_label.queue_draw ();
                black_time_label.queue_draw ();
            });
        }
    }

    public void move (ChessMove m)
    {
        /* Automatically return view to the present */
        scene.move_number = -1;

        history_model.append (get_move_text (m));

        /* Follow the latest move */
        if (m.number == game.n_moves)
            history_dropdown.set_selected (m.number);
    }

    public void undo ()
    {
        /* Remove from the history */
        history_model.remove (history_model.n_items - 1);

        /* Always undo from the most recent move */
        scene.move_number = -1;

        /* Go back one */
        history_dropdown.set_selected (history_model.n_items - 1);
        view.queue_draw ();
    }

    public void end_game ()
    {
        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }
}
