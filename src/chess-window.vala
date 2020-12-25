/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2020 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

[GtkTemplate (ui = "/org/gnome/Chess/ui/chess-window.ui")]
public class ChessWindow : Gtk.ApplicationWindow
{
    public enum LayoutMode {
        NORMAL,
        NARROW
    }

    private LayoutMode _layout_mode = LayoutMode.NORMAL;
    public LayoutMode layout_mode
    {
        get { return _layout_mode; }

        private set
        {
            if (_layout_mode == value)
                return;

            _layout_mode = value;

            Idle.add(() => {
                navigation_box.set_orientation (value == LayoutMode.NORMAL ? Gtk.Orientation.HORIZONTAL : Gtk.Orientation.VERTICAL);
                return Source.REMOVE;
            });
        }
    }

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

    private ulong clock_tick_signal_id = 0;

    [GtkChild]
    private unowned Gtk.Box main_box;
    [GtkChild]
    private unowned Gtk.InfoBar info_bar;
    [GtkChild]
    private unowned Gtk.Label info_bar_label;
    [GtkChild]
    private unowned Gtk.Button pause_resume_button;
    [GtkChild]
    private unowned Gtk.Box navigation_box;
    [GtkChild]
    private unowned Gtk.ComboBox history_combo;
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
        main_box.insert_child_after (view, info_bar);

        update_pause_resume_button ();

        white_time_label.set_draw_func (draw_white_time_label);
        black_time_label.set_draw_func (draw_black_time_label);

        notify["default-height"].connect (window_state_changed_cb);
        notify["default-width"].connect (window_state_changed_cb);
    }

    private void window_state_changed_cb ()
    {
        if (fullscreened || maximized)
            return;

        if (default_width == 0 || default_height == 0)
            return;

        if (default_width <= 500 && layout_mode == LayoutMode.NORMAL)
            layout_mode = LayoutMode.NARROW;
        else if (default_width > 500 && layout_mode == LayoutMode.NARROW)
            layout_mode = LayoutMode.NORMAL;
    }

    public void update_game_status (string? title = null, string? info = null)
    {
        this.title = title != null ? title : app.compute_current_title ();
        info_bar_label.label = info != null ? info : app.compute_status_info ();
        /* Setting the label to null actually just sets it to an empty string. */
        info_bar.visible = info_bar_label.label != "";
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

        history_combo.sensitive = !game.is_paused;

        /* Set move text for all moves (it may have changed format) */
        int i = n_moves;
        foreach (var state in game.move_stack)
        {
            if (state.last_move != null)
            {
                Gtk.TreeIter iter;
                if (history_combo.model.iter_nth_child (out iter, null, i))
                    set_move_text (iter, state.last_move);
            }
            i--;
        }

        history_combo.set_active (move_number);
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

        c.set_source_rgba (fg[0], fg[1], fg[2], alpha);
        c.select_font_face ("fixed", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        c.set_font_size (0.6 * widget.get_allocated_height ());
        Cairo.TextExtents extents;
        c.text_extents (text, out extents);
        c.move_to ((widget.get_allocated_width () - extents.width) / 2 - extents.x_bearing,
                   (widget.get_allocated_height () - extents.height) / 2 - extents.y_bearing);
        c.show_text (text);
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
            return "%d∶\xE2\x80\x8E%02d".printf (time / 60, time % 60);
        else
            return "∶\xE2\x80\x8E%02d".printf (time);
    }

    private void draw_white_time_label (Gtk.DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (scene.game.clock, Color.WHITE), { 0.0, 0.0, 0.0 }, { 1.0, 1.0, 1.0 });
    }

    private void draw_black_time_label (Gtk.DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (scene.game.clock, Color.BLACK), { 1.0, 1.0, 1.0 }, { 0.0, 0.0, 0.0 });
    }

    [GtkCallback]
    private void history_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int move_number;
        combo.model.get (iter, 1, out move_number, -1);
        if (game == null || move_number == game.n_moves)
            move_number = -1;
        scene.move_number = move_number;
    }

    public void set_move_text (Gtk.TreeIter iter, ChessMove move)
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

        var model = (Gtk.ListStore) history_combo.model;
        var label = "%u%c. %s".printf ((move.number + 1) / 2, move.number % 2 == 0 ? 'b' : 'a', move_text);
        model.set (iter, 0, label, -1);
    }

    public void start_game ()
    {
        var model = (Gtk.ListStore) history_combo.model;
        model.clear ();
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 0,
                   /* Move History Combo: Go to the start of the game */
                   _("Game Start"), 1, 0, -1);
        history_combo.set_active_iter (iter);

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();

        if (clock_tick_signal_id != 0)
        {
            disconnect (clock_tick_signal_id);
            clock_tick_signal_id = 0;
        }

        if (game.clock != null)
        {
            clock_tick_signal_id = game.clock.tick.connect (() => {
                white_time_label.queue_draw ();
                black_time_label.queue_draw ();
            });
        }
    }

    public void move (ChessMove m)
    {
        /* Automatically return view to the present */
        scene.move_number = -1;

        var model = (Gtk.ListStore) history_combo.model;
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 1, m.number, -1);
        set_move_text (iter, m);

        /* Follow the latest move */
        if (m.number == game.n_moves)
            history_combo.set_active_iter (iter);
    }

    public void undo ()
    {
        /* Remove from the history */
        var model = (Gtk.ListStore) history_combo.model;
        Gtk.TreeIter iter;
        model.iter_nth_child (out iter, null, model.iter_n_children (null) - 1);
        model.remove (ref iter);

        /* Always undo from the most recent move */
        scene.move_number = -1;

        /* Go back one */
        model.iter_nth_child (out iter, null, model.iter_n_children (null) - 1);
        history_combo.set_active_iter (iter);
        view.queue_draw ();
    }

    public void end_game ()
    {
        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }
}
