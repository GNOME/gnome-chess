/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2024 Michael Catanzaro
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public const string NEW_GAME_ACTION_NAME = "new";
public const string OPEN_GAME_ACTION_NAME = "open";
public const string SAVE_GAME_ACTION_NAME = "save";
public const string SAVE_GAME_AS_ACTION_NAME = "save-as";
public const string UNDO_MOVE_ACTION_NAME = "undo";
public const string RESIGN_ACTION_NAME = "resign";
public const string PAUSE_RESUME_ACTION_NAME = "pause-resume";
public const string HISTORY_GO_FIRST_ACTION_NAME = "go-first";
public const string HISTORY_GO_PREVIOUS_ACTION_NAME = "go-previous";
public const string HISTORY_GO_NEXT_ACTION_NAME = "go-next";
public const string HISTORY_GO_LAST_ACTION_NAME = "go-last";
public const string PREFERENCES_ACTION_NAME = "preferences";
public const string HELP_ACTION_NAME = "help";
public const string ABOUT_ACTION_NAME = "about";
public const string QUIT_ACTION_NAME = "quit";

// https://gitlab.gnome.org/GNOME/gtk/-/issues/6135
namespace Workaround {
    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_show_uri")]
    extern static void gtk_show_uri (Gtk.Window? parent, string uri, uint32 timestamp);
}

public class ChessApplication : Adw.Application
{
    private GLib.Settings settings;
    private Preferences preferences;

    public unowned ChessWindow window
    {
        get; private set;
    }

    public ChessView view
    {
        get { return window.view; }
    }

    public ChessScene scene
    {
        get { return view.scene; }
    }

    private NewGameDialog? new_game_dialog = null;
    private PreferencesDialog? preferences_dialog = null;
    private Adw.AboutDialog? about_dialog = null;
    private Gtk.FileDialog? open_dialog = null;
    private Gtk.FileDialog? save_dialog = null;

