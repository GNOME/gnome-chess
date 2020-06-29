/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2014 Robert Ancell
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

private int str_index (string name)
{
    if (name == "Event")
        return 0;
    else if (name == "Site")
        return 1;
    else if (name == "Date")
        return 2;
    else if (name == "Round")
        return 3;
    else if (name == "White")
        return 4;
    else if (name == "Black")
        return 5;
    else if (name == "Result")
        return 6;
    else if (name == "WhiteTimeLeft")
         return 7;
    else if (name == "BlackTimeLeft")
         return 8;
    else
        return 9;
}

private int compare_tag (string name0, string name1)
{
    int str_index0 = str_index (name0);
    int str_index1 = str_index (name1);

    /* If both not in STR then just order alphabetically */
    if (str_index0 == 9 && str_index1 == 9)
        return strcmp (name0, name1);
    else
        return str_index0 - str_index1;
}

public errordomain PGNError
{
    LOAD_ERROR
}

public class PGNGame : Object
{
    public HashTable<string, string> tags;
    public List<string> moves;

    public static string RESULT_IN_PROGRESS = "*";
    public static string RESULT_DRAW        = "1/2-1/2";
    public static string RESULT_WHITE       = "1-0";
    public static string RESULT_BLACK       = "0-1";

    public static string TERMINATE_ABANDONED        = "abandoned";
    public static string TERMINATE_ADJUDICATION     = "adjudication";
    public static string TERMINATE_DEATH            = "death";
    public static string TERMINATE_EMERGENCY        = "emergency";
    public static string TERMINATE_NORMAL           = "normal";
    public static string TERMINATE_RULES_INFRACTION = "rules infraction";
    public static string TERMINATE_TIME_FORFEIT     = "time forfeit";
    public static string TERMINATE_UNTERMINATED     = "unterminated";

    public string event
    {
        get { return tags.lookup ("Event"); }
        set { tags.insert ("Event", value); }
    }
    public string site
    {
        get { return tags.lookup ("Site"); }
        set { tags.insert ("Site", value); }
    }
    public string date
    {
        get { return tags.lookup ("Date"); }
        set { tags.insert ("Date", value); }
    }
    public string time
    {
        get { return tags.lookup ("Time"); }
        set { tags.insert ("Time", value); }
    }
    public string round
    {
        get { return tags.lookup ("Round"); }
        set { tags.insert ("Round", value); }
    }
    public string white
    {
        get { return tags.lookup ("White"); }
        set { tags.insert ("White", value); }
    }
    public string black
    {
        get { return tags.lookup ("Black"); }
        set { tags.insert ("Black", value); }
    }
    public string result
    {
        get { return tags.lookup ("Result"); }
        set { tags.insert ("Result", value); }
    }
    public string? annotator
    {
        get { return tags.lookup ("Annotator"); }
        set { tags.insert ("Annotator", value); }
    }
    public string? time_control
    {
        get { return tags.lookup ("TimeControl"); }
        set { tags.insert ("TimeControl", value); }
    }
    public string? white_time_left
    {
        get { return tags.lookup ("WhiteTimeLeft"); }
        set { tags.insert ("WhiteTimeLeft", value); }
    }
    public string? black_time_left
    {
        get { return tags.lookup ("BlackTimeLeft"); }
        set { tags.insert ("BlackTimeLeft", value); }
    }
    public string? clock_type
    {
        get { return tags.lookup ("X-GNOME-ClockType"); }
        set { tags.insert ("X-GNOME-ClockType", value); }
    }
    public string? timer_increment
    {
        get { return tags.lookup ("X-GNOME-TimerIncrement"); }
        set { tags.insert ("X-GNOME-TimerIncrement", value); }
    }
    public bool set_up
    {
        get { string? v = tags.lookup ("SetUp"); return v != null && v == "1" ? true : false; }
        set { tags.insert ("SetUp", value ? "1" : "0"); }
    }
    public string? fen
    {
        get { return tags.lookup ("FEN"); }
        set { tags.insert ("FEN", value); }
    }
    public string? termination
    {
        get { return tags.lookup ("Termination"); }
        set { tags.insert ("Termination", value); }
    }
    public string? white_ai
    {
        get { return tags.lookup ("WhiteAI"); }
        set { tags.insert ("WhiteAI", value); }
    }
    public string? white_level
    {
        get { return tags.lookup ("WhiteLevel"); }
        set { tags.insert ("WhiteLevel", value); }
    }
    public string? black_ai
    {
        get { return tags.lookup ("BlackAI"); }
        set { tags.insert ("BlackAI", value); }
    }
    public string? black_level
    {
        get { return tags.lookup ("BlackLevel"); }
        set { tags.insert ("BlackLevel", value); }
    }

