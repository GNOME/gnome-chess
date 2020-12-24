/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2020 Michael Catanzaro
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gtk;

public class ChessApplication : Gtk.Application
{
    private enum LayoutMode {
        NORMAL,
        NARROW
    }
    private LayoutMode layout_mode;

    private GLib.Settings settings;
    private unowned ApplicationWindow window;
    private Box main_box;
    private InfoBar info_bar;
    private Label info_bar_label;
    private ChessScene scene;
    private ChessView view;
    private Button pause_resume_button;
    private Box navigation_box;
    private Button first_move_button;
    private Button prev_move_button;
    private Button next_move_button;
    private Button last_move_button;
    private ComboBox history_combo;
    private Box clock_box;
    private DrawingArea white_time_label;
    private DrawingArea black_time_label;
    private Label timer_increment_label;
    private HeaderBar headerbar;

    private Dialog? preferences_dialog = null;
    private ComboBox side_combo;
    private ComboBox difficulty_combo;
    private ComboBox duration_combo;
    private ComboBox clock_type_combo;
    private Adjustment duration_adjustment;
    private Adjustment timer_increment_adjustment;
    private Box custom_duration_box;
    private Box timer_increment_box;
    private ComboBox timer_increment_units_combo;
    private ComboBox custom_duration_units_combo;
    private uint save_duration_timeout = 0;
    private FileChooserNative? open_dialog = null;
    private FileChooserNative? save_dialog = null;
    private delegate void PromptSaveGameCallback (bool cancelled);
    private PromptSaveGameCallback? prompt_save_game_cb = null;
    private MessageDialog? prompt_save_game_dialog = null;
    private MessageDialog? save_error_dialog = null;
    private MessageDialog? claim_draw_dialog = null;
    private MessageDialog? resign_dialog = null;
    private AboutDialog? about_dialog = null;
    private Dialog? promotion_type_selector_dialog = null;
    private ChessScene.PromotionTypeCompletionHandler? promotion_type_completion_handler = null;

    private PGNGame pgn_game;
    private ChessGame game;
    private string autosave_filename;
    private File game_file;
    private bool game_needs_saving = false;
    private bool starting = true;
    private List<AIProfile> ai_profiles;
    private ChessPlayer? opponent = null;
    private ChessPlayer? human_player = null;
    private ChessEngine? opponent_engine = null;
    private uint engine_timeout_source = 0;
    private string copyrights = """Copyright © 2010–2013 Robert Ancell
Copyright © 2013–2020 Michael Catanzaro
Copyright © 2015–2016 Sahil Sareen""";

    private const GLib.ActionEntry[] app_entries =
    {
        { "preferences", preferences_cb },
        { "help", help_cb },
        { "about", about_cb },
        { "quit", quit_cb },
    };

    private const string NEW_GAME_ACTION_NAME = "new";
    private const string OPEN_GAME_ACTION_NAME = "open";
    private const string SAVE_GAME_ACTION_NAME = "save";
    private const string SAVE_GAME_AS_ACTION_NAME = "save-as";
    private const string UNDO_MOVE_ACTION_NAME = "undo";
    private const string RESIGN_ACTION_NAME = "resign";
    private const string PAUSE_RESUME_ACTION_NAME = "pause-resume";
    private const string HISTORY_GO_FIRST_ACTION_NAME = "go-first";
    private const string HISTORY_GO_PREVIOUS_ACTION_NAME = "go-previous";
    private const string HISTORY_GO_NEXT_ACTION_NAME = "go-next";
    private const string HISTORY_GO_LAST_ACTION_NAME = "go-last";

