/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2014 Michael Catanzaro
 * Copyright (C) 2015-2016 Sahil Sareen
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum ClockType
{
    SIMPLE,
    FISCHER,
    BRONSTEIN,
    INVALID;

    public string to_string ()
    {
        switch (this)
        {
        case SIMPLE:
            return "simple";
        case FISCHER:
            return "fischer";
        case BRONSTEIN:
            return "bronstein";
        default:
            assert_not_reached ();
        }
    }

    public static ClockType string_to_enum (string s)
    {
        switch (s)
        {
        case "simple":
            return SIMPLE;
        case "fischer":
            return FISCHER;
        case "bronstein":
            return BRONSTEIN;
        default:
            return INVALID;
        }
    }
}

public class ChessClock : Object
{
    private int white_initial_seconds;
    private int black_initial_seconds;

    private int white_seconds_used = 0;
    private int black_seconds_used = 0;

    private int white_prev_move_seconds = 0;
    private int black_prev_move_seconds = 0;

    private int white_extra_seconds = 0;
    private int black_extra_seconds = 0;

    public int extra_seconds { get; set; default = 0; }

    public int white_remaining_seconds
    {
        get { return white_initial_seconds + white_extra_seconds - white_seconds_used; }
    }

    public int black_remaining_seconds
    {
        get { return black_initial_seconds + black_extra_seconds - black_seconds_used; }
    }

    public ClockType clock_type { get; set; default = ClockType.SIMPLE; }

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

            // This is a move switch
            // Update the clocks for Fischer and Bronstein mode
            update_extra_seconds ();
            update_prev_move_time ();

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

        if (white_seconds_used >= white_initial_seconds + white_extra_seconds ||
            black_seconds_used >= black_initial_seconds + black_extra_seconds)
        {
            stop ();
            expired ();
        }

        return Source.CONTINUE;
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

    public void update_prev_move_time ()
    {
        if (active_color == Color.WHITE)
            black_prev_move_seconds = black_seconds_used;
        else
            white_prev_move_seconds = white_seconds_used;
    }

    private void update_extra_seconds ()
    {
        int white_move_used = 0, black_move_used = 0;
        switch (clock_type)
        {
        case ClockType.SIMPLE:
            break;
        case ClockType.FISCHER:
            if (active_color == Color.WHITE)
                white_extra_seconds += extra_seconds;
            else
                black_extra_seconds += extra_seconds;
            break;
        case ClockType.BRONSTEIN:
            white_move_used = white_seconds_used - white_prev_move_seconds;
            black_move_used = black_seconds_used - black_prev_move_seconds;
            if (active_color != Color.WHITE)
                white_extra_seconds += int.min (extra_seconds, white_move_used);
            else
                black_extra_seconds += int.min (extra_seconds, black_move_used);
            break;
        }
    }
}
