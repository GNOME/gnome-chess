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

public abstract class ChessEngine : Object
{
    private string binary;
    private string[] args;

    private uint delay_seconds;
    private uint pending_move_source_id;

    private Pid pid = 0;
    private int stdin_fd = -1;
    private int stderr_fd = -1;
    private IOChannel? stdout_channel;
    private uint stdout_watch_id = 0;
    private bool started = false;

    protected virtual void process_input (char[] data) {}

    public signal void starting ();
    public signal void ready_changed ();
    public signal void moved (string move);
    public signal void resigned ();
    public signal void stopped ();
    public signal void error ();
    public signal void claim_draw ();
    public signal void offer_draw ();

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

    public ChessEngine (string binary, string[] args, uint delay_seconds)
    {
        this.binary = binary;
        this.args = args;
        this.delay_seconds = delay_seconds;
    }

    public bool start ()
        requires (pid == 0)
        requires (stdout_watch_id == 0)
        requires (stdin_fd == -1)
        requires (stderr_fd == -1)
        requires (!started)
    {
        string[] argv = {binary};
        foreach (var arg in args)
            argv += arg;
        argv += null;

        int stdout_fd;
        try
        {
            Process.spawn_async_with_pipes (null, argv, null,
                                            SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                                            () => Portability.maybe_kill_orphan_engine (),
                                            out pid, out stdin_fd, out stdout_fd, out stderr_fd);
        }
        catch (SpawnError e)
        {
            warning ("Failed to execute chess engine: %s\n", e.message);
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
            warning ("Failed to set input from chess engine to non-blocking: %s", e.message);
        }
        stdout_channel.set_close_on_unref (true);
        stdout_watch_id = stdout_channel.add_watch (IOCondition.IN, read_cb);

        started = true;
        starting ();

        return true;
    }

    private void engine_stopped_cb (Pid pid, int status)
    {
        // This function could be called because the engine quit on its own, or
        // it could be called because we killed the engine ourselves in
        // ChessEngine.stop(). If it quit on its own, we need to clean up here.
        if (started) {
            stop (false);
            // This signal is only to be emitted when the chess engine stops
            // itself, not when another class calls ChessEngine.stop ().
            stopped ();
        }
    }

    public abstract void start_game ();

    public abstract void report_move (ChessMove move);

    protected abstract void do_undo ();

    protected abstract void request_move ();

    public void move ()
    {
        pending_move_source_id = Timeout.add_seconds (delay_seconds, () => {
            pending_move_source_id = 0;
            request_move ();
            return Source.REMOVE;
        });
    }

    public void undo ()
    {
        if (pending_move_source_id != 0)
        {
            Source.remove (pending_move_source_id);
            pending_move_source_id = 0;
        }

        do_undo ();
    }

    public void stop (bool kill_engine = true)
        requires (!started || stdout_channel != null)
        requires (!started || stdin_fd != -1)
        requires (!started || stderr_fd != -1)
        requires (!started || pid != 0)
    {
        if (!started)
            return;
        started = false;

        // This can be unset on errors in read_cb.
        if (stdout_watch_id != 0)
            Source.remove (stdout_watch_id);

        try
        {
            stdout_channel.shutdown (false);
        }
        catch (IOChannelError e)
        {
            warning ("Failed to close channel to engine's stdout: %s", e.message);
        }
        stdout_channel = null;

        if (FileUtils.close (stdin_fd) == -1)
            warning ("Failed to close pipe to engine's stdin: %s", strerror (errno));
        stdin_fd = -1;

        if (FileUtils.close (stderr_fd) == -1)
            warning ("Failed to close pipe to engine's stderr: %s", strerror (errno));
        stderr_fd = -1;

        if (kill_engine && Posix.kill (pid, Posix.SIGTERM) == -1)
            warning ("Failed to kill engine: %s", strerror (errno));
        Process.close_pid (pid);
        pid = 0;
    }

    private bool read_cb (IOChannel source, IOCondition condition)
        requires (stdout_watch_id != 0)
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
            warning ("Failed to read from engine: %s", e.message);
            stdout_watch_id = 0;
            return false;
        }
        catch (IOChannelError e)
        {
            warning ("Failed to read from engine: %s", e.message);
            stdout_watch_id = 0;
            return false;
        }

        if (status == IOStatus.EOF)
        {
            debug ("EOF");
            stdout_watch_id = 0;
            return false;
        }
        if (status == IOStatus.NORMAL)
        {
            buf.resize ((int) n_read);
            process_input (buf);
        }

        return true;
    }

    protected void write (char[] data)
    {
        size_t offset = 0;
        size_t n_written = 0;

        do
        {
            n_written = Posix.write (stdin_fd, &data[offset], data.length - offset);
            offset += n_written;
        } while (n_written > 0 && offset < data.length);
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
