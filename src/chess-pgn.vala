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
    else
        return 7;
}

private int compare_tag (string name0, string name1)
{
    int str_index0 = str_index (name0);
    int str_index1 = str_index (name1);

    /* If both not in STR then just order alphabetically */
    if (str_index0 == 7 && str_index1 == 7)
        return strcmp (name0, name1);
    else
        return str_index0 - str_index1;
}

public errordomain PGNError
{
    LOAD_ERROR
}

public class PGNGame
{
    public HashTable<string, string> tags;
    public List<string> moves;

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

    public PGNGame ()
    {
        tags = new HashTable<string, string> (str_hash, str_equal);
        tags.insert ("Event", "?");
        tags.insert ("Site", "?");
        tags.insert ("Date", "????.??.??");
        tags.insert ("Round", "?");
        tags.insert ("White", "?");
        tags.insert ("Black", "?");
        tags.insert ("Result", "*");
    }

    public void write (OutputStream stream) throws Error
    {
        // FIXME: Escape \ and " in tag values
        var keys = tags.get_keys ();
        keys.sort ((CompareFunc) compare_tag);
        foreach (var key in keys)
            write_string (stream, "[%s \"%s\"]\n".printf (key, tags.lookup (key)));
        write_string (stream, "\n");

        int i = 0;
        foreach (string move in moves)
        {
            if (i % 2 == 0)
                write_string (stream, "%d. ".printf (i / 2 + 1));
            write_string (stream, move);
            write_string (stream, " ");
            i++;
        }
        write_string (stream, result);
        write_string (stream, "\n");
    }

    private void write_string (OutputStream stream, string value) throws Error
    {
        stream.write_all ((uint8[]) value, null);
    }
}

enum State
{
    IDLE,
    LINE_COMMENT,
    BRACE_COMMENT,
    TAG_START,
    TAG_NAME,
    PRE_TAG_VALUE,
    TAG_VALUE,
    POST_TAG_VALUE,
    SYMBOL,
    NAG,
    ERROR
}

public class PGN
{
    public List<PGNGame> games;

    public PGN ()
    {
    }

    public PGN.from_file (File file) throws Error
    {
        string contents;
        size_t n_read;
        file.load_contents (null, out contents, out n_read);
        
        // FIXME: Feed through newline at end to make sure parsing complete
       
        State state = State.IDLE;
        PGNGame game = new PGNGame ();
        bool in_escape = false;
        size_t token_start = 0, line_offset = 0;
        string tag_name = "";
        StringBuilder tag_value = new StringBuilder ();
        int line = 1;
        bool have_tags = false;
        int rav_level = 0;
        for (size_t offset = 0; offset < contents.length; offset++)
        {
            unichar c = contents[(long) offset];
            
            if (c == '\n')
            {
               line++;
               line_offset = offset + 1;
            }
            
            switch (state)
            {
            case State.IDLE:
                if (c.isspace ())
                    ;//
                else if (c == ';')
                    state = State.LINE_COMMENT;
                else if (c == '{')
                    state = State.BRACE_COMMENT;
                else if (c == '[')
                {
                    have_tags = true;
                    state = State.TAG_START;
                }
                else if (have_tags && c == '*')
                {
                    if (rav_level == 0)
                    {
                        game.result = "*";
                        games.append (game);
                        game = new PGNGame ();
                        have_tags = false;
                    }
                    state = State.IDLE;
                }
                else if (have_tags && c == '.')
                    continue;
                else if (have_tags && c.isalnum ())
                {
                    token_start = offset;
                    state = State.SYMBOL;
                }
                else if (have_tags && c == '$')
                {
                    token_start = offset + 1;
                    state = State.NAG;
                }
                else if (have_tags && c == '(')
                {
                    rav_level++;
                    continue;
                }
                else if (have_tags && c == ')')
                {
                    if (rav_level == 0)
                        state = State.ERROR;
                    else
                        rav_level--;
                }
                else
                    state = State.ERROR;
                break;

            case State.LINE_COMMENT:
                if (c == '\n')
                    state = State.IDLE;
                break;

            case State.BRACE_COMMENT:
                if (c == '}')
                    state = State.IDLE;
                break;

            case State.TAG_START:
                if (c.isspace ())
                    continue;
                else if (c.isalnum())
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
                    tag_name = contents[(long)token_start:(long)offset];
                    state = State.PRE_TAG_VALUE;
                }
                else if (c.isalnum() || c == '_' || c == '+' || c == '#' || c == '=' || c == ':' || c == '-')
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
                    game.tags.insert (tag_name, tag_value.str);
                    state = State.IDLE;
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
                    string symbol = contents[(long)token_start:(long)offset];

                    bool is_number = true;
                    for (int i = 0; i < symbol.length; i++)
                       if (!symbol[i].isdigit ())
                           is_number = false;

                    /* Game termination markers */
                    if (symbol == "1/2-1/2" || symbol == "1-0" || symbol == "0-1")
                    {
                        if (rav_level == 0)
                        {
                            game.result = symbol;
                            games.append (game);
                            game = new PGNGame ();
                            have_tags = false;
                        }
                    }
                    else if (!is_number)
                    {
                        if (rav_level == 0)
                            game.moves.append (symbol);
                    }

                    state = State.IDLE;
                    offset--;
                }
                break;

            case State.NAG:
                if (c.isdigit ())
                    continue;
                else
                {
                    //string nag = contents[(long)token_start:(long)offset];
                    //stdout.printf ("nag = '%s'\n", nag);
                    state = State.IDLE;
                    offset--;
                }
                break;

            case State.ERROR:
                size_t char_offset = offset - line_offset - 1;
                var filename = file.get_path ();
                if (filename == null)
                    filename = file.get_uri ();
                stderr.printf ("%s:%d.%d: error: Unexpected character\n", filename, line, (int) (char_offset + 1));
                stderr.printf ("%s\n", contents[(long)line_offset:(long)offset]);
                for (int i = 0; i < char_offset; i++)
                    stderr.printf (" ");
                stderr.printf ("^\n");
                return;
            }
        }

        /* Must have at least one game */
        if (games == null)
            throw new PGNError.LOAD_ERROR("No games in PGN file");
    }
}