/* gtkglext-1.0.vapi
 *
 * Copyright (C) 2008  Matias De la Puente
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Matias De la Puente <mfpuente.ar@gmail.com>
 * 	Yu Feng <rainwoodman@gmail.com>
 */

[CCode (lower_case_cprefix="gdk_", cprefix="Gdk")]
namespace Gdk {
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLConfigAttrib
	{
		USE_GL,
		BUFFER_SIZE,
		LEVEL,
		RGBA,
		DOUBLEBUFFER,
		STEREO,
		AUX_BUFFERS,
		RED_SIZE,
		GREEN_SIZE,
		BLUE_SIZE,
		ALPHA_SIZE,
		DEPTH_SIZE,
		STENCIL_SIZE,
		ACCUM_RED_SIZE,
		ACCUM_GREEN_SIZE,
		ACCUM_BLUE_SIZE,
		ACCUM_ALPHA_SIZE,
		CONFIG_CAVEAT,
		X_VISUAL_TYPE,
		TRANSPARENT_TYPE,
		TRANSPARENT_INDEX_VALUE,
		TRANSPARENT_RED_VALUE,
		TRANSPARENT_GREEN_VALUE,
		TRANSPARENT_BLUE_VALUE,
		TRANSPARENT_ALPHA_VALUE,
		DRAWABLE_TYPE,
		RENDER_TYPE,
		X_RENDERABLE,
		FBCONFIG_ID,
		MAX_PBUFFER_WIDTH,
		MAX_PBUFFER_HEIGHT,
		MAX_PBUFFER_PIXELS,
		VISUAL_ID,
		SCREEN,
		SAMPLE_BUFFERS,
		SAMPLES
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLConfigCaveat
	{
		CONFIG_CAVEAT_DONT_CARE,
		CONFIG_CAVEAT_NONE,
		SLOW_CONFIG,
		NON_CONFORMANT_CONFIG
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLVisualType
	{
		VISUAL_TYPE_DONT_CARE,
		TRUE_COLOR,
		DIRECT_COLOR,
		PSEUDO_COLOR,
		STATIC_COLOR,
		GRAY_SCALE,
		STATIC_GRAY
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLTransparentType
	{
		TRANSPARENT_NONE,
		TRANSPARENT_RGB,
		TRANSPARENT_INDEX
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLDrawableTypeMask
	{
		WINDOW_BIT,
		PIXMAP_BIT,
		PBUFFER_BIT
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLRenderTypeMask
	{
		RGBA_BIT,
		COLOR_INDEX_BIT
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLBufferMask
	{
		FRONT_LEFT_BUFFER_BIT,
		FRONT_RIGHT_BUFFER_BIT,
		BACK_LEFT_BUFFER_BIT,
		BACK_RIGHT_BUFFER_BIT,
		AUX_BUFFERS_BIT,
		DEPTH_BUFFER_BIT,
		STENCIL_BUFFER_BIT,
		ACCUM_BUFFER_BIT
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLConfigError
	{
		BAD_SCREEN,
		BAD_ATTRIBUTE,
		NO_EXTENSION,
		BAD_VISUAL,
		BAD_CONTEXT,
		BAD_VALUE,
		BAD_ENUM
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLRenderType
	{
		RGBA_TYPE,
		COLOR_INDEX_TYPE
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLDrawableAttrib
	{
		PRESERVED_CONTENTS,
		LARGEST_PBUFFER,
		WIDTH,
		HEIGHT,
		EVENT_MASK
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLPbufferAttrib
	{
		PBUFFER_PRESERVED_CONTENTS,
		PBUFFER_LARGEST_PBUFFER,
		PBUFFER_HEIGHT,
		PBUFFER_WIDTH
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLEventMask
	{
		PBUFFER_CLOBBER_MASK
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLEventType
	{
		DAMAGED,
		SAVED
	}
	
	[CCode (cprefix="GDK_GL_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLDrawableType
	{
		WINDOW,
		PBUFFER
	}
	
	[CCode (cprefix="GDK_GL_MODE_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public enum GLConfigMode
	{
		RGB,
		RGBA,
		INDEX,
		SINGLE,
		DOUBLE,
		STEREO,
		ALPHA,
		DEPTH,
		STENCIL,
		ACCUM,
		MULTISAMPLE
	}
	
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static const uint GL_SUCCESS;
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static const uint GL_ATTRIB_LIST_NONE;
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static const uint GL_DONT_CARE;
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static const uint GL_NONE;
	
	[CCode (has_target = false)]
	public delegate void GLProc ();

	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static void gl_init ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static bool gl_init_check ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	[CCode (cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public static bool gl_parse_args ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	public static bool gl_query_extension ();
	public static bool gl_query_extension_for_display (Gdk.Display display);
	public static bool gl_query_version (out int major, out int minor);
	public static bool gl_query_version_for_display (Gdk.Display display, out int major, out int minor);
	public static bool gl_query_gl_extension (string extension);
	public static GLProc gl_get_proc_address (string proc_name);
	public static unowned Pango.Font gl_font_use_pango_font (Pango.FontDescription font_desc, int first, int count, int list_base);
	public static unowned Pango.Font gl_font_use_pango_font_for_display (Gdk.Display display, Pango.FontDescription font_desc, int first, int count, int list_base);
		
	[CCode (lower_case_cprefix="gdk_gl_draw_")]
	namespace GLDraw
	{
		public static void cube (bool solid, double size);
		public static void sphere (bool solid, double radius, int slices, int stacks);
		public static void cone (bool solid, double @base, double height, int slices, int stacks);
		public static void torus (bool solid, double inner_radius, double outer_radius, int nsides, int rings);
		public static void tetrahedron  (bool solid);
		public static void octahedron (bool solid);
		public static void dodecahedron (bool solid);
		public static void icosahedron (bool solid);
		public static void teapot (bool solid, double scale);
	}

	public class GLConfig : GLib.Object
	{
		public GLConfig ([CCode (array_length = false)] int[] attrib_list);
		public GLConfig.for_screen (Gdk.Screen screen, [CCode (array_length = false)] int[] attib_list);
		public GLConfig.by_mode (GLConfigMode mode);
		public GLConfig.by_mode_for_screen (Gdk.Screen screen, GLConfigMode mode);
		public unowned Gdk.Screen get_screen ();
		public bool get_attrib (int attribute, out int @value);
		public unowned Gdk.Colormap get_colormap ();
		public unowned Gdk.Visual get_visual ();
		public int get_depth ();
		public int get_layer_plane ();
		public int get_n_aux_buffers ();
		public int get_n_sample_buffers ();
		public bool is_rgba ();
		public bool is_double_buffered ();
		public bool is_stereo ();
		public bool has_alpha ();
		public bool has_depth_buffer ();
		public bool has_stencil_buffer ();
		public bool has_accum_buffer ();
	}
		
	public class GLContext : GLib.Object
	{
		public GLContext (Gdk.GLDrawable gldrawable, Gdk.GLContext share_list, bool direct, int render_type);
		public void destroy ();
		public bool copy (Gdk.GLContext src, ulong mask);
		public unowned Gdk.GLDrawable get_gl_drawable ();
		public unowned Gdk.GLConfig get_gl_config ();
		public unowned Gdk.GLContext get_share_list ();
		public bool is_direct ();
		public int get_render_type ();
		public static unowned Gdk.GLContext get_current ();
	}
		
	public class GLDrawable : GLib.Object
	{
		public bool make_current (Gdk.GLContext  glcontext);
		public bool is_double_buffered ();
		public void swap_buffers ();
		public void wait_gl ();
		public void wait_gdk ();
		public bool gl_begin (Gdk.GLContext glcontext);
		public void gl_end ();
		public unowned Gdk.GLConfig get_gl_config ();
		public void get_size (out int width, out int height);
		public static Gdk.GLDrawable get_current ();
	
		/*public virtual signal Gdk.GLContext create_new_context (Gdk.GLContext share_list, bool direct, int render_type);
		public virtual signal bool make_context_current (Gdk.GLDrawable read, Gdk.GLContext glcontext);
		public virtual signal bool is_double_buffered ();
		public virtual signal void swap_buffers ();
		public virtual signal void wait_gl ();
		public virtual signal void wait_gdk ();
		public virtual signal bool gl_begin (Gdk.GLDrawable read, Gdk.GLContext glcontext);
		public virtual signal void gl_end ();
		public virtual signal Gdk.GLConfig  get_gl_config ();
		public virtual signal void get_size (out int width, out int height);
		*/
	}
	
	public class GLPixmap : Gdk.Drawable
	{
		public GLPixmap (Gdk.GLConfig glconfig, Gdk.Pixmap pixmap, [CCode (array_length = false)] int[] attrib_list);
		public void destroy ();
		public unowned Gdk.Pixmap get_pixmap ();
	}

	[CCode (cprefix="gdk_pixmap_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public class PixmapGL {
		public static unowned Gdk.GLPixmap set_gl_capability (Gdk.Pixmap pixmap, Gdk.GLConfig glconfig, [CCode (array_length = false)] int[] attrib_list);
		public static void unset_gl_capability (Gdk.Pixmap pixmap);
		public static bool is_gl_capable (Gdk.Pixmap pixmap);
		public static unowned Gdk.GLPixmap get_gl_pixmap (Gdk.Pixmap pixmap);
		public static unowned Gdk.GLDrawable get_gl_drawable (Gdk.Pixmap pixmap);
	}
	
	public class GLWindow : Gdk.Drawable
	{
		public GLWindow (Gdk.GLConfig glconfig, Gdk.Window window, [CCode (array_length = false)] int[] attrib_list);
		public void destroy ();
		public unowned Gdk.Window get_window ();
	}

	[CCode (cprefix="gdk_window_", cheader_filename="gtkglext-1.0/gdk/gdkgl.h")]
	public class WindowGL {
		public static unowned Gdk.GLWindow set_gl_capability (Gdk.Window window, Gdk.GLConfig glconfig, [CCode (array_length = false)] int[] attrib_list);
		public static void unset_gl_capability (Gdk.Window window);
		public static bool is_gl_capable (Gdk.Window window);
		public static unowned Gdk.GLWindow get_gl_window (Gdk.Window window);
		public static unowned Gdk.GLDrawable get_gl_drawable (Gdk.Window window);
	}
}

[CCode (lower_case_cprefix="gtk_", cprefix="Gtk")]
namespace Gtk
{
	[CCode (cheader_filename="gtkglext-1.0/gtk/gtkgl.h")]
	public static void gl_init ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	[CCode (cheader_filename="gtkglext-1.0/gtk/gtkgl.h")]
	public static bool gl_init_check ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	[CCode (cheader_filename="gtkglext-1.0/gtk/gtkgl.h")]
	public static bool gl_parse_args ([CCode (array_length_pos = 0.9)] ref unowned string[] argv);
	
	[CCode (cprefix="gtk_widget_", cheader_filename="gtkglext-1.0/gtk/gtkgl.h")]
	public class WidgetGL
	{
		public static bool set_gl_capability (Gtk.Widget widget, Gdk.GLConfig glconfig, Gdk.GLContext? share_list, bool direct, int render_type);
		public static bool is_gl_capable (Gtk.Widget widget);
		public static unowned Gdk.GLConfig get_gl_config (Gtk.Widget widget);
		public static unowned Gdk.GLContext create_gl_context (Gtk.Widget widget, Gdk.GLContext share_list, bool direct, int render_type);
		public static unowned Gdk.GLContext get_gl_context (Gtk.Widget widget);
		public static unowned Gdk.GLWindow  get_gl_window (Gtk.Widget widget);
		public static unowned Gdk.GLDrawable get_gl_drawable (Gtk.Widget widget);
		public static bool gl_begin(Gtk.Widget widget) {
			Gdk.GLContext context = get_gl_context(widget);
			Gdk.GLDrawable drawable = get_gl_drawable(widget);
			return drawable.gl_begin(context);
		}
		public static bool gl_swap(Gtk.Widget widget) {
			Gdk.GLDrawable drawable = get_gl_drawable(widget);
			if(drawable.is_double_buffered()) {
				drawable.swap_buffers();
				return true;
			}
			return false;
		}
		public static void gl_end(Gtk.Widget widget) {
			Gdk.GLDrawable drawable = get_gl_drawable(widget);
			drawable.gl_end();
		}
	}
}

