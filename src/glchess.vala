public class Application
{
    private Settings settings;
    private History history;
    private Gtk.Builder builder;
    private Gtk.Builder preferences_builder;
    private Gtk.Window window;
    private Gtk.Widget save_menu;
    private Gtk.Widget save_as_menu;
    private Gtk.MenuItem fullscreen_menu;
    private Gtk.InfoBar info_bar;
    private Gtk.Label info_title_label;
    private Gtk.Label info_label;
    private Gtk.Container view_container;
    private ChessViewOptions view_options;
    private ChessView view;
    private Gtk.Widget first_move_button;
    private Gtk.Widget prev_move_button;
    private Gtk.Widget next_move_button;
    private Gtk.Widget last_move_button;
    private Gtk.ComboBox history_combo;
    private Gtk.Widget white_time_label;
    private Gtk.Widget black_time_label;

    private Gtk.Dialog? preferences_dialog = null;
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
    private bool in_history;
    private File autosave_file;
    private List<AIProfile> ai_profiles;
    private ChessPlayer? opponent = null;
    private ChessEngine? opponent_engine = null;

    public Application ()
    {
        settings = new Settings ("org.gnome.glchess.Settings");

        var data_dir = File.new_for_path (Path.build_filename (Environment.get_user_data_dir (), "glchess", null));
        DirUtils.create_with_parents (data_dir.get_path (), 0755);

        history = new History (data_dir);

        builder = new Gtk.Builder ();
        try
        {
            builder.add_from_file (Path.build_filename (Config.PKGDATADIR, "glchess.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load UI: %s", e.message);
        }
        window = (Gtk.Window) builder.get_object ("glchess_app");
        save_menu = (Gtk.Widget) builder.get_object ("menu_save_item");
        save_as_menu = (Gtk.Widget) builder.get_object ("menu_save_as_item");
        fullscreen_menu = (Gtk.MenuItem) builder.get_object ("menu_fullscreen");
        first_move_button = (Gtk.Widget) builder.get_object ("first_move_button");
        prev_move_button = (Gtk.Widget) builder.get_object ("prev_move_button");
        next_move_button = (Gtk.Widget) builder.get_object ("next_move_button");
        last_move_button = (Gtk.Widget) builder.get_object ("last_move_button");
        history_combo = (Gtk.ComboBox) builder.get_object ("history_combo");
        white_time_label = (Gtk.Widget) builder.get_object ("white_time_label");
        black_time_label = (Gtk.Widget) builder.get_object ("black_time_label");
        settings.bind ("show-toolbar", builder.get_object ("toolbar"), "visible", SettingsBindFlags.DEFAULT);
        settings.bind ("show-history", builder.get_object ("navigation_box"), "visible", SettingsBindFlags.DEFAULT);
        var view_box = (Gtk.VBox) builder.get_object ("view_box");
        view_container = (Gtk.Container) builder.get_object ("view_container");
        builder.connect_signals (this);

        info_bar = new Gtk.InfoBar ();
        var content_area = (Gtk.Container) info_bar.get_content_area ();
        view_box.pack_start (info_bar, true, true, 0);
        var vbox = new Gtk.VBox (false, 6);
        vbox.show ();
        content_area.add (vbox);
        info_title_label = new Gtk.Label ("");
        info_title_label.show ();
        vbox.pack_start (info_title_label, false, true, 0);
        info_label = new Gtk.Label ("");
        info_label.show ();
        vbox.pack_start (info_label, true, true, 0);

        view_options = new ChessViewOptions ();
        view_options.changed.connect (options_changed_cb);
        settings.bind ("show-move-hints", view_options, "show-move-hints", SettingsBindFlags.GET);
        settings.bind ("show-numbering", view_options, "show-numbering", SettingsBindFlags.GET);
        settings.bind ("piece-theme", view_options, "theme-name", SettingsBindFlags.GET);
        settings.bind ("show-3d-smooth", view_options, "show-3d-smooth", SettingsBindFlags.GET);
        settings.bind ("move-format", view_options, "move-format", SettingsBindFlags.GET);
        settings.bind ("board-side", view_options, "board-side", SettingsBindFlags.GET);

        settings.changed.connect (settings_changed_cb);
        settings_changed_cb (settings, "show-3d");
    }

    public void quit ()
    {
        if (save_duration_timeout != 0)
            save_duration_cb ();

        /* Autosave */
        // FIXME: Only once a human has moved
        if (in_history && pgn_game.moves != null)
        {
            try
            {
                if (autosave_file != null)
                    history.update (autosave_file, "", pgn_game.result);
                else
                    autosave_file = history.add (pgn_game.date, pgn_game.result);
                pgn_game.write (autosave_file);
            }
            catch (Error e)
            {
                warning ("Failed to autosave: %s", e.message);
            }
        }

        settings.sync ();
        Gtk.main_quit ();
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
            view.options = view_options;
            view_container.add (view);
            view.show ();
        }
    }

    private void update_history_panel ()
    {
        if (game == null)
            return;

        var move_number = view_options.move_number;
        var n_moves = (int) game.n_moves;
        if (move_number < 0)
            move_number += 1 + n_moves;

        first_move_button.sensitive = n_moves > 0 && move_number != 0;
        prev_move_button.sensitive = move_number > 0;
        next_move_button.sensitive = move_number < n_moves;
        last_move_button.sensitive = n_moves > 0 && move_number != n_moves;

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
    }

    private void options_changed_cb (ChessViewOptions options)
    {
        update_history_panel ();
    }

    private void start_game ()
    {
        if (pgn_game.set_up)
        {
            if (pgn_game.fen != null)
                game = new ChessGame (pgn_game.fen);
            else
            {
                warning ("Chess game has SetUp tag but no FEN tag");
                game = new ChessGame ();            
            }
        }
        else
            game = new ChessGame ();

        if (pgn_game.time_control != null)
        {
            var controls = pgn_game.time_control.split (":");
            foreach (var control in controls)
            {
                /* We only support simple timeouts */
                var duration = control.to_int ();
                if (duration > 0)
                    game.clock = new ChessClock (duration, duration);
            }
        }

        game.started.connect (game_start_cb);
        game.turn_started.connect (game_turn_cb);
        game.moved.connect (game_move_cb);
        game.ended.connect (game_end_cb);
        if (game.clock != null)
            game.clock.tick.connect (game_clock_tick_cb);

        var model = (Gtk.ListStore) history_combo.model;
        model.clear ();
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 0, "Game Start", 1, 0, -1);
        history_combo.set_active_iter (iter);

        view_options.game = game;
        info_bar.hide ();
        save_menu.sensitive = false;
        save_as_menu.sensitive = false;
        update_history_panel ();

        opponent_engine = get_engine (settings.get_string ("opponent"), settings.get_string ("difficulty"));
        opponent = null;
        if (opponent_engine != null)
        {
            if (settings.get_boolean ("play-as-white"))
                opponent = game.black;
            else
                opponent = game.white;
            opponent_engine.ready_changed.connect (engine_ready_cb);
            opponent_engine.moved.connect (engine_move_cb);
            opponent_engine.start ();
        }

        game.start ();
        foreach (var move in pgn_game.moves)
        {
            debug ("Move: %s", move);
            if (!game.current_player.move (move))
            {
                warning ("Invalid move: %s", move);
                break;
            }
        }

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    private ChessEngine? get_engine (string name, string difficulty)
    {
        ChessEngine engine;
        AIProfile? profile = null;

        if (name == "human")
            return null;

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

        string[] options;
        switch (difficulty)
        {
        case "easy":
            options = profile.easy_options;
            break;
        default:
        case "normal":
            options = profile.normal_options;
            break;
        case "hard":
            options = profile.hard_options;
            break;
        }

        if (profile.protocol == "cecp")
            engine = new ChessEngineCECP (options);
        else if (profile.protocol == "uci")
            engine = new ChessEngineUCI (options);
        else
        {
            warning ("Unknown AI protocol %s", profile.protocol);
            return null;
        }
        engine.binary = profile.binary;

        return engine;
    }

    public void start (File? game = null) throws Error
    {
        ai_profiles = load_ai_profiles (Path.build_filename (Config.PKGDATADIR, "engines.conf", null));
        foreach (var profile in ai_profiles)
            message ("Detected AI profile %s", profile.name);

        if (game == null)
        {
            var unfinished = history.get_unfinished ();
            if (unfinished != null)
            {
                autosave_file = unfinished.data;
                load_game (autosave_file, true);
            }
            else
                start_new_game ();
        }
        else
            load_game (game, false);

        if (settings.get_boolean ("fullscreen"))
            window.fullscreen ();
        show ();
    }

    private void engine_ready_cb (ChessEngine engine)
    {
        if (opponent_engine.ready)
        {
            game.start ();
            view.queue_draw ();
        }
    }
    
    private void engine_move_cb (ChessEngine engine, string move)
    {
        opponent.move (move);
    }

    private void game_start_cb (ChessGame game)
    {
        if (opponent_engine != null)
            opponent_engine.start_game ();
    }

    private void game_clock_tick_cb (ChessClock clock)
    {
        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    private void game_turn_cb (ChessGame game, ChessPlayer player)
    {
        if (opponent_engine != null && player == opponent)
            opponent_engine.request_move ();
    }

    private void set_move_text (Gtk.TreeIter iter, ChessMove move)
    {
        /* Note there are no move formats for pieces taking kings and this is not allowed in Chess rules */
        /* Translators: Human Move String: Description of a white pawn moving from %1s to %2s, e.g. 'c2 to c4' */
        const string human_descriptions[] = {"White pawn moves from %1s to %2s",
                                             "White pawn at %1s takes the black pawn at %2s",
                                             "White pawn at %1s takes the black rook at %2s",
                                             "White pawn at %1s takes the black knight at %2s",
                                             "White pawn at %1s takes the black bishop at %2s",
                                             "White pawn at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a white rook moving from %1s to %2s, e.g. 'a1 to a5' */
                                             "White rook moves from %1s to %2s",
                                             "White rook at %1s takes the black pawn at %2s",
                                             "White rook at %1s takes the black rook at %2s",
                                             "White rook at %1s takes the black knight at %2s",
                                             "White rook at %1s takes the black bishop at %2s",
                                             "White rook at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a white knight moving from %1s to %2s, e.g. 'b1 to c3' */
                                             "White knight moves from %1s to %2s",
                                             "White knight at %1s takes the black pawn at %2s",
                                             "White knight at %1s takes the black rook at %2s",
                                             "White knight at %1s takes the black knight at %2s",
                                             "White knight at %1s takes the black bishop at %2s",
                                             "White knight at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a white bishop moving from %1s to %2s, e.g. 'f1 to b5' */
                                             "White bishop moves from %1s to %2s",
                                             "White bishop at %1s takes the black pawn at %2s",
                                             "White bishop at %1s takes the black rook at %2s",
                                             "White bishop at %1s takes the black knight at %2s",
                                             "White bishop at %1s takes the black bishop at %2s",
                                             "White bishop at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a white queen moving from %1s to %2s, e.g. 'd1 to d4' */
                                             "White queen moves from %1s to %2s",
                                             "White queen at %1s takes the black pawn at %2s",
                                             "White queen at %1s takes the black rook at %2s",
                                             "White queen at %1s takes the black knight at %2s",
                                             "White queen at %1s takes the black bishop at %2s",
                                             "White queen at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a white king moving from %1s to %2s, e.g. 'e1 to f1' */
                                             "White king moves from %1s to %2s",
                                             "White king at %1s takes the black pawn at %2s",
                                             "White king at %1s takes the black rook at %2s",
                                             "White king at %1s takes the black knight at %2s",
                                             "White king at %1s takes the black bishop at %2s",
                                             "White king at %1s takes the black queen at %2s",
        /* Translators: Human Move String: Description of a black pawn moving from %1s to %2s, e.g. 'c8 to c6' */
                                             "Black pawn moves from %1$s to %2$s",
                                             "Black pawn at %1$s takes the white pawn at %2$s",
                                             "Black pawn at %1$s takes the white rook at %2$s",
                                             "Black pawn at %1$s takes the white knight at %2$s",
                                             "Black pawn at %1$s takes the white bishop at %2$s",
                                             "Black pawn at %1$s takes the white queen at %2$s",
        /* Translators: Human Move String: Description of a black rook moving from %1$s to %2$s, e.g. 'a8 to a4' */
                                             "Black rook moves from %1s to %2s",
                                             "Black rook at %1s takes the white pawn at %2s",
                                             "Black rook at %1s takes the white rook at %2s",
                                             "Black rook at %1s takes the white knight at %2s",
                                             "Black rook at %1s takes the white bishop at %2s",
                                             "Black rook at %1s takes the white queen at %2s",
        /* Translators: Human Move String: Description of a black knight moving from %1s to %2s, e.g. 'b8 to c6' */
                                             "Black knight moves from %1s to %2s",
                                             "Black knight at %1s takes the white pawn at %2s",
                                             "Black knight at %1s takes the white rook at %2s",
                                             "Black knight at %1s takes the white knight at %2s",
                                             "Black knight at %1s takes the white bishop at %2s",
                                             "Black knight at %1s takes the white queen at %2s",
        /* Translators: Human Move String: Description of a black bishop moving from %1s to %2s, e.g. 'f8 to b3' */
                                             "Black bishop moves from %1s to %2s",
                                             "Black bishop at %1s takes the white pawn at %2s",
                                             "Black bishop at %1s takes the white rook at %2s",
                                             "Black bishop at %1s takes the white knight at %2s",
                                             "Black bishop at %1s takes the white bishop at %2s",
                                             "Black bishop at %1s takes the white queen at %2s",
        /* Translators: Human Move String: Description of a black queen moving from %1s to %2s, e.g. 'd8 to d5' */
                                             "Black queen moves from %1s to %2s",
                                             "Black queen at %1s takes the white pawn at %2s",
                                             "Black queen at %1s takes the white rook at %2s",
                                             "Black queen at %1s takes the white knight at %2s",
                                             "Black queen at %1s takes the white bishop at %2s",
                                             "Black queen at %1s takes the white queen at %2s",
        /* Translators: Human Move String: Description of a black king moving from %1s to %2s, e.g. 'e8 to f8' */
                                             "Black king moves from %1s to %2s",
                                             "Black king at %1s takes the white pawn at %2s",
                                             "Black king at %1s takes the white rook at %2s",
                                             "Black king at %1s takes the white knight at %2s",
                                             "Black king at %1s takes the white bishop at %2s",
                                             "Black king at %1s takes the white queen at %2s"};

        var move_text = "";
        switch (view_options.move_format)
        {
        case "human":
            int index;
            if (move.victim == null)
                index = 0;
            else
                index = move.victim.type + 1;
            index *= move.piece.type;
            if (move.piece.player.color == Color.BLACK)
                index += 36;

            var start = "%c%d".printf ('a' + move.f0, move.r0 + 1);
            var end = "%c%d".printf ('a' + move.f1, move.r1 + 1);
            move_text = human_descriptions[index].printf (start, end);
            break;

        case "san":
            move_text = move.san;
            break;

        case "fan":
            move_text = move.fan;
            break;

        default:
        case "lan":
            move_text = move.lan;
            break;
        }

        var model = (Gtk.ListStore) history_combo.model;
        var label = "%u%c. %s".printf ((move.number + 1) / 2, move.number % 2 == 0 ? 'b' : 'a', move_text);
        model.set (iter, 0, label, -1);
    }

    private void game_move_cb (ChessGame game, ChessMove move)
    {
        if (move.number > pgn_game.moves.length ())
            pgn_game.moves.append (move.san);

        Gtk.TreeIter iter;
        var model = (Gtk.ListStore) history_combo.model;
        model.append (out iter);
        model.set (iter, 1, game.n_moves, -1);        
        set_move_text (iter, move);
        if (view_options.move_number == -1)
            history_combo.set_active_iter (iter);

        save_menu.sensitive = true;
        save_as_menu.sensitive = true;
        update_history_panel ();

        if (opponent_engine != null)
            opponent_engine.report_move (move);
        view.queue_draw ();
    }

    private void game_end_cb (ChessGame game)
    {
        string title = "";
        switch (game.result)
        {
        case ChessResult.WHITE_WON:
            title = "White wins";
            pgn_game.result = PGNGame.RESULT_WHITE;
            break;
        case ChessResult.BLACK_WON:
            title = "Black wins";
            pgn_game.result = PGNGame.RESULT_BLACK;
            break;
        case ChessResult.DRAW:
            title = "Game is drawn";
            pgn_game.result = PGNGame.RESULT_DRAW;            
            break;
        default:
            break;
        }

        string reason = "";
        switch (game.rule)
        {
        case ChessRule.CHECKMATE:
            /* Message displayed when the game ends due to a player being checkmated */
            reason = "Opponent is in check and cannot move (checkmate)";
            break;
        case ChessRule.STALEMATE:
            /* Message displayed when the game terminates due to a stalemate */
            reason = "Opponent cannot move (stalemate)";
            break;
        case ChessRule.FIFTY_MOVES:
            /* Message displayed when the game is drawn due to the fifty move rule */
            reason = "No piece has been taken or pawn moved in the last fifty moves";
            break;
        case ChessRule.TIMEOUT:
            /* Message displayed when the game ends due to one player's clock stopping */
            reason = "Opponent has run out of time";
            break;
        case ChessRule.THREE_FOLD_REPETITION:
            /* Message displayed when the game is drawn due to the three-fold-repitition rule */
            reason = "The same board state has occurred three times (three fold repetition)";
            break;
        case ChessRule.INSUFFICIENT_MATERIAL:
            /* Message displayed when the game is drawn due to the insufficient material rule */
            reason = "Neither player can cause checkmate (insufficient material)";
            break;
        case ChessRule.RESIGN:
            if (game.result == ChessResult.WHITE_WON)
            {
                /* Message displayed when the game ends due to the black player resigning */
                reason = "The black player has resigned";
            }
            else
            {
                /* Message displayed when the game ends due to the white player resigning */
                reason = "The white player has resigned";
            }
            break;
        case ChessRule.ABANDONMENT:
            /* Message displayed when a game is abandoned */
            reason = "The game has been abandoned";
            pgn_game.termination = PGNGame.TERMINATE_ABANDONED;
            break;
        case ChessRule.DEATH:
            /* Message displayed when the game ends due to a player dying */
            reason = "One of the players has died";
            pgn_game.termination = PGNGame.TERMINATE_DEATH;
            break;
        }

        info_title_label.set_markup ("<big><b>%s</b></big>".printf (title));
        info_label.set_text (reason);
        info_bar.show ();

        white_time_label.queue_draw ();
        black_time_label.queue_draw ();
    }

    public void show ()
    {
        window.show ();
    }

    [CCode (cname = "G_MODULE_EXPORT glchess_app_delete_event_cb", instance_pos = -1)]
    public bool glchess_app_delete_event_cb (Gtk.Widget widget, Gdk.Event event)
    {
        quit ();
        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT glchess_app_window_state_event_cb", instance_pos = -1)]
    public bool glchess_app_window_state_event_cb (Gtk.Widget widget, Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
        {
            bool is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
            settings.set_boolean ("fullscreen", is_fullscreen);
            fullscreen_menu.label = is_fullscreen ? Gtk.Stock.LEAVE_FULLSCREEN : Gtk.Stock.FULLSCREEN;
        }

        return false;
    }

    [CCode (cname = "G_MODULE_EXPORT new_game_cb", instance_pos = -1)]
    public void new_game_cb (Gtk.Widget widget)
    {
        start_new_game ();
    }

    [CCode (cname = "G_MODULE_EXPORT resign_cb", instance_pos = -1)]
    public void resign_cb (Gtk.Widget widget)
    {
        game.current_player.resign ();
    }

    [CCode (cname = "G_MODULE_EXPORT claim_draw_cb", instance_pos = -1)]
    public void claim_draw_cb (Gtk.Widget widget)
    {
        game.current_player.claim_draw ();
    }

    [CCode (cname = "G_MODULE_EXPORT undo_move_cb", instance_pos = -1)]
    public void undo_move_cb (Gtk.Widget widget)
    {
        warning ("FIXME: Undo last move");
    }

    [CCode (cname = "G_MODULE_EXPORT quit_cb", instance_pos = -1)]
    public void quit_cb (Gtk.Widget widget)
    {
        quit ();
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

        int used;
        if (color == Color.WHITE)
            used = (int) (game.clock.white_duration / 1000 - game.clock.white_used_in_seconds);
        else
            used = (int) (game.clock.black_duration / 1000 - game.clock.black_used_in_seconds);

        if (used >= 60)
            return "%d:%02d".printf (used / 60, used % 60);
        else
            return ":%02d".printf (used);
    }

    private void draw_time (Gtk.Widget widget, Cairo.Context c, string text, double[] fg, double[] bg)
    {
        double alpha = 1.0;

        if (widget.get_state () == Gtk.StateType.INSENSITIVE)
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

        widget.set_size_request ((int) extents.width + 6, -1);
    }

    [CCode (cname = "G_MODULE_EXPORT history_combo_changed_cb", instance_pos = -1)]
    public void history_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int move_number;
        combo.model.get (iter, 1, out move_number, -1);
        if (move_number == game.n_moves)
            move_number = -1;
        view_options.move_number = move_number;
    }

    [CCode (cname = "G_MODULE_EXPORT history_latest_clicked_cb", instance_pos = -1)]
    public void history_latest_clicked_cb (Gtk.Widget widget)
    {
        view_options.move_number = -1;
    }

    [CCode (cname = "G_MODULE_EXPORT history_next_clicked_cb", instance_pos = -1)]
    public void history_next_clicked_cb (Gtk.Widget widget)
    {
        if (view_options.move_number == -1)
            return;

        int move_number = view_options.move_number + 1;
        if (move_number >= game.n_moves)
            view_options.move_number = -1;
        else
            view_options.move_number = move_number;
    }

    [CCode (cname = "G_MODULE_EXPORT history_previous_clicked_cb", instance_pos = -1)]
    public void history_previous_clicked_cb (Gtk.Widget widget)
    {
        if (view_options.move_number == 0)
            return;

        if (view_options.move_number == -1)
            view_options.move_number = (int) game.n_moves - 1;
        else
            view_options.move_number = view_options.move_number - 1;
    }

    [CCode (cname = "G_MODULE_EXPORT history_start_clicked_cb", instance_pos = -1)]
    public void history_start_clicked_cb (Gtk.Widget widget)
    {
        view_options.move_number = 0;
    }

    [CCode (cname = "G_MODULE_EXPORT toggle_fullscreen_cb", instance_pos = -1)]
    public void toggle_fullscreen_cb (Gtk.Widget widget)
    {
        if (fullscreen_menu.label == Gtk.Stock.FULLSCREEN)
            window.fullscreen ();
        else
            window.unfullscreen ();
    }

    [CCode (cname = "G_MODULE_EXPORT preferences_cb", instance_pos = -1)]
    public void preferences_cb (Gtk.Widget widget)
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        preferences_builder = new Gtk.Builder ();
        try
        {
            preferences_builder.add_from_file (Path.build_filename (Config.PKGDATADIR, "preferences.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load preferences UI: %s", e.message);
        }
        preferences_dialog = (Gtk.Dialog) preferences_builder.get_object ("preferences");
        
        settings.bind ("show-numbering", preferences_builder.get_object ("show_numbering_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-move-hints", preferences_builder.get_object ("show_move_hints_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-toolbar", preferences_builder.get_object ("show_toolbar_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-history", preferences_builder.get_object ("show_history_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-3d", preferences_builder.get_object ("show_3d_check"),
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-3d-smooth", preferences_builder.get_object ("show_3d_smooth_check"),
                       "active", SettingsBindFlags.DEFAULT);

        var side_combo = (Gtk.ComboBox) preferences_builder.get_object ("side_combo");
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
        settings.bind ("show-history", ai_combo, "visible", SettingsBindFlags.SET);

        var difficulty_combo = (Gtk.ComboBox) preferences_builder.get_object ("difficulty_combo");
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

        var promotion_combo = (Gtk.ComboBox) preferences_builder.get_object ("promotion_type_combo");
        set_combo (promotion_combo, 1, settings.get_string ("promotion-type"));

        var theme_combo = (Gtk.ComboBox) preferences_builder.get_object ("piece_style_combo");
        set_combo (theme_combo, 1, settings.get_string ("piece-theme"));

        preferences_builder.connect_signals (this);

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
        if (max_multiplier > 0)
        {
            duration_adjustment.value = duration / max_multiplier;
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
        var magnitude = (int) duration_adjustment.value;
        int multiplier = 1;
        Gtk.TreeIter iter;
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
    public void duration_changed_cb (Gtk.Widget widget)
    {
        if (save_duration_timeout != 0)
            Source.remove (save_duration_timeout);
        /* Do this delayed as it might change a lot being connected to a spin button */
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
        /* Default to 5 minutes when setting custom duration */
        else if (get_duration () <= 0)
            set_duration (5 * 60, false);
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

    [CCode (cname = "G_MODULE_EXPORT promotion_type_combo_changed_cb", instance_pos = -1)]
    public void promotion_type_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("promotion-type", get_combo (combo, 1));
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

    [CCode (cname = "G_MODULE_EXPORT help_cb", instance_pos = -1)]
    public void help_cb (Gtk.Widget widget)
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "ghelp:glchess", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Unable to open help: %s", e.message);
        }
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>" };
    private const string[] artists = { "John-Paul Gignac (3D Models)", "Max Froumentin (2D Models)", "Hylke Bons <h.bons@student.rug.nl> (icon)" };

    [CCode (cname = "G_MODULE_EXPORT about_cb", instance_pos = -1)]
    public void about_cb (Gtk.Widget widget)
    {
        if (about_dialog != null)
        {
            about_dialog.present ();
            return;
        }

        about_dialog = new Gtk.AboutDialog ();
        about_dialog.transient_for = window;
        about_dialog.name = "glchess";
        about_dialog.version = Config.VERSION;
        about_dialog.copyright = "Copyright 2010 Robert Ancell <robert.ancell@gmail.com>";
        about_dialog.license = "glchess is free software; you can redistribute it and/or modify " +
                               "it under the terms of the GNU General Public License as published by " +
                               "the Free Software Foundation; either version 2 of the License, or " +
                               "(at your option) any later version.\n" +
                               "\n" +
                               "glchess is distributed in the hope that it will be useful, " +
                               "but WITHOUT ANY WARRANTY; without even the implied warranty of " +
                               "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the " +
                               "GNU General Public License for more details.\n" +
                               "\n" +
                               "You should have received a copy of the GNU General Public License " +
                               "along with glchess; if not, write to the Free Software Foundation, Inc., " +
                               "51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA";
        about_dialog.wrap_license = true;
        about_dialog.comments = "The 2D/3D chess game for GNOME. \n\nglChess is a part of GNOME Games.";
        about_dialog.authors = authors;
        about_dialog.artists = artists;
        about_dialog.translator_credits = "translator-credits";
        about_dialog.website = "http://www.gnome.org/projects/gnome-games/";
        about_dialog.website_label = "GNOME Games web site";
        about_dialog.logo_icon_name = "glchess";
        about_dialog.response.connect (about_response_cb);
        about_dialog.show ();
    }
    
    private void about_response_cb (int response_id)
    {
        about_dialog.destroy ();
        about_dialog = null;
    }

    [CCode (cname = "G_MODULE_EXPORT save_game_as_cb", instance_pos = -1)]
    public void save_game_as_cb (Gtk.Widget widget)
    {
        save_game ();
    }

    [CCode (cname = "G_MODULE_EXPORT save_game_cb", instance_pos = -1)]
    public void save_game_cb (Gtk.Widget widget)
    {
        save_game ();
    }

    private void add_info_bar_to_dialog (Gtk.Dialog dialog, out Gtk.InfoBar info_bar, out Gtk.Label label)
    {
        var vbox = new Gtk.VBox (false, 0);
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
        dialog.add (vbox);
    }

    private void save_game ()
    {
        /* Show active dialog */
        if (save_dialog != null)
        {
            save_dialog.present ();
            return;
        }

        save_dialog = new Gtk.FileChooserDialog ("Save Chess Game", window, Gtk.FileChooserAction.SAVE,
                                                 Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                                 Gtk.Stock.SAVE, Gtk.ResponseType.OK, null);
        add_info_bar_to_dialog (save_dialog, out save_dialog_info_bar, out save_dialog_error_label);

        save_dialog.file_activated.connect (save_file_cb);        
        save_dialog.response.connect (save_cb);

        /* Filter out non PGN files by default */
        var pgn_filter = new Gtk.FileFilter ();
        pgn_filter.set_name ("PGN files");
        pgn_filter.add_pattern ("*.pgn");
        save_dialog.add_filter (pgn_filter);

        var all_filter = new Gtk.FileFilter ();
        all_filter.set_name ("All files");
        all_filter.add_pattern ("*");
        save_dialog.add_filter (all_filter);

        save_dialog.present ();
    }    

    private void save_file_cb ()
    {
        save_cb (Gtk.ResponseType.OK);
    }

    private void save_cb (int response_id)
    {
        if (response_id == Gtk.ResponseType.OK)
        {
            save_menu.sensitive = false;

            try
            {
                pgn_game.write (save_dialog.get_file ());
            }
            catch (Error e)
            {
                save_dialog_error_label.set_text ("Failed to save game: %s".printf (e.message));
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

    [CCode (cname = "G_MODULE_EXPORT open_game_cb", instance_pos = -1)]
    public void open_game_cb (Gtk.Widget widget)
    {
        /* Show active dialog */
        if (open_dialog != null)
        {
            open_dialog.present ();
            return;
        }

        open_dialog = new Gtk.FileChooserDialog ("Load Chess Game", window, Gtk.FileChooserAction.OPEN,
                                                 Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
                                                 Gtk.Stock.OPEN, Gtk.ResponseType.OK, null);
        add_info_bar_to_dialog (open_dialog, out open_dialog_info_bar, out open_dialog_error_label);

        open_dialog.file_activated.connect (open_file_cb);        
        open_dialog.response.connect (open_cb);

        /* Filter out non PGN files by default */
        var pgn_filter = new Gtk.FileFilter ();
        pgn_filter.set_name ("PGN files");
        pgn_filter.add_pattern ("*.pgn");
        open_dialog.add_filter (pgn_filter);

        var all_filter = new Gtk.FileFilter ();
        all_filter.set_name ("All files");
        all_filter.add_pattern ("*");
        open_dialog.add_filter (all_filter);

        open_dialog.present ();
    }
    
    private void open_file_cb ()
    {
        open_cb (Gtk.ResponseType.OK);
    }

    private void open_cb (int response_id)
    {
        if (response_id == Gtk.ResponseType.OK)
        {
            try
            {
                load_game (open_dialog.get_file (), false);
            }
            catch (Error e)
            {
                open_dialog_error_label.set_text ("Failed to open game: %s".printf (e.message));
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
        in_history = true;
        pgn_game = new PGNGame ();
        var now = new DateTime.now_local ();
        pgn_game.date = now.format ("%Y.%m.%d");
        pgn_game.time = now.format ("%H:%M:%S");
        var duration = settings.get_int ("duration");
        if (duration > 0)
            pgn_game.time_control = "%d".printf (duration);
        start_game ();
    }

    private void load_game (File file, bool in_history) throws Error
    {
        var pgn = new PGN.from_file (file);
        pgn_game = pgn.games.nth_data (0);

        this.in_history = in_history;
        start_game ();
    }
}

class GlChess
{
    public static int main (string[] args)
    {
        Gtk.init (ref args);

        File? game_file = null;
        for (int i = 1; i < args.length; i++)
        {
            switch (args[i])
            {
            case "-v":
            case "--version":
                stderr.printf ("glchess %s\n", Config.VERSION);
                return Posix.EXIT_SUCCESS;
            case "-h":
            case "-?":
            case "--help":
                usage (args[0], false, true);
                return Posix.EXIT_SUCCESS;
            case "--help-gtk":
                usage (args[0], true, false);
                return Posix.EXIT_SUCCESS;
            case "--help-all":
                usage (args[0], true, true);
                return Posix.EXIT_SUCCESS;
            default:
                if (game_file == null && !args[i].has_prefix ("-"))
                    game_file = File.new_for_path (args[i]);
                else
                {
                    stderr.printf ("Unknown argument '%s'\n", args[i]);
                    stderr.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
                    return Posix.EXIT_FAILURE;
                }
                break;
            }
        }

        Application app = new Application ();
        try
        {
            app.start (game_file);
        }
        catch (Error e)
        {
            stderr.printf ("Failed to load %s: %s\n", game_file.get_path (), e.message);
            return Posix.EXIT_FAILURE;
        }

        Gtk.main ();

        return Posix.EXIT_SUCCESS;
    }

    public static void usage (string appname, bool show_gtk, bool show_application)
    {
        stderr.printf ("Usage:\n" +
                       "  %s [OPTIONS...] [FILE] - Play Chess", appname);
        stderr.printf ("\n\n");

        stderr.printf ("Help Options:\n" +
                       "  -h, -?, --help                  Show help options\n" +
                       "  --help-all                      Show all help options\n" +
                       "  --help-gtk                      Show GTK+ options");
        stderr.printf ("\n\n");

        if (show_gtk)
        {
            stderr.printf ("GTK+ Options:\n" +
                           "  --class=CLASS                   Program class as used by the window manager\n" +
                           "  --name=NAME                     Program name as used by the window manager\n" +
                           "  --screen=SCREEN                 X screen to use\n" +
                           "  --sync                          Make X calls synchronous\n" +
                           "  --gtk-module=MODULES            Load additional GTK+ modules\n" +
                           "  --g-fatal-warnings              Make all warnings fatal");
            stderr.printf ("\n\n");
        }

        if (show_application)
        {
            stderr.printf ("Application Options:\n" +
                           "  -v, --version                   Show release version");
            stderr.printf ("\n\n");
        }
    }
}
