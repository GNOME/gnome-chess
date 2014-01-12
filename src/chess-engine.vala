public class ChessEngine : Object
{
    public string binary;
    public string args;

    private Pid pid;
    private int stdin_fd;
    private int stderr_fd;
    private IOChannel stdout_channel;
    private uint stdout_watch_id;
    private bool started = false;

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
        string[] argv = { binary, args, null };
        int stdout_fd;
        try
        {
            Process.spawn_async_with_pipes (null, argv, null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
#if HAVE_LINUX_PRCTL_H
                                            () => Prctl.prctl (Prctl.SET_PDEATHSIG, Posix.SIGTERM),
#else
                                            null,
#endif
                                            out pid, out stdin_fd, out stdout_fd, out stderr_fd);
        }
        catch (SpawnError e)
        {
            stderr.printf ("Failed to execute chess engine: %s\n", e.message);
            return false;
        }

        ChildWatch.add (pid, engine_stopped_cb);

        stdout_channel = new IOChannel.unix_new (stdout_fd);
        try
        {
            stdout_channel.set_flags (IOFlags.NONBLOCK);
        }
        catch (IOChannelError e)
        {
            stderr.printf ("Failed to set input from chess engine to non-blocking: %s", e.message);
        }
        stdout_channel.set_close_on_unref (true);
        stdout_watch_id = stdout_channel.add_watch (IOCondition.IN, read_cb);

        started = true;
        starting ();

        return true;
    }

    private void engine_stopped_cb (Pid pid, int status)
    {
        Process.close_pid (pid);
        stopped ();
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

    public virtual void undo ()
    {
    }

    public void stop ()
    {
        if (!started)
            return;

        Source.remove (stdout_watch_id);

        try
        {
            stdout_channel.shutdown (false);
        }
        catch (IOChannelError e)
        {
            warning ("Failed to close channel to engine's stdout: %s", e.message);
        }

        if (FileUtils.close (stdin_fd) == -1)
            warning ("Failed to close pipe to engine's stdin: %s",
                     strerror (errno));

        if (FileUtils.close (stderr_fd) == -1)
            warning ("Failed to close pipe to engine's stderr: %s",
                     strerror (errno));

        if (Posix.kill (pid, Posix.SIGTERM) == -1)
            warning ("Failed to kill engine: %s", strerror (errno));

        started = false;
    }

    private bool read_cb (IOChannel source, IOCondition condition)
    {
        char[] buf;
        size_t n_read;
        IOStatus status;

        buf = new char[1024];
        try
        {
            status = source.read_chars (buf, out n_read);
        }
        catch (ConvertError e)
        {
            return false;
        }
        catch (IOChannelError e)
        {
            return false;
        }

        if (status == IOStatus.EOF)
        {
            stdout.printf ("EOF\n");
            return false;
        }
        if (status == IOStatus.NORMAL)
        {
            //debug ("Read %zu octets from engine", n_read);
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

            //debug ("Wrote %zu octets to engine", n_written);

            offset += n_written;
        }
    }

    protected void write_line (string line)
    {
        string l = line + "\n";
        debug ("Writing line to engine: '%s'", line);
        char[] d = l.to_utf8 ();
        if (d != null)
            write (d);
    }
}
