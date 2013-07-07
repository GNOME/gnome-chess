/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class ChessClock : Object
{
    private uint _white_duration;
    public uint white_duration
    {
        get { return _white_duration; }
    }
    private uint _black_duration;
    public uint black_duration
    {
        get { return _black_duration; }
    }

    private uint _white_used;
    public uint white_used
    {
        get
        {
            if (timer == null)
                return 0;
            else if (active_color == Color.WHITE)
                return _white_used + (uint) (timer.elapsed () * 1000);
            else
                return _white_used;
        }
    }

    public uint white_used_in_seconds
    {
        get { return (white_used + 500) / 1000; }
    }

    private uint _black_used;
    public uint black_used
    {
        get
        {
            if (timer == null)
                return 0;
            else if (active_color == Color.WHITE)
                return _black_used;
            else
                return _black_used + (uint) (timer.elapsed () * 1000);
        }
    }

    public uint black_used_in_seconds
    {
        get { return (black_used + 500) / 1000; }
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
    private uint expire_timeout = 0;
    private uint tick_timeout = 0;

    public signal void tick ();
    public signal void expired ();

    public ChessClock (uint white_duration, uint black_duration, uint white_used = 0, uint black_used = 0)
    {
        _white_duration = white_duration * 1000;
        _black_duration = black_duration * 1000;
        _white_used = white_used;
        _black_used = black_used;
    }
    
    private bool is_started
    {
        get { return expire_timeout != 0; }
    }
    
    public void start ()
    {
        if (is_started)
            return;

        if (timer == null)
        {
            /* Starts automatically */
            timer = new Timer ();
        }
        else
            timer.start ();

        /* Notify when this timer has expired */
        if (active_color == Color.WHITE)
            expire_timeout = Timeout.add (white_duration - _white_used, timer_expired_cb);
        else
            expire_timeout = Timeout.add (black_duration - _black_used, timer_expired_cb);

        /* Wake up each second */
        tick_cb ();
    }

    private bool timer_expired_cb ()
    {
        stop ();
        expired ();
        return false;
    }

    private bool tick_cb ()
    {
        if (tick_timeout != 0)
            tick ();

        uint elapsed = (uint) (timer.elapsed () * 1000);
        uint used;
        if (active_color == Color.WHITE)
            used = _white_used + elapsed;
        else
            used = _black_used + elapsed;
        var next_tick_time = ((used / 1000) + 1) * 1000;
        tick_timeout = Timeout.add (next_tick_time - used, tick_cb);

        return false;
    }

    public void stop ()
    {
        if (!is_started)
            return;

        timer.stop ();
        Source.remove (expire_timeout);
        expire_timeout = 0;
        Source.remove (tick_timeout);
        tick_timeout = 0;

        var elapsed = (uint) (timer.elapsed () * 1000);
        if (active_color == Color.WHITE)
        {
            _white_used += elapsed;
            if (_white_used > white_duration)
                _white_used = white_duration;
        }
        else
        {
            _black_used += elapsed;
            if (_black_used > black_duration)
                _black_used = black_duration;
        }

        timer.reset ();
    }
}
