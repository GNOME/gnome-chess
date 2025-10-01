/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2022 Nils Lück
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public const string WIDTH_SETTINGS_KEY = "width";
public const string HEIGHT_SETTINGS_KEY = "height";
public const string MAXIMIZED_SETTINGS_KEY = "maximized";
public const string PIECE_STYLE_SETTINGS_KEY = "piece-theme";
public const string SHOW_BOARD_NUMBERING_SETTINGS_KEY = "show-numbering";
public const string MOVE_FORMAT_SETTINGS_KEY = "move-format";
public const string BOARD_ORIENTATION_SETTINGS_KEY = "board-side";
public const string DURATION_SETTINGS_KEY = "duration";
public const string CLOCK_TYPE_SETTINGS_KEY = "clock-type";
public const string INCREMENT_SETTINGS_KEY = "timer-increment";
public const string PLAY_AS_SETTINGS_KEY = "play-as";
public const string LAST_PLAYED_AS_SETTINGS_KEY = "last-played-as";
public const string OPPONENT_SETTINGS_KEY = "opponent";
public const string DIFFICULTY_SETTINGS_KEY = "difficulty";

public class Preferences : Object
{
    private Settings settings;

    public BoardOrientation board_orientation { get; set; }
    public MoveFormat move_format { get; set; }
    public PieceStyle piece_style { get; set; }
    public bool show_board_numbering { get; set; }

    public Opponent opponent { get; set; }
    public PlayAs play_as { get; set; }
    public Difficulty difficulty { get; set; }

    private bool syncing_time_limit = false;
    public TimeLimit? time_limit { get; set; }