    private PGNGame pgn_game;
    private ChessGame? game = null;
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
Copyright © 2013–2024 Michael Catanzaro
Copyright © 2015–2016 Sahil Sareen""";

    private const ActionEntry[] action_entries =
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
        { PREFERENCES_ACTION_NAME, preferences_cb },
        { HELP_ACTION_NAME, help_cb },
        { ABOUT_ACTION_NAME, about_cb },
        { QUIT_ACTION_NAME, quit_cb },
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

        settings = new Settings ("org.gnome.Chess");
        preferences = new Preferences (settings);

        add_action_entries (action_entries, this);
        set_accels_for_action ("app." + NEW_GAME_ACTION_NAME,            {        "<Control>n"     });
        set_accels_for_action ("app." + OPEN_GAME_ACTION_NAME,           {        "<Control>o"     });
        set_accels_for_action ("app." + SAVE_GAME_ACTION_NAME,           {        "<Control>s"     });
        set_accels_for_action ("app." + SAVE_GAME_AS_ACTION_NAME,        { "<Shift><Control>s"     });
        set_accels_for_action ("app." + UNDO_MOVE_ACTION_NAME,           {        "<Control>z"     });
        set_accels_for_action ("app." + PAUSE_RESUME_ACTION_NAME,        {        "<Control>p",
                                                                                           "Pause" });
        set_accels_for_action ("app." + HISTORY_GO_FIRST_ACTION_NAME,    {                 "Up"    });
        set_accels_for_action ("app." + HISTORY_GO_PREVIOUS_ACTION_NAME, {                 "Left"  });
        set_accels_for_action ("app." + HISTORY_GO_NEXT_ACTION_NAME,     {                 "Right" });
        set_accels_for_action ("app." + HISTORY_GO_LAST_ACTION_NAME,     {                 "Down"  });
        set_accels_for_action ("app." + HELP_ACTION_NAME,                {                 "F1"    });
        set_accels_for_action ("app." + QUIT_ACTION_NAME,                {        "<Control>q",
                                                                                  "<Control>w"     });
    }

    private void create_window () {
        window = new ChessWindow (this);
        window.set_default_size (settings.get_int (WIDTH_SETTINGS_KEY), settings.get_int (HEIGHT_SETTINGS_KEY));
        if (settings.get_boolean (MAXIMIZED_SETTINGS_KEY))
            window.maximize ();
        add_window (window);

        settings.bind (SHOW_MOVE_HINTS_SETTINGS_KEY, scene, "show-move-hints", SettingsBindFlags.GET);
        settings.bind (SHOW_BOARD_NUMBERING_SETTINGS_KEY, scene, "show-numbering", SettingsBindFlags.GET);
        settings.bind (PIECE_STYLE_SETTINGS_KEY, scene, "theme-name", SettingsBindFlags.GET);
        settings.bind (MOVE_FORMAT_SETTINGS_KEY, scene, "move-format", SettingsBindFlags.GET);
        settings.bind (BOARD_ORIENTATION_SETTINGS_KEY, scene, "board-side", SettingsBindFlags.GET);

        scene.is_human.connect ((p) => { return p == human_player; });
        scene.choose_promotion_type.connect (show_promotion_type_selector);

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
        if (window == null)
            create_window ();

        window.present ();
    }

    protected override void shutdown ()
    {
        if (window != null)
        {
            if (opponent_engine != null)
                opponent_engine.stop ();

            autosave ();

            /* Save window state */
            settings.delay ();
            settings.set_int (WIDTH_SETTINGS_KEY, window.default_width);
            settings.set_int (HEIGHT_SETTINGS_KEY, window.default_height);
            settings.set_boolean (MAXIMIZED_SETTINGS_KEY, window.maximized);
            settings.apply ();
        }

        base.shutdown ();
    }

    public void quit_game ()
    {
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

    private void start_game ()
    {
        starting = true;

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

        if (game != null)
        {
            game.turn_started.disconnect (game_turn_cb);
            game.moved.disconnect (game_move_cb);
            game.undo.disconnect (game_undo_cb);
            game.ended.connect (game_end_cb);
        }

        try
        {
            game = new ChessGame (fen, moves);
        }
        catch (Error e)
        {
            show_invalid_move_dialog (e.message);
            configure_new_game ();
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

        scene.game = game;

        window.start_game ();

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
        }
        else if (black_engine != null)
        {
            opponent = game.black;
            human_player = game.white;
            opponent_engine = get_engine (black_engine, black_level);
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
            opponent.local_human = false;
            human_player.local_human = true;

            opponent_engine.moved.connect (engine_move_cb);
            opponent_engine.resigned.connect (engine_resigned_cb);
            opponent_engine.stopped_unexpectedly.connect (engine_stopped_unexpectedly_cb);
            opponent_engine.error.connect (engine_error_cb);
            opponent_engine.claim_draw.connect (engine_claim_draw_cb);
            opponent_engine.offer_draw.connect (engine_offer_draw_cb);

            if (!opponent_engine.start ())
            {
                disable_action (SAVE_GAME_ACTION_NAME);
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
            enable_action (SAVE_GAME_ACTION_NAME);
        }
        else
        {
            game_needs_saving = false;
            disable_action (SAVE_GAME_ACTION_NAME);
        }

        game.start ();

        int timer_increment_adj_value = 0;
        if (pgn_game.timer_increment != null)
            timer_increment_adj_value = int.parse (pgn_game.timer_increment);
        else
        {
            timer_increment_adj_value = settings.get_int (INCREMENT_SETTINGS_KEY);
            pgn_game.timer_increment = timer_increment_adj_value.to_string ();
        }

        ChessClockType clock_type = ChessClockType.SIMPLE;
        if (pgn_game.clock_type != null)
            clock_type = ChessClockType.string_to_enum (pgn_game.clock_type);
        else
        {
            clock_type = ChessClockType.string_to_enum (settings.get_string (CLOCK_TYPE_SETTINGS_KEY));
            pgn_game.clock_type = clock_type.to_string ();
        }

        window.set_clock_visible (game.clock != null);

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
            enable_action (PAUSE_RESUME_ACTION_NAME);
        }
        else
        {
            disable_action (PAUSE_RESUME_ACTION_NAME);
        }

        update_action_status ();
        window.update_history_panel ();
        window.update_pause_resume_button ();

        if (ai_profiles == null)
        {
            window.update_game_status (null,
                                       /* Warning at start of game when no chess engine is installed. */
                                       _("No chess engine is installed. You will not be able to play against the computer."));
        }
        else
        {
            window.update_game_status ();
        }

        starting = false;

        if (opponent_engine != null &&
            (white_engine != null && game.current_player.color == Color.WHITE ||
             black_engine != null && game.current_player.color == Color.BLACK))
        {
            update_engine_timeout ();
            opponent_engine.move ();
        }

        // If loading a completed saved game
        if (game.result != ChessResult.IN_PROGRESS)
            game.stop (game.result, ChessRule.UNKNOWN);
    }

    private AIProfile? get_ai_profile (string name)
    {
        if (name == "human")
            return null;

        /* Backwards compatibility with our old spelling of GNU Chess */
        if (name == "GNUchess")
            name = "GNU Chess";

        foreach (var p in ai_profiles)
        {
            if (name == "" || p.name == name)
                return p;
        }

        return null;
    }

    private ChessEngine? get_engine (string name, string difficulty)
    {
        AIProfile? profile = get_ai_profile (name);
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

        ChessEngine engine;
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
            enable_action (PAUSE_RESUME_ACTION_NAME);
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
            engine_timeout_source = Timeout.add_seconds (30, () => {
                engine_timeout_source = 0;
                warning ("Engine did not move for 30 seconds! Game over.");
                engine_error_cb (opponent_engine);
                return Source.REMOVE;
            });
        }
    }

    private void game_move_cb (ChessGame game, ChessMove move)
    {
        /* Warning: this callback is invoked several times when loading a game. */

        /* Need to save after each move */
        game_needs_saving = true;

        /* If the only mover is the AI, then don't bother saving */
        if (move.number == 1 && opponent != null && opponent.color == Color.WHITE)
            game_needs_saving = false;

        if (move.number > pgn_game.moves.length ())
            pgn_game.moves.append (move.get_san ());

        window.move (move);

        enable_action (SAVE_GAME_ACTION_NAME);
        enable_action (SAVE_GAME_AS_ACTION_NAME);
        update_action_status ();
        window.update_history_panel ();
        window.update_game_status ();

        view.queue_draw ();

        /* This work goes in a timeout to give the game widget a chance to
         * redraw first, so the pieces are shown to move before displaying the
         * claim draw dialog. */
        var started = !starting && game.is_started;
        Timeout.add(100, () => {
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

        window.undo ();

        if (game.n_moves > 0)
        {
            game_needs_saving = true;
            enable_action (SAVE_GAME_ACTION_NAME);
            enable_action (SAVE_GAME_AS_ACTION_NAME);
        }
        else
        {
            game_needs_saving = false;
            disable_action (SAVE_GAME_ACTION_NAME);
            disable_action (SAVE_GAME_AS_ACTION_NAME);
        }

        update_action_status ();
        window.update_history_panel ();
        window.update_game_status ();
    }

    private void update_action_status ()
    {
        var can_resign = game.n_moves > 0 && !game.is_paused;
        if (can_resign)
            enable_action (RESIGN_ACTION_NAME);
        else
            disable_action (RESIGN_ACTION_NAME);

        /* Can undo once the human player has made a move */
        var can_undo = game.n_moves > 0 && !game.is_paused;
        if (opponent != null && opponent.color == Color.WHITE)
            can_undo = game.n_moves > 1 && !game.is_paused;

        if (can_undo)
            enable_action (UNDO_MOVE_ACTION_NAME);
        else
            disable_action (UNDO_MOVE_ACTION_NAME);
    }

    public string compute_current_title ()
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

    public string? compute_status_info ()
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

    private void game_end_cb ()
    {
        disable_action (RESIGN_ACTION_NAME);
        disable_action (PAUSE_RESUME_ACTION_NAME);

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
            why = _("Player cannot move.");
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

        window.update_game_status (what, why);
        window.end_game ();
        update_engine_timeout ();
    }

    private delegate void PromptSaveGameCallback (bool cancelled);
    private void prompt_save_game (string prompt_text, PromptSaveGameCallback callback)
    {
        if (!game_needs_saving)
        {
            callback (false);
            return;
        }

        var prompt_save_game_dialog = new Adw.AlertDialog (_("Save Game?"), prompt_text);

        prompt_save_game_dialog.add_response ("cancel", _("_Cancel"));

        if (game.result == ChessResult.IN_PROGRESS)
        {
            prompt_save_game_dialog.add_responses ("no", _("_Abandon Game"),
                                                   "yes", _("Save game for later"));
            prompt_save_game_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DESTRUCTIVE);
            prompt_save_game_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.SUGGESTED);
        }
        else
        {
            prompt_save_game_dialog.add_responses ("no", _("_Discard Game"),
                                                   "yes", _("Save game log"));
            prompt_save_game_dialog.set_response_appearance ("no", Adw.ResponseAppearance.DESTRUCTIVE);
            prompt_save_game_dialog.set_response_appearance ("yes", Adw.ResponseAppearance.SUGGESTED);
        }

        prompt_save_game_dialog.response.connect ((dialog, response) => {
            if (response == "cancel" || response == "close")
            {
                callback (true);
            }
            else if (response == "yes")
            {
                present_save_dialog ((saved) => {
                    callback (!saved);
                });
            }
            else if (response == "no")
            {
                /* Remove completed game from history */
                game_needs_saving = false;
                autosave ();

                callback (false);
            }
        });

        prompt_save_game_dialog.present (window);
    }

    private void present_claim_draw_dialog ()
        requires (game.can_claim_draw ())
    {
        game.pause (false);

        var claim_draw_dialog = new Adw.AlertDialog (_("Would you like to claim a draw?"), "");

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
        else
            assert_not_reached ();

        claim_draw_dialog.body = reason;

        claim_draw_dialog.add_responses ("reject", _("_Keep Playing"),
                                         "accept", _("_Claim Draw"));
        claim_draw_dialog.set_response_appearance ("reject", Adw.ResponseAppearance.SUGGESTED);
        claim_draw_dialog.set_response_appearance ("accept", Adw.ResponseAppearance.DESTRUCTIVE);

        claim_draw_dialog.response.connect ((dialog, response) => {
            game.unpause ();

            if (response == "accept")
                game.current_player.claim_draw ();
        });

        claim_draw_dialog.present (window);
    }

    public void new_game_cb ()
    {
        prompt_save_game (_("By starting a new game now, unsaved progress would be lost."), (cancelled) => {
            if (!cancelled)
                configure_new_game ();
        });
    }

    public void resign_cb ()
    {
        game.pause (false);

        var resign_dialog = new Adw.AlertDialog (_("Are you sure you want to resign?"), "");
        /* Text on warning dialog when player clicks Resign */
        resign_dialog.body = _("This makes sense if you plan to save the game as a record of your loss.");
        resign_dialog.add_responses ("reject", _("_Keep Playing"),
                                     "accept", _("_Resign"));
        resign_dialog.set_response_appearance ("reject", Adw.ResponseAppearance.SUGGESTED);
        resign_dialog.set_response_appearance ("accept", Adw.ResponseAppearance.DESTRUCTIVE);

        resign_dialog.response.connect ((dialog, response) => {
            game.unpause ();

            if (response == "accept")
            {
                if (human_player != null)
                    human_player.resign ();
                else
                    game.current_player.resign ();
            }
        });

        resign_dialog.present (window);
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

        update_action_status ();
        window.update_history_panel ();
        window.update_pause_resume_button ();
    }

    public void quit_cb ()
    {
        quit_game ();
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

    private void configure_new_game ()
    {
        if (new_game_dialog != null)
        {
            new_game_dialog.present (window);
            return;
        }

        new_game_dialog = new NewGameDialog (preferences, ai_profiles);
        new_game_dialog.new_game_requested.connect (() => start_new_game ());
        new_game_dialog.present (window);
    }

    private void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present (window);
            return;
        }

        preferences_dialog = new PreferencesDialog (preferences);
        preferences_dialog.present (window);
    }

    public void help_cb ()
    {
        Workaround.gtk_show_uri (window, "help:gnome-chess", Gdk.CURRENT_TIME);
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>", "Michael Catanzaro <mcatanzaro@gnome.org>", null };
    private const string[] artists = { "Max Froumentin", "Jakub Steiner", null };

    public void about_cb ()
    {
        if (about_dialog != null)
        {
            about_dialog.present (window);
            return;
        }

        about_dialog = new Adw.AboutDialog ();
        about_dialog.application_name = _("Chess");
        about_dialog.version = VERSION;
        about_dialog.copyright = copyrights;
        about_dialog.license_type = Gtk.License.GPL_3_0;
        about_dialog.developers = authors;
        about_dialog.artists = artists;
        about_dialog.translator_credits = _("translator-credits");
        about_dialog.application_icon = "org.gnome.Chess";
        about_dialog.present (window);
    }

    private void show_promotion_type_selector (owned ChessScene.PromotionTypeCompletionHandler handler)
    {
        /* We cannot cache this dialog because it uses the piece color of the current player. */
        var promotion_type_selector_dialog = new PromotionTypeSelectorDialog (game.current_player.color,
                                                                              scene.theme_name);

        promotion_type_selector_dialog.piece_selected.connect ((selected_type) => {
            switch (selected_type)
            {
            case PromotionTypeSelectorDialog.SelectedType.QUEEN:
                handler (PieceType.QUEEN);
                break;
            case PromotionTypeSelectorDialog.SelectedType.KNIGHT:
                handler (PieceType.KNIGHT);
                break;
            case PromotionTypeSelectorDialog.SelectedType.ROOK:
                handler (PieceType.ROOK);
                break;
            case PromotionTypeSelectorDialog.SelectedType.BISHOP:
                handler (PieceType.BISHOP);
                break;
            default:
                handler (null);
                break;
            }

            promotion_type_selector_dialog.close ();
            promotion_type_selector_dialog = null;
        });

        promotion_type_selector_dialog.present (window);
    }

    private void run_invalid_pgn_dialog ()
    {
        var invalid_pgn_dialog = new Adw.AlertDialog (_("Error Loading PGN File"),
                                                      _("This does not look like a valid PGN game."));
        invalid_pgn_dialog.add_response ("okay", _("_OK"));
        invalid_pgn_dialog.response.connect ((dialog, response) => invalid_pgn_dialog.destroy ());
        invalid_pgn_dialog.present (window);
    }

    private void show_invalid_move_dialog (string error_message)
    {
        var invalid_move_dialog = new Adw.AlertDialog (_("Invalid Move"), error_message);
        invalid_move_dialog.add_response ("okay", _("_OK"));
        invalid_move_dialog.response.connect (( dialog, response) => invalid_move_dialog.destroy ());
        invalid_move_dialog.present (window);
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

    /* Why is the callback owned? https://gitlab.gnome.org/GNOME/gnome-chess/-/issues/92#note_2164360 */
    private delegate void PresentSaveDialogCallback (bool saved);
    private void present_save_dialog (owned PresentSaveDialogCallback? callback = null)
    {
        if (save_dialog == null)
        {
            save_dialog = new Gtk.FileDialog ();
            /* Title of save game dialog */
            save_dialog.title = _("Save Chess Game");

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
                    save_dialog.set_initial_file (game_file);
                    set_file = true;
                }
            }

            if (!set_file)
            {
                save_dialog.set_initial_name (/* Default filename for the save game dialog */
                                              _("Untitled Chess Game") + ".pgn");
            }

            /* Filter out non PGN files by default */
            var pgn_filter = new Gtk.FileFilter ();
            /* Save Game Dialog: Name of filter to show only PGN files */
            pgn_filter.set_filter_name (_("PGN files"));
            pgn_filter.add_pattern ("*.pgn");

            var all_filter = new Gtk.FileFilter ();
            /* Save Game Dialog: Name of filter to show all files */
            all_filter.set_filter_name (_("All files"));
            all_filter.add_pattern ("*");

            var filters = new ListStore (typeof (Gtk.FileFilter));
            filters.append (pgn_filter);
            filters.append (all_filter);
            save_dialog.filters = filters;
        }

        save_dialog.save.begin (window, null, (object, result) => {
            update_pgn_time_remaining ();

            try
            {
                game_file = save_dialog.save.end (result);
                pgn_game.write (game_file);

                disable_action (SAVE_GAME_ACTION_NAME);
                game_needs_saving = false;

                if (callback != null)
                    callback (true);
            }
            catch (Error e)
            {
                if (e.matches (Gtk.DialogError.quark (), Gtk.DialogError.DISMISSED))
                {
                    if (callback != null)
                        callback (false);
                    return;
                }

                var save_error_dialog = new Adw.AlertDialog (_("Save Error"), "");
                save_error_dialog.format_body (_("Failed to save game: %s"), e.message);
                save_error_dialog.add_response ("ok", _("_OK"));
                save_error_dialog.response.connect(( dialog, response ) => {
                    if (callback != null)
                        callback (false);
                });
                save_error_dialog.present (window);
            }
        });
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
            disable_action (SAVE_GAME_ACTION_NAME);
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
        prompt_save_game (_("Save this game before loading another one?"), (cancelled) => {
            if (cancelled)
                return;

            if (open_dialog == null)
            {
                open_dialog = new Gtk.FileDialog ();
                /* Title of load game dialog */
                open_dialog.title = _("Load Chess Game");
                open_dialog.modal = true;

                /* Filter out non PGN files by default */
                var pgn_filter = new Gtk.FileFilter ();
                /* Load Game Dialog: Name of filter to show only PGN files */
                pgn_filter.set_filter_name (_("PGN files"));
                pgn_filter.add_pattern ("*.pgn");

                var all_filter = new Gtk.FileFilter ();
                /* Load Game Dialog: Name of filter to show all files */
                all_filter.set_filter_name (_("All files"));
                all_filter.add_pattern ("*");

                var filters = new ListStore (typeof (Gtk.FileFilter));
                filters.append (pgn_filter);
                filters.append (all_filter);
                open_dialog.filters = filters;
            }

            open_dialog.open.begin (window, null, (object, result) => {
                try
                {
                    game_file = open_dialog.open.end (result);
                    load_game (game_file);
                }
                catch (Error e)
                {
                    if (!e.matches (Gtk.DialogError.quark (), Gtk.DialogError.DISMISSED))
                        warning ("Failed to open game: %s", e.message);
                }
            });
        });
    }

    private void start_new_game ()
    {
        game_file = null;

        disable_action (SAVE_GAME_AS_ACTION_NAME);

        pgn_game = new PGNGame ();
        var now = new DateTime.now_local ();
        pgn_game.date = now.format ("%Y.%m.%d");
        pgn_game.time = now.format ("%H:%M:%S");
        var duration = settings.get_int (DURATION_SETTINGS_KEY);
        if (duration > 0)
        {
            pgn_game.time_control = duration.to_string ();
            pgn_game.white_time_left = duration.to_string ();
            pgn_game.black_time_left = duration.to_string ();
        }
        var engine_level = settings.get_string (DIFFICULTY_SETTINGS_KEY);
        var engine_name = settings.get_string (OPPONENT_SETTINGS_KEY);
        if (engine_name != "human" && get_ai_profile (engine_name) == null)
        {
            if (ai_profiles != null)
                engine_name = ai_profiles.data.name;
            else
                engine_name = "human";
        }
        if (engine_name != null && engine_name != "human")
        {
            var play_as = settings.get_string (PLAY_AS_SETTINGS_KEY);

            if (play_as == "alternate")
            {
                var last_side = settings.get_string (LAST_PLAYED_AS_SETTINGS_KEY);
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

            settings.set_string (LAST_PLAYED_AS_SETTINGS_KEY, play_as);
        }

        start_game ();
    }

    private void load_game (File file)
    {
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

    public void enable_action (string name)
    {
        ((SimpleAction) lookup_action (name)).set_enabled (true);
    }

    public void disable_action (string name)
    {
        ((SimpleAction) lookup_action (name)).set_enabled (false);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Chess"));
        Gtk.Window.set_default_icon_name ("org.gnome.Chess");

        return new ChessApplication ().run (args);
    }
}
