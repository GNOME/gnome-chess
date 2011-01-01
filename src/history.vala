public class History
{
    private File history_dir;
    private bool loaded = false;
    private Sqlite.Database db;

    public History (File data_dir)
    {
        history_dir = File.new_for_path (Path.build_filename (data_dir.get_path (), "history", null));
    }
    
    public File add (int year, int month, int day, string result) throws Error
    {
        load ();

        string relative_path;
        File file;
        int version = 0;
        while (true)
        {
            string filename;
            if (version == 0)
                filename = "%04d-%02d-%02d.pgn".printf (year, month, day);
            else
                filename = "%04d-%02d-%02d-%d.pgn".printf (year, month, day, version);
            relative_path = Path.build_filename ("%04d".printf (year), "%02d".printf (month), "%02d".printf (day), filename, null);

            file = File.new_for_path (Path.build_filename (history_dir.get_path (), relative_path, null));
            DirUtils.create_with_parents (Path.get_dirname (file.get_path ()), 0755);
            try
            {
                file.create (FileCreateFlags.NONE);
                break;
            }
            catch (Error e)
            {
                if (!(e is IOError.EXISTS))
                    throw e;
            }

            version++;
        }

        Sqlite.Statement statement;
        assert (db.prepare_v2 ("INSERT INTO GameTable (date, path, result) VALUES (0, \"%s\", \"%s\")".printf (relative_path, result), -1, out statement) == Sqlite.OK);
        if (statement.step () != Sqlite.DONE)
            warning ("Failed to insert game into history index: %s", db.errmsg ());

        return file;
    }

    public List<File> get_unfinished ()
    {
        load ();

        List<File> values = null;

        Sqlite.Statement statement;
        var result = db.prepare_v2 ("SELECT path FROM GameTable WHERE result=\"*\"", -1, out statement);
        assert (result == Sqlite.OK);

        while ((result = statement.step ()) == Sqlite.ROW)
        {
            var path = statement.column_text (0);
            debug ("%s is unfinished", path);
            values.append (File.new_for_path (Path.build_filename (history_dir.get_path (), path, null)));
        }

        if (result != Sqlite.DONE)
            warning ("Failed to get unfinished games: %s", db.errmsg ());

        return values;
    }

    private void load ()
    {
        if (loaded)
            return;

        var have_history = history_dir.query_exists ();
        DirUtils.create_with_parents (history_dir.get_path (), 0755);

        /* Open the database */
        if (Sqlite.Database.open_v2 (Path.build_filename (history_dir.get_path (), "index.db"), out db) != Sqlite.OK)
            warning ("Failed to load history index: %s", db.errmsg ());

        /* Create table */
        Sqlite.Statement statement;
        var result = db.prepare_v2 ("CREATE TABLE IF NOT EXISTS GameTable (id INTEGER PRIMARY KEY, date INTEGER, path TEXT, fen TEXT, result TEXT)", -1, out statement);
        assert (result == Sqlite.OK);
        if (statement.step () != Sqlite.DONE)
            warning ("Failed to create game table: %s", db.errmsg ());

        /* Migrate from old settings */
        var old_history_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".gnome2", "glchess", "history", null));
        if (!have_history && old_history_dir.query_exists ())
        {
            debug ("Migrating history from %s to %s", old_history_dir.get_path (), history_dir.get_path ());
            try
            {
                load_history_recursive (old_history_dir, old_history_dir, false);
            }
            catch (Error e)
            {
                warning ("Failed to migrate history: %s", e.message);
            }
        }

        loaded = true;
    }

    private void load_history_recursive (File base_dir, File dir, bool load_files) throws Error
    {
        var children = dir.enumerate_children ("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

        while (true)
        {
            var info = children.next_file ();
            if (info == null)
                return;

            switch (info.get_file_type ())
            {
            case FileType.REGULAR:
                if (!load_files)
                    break;

                var f = File.new_for_path (Path.build_filename (dir.get_path (), info.get_name (), null));
                debug ("Migrating %s", f.get_path ());
                    
                try
                {
                    var pgn = new PGN.from_file (f);
                    var game = pgn.games.nth_data (0);

                    var tokens = game.date.split (".");
                    int year = 0, month = 0, day = 0;
                    if (tokens.length == 3)
                    {
                        year = tokens[0].to_int ();
                        month = tokens[1].to_int ();
                        day = tokens[2].to_int ();
                    }

                    /* Copy file */
                    var new_file = add (year, month, day, game.result);
                    f.copy (new_file, FileCopyFlags.OVERWRITE);
                }
                catch (Error e)
                {
                    warning ("Failed to migrate file: %s", e.message);
                }
                break;
            case FileType.DIRECTORY:
                var path = Path.build_filename (dir.get_path (), info.get_name (), null);
                try
                {
                    load_history_recursive (base_dir, File.new_for_path (path), true);
                }
                catch (Error e)
                {
                    warning ("Couldn't open directory %s: %s", path, e.message);
                }
                break;
            default:
                break;
            }
        }
    }
}