    public Preferences(Settings settings)
    {
        this.settings = settings;

        settings.bind (SHOW_BOARD_NUMBERING_SETTINGS_KEY, this, "show-board-numbering", SettingsBindFlags.DEFAULT);

        settings.bind_with_mapping (
            BOARD_ORIENTATION_SETTINGS_KEY, 
            this, 
            "board-orientation", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = BoardOrientation.from_setting (from_value.get_string ()) ?? BoardOrientation.HUMAN_SIDE;
                to_value.set_enum (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (BoardOrientation) from_value.get_enum ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);

        settings.bind_with_mapping (
            MOVE_FORMAT_SETTINGS_KEY, 
            this, 
            "move-format", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = MoveFormat.from_setting (from_value.get_string ()) ?? MoveFormat.HUMAN;
                to_value.set_enum (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (MoveFormat) from_value.get_enum ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);

        settings.bind_with_mapping (
            PIECE_STYLE_SETTINGS_KEY, 
            this, 
            "piece-style", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = PieceStyle.from_setting (from_value.get_string ()) ?? PieceStyle.SIMPLE;
                to_value.set_enum (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (PieceStyle) from_value.get_enum ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);

        settings.bind_with_mapping (
            PLAY_AS_SETTINGS_KEY, 
            this, 
            "play-as", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = PlayAs.from_setting (from_value.get_string ()) ?? PlayAs.WHITE;
                to_value.set_enum (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (PlayAs) from_value.get_enum ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);

        settings.bind_with_mapping (
            DIFFICULTY_SETTINGS_KEY, 
            this, 
            "difficulty", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = Difficulty.from_setting (from_value.get_string ()) ?? Difficulty.EASY;
                to_value.set_enum (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (Difficulty) from_value.get_enum ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);

        settings.bind_with_mapping (
            OPPONENT_SETTINGS_KEY, 
            this, 
            "opponent", 
            SettingsBindFlags.DEFAULT, 
            (to_value, from_value, user_data) =>
            {
                var value = Opponent.from_setting (from_value.get_string ());
                to_value.set_object (value);
                return true;
            },
            (from_value, expected_type, user_data) =>
            {
                var value = (Opponent) from_value.get_object ();
                return new Variant.string (value.to_setting ());
            },
            null, 
            null);
        
        time_limit_settings_changed_cb ();
        settings.changed[DURATION_SETTINGS_KEY].connect(time_limit_settings_changed_cb);
        settings.changed[INCREMENT_SETTINGS_KEY].connect(time_limit_settings_changed_cb);
        settings.changed[CLOCK_TYPE_SETTINGS_KEY].connect(time_limit_settings_changed_cb);
        notify["time-limit"].connect(time_limit_preferences_changed_cb);
    }

    private void time_limit_settings_changed_cb ()
    {
        if (syncing_time_limit)
            return;
        syncing_time_limit = true;

        var duration = settings.get_int (DURATION_SETTINGS_KEY);
        var increment = settings.get_int (INCREMENT_SETTINGS_KEY);
        var clock_type = settings.get_string (CLOCK_TYPE_SETTINGS_KEY);
        time_limit = TimeLimit.from_settings (duration, increment, clock_type);

        syncing_time_limit = false;
    }

    private void time_limit_preferences_changed_cb ()
    {
        if (syncing_time_limit)
            return;
        syncing_time_limit = true;

        int duration;
        int increment;
        string clock_type;
        TimeLimit.to_settings (time_limit, out duration, out increment, out clock_type);
        settings.set_int (DURATION_SETTINGS_KEY, duration);
        settings.set_int (INCREMENT_SETTINGS_KEY, increment);
        settings.set_string (CLOCK_TYPE_SETTINGS_KEY, clock_type);

        syncing_time_limit = false;
    }
}

public enum BoardOrientation
{
    HUMAN_SIDE,
    WHITE_SIDE,
    BLACK_SIDE,
    CURRENT_PLAYER;

    public string display_name ()
    {
        switch (this)
        {
        case WHITE_SIDE:
            return C_("chess-side", "White Side");
        case BLACK_SIDE:
            return C_("chess-side", "Black Side");
        case HUMAN_SIDE:
            return C_("chess-side", "Human Side");
        case CURRENT_PLAYER:
            return C_("chess-side", "Current Player");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case WHITE_SIDE:
            return "white";
        case BLACK_SIDE:
            return "black";
        case HUMAN_SIDE:
            return "human";
        case CURRENT_PLAYER:
            return "current";
        default:
            assert_not_reached ();
        }
    }

    public static BoardOrientation? from_setting (string s)
    {
        switch (s)
        {
        case "white":
            return WHITE_SIDE;
        case "black":
            return BLACK_SIDE;
        case "human":
            return HUMAN_SIDE;
        case "current":
            return CURRENT_PLAYER;
        default:
            return null;
        }
    }
}

public enum MoveFormat
{
    HUMAN,
    STANDARD_ALGEBRAIC,
    LONG_ALGEBRAIC,
    FIGURINE;

    public string display_name ()
    {
        switch (this)
        {
        case HUMAN:
            return C_("chess-move-format", "Human");
        case STANDARD_ALGEBRAIC:
            return C_("chess-move-format", "Standard Algebraic");
        case LONG_ALGEBRAIC:
            return C_("chess-move-format", "Long Algebraic");
        case FIGURINE:
            return C_("chess-move-format", "Figurine");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case HUMAN:
            return "human";
        case STANDARD_ALGEBRAIC:
            return "san";
        case LONG_ALGEBRAIC:
            return "lan";
        case FIGURINE:
            return "fan";
        default:
            assert_not_reached ();
        }
    }

    public static MoveFormat? from_setting (string s)
    {
        switch (s)
        {
        case "human":
            return HUMAN;
        case "san":
            return STANDARD_ALGEBRAIC;
        case "lan":
            return LONG_ALGEBRAIC;
        case "fan":
            return FIGURINE;
        default:
            return null;
        }
    }
}

public enum PieceStyle
{
    SIMPLE,
    FANCY;

    public string display_name ()
    {
        switch (this)
        {
        case SIMPLE:
            return C_("chess-piece-style", "Simple");
        case FANCY:
            return C_("chess-piece-style", "Fancy");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case SIMPLE:
            return "simple";
        case FANCY:
            return "fancy";
        default:
            assert_not_reached ();
        }
    }

    public static PieceStyle? from_setting (string s)
    {
        switch (s)
        {
        case "simple":
            return SIMPLE;
        case "fancy":
            return FANCY;
        default:
            return null;
        }
    }
}

public enum PlayAs
{
    WHITE,
    BLACK,
    ALTERNATE;

    public string display_name ()
    {
        switch (this)
        {
        case WHITE:
            return C_("chess-player", "White");
        case BLACK:
            return C_("chess-player", "Black");
        case ALTERNATE:
            return C_("chess-player", "Alternate");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case WHITE:
            return "white";
        case BLACK:
            return "black";
        case ALTERNATE:
            return "alternate";
        default:
            assert_not_reached ();
        }
    }

    public static PlayAs? from_setting (string s)
    {
        switch (s)
        {
        case "white":
            return WHITE;
        case "black":
            return BLACK;
        case "alternate":
            return ALTERNATE;
        default:
            return null;
        }
    }
}

public enum Difficulty
{
    EASY,
    NORMAL,
    HARD;

    public string display_name ()
    {
        switch (this)
        {
        case EASY:
            return C_("difficulty", "Easy");
        case NORMAL:
            return C_("difficulty", "Normal");
        case HARD:
            return C_("difficulty", "Hard");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case EASY:
            return "easy";
        case NORMAL:
            return "normal";
        case HARD:
            return "hard";
        default:
            assert_not_reached ();
        }
    }

    public static Difficulty? from_setting (string s)
    {
        switch (s)
        {
        case "easy":
            return EASY;
        case "normal":
            return NORMAL;
        case "hard":
            return HARD;
        default:
            return null;
        }
    }
}

public enum ClockType
{
    FISCHER,
    BRONSTEIN;

    public string display_name ()
    {
        switch (this)
        {
        case FISCHER:
            return C_("clock-type", "Fischer");
        case BRONSTEIN:
            return C_("clock-type", "Bronstein");
        default:
            assert_not_reached ();
        }
    }

    public string to_setting ()
    {
        switch (this)
        {
        case FISCHER:
            return "fischer";
        case BRONSTEIN:
            return "bronstein";
        default:
            assert_not_reached ();
        }
    }

    public static ClockType? from_setting (string s)
    {
        switch (s)
        {
        case "fischer":
            return FISCHER;
        case "bronstein":
            return BRONSTEIN;
        default:
            return null;
        }
    }
}

public class Opponent : Object
{
    private const string HUMAN_NAME = "human";

    private static Opponent _human;
    public static Opponent human
    {
        get
        {
            if (_human == null)
                _human = new Opponent (HUMAN_NAME, C_("chess-opponent", "Human"));
            return _human;
        }
    }

    private static Opponent _default_opponent;
    public static Opponent default_opponent
    {
        get
        {
            if (_default_opponent == null)
                _default_opponent = new Opponent ("", "");
            return _default_opponent;
        }
    }

    public string name { get; private set; }
    public string display_name { get; private set; }
    public bool is_human { get { return name == HUMAN_NAME; } }
    public bool is_default_opponent { get { return name == ""; } }

    public Opponent (string name, string display_name)
    {
        this.name = name;
        this.display_name = display_name;
    }

    public string to_setting ()
    {
        return name;
    }

    public static Opponent from_setting (string s)
    {
        if (s == HUMAN_NAME)
            return human;
        else if (s == null || s.length == 0)
            return default_opponent;
        return new Opponent (s, s);
    }

    public static Opponent from_ai_profile (AIProfile ai_profile)
    {
        return new Opponent (ai_profile.name, ai_profile.name);
    }
}

public class TimeLimit
{
    public int duration_in_seconds { get; private set; }
    public int increment_in_seconds { get; private set; }
    public ClockType clock_type { get; private set; }

    public TimeLimit (int duration_in_seconds, int increment_in_seconds, ClockType clock_type)
    {
        assert_cmpint (duration_in_seconds, CompareOperator.GT, 0);
        assert_cmpint (increment_in_seconds, CompareOperator.GE, 0);
        this.duration_in_seconds = duration_in_seconds;
        this.increment_in_seconds = increment_in_seconds;
        this.clock_type = clock_type;
    }

    public static void to_settings (TimeLimit? time_limit, out int duration, out int increment, out string clock_type)
    {
        if (time_limit == null)
        {
            duration = 0;
            increment = 0;
            clock_type = "simple";
            return;
        }

        duration = time_limit.duration_in_seconds;
        increment = time_limit.increment_in_seconds;

        if (increment == 0)
            clock_type = "simple";
        else
            clock_type = time_limit.clock_type.to_setting ();
    }

    public static TimeLimit? from_settings (int duration_setting, int increment_setting, string clock_type_setting)
    {
        if (duration_setting <= 0)
            return null;

        var clock_type = ClockType.from_setting (clock_type_setting);
        if (clock_type == null || increment_setting <= 0)
            return new TimeLimit (duration_setting, 0, ClockType.FISCHER);

        return new TimeLimit (duration_setting, increment_setting, clock_type);
    }
}
