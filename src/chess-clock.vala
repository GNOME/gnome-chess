/*
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class ChessClock : Object
{
    public int white_initial_seconds { get; private set; }

    public int black_initial_seconds { get; private set; }

    public int white_seconds_used { get; private set; default = 0; }

    public int black_seconds_used { get; private set; default = 0; }

    private Color _active_color = Color.WHITE;
    public Color active_color
    {
        get { return _active_color; }
        set
        {
            if (value == active_color)
                return;

            stop ();
            _active_color = value;
            start ();
        }
    }

    private Timer? timer;
    private uint expire_timeout_id = 0;
    private uint tick_timeout_id = 0;

    public signal void tick ();
    public signal void expired ();

    public ChessClock (int white_initial_seconds_seconds, int black_initial_seconds_seconds)
    {
        white_initial_seconds = white_initial_seconds_seconds;
        black_initial_seconds = black_initial_seconds_seconds;
    }

    private bool is_active
    {
        get { return timer != null && expire_timeout_id != 0; }
    }
    
    public void start ()
    {
        if (is_active)
            return;

        if (timer == null)
        {
            /* Starts automatically */
            timer = new Timer ();
        }
        else
        {
            timer.start ();
        }

        watch_timer ();
    }

    private bool timer_expired_cb ()
    {
        stop ();
        expired ();
        return false;
    }

    private bool tick_cb ()
    {
        if (active_color == Color.WHITE)
            white_seconds_used++;
        else
            black_seconds_used++;

        tick ();

        return true;
    }

    public void stop ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_watching_timer ();
    }

    public void pause ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_watching_timer ();
    }

    public void unpause ()
    {
        if (timer == null || is_active)
            return;

        timer.@continue ();
        watch_timer ();
    }

    private void watch_timer ()
    {
        /* Notify when this timer has expired */
        if (active_color == Color.WHITE)
            expire_timeout_id = Timeout.add_seconds (white_initial_seconds - white_seconds_used,
                                                     timer_expired_cb);
        else
            expire_timeout_id = Timeout.add_seconds (black_initial_seconds - black_seconds_used,
                                                     timer_expired_cb);

        /* Wake up each second */
        tick_timeout_id = Timeout.add_seconds (1, tick_cb);
    }

    private void stop_watching_timer ()
    {
        Source.remove (expire_timeout_id);
        expire_timeout_id = 0;
        Source.remove (tick_timeout_id);
        tick_timeout_id = 0;
    }
}
