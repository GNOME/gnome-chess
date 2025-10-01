/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2022 Nils Lück
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

[GtkTemplate (ui = "/org/gnome/Chess/ui/new-game-dialog.ui")]
public class NewGameDialog : Adw.PreferencesDialog
{
    private bool syncing_time_limit = false;
    private Preferences preferences;
    private unowned List<AIProfile> ai_profiles;
    private List<Opponent> opponents = new List<Opponent> ();

    public signal void new_game_requested ();

    [GtkChild]
    private unowned Adw.ComboRow play_as_combo;
    [GtkChild]
    private unowned Adw.ComboRow difficulty_combo;
    [GtkChild]
    private unowned Adw.ComboRow opponent_combo;
    [GtkChild]
    private unowned Adw.ComboRow clock_type_combo;
    [GtkChild]
    private unowned Gtk.SpinButton duration_spin;
    [GtkChild]
    private unowned Gtk.SpinButton increment_spin;
    [GtkChild]
    private unowned Gtk.Switch time_limit_switch;

    public NewGameDialog (Preferences preferences, List<AIProfile> ai_profiles)
    {
        this.preferences = preferences;
        this.ai_profiles = ai_profiles;
        initialize_opponents (ai_profiles);

        preferences.bind_property ("play-as", play_as_combo, "selected", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
        preferences.bind_property ("difficulty", difficulty_combo, "selected", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);

        preferences.bind_property (
            "opponent",
            opponent_combo,
            "selected",
            BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE,
            (binding, from_value, ref to_value) =>
            {
                var opponent = (Opponent) from_value.get_object ();
                var position = get_opponent_index (opponent);
                to_value.set_uint (position);
                return true;
            },
            (binding, from_value, ref to_value) =>
            {
                var position = from_value.get_uint ();
                to_value.set_object (opponents.nth_data (position));
                return true;
            });

        time_limit_settings_changed_cb ();
        time_limit_switch.notify["active"].connect (time_limit_controls_changed_cb);
        clock_type_combo.notify["selected"].connect (time_limit_controls_changed_cb);
        duration_spin.value_changed.connect (time_limit_controls_changed_cb);
        increment_spin.value_changed.connect (time_limit_controls_changed_cb);
        preferences.notify["time-limit"].connect (time_limit_settings_changed_cb);

        opponent_combo.bind_property (
            "selected",
            difficulty_combo,
            "sensitive",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
            (binding, from_value, ref to_value) =>
            {
                var opponent = opponents.nth_data (from_value.get_uint ());
                to_value.set_boolean (!opponent.is_human);
                return true;
            },
            null);

        opponent_combo.bind_property (
            "selected",
            play_as_combo,
            "sensitive",
            BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE,
            (binding, from_value, ref to_value) =>
            {
                var opponent = opponents.nth_data (from_value.get_uint ());
                to_value.set_boolean (!opponent.is_human);
                return true;
            },
            null);
    }

    [GtkCallback]
    private void start_game_cb ()
    {
        close ();
        new_game_requested ();
    }

    [GtkCallback]
    private string play_as_display_name_cb (Adw.EnumListItem item)
    {
        var value = (PlayAs) item.value;
        return value.display_name ();
    }

    [GtkCallback]
    private string difficulty_display_name_cb (Adw.EnumListItem item)
    {
        var value = (Difficulty) item.value;
        return value.display_name ();
    }

    [GtkCallback]
    private string clock_type_display_name_cb (Adw.EnumListItem item)
    {
        var value = (ClockType) item.value;
        return value.display_name ();
    }

    private void time_limit_settings_changed_cb ()
    {
        if (syncing_time_limit)
            return;
        syncing_time_limit = true;

        if (preferences.time_limit == null)
        {
            time_limit_switch.active = false;
            duration_spin.value = 5;
            increment_spin.value = 0;
            clock_type_combo.selected = (int) ClockType.FISCHER;
        }
        else
        {
            time_limit_switch.active = true;
            duration_spin.value = preferences.time_limit.duration_in_seconds / 60.0;
            increment_spin.value = preferences.time_limit.increment_in_seconds;
            clock_type_combo.selected = (int) preferences.time_limit.clock_type;
        }

        syncing_time_limit = false;
    }

    private void time_limit_controls_changed_cb ()
    {
        if (syncing_time_limit)
            return;
        syncing_time_limit = true;

        if (time_limit_switch.active)
        {
            var duration_in_seconds = (int) duration_spin.value * 60;
            var increment_in_seconds = (int) increment_spin.value;
            var clock_type = (ClockType) clock_type_combo.selected;
            preferences.time_limit = new TimeLimit (duration_in_seconds, increment_in_seconds, clock_type);
        }
        else
            preferences.time_limit = null;

        syncing_time_limit = false;
    }

    private void initialize_opponents (List<AIProfile> ai_profiles)
    {
        opponents.append (Opponent.human);
        foreach (var ai_profile in ai_profiles)
        {
            opponents.append (Opponent.from_ai_profile (ai_profile));
        }
        var opponents_model = new Gtk.StringList (null);
        foreach (var opponent in opponents)
        {
            opponents_model.append(opponent.display_name);
        }
        opponent_combo.model = opponents_model;
    }

    private uint get_opponent_index (Opponent opponent)
    {
        var i = 0;
        foreach (var o in opponents)
        {
            if (opponent.display_name == o.display_name)
                return i;

            // Default opponent means we should select the first available AI.
            if (opponent.is_default_opponent && !o.is_human)
                return i;

            i++;
        }
        return 0;
    }
}