    public PGNGame ()
    {
        tags = new HashTable<string, string> (str_hash, str_equal);
        tags.insert ("Event", "?");
        tags.insert ("Site", "?");
        tags.insert ("Date", "????.??.??");
        tags.insert ("Round", "?");
        tags.insert ("White", "?");
        tags.insert ("Black", "?");
        tags.insert ("Result", PGNGame.RESULT_IN_PROGRESS);
    }

    public string escape (string value)
    {
        var a = value.replace ("\\", "\\\\");
        return a.replace ("\"", "\\\"");
    }

    public void write (File file) throws Error
    {
        var data = new StringBuilder ();

        var keys = tags.get_keys ();
        keys.sort ((CompareFunc) compare_tag);
        foreach (var key in keys)
            data.append ("[%s \"%s\"]\n".printf (key, escape (tags.lookup (key))));
        data.append ("\n");

        int i = 0;
        foreach (string move in moves)
        {
            if (i % 2 == 0)
                data.append ("%d. ".printf (i / 2 + 1));
            data.append (move);
            data.append (" ");
            i++;
        }
        data.append (result);
        data.append ("\n");

        file.replace_contents (data.str.data, null, false, FileCreateFlags.NONE, null);
    }
}

enum State
{
    TAGS,
    MOVE_TEXT,
    LINE_COMMENT,
    BRACE_COMMENT,
    TAG_START,
    TAG_NAME,
    PRE_TAG_VALUE,
    TAG_VALUE,
    POST_TAG_VALUE,
    SYMBOL,
    PERIOD,
    NAG,
    ERROR
}

public class PGN : Object
{
    public List<PGNGame> games;
    private void insert_tag (PGNGame game, string tag_name, string tag_value)
    {
        switch (tag_name)
        {
        case "WhiteTimeLeft":
            if (int64.try_parse (tag_value) == false)
                warning (_("Invalid %s : %s in PGN, setting timer to infinity."), tag_name, tag_value);
            else
                game.tags.insert (tag_name, tag_value);
            break;
        case "BlackTimeLeft":
            if (int64.try_parse (tag_value) == false)
                warning (_("Invalid %s : %s in PGN, setting timer to infinity."), tag_name, tag_value);
            else
                game.tags.insert (tag_name, tag_value);
            break;
        case "TimeControl":
            if (int64.try_parse (tag_value) == true)
                game.tags.insert (tag_name, tag_value);
            else
                warning (_("Invalid %s : %s in PGN, setting timer to infinity."), tag_name, tag_value);
            break;
        case "X-GNOME-ClockType":
            if (ClockType.string_to_enum (tag_value) == ClockType.INVALID)
            {
                warning (_("Invalid clock type in PGN: %s, using a simple clock."), tag_value);
                game.tags.insert (tag_name, "simple");
            }
            break;
        case "X-GNOME-TimerIncrement":
            if (int64.try_parse (tag_value) == false)
            {
                warning (_("Invalid timer increment in PGN: %s, using a simple clock."), tag_value);
                game.tags["X-GNOME-ClockType"] = "simple";
                game.tags.insert (tag_name, "0");
            }
            break;
        default:
            game.tags.insert (tag_name, tag_value);
            break;
        }
    }