    private const GLib.ActionEntry[] window_entries =
    {
        { NEW_GAME_ACTION_NAME, new_game_cb },
        { OPEN_GAME_ACTION_NAME, open_game_cb },
        { SAVE_GAME_ACTION_NAME, save_game_cb },
        { SAVE_GAME_AS_ACTION_NAME, save_game_as_cb },
        { UNDO_MOVE_ACTION_NAME, undo_move_cb },
        { RESIGN_ACTION_NAME, resign_cb },
        { PAUSE_RESUME_ACTION_NAME, pause_resume_cb },
        { HISTORY_GO_FIRST_ACTION_NAME, history_go_first_cb },
        { HISTORY_GO_PREVIOUS_ACTION_NAME, history_go_previous_cb },
        { HISTORY_GO_NEXT_ACTION_NAME, history_go_next_cb },
        { HISTORY_GO_LAST_ACTION_NAME, history_go_last_cb },
    };

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null,
        /* Help string for command line --version flag */
        N_("Show release version"), null},

        { null }
    };

    private ChessApplication ()
    {
        Object (application_id: "org.gnome.Chess", flags: ApplicationFlags.HANDLES_OPEN);
        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* Not translated so can be easily parsed */
            stderr.printf ("gnome-chess %s\n", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        /* Activate */
        return -1;
    }

    public override void startup ()
    {
        base.startup ();

        settings = new GLib.Settings ("org.gnome.Chess");

        add_action_entries (app_entries, this);
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Control>q", "<Control>w"});

        Builder builder = new Builder ();
        builder.set_current_object (this);
        try
        {
            builder.add_from_resource ("/org/gnome/Chess/ui/gnome-chess.ui");
        }
        catch (Error e)
        {
            error ("Failed to load UI resource: %s", e.message);
        }

        window = (ApplicationWindow) builder.get_object ("gnome_chess_app");
        window.set_default_size (settings.get_int ("width"), settings.get_int ("height"));
        if (settings.get_boolean ("maximized"))
            window.maximize ();

        main_box = (Box) builder.get_object ("main_box");
        info_bar = (InfoBar) builder.get_object ("info_bar");
        info_bar_label = (Label) builder.get_object ("info_bar_label");
        pause_resume_button = (Button) builder.get_object ("pause_button");
        navigation_box = (Box) builder.get_object ("navigation_box");
        first_move_button = (Button) builder.get_object ("first_move_button");
        prev_move_button = (Button) builder.get_object ("prev_move_button");
        next_move_button = (Button) builder.get_object ("next_move_button");
        last_move_button = (Button) builder.get_object ("last_move_button");
        history_combo = (ComboBox) builder.get_object ("history_combo");
        clock_box = (Box) builder.get_object ("clock_box");
        white_time_label = (DrawingArea) builder.get_object ("white_time_label");
        black_time_label = (DrawingArea) builder.get_object ("black_time_label");
        headerbar = (HeaderBar) builder.get_object ("headerbar");

        update_pause_resume_button ();

        window.add_action_entries (window_entries, this);
        set_accels_for_action ("win." + NEW_GAME_ACTION_NAME,            {        "<Control>n"     });
        set_accels_for_action ("win." + OPEN_GAME_ACTION_NAME,           {        "<Control>o"     });
        set_accels_for_action ("win." + SAVE_GAME_ACTION_NAME,           {        "<Control>s"     });
        set_accels_for_action ("win." + SAVE_GAME_AS_ACTION_NAME,        { "<Shift><Control>s"     });
        set_accels_for_action ("win." + UNDO_MOVE_ACTION_NAME,           {        "<Control>z"     });
        set_accels_for_action ("win." + PAUSE_RESUME_ACTION_NAME,        {        "<Control>p",
                                                                                           "Pause" });
        set_accels_for_action ("win." + HISTORY_GO_FIRST_ACTION_NAME,    {     "<Shift><Alt>Left"  });
        set_accels_for_action ("win." + HISTORY_GO_PREVIOUS_ACTION_NAME, {            "<Alt>Left"  });
        set_accels_for_action ("win." + HISTORY_GO_NEXT_ACTION_NAME,     {            "<Alt>Right" });
        set_accels_for_action ("win." + HISTORY_GO_LAST_ACTION_NAME,     {     "<Shift><Alt>Right"  });

        window.notify["default-height"].connect (window_state_changed_cb);
        window.notify["default-width"].connect (window_state_changed_cb);

        add_window (window);

        scene = new ChessScene ();
        scene.is_human.connect ((p) => { return p == human_player; });
        scene.changed.connect (scene_changed_cb);
        scene.choose_promotion_type.connect (show_promotion_type_selector);

        settings.bind ("show-move-hints", scene, "show-move-hints", SettingsBindFlags.GET);
        settings.bind ("show-numbering", scene, "show-numbering", SettingsBindFlags.GET);
        settings.bind ("piece-theme", scene, "theme-name", SettingsBindFlags.GET);
        settings.bind ("move-format", scene, "move-format", SettingsBindFlags.GET);
        settings.bind ("board-side", scene, "board-side", SettingsBindFlags.GET);

        view = new ChessView ();
        view.set_size_request (100, 100);
        view.scene = scene;
        main_box.insert_child_after (view, info_bar);
        view.show ();

        white_time_label.set_draw_func (draw_white_time_label);
        black_time_label.set_draw_func (draw_black_time_label);

        var system_engine_cfg = Path.build_filename (SYSCONFDIR, "gnome-chess", "engines.conf", null);
        var user_engine_cfg = Path.build_filename (Environment.get_user_config_dir (), "gnome-chess", "engines.conf", null);
        if (FileUtils.test (user_engine_cfg, FileTest.EXISTS))
            ai_profiles = AIProfile.load_ai_profiles (user_engine_cfg);
        else if (FileUtils.test (system_engine_cfg, FileTest.EXISTS))
            ai_profiles = AIProfile.load_ai_profiles (system_engine_cfg);
        else
            warning ("engines.conf not found");

        foreach (var profile in ai_profiles)
            debug ("Detected AI profile %s in %s", profile.name, profile.path);
    }

    public override void open (File[] files, string hint)
    {
        if (files.length != 1)
        {
            /* May print when started on the command line; a PGN is a saved game file. */
            warning (_("GNOME Chess can only open one PGN at a time."));
        }

        game_file = files[0];
        activate ();
    }

    public override void activate ()
    {
        if (!window.visible)
        {
            var data_dir = File.new_for_path (Path.build_filename (Environment.get_user_data_dir (), "gnome-chess", null));
            DirUtils.create_with_parents (data_dir.get_path (), 0755);

            autosave_filename = data_dir.get_path () + "/autosave.pgn";

            /* Load from history if no game requested */
            if (game_file == null && FileUtils.test (autosave_filename, FileTest.EXISTS))
                game_file = File.new_for_path (autosave_filename);

            if (game_file == null)
                start_new_game ();
            else
                load_game (game_file);
        }

        window.present ();
    }

    protected override void shutdown ()
    {
        if (opponent_engine != null)
            opponent_engine.stop ();

        base.shutdown ();
    }

    private void set_layout_mode (LayoutMode new_layout_mode)
    {
        if (layout_mode == new_layout_mode)
            return;

        layout_mode = new_layout_mode;

        Idle.add(() => {
            navigation_box.set_orientation (layout_mode == LayoutMode.NORMAL ? Orientation.HORIZONTAL : Orientation.VERTICAL);
            return Source.REMOVE;
        });
    }

    private void window_state_changed_cb ()
    {
        if (window.fullscreened || window.maximized)
            return;

        if (window.default_width == 0 || window.default_height == 0)
            return;

        if (window.default_width <= 500 && layout_mode == LayoutMode.NORMAL)
            set_layout_mode (LayoutMode.NARROW);
        else if (window.default_width > 500 && layout_mode == LayoutMode.NARROW)
            set_layout_mode (LayoutMode.NORMAL);
    }

    [CCode (cname = "queen_selected_cb", instance_pos = -1)]
    public void queen_selected_cb (Button button)
        requires (promotion_type_selector_dialog != null)
    {
        promotion_type_selector_dialog.response (PromotionTypeSelected.QUEEN);
    }

    [CCode (cname = "knight_selected_cb", instance_pos = -1)]
    public void knight_selected_cb (Button button)
        requires (promotion_type_selector_dialog != null)
    {
        promotion_type_selector_dialog.response (PromotionTypeSelected.KNIGHT);
    }

    [CCode (cname = "rook_selected_cb", instance_pos = -1)]
    public void rook_selected_cb (Button button)
        requires (promotion_type_selector_dialog != null)
    {
        promotion_type_selector_dialog.response (PromotionTypeSelected.KNIGHT);
    }

    [CCode (cname = "bishop_selected_cb", instance_pos = -1)]
    public void bishop_selected_cb (Button button)
        requires (promotion_type_selector_dialog != null)
    {
        promotion_type_selector_dialog.response (PromotionTypeSelected.BISHOP);
    }

    private void promotion_type_selector_response_cb (int response_id)
        requires (promotion_type_completion_handler != null)
    {
        switch (response_id)
        {
        case PromotionTypeSelected.QUEEN:
            promotion_type_completion_handler (PieceType.QUEEN);
            break;
        case PromotionTypeSelected.KNIGHT:
            promotion_type_completion_handler (PieceType.KNIGHT);
            break;
        case PromotionTypeSelected.ROOK:
            promotion_type_completion_handler (PieceType.ROOK);
            break;
        case PromotionTypeSelected.BISHOP:
            promotion_type_completion_handler (PieceType.BISHOP);
            break;
        default:
            promotion_type_completion_handler (null);
            break;
        }

        promotion_type_selector_dialog.hide ();

        promotion_type_completion_handler = null;
    }

    public void show_promotion_type_selector (owned ChessScene.PromotionTypeCompletionHandler handler)
        requires (promotion_type_completion_handler == null)
    {
        if (promotion_type_selector_dialog == null)
        {
            Builder builder = new Builder ();
            builder.set_current_object (this);
            try
            {
                builder.add_from_resource ("/org/gnome/Chess/ui/promotion-type-selector.ui");
            }
            catch (Error e)
            {
                error ("Failed to load UI resource: %s", e.message);
            }

            promotion_type_selector_dialog = (Dialog) builder.get_object ("dialog_promotion_type_selector");
            promotion_type_selector_dialog.transient_for = window;
            promotion_type_selector_dialog.modal = true;

            var button_box = (Box) builder.get_object ("button_box");
            if (layout_mode == LayoutMode.NARROW)
                button_box.orientation = Orientation.VERTICAL;

            string color;
            if (game.current_player.color == Color.WHITE)
                color = "white";
            else
                color = "black";

            var filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sQueen.svg".printf (color));
            set_piece_image ((Image) builder.get_object ("image_queen"), filename);

            filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sKnight.svg".printf (color));
            set_piece_image ((Image) builder.get_object ("image_knight"), filename);

            filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sRook.svg".printf (color));
            set_piece_image ((Image) builder.get_object ("image_rook"), filename);

            filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sBishop.svg".printf (color));
            set_piece_image ((Image) builder.get_object ("image_bishop"), filename);

            promotion_type_selector_dialog.response.connect (promotion_type_selector_response_cb);
        }

        promotion_type_selector_dialog.show ();

        promotion_type_completion_handler = (type) => handler (type);
    }

    private void set_piece_image (Image image, string filename)
    {
        const int size = 48;

        try
        {
            var h = new Rsvg.Handle.from_file (filename);

            var s = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
            var c = new Cairo.Context (s);
            h.render_document (c, Rsvg.Rectangle () { width = size, height = size, x = 0, y = 0 });

            var p = Gdk.pixbuf_get_from_surface (s, 0, 0, size, size);
            image.set_from_pixbuf (p);

            image.height_request = size;
        }
        catch (Error e)
        {
            warning ("Failed to load image %s: %s", filename, e.message);
        }
    }

    enum PromotionTypeSelected
    {
        QUEEN,
        KNIGHT,
        ROOK,
        BISHOP
    }

    public void quit_game ()
    {
        if (save_duration_timeout != 0)
            save_duration_cb ();

        autosave ();

        /* Save window state */
        settings.delay ();
        settings.set_int ("width", window.default_width);
        settings.set_int ("height", window.default_height);
        settings.set_boolean ("maximized", window.maximized);
        settings.apply ();

        window.destroy ();
        window = null;
    }

    private void autosave ()
    {
        /* Don't autosave if no moves (e.g. they have been undone) or only the computer has moved */
        if (!game_needs_saving)
        {
            FileUtils.remove (autosave_filename);
            return;
        }

        try
        {
            var autosave_file = File.new_for_path (autosave_filename);
            debug ("Writing current game to %s", autosave_file.get_path ());
            update_pgn_time_remaining ();
            pgn_game.write (autosave_file);
        }
        catch (Error e)
        {
            warning ("Failed to autosave: %s", e.message);
        }
    }

    private void update_history_panel ()
    {
        if (game == null)
            return;

        var move_number = scene.move_number;
        var n_moves = (int) game.n_moves;
        if (move_number < 0)
            move_number += 1 + n_moves;

        if (n_moves > 0 && move_number != 0 && !game.is_paused)
            enable_window_action (HISTORY_GO_FIRST_ACTION_NAME);
        else
            disable_window_action (HISTORY_GO_FIRST_ACTION_NAME);

        if (move_number > 0 && !game.is_paused)
            enable_window_action (HISTORY_GO_PREVIOUS_ACTION_NAME);
        else
            disable_window_action (HISTORY_GO_PREVIOUS_ACTION_NAME);

        if (move_number < n_moves && !game.is_paused)
            enable_window_action (HISTORY_GO_NEXT_ACTION_NAME);
        else
            disable_window_action (HISTORY_GO_NEXT_ACTION_NAME);

        if (n_moves > 0 && move_number != n_moves && !game.is_paused)
            enable_window_action (HISTORY_GO_LAST_ACTION_NAME);
        else
            disable_window_action (HISTORY_GO_LAST_ACTION_NAME);

        history_combo.sensitive = !game.is_paused;

        /* Set move text for all moves (it may have changed format) */
        int i = n_moves;
        foreach (var state in game.move_stack)
        {
            if (state.last_move != null)
            {
                TreeIter iter;
                if (history_combo.model.iter_nth_child (out iter, null, i))
                    set_move_text (iter, state.last_move);
            }
            i--;
        }

        history_combo.set_active (move_number);
    }

    private void scene_changed_cb (ChessScene scene)
    {
        update_history_panel ();
    }

    private void start_game ()
    {
        starting = true;

        var model = (Gtk.ListStore) history_combo.model;
        model.clear ();
        TreeIter iter;
        model.append (out iter);
        model.set (iter, 0,
                   /* Move History Combo: Go to the start of the game */
                   _("Game Start"), 1, 0, -1);
        history_combo.set_active_iter (iter);

        string fen = ChessGame.STANDARD_SETUP;
        string[] moves = new string[pgn_game.moves.length ()];
        var i = 0;
        foreach (var move in pgn_game.moves)
            moves[i++] = move;

        if (pgn_game.set_up)
        {
            if (pgn_game.fen != null)
                fen = pgn_game.fen;
            else
                warning ("Chess game has SetUp tag but no FEN tag");
        }

        try
        {
            game = new ChessGame (fen, moves);
        }
        catch (Error e)
        {
            run_invalid_move_dialog (e.message);
            start_new_game ();
            return;
        }

        /*
         * We only support simple timeouts
         * http://www.saremba.de/chessgml/standards/pgn/pgn-complete.htm#c9.6.1
         */
        if (pgn_game.time_control != null && int.parse (pgn_game.time_control) != 0)
        {
            if (pgn_game.white_time_left != null && pgn_game.black_time_left != null)
            {
                var white_seconds = int.parse (pgn_game.white_time_left);
                var black_seconds = int.parse (pgn_game.black_time_left);

                if (white_seconds >= 0 && black_seconds >= 0)
                    game.clock = new ChessClock (white_seconds, black_seconds);
            }
        }

        game.turn_started.connect (game_turn_cb);
        game.moved.connect (game_move_cb);
        game.undo.connect (game_undo_cb);
        game.ended.connect (game_end_cb);
        if (game.clock != null)
            game.clock.tick.connect (game_clock_tick_cb);

        scene.game = game;

        var white_engine = pgn_game.white_ai;
        var white_level = pgn_game.white_level;
        if (white_level == null)
            white_level = "normal";

        var black_engine = pgn_game.black_ai;
        var black_level = pgn_game.black_level;
        if (black_level == null)
            black_level = "normal";

        human_player = null;
        opponent = null;
        if (opponent_engine != null)
        {
            opponent_engine.stop ();
            opponent_engine.ready_changed.disconnect (engine_ready_cb);
            opponent_engine.moved.disconnect (engine_move_cb);
            opponent_engine.resigned.disconnect (engine_resigned_cb);
            opponent_engine.stopped_unexpectedly.disconnect (engine_stopped_unexpectedly_cb);
            opponent_engine.error.disconnect (engine_error_cb);
            opponent_engine.claim_draw.disconnect (engine_claim_draw_cb);
            opponent_engine.offer_draw.disconnect (engine_offer_draw_cb);
            opponent_engine = null;
        }

        if (white_engine != null)
        {
            opponent = game.white;
            human_player = game.black;
            opponent_engine = get_engine (white_engine, white_level);
            opponent.local_human = false;
            human_player.local_human = true;
        }
        else if (black_engine != null)
        {
            opponent = game.black;
            human_player = game.white;
            opponent_engine = get_engine (black_engine, black_level);
            opponent.local_human = false;
            human_player.local_human = true;
        }

        /* Game saved vs. human, or game saved vs. engine but none installed */
        if (opponent_engine == null)
        {
            game.black.local_human = true;
            game.white.local_human = true;
            human_player = null;
        }
        else
        {
            opponent_engine.ready_changed.connect (engine_ready_cb);
            opponent_engine.moved.connect (engine_move_cb);
            opponent_engine.resigned.connect (engine_resigned_cb);
            opponent_engine.stopped_unexpectedly.connect (engine_stopped_unexpectedly_cb);
            opponent_engine.error.connect (engine_error_cb);
            opponent_engine.claim_draw.connect (engine_claim_draw_cb);
            opponent_engine.offer_draw.connect (engine_offer_draw_cb);

            if (!opponent_engine.start ())
            {
                disable_window_action (SAVE_GAME_ACTION_NAME);
                game.result = ChessResult.BUG;
                game.rule = ChessRule.BUG;
                game_end_cb ();
                return;
            }
        }

        /* Replay current moves */
        for (var j = (int) game.move_stack.length () - 2; j >= 0; j--)
        {
            var state = game.move_stack.nth_data (j);
            game_move_cb (game, state.last_move);
        }

        if (game_file != null && game_file.get_path () == autosave_filename)
        {
            game_needs_saving = true;
            enable_window_action (SAVE_GAME_ACTION_NAME);
        }
        else
        {
            game_needs_saving = false;
            disable_window_action (SAVE_GAME_ACTION_NAME);
        }

        game.start ();

        int timer_increment_adj_value = 0;
        if (pgn_game.timer_increment != null)
            timer_increment_adj_value = int.parse (pgn_game.timer_increment);
        else
        {
            timer_increment_adj_value = settings.get_int ("timer-increment");
            pgn_game.timer_increment = timer_increment_adj_value.to_string ();
        }

        ClockType clock_type = ClockType.SIMPLE;
        if (pgn_game.clock_type != null)
            clock_type = ClockType.string_to_enum (pgn_game.clock_type);
        else
        {
            clock_type = ClockType.string_to_enum (settings.get_string ("clock-type"));
            pgn_game.clock_type = clock_type.to_string ();
        }

        clock_box.visible = game.clock != null;

        if (game.clock != null)
        {
            game.clock.extra_seconds = (int) timer_increment_adj_value;
            game.clock.clock_type = clock_type;
        }

        // If loading a completed saved game
        if (pgn_game.result == PGNGame.RESULT_WHITE)
            game.result = ChessResult.WHITE_WON;
        else if (pgn_game.result == PGNGame.RESULT_BLACK)
            game.result = ChessResult.BLACK_WON;
        else if (pgn_game.result == PGNGame.RESULT_DRAW)
            game.result = ChessResult.DRAW;

        if (opponent_engine != null)
            opponent_engine.start_game ();

        if (moves.length > 0 && game.clock != null)
        {
            game.clock.start ();
            enable_window_action (PAUSE_RESUME_ACTION_NAME);
        }
        else
        {
            disable_window_action (PAUSE_RESUME_ACTION_NAME);
        }

        update_history_panel ();
        update_action_status ();
        update_pause_resume_button ();

        if (ai_profiles == null)
        {
            update_game_status (null,
                                /* Warning at start of game when no chess engine is installed. */
                                _("No chess engine is installed. You will not be able to play against the computer."));
        }
        else
        {
            update_game_status ();
        }

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();

        starting = false;

        if (white_engine != null && game.current_player.color == Color.WHITE ||
            black_engine != null && game.current_player.color == Color.BLACK)
        {
            assert (opponent_engine != null);
            update_engine_timeout ();
            opponent_engine.move ();
        }

        // If loading a completed saved game
        if (game.result != ChessResult.IN_PROGRESS)
            game.stop (game.result, ChessRule.UNKNOWN);
    }

    private ChessEngine? get_engine (string name, string difficulty)
    {
        ChessEngine engine;
        AIProfile? profile = null;

        if (name == "human")
            return null;

        /* Backwards compatibility with our old spelling of GNU Chess */
        if (name == "GNUchess")
            name = "GNU Chess";

        foreach (var p in ai_profiles)
        {
            if (name == "" || p.name == name)
            {
                profile = p;
                break;
            }
        }
        if (profile == null)
        {
            warning ("Unknown AI profile %s", name);
            if (ai_profiles == null)
                return null;
            profile = ai_profiles.data;
        }

        string[] options, uci_go_options, args;
        switch (difficulty)
        {
        case "easy":
            options = profile.easy_options;
            uci_go_options = profile.easy_uci_go_options;
            args = profile.easy_args;
            break;
        default:
        case "normal":
            options = profile.normal_options;
            uci_go_options = profile.normal_uci_go_options;
            args = profile.normal_args;
            break;
        case "hard":
            options = profile.hard_options;
            uci_go_options = profile.hard_uci_go_options;
            args = profile.hard_args;
            break;
        }

        if (profile.protocol == "cecp")
        {
            warn_if_fail (uci_go_options.length == 0);
            engine = new ChessEngineCECP (profile.binary, args, profile.delay_seconds, options);
        }
        else if (profile.protocol == "uci")
        {
            engine = new ChessEngineUCI (profile.binary, args, profile.delay_seconds, options, uci_go_options);
        }
        else
        {
            warning ("Unknown AI protocol %s", profile.protocol);
            return null;
        }

        return engine;
    }

    private void engine_ready_cb (ChessEngine engine)
    {
        if (opponent_engine.ready)
        {
            view.queue_draw ();
        }
    }

    private void do_engine_move (string move)
    {
        if (!opponent.move (move))
        {
            warning ("Engine's move %s is illegal! Engine desync?", move);
            game.stop (ChessResult.BUG, ChessRule.BUG);
        }
    }

    private void engine_move_cb (ChessEngine engine, string move)
    {
        var original_game = game;
        var original_state = game.current_state;

        /* We don't inform the engine that the game has ended when the user
         * resigns. So if the game is over, and the next game has not yet
         * begun, we need to ignore it.
         */
        if (!game.is_started)
            return;

        if (!game.is_paused)
        {
            do_engine_move (move);
        }
        else
        {
            Timeout.add_seconds (1, () => {
                if (game.is_paused)
                {
                    return Source.CONTINUE;
                }
                else
                {
                    /* If the user has started a new game, then the state of the game is no longer
                     * what it was at the time.
                     * the engine moved, we need to discard the move. The engine will move again.
                     */
                    if (game == original_game)
                    {
                        assert (game.current_state == original_state);
                        do_engine_move (move);
                    }
                    return Source.REMOVE;
                }
            });
        }
    }

    private void engine_resigned_cb (ChessEngine engine)
    {
        opponent.resign ();
    }

    private void engine_stopped_unexpectedly_cb (ChessEngine engine)
    {
        /*
         * Many engines close themselves immediately after the end of the game.
         * So wait two seconds before displaying the unfortunate result. The
         * game is likely to end naturally first. (And in the off chance that
         * the game really is over but it takes more than two seconds for us to
         * figure that out, something really HAS gone wrong.)
         *
         * This is complicated a bit more because we have to be sure we're
         * stopping the original, presumably-buggy game, and not a new one that
         * the player just happens to have started two seconds after the last
         * game finished normally.
         */
        var original_game = game;
        Timeout.add_seconds (2, () => {
            if (game == original_game && game.is_started)
                game.stop (ChessResult.BUG, ChessRule.BUG);
            return Source.REMOVE;
        });
    }

    private void engine_error_cb (ChessEngine engine)
    {
        game.stop (ChessResult.BUG, ChessRule.BUG);
    }

    private void engine_claim_draw_cb (ChessEngine engine)
    {
        if (game.can_claim_draw ())
            opponent.claim_draw ();
        else if (!game.current_state.can_move (game.current_state.current_player))
            game.stop (ChessResult.DRAW, ChessRule.STALEMATE);
        else
            game.stop (ChessResult.BUG, ChessRule.BUG);
    }

    private void engine_offer_draw_cb (ChessEngine engine)
    {
        if (game.can_claim_draw ())
            opponent.claim_draw ();

        /*
         * If the draw cannot be claimed, do nothing.
         *
         * In the future we might want to actually give the player a choice
         * of accepting the draw, but this doesn't make much sense unless the
         * player can also offer a draw himself.
         */
    }

    private void game_clock_tick_cb (ChessClock clock)
    {
        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    private void game_turn_cb (ChessGame game, ChessPlayer player)
    {
        /*
         * Warning: this callback is invoked in response to the signal
         * ChessGame.turn_started (), which is misleadingly-named. It can fire
         * whenever an animation completes, such as when moving through history view.
         * Do not do anything here that cannot safely be done after pressing a
         * history button; in particular, anything involving an engine is probably
         * unsafe. Use game_move_cb () instead.
         *
         * It is really not possible to detect if we're using the history controls
         * or not, since even if we're viewing the most recent move, we could have
         * just returned from the past via history controls.
         */

        if (!game.is_started)
            return;

        if (game.clock != null)
            enable_window_action (PAUSE_RESUME_ACTION_NAME);
    }

    private void set_move_text (TreeIter iter, ChessMove move)
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

    private void update_engine_timeout ()
    {
        if (engine_timeout_source != 0)
        {
            Source.remove(engine_timeout_source);
            engine_timeout_source = 0;
        }

        if (!game.is_started)
            return;

        if (pgn_game.white_ai != null && game.current_player.color == Color.WHITE ||
            pgn_game.black_ai != null && game.current_player.color == Color.BLACK)
        {
            engine_timeout_source = Timeout.add_seconds (10, () => {
                engine_timeout_source = 0;
                warning ("Engine did not move for 10 seconds! Game over.");
                engine_error_cb (opponent_engine);
                return Source.REMOVE;
            });
        }
    }

    private void game_move_cb (ChessGame game, ChessMove move)
    {
        /* Warning: this callback is invoked several times when loading a game. */

        enable_window_action (NEW_GAME_ACTION_NAME);

        /* Need to save after each move */
        game_needs_saving = true;

        /* If the only mover is the AI, then don't bother saving */
        if (move.number == 1 && opponent != null && opponent.color == Color.WHITE)
            game_needs_saving = false;

        if (move.number > pgn_game.moves.length ())
            pgn_game.moves.append (move.get_san ());

        /* Automatically return view to the present */
        scene.move_number = -1;

        var model = (Gtk.ListStore) history_combo.model;
        TreeIter iter;
        model.append (out iter);
        model.set (iter, 1, move.number, -1);
        set_move_text (iter, move);

        /* Follow the latest move */
        if (move.number == game.n_moves)
            history_combo.set_active_iter (iter);

        enable_window_action (SAVE_GAME_ACTION_NAME);
        enable_window_action (SAVE_GAME_AS_ACTION_NAME);
        update_history_panel ();
        update_action_status ();
        update_game_status ();

        view.queue_draw ();

        /* This work goes in a timeout to give the game widget a chance to
         * redraw first, so the pieces are shown to move before displaying the
         * claim draw dialog. */
        var started = !starting && game.is_started;
        Timeout.add (100, () => {
            if (game.can_claim_draw () && started)
                present_claim_draw_dialog ();

            if (opponent_engine != null)
            {
                opponent_engine.report_move (move);

                if (move.piece.color != opponent.color && started)
                    opponent_engine.move ();
            }

            return Source.REMOVE;
        });

        if (started)
            update_engine_timeout ();
    }

    private void game_undo_cb (ChessGame game)
    {
        /* Notify AI */
        if (opponent_engine != null)
            opponent_engine.undo ();

        /* Remove from the PGN game */
        pgn_game.moves.remove_link (pgn_game.moves.last ());
        pgn_game.result = PGNGame.RESULT_IN_PROGRESS;

        /* Remove from the history */
        var model = (Gtk.ListStore) history_combo.model;
        TreeIter iter;
        model.iter_nth_child (out iter, null, model.iter_n_children (null) - 1);
        model.remove (ref iter);

        /* Always undo from the most recent move */
        scene.move_number = -1;

        /* Go back one */
        model.iter_nth_child (out iter, null, model.iter_n_children (null) - 1);
        history_combo.set_active_iter (iter);
        view.queue_draw ();

        if (game.n_moves > 0)
        {
            game_needs_saving = true;
            enable_window_action (SAVE_GAME_ACTION_NAME);
            enable_window_action (SAVE_GAME_AS_ACTION_NAME);
        }
        else
        {
            game_needs_saving = false;
            disable_window_action (NEW_GAME_ACTION_NAME);
            disable_window_action (SAVE_GAME_ACTION_NAME);
            disable_window_action (SAVE_GAME_AS_ACTION_NAME);
        }

        update_history_panel ();
        update_action_status ();
        update_game_status ();
    }

    private void update_action_status ()
    {
        var can_resign = game.n_moves > 0 && !game.is_paused;
        if (can_resign)
            enable_window_action (RESIGN_ACTION_NAME);
        else
            disable_window_action (RESIGN_ACTION_NAME);

        /* Can undo once the human player has made a move */
        var can_undo = game.n_moves > 0 && !game.is_paused;
        if (opponent != null && opponent.color == Color.WHITE)
            can_undo = game.n_moves > 1 && !game.is_paused;

        if (can_undo)
            enable_window_action (UNDO_MOVE_ACTION_NAME);
        else
            disable_window_action (UNDO_MOVE_ACTION_NAME);
    }

    private string compute_current_title ()
    {
        if (human_player != null &&
            human_player.color == game.current_player.color &&
            game.current_state.is_in_check (game.current_player))
        {
            if (game.current_player.color == Color.WHITE)
                /* Game status on White's turn when in check */
               return _("White is in Check");
            else
                /* Game status on Black's turn when in check */
                return _("Black is in Check");
        }
        else if (game.current_player.color == Color.WHITE)
        {
            if (human_player == null || human_player.color == Color.WHITE)
                /* Game status on White's turn if White is human */
                return _("White to Move");
            else
                /* Game status on White's turn if White is a computer */
                return _("White is Thinking…");
        }
        else
        {
            if (human_player == null || human_player.color == Color.BLACK)
                /* Game status on Black's turn if Black is human */
                return _("Black to Move");
            else
                /* Game status on Black's turn if Black is a computer */
                return _("Black is Thinking…");
        }
    }

    private string? compute_status_info ()
    {
        if (game.current_state.last_move != null &&
            game.current_state.last_move.en_passant)
        {
            if (game.current_player.color == Color.WHITE)
                /* Game status when Black captures White's pawn en passant */
                return _("Black captured White's pawn <span font_style='italic'>en passant</span>.");
            else
                /* Game status when White captures Black's pawn en passant */
                return _("White captured Black's pawn <span font_style='italic'>en passant</span>.");
        }

        return null;
    }

    private void update_game_status (string? title = null, string? info = null)
    {
        window.title = title != null ? title : compute_current_title ();
        info_bar_label.label = info != null ? info : compute_status_info ();
        /* Setting the label to null actually just sets it to an empty string. */
        info_bar.visible = info_bar_label.label != "";
    }

    private void update_pause_resume_button ()
    {
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

    private void game_end_cb ()
    {
        disable_window_action (RESIGN_ACTION_NAME);
        disable_window_action (PAUSE_RESUME_ACTION_NAME);

        /* In case of engine desync before the first move, or after undo */
        enable_window_action (NEW_GAME_ACTION_NAME);

        game_needs_saving = false;

        string what = "";
        switch (game.result)
        {
        case ChessResult.WHITE_WON:
            /* Game status when the white player wins */
            what = _("White Wins");
            pgn_game.result = PGNGame.RESULT_WHITE;
            break;
        case ChessResult.BLACK_WON:
            /* Game status when the black player wins */
            what = _("Black Wins");
            pgn_game.result = PGNGame.RESULT_BLACK;
            break;
        case ChessResult.DRAW:
            /* Game status when the game is drawn */
            what = _("Game is Drawn");
            pgn_game.result = PGNGame.RESULT_DRAW;
            break;
        case ChessResult.BUG:
            /* Game status when something goes wrong with the engine. */
            what = _("Oops!");
            /* don't set the pgn_game result; these are standards */
            break;
        default:
            break;
        }

        string why = "";
        switch (game.rule)
        {
        case ChessRule.CHECKMATE:
            if (game.result == ChessResult.WHITE_WON)
                /* Game status when Black is checkmated */
                why = _("Black is in check and cannot move.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Game status when White is checkmated */
                why = _("White is in check and cannot move.");
            else
                assert_not_reached ();
            break;
        case ChessRule.STALEMATE:
            /* Game status when the game terminates due to a stalemate */
            why = _("Opponent cannot move.");
            break;
        case ChessRule.FIFTY_MOVES:
            /* Game status when the game is drawn due to the fifty move rule */
            why = _("No piece was taken or pawn moved in fifty moves.");
            break;
        case ChessRule.SEVENTY_FIVE_MOVES:
            /* Game status when the game is drawn due to the 75 move rule */
            why = _("No piece was taken or pawn moved in 75 moves.");
            break;
        case ChessRule.TIMEOUT:
            if (game.result == ChessResult.WHITE_WON)
                /* Game status when the game ends due to Black's clock stopping */
                why = _("Black has run out of time.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Game status when the game ends due to White's clock stopping */
                why = _("White has run out of time.");
            else
                assert_not_reached ();
            break;
        case ChessRule.THREE_FOLD_REPETITION:
            /* Game status when the game is drawn due to the three-fold-repetition rule */
            why = _("The same board state has occurred three times.");
            break;
        case ChessRule.FIVE_FOLD_REPETITION:
            /* Game status when the game is drawn due to the five-fold-repetition rule */
            why = _("The same board state has occurred five times.");
            break;
        case ChessRule.INSUFFICIENT_MATERIAL:
            /* Game status when the game is drawn due to the insufficient material rule */
            why = _("Neither player can checkmate.");
            break;
        case ChessRule.RESIGN:
            if (game.result == ChessResult.WHITE_WON)
                /* Game status when the game ends due to the black player resigning */
                why = _("Black has resigned.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Game status when the game ends due to the white player resigning */
                why = _("White has resigned.");
            else
                assert_not_reached ();
            break;
        case ChessRule.ABANDONMENT:
            /* Game status when a game is abandoned */
            why = _("The game has been abandoned.");
            pgn_game.termination = PGNGame.TERMINATE_ABANDONED;
            break;
        case ChessRule.DEATH:
            /* Game status when the game ends due to a player dying during the game. */
            why = _("The game log says a player died!");
            pgn_game.termination = PGNGame.TERMINATE_DEATH;
            break;
        case ChessRule.BUG:
            /* Game status when something goes wrong with the engine. */
            why = _("The computer player is confused. The game cannot continue.");
            /* Don't set pgn_game termination; these are standards*/
            break;
        case ChessRule.UNKNOWN:
            /* Game status when we don't know the why the game ended
             * Set it to the pgn_file_name
             * We are using this when loading completed saved games */
             why = game_file.get_basename ();
             break;
        }

        update_game_status (what, why);
        update_engine_timeout ();

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    private void prompt_save_game_response_cb (int response_id)
        requires (prompt_save_game_cb != null)
    {
        if (response_id == ResponseType.CANCEL || response_id == ResponseType.DELETE_EVENT)
        {
            prompt_save_game_cb (true);
            prompt_save_game_cb = null;
        }
        else if (response_id == ResponseType.YES)
        {
            present_save_dialog ();
            prompt_save_game_cb (false);
        }
        else
        {
            warn_if_fail (response_id == ResponseType.NO);
            /* Remove completed game from history */
            game_needs_saving = false;
            autosave ();

            prompt_save_game_cb (false);
            prompt_save_game_cb = null;
        }

        prompt_save_game_dialog.hide ();
    }

    private void prompt_save_game (string prompt_text)
        requires (prompt_save_game_cb != null)
    {
        if (!game_needs_saving)
        {
            prompt_save_game_cb (false);
            return;
        }

        if (prompt_save_game_dialog == null)
        {
            prompt_save_game_dialog = new MessageDialog (window,
                                                         DialogFlags.MODAL,
                                                         MessageType.QUESTION,
                                                         ButtonsType.NONE,
                                                         prompt_text);
            prompt_save_game_dialog.add_button (_("_Cancel"), ResponseType.CANCEL);

            if (game.result == ChessResult.IN_PROGRESS)
            {
                prompt_save_game_dialog.add_button (_("_Abandon game"), ResponseType.NO);
                prompt_save_game_dialog.add_button (_("_Save game for later"), ResponseType.YES);
            }
            else
            {
                prompt_save_game_dialog.add_button (_("_Discard game"), ResponseType.NO);
                prompt_save_game_dialog.add_button (_("_Save game log"), ResponseType.YES);
            }

            prompt_save_game_dialog.response.connect (prompt_save_game_response_cb);
        }

        prompt_save_game_dialog.show ();
    }

    private void claim_draw_response_cb (int response_id)
    {
        game.unpause ();

        if (response_id == ResponseType.ACCEPT)
            game.current_player.claim_draw ();

        claim_draw_dialog.hide ();
    }

    private void present_claim_draw_dialog ()
        requires (game.can_claim_draw ())
    {
        game.pause (false);

        if (claim_draw_dialog == null)
        {
            claim_draw_dialog = new MessageDialog (window,
                                                   DialogFlags.MODAL,
                                                   MessageType.QUESTION,
                                                   ButtonsType.NONE,
                                                   /* Title of claim draw dialog */
                                                   _("Would you like to claim a draw?"));

            string reason;
            if (game.is_fifty_move_rule_fulfilled ())
            {
                /* Message in claim draw dialog when triggered by fifty-move rule */
                reason = _("You may claim a draw because fifty moves have passed without a capture or pawn advancement. (The computer player may still choose to claim a draw even if you choose to keep playing.)");
            }
            else if (game.is_three_fold_repeat ())
            {
                /* Message in claim draw dialog when triggered by three-fold repetition */
                reason = _("You may claim a draw because the current board position has occurred three times. (The computer player may still choose to claim a draw even if you choose to keep playing.)");
            }
            else assert_not_reached ();

            claim_draw_dialog.secondary_text = reason;

            claim_draw_dialog.add_buttons (/* Option in claim draw dialog */
                                           _("_Keep Playing"), ResponseType.REJECT,
                                           /* Option in claim draw dialog */
                                           _("_Claim Draw"), ResponseType.ACCEPT,
                                           null);

            claim_draw_dialog.response.connect (claim_draw_response_cb);
        }

        claim_draw_dialog.show ();
    }

    private void new_game_prompt_save_game_cb (bool cancelled)
    {
        prompt_save_game_cb = null;

        if (!cancelled)
            start_new_game ();
    }

    public void new_game_cb ()
        requires (prompt_save_game_cb == null)
    {
        prompt_save_game_cb = new_game_prompt_save_game_cb;
        prompt_save_game (_("Save this game before starting a new one?"));
    }

    private void resign_response_cb (int response_id)
    {
        game.unpause ();

        if (response_id == ResponseType.ACCEPT)
        {
            if (human_player != null)
                human_player.resign ();
            else
                game.current_player.resign ();
        }

        resign_dialog.hide ();
    }

    public void resign_cb ()
    {
        game.pause (false);

        if (resign_dialog == null)
        {
            resign_dialog = new MessageDialog (window,
                                               DialogFlags.MODAL,
                                               MessageType.QUESTION,
                                               ButtonsType.NONE,
                                               /* Title of warning dialog when player clicks Resign */
                                               _("Are you sure you want to resign?"));
            resign_dialog.format_secondary_text (
                /* Text on warning dialog when player clicks Resign */
                _("This makes sense if you plan to save the game as a record of your loss."));
            resign_dialog.add_buttons (/* Option on warning dialog when player clicks resign */
                                       _("_Keep Playing"), ResponseType.REJECT,
                                       /* Option on warning dialog when player clicks resign */
                                       _("_Resign"), ResponseType.ACCEPT,
                                       null);
        }

        resign_dialog.response.connect (resign_response_cb);
        resign_dialog.show ();
    }

    public void undo_move_cb ()
    {
        // No piece should be selected now
        scene.selected_rank = -1;
        scene.selected_file = -1;

        if (opponent != null)
            human_player.undo ();
        else
            game.opponent.undo ();
    }

    public void pause_resume_cb ()
    {
        if (game.is_paused)
            game.unpause ();
        else
            game.pause ();

        update_pause_resume_button ();
        update_history_panel ();
        update_action_status ();
    }

    public void quit_cb ()
    {
        quit_game ();
    }

    private void draw_white_time_label (DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (game.clock, Color.WHITE), { 0.0, 0.0, 0.0 }, { 1.0, 1.0, 1.0 });
    }

    private void draw_black_time_label (DrawingArea drawing_area, Cairo.Context c, int width, int height)
    {
        draw_time (drawing_area, c, width, height, make_clock_text (game.clock, Color.BLACK), { 1.0, 1.0, 1.0 }, { 0.0, 0.0, 0.0 });
    }

    private string make_clock_text (ChessClock? clock, Color color)
        requires (clock != null)
    {
        int time;
        if (color == Color.WHITE)
            time = game.clock.white_remaining_seconds;
        else
            time = game.clock.black_remaining_seconds;

        if (time >= 60)
            return "%d∶\xE2\x80\x8E%02d".printf (time / 60, time % 60);
        else
            return "∶\xE2\x80\x8E%02d".printf (time);
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

    private void draw_time (Widget widget, Cairo.Context c, int width, int height, string text, double[] fg, double[] bg)
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
        if ((widget.get_state_flags () & StateFlags.INSENSITIVE) != 0)
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

    [CCode (cname = "history_combo_changed_cb", instance_pos = -1)]
    public void history_combo_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int move_number;
        combo.model.@get (iter, 1, out move_number, -1);
        if (game == null || move_number == game.n_moves)
            move_number = -1;
        scene.move_number = move_number;
    }

    private void history_go_first_cb ()
    {
        scene.move_number = 0;
    }

    private void history_go_previous_cb ()
    {
        if (scene.move_number == 0)
            return;

        if (scene.move_number == -1)
            scene.move_number = (int) game.n_moves - 1;
        else
            scene.move_number = scene.move_number - 1;
    }

    private void history_go_next_cb ()
    {
        if (scene.move_number == -1)
            return;

        int move_number = scene.move_number + 1;
        if (move_number >= game.n_moves)
            scene.move_number = -1;
        else
            scene.move_number = move_number;
    }

    private void history_go_last_cb ()
    {
        scene.move_number = -1;
    }

    private void preferences_response_cb (int response_id)
    {
        preferences_dialog.hide ();
    }

    public void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.show ();
            return;
        }

        Builder builder = new Builder ();
        builder.set_current_object (this);
        try
        {
            builder.add_from_resource ("/org/gnome/Chess/ui/preferences.ui");
        }
        catch (Error e)
        {
            error ("Failed to load UI resource: %s", e.message);
        }

        preferences_dialog = (Dialog) builder.get_object ("preferences");
        preferences_dialog.transient_for = window;
        preferences_dialog.modal = true;

        settings.bind ("show-numbering", builder.get_object ("show_numbering_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-move-hints", builder.get_object ("show_move_hints_check"),
                       "active", SettingsBindFlags.DEFAULT);

        side_combo = (ComboBox) builder.get_object ("side_combo");
        side_combo.set_active (settings.get_enum ("play-as"));

        difficulty_combo = (ComboBox) builder.get_object ("difficulty_combo");
        set_combo (difficulty_combo, 1, settings.get_string ("difficulty"));

        var ai_combo = (ComboBox) builder.get_object ("opponent_combo");
        var ai_model = (Gtk.ListStore) ai_combo.model;
        var opponent_name = settings.get_string ("opponent");
        if (opponent_name == "human")
            ai_combo.set_active (0);
        foreach (var p in ai_profiles)
        {
            TreeIter iter;
            ai_model.append (out iter);
            ai_model.set (iter, 0, p.name, 1, p.name, -1);
            if (p.name == opponent_name || (opponent_name == "" && ai_combo.get_active () == -1))
                ai_combo.set_active_iter (iter);
        }
        if (ai_combo.get_active () == -1)
        {
            ai_combo.set_active (0);
            settings.set_string ("opponent", "human");
        }

        duration_adjustment = (Adjustment) builder.get_object ("duration_adjustment");
        timer_increment_adjustment = (Adjustment) builder.get_object ("timer_increment_adjustment");
        custom_duration_box = (Box) builder.get_object ("custom_duration_box");
        timer_increment_box = (Box) builder.get_object ("timer_increment_box");
        custom_duration_units_combo = (ComboBox) builder.get_object ("custom_duration_units_combo");
        timer_increment_label = (Label) builder.get_object ("timer_increment_label");
        timer_increment_units_combo = (ComboBox) builder.get_object ("timer_increment_units_combo");
        clock_type_combo = (ComboBox) builder.get_object ("clock_type_combo");
        duration_combo = (ComboBox) builder.get_object ("duration_combo");
        set_duration (settings.get_int ("duration"));

        if (pgn_game.clock_type != null)
            set_clock_type (ClockType.string_to_enum (pgn_game.clock_type));
        else
            set_clock_type ((int) ClockType.string_to_enum (settings.get_string ("clock-type")));

        if (pgn_game.timer_increment != null)
            set_timer_increment (int.parse (pgn_game.timer_increment));
        else
            set_timer_increment (settings.get_int ("timer-increment"));

        var orientation_combo = (ComboBox) builder.get_object ("orientation_combo");
        set_combo (orientation_combo, 1, settings.get_string ("board-side"));

        var move_combo = (ComboBox) builder.get_object ("move_format_combo");
        set_combo (move_combo, 1, settings.get_string ("move-format"));

        var theme_combo = (ComboBox) builder.get_object ("piece_style_combo");
        set_combo (theme_combo, 1, settings.get_string ("piece-theme"));

        /* Human vs. human */
        if (ai_combo.get_active () == 0)
        {
            side_combo.sensitive = false;
            difficulty_combo.sensitive = false;
        }

        preferences_dialog.response.connect (preferences_response_cb);
        preferences_dialog.show ();
    }

    private void set_combo (ComboBox combo, int value_index, string value)
    {
        TreeIter iter;
        var model = combo.model;
        if (!model.get_iter_first (out iter))
            return;
        do
        {
            string v;
            model.@get (iter, value_index, out v, -1);
            if (v == value)
            {
                combo.set_active_iter (iter);
                return;
            }
        } while (model.iter_next (ref iter));
    }

    private string? get_combo (ComboBox combo, int value_index)
    {
        string value;
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return null;
        combo.model.@get (iter, value_index, out value, -1);
        return value;
    }

    [CCode (cname = "side_combo_changed_cb", instance_pos = -1)]
    public void side_combo_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int player;
        combo.model.@get (iter, 1, out player, -1);

        settings.set_enum ("play-as", player);
    }

    [CCode (cname = "opponent_combo_changed_cb", instance_pos = -1)]
    public void opponent_combo_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string opponent;
        combo.model.@get (iter, 1, out opponent, -1);
        settings.set_string ("opponent", opponent);
        bool vs_human = (combo.get_active () == 0);
        side_combo.sensitive = !vs_human;
        difficulty_combo.sensitive = !vs_human;
    }

    [CCode (cname = "difficulty_combo_changed_cb", instance_pos = -1)]
    public void difficulty_combo_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string difficulty;
        combo.model.@get (iter, 1, out difficulty, -1);
        settings.set_string ("difficulty", difficulty);
    }

    private void set_clock_type (int clock_type)
    {
        var model = clock_type_combo.model;
        TreeIter iter, active_iter_clock_type = {};

        /* Find the largest units that can be used for this value */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int type;
                model.@get (iter, 1, out type, -1);
                if (type == clock_type)
                {
                    active_iter_clock_type = iter;
                }
            } while (model.iter_next (ref iter));
        }

        clock_type_combo.set_active_iter (active_iter_clock_type);
        clock_type_changed_cb (clock_type_combo);
    }

    private void set_timer_increment (int timer_increment)
    {
        int timer_increment_multiplier = 1;

        if (timer_increment >= 60)
        {
            timer_increment_adjustment.value = timer_increment / 60;
            timer_increment_multiplier = 60;
        } else
            timer_increment_adjustment.value = timer_increment;

        var model = timer_increment_units_combo.model;
        TreeIter iter, reqd_iter = {};

        /* Find the largest units that can be used for this value */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                if (multiplier == timer_increment_multiplier)
                {
                    reqd_iter = iter;
                }
            } while (model.iter_next (ref iter));
        }

        timer_increment_units_combo.set_active_iter (reqd_iter);
        timer_increment_units_changed_cb (timer_increment_units_combo);
    }

    private void set_duration (int duration, bool simplify = true)
    {
        var model = custom_duration_units_combo.model;
        TreeIter iter, max_iter = {};

        /* Find the largest units that can be used for this value */
        int max_multiplier = 0;
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                if (multiplier > max_multiplier && duration % multiplier == 0)
                {
                    max_multiplier = multiplier;
                    max_iter = iter;
                }
            } while (model.iter_next (ref iter));
        }

        /* Set the spin button to the value with the chosen units */
        var value = 0;
        if (max_multiplier > 0)
        {
            value = duration / max_multiplier;
            duration_adjustment.value = value;
            custom_duration_units_combo.set_active_iter (max_iter);
        }

        if (!simplify)
            return;

        model = duration_combo.model;
        if (!model.get_iter_first (out iter))
            return;
        do
        {
            int v;
            model.@get (iter, 1, out v, -1);
            if (v == duration || v == -1)
            {
                duration_combo.set_active_iter (iter);
                custom_duration_box.visible = v == -1;
                return;
            }
        } while (model.iter_next (ref iter));
    }

    private int get_duration ()
    {
        TreeIter iter;
        if (duration_combo.get_active_iter (out iter))
        {
            int duration;
            duration_combo.model.@get (iter, 1, out duration, -1);
            if (duration >= 0)
                return duration;
        }

        var magnitude = (int) duration_adjustment.value;
        int multiplier = 1;
        if (custom_duration_units_combo.get_active_iter (out iter))
            custom_duration_units_combo.model.@get (iter, 1, out multiplier, -1);

        switch (multiplier)
        {
        case 60:
            if (duration_adjustment.get_upper () != 600)
                duration_adjustment.set_upper (600);
            break;
        case 3600:
            if (duration_adjustment.get_upper () != 10)
            {
                duration_adjustment.set_upper (10);
                if (duration_adjustment.value > 10)
                {
                    duration_adjustment.value = 10;
                    magnitude = 10;
                }
            }
            break;
        default:
            assert_not_reached ();
        }

        return magnitude * multiplier;
    }

    private bool save_duration_cb ()
    {
        settings.set_int ("duration", get_duration ());
        Source.remove (save_duration_timeout);
        save_duration_timeout = 0;
        return Source.REMOVE;
    }

    [CCode (cname = "duration_changed_cb", instance_pos = -1)]
    public void duration_changed_cb (Adjustment adjustment)
    {
        var model = (Gtk.ListStore) custom_duration_units_combo.model;
        TreeIter iter;
        /* Set the unit labels to the correct plural form */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                switch (multiplier)
                {
                case 60:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in minutes */
                                                  "minute", "minutes", (ulong) adjustment.value), -1);
                    break;
                case 3600:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in hours */
                                                  "hour", "hours", (ulong) adjustment.value), -1);
                    break;
                default:
                    assert_not_reached ();
                }
            } while (model.iter_next (ref iter));
        }

        save_duration ();
    }

    [CCode (cname = "duration_units_changed_cb", instance_pos = -1)]
    public void duration_units_changed_cb (Widget widget)
    {
        save_duration ();
    }

    [CCode (cname = "timer_increment_units_changed_cb", instance_pos = -1)]
    public void timer_increment_units_changed_cb (Widget widget)
    {
        var model = (Gtk.ListStore) timer_increment_units_combo.model;
        TreeIter iter;
        int multiplier = 0;
        /* Set the unit labels to the correct plural form */
        if (model.get_iter_first (out iter))
        {
            do
            {
                model.@get (iter, 1, out multiplier, -1);
                switch (multiplier)
                {
                case 1:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom clock type set in seconds */
                                                  "second", "seconds", (ulong) timer_increment_adjustment.value), -1);
                    break;
                case 60:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom clock type set in minutes */
                                                  "minute", "minutes", (ulong) timer_increment_adjustment.value), -1);
                    break;
                default:
                    assert_not_reached ();
                }
            } while (model.iter_next (ref iter));
        }

        if (timer_increment_units_combo.get_active_iter (out iter))
            timer_increment_units_combo.model.@get (iter, 1, out multiplier, -1);

        switch (multiplier)
        {
        case 1:
            if (timer_increment_adjustment.get_upper () != 59)
                timer_increment_adjustment.set_upper (59);
            break;
        case 60:
            if (timer_increment_adjustment.get_upper () != 10)
            {
                timer_increment_adjustment.set_upper (10);
                if (timer_increment_adjustment.value > 10)
                    timer_increment_adjustment.value = 10;
            }
            break;
        default:
            assert_not_reached ();
        }
        settings.set_int ("timer-increment", (int) timer_increment_adjustment.value * multiplier);
    }

    private void save_duration ()
    {
        /* Delay writing the value as it this event will be generated a lot spinning through the value */
        if (save_duration_timeout != 0)
            Source.remove (save_duration_timeout);
        save_duration_timeout = Timeout.add (100, save_duration_cb);
    }

    [CCode (cname = "duration_combo_changed_cb", instance_pos = -1)]
    public void duration_combo_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int duration;
        combo.model.@get (iter, 1, out duration, -1);
        custom_duration_box.visible = duration < 0;
        clock_type_combo.sensitive = duration != 0;

        if (duration == 0)
            set_clock_type (ClockType.SIMPLE);

        if (duration >= 0)
            set_duration (duration, false);
        /* Default to one hour (30 minutes/player) when setting custom duration */
        else if (get_duration () <= 0)
            set_duration (60 * 60, false);

        save_duration ();
    }

    [CCode (cname = "clock_type_changed_cb", instance_pos = -1)]
    public void clock_type_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        ClockType clock_type;
        combo.model.@get (iter, 1, out clock_type, -1);

        timer_increment_box.visible = clock_type > 0;
        timer_increment_label.visible = clock_type > 0;
        settings.set_string ("clock-type", clock_type.to_string ());
    }

    [CCode (cname = "piece_style_combo_changed_cb", instance_pos = -1)]
    public void piece_style_combo_changed_cb (ComboBox combo)
    {
        settings.set_string ("piece-theme", get_combo (combo, 1));
    }

    [CCode (cname = "move_format_combo_changed_cb", instance_pos = -1)]
    public void move_format_combo_changed_cb (ComboBox combo)
    {
        settings.set_string ("move-format", get_combo (combo, 1));
    }

    [CCode (cname = "orientation_combo_changed_cb", instance_pos = -1)]
    public void orientation_combo_changed_cb (ComboBox combo)
    {
        settings.set_string ("board-side", get_combo (combo, 1));
    }

    public void help_cb ()
    {
        show_uri (window, "help:gnome-chess", Gdk.CURRENT_TIME);
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>", null };
    private const string[] artists = { "Max Froumentin", "Jakub Steiner", null };

    public void about_cb ()
    {
        if (about_dialog != null)
        {
            about_dialog.show ();
            return;
        }

        about_dialog = new AboutDialog ();
        about_dialog.transient_for = window;
        about_dialog.modal = true;
        about_dialog.program_name = _("Chess");
        about_dialog.version = VERSION;
        about_dialog.copyright = copyrights;
        about_dialog.license_type = License.GPL_3_0;
        about_dialog.comments = _("A classic game of positional strategy");
        about_dialog.authors = authors;
        about_dialog.artists = artists;
        about_dialog.translator_credits = _("translator-credits");
        about_dialog.website = "https://wiki.gnome.org/Apps/Chess";
        about_dialog.logo_icon_name = "org.gnome.Chess";
        about_dialog.hide_on_close = true;
        about_dialog.show ();
    }

    private void run_invalid_pgn_dialog ()
    {
        var invalid_pgn_dialog = new MessageDialog (window,
                                                    DialogFlags.MODAL,
                                                    MessageType.ERROR,
                                                    ButtonsType.NONE,
                                                    _("This does not look like a valid PGN game."));
        invalid_pgn_dialog.add_button (_("_OK"), ResponseType.OK);

        invalid_pgn_dialog.response.connect (() => invalid_pgn_dialog.destroy ());
        invalid_pgn_dialog.show ();
    }

    private void run_invalid_move_dialog (string error_message)
    {
        var invalid_move_dialog = new MessageDialog (window,
                                                     DialogFlags.MODAL,
                                                     MessageType.ERROR,
                                                     ButtonsType.NONE,
                                                     error_message);
        invalid_move_dialog.add_button (_("_OK"), ResponseType.OK);

        invalid_move_dialog.response.connect (() => invalid_move_dialog.destroy ());
        invalid_move_dialog.show ();
    }

    private void update_pgn_time_remaining ()
    {
        if (game.clock != null)
        {
            /* We currently only support simple timeouts */
            pgn_game.white_time_left = game.clock.white_remaining_seconds.to_string ();
            pgn_game.black_time_left = game.clock.black_remaining_seconds.to_string ();
        }
    }

    private void save_dialog_response_cb (int response_id)
    {
        if (response_id == ResponseType.ACCEPT)
        {
            update_pgn_time_remaining ();

            try
            {
                game_file = save_dialog.get_file ();
                pgn_game.write (game_file);

                disable_window_action (SAVE_GAME_ACTION_NAME);
                game_needs_saving = false;
            }
            catch (Error e)
            {
                if (save_error_dialog == null)
                {
                    save_error_dialog = new MessageDialog (window,
                                                           DialogFlags.MODAL,
                                                           MessageType.ERROR,
                                                           ButtonsType.NONE,
                                                           _("Failed to save game: %s"),
                                                           e.message);
                    save_error_dialog.add_button (_("_OK"), ResponseType.OK);
                    save_error_dialog.response.connect (() => save_error_dialog.hide ());
                }

                save_error_dialog.show ();
            }
        }

        save_dialog.hide ();

        if (prompt_save_game_cb != null)
        {
            prompt_save_game_cb (false);
            prompt_save_game_cb = null;
        }
    }

    private void present_save_dialog ()
    {
        /* Show active dialog */
        if (save_dialog == null)
        {
            save_dialog = new FileChooserNative (/* Title of save game dialog */
                                                 _("Save Chess Game"),
                                                 window, FileChooserAction.SAVE,
                                                 _("_Save"),
                                                 _("_Cancel"));

            var set_file = false;
            if (game_file != null)
            {
                /* If the path is under /run, we are probably sandboxed, and the
                 * path we see is entirely different from the path to the file
                 * on the host system. In this case, we should force the user to
                 * navigate the filesystem rather than displaying /run, which
                 * would be meaningless to the user.
                 *
                 * Also, of course we don't want to preselect the autosave file.
                 */
                var path = game_file.get_path ();
                if (path != autosave_filename && !path.has_prefix ("/run"))
                {
                    try
                    {
                        save_dialog.set_file (game_file);
                        set_file = true;
                    }
                    catch (Error e)
                    {
                        warning ("Failed to set file chooser default file: %s", e.message);
                    }
                }
            }

            if (!set_file)
            {
                save_dialog.set_current_name (/* Default filename for the save game dialog */
                                              _("Untitled Chess Game") + ".pgn");
            }

            /* Filter out non PGN files by default */
            var pgn_filter = new FileFilter ();
            /* Save Game Dialog: Name of filter to show only PGN files */
            pgn_filter.set_filter_name (_("PGN files"));
            pgn_filter.add_pattern ("*.pgn");
            save_dialog.add_filter (pgn_filter);

            var all_filter = new FileFilter ();
            /* Save Game Dialog: Name of filter to show all files */
            all_filter.set_filter_name (_("All files"));
            all_filter.add_pattern ("*");
            save_dialog.add_filter (all_filter);

            save_dialog.modal = true;
            save_dialog.response.connect (save_dialog_response_cb);
        }

        save_dialog.show ();
    }

    public void save_game_cb ()
    {
        if (game_file == null || game_file.get_path () == autosave_filename)
        {
            present_save_dialog ();
            return;
        }

        update_pgn_time_remaining ();

        try
        {
            pgn_game.write (game_file);
            game_needs_saving = false;
            disable_window_action (SAVE_GAME_ACTION_NAME);
        }
        catch (Error e)
        {
            present_save_dialog ();
        }
    }

    public void save_game_as_cb ()
    {
        present_save_dialog ();
    }

    private void open_game_response_cb (int response_id)
    {
        if (response_id == ResponseType.ACCEPT)
        {
            game_file = open_dialog.get_file ();
            load_game (game_file);
        }

        open_dialog.hide ();
    }

    private void open_game_prompt_save_game_cb (bool cancelled)
    {
        prompt_save_game_cb = null;

        if (cancelled)
            return;

        /* Show active dialog */
        if (open_dialog == null)
        {
            open_dialog = new FileChooserNative (/* Title of load game dialog */
                                                 _("Load Chess Game"),
                                                 window, FileChooserAction.OPEN,
                                                 _("_Open"),
                                                 _("_Cancel"));

            /* Filter out non PGN files by default */
            var pgn_filter = new FileFilter ();
            /* Load Game Dialog: Name of filter to show only PGN files */
            pgn_filter.set_filter_name (_("PGN files"));
            pgn_filter.add_pattern ("*.pgn");
            open_dialog.add_filter (pgn_filter);

            var all_filter = new FileFilter ();
            /* Load Game Dialog: Name of filter to show all files */
            all_filter.set_filter_name (_("All files"));
            all_filter.add_pattern ("*");
            open_dialog.add_filter (all_filter);

            open_dialog.modal = true;
            open_dialog.response.connect (open_game_response_cb);
        }

        open_dialog.show ();
    }

    public void open_game_cb ()
        requires (prompt_save_game_cb == null)
    {
        prompt_save_game_cb = open_game_prompt_save_game_cb;
        prompt_save_game (_("Save this game before loading another one?"));
    }

    private void start_new_game ()
    {
        game_file = null;

        disable_window_action (NEW_GAME_ACTION_NAME);
        disable_window_action (SAVE_GAME_AS_ACTION_NAME);

        pgn_game = new PGNGame ();
        var now = new DateTime.now_local ();
        pgn_game.date = now.format ("%Y.%m.%d");
        pgn_game.time = now.format ("%H:%M:%S");
        var duration = settings.get_int ("duration");
        if (duration > 0)
        {
            pgn_game.time_control = duration.to_string ();
            pgn_game.white_time_left = duration.to_string ();
            pgn_game.black_time_left = duration.to_string ();
        }
        var engine_name = settings.get_string ("opponent");
        if (engine_name == "")
        {
            if (ai_profiles != null)
                engine_name = ai_profiles.data.name;
            else
                engine_name = "human";
        }
        var engine_level = settings.get_string ("difficulty");
        if (engine_name != null && engine_name != "human")
        {
            var play_as = settings.get_string ("play-as");

            if (play_as == "alternate")
            {
                var last_side = settings.get_string ("last-played-as");
                play_as = (last_side == "white" ? "black" : "white");
            }

            if (play_as == "white")
            {
                pgn_game.black_ai = engine_name;
                pgn_game.black_level = engine_level;
            }
            else if (play_as == "black")
            {
                pgn_game.white_ai = engine_name;
                pgn_game.white_level = engine_level;
            }
            else
            {
                assert_not_reached ();
            }

            settings.set_string ("last-played-as", play_as);
        }

        start_game ();
    }

    private void load_game (File file)
    {
        enable_window_action (NEW_GAME_ACTION_NAME);

        try
        {
            var pgn = new PGN.from_file (file);
            pgn_game = pgn.games.nth_data (0);
        }
        catch (Error e)
        {
            pgn_game = null;
        }

        if (pgn_game == null)
        {
            run_invalid_pgn_dialog ();
            pgn_game = new PGNGame ();
            game_file = null;
        }
        else
        {
            game_file = file;
            start_game ();
        }
    }

    private void enable_window_action (string name)
    {
        ((SimpleAction) window.lookup_action (name)).set_enabled (true);
    }

    private void disable_window_action (string name)
    {
        ((SimpleAction) window.lookup_action (name)).set_enabled (false);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Chess"));
        Window.set_default_icon_name ("org.gnome.Chess");

        return new ChessApplication ().run (args);
    }
}
