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

[GtkTemplate (ui = "/org/gnome/Chess/ui/promotion-type-selector.ui")]
public class PromotionTypeSelectorDialog : Adw.Dialog
{
    public enum SelectedType
    {
        QUEEN,
        KNIGHT,
        ROOK,
        BISHOP
    }

    [GtkChild]
    private unowned Gtk.Image queen_image;
    [GtkChild]
    private unowned Gtk.Image knight_image;
    [GtkChild]
    private unowned Gtk.Image rook_image;
    [GtkChild]
    private unowned Gtk.Image bishop_image;

    public signal void piece_selected (SelectedType type);

    public PromotionTypeSelectorDialog (Color color, string theme)
    {
        var color_string = color == Color.WHITE ? "white" : "black";
        var resource_path = Path.build_path ("/", "/org/gnome/Chess/pieces", theme, "%sQueen.svg".printf (color_string));
        set_piece_image (queen_image, resource_path);

        resource_path = Path.build_path ("/", "/org/gnome/Chess/pieces", theme, "%sKnight.svg".printf (color_string));
        set_piece_image (knight_image, resource_path);

        resource_path = Path.build_path ("/", "/org/gnome/Chess/pieces", theme, "%sRook.svg".printf (color_string));
        set_piece_image (rook_image, resource_path);

        resource_path = Path.build_path ("/", "/org/gnome/Chess/pieces", theme, "%sBishop.svg".printf (color_string));
        set_piece_image (bishop_image, resource_path);
    }

    private void set_piece_image (Gtk.Image image, string resource_path)
    {
        const int size = 48;

        try
        {
            var stream = resources_open_stream (resource_path, ResourceLookupFlags.NONE);
            var h = new Rsvg.Handle.from_stream_sync (stream, null, Rsvg.HandleFlags.FLAGS_NONE, null);

            var s = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
            var c = new Cairo.Context (s);
            h.render_document (c, Rsvg.Rectangle () { width = size, height = size, x = 0, y = 0 });

            var p = create_texture_for_surface (s);
            image.set_from_paintable (p);

            image.height_request = size;
        }
        catch (Error e)
        {
            warning ("Failed to load piece image %s: %s", resource_path, e.message);
        }
    }

    private static Gdk.Texture create_texture_for_surface (Cairo.ImageSurface surface)
        requires (surface.get_type () == Cairo.SurfaceType.IMAGE)
        requires (surface.get_width () > 0)
        requires (surface.get_height () > 0)
        requires (BYTE_ORDER == ByteOrder.LITTLE_ENDIAN || BYTE_ORDER == ByteOrder.BIG_ENDIAN)
    {
        unowned uchar[] data = surface.get_data ();
        data.length = surface.get_height () * surface.get_stride ();
        return new Gdk.MemoryTexture (surface.get_width (),
                                      surface.get_height (),
                                      BYTE_ORDER == ByteOrder.LITTLE_ENDIAN ? Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED : Gdk.MemoryFormat.A8R8G8B8_PREMULTIPLIED,
                                      new Bytes (data),
                                      surface.get_stride ());
    }

    [GtkCallback]
    private void queen_selected_cb (Gtk.Button button)
    {
        piece_selected (SelectedType.QUEEN);
    }

    [GtkCallback]
    private void knight_selected_cb (Gtk.Button button)
    {
        piece_selected (SelectedType.KNIGHT);
    }

    [GtkCallback]
    private void rook_selected_cb (Gtk.Button button)
    {
        piece_selected (SelectedType.ROOK);
    }

    [GtkCallback]
    private void bishop_selected_cb (Gtk.Button button)
    {
        piece_selected (SelectedType.BISHOP);
    }
}
