public class History
{
    private File history_dir;
    private Sqlite.Database db;

    public History (File data_dir)
    {
        history_dir = File.new_for_path (Path.build_filename (data_dir.get_path (), "history", null));

        var have_history = history_dir.query_exists ();
        DirUtils.create_with_parents (history_dir.get_path (), 0755);

        /* Open the database */
        var result = Sqlite.Database.open_v2 (Path.build_filename (history_dir.get_path (), "index.db"), out db);
        if (result != Sqlite.OK)
            warning ("Failed to load history index: %s", db.errmsg ());

        /* Create table */
        Sqlite.Statement statement;
        result = db.prepare_v2 ("CREATE TABLE IF NOT EXISTS GameTable (id INTEGER PRIMARY KEY, date INTEGER, path TEXT, fen TEXT, result TEXT)", -1, out statement);
        assert (result == Sqlite.OK);
        result = statement.step ();
        if (result != Sqlite.DONE)
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
                if (load_files)
                {
                    var f = File.new_for_path (Path.build_filename (dir.get_path (), info.get_name (), null));
                    var relative_path = base_dir.get_relative_path (f);
                    var pgn = new PGN.from_file (f);
                    var game = pgn.games.nth_data (0);
                    if (game != null)
                    {
                        /* Copy file */
                        var new_file = File.new_for_path (Path.build_filename (history_dir.get_path (), relative_path, null));
                        DirUtils.create_with_parents (Path.get_dirname (new_file.get_path ()), 0755);
                        f.copy (new_file, FileCopyFlags.NONE);

                        /* Insert into index */
                        Sqlite.Statement statement;
                        debug ("  Migrating %s", relative_path);
                        var result = db.prepare_v2 ("INSERT INTO GameTable (date, path, result) VALUES (0, \"%s\", \"%s\")".printf (relative_path, game.result), -1, out statement);
                        assert (result == Sqlite.OK);
                        result = statement.step ();
                        if (result != Sqlite.DONE)
                            warning ("Failed to insert game into history index: %s", db.errmsg ());
                    }
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

    public List<string> get_unfinished ()
    {
        List<string> values = null;

        Sqlite.Statement statement;
        var result = db.prepare_v2 ("SELECT path FROM GameTable WHERE result=\"*\"", -1, out statement);
        assert (result == Sqlite.OK);

        while ((result = statement.step ()) == Sqlite.ROW)
        {
            var path = statement.column_text (0);
            debug ("%s is unfinished", path);
            values.append (path);
        }

        if (result != Sqlite.DONE)
            warning ("Failed to get unfinished games: %s", db.errmsg ());

        return values;
    }

    public File get_game_file (string key)
    {
        return File.new_for_path (Path.build_filename (history_dir.get_path(), key, null));
    }
}
