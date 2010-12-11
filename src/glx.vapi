/* glx.vapi
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
 */
 
[CCode (lower_case_cprefix ="", cheader_filename="GL/glx.h")]
namespace GLX
{
	
	public const int GLX_VERSION_1_1;
	public const int GLX_VERSION_1_2;
	public const int GLX_VERSION_1_3;
	public const int GLX_VERSION_1_4;
	public const int GLX_EXTENSION_NAME;
	public const int GLX_USE_GL;
	public const int GLX_BUFFER_SIZE;
	public const int GLX_LEVEL;
	public const int GLX_RGBA;
	public const int GLX_DOUBLEBUFFER;
	public const int GLX_STEREO;
	public const int GLX_AUX_BUFFERS;
	public const int GLX_RED_SIZE;
	public const int GLX_GREEN_SIZE;
	public const int GLX_BLUE_SIZE;
	public const int GLX_ALPHA_SIZE;
	public const int GLX_DEPTH_SIZE;
	public const int GLX_STENCIL_SIZE;
	public const int GLX_ACCUM_RED_SIZE;
	public const int GLX_ACCUM_GREEN_SIZE;
	public const int GLX_ACCUM_BLUE_SIZE;
	public const int GLX_ACCUM_ALPHA_SIZE;
	public const int GLX_BAD_SCREEN;
	public const int GLX_BAD_ATTRIBUTE;
	public const int GLX_NO_EXTENSION;
	public const int GLX_BAD_VISUAL;
	public const int GLX_BAD_CONTEXT;
	public const int GLX_BAD_VALUE;
	public const int GLX_BAD_ENUM;
	public const int GLX_VENDOR;
	public const int GLX_VERSION;
	public const int GLX_EXTENSIONS;
	public const int GLX_CONFIG_CAVEAT;
	public const int GLX_DONT_CARE;
	public const int GLX_X_VISUAL_TYPE;
	public const int GLX_TRANSPARENT_TYPE;
	public const int GLX_TRANSPARENT_INDEX_VALUE;
	public const int GLX_TRANSPARENT_RED_VALUE;
	public const int GLX_TRANSPARENT_GREEN_VALUE;
	public const int GLX_TRANSPARENT_BLUE_VALUE;
	public const int GLX_TRANSPARENT_ALPHA_VALUE;
	public const int GLX_WINDOW_BIT;
	public const int GLX_PIXMAP_BIT;
	public const int GLX_PBUFFER_BIT;
	public const int GLX_AUX_BUFFERS_BIT;
	public const int GLX_FRONT_LEFT_BUFFER_BIT;
	public const int GLX_FRONT_RIGHT_BUFFER_BIT;
	public const int GLX_BACK_LEFT_BUFFER_BIT;
	public const int GLX_BACK_RIGHT_BUFFER_BIT;
	public const int GLX_DEPTH_BUFFER_BIT;
	public const int GLX_STENCIL_BUFFER_BIT;
	public const int GLX_ACCUM_BUFFER_BIT;
	public const int GLX_NONE;
	public const int GLX_SLOW_CONFIG;
	public const int GLX_TRUE_COLOR;
	public const int GLX_DIRECT_COLOR;
	public const int GLX_PSEUDO_COLOR;
	public const int GLX_STATIC_COLOR;
	public const int GLX_GRAY_SCALE;
	public const int GLX_STATIC_GRAY;
	public const int GLX_TRANSPARENT_RGB;
	public const int GLX_TRANSPARENT_INDEX;
	public const int GLX_VISUAL_ID;
	public const int GLX_SCREEN;
	public const int GLX_NON_CONFORMANT_CONFIG;
	public const int GLX_DRAWABLE_TYPE;
	public const int GLX_RENDER_TYPE;
	public const int GLX_X_RENDERABLE;
	public const int GLX_FBCONFIG_ID;
	public const int GLX_RGBA_TYPE;
	public const int GLX_COLOR_INDEX_TYPE;
	public const int GLX_MAX_PBUFFER_WIDTH;
	public const int GLX_MAX_PBUFFER_HEIGHT;
	public const int GLX_MAX_PBUFFER_PIXELS;
	public const int GLX_PRESERVED_CONTENTS;
	public const int GLX_LARGEST_PBUFFER;
	public const int GLX_WIDTH;
	public const int GLX_HEIGHT;
	public const int GLX_EVENT_MASK;
	public const int GLX_DAMAGED;
	public const int GLX_SAVED;
	public const int GLX_WINDOW;
	public const int GLX_PBUFFER;
	public const int GLX_PBUFFER_HEIGHT;
	public const int GLX_PBUFFER_WIDTH;
	public const int GLX_RGBA_BIT;
	public const int GLX_COLOR_INDEX_BIT;
	public const int GLX_PBUFFER_CLOBBER_MASK;
	public const int GLX_SAMPLE_BUFFERS;
	public const int GLX_SAMPLES;

