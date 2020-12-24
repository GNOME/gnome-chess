/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2013-2020 Michael Catanzaro
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

[GtkTemplate (ui = "/org/gnome/Chess/ui/preferences.ui")]
public class PreferencesDialog : Gtk.Dialog
{
    private Settings settings;
    private unowned List<AIProfile> ai_profiles;
    private uint save_duration_timeout = 0;

    [GtkChild]
    private unowned Gtk.Box main_box;
    [GtkChild]
    private unowned Gtk.CheckButton show_numbering_check;
    [GtkChild]
    private unowned Gtk.CheckButton show_move_hints_check;
    [GtkChild]
    private unowned Gtk.ComboBox side_combo;
    [GtkChild]
    private unowned Gtk.ComboBox difficulty_combo;
    [GtkChild]
    private unowned Gtk.ComboBox opponent_combo;
    [GtkChild]
    private unowned Gtk.ListStore opponent_model;
    [GtkChild]
    private unowned Gtk.Adjustment duration_adjustment;
    [GtkChild]
    private unowned Gtk.Adjustment timer_increment_adjustment;
    [GtkChild]
    private unowned Gtk.Box custom_duration_box;
    [GtkChild]
    private unowned Gtk.Box timer_increment_box;
    [GtkChild]
    private unowned Gtk.ComboBox custom_duration_units_combo;
    [GtkChild]
    private unowned Gtk.Label timer_increment_label;
    [GtkChild]
    private unowned Gtk.ComboBox timer_increment_units_combo;
    [GtkChild]
    private unowned Gtk.ComboBox clock_type_combo;
    [GtkChild]
    private unowned Gtk.ComboBox duration_combo;
    [GtkChild]
    private unowned Gtk.ComboBox orientation_combo;
    [GtkChild]
    private unowned Gtk.ComboBox move_format_combo;
    [GtkChild]
    private unowned Gtk.ComboBox piece_style_combo;

    public PreferencesDialog (Gtk.Window window, Settings settings, List<AIProfile> ai_profiles)
    {
        transient_for = window;
        modal = true;

        this.settings = settings;
        this.ai_profiles = ai_profiles;

        settings.bind ("show-numbering", show_numbering_check,
                       "active", SettingsBindFlags.DEFAULT);
        settings.bind ("show-move-hints", show_move_hints_check,
                       "active", SettingsBindFlags.DEFAULT);

        side_combo.set_active (settings.get_enum ("play-as"));
        set_combo (difficulty_combo, 1, settings.get_string ("difficulty"));

        var opponent_name = settings.get_string ("opponent");
        if (opponent_name == "human")
            opponent_combo.set_active (0);

        foreach (var p in ai_profiles)
        {
            Gtk.TreeIter iter;
            opponent_model.append (out iter);
            opponent_model.set (iter, 0, p.name, 1, p.name, -1);
            if (p.name == opponent_name || (opponent_name == "" && opponent_combo.active == -1))
                opponent_combo.set_active_iter (iter);
        }

        if (opponent_combo.active == -1)
        {
            opponent_combo.active = 0;
            settings.set_string ("opponent", "human");
        }

        set_duration (settings.get_int ("duration"));

        set_clock_type ((int) ClockType.string_to_enum (settings.get_string ("clock-type")));
        set_timer_increment (settings.get_int ("timer-increment"));

        set_combo (orientation_combo, 1, settings.get_string ("board-side"));
        set_combo (move_format_combo, 1, settings.get_string ("move-format"));
        set_combo (piece_style_combo, 1, settings.get_string ("piece-theme"));

        /* Human vs. human */
        if (opponent_combo.get_active () == 0)
        {
            side_combo.sensitive = false;
            difficulty_combo.sensitive = false;
        }
    }

    ~PreferencesDialog ()
    {
        if (save_duration_timeout != 0)
        {
            Source.remove (save_duration_timeout);
            save_duration_cb ();
        }
    }

    public override void dispose ()
    {
        if (main_box != null)
        {
            main_box.unparent ();
            main_box = null;
        }

        base.dispose ();
    }

    private void set_combo (Gtk.ComboBox combo, int value_index, string value)
    {
        Gtk.TreeIter iter;
        var model = combo.model;
        if (!model.get_iter_first (out iter))
            return;
        do
        {
            string v;
            model.@get (iter, value_index, out v, -1);
            if (v == value)
            {
                combo.set_active_iter (iter);
                return;
            }
        } while (model.iter_next (ref iter));
    }

