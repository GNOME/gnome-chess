/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
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
    private uint tick_timeout_id = 0;

    public signal void tick ();
    public signal void expired ();

    private bool is_active = false;

    public ChessClock (int white_initial_seconds, int black_initial_seconds)
    {
        this.white_initial_seconds = white_initial_seconds;
        this.black_initial_seconds = black_initial_seconds;
    }

    public void start ()
    {
        if (is_active)
            return;

        is_active = true;

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

    private bool tick_cb ()
    {
        if (active_color == Color.WHITE)
            white_seconds_used++;
        else
            black_seconds_used++;

        tick ();

        if (white_seconds_used >= white_initial_seconds ||
            black_seconds_used >= black_initial_seconds)
        {
            stop ();
            expired ();
        }

        return true;
    }

    public void stop ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_watching_timer ();
        is_active = false;
    }

    public void pause ()
    {
        if (!is_active)
            return;

        timer.stop ();
        stop_watching_timer ();
	is_active = false;
    }

    public void unpause ()
    {
        if (timer == null || is_active)
            return;

        timer.@continue ();
        watch_timer ();
	is_active = true;
    }

    private void watch_timer ()
    {
        /* Wake up each second */
        tick_timeout_id = Timeout.add (1000, tick_cb);
    }

    private void stop_watching_timer ()
    {
        Source.remove (tick_timeout_id);
        tick_timeout_id = 0;
    }
}