	[SimpleType]
	public struct Context { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct Pixmap { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct Drawable { }
	[SimpleType]
	public struct FBConfig { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct FBConfigID { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct ContextID { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct Window { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct Pbuffer { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct Font { }
	[SimpleType]
	[IntegerType (rank=9)]
	public struct VisualID { }
	
	[Compact]
	[CCode (cname="XVisualInfo", free_function="XFree")]
	public class XVisualInfo
	{
		public uint32 visualid;
		public int screen;
		public int depth;
		public int @class;
		public ulong red_mask;
		public ulong green_mask;
		public ulong blue_mask;
		public int colormap_size;
		public int bits_per_rgb;
	}

	public static XVisualInfo glXChooseVisual (void* dpy, int screen, [CCode (array_length = false)] int[] attribList);
	public static Context glXCreateContext (void* dpy, XVisualInfo vis, Context? shareList, bool direct);
	public static void glXDestroyContext (void* dpy, Context ctx);
	public static bool glXMakeCurrent (void* dpy, Drawable drawable, Context ctx);
	public static void glXCopyContext (void* dpy, Context src, Context dst, ulong mask);
	public static void glXSwapBuffers (void* dpy, Drawable drawable);
	public static Pixmap glXCreateGLXPixmap (void* dpy, XVisualInfo visual, Pixmap pixmap);
	public static void glXDestroyGLXPixmap (void* dpy, Pixmap pixmap);
	public static bool glXQueryExtension (void* dpy, out int errorb, out int event);
	public static bool glXQueryVersion (void* dpy, out int maj, out int min);
	public static bool glXIsDirect (void* dpy, Context ctx );
	public static int glXGetConfig (void* dpy, XVisualInfo visual, int attrib, out int @value);
	public static unowned string glXQueryExtensionsString (void* dpy, int screen);
	public static unowned string glXQueryServerString (void* dpy, int screen, int name);
	public static unowned string glXGetClientString (void* dpy, int name);
	public static void* glXGetCurrentDisplay (void* dpy);
	public static FBConfig* glXChooseFBConfig (void* dpy, int screen, [CCode (array_length = false)] int[] attribList, out int nitems);
	public static int glXGetFBConfigAttrib (void* dpy, FBConfig config, int attribute, out int @value);
	public static FBConfig glXGetFBConfigs (void* dpy, int screen, out int nelements);
	public static XVisualInfo glXGetVisualFromFBConfig (void* dpy, FBConfig config);
	public static Window glXCreateWindow (void* dpy, FBConfig config, Window win, [CCode (array_length = false)] int[] attribList);
	public static void glXDestroyWindow (void* dpy, Window window);
	public static Pixmap glXCreatePixmap (void* dpy, FBConfig config, Pixmap pixmap, [CCode (array_length = false)] int[] attribList);
	public static void glXDestroyPixmap (void* dpy, Pixmap pixmap);
	public static Pbuffer glXCreatePbuffer (void* dpy, FBConfig config, [CCode (array_length = false)] int[] attribList);
	public static void glXDestroyPbuffer (void* dpy, Pbuffer pbuf);
	public static void glXQueryDrawable (void* dpy, Drawable draw, int attribute, out uint @value);
	public static Context glXCreateNewContext (void* dpy, FBConfig config, int renderType, Context shareList, bool direct);
	public static bool glXMakeContextCurrent (void* dpy, Drawable draw, Drawable read, Context ctx);
	public static int glXQueryContext (void* dpy, Context ctx, int attribute, out int @value);
	public static void glXSelectEvent (void* dpy, Drawable drawable, ulong mask);
	public static void glXGetSelectedEvent (void* dpy, Drawable drawable, out ulong mask);

	public static Context glXGetCurrentContext ();
	public static Drawable glXGetCurrentDrawable ();
	public static void glXWaitGL ();
	public static void glXWaitX ();
	public static void glXUseXFont (Font font, int first, int count, int list);
	public static Drawable glXGetCurrentReadDrawable ();
}

