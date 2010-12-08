/* glu.vapi
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
 
[CCode (lower_case_cprefix ="", cheader_filename="GL/glu.h")]
namespace GLU
{
	// Extensions
	public const GL.GLenum GLU_EXT_object_space_tess;
	public const GL.GLenum GLU_EXT_nurbs_tessellator;
	
	// Version
	public const GL.GLenum GLU_VERSION_1_1;
	public const GL.GLenum GLU_VERSION_1_2;
	public const GL.GLenum GLU_VERSION_1_3;
	
	// StringName
	public const GL.GLenum GLU_VERSION;
	public const GL.GLenum GLU_EXTENSIONS;
	
	// ErrorCode
	public const GL.GLenum GLU_INVALID_ENUM;
	public const GL.GLenum GLU_INVALID_VALUE;
	public const GL.GLenum GLU_OUT_OF_MEMORY;
	public const GL.GLenum GLU_INCOMPATIBLE_GL_VERSION;
	public const GL.GLenum GLU_INVALID_OPERATION;
	
	// NurbsDisplay
	public const GL.GLenum GLU_OUTLINE_POLYGON;
	public const GL.GLenum GLU_OUTLINE_PATCH;
	
	// NurbsCallback
	public const GL.GLenum GLU_NURBS_ERROR;
	public const GL.GLenum GLU_ERROR;
	public const GL.GLenum GLU_NURBS_BEGIN;
	public const GL.GLenum GLU_NURBS_BEGIN_EXT;
	public const GL.GLenum GLU_NURBS_VERTEX;
	public const GL.GLenum GLU_NURBS_VERTEX_EXT;
	public const GL.GLenum GLU_NURBS_NORMAL;
	public const GL.GLenum GLU_NURBS_NORMAL_EXT;
	public const GL.GLenum GLU_NURBS_COLOR;
	public const GL.GLenum GLU_NURBS_COLOR_EXT;
	public const GL.GLenum GLU_NURBS_TEXTURE_COORD;
	public const GL.GLenum GLU_NURBS_TEX_COORD_EXT;
	public const GL.GLenum GLU_NURBS_END;
	public const GL.GLenum GLU_NURBS_END_EXT;
	public const GL.GLenum GLU_NURBS_BEGIN_DATA;
	public const GL.GLenum GLU_NURBS_BEGIN_DATA_EXT;
	public const GL.GLenum GLU_NURBS_VERTEX_DATA;
	public const GL.GLenum GLU_NURBS_VERTEX_DATA_EXT;
	public const GL.GLenum GLU_NURBS_NORMAL_DATA;
	public const GL.GLenum GLU_NURBS_NORMAL_DATA_EXT;
	public const GL.GLenum GLU_NURBS_COLOR_DATA;
	public const GL.GLenum GLU_NURBS_COLOR_DATA_EXT;
	public const GL.GLenum GLU_NURBS_TEXTURE_COORD_DATA;
	public const GL.GLenum GLU_NURBS_TEX_COORD_DATA_EXT;
	public const GL.GLenum GLU_NURBS_END_DATA;
	public const GL.GLenum GLU_NURBS_END_DATA_EXT;
	
	// NurbsError
	public const GL.GLenum GLU_NURBS_ERROR1;
	public const GL.GLenum GLU_NURBS_ERROR2;
	public const GL.GLenum GLU_NURBS_ERROR3;
	public const GL.GLenum GLU_NURBS_ERROR4;
	public const GL.GLenum GLU_NURBS_ERROR5;
	public const GL.GLenum GLU_NURBS_ERROR6;
	public const GL.GLenum GLU_NURBS_ERROR7;
	public const GL.GLenum GLU_NURBS_ERROR8;
	public const GL.GLenum GLU_NURBS_ERROR9;
	public const GL.GLenum GLU_NURBS_ERROR10;
	public const GL.GLenum GLU_NURBS_ERROR11;
	public const GL.GLenum GLU_NURBS_ERROR12;
	public const GL.GLenum GLU_NURBS_ERROR13;
	public const GL.GLenum GLU_NURBS_ERROR14;
	public const GL.GLenum GLU_NURBS_ERROR15;
	public const GL.GLenum GLU_NURBS_ERROR16;
	public const GL.GLenum GLU_NURBS_ERROR17;
	public const GL.GLenum GLU_NURBS_ERROR18;
	public const GL.GLenum GLU_NURBS_ERROR19;
	public const GL.GLenum GLU_NURBS_ERROR20;
	public const GL.GLenum GLU_NURBS_ERROR21;
	public const GL.GLenum GLU_NURBS_ERROR22;
	public const GL.GLenum GLU_NURBS_ERROR23;
	public const GL.GLenum GLU_NURBS_ERROR24;
	public const GL.GLenum GLU_NURBS_ERROR25;
	public const GL.GLenum GLU_NURBS_ERROR26;
	public const GL.GLenum GLU_NURBS_ERROR27;
	public const GL.GLenum GLU_NURBS_ERROR28;
	public const GL.GLenum GLU_NURBS_ERROR29;
	public const GL.GLenum GLU_NURBS_ERROR30;
	public const GL.GLenum GLU_NURBS_ERROR31;
	public const GL.GLenum GLU_NURBS_ERROR32;
	public const GL.GLenum GLU_NURBS_ERROR33;
	public const GL.GLenum GLU_NURBS_ERROR34;
	public const GL.GLenum GLU_NURBS_ERROR35;
	public const GL.GLenum GLU_NURBS_ERROR36;
	public const GL.GLenum GLU_NURBS_ERROR37;
	
	// NurbsProperty
	public const GL.GLenum GLU_AUTO_LOAD_MATRIX;
	public const GL.GLenum GLU_CULLING;
	public const GL.GLenum GLU_SAMPLING_TOLERANCE;
	public const GL.GLenum GLU_DISPLAY_MODE;
	public const GL.GLenum GLU_PARAMETRIC_TOLERANCE;
	public const GL.GLenum GLU_SAMPLING_METHOD;
	public const GL.GLenum GLU_U_STEP;
	public const GL.GLenum GLU_V_STEP;
	public const GL.GLenum GLU_NURBS_MODE;
	public const GL.GLenum GLU_NURBS_MODE_EXT;
	public const GL.GLenum GLU_NURBS_TESSELLATOR;
	public const GL.GLenum GLU_NURBS_TESSELLATOR_EXT;
	public const GL.GLenum GLU_NURBS_RENDERER;
	public const GL.GLenum GLU_NURBS_RENDERER_EXT;
	
	// NurbsSampling
	public const GL.GLenum GLU_OBJECT_PARAMETRIC_ERROR;
	public const GL.GLenum GLU_OBJECT_PARAMETRIC_ERROR_EXT;
	public const GL.GLenum GLU_OBJECT_PATH_LENGTH;
	public const GL.GLenum GLU_OBJECT_PATH_LENGTH_EXT;
	public const GL.GLenum GLU_PATH_LENGTH;
	public const GL.GLenum GLU_PARAMETRIC_ERROR;
	public const GL.GLenum GLU_DOMAIN_DISTANCE;
	
	// NurbsTrim
	public const GL.GLenum GLU_MAP1_TRIM_2;
	public const GL.GLenum GLU_MAP1_TRIM_3;
	
	// QuadricDrawStyle
	public const GL.GLenum GLU_POINT;
	public const GL.GLenum GLU_LINE;
	public const GL.GLenum GLU_FILL;
	public const GL.GLenum GLU_SILHOUETTE;
	
	// QuadricNormal
	public const GL.GLenum GLU_SMOOTH;
	public const GL.GLenum GLU_FLAT;
	public const GL.GLenum GLU_NONE;
	
	// QuadricOrientation
	public const GL.GLenum GLU_OUTSIDE;
	public const GL.GLenum GLU_INSIDE;
	
	// TessCallback
	public const GL.GLenum GLU_TESS_BEGIN;
	public const GL.GLenum GLU_BEGIN;
	public const GL.GLenum GLU_TESS_VERTEX;
	public const GL.GLenum GLU_VERTEX;
	public const GL.GLenum GLU_TESS_END;
	public const GL.GLenum GLU_END;
	public const GL.GLenum GLU_TESS_ERROR;
	public const GL.GLenum GLU_TESS_EDGE_FLAG;
	public const GL.GLenum GLU_EDGE_FLAG;
	public const GL.GLenum GLU_TESS_COMBINE;
	public const GL.GLenum GLU_TESS_BEGIN_DATA;
	public const GL.GLenum GLU_TESS_VERTEX_DATA;
	public const GL.GLenum GLU_TESS_END_DATA;
	public const GL.GLenum GLU_TESS_ERROR_DATA;
	public const GL.GLenum GLU_TESS_EDGE_FLAG_DATA;
	public const GL.GLenum GLU_TESS_COMBINE_DATA;
	
	// TessContour
	public const GL.GLenum GLU_CW;
	public const GL.GLenum GLU_CCW;
	public const GL.GLenum GLU_INTERIOR;
	public const GL.GLenum GLU_EXTERIOR;
	public const GL.GLenum GLU_UNKNOWN;
	
	// TessProperty
	public const GL.GLenum GLU_TESS_WINDING_RULE;
	public const GL.GLenum GLU_TESS_BOUNDARY_ONLY;
	public const GL.GLenum GLU_TESS_TOLERANCE;
	
	// TessError
	public const GL.GLenum GLU_TESS_ERROR1;
	public const GL.GLenum GLU_TESS_ERROR2;
	public const GL.GLenum GLU_TESS_ERROR3;
	public const GL.GLenum GLU_TESS_ERROR4;
	public const GL.GLenum GLU_TESS_ERROR5;
	public const GL.GLenum GLU_TESS_ERROR6;
	public const GL.GLenum GLU_TESS_ERROR7;
	public const GL.GLenum GLU_TESS_ERROR8;
	public const GL.GLenum GLU_TESS_MISSING_BEGIN_POLYGON;
	public const GL.GLenum GLU_TESS_MISSING_BEGIN_CONTOUR;
	public const GL.GLenum GLU_TESS_MISSING_END_POLYGON;
	public const GL.GLenum GLU_TESS_MISSING_END_CONTOUR;
	public const GL.GLenum GLU_TESS_COORD_TOO_LARGE;
	public const GL.GLenum GLU_TESS_NEED_COMBINE_CALLBACK;
	
	// TessWinding
	public const GL.GLenum GLU_TESS_WINDING_ODD;
	public const GL.GLenum GLU_TESS_WINDING_NONZERO;
	public const GL.GLenum GLU_TESS_WINDING_POSITIVE;
	public const GL.GLenum GLU_TESS_WINDING_NEGATIVE;
	public const GL.GLenum GLU_TESS_WINDING_ABS_GEQ_TWO;
	public const GL.GLenum GLU_TESS_MAX_COORD;

	[CCode (cname="_GLUfuncptr", has_target = false)]
	public delegate void GLUfuncptr ();

	[Compact]
	[CCode (cname="GLUnurbsObj", cprefix="glu", free_function="gluDeleteNurbsRenderer")]
	public class Nurbs
	{
		[CCode (cname="gluNewNurbsRenderer")]
		public Nurbs ();

		public void BeginCurve ();
		public void BeginSurface ();
		public void BeginTrim ();
		public void EndCurve ();
		public void EndSurface ();
		public void EndTrim ();
		public void GetNurbsProperty (GL.GLenum property, out GL.GLfloat data);
		public void LoadSamplingMatrices ([CCode (array_length = false)] GL.GLfloat[] model, [CCode (array_length = false)] GL.GLfloat[] perspective, [CCode (array_length = false)] GL.GLint[] view);
		public void NurbsCallback (GL.GLenum which, GLUfuncptr CallBackFunc);
		public void NurbsCallbackData (GL.GLvoid* userData);
		public void NurbsCallbackDataEXT (GL.GLvoid* userData);
		public void NurbsCurve (GL.GLint knotCount, [CCode (array_length = false)] GL.GLfloat[] knots, [CCode (array_length = false)] GL.GLint stride, [CCode (array_length = false)] GL.GLfloat[] control, GL.GLint order, GL.GLenum type);
		public void NurbsProperty (GL.GLenum property, GL.GLfloat @value);
		public void NurbsSurface (GL.GLint sKnotCount, [CCode (array_length = false)] GL.GLfloat[] sKnots, GL.GLint tKnotCount, [CCode (array_length = false)] GL.GLfloat[] tKnots, GL.GLint sStride, GL.GLint tStride, [CCode (array_length = false)] GL.GLfloat[] control, GL.GLint sOrder, GL.GLint tOrder, GL.GLenum type);
		public void PwlCurve (GL.GLint count, [CCode (array_length = false)] GL.GLfloat[] data, GL.GLint stride, GL.GLenum type);
	}
	
	[Compact]
	[CCode (cname="GLUquadricObj", cprefix="glu", free_function="gluDeleteQuadric")]
	public class Quadric
	{
		[CCode (cname="gluNewQuadric")]
		public Quadric ();
		
		public void Cylinder (GL.GLdouble @base, GL.GLdouble top, GL.GLdouble height, GL.GLint slices, GL.GLint stacks);
		public void Disk (GL.GLdouble inner, GL.GLdouble outer, GL.GLint slices, GL.GLint loops);
		public void PartialDisk (GL.GLdouble inner, GL.GLdouble outer, GL.GLint slices, GL.GLint loops, GL.GLdouble start, GL.GLdouble sweep);
		public void Sphere (GL.GLdouble radius, GL.GLint slices, GL.GLint stacks);
		public void QuadricCallback (GL.GLenum which, GLUfuncptr CallBackFunc);
		public void QuadricDrawStyle (GL.GLenum draw);
		public void QuadricNormals (GL.GLenum normal);
		public void QuadricOrientation (GL.GLenum orientation);
		public void QuadricTexture (GL.GLboolean texture);
	}
	
	[Compact]
	[CCode (cname="GLUtesselatorObj", cprefix="glu", free_function="gluDeleteTess")]
	public class Tesselator
	{
		[CCode (cname="gluNewTess")]
		public Tesselator ();

		public void BeginPolygon ();
		public void EndPolygon ();
		public void GetTessProperty (GL.GLenum which, out GL.GLdouble data);
		public void NextContour (GL.GLenum type);
		public void TessBeginContour ();
		public void TessBeginPolygon (GL.GLvoid* data);
		public void TessCallback (GL.GLenum which, GLUfuncptr CallBackFunc);
		public void TessEndContour ();
		public void TessEndPolygon ();
		public void TessNormal (GL.GLdouble valueX, GL.GLdouble valueY, GL.GLdouble valueZ);
		public void TessProperty (GL.GLenum which, GL.GLdouble data);
		public void TessVertex ([CCode (array_length = false)] GL.GLdouble[] location, GL.GLvoid* data);
	}


	public static GL.GLint gluBuild1DMipmapLevels (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLenum format, GL.GLenum type, GL.GLint level, GL.GLint @base, GL.GLint max, void* data);
	public static GL.GLint gluBuild1DMipmaps (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLenum format, GL.GLenum type, void* data);
	public static GL.GLint gluBuild2DMipmapLevels (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLsizei height, GL.GLenum format, GL.GLenum type, GL.GLint level, GL.GLint @base, GL.GLint max, void* data);
	public static GL.GLint gluBuild2DMipmaps (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLsizei height, GL.GLenum format, GL.GLenum type, void* data);
	public static GL.GLint gluBuild3DMipmapLevels (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLsizei height, GL.GLsizei depth, GL.GLenum format, GL.GLenum type, GL.GLint level, GL.GLint @base, GL.GLint max, void* data);
	public static GL.GLint gluBuild3DMipmaps (GL.GLenum target, GL.GLint internalFormat, GL.GLsizei width, GL.GLsizei height, GL.GLsizei depth, GL.GLenum format, GL.GLenum type, void* data);
	public static GL.GLboolean gluCheckExtension (string extName, string extString);
	public static unowned string gluErrorString (GL.GLenum error);
	public static unowned string gluGetString (GL.GLenum name);
	public static void gluLookAt (GL.GLdouble eyeX, GL.GLdouble eyeY, GL.GLdouble eyeZ, GL.GLdouble centerX, GL.GLdouble centerY, GL.GLdouble centerZ, GL.GLdouble upX, GL.GLdouble upY, GL.GLdouble upZ);
	public static void gluOrtho2D (GL.GLdouble left, GL.GLdouble right, GL.GLdouble bottom, GL.GLdouble top);
	public static void gluPerspective (GL.GLdouble fovy, GL.GLdouble aspect, GL.GLdouble zNear, GL.GLdouble zFar);
	public static void gluPickMatrix (GL.GLdouble x, GL.GLdouble y, GL.GLdouble delX, GL.GLdouble delY, [CCode (array_length = false)] GL.GLint[] viewport);
	public static GL.GLint gluProject (GL.GLdouble objX, GL.GLdouble objY, GL.GLdouble objZ, [CCode (array_length = false)] GL.GLdouble[] model, [CCode (array_length = false)] GL.GLdouble[] proj, [CCode (array_length = false)] GL.GLint[] view, out GL.GLdouble winX, out GL.GLdouble winY, out GL.GLdouble winZ);
	public static GL.GLint gluScaleImage (GL.GLenum format, GL.GLsizei wIn, GL.GLsizei hIn, GL.GLenum typeIn, void* dataIn, GL.GLsizei wOut, GL.GLsizei hOut, GL.GLenum typeOut, GL.GLvoid* dataOut);
	public static GL.GLint gluUnProject (GL.GLdouble winX, GL.GLdouble winY, GL.GLdouble winZ, [CCode (array_length = false)] GL.GLdouble[] model, [CCode (array_length = false)] GL.GLdouble[] proj, [CCode (array_length = false)] GL.GLint[] view, out GL.GLdouble objX, out GL.GLdouble objY, out GL.GLdouble objZ);
	public static GL.GLint gluUnProject4 (GL.GLdouble winX, GL.GLdouble winY, GL.GLdouble winZ, GL.GLdouble clipW, [CCode (array_length = false)] GL.GLdouble[] model, [CCode (array_length = false)] GL.GLdouble[] proj, [CCode (array_length = false)] GL.GLint[] view, GL.GLdouble nearVal, GL.GLdouble farVal, out GL.GLdouble objX, out GL.GLdouble objY, out GL.GLdouble objZ, out GL.GLdouble objW);

}

