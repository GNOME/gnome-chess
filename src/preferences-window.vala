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

[GtkTemplate (ui = "/org/gnome/Chess/ui/preferences-window.ui")]
public class PreferencesWindow : Adw.PreferencesWindow
{
    private Preferences preferences;

    [GtkChild]
    private unowned Adw.ComboRow board_orientation_combo;
    [GtkChild]
    private unowned Adw.ComboRow move_format_combo;
    [GtkChild]
    private unowned Adw.ComboRow piece_style_combo;
    [GtkChild]
    private unowned Gtk.Switch board_numbering_switch;
    [GtkChild]
    private unowned Gtk.Switch move_hints_switch;

    public PreferencesWindow (Gtk.Window window, Preferences preferences)
    {
        transient_for = window;
        this.preferences = preferences;

        preferences.bind_property ("show-board-numbering", board_numbering_switch, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
        preferences.bind_property ("show-move-hints", move_hints_switch, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
        preferences.bind_property ("piece-style", piece_style_combo, "selected", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
        preferences.bind_property ("move-format", move_format_combo, "selected", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
        preferences.bind_property ("board-orientation", board_orientation_combo, "selected", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE, null, null);
    }
    
    [GtkCallback]
    private string board_orientation_display_name_cb (Adw.EnumListItem item)
    {
        var value = (BoardOrientation) item.value;
        return value.display_name ();
    }
    
    [GtkCallback]
    private string move_format_display_name_cb (Adw.EnumListItem item)
    {
        var value = (MoveFormat) item.value;
        return value.display_name ();
    }

    [GtkCallback]
    private string piece_style_display_name_cb (Adw.EnumListItem item)
    {
        var value = (PieceStyle) item.value;
        return value.display_name ();
    }
}
