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
    private uint _white_initial_ms;
    public uint white_initial_seconds
    {
        get { return ms_to_seconds (_white_initial_ms); }
    }

    private uint _black_initial_ms;
    public uint black_initial_seconds
    {
        get { return ms_to_seconds (_black_initial_ms); }
    }

    private uint _white_ms_used = 0;
    public uint white_seconds_used
    {
        get
        {
            if (timer == null)
                return 0;
            else if (active_color == Color.WHITE)
                return ms_to_seconds (_white_ms_used + (uint) (timer.elapsed () * 1000));
            else
                return ms_to_seconds (_white_ms_used);
        }
    }

    private uint _black_ms_used = 0;
    public uint black_seconds_used
    {
        get
        {
            if (timer == null)
                return 0;
            else if (active_color == Color.WHITE)
                return ms_to_seconds (_black_ms_used);
            else
                return ms_to_seconds (_black_ms_used + (uint) (timer.elapsed () * 1000));
        }
    }

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

    public ChessClock (uint white_initial_seconds, uint black_initial_seconds)
    {
        _white_initial_ms = white_initial_seconds * 1000;
        _black_initial_ms = black_initial_seconds * 1000;
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
        if (tick_timeout_id != 0)
            tick ();

        uint elapsed = (uint) (timer.elapsed () * 1000);
        uint used;
        if (active_color == Color.WHITE)
            used = _white_ms_used + elapsed;
        else
            used = _black_ms_used + elapsed;
        var next_tick_time = ((used / 1000) + 1) * 1000;
        tick_timeout_id = Timeout.add (next_tick_time - used, tick_cb);

        return false;
    }

    public void stop ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_checking_timer ();

        var elapsed = (uint) (timer.elapsed () * 1000);
        if (active_color == Color.WHITE)
        {
            _white_ms_used += elapsed;
            if (_white_ms_used > _white_initial_ms)
                _white_ms_used = _white_initial_ms;
        }
        else
        {
            _black_ms_used += elapsed;
            if (_black_ms_used > _black_initial_ms)
                _black_ms_used = _black_initial_ms;
        }

        timer.reset ();
    }

    public void pause ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_checking_timer ();
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
            expire_timeout_id = Timeout.add (_white_initial_ms - _white_ms_used, timer_expired_cb);
        else
            expire_timeout_id = Timeout.add (_black_initial_ms - _black_ms_used, timer_expired_cb);

        /* Wake up each second */
        tick_cb ();
    }

    private void stop_checking_timer ()
    {
        Source.remove (expire_timeout_id);
        expire_timeout_id = 0;
        Source.remove (tick_timeout_id);
        tick_timeout_id = 0;
    }

    private uint ms_to_seconds (uint ms)
    {
        return (ms + 500) / 1000;
    }
}