    public PGN.from_string (string data) throws PGNError
    {
        // FIXME: Feed through newline at end to make sure parsing complete

        State state = State.TAGS, home_state = State.TAGS;
        PGNGame game = new PGNGame ();
        bool in_escape = false;
        size_t token_start = 0, line_offset = 0;
        string tag_name = "";
        StringBuilder tag_value = new StringBuilder ();
        int line = 1;
        int rav_level = 0;
        for (size_t offset = 0; offset <= data.length; offset++)
        {
            unichar c = data[(long) offset];

            if (c == '\n')
            {
               line++;
               line_offset = offset + 1;
            }

            switch (state)
            {
            case State.TAGS:
                home_state = State.TAGS;
                if (c == ';')
                    state = State.LINE_COMMENT;
                else if (c == '{')
                    state = State.BRACE_COMMENT;
                else if (c == '[')
                    state = State.TAG_START;
                else if (!c.isspace ())
                {
                    offset--;
                    state = State.MOVE_TEXT;
                    continue;
                }
                break;

            case State.MOVE_TEXT:
                home_state = State.MOVE_TEXT;
                if (c == ';')
                    state = State.LINE_COMMENT;
                else if (c == '{')
                    state = State.BRACE_COMMENT;
                else if (c == '*')
                {
                    if (rav_level == 0)
                    {
                        game.result = PGNGame.RESULT_IN_PROGRESS;
                        games.append (game);
                        game = new PGNGame ();
                        state = State.TAGS;
                    }
                }
                else if (c == '.')
                {
                    offset--;
                    state = State.PERIOD;
                }
                else if (c.isalnum ())
                {
                    token_start = offset;
                    state = State.SYMBOL;
                }
                else if (c == '$')
                {
                    token_start = offset + 1;
                    state = State.NAG;
                }
                else if (c == '(')
                {
                    rav_level++;
                    continue;
                }
                else if (c == ')')
                {
                    if (rav_level == 0)
                        state = State.ERROR;
                    else
                        rav_level--;
                }
                else if (!c.isspace ())
                    state = State.ERROR;
                break;

            case State.LINE_COMMENT:
                if (c == '\n')
                    state = home_state;
                break;

            case State.BRACE_COMMENT:
                if (c == '}')
                    state = home_state;
                break;

            case State.TAG_START:
                if (c.isspace ())
                    continue;
                else if (c.isalnum ())
                {
                    token_start = offset;
                    state = State.TAG_NAME;
                }
                else
                    state = State.ERROR;
                break;

            case State.TAG_NAME:
                if (c.isspace ())
                {
                    tag_name = data[(long) token_start:(long) offset];
                    state = State.PRE_TAG_VALUE;
                }
                else if (c.isalnum () || c == '_' || c == '+' || c == '#' || c == '=' || c == ':' || c == '-')
                    continue;
                else
                    state = State.ERROR;
                break;

            case State.PRE_TAG_VALUE:
                if (c.isspace ())
                    continue;
                else if (c == '"')
                {
                    state = State.TAG_VALUE;
                    tag_value.erase ();
                    in_escape = false;
                }
                else
                    state = State.ERROR;
                break;

            case State.TAG_VALUE:
                if (c == '\\' && !in_escape)
                    in_escape = true;
                else if (c == '"' && !in_escape)
                    state = State.POST_TAG_VALUE;
                else if (c.isprint ())
                {
                    tag_value.append_unichar (c);
                    in_escape = false;
                }
                else
                    state = State.ERROR;
                break;

            case State.POST_TAG_VALUE:
                if (c.isspace ())
                    continue;
                else if (c == ']')
                {
                    insert_tag (game, tag_name, tag_value.str);
                    state = State.TAGS;
                }
                else
                    state = State.ERROR;
                break;

            case State.SYMBOL:
                /* NOTE: '/' not in spec but required for 1/2-1/2 symbol */
                if (c.isalnum () || c == '_' || c == '+' || c == '#' || c == '=' || c == ':' || c == '-' || c == '/')
                    continue;
                else
                {
                    string symbol = data[(long) token_start:(long) offset];

                    bool is_number = true;
                    for (int i = 0; i < symbol.length; i++)
                       if (!symbol[i].isdigit ())
                           is_number = false;

                    state = State.MOVE_TEXT;
                    offset--;

                    /* Game termination markers */
                    if (symbol == PGNGame.RESULT_DRAW || symbol == PGNGame.RESULT_WHITE || symbol == PGNGame.RESULT_BLACK)
                    {
                        if (rav_level == 0)
                        {
                            game.result = symbol;
                            games.append (game);
                            game = new PGNGame ();
                            state = State.TAGS;
                        }
                    }
                    else if (!is_number)
                    {
                        if (rav_level == 0)
                            game.moves.append (symbol);
                    }
                }
                break;

            case State.PERIOD:
                /* FIXME: Should check these move carefully, e.g. "1. e2" */
                state = State.MOVE_TEXT;
                break;

            case State.NAG:
                if (c.isdigit ())
                    continue;
                else
                {
                    state = State.MOVE_TEXT;
                    offset--;
                }
                break;

            case State.ERROR:
                size_t char_offset = offset - line_offset - 1;
                stderr.printf ("%d.%d: error: Unexpected character\n", line, (int) (char_offset + 1));
                stderr.printf ("%s\n", data[(long) line_offset:(long) offset]);
                for (int i = 0; i < char_offset; i++)
                    stderr.printf (" ");
                stderr.printf ("^\n");
                return;
            }
        }

        if (game.moves.length () > 0 || game.tags.size () > 0)
            games.append (game);

        /* Must have at least one game */
        if (games == null)
            throw new PGNError.LOAD_ERROR ("No games in PGN file");
    }

    public PGN.from_file (File file) throws Error
    {
        uint8[] contents;
        file.load_contents (null, out contents, null);
        this.from_string ((string) contents);
    }
}
