public class ChessEngine : GLib.Object
{
    public string binary;
    private GLib.Pid pid;
    private int stdin_fd;
    private int stderr_fd;
    private GLib.IOChannel stdout_channel;

    protected virtual void process_input (char[] data) {}

    public signal void starting ();
    public signal void ready_changed ();
    public signal void moved (string move);
    public signal void resigned ();
    public signal void stopped ();
    
    private bool _ready = false;
    public bool ready
    {
        protected set
        {
           _ready = value;
           ready_changed ();
        }
        public get
        {
            return _ready;
        }
    }
    
    public bool start ()
    {
        string[] argv = { binary, null };
        int stdout_fd;
        try
        {
            GLib.Process.spawn_async_with_pipes (null, argv, null,
                                                 GLib.SpawnFlags.SEARCH_PATH,
                                                 null,
                                                 out pid, out stdin_fd, out stdout_fd, out stderr_fd);
        }
        catch (GLib.SpawnError e)
        {
            stderr.printf ("Failed to execute chess engine: %s\n", e.message);
            return false;
        }

        stdout_channel = new GLib.IOChannel.unix_new (stdout_fd);
        try
        {
            stdout_channel.set_flags (GLib.IOFlags.NONBLOCK);
        }
        catch (GLib.IOChannelError e)
        {
            stderr.printf ("Failed to set input from chess engine to non-blocking: %s", e.message);
        }
        stdout_channel.add_watch (GLib.IOCondition.IN, read_cb);

        starting ();

        return true;
    }
    
    public virtual void start_game ()
    {
    }

    public virtual void request_move ()
    {
    }

    public virtual void report_move (ChessMove move)
    {
    }

    public void stop ()
    {
        // FIXME
        stopped ();
    }

    private bool read_cb (GLib.IOChannel source, GLib.IOCondition condition)
    {
        char[] buf;
        size_t n_read;
        GLib.IOStatus status;

        buf = new char[1024];
        try
        {
            status = source.read_chars (buf, out n_read);
        }
        catch (GLib.ConvertError e)
        {
            return false;
        }
        catch (GLib.IOChannelError e)
        {
            return false;
        }

        if (status == GLib.IOStatus.EOF)
        {
            stdout.printf ("EOF\n");
            return false;
        }
        if (status == GLib.IOStatus.NORMAL)
        {
            //GLib.debug ("Read %zu octets from engine", n_read);
            buf.resize ((int) n_read);
            process_input (buf);
        }

        return true;
    }

    protected void write (char[] data)
    {
        size_t offset = 0;
        size_t n_written;
        
        while (offset < data.length)
        {
            /* Unnecessary copying but there seems to be a vala bug here */
            char[] d = new char[data.length - offset];
            for (int i = 0; i < data.length - offset; i++)
                d[i] = data[offset + i];

            n_written = Posix.write(stdin_fd, d, d.length);
            if (n_written < 0)
                return;

            //GLib.debug ("Wrote %zu octets to engine", n_written);

            offset += n_written;
        }
    }

    protected void write_line (string line)
    {
        string l = line + "\n";
        GLib.debug ("Writing line to engine: '%s'", line);
        char[] d = l.to_utf8 ();
        if (d != null)
            write (d);
    }
}