    private string? get_combo (Gtk.ComboBox combo, int value_index)
    {
        string value;
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return null;
        combo.model.@get (iter, value_index, out value, -1);
        return value;
    }

    [GtkCallback]
    private void side_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int player;
        combo.model.@get (iter, 1, out player, -1);

        settings.set_enum ("play-as", player);
    }

    [GtkCallback]
    private void opponent_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string opponent;
        combo.model.@get (iter, 1, out opponent, -1);
        settings.set_string ("opponent", opponent);
        bool vs_human = (combo.get_active () == 0);
        side_combo.sensitive = !vs_human;
        difficulty_combo.sensitive = !vs_human;
    }

    [GtkCallback]
    private void difficulty_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        string difficulty;
        combo.model.@get (iter, 1, out difficulty, -1);
        settings.set_string ("difficulty", difficulty);
    }

    private void set_clock_type (int clock_type)
    {
        var model = clock_type_combo.model;
        Gtk.TreeIter iter, active_iter_clock_type = {};

        /* Find the largest units that can be used for this value */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int type;
                model.@get (iter, 1, out type, -1);
                if (type == clock_type)
                {
                    active_iter_clock_type = iter;
                }
            } while (model.iter_next (ref iter));
        }

        clock_type_combo.set_active_iter (active_iter_clock_type);
        clock_type_changed_cb (clock_type_combo);
    }

    private void set_timer_increment (int timer_increment)
    {
        int timer_increment_multiplier = 1;

        if (timer_increment >= 60)
        {
            timer_increment_adjustment.value = timer_increment / 60;
            timer_increment_multiplier = 60;
        } else
            timer_increment_adjustment.value = timer_increment;

        var model = timer_increment_units_combo.model;
        Gtk.TreeIter iter, reqd_iter = {};

        /* Find the largest units that can be used for this value */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                if (multiplier == timer_increment_multiplier)
                {
                    reqd_iter = iter;
                }
            } while (model.iter_next (ref iter));
        }

        timer_increment_units_combo.set_active_iter (reqd_iter);
        timer_increment_units_changed_cb (timer_increment_units_combo);
    }

    private void set_duration (int duration, bool simplify = true)
    {
        var model = custom_duration_units_combo.model;
        Gtk.TreeIter iter, max_iter = {};

        /* Find the largest units that can be used for this value */
        int max_multiplier = 0;
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                if (multiplier > max_multiplier && duration % multiplier == 0)
                {
                    max_multiplier = multiplier;
                    max_iter = iter;
                }
            } while (model.iter_next (ref iter));
        }

        /* Set the spin button to the value with the chosen units */
        var value = 0;
        if (max_multiplier > 0)
        {
            value = duration / max_multiplier;
            duration_adjustment.value = value;
            custom_duration_units_combo.set_active_iter (max_iter);
        }

        if (!simplify)
            return;

        model = duration_combo.model;
        if (!model.get_iter_first (out iter))
            return;
        do
        {
            int v;
            model.@get (iter, 1, out v, -1);
            if (v == duration || v == -1)
            {
                duration_combo.set_active_iter (iter);
                custom_duration_box.visible = v == -1;
                return;
            }
        } while (model.iter_next (ref iter));
    }

    private int get_duration ()
    {
        Gtk.TreeIter iter;
        if (duration_combo.get_active_iter (out iter))
        {
            int duration;
            duration_combo.model.@get (iter, 1, out duration, -1);
            if (duration >= 0)
                return duration;
        }

        var magnitude = (int) duration_adjustment.value;
        int multiplier = 1;
        if (custom_duration_units_combo.get_active_iter (out iter))
            custom_duration_units_combo.model.@get (iter, 1, out multiplier, -1);

        switch (multiplier)
        {
        case 60:
            if (duration_adjustment.get_upper () != 600)
                duration_adjustment.set_upper (600);
            break;
        case 3600:
            if (duration_adjustment.get_upper () != 10)
            {
                duration_adjustment.set_upper (10);
                if (duration_adjustment.value > 10)
                {
                    duration_adjustment.value = 10;
                    magnitude = 10;
                }
            }
            break;
        default:
            assert_not_reached ();
        }

        return magnitude * multiplier;
    }

    [GtkCallback]
    private void duration_changed_cb (Gtk.Adjustment adjustment)
    {
        var model = (Gtk.ListStore) custom_duration_units_combo.model;
        Gtk.TreeIter iter;
        /* Set the unit labels to the correct plural form */
        if (model.get_iter_first (out iter))
        {
            do
            {
                int multiplier;
                model.@get (iter, 1, out multiplier, -1);
                switch (multiplier)
                {
                case 60:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in minutes */
                                                  "minute", "minutes", (ulong) adjustment.value), -1);
                    break;
                case 3600:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom game timer set in hours */
                                                  "hour", "hours", (ulong) adjustment.value), -1);
                    break;
                default:
                    assert_not_reached ();
                }
            } while (model.iter_next (ref iter));
        }

        save_duration ();
    }

    [GtkCallback]
    private void duration_units_changed_cb (Gtk.Widget widget)
    {
        save_duration ();
    }

    [GtkCallback]
    private void timer_increment_units_changed_cb (Gtk.Widget widget)
    {
        var model = (Gtk.ListStore) timer_increment_units_combo.model;
        Gtk.TreeIter iter;
        int multiplier = 0;
        /* Set the unit labels to the correct plural form */
        if (model.get_iter_first (out iter))
        {
            do
            {
                model.@get (iter, 1, out multiplier, -1);
                switch (multiplier)
                {
                case 1:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom clock type set in seconds */
                                                  "second", "seconds", (ulong) timer_increment_adjustment.value), -1);
                    break;
                case 60:
                    model.set (iter, 0, ngettext (/* Preferences Dialog: Combo box entry for a custom clock type set in minutes */
                                                  "minute", "minutes", (ulong) timer_increment_adjustment.value), -1);
                    break;
                default:
                    assert_not_reached ();
                }
            } while (model.iter_next (ref iter));
        }

        if (timer_increment_units_combo.get_active_iter (out iter))
            timer_increment_units_combo.model.@get (iter, 1, out multiplier, -1);

        switch (multiplier)
        {
        case 1:
            if (timer_increment_adjustment.get_upper () != 59)
                timer_increment_adjustment.set_upper (59);
            break;
        case 60:
            if (timer_increment_adjustment.get_upper () != 10)
            {
                timer_increment_adjustment.set_upper (10);
                if (timer_increment_adjustment.value > 10)
                    timer_increment_adjustment.value = 10;
            }
            break;
        default:
            assert_not_reached ();
        }
        settings.set_int ("timer-increment", (int) timer_increment_adjustment.value * multiplier);
    }

    private bool save_duration_cb ()
    {
        settings.set_int ("duration", get_duration ());
        save_duration_timeout = 0;
        return Source.REMOVE;
    }

    private void save_duration ()
    {
        if (save_duration_timeout != 0)
            Source.remove (save_duration_timeout);

        /* Delay writing the value as this event will be generated a lot spinning through the value */
        save_duration_timeout = Timeout.add (100, save_duration_cb);
    }

    [GtkCallback]
    private void duration_combo_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        int duration;
        combo.model.@get (iter, 1, out duration, -1);
        custom_duration_box.visible = duration < 0;
        clock_type_combo.sensitive = duration != 0;

        if (duration == 0)
            set_clock_type (ClockType.SIMPLE);

        if (duration >= 0)
            set_duration (duration, false);
        /* Default to one hour (30 minutes/player) when setting custom duration */
        else if (get_duration () <= 0)
            set_duration (60 * 60, false);

        save_duration ();
    }

    [GtkCallback]
    private void clock_type_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;
        ClockType clock_type;
        combo.model.@get (iter, 1, out clock_type, -1);

        timer_increment_box.visible = clock_type > 0;
        timer_increment_label.visible = clock_type > 0;
        settings.set_string ("clock-type", clock_type.to_string ());
    }

    [GtkCallback]
    private void piece_style_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("piece-theme", get_combo (combo, 1));
    }

    [GtkCallback]
    private void move_format_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("move-format", get_combo (combo, 1));
    }

    [GtkCallback]
    private void orientation_combo_changed_cb (Gtk.ComboBox combo)
    {
        settings.set_string ("board-side", get_combo (combo, 1));
    }
}
