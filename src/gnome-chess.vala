/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2014 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Application : Gtk.Application
{
    private Settings settings;
    private Gtk.Builder builder;
    private Gtk.Builder preferences_builder;
    private Gtk.ApplicationWindow window;
    private Gtk.Container view_container;
    private ChessScene scene;
    private ChessView view;
    private Gtk.Button pause_resume_button;
    private Gtk.Widget first_move_button;
    private Gtk.Widget prev_move_button;
    private Gtk.Widget next_move_button;
    private Gtk.Widget last_move_button;
    private Gtk.ComboBox history_combo;
    private Gtk.Widget white_time_label;
    private Gtk.Widget black_time_label;
    private Gtk.HeaderBar headerbar;

    private Gtk.Dialog? preferences_dialog = null;
    private Gtk.ComboBox side_combo;
    private Gtk.ComboBox difficulty_combo;
    private Gtk.ComboBox duration_combo;
    private Gtk.Adjustment duration_adjustment;
    private Gtk.Container custom_duration_box;
    private Gtk.ComboBox custom_duration_units_combo;
    private uint save_duration_timeout = 0;
    private Gtk.FileChooserDialog? open_dialog = null;
    private Gtk.InfoBar? open_dialog_info_bar = null;
    private Gtk.Label? open_dialog_error_label = null;
    private Gtk.FileChooserDialog? save_dialog = null;
    private Gtk.InfoBar? save_dialog_info_bar = null;
    private Gtk.Label? save_dialog_error_label = null;
    private Gtk.AboutDialog? about_dialog = null;

    private PGNGame pgn_game;
    private ChessGame game;
    private string autosave_filename;
    private File game_file;
    private bool game_needs_saving = false;
    private bool allow_claim_draw_dialog = true;
    private List<AIProfile> ai_profiles;
    private ChessPlayer? opponent = null;
    private ChessPlayer? human_player = null;
    private ChessEngine? opponent_engine = null;

    private const ActionEntry[] app_entries =
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

    private const ActionEntry[] window_entries =
    {
        { NEW_GAME_ACTION_NAME, new_game_cb },
        { OPEN_GAME_ACTION_NAME, open_game_cb },
        { SAVE_GAME_ACTION_NAME, save_game_cb },
        { SAVE_GAME_AS_ACTION_NAME, save_game_as_cb },
        { UNDO_MOVE_ACTION_NAME, undo_move_cb },
        { RESIGN_ACTION_NAME, resign_cb },
        { PAUSE_RESUME_ACTION_NAME, pause_resume_cb },
    };

    public Application (File? game_file)
    {
        Object (application_id: "org.gnome.gnome-chess", flags: ApplicationFlags.FLAGS_NONE);
        this.game_file = game_file;
    }

    public override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Chess"));
        Gtk.Window.set_default_icon_name ("gnome-chess");

        settings = new Settings ("org.gnome.gnome-chess");

        var data_dir = File.new_for_path (Path.build_filename (Environment.get_user_data_dir (), "gnome-chess", null));
        DirUtils.create_with_parents (data_dir.get_path (), 0755);

        add_action_entries (app_entries, this);

        builder = new Gtk.Builder ();

        try
        {
            builder.add_from_file (Path.build_filename (PKGDATADIR, "menu.ui", null));
        }
        catch (Error e)
        {
            error ("Error loading menu UI: %s", e.message);
        }

        var app_menu = (Menu) builder.get_object ("appmenu");
        set_app_menu (app_menu);

        try
        {
            builder.add_from_file (Path.build_filename (PKGDATADIR, "gnome-chess.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load UI: %s", e.message);
        }
        window = (Gtk.ApplicationWindow) builder.get_object ("gnome_chess_app");
        pause_resume_button = (Gtk.Button) builder.get_object ("pause_button");
        first_move_button = (Gtk.Widget) builder.get_object ("first_move_button");
        prev_move_button = (Gtk.Widget) builder.get_object ("prev_move_button");
        next_move_button = (Gtk.Widget) builder.get_object ("next_move_button");
        last_move_button = (Gtk.Widget) builder.get_object ("last_move_button");
        history_combo = (Gtk.ComboBox) builder.get_object ("history_combo");
        white_time_label = (Gtk.Widget) builder.get_object ("white_time_label");
        black_time_label = (Gtk.Widget) builder.get_object ("black_time_label");
        view_container = (Gtk.Container) builder.get_object ("view_container");
        headerbar = (Gtk.HeaderBar) builder.get_object ("headerbar");
        builder.connect_signals (this);

        update_pause_resume_button ();

        window.add_action_entries (window_entries, this);

        add_window (window);

        scene = new ChessScene ();
        scene.is_human.connect ((p) => { return p == human_player; } );
        scene.changed.connect (scene_changed_cb);
        scene.choose_promotion_type.connect (show_promotion_type_selector);
        settings.bind ("show-move-hints", scene, "show-move-hints", SettingsBindFlags.GET);
        settings.bind ("show-numbering", scene, "show-numbering", SettingsBindFlags.GET);
        settings.bind ("piece-theme", scene, "theme-name", SettingsBindFlags.GET);
        settings.bind ("show-3d-smooth", scene, "show-3d-smooth", SettingsBindFlags.GET);
        settings.bind ("move-format", scene, "move-format", SettingsBindFlags.GET);
        settings.bind ("board-side", scene, "board-side", SettingsBindFlags.GET);

        settings.changed.connect (settings_changed_cb);
        settings_changed_cb (settings, "show-3d");

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

        autosave_filename = data_dir.get_path () + "/autosave.pgn";

        /* Load from history if no game requested */
        if (game_file == null)
        {
            if (FileUtils.test (autosave_filename, FileTest.EXISTS))
                game_file = File.new_for_path (autosave_filename);

            if (game_file == null)
                start_new_game ();
        }

        if (game_file != null)
        {
            try
            {
                load_game (game_file);
            }
            catch (Error e)
            {
                stderr.printf ("Failed to load %s: %s\n", game_file.get_path (), e.message);
                quit ();
            }
        }

        window.set_default_size (settings.get_int ("width"), settings.get_int ("height"));        

        if (settings.get_boolean ("maximized"))
        {
            window.maximize ();
        }

        add_accelerators ();
        show ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();
        if (opponent_engine != null)
            opponent_engine.stop ();
    }

    public PieceType show_promotion_type_selector ()
    {
        Gtk.Builder promotion_type_selector_builder;

        promotion_type_selector_builder = new Gtk.Builder ();
        try
        {
            promotion_type_selector_builder.add_from_file (Path.build_filename (PKGDATADIR, "promotion-type-selector.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load promotion type selector UI: %s", e.message);
        }

        Gtk.Dialog promotion_type_selector_dialog = promotion_type_selector_builder.get_object ("dialog_promotion_type_selector") as Gtk.Dialog;

        string color;
        if (game.current_player.color == Color.WHITE)
            color = "white";
        else
            color = "black";

        var filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sQueen.svg".printf (color));
        set_piece_image (promotion_type_selector_builder.get_object ("image_queen") as Gtk.Image, filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sKnight.svg".printf (color));
        set_piece_image (promotion_type_selector_builder.get_object ("image_knight") as Gtk.Image, filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sRook.svg".printf (color));
        set_piece_image (promotion_type_selector_builder.get_object ("image_rook") as Gtk.Image, filename);

        filename = Path.build_filename (PKGDATADIR, "pieces", scene.theme_name, "%sBishop.svg".printf (color));
        set_piece_image (promotion_type_selector_builder.get_object ("image_bishop") as Gtk.Image, filename);

        promotion_type_selector_builder.connect_signals (this);

        PieceType selection;
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
            default:
                selection = PieceType.QUEEN;
                break;
        }
        promotion_type_selector_dialog.destroy ();

        return selection;
    }

    private void set_piece_image (Gtk.Image image, string filename)
    {
        int width, height;
        if (!Gtk.icon_size_lookup (Gtk.IconSize.DIALOG, out width, out height))
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

    private void settings_changed_cb (Settings settings, string key)
    {
        if (key == "show-3d")
        {
            if (view != null)
            {
                view_container.remove (view);
                view.destroy ();
            }
            if (settings.get_boolean ("show-3d"))
                view = new ChessView3D ();
            else
                view = new ChessView2D ();
            view.set_size_request (300, 300);
            view.scene = scene;
            view_container.add (view);
            view.show ();
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
                Gtk.TreeIter iter;
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
        if (game_file != null && game_file.get_path () != autosave_filename)
            headerbar.set_subtitle (game_file.get_basename ());
        else
            headerbar.set_subtitle (null);

        var model = (Gtk.ListStore) history_combo.model;
        model.clear ();
        Gtk.TreeIter iter;
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
        game = new ChessGame (fen, moves);

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

                if (white_seconds > 0 && black_seconds > 0)
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
            opponent_engine.stopped.disconnect (engine_stopped_cb);
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
            opponent_engine.stopped.connect (engine_stopped_cb);
            opponent_engine.error.connect (engine_error_cb);
            opponent_engine.claim_draw.connect (engine_claim_draw_cb);
            opponent_engine.offer_draw.connect (engine_offer_draw_cb);

            if (!opponent_engine.start ())
            {
                disable_window_action (SAVE_GAME_ACTION_NAME);
                game.result = ChessResult.BUG;
                game.rule = ChessRule.DEATH;
                game_end_cb (game);
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

        if (game.result != ChessResult.IN_PROGRESS)
            game_end_cb (game);

        update_history_panel ();
        update_action_status ();
        update_pause_resume_button ();
        update_headerbar_title ();

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
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

    public override void activate ()
    {
        base.activate ();
        window.show ();
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
            game.stop (ChessResult.BUG, ChessRule.BUG);
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
                    /* Keep waiting */
                    return true;
                }
                else
                {
                    do_engine_move (move);
                    /* Disconnect from main loop */
                    return false;
                }
            });
        }
    }

    private void engine_resigned_cb (ChessEngine engine)
    {
        opponent.resign ();
    }

    private void engine_stopped_cb (ChessEngine engine)
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
            if (game == original_game)
                game.stop (ChessResult.BUG, ChessRule.DEATH);
            /* Disconnect from the main loop */
            return false;
        });
    }

    private void engine_error_cb (ChessEngine engine)
    {
        game.stop (ChessResult.BUG, ChessRule.BUG);
    }

    private void engine_claim_draw_cb (ChessEngine engine)
    {
        if (!game.can_claim_draw ())
            game.stop (ChessResult.BUG, ChessRule.BUG);
    }

    private void engine_offer_draw_cb (ChessEngine engine)
    {
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
        if (game.clock != null)
            enable_window_action (PAUSE_RESUME_ACTION_NAME);
        
        if (game.is_started)
        {
            if (opponent_engine != null && player == opponent)
                opponent_engine.move ();
            else if (game.can_claim_draw () && allow_claim_draw_dialog)
                present_claim_draw_dialog ();
        }
    }

    private void set_move_text (Gtk.TreeIter iter, ChessMove move)
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
            if (move.moved_rook == null)
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
            else if (move.f0 < move.f1 && move.r0 == 0)
            {
                move_text = _("White castles kingside");
            }
            else if (move.f1 < move.f0 && move.r0 == 0)
            {
                move_text = _("White castles queenside");
            }
            else if (move.f0 < move.f1 && move.r0 == 7)
            {
                move_text = _("Black castles kingside");
            }
            else if (move.f1 < move.f0 && move.r0 == 7)
            {
                move_text = _("Black castles queenside");
            }
            else assert_not_reached ();
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
        enable_window_action (NEW_GAME_ACTION_NAME);

        /* Need to save after each move */
        game_needs_saving = true;

        /* If the only mover is the AI, then don't bother saving */
        if (move.number == 1 && opponent != null && opponent.color == Color.WHITE)
            game_needs_saving = false;

        if (move.number > pgn_game.moves.length ())
            pgn_game.moves.append (move.get_san ());

        var model = (Gtk.ListStore) history_combo.model;
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 1, move.number, -1);        
        set_move_text (iter, move);

        /* Follow the latest move */
        if (move.number == game.n_moves && scene.move_number == -1)
            history_combo.set_active_iter (iter);

        enable_window_action (SAVE_GAME_ACTION_NAME);
        enable_window_action (SAVE_GAME_AS_ACTION_NAME);
        update_history_panel ();
        update_action_status ();
        update_headerbar_title ();

        if (opponent_engine != null)
            opponent_engine.report_move (move);
        view.queue_draw ();
    }

    private void game_undo_cb (ChessGame game)
    {
        /* Notify AI */
        if (opponent_engine != null)
            opponent_engine.undo ();

        /* Remove from the PGN game */
        pgn_game.moves.remove_link (pgn_game.moves.last ());

        /* Remove from the history */
        var model = (Gtk.ListStore) history_combo.model;
        Gtk.TreeIter iter;
        model.iter_nth_child (out iter, null, model.iter_n_children (null) - 1);
        model.remove (iter);

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
        if ((human_player == null ||
             human_player.color == game.current_player.color) &&
            game.current_state.is_in_check (game.current_player))
        {
            if (game.current_player.color == Color.WHITE)
                /* Window title on a White human's turn if he is in check */
                headerbar.set_title (_("White is in Check"));
            else
                /* Window title on a Black human's turn if he is in check */
                headerbar.set_title (_("Black is in Check"));
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
    }

    private void add_accelerators ()
    {
        add_accelerator ("<Primary>N", "win." + NEW_GAME_ACTION_NAME, null);
        add_accelerator ("<Primary>O", "win." + OPEN_GAME_ACTION_NAME, null);
        add_accelerator ("<Primary>S", "win." + SAVE_GAME_ACTION_NAME, null);
        add_accelerator ("<Shift><Primary>S", "win." + SAVE_GAME_AS_ACTION_NAME, null);
        add_accelerator ("<Primary>Z", "win." + UNDO_MOVE_ACTION_NAME, null);
        add_accelerator ("Pause", "win." + PAUSE_RESUME_ACTION_NAME, null);
    }

    private void update_pause_resume_button ()
    {
        if (game != null && game.clock == null)
            pause_resume_button.hide ();
        else
            pause_resume_button.show ();

        if (game != null && game.is_paused)
        {
            pause_resume_button.image = new Gtk.Image.from_icon_name ("media-playback-start-symbolic",
                                                                      Gtk.IconSize.BUTTON);
            pause_resume_button.tooltip_text = _("Unpause the game");
        }
        else
        {
            pause_resume_button.image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic",
                                                                      Gtk.IconSize.BUTTON);
            pause_resume_button.tooltip_text = _("Pause the game");
        }
    }

    private void game_end_cb (ChessGame game)
    {
        disable_window_action (RESIGN_ACTION_NAME);
        disable_window_action (UNDO_MOVE_ACTION_NAME);
        disable_window_action (PAUSE_RESUME_ACTION_NAME);

        game_needs_saving = false;

        if (opponent_engine != null)
            opponent_engine.stop ();

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
            if (game.rule == ChessRule.DEATH)
                /* Window title when the chess engine dies unexpectedly */
                title = _("The computer player died unexpectedly.");
            else
                /* Window subtitle when something goes wrong with the engine...
                 * or when the engine says something is wrong with us! */
                title = _("The computer player is very confused.");
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
                reason = _("Black is in check and cannot move (checkmate).");
            else if (game.result == ChessResult.BLACK_WON)
                /* Window subtitle when White is checkmated */
                reason = _("White is in check and cannot move (checkmate).");
            else
                assert_not_reached ();
            break;
        case ChessRule.STALEMATE:
            /* Window subtitle when the game terminates due to a stalemate */
            reason = _("Opponent cannot move (stalemate).");
            break;
        case ChessRule.FIFTY_MOVES:
            /* Window subtitle when the game is drawn due to the fifty move rule */
            reason = _("No piece has been taken or pawn moved in the last fifty moves.");
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
            /* Window subtitle when the game is drawn due to the three-fold-repitition rule */
            reason = _("The same board state has occurred three times (threefold repetition).");
            break;
        case ChessRule.INSUFFICIENT_MATERIAL:
            /* Window subtitle when the game is drawn due to the insufficient material rule */
            reason = _("Neither player can checkmate (insufficient material).");
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
            if (game.result == ChessResult.BUG)
                /* Window subtitle when the chess engine dies unexpectedly. */
                reason = _("The game cannot continue.");
            else
                /* Window subtitle when the game ends due to a player dying.
                 * This is a PGN standard. GNOME Chess will never kill the user. */
                reason = _("One of the players has died.");
            pgn_game.termination = PGNGame.TERMINATE_DEATH;
            break;
        case ChessRule.BUG:
            /* Window subtitle when something goes wrong with the engine...
             * or when the engine says something is wrong with us! */
            reason = _("The game cannot continue.");
            /* Don't set pgn_game termination; these are standards*/
            break;
        }

        headerbar.set_title (title);
        headerbar.set_subtitle (reason);

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    public void show ()
    {
        window.show ();
    }

    [CCode (cname = "G_MODULE_EXPORT gnome_chess_app_delete_event_cb", instance_pos = -1)]
    public bool gnome_chess_app_delete_event_cb (Gtk.Widget widget, Gdk.Event event)
    {
        quit_game ();
        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT gnome_chess_app_configure_event_cb", instance_pos = -1)]
    public bool gnome_chess_app_configure_event_cb (Gtk.Widget widget, Gdk.EventConfigure event)
    {
        if (!settings.get_boolean ("maximized"))
        {
            settings.set_int ("width", event.width);
            settings.set_int ("height", event.height);
        }

        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT gnome_chess_app_window_state_event_cb", instance_pos = -1)]
    public bool gnome_chess_app_window_state_event_cb (Gtk.Widget widget, Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
        {
            var is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
            settings.set_boolean ("maximized", is_maximized);
        }

        return false;
    }

    private bool prompt_save_game (string prompt_text)
    {
        if (!game_needs_saving)
            return true;

        var dialog = new Gtk.MessageDialog (window,
                                            Gtk.DialogFlags.MODAL,
                                            Gtk.MessageType.QUESTION,
                                            Gtk.ButtonsType.NONE,
                                            prompt_text);
        dialog.add_button (_("_Cancel"), Gtk.ResponseType.CANCEL);

        if (game.result == ChessResult.IN_PROGRESS)
        {
            dialog.add_button (_("_Abandon game"), Gtk.ResponseType.NO);
            dialog.add_button (_("_Save game for later"), Gtk.ResponseType.YES);
        }
        else
        {
            dialog.add_button (_("_Discard game"), Gtk.ResponseType.NO);
            dialog.add_button (_("_Save game log"), Gtk.ResponseType.YES);
        }

        var result = dialog.run ();
        dialog.destroy ();

        if (result == Gtk.ResponseType.CANCEL || result == Gtk.ResponseType.DELETE_EVENT)
        {
            return false;
        }
        else if (result == Gtk.ResponseType.YES)
        {
            /* Your very last chance to save */
            present_save_dialog (_("_Discard"), _("_Save"));
        }
        else
        {
            warn_if_fail (result == Gtk.ResponseType.NO);
            /* Remove completed game from history */
            game_needs_saving = false;
            autosave ();
        }

        return true;
    }

    private void present_claim_draw_dialog ()
        requires (game.can_claim_draw ())
    {
        /* Manually since we don't want to show the pause overlay */
        if (game.clock != null)
            game.clock.pause ();

        var dialog = new Gtk.MessageDialog (window,
                                            Gtk.DialogFlags.MODAL,
                                            Gtk.MessageType.QUESTION,
                                            Gtk.ButtonsType.NONE,
                                            /* Title of claim draw dialog */
                                            _("Would you like to claim a draw?"));

        string reason;
        if (game.is_fifty_move_rule_fulfilled ())
        {
            /* Message in claim draw dialog when triggered by fifty-move rule */
            reason = _("Fifty moves have passed without a capture or pawn advancement.");
        }
        else if (game.is_three_fold_repeat ())
        {
            /* Message in claim draw dialog when triggered by three-fold repetition */
            reason = _("The current board position has occurred three times.");
        }
        else assert_not_reached ();

        dialog.format_secondary_text ("%s\n%s", reason,
            /* Displays in claim draw dialog to warn player that the dialog only appears once */
            _("(You will not be offered this choice again.)"));

        dialog.add_buttons (/* Option in claim draw dialog */
                            _("_Keep Playing"), Gtk.ResponseType.REJECT,
                            /* Option in claim draw dialog */
                            _("_Claim Draw"), Gtk.ResponseType.ACCEPT,
                            null);

        var response = dialog.run ();
        dialog.destroy ();

        if (response == Gtk.ResponseType.ACCEPT)
        {
            game.current_player.claim_draw ();
        }
        else
        {
            /* Display this dialog only once per game */
            allow_claim_draw_dialog = false;

            if (game.clock != null)
                game.clock.unpause ();
        }
    }

    public void new_game_cb ()
    {
        if (prompt_save_game (_("Save this game before starting a new one?")))
            start_new_game ();
    }

    public void resign_cb ()
    {
        /* Manually since we don't want to show the pause overlay */
        if (game.clock != null)
            game.clock.pause ();

        var dialog = new Gtk.MessageDialog (window,
                                            Gtk.DialogFlags.MODAL,
                                            Gtk.MessageType.QUESTION,
                                            Gtk.ButtonsType.NONE,
                                            /* Title of warning dialog when player clicks Resign */
                                            _("Are you sure you want to resign?"));
        dialog.format_secondary_text (
            /* Text on warningn dialog when player clicks Resign */
            _("This makes sense if you plan to save the game as a record of your loss."));
        dialog.add_buttons (/* Option on warning dialog when player clicks resign */
                            _("_Keep Playing"), Gtk.ResponseType.REJECT,
                            /* Option on warning dialog when player clicks resign */
                            _("_Resign"), Gtk.ResponseType.ACCEPT,
                            null);

        var response = dialog.run ();
        dialog.destroy ();

        if (response == Gtk.ResponseType.ACCEPT)
        {
            if (human_player != null)
                human_player.resign ();
            else
                game.current_player.resign ();
        }
        else
        {
            if (game.clock != null)
                game.clock.unpause ();
        }
    }

    public void undo_move_cb ()
    {
        if (opponent != null)
            human_player.undo ();
        else
            game.opponent.undo ();

        update_headerbar_title ();
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

    [CCode (cname = "G_MODULE_EXPORT white_time_draw_cb", instance_pos = -1)]
    public bool white_time_draw_cb (Gtk.Widget widget, Cairo.Context c)
    {
        double fg[3] = { 0.0, 0.0, 0.0 };
        double bg[3] = { 1.0, 1.0, 1.0 };

        draw_time (widget, c, make_clock_text (game.clock, Color.WHITE), fg, bg);
        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT black_time_draw_cb", instance_pos = -1)]
    public bool black_time_draw_cb (Gtk.Widget widget, Cairo.Context c)
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
            time = game.clock.white_initial_seconds - game.clock.white_seconds_used;
        else
            time = game.clock.black_initial_seconds - game.clock.black_seconds_used;

        if (time >= 60)
            return "%d∶%02d".printf (time / 60, time % 60);
        else
            return "∶%02d".printf (time);
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

    private void draw_time (Gtk.Widget widget, Cairo.Context c, string text, double[] fg, double[] bg)
    {
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

        int width;
        widget.get_size_request (out width, null);
        if (width == -1)
            widget.set_size_request (compute_time_label_width_request (c), -1);
    }

    [CCode (cname = "G_MODULE_EXPORT history_combo_changed_cb", instance_pos = -1)]
    public void history_combo_changed_cb (Gtk.ComboBox combo)
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

    [CCode (cname = "G_MODULE_EXPORT history_latest_clicked_cb", instance_pos = -1)]
    public void history_latest_clicked_cb (Gtk.Widget widget)
    {
        scene.move_number = -1;
    }

    [CCode (cname = "G_MODULE_EXPORT history_next_clicked_cb", instance_pos = -1)]
    public void history_next_clicked_cb (Gtk.Widget widget)
    {
        if (scene.move_number == -1)
            return;

        int move_number = scene.move_number + 1;
        if (move_number >= game.n_moves)
            scene.move_number = -1;
        else
            scene.move_number = move_number;
    }

    [CCode (cname = "G_MODULE_EXPORT history_previous_clicked_cb", instance_pos = -1)]
    public void history_previous_clicked_cb (Gtk.Widget widget)
    {
        if (scene.move_number == 0)
            return;

        if (scene.move_number == -1)
            scene.move_number = (int) game.n_moves - 1;
        else
            scene.move_number = scene.move_number - 1;
    }

    [CCode (cname = "G_MODULE_EXPORT history_start_clicked_cb", instance_pos = -1)]
    public void history_start_clicked_cb (Gtk.Widget widget)
    {
        scene.move_number = 0;
    }

    public void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        preferences_builder = new Gtk.Builder ();
        try
        {
            preferences_builder.add_from_file (Path.build_filename (PKGDATADIR, "preferences.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load preferences UI: %s", e.message);
        }
        preferences_dialog = (Gtk.Dialog) preferences_builder.get_object ("preferences");
        preferences_dialog.transient_for = window;
        
        settings.bind ("show-numbering", preferences_builder.get_object ("show_numbering_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-move-hints", preferences_builder.get_object ("show_move_hints_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-3d", preferences_builder.get_object ("show_3d_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-3d-smooth", preferences_builder.get_object ("show_3d_smooth_check"),
                       "active", SettingsBindFlags.DEFAULT);

        side_combo = (Gtk.ComboBox) preferences_builder.get_object ("side_combo");
        side_combo.set_active (settings.get_boolean ("play-as-white") ? 0 : 1);

        var ai_combo = (Gtk.ComboBox) preferences_builder.get_object ("opponent_combo");
        var ai_model = (Gtk.ListStore) ai_combo.model;
        var opponent_name = settings.get_string ("opponent");
        if (opponent_name == "human")
            ai_combo.set_active (0);
        foreach (var p in ai_profiles)
        {
            Gtk.TreeIter iter;
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

        difficulty_combo = (Gtk.ComboBox) preferences_builder.get_object ("difficulty_combo");
        set_combo (difficulty_combo, 1, settings.get_string ("difficulty"));

        duration_combo = (Gtk.ComboBox) preferences_builder.get_object ("duration_combo");
        duration_adjustment = (Gtk.Adjustment) preferences_builder.get_object ("duration_adjustment");
        custom_duration_box = (Gtk.Container) preferences_builder.get_object ("custom_duration_box");
        custom_duration_units_combo = (Gtk.ComboBox) preferences_builder.get_object ("custom_duration_units_combo");
        set_duration (settings.get_int ("duration"));

        var orientation_combo = (Gtk.ComboBox) preferences_builder.get_object ("orientation_combo");
        set_combo (orientation_combo, 1, settings.get_string ("board-side"));

        var move_combo = (Gtk.ComboBox) preferences_builder.get_object ("move_format_combo");
        set_combo (move_combo, 1, settings.get_string ("move-format"));

        var show_3d_check = (Gtk.CheckButton) preferences_builder.get_object ("show_3d_check");

        var theme_combo = (Gtk.ComboBox) preferences_builder.get_object ("piece_style_combo");
        set_combo (theme_combo, 1, settings.get_string ("piece-theme"));
        theme_combo.sensitive = !show_3d_check.active;

        var show_3d_smooth_check = (Gtk.CheckButton) preferences_builder.get_object ("show_3d_smooth_check");
        show_3d_smooth_check.sensitive = show_3d_check.active;

        preferences_builder.connect_signals (this);

        /* Human vs. human */
        if (ai_combo.get_active () == 0)
        {
            side_combo.sensitive = false;
            difficulty_combo.sensitive = false;
        }

        preferences_dialog.present ();
    }

    private void set_combo (Gtk.ComboBox combo, int value_index, string value)
    {
        Gtk.TreeIter iter;
        var model = combo.model;
        if (!model.get_iter_first (out iter))
            return;
        do
        {
            string v;
            model.get (iter, value_index, out v, -1);
            if (v == value)
            {
                combo.set_active_iter (iter);
                return;
            }
        } while (model.iter_next (ref iter));
    }

    private string? get_combo (Gtk.ComboBox combo, int value_index)
    {
        string value;
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return null;
        combo.model.get (iter, value_index, out value, -1);
        return value;
    }

    [CCode (cname = "G_MODULE_EXPORT side_combo_changed_cb", instance_pos = -1)]
    public void side_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        bool play_as_white;
        combo.model.get (iter, 1, out play_as_white, -1);
        settings.set_boolean ("play-as-white", play_as_white);
    }

    [CCode (cname = "G_MODULE_EXPORT opponent_combo_changed_cb", instance_pos = -1)]
    public void opponent_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string opponent;
        combo.model.get (iter, 1, out opponent, -1);
        settings.set_string ("opponent", opponent);
        bool vs_human = (combo.get_active () == 0);
        side_combo.sensitive = !vs_human;
        difficulty_combo.sensitive = !vs_human;
    }

    [CCode (cname = "G_MODULE_EXPORT difficulty_combo_changed_cb", instance_pos = -1)]
    public void difficulty_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string difficulty;
        combo.model.get (iter, 1, out difficulty, -1);
        settings.set_string ("difficulty", difficulty);
    }

    private void set_duration (int duration, bool simplify = true)
    {
        var model = custom_duration_units_combo.model;
        Gtk.TreeIter iter, max_iter = {};

        /* Find the largest units that can be used for this value */
        int max_multiplier = 0;
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.get (iter, 1, out multiplier, -1);
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
            model.get (iter, 1, out v, -1);
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
        Gtk.TreeIter iter;
        if (duration_combo.get_active_iter (out iter))
        {
            int duration;
            duration_combo.model.get (iter, 1, out duration, -1);
            if (duration >= 0)
                return duration;
        }
    
        var magnitude = (int) duration_adjustment.value;
        int multiplier = 1;
        if (custom_duration_units_combo.get_active_iter (out iter))
            custom_duration_units_combo.model.get (iter, 1, out multiplier, -1);
        return magnitude * multiplier;
    }

    private bool save_duration_cb ()
    {
        settings.set_int ("duration", get_duration ());
        Source.remove (save_duration_timeout);
        save_duration_timeout = 0;
        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT duration_changed_cb", instance_pos = -1)]
    public void duration_changed_cb (Gtk.Adjustment adjustment)
    {
        var model = (Gtk.ListStore) custom_duration_units_combo.model;
        Gtk.TreeIter iter;
        /* Set the unit labels to the correct plural form */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.get (iter, 1, out multiplier, -1);
                switch (multiplier)
                {
                case 1:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in seconds */
                                                  "second", "seconds", (ulong) adjustment.value), -1);
                    break;
                case 60:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in minutes */
                                                  "minute", "minutes", (ulong) adjustment.value), -1);
                    break;
                case 3600:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in hours */
                                                  "hour", "hours", (ulong) adjustment.value), -1);
                    break;
                }
            } while (model.iter_next (ref iter));
        }

        save_duration ();
    }

    [CCode (cname = "G_MODULE_EXPORT duration_units_changed_cb", instance_pos = -1)]
    public void duration_units_changed_cb (Gtk.Widget widget)
    {
        save_duration ();
    }

    private void save_duration ()
    {
        /* Delay writing the value as it this event will be generated a lot spinning through the value */
        if (save_duration_timeout != 0)
            Source.remove (save_duration_timeout);
        save_duration_timeout = Timeout.add (100, save_duration_cb);
    }

    [CCode (cname = "G_MODULE_EXPORT duration_combo_changed_cb", instance_pos = -1)]
    public void duration_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int duration;
        combo.model.get (iter, 1, out duration, -1);
        custom_duration_box.visible = duration < 0;

        if (duration >= 0)
            set_duration (duration, false);
        /* Default to one hour (30 minutes/player) when setting custom duration */
        else if (get_duration () <= 0)
            set_duration (60 * 60, false);

        save_duration ();
    }

    [CCode (cname = "G_MODULE_EXPORT preferences_response_cb", instance_pos = -1)]
    public void preferences_response_cb (Gtk.Widget widget, int response_id)
    {
        preferences_dialog.hide ();
    }

    [CCode (cname = "G_MODULE_EXPORT preferences_delete_event_cb", instance_pos = -1)]
    public bool preferences_delete_event_cb (Gtk.Widget widget, Gdk.Event event)
    {
        preferences_response_cb (widget, Gtk.ResponseType.CANCEL);
        return true;
    }

    [CCode (cname = "G_MODULE_EXPORT piece_style_combo_changed_cb", instance_pos = -1)]
    public void piece_style_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("piece-theme", get_combo (combo, 1));
    }

    [CCode (cname = "G_MODULE_EXPORT show_3d_toggle_cb", instance_pos = -1)]
    public void show_3d_toggle_cb (Gtk.ToggleButton widget)
    {
        var w = (Gtk.Widget) preferences_builder.get_object ("show_3d_smooth_check");
        w.sensitive = widget.active;

        w = (Gtk.Widget) preferences_builder.get_object ("piece_style_combo");
        w.sensitive = !widget.active;
    }

    [CCode (cname = "G_MODULE_EXPORT move_format_combo_changed_cb", instance_pos = -1)]
    public void move_format_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("move-format", get_combo (combo, 1));
    }

    [CCode (cname = "G_MODULE_EXPORT orientation_combo_changed_cb", instance_pos = -1)]
    public void orientation_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("board-side", get_combo (combo, 1));    
    }

    public void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:gnome-chess", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Unable to open help: %s", e.message);
        }
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>", null };
    private const string[] artists = { "John-Paul Gignac (3D Models)", "Max Froumentin (2D Models)", "Jakub Steiner (icon)", null };

    public void about_cb ()
    {
        if (about_dialog != null)
        {
            about_dialog.present ();
            return;
        }

        about_dialog = new Gtk.AboutDialog ();
        about_dialog.transient_for = window;
        about_dialog.modal = true;
        about_dialog.program_name = _("Chess");
        about_dialog.version = VERSION;
        about_dialog.copyright = "Copyright © 2010–2013 Robert Ancell\nCopyright © 2013–2014 Michael Catanzaro";
        about_dialog.license_type = Gtk.License.GPL_2_0;
        about_dialog.comments = _("The 2D/3D chess game for GNOME\n\nGNOME Chess is a part of GNOME Games.");
        about_dialog.authors = authors;
        about_dialog.artists = artists;
        about_dialog.translator_credits = _("translator-credits");
        about_dialog.website = "https://wiki.gnome.org/Apps/Chess";
        about_dialog.logo_icon_name = "gnome-chess";
        about_dialog.response.connect (about_response_cb);
        about_dialog.show ();
    }
    
    private void about_response_cb (int response_id)
    {
        about_dialog.destroy ();
        about_dialog = null;
    }

    private void add_info_bar_to_dialog (Gtk.Dialog dialog, out Gtk.InfoBar info_bar, out Gtk.Label label)
    {
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.show ();

        info_bar = new Gtk.InfoBar ();
        var content_area = (Gtk.Container) info_bar.get_content_area ();
        vbox.pack_start (info_bar, false, true, 0);

        label = new Gtk.Label ("");
        content_area.add (label);
        label.show ();

        var child = (Gtk.Container) dialog.get_child ();
        child.reparent (vbox);
        child.border_width = dialog.border_width;
        dialog.border_width = 0;

        vbox.set_child_packing (child, true, true, 0, Gtk.PackType.START);
        dialog.add (vbox);
    }

    private void update_pgn_time_remaining ()
    {
        if (game.clock != null)
        {
            /* We currently only support simple timeouts */
            uint initial_time = int.parse (pgn_game.time_control);
            uint white_used = game.clock.white_seconds_used;
            uint black_used = game.clock.black_seconds_used;

            pgn_game.white_time_left = (initial_time - white_used).to_string ();
            pgn_game.black_time_left = (initial_time - black_used).to_string ();
        }
    }

    private void save_dialog_cb (int response_id)
    {
        if (response_id == Gtk.ResponseType.OK)
        {
            update_pgn_time_remaining ();

            try
            {
                game_file = save_dialog.get_file ();
                pgn_game.write (game_file);
                headerbar.set_subtitle (game_file.get_basename ());
                disable_window_action (SAVE_GAME_ACTION_NAME);
                game_needs_saving = false;
            }
            catch (Error e)
            {
                warning ("Failed to save game: %s", e.message);
                save_dialog_error_label.set_text (_("Failed to save game"));
                save_dialog_info_bar.set_message_type (Gtk.MessageType.ERROR);
                save_dialog_info_bar.show ();
                return;
            }
        }

        save_dialog.destroy ();
        save_dialog = null;
        save_dialog_info_bar = null;
        save_dialog_error_label = null;
    }
    
    private void present_save_dialog (string cancel_button_label = N_("_Cancel"),
                                      string save_button_label = N_("_Save"))
    {
        /* Show active dialog */
        if (save_dialog != null)
        {
            save_dialog.run ();
            return;
        }

        save_dialog = new Gtk.FileChooserDialog (/* Title of save game dialog */
                                                 _("Save Chess Game"),
                                                 window, Gtk.FileChooserAction.SAVE,
                                                 _(cancel_button_label), Gtk.ResponseType.CANCEL,
                                                 _(save_button_label), Gtk.ResponseType.OK, null);
        add_info_bar_to_dialog (save_dialog, out save_dialog_info_bar, out save_dialog_error_label);

        save_dialog.file_activated.connect (() => save_dialog_cb (Gtk.ResponseType.OK));
        save_dialog.response.connect (save_dialog_cb);

        if (game_file != null && game_file.get_path () != autosave_filename)
            save_dialog.set_filename (game_file.get_path ());
        else
            save_dialog.set_current_name (/* Default filename for the save game dialog */
                                          _("Untitled Chess Game") + ".pgn");

        /* Filter out non PGN files by default */
        var pgn_filter = new Gtk.FileFilter ();
        /* Save Game Dialog: Name of filter to show only PGN files */
        pgn_filter.set_filter_name (_("PGN files"));
        pgn_filter.add_pattern ("*.pgn");
        save_dialog.add_filter (pgn_filter);

        var all_filter = new Gtk.FileFilter ();
        /* Save Game Dialog: Name of filter to show all files */
        all_filter.set_filter_name (_("All files"));
        all_filter.add_pattern ("*");
        save_dialog.add_filter (all_filter);

        save_dialog.run ();
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
        if (open_dialog != null)
        {
            open_dialog.present ();
            return;
        }

        open_dialog = new Gtk.FileChooserDialog (/* Title of load game dialog */
                                                 _("Load Chess Game"),
                                                 window, Gtk.FileChooserAction.OPEN,
                                                 _("_Cancel"), Gtk.ResponseType.CANCEL,
                                                 _("_Open"), Gtk.ResponseType.OK, null);
        add_info_bar_to_dialog (open_dialog, out open_dialog_info_bar, out open_dialog_error_label);

        open_dialog.file_activated.connect (() => open_dialog_cb (Gtk.ResponseType.OK));
        open_dialog.response.connect (open_dialog_cb);

        /* Filter out non PGN files by default */
        var pgn_filter = new Gtk.FileFilter ();
        /* Load Game Dialog: Name of filter to show only PGN files */
        pgn_filter.set_filter_name (_("PGN files"));
        pgn_filter.add_pattern ("*.pgn");
        open_dialog.add_filter (pgn_filter);

        var all_filter = new Gtk.FileFilter ();
        /* Load Game Dialog: Name of filter to show all files */
        all_filter.set_filter_name (_("All files"));
        all_filter.add_pattern ("*");
        open_dialog.add_filter (all_filter);

        open_dialog.present ();
    }

    private void open_dialog_cb (int response_id)
    {
        if (response_id == Gtk.ResponseType.OK)
        {
            try
            {
                game_file = open_dialog.get_file ();
                load_game (game_file);
            }
            catch (Error e)
            {
                warning ("Failed to open game: %s", e.message);
                open_dialog_error_label.set_text (_("Failed to open game"));
                open_dialog_info_bar.set_message_type (Gtk.MessageType.ERROR);
                open_dialog_info_bar.show ();
                return;
            }
        }

        open_dialog.destroy ();
        open_dialog = null;
        open_dialog_info_bar = null;
        open_dialog_error_label = null;
    }

    private void start_new_game ()
    {
        game_file = null;

        allow_claim_draw_dialog = true;
        disable_window_action (NEW_GAME_ACTION_NAME);
        disable_window_action (SAVE_GAME_AS_ACTION_NAME);

        pgn_game = new PGNGame ();
        var now = new DateTime.now_local ();
        pgn_game.date = now.format ("%Y.%m.%d");
        pgn_game.time = now.format ("%H:%M:%S");
        var duration = settings.get_int ("duration");
        if (duration > 0)
        {
            pgn_game.time_control = (duration / 2).to_string ();
            pgn_game.white_time_left = (duration / 2).to_string ();
            pgn_game.black_time_left = (duration / 2).to_string ();
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
            if (settings.get_boolean ("play-as-white"))
            {
                pgn_game.black_ai = engine_name;
                pgn_game.black_level = engine_level;
            }
            else
            {
                pgn_game.white_ai = engine_name;
                pgn_game.white_level = engine_level;
            }
        }

        start_game ();
    }

    private void load_game (File file) throws Error
    {
        enable_window_action (NEW_GAME_ACTION_NAME);

        var pgn = new PGN.from_file (file);
        pgn_game = pgn.games.nth_data (0);

        game_file = file;
        start_game ();
    }

    private void enable_window_action (string name)
    {
        ((SimpleAction) window.lookup_action (name)).set_enabled (true);
    }

    private void disable_window_action (string name)
    {
        ((SimpleAction) window.lookup_action (name)).set_enabled (false);
    }
}

class GnomeChess
{
    static bool show_version;
    public static const OptionEntry[] options =
    {
        { "version", 'v', 0, OptionArg.NONE, ref show_version,
          /* Help string for command line --version flag */
          N_("Show release version"), null},
        { null }
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var c = new OptionContext (/* Arguments and description for --help text */
                                   _("[FILE] - Play Chess"));
        c.add_main_entries (options, GETTEXT_PACKAGE);
        c.add_group (Gtk.get_option_group (true));
        try
        {
            c.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            stderr.printf (/* Text printed out when an unknown command-line argument provided */
                           _("Run '%s --help' to see a full list of available command line options."), args[0]);
            stderr.printf ("\n");
            return Posix.EXIT_FAILURE;
        }
        if (show_version)
        {
            /* Note, not translated so can be easily parsed */
            stderr.printf ("gnome-chess %s\n", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        File? game_file = null;
        if (args.length > 1)
            game_file = File.new_for_path (args[1]);

        var app = new Application (game_file);
        return app.run ();
    }
}
