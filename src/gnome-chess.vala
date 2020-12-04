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

    private bool is_tiled;
    private bool is_maximized;
    private int window_width;
    private int window_height;

    private GLib.Settings settings;
    private ApplicationWindow window;
    private InfoBar info_bar;
    private Container view_container;
    private ChessScene scene;
    private ChessView view;
    private Button pause_resume_button;
    private Box navigation_box;
    private Widget first_move_button;
    private Widget prev_move_button;
    private Widget next_move_button;
    private Widget last_move_button;
    private ComboBox history_combo;
    private Widget white_time_label;
    private Widget black_time_label;
    private Widget timer_increment_label;
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
    private FileChooserNative open_dialog = null;
    private FileChooserNative? save_dialog = null;
    private AboutDialog? about_dialog = null;

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
    private int engine_timeout_counter = 10;
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

    private const GLib.ActionEntry[] window_entries =
    {
        { NEW_GAME_ACTION_NAME, new_game_cb },
        { OPEN_GAME_ACTION_NAME, open_game_cb },
        { SAVE_GAME_ACTION_NAME, save_game_cb },
        { SAVE_GAME_AS_ACTION_NAME, save_game_as_cb },
        { UNDO_MOVE_ACTION_NAME, undo_move_cb },
        { RESIGN_ACTION_NAME, resign_cb },
        { PAUSE_RESUME_ACTION_NAME, pause_resume_cb },
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

    private void display_no_engine_info_bar ()
    {
        var label = new Label (_("No chess engine is installed. You will not be able to play against the computer."));
        label.set_line_wrap (true);
        label.show ();

        info_bar.get_content_area ().add (label);
        info_bar.set_message_type (MessageType.ERROR);
        info_bar.set_show_close_button (true);
        info_bar.response.connect (() => info_bar.destroy ());
        info_bar.show ();
    }

    public override void startup ()
    {
        base.startup ();

        settings = new GLib.Settings ("org.gnome.Chess");

        add_action_entries (app_entries, this);
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q", "<Primary>w"});
        Builder builder = new Builder.from_resource ("/org/gnome/Chess/ui/gnome-chess.ui");

        window = (ApplicationWindow) builder.get_object ("gnome_chess_app");
        window.set_default_size (settings.get_int ("width"), settings.get_int ("height"));
        if (settings.get_boolean ("maximized"))
            window.maximize ();
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);

        info_bar = (InfoBar) builder.get_object ("info_bar");
        pause_resume_button = (Button) builder.get_object ("pause_button");
        navigation_box = (Box) builder.get_object ("navigation_box");
        first_move_button = (Widget) builder.get_object ("first_move_button");
        prev_move_button = (Widget) builder.get_object ("prev_move_button");
        next_move_button = (Widget) builder.get_object ("next_move_button");
        last_move_button = (Widget) builder.get_object ("last_move_button");
        history_combo = (ComboBox) builder.get_object ("history_combo");
        white_time_label = (Widget) builder.get_object ("white_time_label");
        black_time_label = (Widget) builder.get_object ("black_time_label");
        view_container = (Container) builder.get_object ("view_container");
        headerbar = (HeaderBar) builder.get_object ("headerbar");
        builder.connect_signals (this);

        update_pause_resume_button ();

        window.add_action_entries (window_entries, this);
        set_accels_for_action ("win." + NEW_GAME_ACTION_NAME,       {        "<Primary>n"       });
        set_accels_for_action ("win." + OPEN_GAME_ACTION_NAME,      {        "<Primary>o"       });
        set_accels_for_action ("win." + SAVE_GAME_ACTION_NAME,      {        "<Primary>s"       });
        set_accels_for_action ("win." + SAVE_GAME_AS_ACTION_NAME,   { "<Shift><Primary>s"       });
        set_accels_for_action ("win." + UNDO_MOVE_ACTION_NAME,      {        "<Primary>z"       });
        set_accels_for_action ("win." + PAUSE_RESUME_ACTION_NAME,   {        "<Primary>p",
                                                                                      "Pause"   });
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
        view_container.add (view);
        view.show ();

        var system_engine_cfg = Path.build_filename (SYSCONFDIR, "gnome-chess", "engines.conf", null);
        var user_engine_cfg = Path.build_filename (Environment.get_user_config_dir (), "gnome-chess", "engines.conf", null);
        if (FileUtils.test (user_engine_cfg, FileTest.EXISTS))
            ai_profiles = AIProfile.load_ai_profiles (user_engine_cfg);
        else if (FileUtils.test (system_engine_cfg, FileTest.EXISTS))
            ai_profiles = AIProfile.load_ai_profiles (system_engine_cfg);
        else
            warning ("engines.conf not found");

        if (ai_profiles == null)
            display_no_engine_info_bar ();

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

        /* Save window state */
        settings.delay ();
        settings.set_int ("width", window_width);
        settings.set_int ("height", window_height);
        settings.set_boolean ("maximized", is_maximized);
        settings.apply ();
    }

    private void set_layout_mode (LayoutMode new_layout_mode)
    {
        if (layout_mode == new_layout_mode)
            return;
        layout_mode = new_layout_mode;

        navigation_box.set_orientation ((layout_mode == LayoutMode.NORMAL) ? Orientation.HORIZONTAL : Orientation.VERTICAL);
    }

    private void size_allocate_cb (Allocation allocation)
    {
        if (is_maximized || is_tiled)
            return;
        window.get_size (out window_width, out window_height);
        if (window_width <= 500 && layout_mode == LayoutMode.NORMAL)
            set_layout_mode (LayoutMode.NARROW);
        else if (window_width > 500 && layout_mode == LayoutMode.NARROW)
            set_layout_mode (LayoutMode.NORMAL);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    public PieceType? show_promotion_type_selector ()
    {
        Builder promotion_type_selector_builder = new Builder.from_resource ("/org/gnome/Chess/ui/promotion-type-selector.ui");

        Dialog promotion_type_selector_dialog = (Dialog) promotion_type_selector_builder.get_object ("dialog_promotion_type_selector");
        promotion_type_selector_dialog.transient_for = window;

        string color;
        if (game.current_player.color == Color.WHITE)
            color = "white";
        else
            color = "black";

        var filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sQueen.svg".printf (color));
        set_piece_image ((Image) promotion_type_selector_builder.get_object ("image_queen"), filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sKnight.svg".printf (color));
        set_piece_image ((Image) promotion_type_selector_builder.get_object ("image_knight"), filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sRook.svg".printf (color));
        set_piece_image ((Image) promotion_type_selector_builder.get_object ("image_rook"), filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sBishop.svg".printf (color));
        set_piece_image ((Image) promotion_type_selector_builder.get_object ("image_bishop"), filename);

        promotion_type_selector_builder.connect_signals (this);

        PieceType? selection = null;
        int choice = promotion_type_selector_dialog.run ();
        switch (choice)
        {
        case PromotionTypeSelected.QUEEN:
            selection = PieceType.QUEEN;
            break;
        case PromotionTypeSelected.KNIGHT:
            selection = PieceType.KNIGHT;
            break;
        case PromotionTypeSelected.ROOK:
            selection = PieceType.ROOK;
            break;
        case PromotionTypeSelected.BISHOP:
            selection = PieceType.BISHOP;
            break;
        }
        promotion_type_selector_dialog.destroy ();

        return selection;
    }

    private void set_piece_image (Image image, string filename)
    {
        int width, height;
        if (!icon_size_lookup (IconSize.DIALOG, out width, out height))
            return;

        try
        {
            var h = new Rsvg.Handle.from_file (filename);

            var s = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
            var c = new Cairo.Context (s);
            var m = Cairo.Matrix.identity ();
            m.scale ((double) width / h.width, (double) height / h.height);
            c.set_matrix (m);
            h.render_cairo (c);

            var p = Gdk.pixbuf_get_from_surface (s, 0, 0, width, height);
            image.set_from_pixbuf (p);
        }
        catch (Error e)
        {
            warning ("Failed to load image %s: %s", filename, e.message);
            return;
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
        window.destroy ();
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

        first_move_button.sensitive = n_moves > 0 && move_number != 0 && !game.is_paused;
        prev_move_button.sensitive = move_number > 0 && !game.is_paused;
        next_move_button.sensitive = move_number < n_moves && !game.is_paused;
        last_move_button.sensitive = n_moves > 0 && move_number != n_moves && !game.is_paused;
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

        if (game_file != null && game_file.get_path () != autosave_filename)
            headerbar.set_subtitle (game_file.get_basename ());
        else
            headerbar.set_subtitle (null);

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
        update_headerbar_title ();

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();

        starting = false;

        if (white_engine != null && game.current_player.color == Color.WHITE ||
            black_engine != null && game.current_player.color == Color.BLACK)
        {
            assert (opponent_engine != null);
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
                    do_engine_move (move);
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

    private void check_engine_timeout ()
        requires (engine_timeout_counter >= 0)
        ensures (engine_timeout_counter >= 0)
    {
        if (opponent_engine == null)
            return;

        if (pgn_game.white_ai != null && game.current_player.color == Color.WHITE ||
            pgn_game.black_ai != null && game.current_player.color == Color.BLACK)
        {
            engine_timeout_counter -= 1;

            if (engine_timeout_counter == 0)
            {
                // Chess engine did not move for a long time
                // End the game assuming a buggy engine
                engine_error_cb (opponent_engine);
            }
        }
        else
        {
            // Reset the engine timeout
            engine_timeout_counter = 10;
        }
    }

    private void game_clock_tick_cb (ChessClock clock)
    {
        check_engine_timeout ();
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
            if (move.en_passant)
            {
                if (move.r0 < move.r1)
                    move_text = _("White pawn captures black pawn en passant");
                else
                    move_text = _("Black pawn captures white pawn en passant");
            }
            else if (move.castling_rook != null)
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
                move_text = _(human_descriptions[index]).printf (start, end);
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
        update_headerbar_title ();

        view.queue_draw ();

        /* Remaining work goes in a timeout to give the game widget a chance to
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
        update_headerbar_title ();
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

    private void update_headerbar_title ()
    {
        if (human_player != null &&
            human_player.color == game.current_player.color &&
            game.current_state.is_in_check (game.current_player))
        {
            if (game.current_player.color == Color.WHITE)
                /* Window title on a White human's turn if he is in check */
                headerbar.set_title (_("White is in Check"));
            else
                /* Window title on a Black human's turn if he is in check */
                headerbar.set_title (_("Black is in Check"));
        }
        else if (game.current_state.last_move != null &&
                 game.current_state.last_move.en_passant)
        {
            if (game.current_player.color == Color.WHITE)
                headerbar.set_title (_("Black performed an en passant capture"));
            else
                headerbar.set_title (_("White performed an en passant capture"));
        }
        else if (game.current_player.color == Color.WHITE)
        {
            if (human_player == null || human_player.color == Color.WHITE)
                /* Window title on White's turn if White is human */
                headerbar.set_title (_("White to Move"));
            else
                /* Window title on White's turn if White is a computer */
                headerbar.set_title (_("White is Thinking…"));
        }
        else
        {
            if (human_player == null || human_player.color == Color.BLACK)
                /* Window title on Black's turn if Black is human */
                headerbar.set_title (_("Black to Move"));
            else
                /* Window title on Black's turn if Black is a computer */
                headerbar.set_title (_("Black is Thinking…"));
        }
        headerbar.set_subtitle (null);
    }

    private void update_pause_resume_button ()
    {
        if (game != null && game.clock == null)
            pause_resume_button.hide ();
        else
            pause_resume_button.show ();

        if (game != null && game.is_paused)
        {
            pause_resume_button.image = new Image.from_icon_name ("media-playback-start-symbolic",
                                                                  IconSize.BUTTON);
            pause_resume_button.tooltip_text = _("Unpause the game");
        }
        else
        {
            pause_resume_button.image = new Image.from_icon_name ("media-playback-pause-symbolic",
                                                                  IconSize.BUTTON);
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

        string title = "";
        switch (game.result)
        {
        case ChessResult.WHITE_WON:
            /* Window title when the white player wins */
            title = _("White Wins");
            pgn_game.result = PGNGame.RESULT_WHITE;
            break;
        case ChessResult.BLACK_WON:
            /* Window title when the black player wins */
            title = _("Black Wins");
            pgn_game.result = PGNGame.RESULT_BLACK;
            break;
        case ChessResult.DRAW:
            /* Window title when the game is drawn */
            title = _("Game is Drawn");
            pgn_game.result = PGNGame.RESULT_DRAW;
            break;
        case ChessResult.BUG:
            /*
             * Window title when something goes wrong with the engine...
             * or when the engine says something is wrong with us! Translators,
             * please test to make sure this does not get ellipsized -- you don't
             * have much room. Set your opponent to GNU Chess, set a time limit
             * because the pause button eats up some of your space, start a new game,
             * then run 'killall gnuchess' in a terminal.
             */
            title = _("Oops! Something has gone wrong.");
            /* don't set the pgn_game result; these are standards */
            break;
        default:
            break;
        }

        string reason = "";
        switch (game.rule)
        {
        case ChessRule.CHECKMATE:
            if (game.result == ChessResult.WHITE_WON)
                /* Window subtitle when Black is checkmated */
                reason = _("Black is in check and cannot move.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Window subtitle when White is checkmated */
                reason = _("White is in check and cannot move.");
            else
                assert_not_reached ();
            break;
        case ChessRule.STALEMATE:
            /* Window subtitle when the game terminates due to a stalemate */
            reason = _("Opponent cannot move.");
            break;
        case ChessRule.FIFTY_MOVES:
            /* Window subtitle when the game is drawn due to the fifty move rule */
            reason = _("No piece was taken or pawn moved in fifty moves.");
            break;
        case ChessRule.SEVENTY_FIVE_MOVES:
            /* Window subtitle when the game is drawn due to the 75 move rule */
            reason = _("No piece was taken or pawn moved in 75 moves.");
            break;
        case ChessRule.TIMEOUT:
            if (game.result == ChessResult.WHITE_WON)
                /* Window subtitle when the game ends due to Black's clock stopping */
                reason = _("Black has run out of time.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Window subtitle when the game ends due to White's clock stopping */
                reason = _("White has run out of time.");
            else
                assert_not_reached ();
            break;
        case ChessRule.THREE_FOLD_REPETITION:
            /* Window subtitle when the game is drawn due to the three-fold-repetition rule */
            reason = _("The same board state has occurred three times.");
            break;
        case ChessRule.FIVE_FOLD_REPETITION:
            /* Window subtitle when the game is drawn due to the five-fold-repetition rule */
            reason = _("The same board state has occurred five times.");
            break;
        case ChessRule.INSUFFICIENT_MATERIAL:
            /* Window subtitle when the game is drawn due to the insufficient material rule */
            reason = _("Neither player can checkmate.");
            break;
        case ChessRule.RESIGN:
            if (game.result == ChessResult.WHITE_WON)
                /* Window subtitle when the game ends due to the black player resigning */
                reason = _("Black has resigned.");
            else if (game.result == ChessResult.BLACK_WON)
                /* Window subtitle when the game ends due to the white player resigning */
                reason = _("White has resigned.");
            else
                assert_not_reached ();
            break;
        case ChessRule.ABANDONMENT:
            /* Window subtitle when a game is abandoned */
            reason = _("The game has been abandoned.");
            pgn_game.termination = PGNGame.TERMINATE_ABANDONED;
            break;
        case ChessRule.DEATH:
            /* Window subtitle when the game ends due to a player dying.
             * This is a PGN standard. GNOME Chess will never kill the user. */
            reason = _("The game log says a player died!");
            pgn_game.termination = PGNGame.TERMINATE_DEATH;
            break;
        case ChessRule.BUG:
            /* Window subtitle when something goes wrong with the engine...
             * or when the engine says something is wrong with us! */
            reason = _("The computer player is confused. The game cannot continue.");
            /* Don't set pgn_game termination; these are standards*/
            break;
        case ChessRule.UNKNOWN:
            /* Window subtitle when we don't know the reason
             * Set it to the pgn_file_name
             * We are using this when loading completed saved games */
             reason = game_file.get_basename ();
             break;
        }

        headerbar.set_title (title);
        headerbar.set_subtitle (reason);

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    [CCode (cname = "gnome_chess_app_delete_event_cb", instance_pos = -1)]
    public bool gnome_chess_app_delete_event_cb (Widget widget, Gdk.Event event)
    {
        quit_game ();
        return false;
    }

    private bool prompt_save_game (string prompt_text)
    {
        if (!game_needs_saving)
            return true;

        var dialog = new MessageDialog (window,
                                        DialogFlags.MODAL,
                                        MessageType.QUESTION,
                                        ButtonsType.NONE,
                                        prompt_text);
        dialog.add_button (_("_Cancel"), ResponseType.CANCEL);

        if (game.result == ChessResult.IN_PROGRESS)
        {
            dialog.add_button (_("_Abandon game"), ResponseType.NO);
            dialog.add_button (_("_Save game for later"), ResponseType.YES);
        }
        else
        {
            dialog.add_button (_("_Discard game"), ResponseType.NO);
            dialog.add_button (_("_Save game log"), ResponseType.YES);
        }

        var result = dialog.run ();
        dialog.destroy ();

        if (result == ResponseType.CANCEL || result == ResponseType.DELETE_EVENT)
        {
            return false;
        }
        else if (result == ResponseType.YES)
        {
            present_save_dialog ();
        }
        else
        {
            warn_if_fail (result == ResponseType.NO);
            /* Remove completed game from history */
            game_needs_saving = false;
            autosave ();
        }

        return true;
    }

    private void present_claim_draw_dialog ()
        requires (game.can_claim_draw ())
    {
        game.pause (false);

        var dialog = new MessageDialog (window,
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

        dialog.secondary_text = reason;

        dialog.add_buttons (/* Option in claim draw dialog */
                            _("_Keep Playing"), ResponseType.REJECT,
                            /* Option in claim draw dialog */
                            _("_Claim Draw"), ResponseType.ACCEPT,
                            null);

        var response = dialog.run ();
        dialog.destroy ();
        game.unpause ();

        if (response == ResponseType.ACCEPT)
        {
            game.current_player.claim_draw ();
        }
    }

    public void new_game_cb ()
    {
        if (prompt_save_game (_("Save this game before starting a new one?")))
            start_new_game ();
    }

    public void resign_cb ()
    {
        game.pause (false);

        var dialog = new MessageDialog (window,
                                        DialogFlags.MODAL,
                                        MessageType.QUESTION,
                                        ButtonsType.NONE,
                                        /* Title of warning dialog when player clicks Resign */
                                        _("Are you sure you want to resign?"));
        dialog.format_secondary_text (
            /* Text on warning dialog when player clicks Resign */
            _("This makes sense if you plan to save the game as a record of your loss."));
        dialog.add_buttons (/* Option on warning dialog when player clicks resign */
                            _("_Keep Playing"), ResponseType.REJECT,
                            /* Option on warning dialog when player clicks resign */
                            _("_Resign"), ResponseType.ACCEPT,
                            null);

        var response = dialog.run ();
        dialog.destroy ();
        game.unpause ();

        if (response == ResponseType.ACCEPT)
        {
            if (human_player != null)
                human_player.resign ();
            else
                game.current_player.resign ();
        }
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

    [CCode (cname = "white_time_draw_cb", instance_pos = -1)]
    public bool white_time_draw_cb (Widget widget, Cairo.Context c)
    {
        double fg[3] = { 0.0, 0.0, 0.0 };
        double bg[3] = { 1.0, 1.0, 1.0 };

        draw_time (widget, c, make_clock_text (game.clock, Color.WHITE), fg, bg);
        return false;
    }

    [CCode (cname = "black_time_draw_cb", instance_pos = -1)]
    public bool black_time_draw_cb (Widget widget, Cairo.Context c)
    {
        double fg[3] = { 1.0, 1.0, 1.0 };
        double bg[3] = { 0.0, 0.0, 0.0 };

        draw_time (widget, c, make_clock_text (game.clock, Color.BLACK), fg, bg);
        return false;
    }

    private string make_clock_text (ChessClock? clock, Color color)
    {
        if (clock == null)
            return "∞";

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

    /*
     * Compute the largest possible size the timer label might ever want to take.
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

    private void draw_time (Widget widget, Cairo.Context c, string text, double[] fg, double[] bg)
    {
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

        int width;
        widget.get_size_request (out width, null);
        if (width == -1)
            widget.set_size_request (compute_time_label_width_request (c), -1);
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

    [CCode (cname = "history_latest_clicked_cb", instance_pos = -1)]
    public void history_latest_clicked_cb (Widget widget)
    {
        scene.move_number = -1;
    }

    [CCode (cname = "history_next_clicked_cb", instance_pos = -1)]
    public void history_next_clicked_cb (Widget widget)
    {
        if (scene.move_number == -1)
            return;

        int move_number = scene.move_number + 1;
        if (move_number >= game.n_moves)
            scene.move_number = -1;
        else
            scene.move_number = move_number;
    }

    [CCode (cname = "history_previous_clicked_cb", instance_pos = -1)]
    public void history_previous_clicked_cb (Widget widget)
    {
        if (scene.move_number == 0)
            return;

        if (scene.move_number == -1)
            scene.move_number = (int) game.n_moves - 1;
        else
            scene.move_number = scene.move_number - 1;
    }

    [CCode (cname = "history_start_clicked_cb", instance_pos = -1)]
    public void history_start_clicked_cb (Widget widget)
    {
        scene.move_number = 0;
    }

    public void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.run ();
            return;
        }

        Builder preferences_builder = new Builder.from_resource ("/org/gnome/Chess/ui/preferences.ui");

        preferences_dialog = (Dialog) preferences_builder.get_object ("preferences");
        preferences_dialog.transient_for = window;

        settings.bind ("show-numbering", preferences_builder.get_object ("show_numbering_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-move-hints", preferences_builder.get_object ("show_move_hints_check"),
                       "active", SettingsBindFlags.DEFAULT);

        side_combo = (ComboBox) preferences_builder.get_object ("side_combo");
        side_combo.set_active (settings.get_enum ("play-as"));

        var ai_combo = (ComboBox) preferences_builder.get_object ("opponent_combo");
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

        difficulty_combo = (ComboBox) preferences_builder.get_object ("difficulty_combo");
        set_combo (difficulty_combo, 1, settings.get_string ("difficulty"));

        duration_combo = (ComboBox) preferences_builder.get_object ("duration_combo");
        clock_type_combo = (ComboBox) preferences_builder.get_object ("clock_type_combo");
        duration_adjustment = (Adjustment) preferences_builder.get_object ("duration_adjustment");
        timer_increment_adjustment = (Adjustment) preferences_builder.get_object ("timer_increment_adjustment");
        custom_duration_box = (Box) preferences_builder.get_object ("custom_duration_box");
        timer_increment_box = (Box) preferences_builder.get_object ("timer_increment_box");
        custom_duration_units_combo = (ComboBox) preferences_builder.get_object ("custom_duration_units_combo");
        set_duration (settings.get_int ("duration"));
        timer_increment_label = (Widget) preferences_builder.get_object ("timer_increment_label");
        timer_increment_units_combo = (ComboBox) preferences_builder.get_object ("timer_increment_units_combo");

        if (pgn_game.clock_type != null)
            set_clock_type (ClockType.string_to_enum (pgn_game.clock_type));
        else
            set_clock_type ((int) ClockType.string_to_enum (settings.get_string ("clock-type")));

        if (pgn_game.timer_increment != null)
            set_timer_increment (int.parse (pgn_game.timer_increment));
        else
            set_timer_increment (settings.get_int ("timer-increment"));

        var orientation_combo = (ComboBox) preferences_builder.get_object ("orientation_combo");
        set_combo (orientation_combo, 1, settings.get_string ("board-side"));

        var move_combo = (ComboBox) preferences_builder.get_object ("move_format_combo");
        set_combo (move_combo, 1, settings.get_string ("move-format"));

        var theme_combo = (ComboBox) preferences_builder.get_object ("piece_style_combo");
        set_combo (theme_combo, 1, settings.get_string ("piece-theme"));

        preferences_builder.connect_signals (this);

        /* Human vs. human */
        if (ai_combo.get_active () == 0)
        {
            side_combo.sensitive = false;
            difficulty_combo.sensitive = false;
        }

        preferences_dialog.run ();
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

    [CCode (cname = "preferences_response_cb", instance_pos = -1)]
    public void preferences_response_cb (Widget widget, int response_id)
    {
        preferences_dialog.hide ();
    }

    [CCode (cname = "preferences_delete_event_cb", instance_pos = -1)]
    public bool preferences_delete_event_cb (Widget widget, Gdk.Event event)
    {
        preferences_response_cb (widget, ResponseType.CANCEL);
        return true;
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
        try
        {
            show_uri_on_window (window, "help:gnome-chess", get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Unable to open help: %s", e.message);
        }
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>", null };
    private const string[] artists = { "Max Froumentin", "Jakub Steiner", null };

    public void about_cb ()
    {
        if (about_dialog != null)
        {
            about_dialog.present ();
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
        about_dialog.response.connect (about_response_cb);
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

        invalid_pgn_dialog.run ();
        invalid_pgn_dialog.destroy ();
    }

    private void run_invalid_move_dialog (string error_message)
    {
        var invalid_move_dialog = new MessageDialog (window,
                                                     DialogFlags.MODAL,
                                                     MessageType.ERROR,
                                                     ButtonsType.NONE,
                                                     error_message);
        invalid_move_dialog.add_button (_("_OK"), ResponseType.OK);

        invalid_move_dialog.run ();
        invalid_move_dialog.destroy ();
    }

    private void about_response_cb (int response_id)
    {
        about_dialog.destroy ();
        about_dialog = null;
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

            if (game_file != null && game_file.get_path () != autosave_filename)
                save_dialog.set_filename (game_file.get_path ());
            else
                save_dialog.set_current_name (/* Default filename for the save game dialog */
                                              _("Untitled Chess Game") + ".pgn");

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
        }

        var response_id = save_dialog.run ();
        if (response_id == ResponseType.ACCEPT)
        {
            update_pgn_time_remaining ();

            try
            {
                game_file = save_dialog.get_file ();
                save_dialog.destroy ();
                save_dialog = null;

                pgn_game.write (game_file);
                headerbar.set_subtitle (game_file.get_basename ());
                disable_window_action (SAVE_GAME_ACTION_NAME);
                game_needs_saving = false;
            }
            catch (Error e)
            {
                var error_dialog = new MessageDialog (window,
                                                      DialogFlags.MODAL,
                                                      MessageType.ERROR,
                                                      ButtonsType.NONE,
                                                      _("Failed to save game: %s"),
                                                      e.message);
                error_dialog.add_button (_("_OK"), ResponseType.OK);

                error_dialog.run ();
                error_dialog.destroy ();
            }
        }
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

    public void open_game_cb ()
    {
        if (!prompt_save_game (_("Save this game before loading another one?")))
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
        }

        var response_id = open_dialog.run ();
        if (response_id == ResponseType.ACCEPT)
        {
            game_file = open_dialog.get_file ();
            open_dialog.destroy ();
            open_dialog = null;

            load_game (game_file);
        }
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
