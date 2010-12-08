/* gl.vapi
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
 
[CCode (lower_case_cprefix ="", cheader_filename="GL/gl.h")]
namespace GL
{
	[CCode (cname="GLenum")]
	public struct GLenum : uint { }
	[CCode (cname="GLboolean")]
	public struct GLboolean : bool { }
	[CCode (cname="GLbitfield")]
	public struct GLbitfield : uint { }
	[CCode (cname="GLvoid")]
	public struct GLvoid { }
	[CCode (cname="GLbyte")]
	public struct GLbyte : char { }
	[CCode (cname="GLshort")]
	public struct GLshort : short { }
	[CCode (cname="GLint")]
	public struct GLint : int { }
	[CCode (cname="GLubyte")]
	public struct GLubyte : uchar { }
	[CCode (cname="GLushort")]
	public struct GLushort : ushort { }
	[CCode (cname="GLuint")]
	public struct GLuint : uint { }
	[CCode (cname="GLsizei")]
	public struct GLsizei : int { }
	[CCode (cname="GLfloat")]
	[FloatingType (rank = 1)]
	public struct GLfloat : float { }
	[CCode (cname="GLclampf")]
	[FloatingType (rank = 1)]
	public struct GLclampf : float { }
	[CCode (cname="GLdouble")]
	[FloatingType (rank = 2)]
	public struct GLdouble : double { }
	[CCode (cname="GLclampd")]
	[FloatingType (rank = 2)]
	public struct GLclampd : double { }
	
	
	// Data Types
	public const GLenum GL_BYTE;
	public const GLenum GL_UNSIGNED_BYTE;
	public const GLenum GL_SHORT;
	public const GLenum GL_UNSIGNED_SHORT;
	public const GLenum GL_INT;
	public const GLenum GL_UNSIGNED_INT;
	public const GLenum GL_FLOAT;
	public const GLenum GL_2_BYTES;
	public const GLenum GL_3_BYTES;
	public const GLenum GL_4_BYTES;
	public const GLenum GL_DOUBLE;
	
	// Primitives
	public const GLenum GL_POINTS;
	public const GLenum GL_LINES;
	public const GLenum GL_LINE_LOOP;
	public const GLenum GL_LINE_STRIP;
	public const GLenum GL_TRIANGLES;
	public const GLenum GL_TRIANGLE_STRIP;
	public const GLenum GL_TRIANGLE_FAN;
	public const GLenum GL_QUADS;
	public const GLenum GL_QUAD_STRIP;
	public const GLenum GL_POLYGON;
	
	// Vertex Arrays
	public const GLenum GL_VERTEX_ARRAY;
	public const GLenum GL_NORMAL_ARRAY;
	public const GLenum GL_COLOR_ARRAY;
	public const GLenum GL_INDEX_ARRAY;
	public const GLenum GL_TEXTURE_COORD_ARRAY;
	public const GLenum GL_EDGE_FLAG_ARRAY;
	public const GLenum GL_VERTEX_ARRAY_SIZE;
	public const GLenum GL_VERTEX_ARRAY_TYPE;
	public const GLenum GL_VERTEX_ARRAY_STRIDE;
	public const GLenum GL_NORMAL_ARRAY_TYPE;
	public const GLenum GL_NORMAL_ARRAY_STRIDE;
	public const GLenum GL_COLOR_ARRAY_SIZE;
	public const GLenum GL_COLOR_ARRAY_TYPE;
	public const GLenum GL_COLOR_ARRAY_STRIDE;
	public const GLenum GL_INDEX_ARRAY_TYPE;
	public const GLenum GL_INDEX_ARRAY_STRIDE;
	public const GLenum GL_TEXTURE_COORD_ARRAY_SIZE;
	public const GLenum GL_TEXTURE_COORD_ARRAY_TYPE;
	public const GLenum GL_TEXTURE_COORD_ARRAY_STRIDE;
	public const GLenum GL_EDGE_FLAG_ARRAY_STRIDE;
	public const GLenum GL_VERTEX_ARRAY_POINTER;
	public const GLenum GL_NORMAL_ARRAY_POINTER;
	public const GLenum GL_COLOR_ARRAY_POINTER;
	public const GLenum GL_INDEX_ARRAY_POINTER;
	public const GLenum GL_TEXTURE_COORD_ARRAY_POINTER;
	public const GLenum GL_EDGE_FLAG_ARRAY_POINTER;
	public const GLenum GL_V2F;
	public const GLenum GL_V3F;
	public const GLenum GL_C4UB_V2F;
	public const GLenum GL_C4UB_V3F;
	public const GLenum GL_C3F_V3F;
	public const GLenum GL_N3F_V3F;
	public const GLenum GL_C4F_N3F_V3F;
	public const GLenum GL_T2F_V3F;
	public const GLenum GL_T4F_V4F;
	public const GLenum GL_T2F_C4UB_V3F;
	public const GLenum GL_T2F_C3F_V3F;
	public const GLenum GL_T2F_N3F_V3F;
	public const GLenum GL_T2F_C4F_N3F_V3F;
	public const GLenum GL_T4F_C4F_N3F_V4F;
	
	// Matrix Mode
	public const GLenum GL_MATRIX_MODE;
	public const GLenum GL_MODELVIEW;
	public const GLenum GL_PROJECTION;
	public const GLenum GL_TEXTURE;
	
	// Points
	public const GLenum GL_POINT_SMOOTH;
	public const GLenum GL_POINT_SIZE;
	public const GLenum GL_POINT_SIZE_GRANULARITY;
	public const GLenum GL_POINT_SIZE_RANGE;
	
	// Lines
	public const GLenum GL_LINE_SMOOTH;
	public const GLenum GL_LINE_STIPPLE;
	public const GLenum GL_LINE_STIPPLE_PATTERN;
	public const GLenum GL_LINE_STIPPLE_REPEAT;
	public const GLenum GL_LINE_WIDTH;
	public const GLenum GL_LINE_WIDTH_GRANULARITY;
	public const GLenum GL_LINE_WIDTH_RANGE;
	
	// Polygons
	public const GLenum GL_POINT;
	public const GLenum GL_LINE;
	public const GLenum GL_FILL;
	public const GLenum GL_CW;
	public const GLenum GL_CCW;
	public const GLenum GL_FRONT;
	public const GLenum GL_BACK;
	public const GLenum GL_POLYGON_MODE;
	public const GLenum GL_POLYGON_SMOOTH;
	public const GLenum GL_POLYGON_STIPPLE;
	public const GLenum GL_EDGE_FLAG;
	public const GLenum GL_CULL_FACE;
	public const GLenum GL_CULL_FACE_MODE;
	public const GLenum GL_FRONT_FACE;
	public const GLenum GL_POLYGON_OFFSET_FACTOR;
	public const GLenum GL_POLYGON_OFFSET_UNITS;
	public const GLenum GL_POLYGON_OFFSET_POINT;
	public const GLenum GL_POLYGON_OFFSET_LINE;
	public const GLenum GL_POLYGON_OFFSET_FILL;
	
	// Display Lists
	public const GLenum GL_COMPILE;
	public const GLenum GL_COMPILE_AND_EXECUTE;
	public const GLenum GL_LIST_BASE;
	public const GLenum GL_LIST_INDEX;
	public const GLenum GL_LIST_MODE;
	
	// Depth Buffer
	public const GLenum GL_NEVER;
	public const GLenum GL_LESS;
	public const GLenum GL_EQUAL;
	public const GLenum GL_LEQUAL;
	public const GLenum GL_GREATER;
	public const GLenum GL_NOTEQUAL;
	public const GLenum GL_GEQUAL;
	public const GLenum GL_ALWAYS;
	public const GLenum GL_DEPTH_TEST;
	public const GLenum GL_DEPTH_BITS;
	public const GLenum GL_DEPTH_CLEAR_VALUE;
	public const GLenum GL_DEPTH_FUNC;
	public const GLenum GL_DEPTH_RANGE;
	public const GLenum GL_DEPTH_WRITEMASK;
	public const GLenum GL_DEPTH_COMPONENT;
	
	// Lighting
	public const GLenum GL_LIGHTING;
	public const GLenum GL_LIGHT0;
	public const GLenum GL_LIGHT1;
	public const GLenum GL_LIGHT2;
	public const GLenum GL_LIGHT3;
	public const GLenum GL_LIGHT4;
	public const GLenum GL_LIGHT5;
	public const GLenum GL_LIGHT6;
	public const GLenum GL_LIGHT7;
	public const GLenum GL_SPOT_EXPONENT;
	public const GLenum GL_SPOT_CUTOFF;
	public const GLenum GL_CONSTANT_ATTENUATION;
	public const GLenum GL_LINEAR_ATTENUATION;
	public const GLenum GL_QUADRATIC_ATTENUATION;
	public const GLenum GL_AMBIENT;
	public const GLenum GL_DIFFUSE;
	public const GLenum GL_SPECULAR;
	public const GLenum GL_SHININESS;
	public const GLenum GL_EMISSION;
	public const GLenum GL_POSITION;
	public const GLenum GL_SPOT_DIRECTION;
	public const GLenum GL_AMBIENT_AND_DIFFUSE;
	public const GLenum GL_COLOR_INDEXES;
	public const GLenum GL_LIGHT_MODEL_TWO_SIDE;
	public const GLenum GL_LIGHT_MODEL_LOCAL_VIEWER;
	public const GLenum GL_LIGHT_MODEL_AMBIENT;
	public const GLenum GL_FRONT_AND_BACK;
	public const GLenum GL_SHADE_MODEL;
	public const GLenum GL_FLAT;
	public const GLenum GL_SMOOTH;
	public const GLenum GL_COLOR_MATERIAL;
	public const GLenum GL_COLOR_MATERIAL_FACE;
	public const GLenum GL_COLOR_MATERIAL_PARAMETER;
	public const GLenum GL_NORMALIZE;
	
	// User Clipping Planes
	public const GLenum GL_CLIP_PLANE0;
	public const GLenum GL_CLIP_PLANE1;
	public const GLenum GL_CLIP_PLANE2;
	public const GLenum GL_CLIP_PLANE3;
	public const GLenum GL_CLIP_PLANE4;
	public const GLenum GL_CLIP_PLANE5;
	
	// Accumulation Buffer
	public const GLenum GL_ACCUM_RED_BITS;
	public const GLenum GL_ACCUM_GREEN_BITS;
	public const GLenum GL_ACCUM_BLUE_BITS;
	public const GLenum GL_ACCUM_ALPHA_BITS;
	public const GLenum GL_ACCUM_CLEAR_VALUE;
	public const GLenum GL_ACCUM;
	public const GLenum GL_ADD;
	public const GLenum GL_LOAD;
	public const GLenum GL_MULT;
	public const GLenum GL_RETURN;
	
	// Alpha Testing
	public const GLenum GL_ALPHA_TEST;
	public const GLenum GL_ALPHA_TEST_REF;
	public const GLenum GL_ALPHA_TEST_FUNC;
	
	// Blending
	public const GLenum GL_BLEND;
	public const GLenum GL_BLEND_SRC;
	public const GLenum GL_BLEND_DST;
	public const GLenum GL_ZERO;
	public const GLenum GL_ONE;
	public const GLenum GL_SRC_COLOR;
	public const GLenum GL_ONE_MINUS_SRC_COLOR;
	public const GLenum GL_SRC_ALPHA;
	public const GLenum GL_ONE_MINUS_SRC_ALPHA;
	public const GLenum GL_DST_ALPHA;
	public const GLenum GL_ONE_MINUS_DST_ALPHA;
	public const GLenum GL_DST_COLOR;
	public const GLenum GL_ONE_MINUS_DST_COLOR;
	public const GLenum GL_SRC_ALPHA_SATURATE;
	
	// Render Mode
	public const GLenum GL_FEEDBACK;
	public const GLenum GL_RENDER;
	public const GLenum GL_SELECT;
	
	// Feedback
	public const GLenum GL_2D;
	public const GLenum GL_3D;
	public const GLenum GL_3D_COLOR;
	public const GLenum GL_3D_COLOR_TEXTURE;
	public const GLenum GL_4D_COLOR_TEXTURE;
	public const GLenum GL_POINT_TOKEN;
	public const GLenum GL_LINE_TOKEN;
	public const GLenum GL_LINE_RESET_TOKEN;
	public const GLenum GL_POLYGON_TOKEN;
	public const GLenum GL_BITMAP_TOKEN;
	public const GLenum GL_DRAW_PIXEL_TOKEN;
	public const GLenum GL_COPY_PIXEL_TOKEN;
	public const GLenum GL_PASS_THROUGH_TOKEN;
	public const GLenum GL_FEEDBACK_BUFFER_POINTER;
	public const GLenum GL_FEEDBACK_BUFFER_SIZE;
	public const GLenum GL_FEEDBACK_BUFFER_TYPE;
	
	// Selection Buffer
	public const GLenum GL_SELECTION_BUFFER_POINTER;
	public const GLenum GL_SELECTION_BUFFER_SIZE;
	
	// Fog
	public const GLenum GL_FOG;
	public const GLenum GL_FOG_MODE;
	public const GLenum GL_FOG_DENSITY;
	public const GLenum GL_FOG_COLOR;
	public const GLenum GL_FOG_INDEX;
	public const GLenum GL_FOG_START;
	public const GLenum GL_FOG_END;
	public const GLenum GL_LINEAR;
	public const GLenum GL_EXP;
	public const GLenum GL_EXP2;
	
	// Logic Ops
	public const GLenum GL_LOGIC_OP;
	public const GLenum GL_INDEX_LOGIC_OP;
	public const GLenum GL_COLOR_LOGIC_OP;
	public const GLenum GL_LOGIC_OP_MODE;
	public const GLenum GL_CLEAR;
	public const GLenum GL_SET;
	public const GLenum GL_COPY;
	public const GLenum GL_COPY_INVERTED;
	public const GLenum GL_NOOP;
	public const GLenum GL_INVERT;
	public const GLenum GL_AND;
	public const GLenum GL_NAND;
	public const GLenum GL_OR;
	public const GLenum GL_NOR;
	public const GLenum GL_XOR;
	public const GLenum GL_EQUIV;
	public const GLenum GL_AND_REVERSE;
	public const GLenum GL_AND_INVERTED;
	public const GLenum GL_OR_REVERSE;
	public const GLenum GL_OR_INVERTED;
	
	// Stencil
	public const GLenum GL_STENCIL_BITS;
	public const GLenum GL_STENCIL_TEST;
	public const GLenum GL_STENCIL_CLEAR_VALUE;
	public const GLenum GL_STENCIL_FUNC;
	public const GLenum GL_STENCIL_VALUE_MASK;
	public const GLenum GL_STENCIL_FAIL;
	public const GLenum GL_STENCIL_PASS_DEPTH_FAIL;
	public const GLenum GL_STENCIL_PASS_DEPTH_PASS;
	public const GLenum GL_STENCIL_REF;
	public const GLenum GL_STENCIL_WRITEMASK;
	public const GLenum GL_STENCIL_INDEX;
	public const GLenum GL_KEEP;
	public const GLenum GL_REPLACE;
	public const GLenum GL_INCR;
	public const GLenum GL_DECR;
	
	// Buffers, Pixel Drawing/Reading
	public const GLenum GL_NONE;
	public const GLenum GL_LEFT;
	public const GLenum GL_RIGHT;
	public const GLenum GL_FRONT_LEFT;
	public const GLenum GL_FRONT_RIGHT;
	public const GLenum GL_BACK_LEFT;
	public const GLenum GL_BACK_RIGHT;
	public const GLenum GL_AUX0;
	public const GLenum GL_AUX1;
	public const GLenum GL_AUX2;
	public const GLenum GL_AUX3;
	public const GLenum GL_COLOR_INDEX;
	public const GLenum GL_RED;
	public const GLenum GL_GREEN;
	public const GLenum GL_BLUE;
	public const GLenum GL_ALPHA;
	public const GLenum GL_LUMINANCE;
	public const GLenum GL_LUMINANCE_ALPHA;
	public const GLenum GL_ALPHA_BITS;
	public const GLenum GL_RED_BITS;
	public const GLenum GL_GREEN_BITS;
	public const GLenum GL_BLUE_BITS;
	public const GLenum GL_INDEX_BITS;
	public const GLenum GL_SUBPIXEL_BITS;
	public const GLenum GL_AUX_BUFFERS;
	public const GLenum GL_READ_BUFFER;
	public const GLenum GL_DRAW_BUFFER;
	public const GLenum GL_DOUBLEBUFFER;
	public const GLenum GL_STEREO;
	public const GLenum GL_BITMAP;
	public const GLenum GL_COLOR;
	public const GLenum GL_DEPTH;
	public const GLenum GL_STENCIL;
	public const GLenum GL_DITHER;
	public const GLenum GL_RGB;
	public const GLenum GL_RGBA;
	
	// Implementation Limits
	public const GLenum GL_MAX_LIST_NESTING;
	public const GLenum GL_MAX_EVAL_ORDER;
	public const GLenum GL_MAX_LIGHTS;
	public const GLenum GL_MAX_CLIP_PLANES;
	public const GLenum GL_MAX_TEXTURE_SIZE;
	public const GLenum GL_MAX_PIXEL_MAP_TABLE;
	public const GLenum GL_MAX_ATTRIB_STACK_DEPTH;
	public const GLenum GL_MAX_MODELVIEW_STACK_DEPTH;
	public const GLenum GL_MAX_NAME_STACK_DEPTH;
	public const GLenum GL_MAX_PROJECTION_STACK_DEPTH;
	public const GLenum GL_MAX_TEXTURE_STACK_DEPTH;
	public const GLenum GL_MAX_VIEWPORT_DIMS;
	public const GLenum GL_MAX_CLIENT_ATTRIB_STACK_DEPTH;
	
	// Gets
	public const GLenum GL_ATTRIB_STACK_DEPTH;
	public const GLenum GL_CLIENT_ATTRIB_STACK_DEPTH;
	public const GLenum GL_COLOR_CLEAR_VALUE;
	public const GLenum GL_COLOR_WRITEMASK;
	public const GLenum GL_CURRENT_INDEX;
	public const GLenum GL_CURRENT_COLOR;
	public const GLenum GL_CURRENT_NORMAL;
	public const GLenum GL_CURRENT_RASTER_COLOR;
	public const GLenum GL_CURRENT_RASTER_DISTANCE;
	public const GLenum GL_CURRENT_RASTER_INDEX;
	public const GLenum GL_CURRENT_RASTER_POSITION;
	public const GLenum GL_CURRENT_RASTER_TEXTURE_COORDS;
	public const GLenum GL_CURRENT_RASTER_POSITION_VALID;
	public const GLenum GL_CURRENT_TEXTURE_COORDS;
	public const GLenum GL_INDEX_CLEAR_VALUE;
	public const GLenum GL_INDEX_MODE;
	public const GLenum GL_INDEX_WRITEMASK;
	public const GLenum GL_MODELVIEW_MATRIX;
	public const GLenum GL_MODELVIEW_STACK_DEPTH;
	public const GLenum GL_NAME_STACK_DEPTH;
	public const GLenum GL_PROJECTION_MATRIX;
	public const GLenum GL_PROJECTION_STACK_DEPTH;
	public const GLenum GL_RENDER_MODE;
	public const GLenum GL_RGBA_MODE;
	public const GLenum GL_TEXTURE_MATRIX;
	public const GLenum GL_TEXTURE_STACK_DEPTH;
	public const GLenum GL_VIEWPORT;
	
	// Evaluators
	public const GLenum GL_AUTO_NORMAL;
	public const GLenum GL_MAP1_COLOR_4;
	public const GLenum GL_MAP1_INDEX;
	public const GLenum GL_MAP1_NORMAL;
	public const GLenum GL_MAP1_TEXTURE_COORD_1;
	public const GLenum GL_MAP1_TEXTURE_COORD_2;
	public const GLenum GL_MAP1_TEXTURE_COORD_3;
	public const GLenum GL_MAP1_TEXTURE_COORD_4;
	public const GLenum GL_MAP1_VERTEX_3;
	public const GLenum GL_MAP1_VERTEX_4;
	public const GLenum GL_MAP2_COLOR_4;
	public const GLenum GL_MAP2_INDEX;
	public const GLenum GL_MAP2_NORMAL;
	public const GLenum GL_MAP2_TEXTURE_COORD_1;
	public const GLenum GL_MAP2_TEXTURE_COORD_2;
	public const GLenum GL_MAP2_TEXTURE_COORD_3;
	public const GLenum GL_MAP2_TEXTURE_COORD_4;
	public const GLenum GL_MAP2_VERTEX_3;
	public const GLenum GL_MAP2_VERTEX_4;
	public const GLenum GL_MAP1_GRID_DOMAIN;
	public const GLenum GL_MAP1_GRID_SEGMENTS;
	public const GLenum GL_MAP2_GRID_DOMAIN;
	public const GLenum GL_MAP2_GRID_SEGMENTS;
	public const GLenum GL_COEFF;
	public const GLenum GL_ORDER;
	public const GLenum GL_DOMAIN;
	
	// Hints
	public const GLenum GL_PERSPECTIVE_CORRECTION_HINT;
	public const GLenum GL_POINT_SMOOTH_HINT;
	public const GLenum GL_LINE_SMOOTH_HINT;
	public const GLenum GL_POLYGON_SMOOTH_HINT;
	public const GLenum GL_FOG_HINT;
	public const GLenum GL_DONT_CARE;
	public const GLenum GL_FASTEST;
	public const GLenum GL_NICEST;
	
	// Scissor box
	public const GLenum GL_SCISSOR_BOX;
	public const GLenum GL_SCISSOR_TEST;
	
	// Pixel Mode / Transfer
	public const GLenum GL_MAP_COLOR;
	public const GLenum GL_MAP_STENCIL;
	public const GLenum GL_INDEX_SHIFT;
	public const GLenum GL_INDEX_OFFSET;
	public const GLenum GL_RED_SCALE;
	public const GLenum GL_RED_BIAS;
	public const GLenum GL_GREEN_SCALE;
	public const GLenum GL_GREEN_BIAS;
	public const GLenum GL_BLUE_SCALE;
	public const GLenum GL_BLUE_BIAS;
	public const GLenum GL_ALPHA_SCALE;
	public const GLenum GL_ALPHA_BIAS;
	public const GLenum GL_DEPTH_SCALE;
	public const GLenum GL_DEPTH_BIAS;
	public const GLenum GL_PIXEL_MAP_S_TO_S_SIZE;
	public const GLenum GL_PIXEL_MAP_I_TO_I_SIZE;
	public const GLenum GL_PIXEL_MAP_I_TO_R_SIZE;
	public const GLenum GL_PIXEL_MAP_I_TO_G_SIZE;
	public const GLenum GL_PIXEL_MAP_I_TO_B_SIZE;
	public const GLenum GL_PIXEL_MAP_I_TO_A_SIZE;
	public const GLenum GL_PIXEL_MAP_R_TO_R_SIZE;
	public const GLenum GL_PIXEL_MAP_G_TO_G_SIZE;
	public const GLenum GL_PIXEL_MAP_B_TO_B_SIZE;
	public const GLenum GL_PIXEL_MAP_A_TO_A_SIZE;
	public const GLenum GL_PIXEL_MAP_S_TO_S;
	public const GLenum GL_PIXEL_MAP_I_TO_I;
	public const GLenum GL_PIXEL_MAP_I_TO_R;
	public const GLenum GL_PIXEL_MAP_I_TO_G;
	public const GLenum GL_PIXEL_MAP_I_TO_B;
	public const GLenum GL_PIXEL_MAP_I_TO_A;
	public const GLenum GL_PIXEL_MAP_R_TO_R;
	public const GLenum GL_PIXEL_MAP_G_TO_G;
	public const GLenum GL_PIXEL_MAP_B_TO_B;
	public const GLenum GL_PIXEL_MAP_A_TO_A;
	public const GLenum GL_PACK_ALIGNMENT;
	public const GLenum GL_PACK_LSB_FIRST;
	public const GLenum GL_PACK_ROW_LENGTH;
	public const GLenum GL_PACK_SKIP_PIXELS;
	public const GLenum GL_PACK_SKIP_ROWS;
	public const GLenum GL_PACK_SWAP_BYTES;
	public const GLenum GL_UNPACK_ALIGNMENT;
	public const GLenum GL_UNPACK_LSB_FIRST;
	public const GLenum GL_UNPACK_ROW_LENGTH;
	public const GLenum GL_UNPACK_SKIP_PIXELS;
	public const GLenum GL_UNPACK_SKIP_ROWS;
	public const GLenum GL_UNPACK_SWAP_BYTES;
	public const GLenum GL_ZOOM_X;
	public const GLenum GL_ZOOM_Y;
	
	// Texture Mapping
	public const GLenum GL_TEXTURE_ENV;
	public const GLenum GL_TEXTURE_ENV_MODE;
	public const GLenum GL_TEXTURE_1D;
	public const GLenum GL_TEXTURE_2D;
	public const GLenum GL_TEXTURE_WRAP_S;
	public const GLenum GL_TEXTURE_WRAP_T;
	public const GLenum GL_TEXTURE_MAG_FILTER;
	public const GLenum GL_TEXTURE_MIN_FILTER;
	public const GLenum GL_TEXTURE_ENV_COLOR;
	public const GLenum GL_TEXTURE_GEN_S;
	public const GLenum GL_TEXTURE_GEN_T;
	public const GLenum GL_TEXTURE_GEN_MODE;
	public const GLenum GL_TEXTURE_BORDER_COLOR;
	public const GLenum GL_TEXTURE_WIDTH;
	public const GLenum GL_TEXTURE_HEIGHT;
	public const GLenum GL_TEXTURE_BORDER;
	public const GLenum GL_TEXTURE_COMPONENTS;
	public const GLenum GL_TEXTURE_RED_SIZE;
	public const GLenum GL_TEXTURE_GREEN_SIZE;
	public const GLenum GL_TEXTURE_BLUE_SIZE;
	public const GLenum GL_TEXTURE_ALPHA_SIZE;
	public const GLenum GL_TEXTURE_LUMINANCE_SIZE;
	public const GLenum GL_TEXTURE_INTENSITY_SIZE;
	public const GLenum GL_NEAREST_MIPMAP_NEAREST;
	public const GLenum GL_NEAREST_MIPMAP_LINEAR;
	public const GLenum GL_LINEAR_MIPMAP_NEAREST;
	public const GLenum GL_LINEAR_MIPMAP_LINEAR;
	public const GLenum GL_OBJECT_LINEAR;
	public const GLenum GL_OBJECT_PLANE;
	public const GLenum GL_EYE_LINEAR;
	public const GLenum GL_EYE_PLANE;
	public const GLenum GL_SPHERE_MAP;
	public const GLenum GL_DECAL;
	public const GLenum GL_MODULATE;
	public const GLenum GL_NEAREST;
	public const GLenum GL_REPEAT;
	public const GLenum GL_CLAMP;
	public const GLenum GL_S;
	public const GLenum GL_T;
	public const GLenum GL_R;
	public const GLenum GL_Q;
	public const GLenum GL_TEXTURE_GEN_R;
	public const GLenum GL_TEXTURE_GEN_Q;
	
	// Utility
	public const GLenum GL_VENDOR;
	public const GLenum GL_RENDERER;
	public const GLenum GL_VERSION;
	public const GLenum GL_EXTENSIONS;
	
	// Errors
	public const GLenum GL_NO_ERROR;
	public const GLenum GL_INVALID_ENUM;
	public const GLenum GL_INVALID_VALUE;
	public const GLenum GL_INVALID_OPERATION;
	public const GLenum GL_STACK_OVERFLOW;
	public const GLenum GL_STACK_UNDERFLOW;
	public const GLenum GL_OUT_OF_MEMORY;
	
	// glPush/Pop Attrib Bits
	public const GLenum GL_CURRENT_BIT;
	public const GLenum GL_POINT_BIT;
	public const GLenum GL_LINE_BIT;
	public const GLenum GL_POLYGON_BIT;
	public const GLenum GL_POLYGON_STIPPLE_BIT;
	public const GLenum GL_PIXEL_MODE_BIT;
	public const GLenum GL_LIGHTING_BIT;
	public const GLenum GL_FOG_BIT;
	public const GLenum GL_DEPTH_BUFFER_BIT;
	public const GLenum GL_ACCUM_BUFFER_BIT;
	public const GLenum GL_STENCIL_BUFFER_BIT;
	public const GLenum GL_VIEWPORT_BIT;
	public const GLenum GL_TRANSFORM_BIT;
	public const GLenum GL_ENABLE_BIT;
	public const GLenum GL_COLOR_BUFFER_BIT;
	public const GLenum GL_HINT_BIT;
	public const GLenum GL_EVAL_BIT;
	public const GLenum GL_LIST_BIT;
	public const GLenum GL_TEXTURE_BIT;
	public const GLenum GL_SCISSOR_BIT;
	public const GLenum GL_ALL_ATTRIB_BITS;
	
	// OpenGL 1.1
	public const GLenum GL_PROXY_TEXTURE_1D;
	public const GLenum GL_PROXY_TEXTURE_2D;
	public const GLenum GL_TEXTURE_PRIORITY;
	public const GLenum GL_TEXTURE_RESIDENT;
	public const GLenum GL_TEXTURE_BINDING_1D;
	public const GLenum GL_TEXTURE_BINDING_2D;
	public const GLenum GL_TEXTURE_INTERNAL_FORMAT;
	public const GLenum GL_ALPHA4;
	public const GLenum GL_ALPHA8;
	public const GLenum GL_ALPHA12;
	public const GLenum GL_ALPHA16;
	public const GLenum GL_LUMINANCE4;
	public const GLenum GL_LUMINANCE8;
	public const GLenum GL_LUMINANCE12;
	public const GLenum GL_LUMINANCE16;
	public const GLenum GL_LUMINANCE4_ALPHA4;
	public const GLenum GL_LUMINANCE6_ALPHA2;
	public const GLenum GL_LUMINANCE8_ALPHA8;
	public const GLenum GL_LUMINANCE12_ALPHA4;
	public const GLenum GL_LUMINANCE12_ALPHA12;
	public const GLenum GL_LUMINANCE16_ALPHA16;
	public const GLenum GL_INTENSITY;
	public const GLenum GL_INTENSITY4;
	public const GLenum GL_INTENSITY8;
	public const GLenum GL_INTENSITY12;
	public const GLenum GL_INTENSITY16;
	public const GLenum GL_R3_G3_B2;
	public const GLenum GL_RGB4;
	public const GLenum GL_RGB5;
	public const GLenum GL_RGB8;
	public const GLenum GL_RGB10;
	public const GLenum GL_RGB12;
	public const GLenum GL_RGB16;
	public const GLenum GL_RGBA2;
	public const GLenum GL_RGBA4;
	public const GLenum GL_RGB5_A1;
	public const GLenum GL_RGBA8;
	public const GLenum GL_RGB10_A2;
	public const GLenum GL_RGBA12;
	public const GLenum GL_RGBA16;
	public const GLenum GL_CLIENT_PIXEL_STORE_BIT;
	public const GLenum GL_CLIENT_VERTEX_ARRAY_BIT;
	public const GLenum GL_ALL_CLIENT_ATTRIB_BITS;
	public const GLenum GL_CLIENT_ALL_ATTRIB_BITS;
	
	// OpenGL 1.2
	public const GLenum GL_RESCALE_NORMAL;
	public const GLenum GL_CLAMP_TO_EDGE;
	public const GLenum GL_MAX_ELEMENTS_VERTICES;
	public const GLenum GL_MAX_ELEMENTS_INDICES;
	public const GLenum GL_BGR;
	public const GLenum GL_BGRA;
	public const GLenum GL_UNSIGNED_BYTE_3_3_2;
	public const GLenum GL_UNSIGNED_BYTE_2_3_3_REV;
	public const GLenum GL_UNSIGNED_SHORT_5_6_5;
	public const GLenum GL_UNSIGNED_SHORT_5_6_5_REV;
	public const GLenum GL_UNSIGNED_SHORT_4_4_4_4;
	public const GLenum GL_UNSIGNED_SHORT_4_4_4_4_REV;
	public const GLenum GL_UNSIGNED_SHORT_5_5_5_1;
	public const GLenum GL_UNSIGNED_SHORT_1_5_5_5_REV;
	public const GLenum GL_UNSIGNED_INT_8_8_8_8;
	public const GLenum GL_UNSIGNED_INT_8_8_8_8_REV;
	public const GLenum GL_UNSIGNED_INT_10_10_10_2;
	public const GLenum GL_UNSIGNED_INT_2_10_10_10_REV;
	public const GLenum GL_LIGHT_MODEL_COLOR_CONTROL;
	public const GLenum GL_SINGLE_COLOR;
	public const GLenum GL_SEPARATE_SPECULAR_COLOR;
	public const GLenum GL_TEXTURE_MIN_LOD;
	public const GLenum GL_TEXTURE_MAX_LOD;
	public const GLenum GL_TEXTURE_BASE_LEVEL;
	public const GLenum GL_TEXTURE_MAX_LEVEL;
	public const GLenum GL_SMOOTH_POINT_SIZE_RANGE;
	public const GLenum GL_SMOOTH_POINT_SIZE_GRANULARITY;
	public const GLenum GL_SMOOTH_LINE_WIDTH_RANGE;
	public const GLenum GL_SMOOTH_LINE_WIDTH_GRANULARITY;
	public const GLenum GL_ALIASED_POINT_SIZE_RANGE;
	public const GLenum GL_ALIASED_LINE_WIDTH_RANGE;
	public const GLenum GL_PACK_SKIP_IMAGES;
	public const GLenum GL_PACK_IMAGE_HEIGHT;
	public const GLenum GL_UNPACK_SKIP_IMAGES;
	public const GLenum GL_UNPACK_IMAGE_HEIGHT;
	public const GLenum GL_TEXTURE_3D;
	public const GLenum GL_PROXY_TEXTURE_3D;
	public const GLenum GL_TEXTURE_DEPTH;
	public const GLenum GL_TEXTURE_WRAP_R;
	public const GLenum GL_MAX_3D_TEXTURE_SIZE;
	public const GLenum GL_TEXTURE_BINDING_3D;
	
	// GL_ARB_imaging
	public const GLenum GL_ARB_imaging;
	public const GLenum GL_CONSTANT_COLOR;
	public const GLenum GL_ONE_MINUS_CONSTANT_COLOR;
	public const GLenum GL_CONSTANT_ALPHA;
	public const GLenum GL_ONE_MINUS_CONSTANT_ALPHA;
	public const GLenum GL_COLOR_TABLE;
	public const GLenum GL_POST_CONVOLUTION_COLOR_TABLE;
	public const GLenum GL_POST_COLOR_MATRIX_COLOR_TABLE;
	public const GLenum GL_PROXY_COLOR_TABLE;
	public const GLenum GL_PROXY_POST_CONVOLUTION_COLOR_TABLE;
	public const GLenum GL_PROXY_POST_COLOR_MATRIX_COLOR_TABLE;
	public const GLenum GL_COLOR_TABLE_SCALE;
	public const GLenum GL_COLOR_TABLE_BIAS;
	public const GLenum GL_COLOR_TABLE_FORMAT;
	public const GLenum GL_COLOR_TABLE_WIDTH;
	public const GLenum GL_COLOR_TABLE_RED_SIZE;
	public const GLenum GL_COLOR_TABLE_GREEN_SIZE;
	public const GLenum GL_COLOR_TABLE_BLUE_SIZE;
	public const GLenum GL_COLOR_TABLE_ALPHA_SIZE;
	public const GLenum GL_COLOR_TABLE_LUMINANCE_SIZE;
	public const GLenum GL_COLOR_TABLE_INTENSITY_SIZE;
	public const GLenum GL_CONVOLUTION_1D;
	public const GLenum GL_CONVOLUTION_2D;
	public const GLenum GL_SEPARABLE_2D;
	public const GLenum GL_CONVOLUTION_BORDER_MODE;
	public const GLenum GL_CONVOLUTION_FILTER_SCALE;
	public const GLenum GL_CONVOLUTION_FILTER_BIAS;
	public const GLenum GL_REDUCE;
	public const GLenum GL_CONVOLUTION_FORMAT;
	public const GLenum GL_CONVOLUTION_WIDTH;
	public const GLenum GL_CONVOLUTION_HEIGHT;
	public const GLenum GL_MAX_CONVOLUTION_WIDTH;
	public const GLenum GL_MAX_CONVOLUTION_HEIGHT;
	public const GLenum GL_POST_CONVOLUTION_RED_SCALE;
	public const GLenum GL_POST_CONVOLUTION_GREEN_SCALE;
	public const GLenum GL_POST_CONVOLUTION_BLUE_SCALE;
	public const GLenum GL_POST_CONVOLUTION_ALPHA_SCALE;
	public const GLenum GL_POST_CONVOLUTION_RED_BIAS;
	public const GLenum GL_POST_CONVOLUTION_GREEN_BIAS;
	public const GLenum GL_POST_CONVOLUTION_BLUE_BIAS;
	public const GLenum GL_POST_CONVOLUTION_ALPHA_BIAS;
	public const GLenum GL_CONSTANT_BORDER;
	public const GLenum GL_REPLICATE_BORDER;
	public const GLenum GL_CONVOLUTION_BORDER_COLOR;
	public const GLenum GL_COLOR_MATRIX;
	public const GLenum GL_COLOR_MATRIX_STACK_DEPTH;
	public const GLenum GL_MAX_COLOR_MATRIX_STACK_DEPTH;
	public const GLenum GL_POST_COLOR_MATRIX_RED_SCALE;
	public const GLenum GL_POST_COLOR_MATRIX_GREEN_SCALE;
	public const GLenum GL_POST_COLOR_MATRIX_BLUE_SCALE;
	public const GLenum GL_POST_COLOR_MATRIX_ALPHA_SCALE;
	public const GLenum GL_POST_COLOR_MATRIX_RED_BIAS;
	public const GLenum GL_POST_COLOR_MATRIX_GREEN_BIAS;
	public const GLenum GL_POST_COLOR_MATRIX_BLUE_BIAS;
	public const GLenum GL_POST_COLOR_MATRIX_ALPHA_BIAS;
	public const GLenum GL_HISTOGRAM;
	public const GLenum GL_PROXY_HISTOGRAM;
	public const GLenum GL_HISTOGRAM_WIDTH;
	public const GLenum GL_HISTOGRAM_FORMAT;
	public const GLenum GL_HISTOGRAM_RED_SIZE;
	public const GLenum GL_HISTOGRAM_GREEN_SIZE;
	public const GLenum GL_HISTOGRAM_BLUE_SIZE;
	public const GLenum GL_HISTOGRAM_ALPHA_SIZE;
	public const GLenum GL_HISTOGRAM_LUMINANCE_SIZE;
	public const GLenum GL_HISTOGRAM_SINK;
	public const GLenum GL_MINMAX;
	public const GLenum GL_MINMAX_FORMAT;
	public const GLenum GL_MINMAX_SINK;
	public const GLenum GL_TABLE_TOO_LARGE;
	public const GLenum GL_BLEND_EQUATION;
	public const GLenum GL_MIN;
	public const GLenum GL_MAX;
	public const GLenum GL_FUNC_ADD;
	public const GLenum GL_FUNC_SUBTRACT;
	public const GLenum GL_FUNC_REVERSE_SUBTRACT;
	public const GLenum GL_BLEND_COLOR;
	
	// OpenGL 1.3
	public const GLenum GL_TEXTURE0;
	public const GLenum GL_TEXTURE1;
	public const GLenum GL_TEXTURE2;
	public const GLenum GL_TEXTURE3;
	public const GLenum GL_TEXTURE4;
	public const GLenum GL_TEXTURE5;
	public const GLenum GL_TEXTURE6;
	public const GLenum GL_TEXTURE7;
	public const GLenum GL_TEXTURE8;
	public const GLenum GL_TEXTURE9;
	public const GLenum GL_TEXTURE10;
	public const GLenum GL_TEXTURE11;
	public const GLenum GL_TEXTURE12;
	public const GLenum GL_TEXTURE13;
	public const GLenum GL_TEXTURE14;
	public const GLenum GL_TEXTURE15;
	public const GLenum GL_TEXTURE16;
	public const GLenum GL_TEXTURE17;
	public const GLenum GL_TEXTURE18;
	public const GLenum GL_TEXTURE19;
	public const GLenum GL_TEXTURE20;
	public const GLenum GL_TEXTURE21;
	public const GLenum GL_TEXTURE22;
	public const GLenum GL_TEXTURE23;
	public const GLenum GL_TEXTURE24;
	public const GLenum GL_TEXTURE25;
	public const GLenum GL_TEXTURE26;
	public const GLenum GL_TEXTURE27;
	public const GLenum GL_TEXTURE28;
	public const GLenum GL_TEXTURE29;
	public const GLenum GL_TEXTURE30;
	public const GLenum GL_TEXTURE31;
	public const GLenum GL_ACTIVE_TEXTURE;
	public const GLenum GL_CLIENT_ACTIVE_TEXTURE;
	public const GLenum GL_MAX_TEXTURE_UNITS;
	public const GLenum GL_NORMAL_MAP;
	public const GLenum GL_REFLECTION_MAP;
	public const GLenum GL_TEXTURE_CUBE_MAP;
	public const GLenum GL_TEXTURE_BINDING_CUBE_MAP;
	public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_X;
	public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_X;
	public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_Y;
	public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_Y;
	public const GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_Z;
	public const GLenum GL_TEXTURE_CUBE_MAP_NEGATIVE_Z;
	public const GLenum GL_PROXY_TEXTURE_CUBE_MAP;
	public const GLenum GL_MAX_CUBE_MAP_TEXTURE_SIZE;
	public const GLenum GL_COMPRESSED_ALPHA;
	public const GLenum GL_COMPRESSED_LUMINANCE;
	public const GLenum GL_COMPRESSED_LUMINANCE_ALPHA;
	public const GLenum GL_COMPRESSED_INTENSITY;
	public const GLenum GL_COMPRESSED_RGB;
	public const GLenum GL_COMPRESSED_RGBA;
	public const GLenum GL_TEXTURE_COMPRESSION_HINT;
	public const GLenum GL_TEXTURE_COMPRESSED_IMAGE_SIZE;
	public const GLenum GL_TEXTURE_COMPRESSED;
	public const GLenum GL_NUM_COMPRESSED_TEXTURE_FORMATS;
	public const GLenum GL_COMPRESSED_TEXTURE_FORMATS;
	public const GLenum GL_MULTISAMPLE;
	public const GLenum GL_SAMPLE_ALPHA_TO_COVERAGE;
	public const GLenum GL_SAMPLE_ALPHA_TO_ONE;
	public const GLenum GL_SAMPLE_COVERAGE;
	public const GLenum GL_SAMPLE_BUFFERS;
	public const GLenum GL_SAMPLES;
	public const GLenum GL_SAMPLE_COVERAGE_VALUE;
	public const GLenum GL_SAMPLE_COVERAGE_INVERT;
	public const GLenum GL_MULTISAMPLE_BIT;
	public const GLenum GL_TRANSPOSE_MODELVIEW_MATRIX;
	public const GLenum GL_TRANSPOSE_PROJECTION_MATRIX;
	public const GLenum GL_TRANSPOSE_TEXTURE_MATRIX;
	public const GLenum GL_TRANSPOSE_COLOR_MATRIX;
	public const GLenum GL_COMBINE;
	public const GLenum GL_COMBINE_RGB;
	public const GLenum GL_COMBINE_ALPHA;
	public const GLenum GL_SOURCE0_RGB;
	public const GLenum GL_SOURCE1_RGB;
	public const GLenum GL_SOURCE2_RGB;
	public const GLenum GL_SOURCE0_ALPHA;
	public const GLenum GL_SOURCE1_ALPHA;
	public const GLenum GL_SOURCE2_ALPHA;
	public const GLenum GL_OPERAND0_RGB;
	public const GLenum GL_OPERAND1_RGB;
	public const GLenum GL_OPERAND2_RGB;
	public const GLenum GL_OPERAND0_ALPHA;
	public const GLenum GL_OPERAND1_ALPHA;
	public const GLenum GL_OPERAND2_ALPHA;
	public const GLenum GL_RGB_SCALE;
	public const GLenum GL_ADD_SIGNED;
	public const GLenum GL_INTERPOLATE;
	public const GLenum GL_SUBTRACT;
	public const GLenum GL_CONSTANT;
	public const GLenum GL_PRIMARY_COLOR;
	public const GLenum GL_PREVIOUS;
	public const GLenum GL_DOT3_RGB;
	public const GLenum GL_DOT3_RGBA;
	public const GLenum GL_CLAMP_TO_BORDER;
	
	// GL_ARB_multitexture (ARB extension 1 and OpenGL 1.2.1)
	public const GLenum GL_TEXTURE0_ARB;
	public const GLenum GL_TEXTURE1_ARB;
	public const GLenum GL_TEXTURE2_ARB;
	public const GLenum GL_TEXTURE3_ARB;
	public const GLenum GL_TEXTURE4_ARB;
	public const GLenum GL_TEXTURE5_ARB;
	public const GLenum GL_TEXTURE6_ARB;
	public const GLenum GL_TEXTURE7_ARB;
	public const GLenum GL_TEXTURE8_ARB;
	public const GLenum GL_TEXTURE9_ARB;
	public const GLenum GL_TEXTURE10_ARB;
	public const GLenum GL_TEXTURE11_ARB;
	public const GLenum GL_TEXTURE12_ARB;
	public const GLenum GL_TEXTURE13_ARB;
	public const GLenum GL_TEXTURE14_ARB;
	public const GLenum GL_TEXTURE15_ARB;
	public const GLenum GL_TEXTURE16_ARB;
	public const GLenum GL_TEXTURE17_ARB;
	public const GLenum GL_TEXTURE18_ARB;
	public const GLenum GL_TEXTURE19_ARB;
	public const GLenum GL_TEXTURE20_ARB;
	public const GLenum GL_TEXTURE21_ARB;
	public const GLenum GL_TEXTURE22_ARB;
	public const GLenum GL_TEXTURE23_ARB;
	public const GLenum GL_TEXTURE24_ARB;
	public const GLenum GL_TEXTURE25_ARB;
	public const GLenum GL_TEXTURE26_ARB;
	public const GLenum GL_TEXTURE27_ARB;
	public const GLenum GL_TEXTURE28_ARB;
	public const GLenum GL_TEXTURE29_ARB;
	public const GLenum GL_TEXTURE30_ARB;
	public const GLenum GL_TEXTURE31_ARB;
	public const GLenum GL_ACTIVE_TEXTURE_ARB;
	public const GLenum GL_CLIENT_ACTIVE_TEXTURE_ARB;
	public const GLenum GL_MAX_TEXTURE_UNITS_ARB;

	
	// Miscellaneous
	public static void glClearIndex (GLfloat c);
	public static void glClearColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
	public static void glClear (GLbitfield mask);
	public static void glIndexMask (GLuint mask);
	public static void glColorMask (GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha);
	public static void glAlphaFunc (GLenum func, GLclampf @ref);
	public static void glBlendFunc (GLenum sfactor, GLenum dfactor);
	public static void glLogicOp (GLenum opcode);
	public static void glCullFace (GLenum mode);
	public static void glFrontFace (GLenum mode);
	public static void glPointSize (GLfloat size);
	public static void glLineWidth (GLfloat width);
	public static void glLineStipple (GLint factor, GLushort pattern);
	public static void glPolygonMode (GLenum face, GLenum mode);
	public static void glPolygonOffset (GLfloat factor, GLfloat units);
	public static void glPolygonStipple ([CCode (array_length = false)] GLubyte[] mask);
	public static void glGetPolygonStipple (out GLubyte mask);
	public static void glEdgeFlag (GLboolean flag);
	public static void glEdgeFlagv ([CCode (array_length = false)] GLboolean[] flag);
	public static void glScissor (GLint x, GLint y, GLsizei width, GLsizei height);
	public static void glClipPlane (GLenum plane, [CCode (array_length = false)] GLdouble[] equation);
	public static void glGetClipPlane (GLenum plane, [CCode (array_length = false)] GLdouble[] equation);
	public static void glDrawBuffer (GLenum mode);
	public static void glReadBuffer (GLenum mode);
	public static void glEnable (GLenum cap);
	public static void glDisable (GLenum cap);
	public static GLboolean glIsEnabled (GLenum cap);
	public static void glEnableClientState (GLenum cap);
	public static void glDisableClientState (GLenum cap);
	public static void glGetBooleanv (GLenum pname, [CCode (array_length = false)] GLboolean[] params);
	public static void glGetDoublev (GLenum pname, [CCode (array_length = false)] GLdouble[] params);
	public static void glGetFloatv (GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetIntegerv (GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glPushAttrib (GLbitfield mask);
	public static void glPopAttrib ();
	public static void glPushClientAttrib (GLbitfield mask);
	public static void glPopClientAttrib ();
	public static GLint glRenderMode (GLenum mode);
	public static GLenum glGetError ();
	public static unowned string glGetString (GLenum name);
	public static void glFinish ();
	public static void glFlush ();
	public static void glHint (GLenum target, GLenum mode);

	// Depth Buffer
	public static void glClearDepth (GLclampd depth);
	public static void glDepthFunc (GLenum func);
	public static void glDepthMask (GLboolean flag);
	public static void glDepthRange (GLclampd near_val, GLclampd far_val);

	// Accumulation Buffer
	public static void glClearAccum (GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
	public static void glAccum (GLenum op, GLfloat @value);

	// Transformation
	public static void glMatrixMode (GLenum mode);
	public static void glOrtho (GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble near_val, GLdouble far_val);
	public static void glFrustum (GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble near_val, GLdouble far_val);
	public static void glViewport (GLint x, GLint y, GLsizei width, GLsizei height);
	public static void glPushMatrix ();
	public static void glPopMatrix ();
	public static void glLoadIdentity ();
	public static void glLoadMatrixd ([CCode (array_length = false)] GLdouble[] m);
	public static void glLoadMatrixf ([CCode (array_length = false)] GLfloat[] m);
	public static void glMultMatrixd ([CCode (array_length = false)] GLdouble[] m);
	public static void glMultMatrixf ([CCode (array_length = false)] GLfloat[] m);
	public static void glRotated (GLdouble angle, GLdouble x, GLdouble y, GLdouble z);
	public static void glRotatef (GLfloat angle, GLfloat x, GLfloat y, GLfloat z);
	public static void glScaled (GLdouble x, GLdouble y, GLdouble z);
	public static void glScalef (GLfloat x, GLfloat y, GLfloat z);
	public static void glTranslated (GLdouble x, GLdouble y, GLdouble z);
	public static void glTranslatef (GLfloat x, GLfloat y, GLfloat z);

	// Display Lists
	public static GLboolean glIsList (GLuint list);
	public static void glDeleteLists (GLuint list, GLsizei range);
	public static GLuint glGenLists (GLsizei range);
	public static void glNewList (GLuint list, GLenum mode);
	public static void glEndList ();
	public static void glCallList (GLuint list);
	public static void glCallLists (GLsizei n, GLenum type, [CCode (array_length = false)] GLvoid[] lists);
	public static void glListBase (GLuint @base);

	// Drawing Functions
	public static void glBegin (GLenum mode);
	public static void glEnd ();
	public static void glVertex2d (GLdouble x, GLdouble y);
	public static void glVertex2f (GLfloat x, GLfloat y);
	public static void glVertex2i (GLint x, GLint y);
	public static void glVertex2s (GLshort x, GLshort y);
	public static void glVertex3d (GLdouble x, GLdouble y, GLdouble z);
	public static void glVertex3f (GLfloat x, GLfloat y, GLfloat z);
	public static void glVertex3i (GLint x, GLint y, GLint z);
	public static void glVertex3s (GLshort x, GLshort y, GLshort z);
	public static void glVertex4d (GLdouble x, GLdouble y, GLdouble z, GLdouble w);
	public static void glVertex4f (GLfloat x, GLfloat y, GLfloat z, GLfloat w);
	public static void glVertex4i (GLint x, GLint y, GLint z, GLint w);
	public static void glVertex4s (GLshort x, GLshort y, GLshort z, GLshort w);
	public static void glVertex2dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glVertex2fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glVertex2iv ([CCode (array_length = false)] GLint[] v);
	public static void glVertex2sv ([CCode (array_length = false)] GLshort[] v);
	public static void glVertex3dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glVertex3fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glVertex3iv ([CCode (array_length = false)] GLint[] v);
	public static void glVertex3sv ([CCode (array_length = false)] GLshort[] v);
	public static void glVertex4dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glVertex4fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glVertex4iv ([CCode (array_length = false)] GLint[] v);
	public static void glVertex4sv ([CCode (array_length = false)] GLshort[] v);
	public static void glNormal3b (GLbyte nx, GLbyte ny, GLbyte nz);
	public static void glNormal3d (GLdouble nx, GLdouble ny, GLdouble nz);
	public static void glNormal3f (GLfloat nx, GLfloat ny, GLfloat nz);
	public static void glNormal3i (GLint nx, GLint ny, GLint nz);
	public static void glNormal3s (GLshort nx, GLshort ny, GLshort nz);
	public static void glNormal3bv ([CCode (array_length = false)] GLbyte[] v);
	public static void glNormal3dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glNormal3fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glNormal3iv ([CCode (array_length = false)] GLint[] v);
	public static void glNormal3sv ([CCode (array_length = false)] GLshort[] v);
	public static void glIndexd (GLdouble c);
	public static void glIndexf (GLfloat c);
	public static void glIndexi (GLint c);
	public static void glIndexs (GLshort c);
	public static void glIndexub (GLubyte c);
	public static void glIndexdv ([CCode (array_length = false)] GLdouble[] c);
	public static void glIndexfv ([CCode (array_length = false)] GLfloat[] c);
	public static void glIndexiv ([CCode (array_length = false)] GLint[] c);
	public static void glIndexsv ([CCode (array_length = false)] GLshort[] c);
	public static void glIndexubv ([CCode (array_length = false)] GLubyte[] c);
	public static void glColor3b (GLbyte red, GLbyte green, GLbyte blue);
	public static void glColor3d (GLdouble red, GLdouble green, GLdouble blue);
	public static void glColor3f (GLfloat red, GLfloat green, GLfloat blue);
	public static void glColor3i (GLint red, GLint green, GLint blue);
	public static void glColor3s (GLshort red, GLshort green, GLshort blue);
	public static void glColor3ub (GLubyte red, GLubyte green, GLubyte blue);
	public static void glColor3ui (GLuint red, GLuint green, GLuint blue);
	public static void glColor3us (GLushort red, GLushort green, GLushort blue);
	public static void glColor4b (GLbyte red, GLbyte green, GLbyte blue, GLbyte alpha);
	public static void glColor4d (GLdouble red, GLdouble green, GLdouble blue, GLdouble alpha);
	public static void glColor4f (GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
	public static void glColor4i (GLint red, GLint green, GLint blue, GLint alpha);
	public static void glColor4s (GLshort red, GLshort green, GLshort blue, GLshort alpha);
	public static void glColor4ub (GLubyte red, GLubyte green, GLubyte blue, GLubyte alpha);
	public static void glColor4ui (GLuint red, GLuint green, GLuint blue, GLuint alpha);
	public static void glColor4us (GLushort red, GLushort green, GLushort blue, GLushort alpha);
	public static void glColor3bv ([CCode (array_length = false)] GLbyte[] v);
	public static void glColor3dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glColor3fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glColor3iv ([CCode (array_length = false)] GLint[] v);
	public static void glColor3sv ([CCode (array_length = false)] GLshort[] v);
	public static void glColor3ubv ([CCode (array_length = false)] GLubyte[] v);
	public static void glColor3uiv ([CCode (array_length = false)] GLuint[] v);
	public static void glColor3usv ([CCode (array_length = false)] GLushort[] v);
	public static void glColor4bv ([CCode (array_length = false)] GLbyte[] v);
	public static void glColor4dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glColor4fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glColor4iv ([CCode (array_length = false)] GLint[] v);
	public static void glColor4sv ([CCode (array_length = false)] GLshort[] v);
	public static void glColor4ubv ([CCode (array_length = false)] GLubyte[] v);
	public static void glColor4uiv ([CCode (array_length = false)] GLuint[] v);
	public static void glColor4usv ([CCode (array_length = false)] GLushort[] v);
	public static void glTexCoord1d (GLdouble s);
	public static void glTexCoord1f (GLfloat s);
	public static void glTexCoord1i (GLint s);
	public static void glTexCoord1s (GLshort s);
	public static void glTexCoord2d (GLdouble s, GLdouble t);
	public static void glTexCoord2f (GLfloat s, GLfloat t);
	public static void glTexCoord2i (GLint s, GLint t);
	public static void glTexCoord2s (GLshort s, GLshort t);
	public static void glTexCoord3d (GLdouble s, GLdouble t, GLdouble r);
	public static void glTexCoord3f (GLfloat s, GLfloat t, GLfloat r);
	public static void glTexCoord3i (GLint s, GLint t, GLint r);
	public static void glTexCoord3s (GLshort s, GLshort t, GLshort r);
	public static void glTexCoord4d (GLdouble s, GLdouble t, GLdouble r, GLdouble q);
	public static void glTexCoord4f (GLfloat s, GLfloat t, GLfloat r, GLfloat q);
	public static void glTexCoord4i (GLint s, GLint t, GLint r, GLint q);
	public static void glTexCoord4s (GLshort s, GLshort t, GLshort r, GLshort q);
	public static void glTexCoord1dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glTexCoord1fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glTexCoord1iv ([CCode (array_length = false)] GLint[] v);
	public static void glTexCoord1sv ([CCode (array_length = false)] GLshort[] v);
	public static void glTexCoord2dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glTexCoord2fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glTexCoord2iv ([CCode (array_length = false)] GLint[] v);
	public static void glTexCoord2sv ([CCode (array_length = false)] GLshort[] v);
	public static void glTexCoord3dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glTexCoord3fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glTexCoord3iv ([CCode (array_length = false)] GLint[] v);
	public static void glTexCoord3sv ([CCode (array_length = false)] GLshort[] v);
	public static void glTexCoord4dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glTexCoord4fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glTexCoord4iv ([CCode (array_length = false)] GLint[] v);
	public static void glTexCoord4sv ([CCode (array_length = false)] GLshort[] v);
	public static void glRasterPos2d (GLdouble x, GLdouble y);
	public static void glRasterPos2f (GLfloat x, GLfloat y);
	public static void glRasterPos2i (GLint x, GLint y);
	public static void glRasterPos2s (GLshort x, GLshort y);
	public static void glRasterPos3d (GLdouble x, GLdouble y, GLdouble z);
	public static void glRasterPos3f (GLfloat x, GLfloat y, GLfloat z);
	public static void glRasterPos3i (GLint x, GLint y, GLint z);
	public static void glRasterPos3s (GLshort x, GLshort y, GLshort z);
	public static void glRasterPos4d (GLdouble x, GLdouble y, GLdouble z, GLdouble w);
	public static void glRasterPos4f (GLfloat x, GLfloat y, GLfloat z, GLfloat w);
	public static void glRasterPos4i (GLint x, GLint y, GLint z, GLint w);
	public static void glRasterPos4s (GLshort x, GLshort y, GLshort z, GLshort w);
	public static void glRasterPos2dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glRasterPos2fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glRasterPos2iv ([CCode (array_length = false)] GLint[] v);
	public static void glRasterPos2sv ([CCode (array_length = false)] GLshort[] v);
	public static void glRasterPos3dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glRasterPos3fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glRasterPos3iv ([CCode (array_length = false)] GLint[] v);
	public static void glRasterPos3sv ([CCode (array_length = false)] GLshort[] v);
	public static void glRasterPos4dv ([CCode (array_length = false)] GLdouble[] v);
	public static void glRasterPos4fv ([CCode (array_length = false)] GLfloat[] v);
	public static void glRasterPos4iv ([CCode (array_length = false)] GLint[] v);
	public static void glRasterPos4sv ([CCode (array_length = false)] GLshort[] v);
	public static void glRectd (GLdouble x1, GLdouble y1, GLdouble x2, GLdouble y2);
	public static void glRectf (GLfloat x1, GLfloat y1, GLfloat x2, GLfloat y2);
	public static void glRecti (GLint x1, GLint y1, GLint x2, GLint y2);
	public static void glRects (GLshort x1, GLshort y1, GLshort x2, GLshort y2);
	public static void glRectdv ([CCode (array_length = false)] GLdouble[] v1, [CCode (array_length = false)] GLdouble[] v2);
	public static void glRectfv ([CCode (array_length = false)] GLfloat[] v1, [CCode (array_length = false)] GLfloat[] v2);
	public static void glRectiv ([CCode (array_length = false)] GLint[] v1, [CCode (array_length = false)] GLint[] v2);
	public static void glRectsv ([CCode (array_length = false)] GLshort[] v1, [CCode (array_length = false)] GLshort[] v2);
    
	// Vertex Arrays  (1.1)
	public static void glVertexPointer (GLint size, GLenum type, GLsizei stride, GLvoid* ptr);
	public static void glNormalPointer (GLenum type, GLsizei stride, GLvoid* ptr);
	public static void glColorPointer (GLint size, GLenum type, GLsizei stride, GLvoid* ptr);
	public static void glIndexPointer (GLenum type, GLsizei stride, GLvoid* ptr);
	public static void glTexCoordPointer (GLint size, GLenum type, GLsizei stride, GLvoid* ptr);
	public static void glEdgeFlagPointer (GLsizei stride, GLvoid* ptr);
	public static void glGetPointerv (GLenum pname, GLvoid** params); 
	public static void glArrayElement (GLint i);
	public static void glDrawArrays (GLenum mode, GLint first, GLsizei count);
	public static void glDrawElements (GLenum mode, GLsizei count, GLenum type, GLvoid* indices);
	public static void glInterleavedArrays (GLenum format, GLsizei stride, GLvoid* pointer);

	// Lighting
	public static void glShadeModel (GLenum mode);
	public static void glLightf (GLenum light, GLenum pname, GLfloat param);
	public static void glLighti (GLenum light, GLenum pname, GLint param);
	public static void glLightfv (GLenum light, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glLightiv (GLenum light, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetLightfv (GLenum light, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetLightiv (GLenum light, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glLightModelf (GLenum pname, GLfloat param);
	public static void glLightModeli (GLenum pname, GLint param);
	public static void glLightModelfv (GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glLightModeliv (GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glMaterialf (GLenum face, GLenum pname, GLfloat param);
	public static void glMateriali (GLenum face, GLenum pname, GLint param);
	public static void glMaterialfv (GLenum face, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glMaterialiv (GLenum face, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetMaterialfv (GLenum face, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetMaterialiv (GLenum face, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glColorMaterial (GLenum face, GLenum mode);

	// Raster functions
	public static void glPixelZoom (GLfloat xfactor, GLfloat yfactor);
	public static void glPixelStoref (GLenum pname, GLfloat param);
	public static void glPixelStorei (GLenum pname, GLint param);
	public static void glPixelTransferf (GLenum pname, GLfloat param);
	public static void glPixelTransferi (GLenum pname, GLint param);
	public static void glPixelMapfv (GLenum map, GLsizei mapsize, [CCode (array_length = false)] GLfloat[] values);
	public static void glPixelMapuiv (GLenum map, GLsizei mapsize, [CCode (array_length = false)] GLuint[] values);
	public static void glPixelMapusv (GLenum map, GLsizei mapsize, [CCode (array_length = false)] GLushort[] values);
	public static void glGetPixelMapfv (GLenum map, [CCode (array_length = false)] GLfloat[] values);
	public static void glGetPixelMapuiv (GLenum map, [CCode (array_length = false)] GLuint[] values);
	public static void glGetPixelMapusv (GLenum map, [CCode (array_length = false)] GLushort[] values);
	public static void glBitmap (GLsizei width, GLsizei height, GLfloat xorig, GLfloat yorig, GLfloat xmove, GLfloat ymove, GLubyte* bitmap);
	public static void glReadPixels (GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* pixels);
	public static void glDrawPixels (GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* pixels);
	public static void glCopyPixels (GLint x, GLint y, GLsizei width, GLsizei height, GLenum type);

	// Stenciling
	public static void glStencilFunc (GLenum func, GLint @ref, GLuint mask);
	public static void glStencilMask (GLuint mask);
	public static void glStencilOp (GLenum fail, GLenum zfail, GLenum zpass);
	public static void glClearStencil (GLint s);

	// Texture mapping
	public static void glTexGend (GLenum coord, GLenum pname, GLdouble param);
	public static void glTexGenf (GLenum coord, GLenum pname, GLfloat param);
	public static void glTexGeni (GLenum coord, GLenum pname, GLint param);
	public static void glTexGendv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLdouble[] params);
	public static void glTexGenfv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glTexGeniv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetTexGendv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLdouble[] params);
	public static void glGetTexGenfv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetTexGeniv (GLenum coord, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glTexEnvf (GLenum target, GLenum pname, GLfloat param);
	public static void glTexEnvi (GLenum target, GLenum pname, GLint param);
	public static void glTexEnvfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glTexEnviv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetTexEnvfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetTexEnviv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glTexParameterf (GLenum target, GLenum pname, GLfloat param);
	public static void glTexParameteri (GLenum target, GLenum pname, GLint param);
	public static void glTexParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glTexParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetTexParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetTexParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glGetTexLevelParameterfv (GLenum target, GLint level, [CCode (array_length = false)] GLenum pname, GLfloat[] params);
	public static void glGetTexLevelParameteriv (GLenum target, GLint level, GLenum pname,[CCode (array_length = false)]  GLint[] params);
	public static void glTexImage1D (GLenum target, GLint level, GLint internalFormat, GLsizei width, GLint border, GLenum format, GLenum type, GLvoid* pixels);
	public static void glTexImage2D (GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, GLvoid* pixels);
	public static void glGetTexImage (GLenum target, GLint level, GLenum format, GLenum type, GLvoid* pixels);

	// 1.1 functions
	public static void glGenTextures (GLsizei n, [CCode (array_length = false)] GLuint[] textures);
	public static void glDeleteTextures (GLsizei n, [CCode (array_length = false)] GLuint[] textures);
	public static void glBindTexture (GLenum target, GLuint texture);
	public static void glPrioritizeTextures (GLsizei n, [CCode (array_length = false)] GLuint[] textures, [CCode (array_length = false)] GLclampf[] priorities);
	public static GLboolean glAreTexturesResident (GLsizei n, [CCode (array_length = false)] GLuint[] textures, [CCode (array_length = false)] GLboolean[] residences);
	public static GLboolean glIsTexture (GLuint texture);
	public static void glTexSubImage1D (GLenum target, GLint level, GLint xoffset, GLsizei width, GLenum format, GLenum type, GLvoid* pixels);
	public static void glTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* pixels);
	public static void glCopyTexImage1D (GLenum target, GLint level, GLenum internalformat, GLint x, GLint y, GLsizei width, GLint border);
	public static void glCopyTexImage2D (GLenum target, GLint level, GLenum internalformat, GLint x, GLint y, GLsizei width, GLsizei height, GLint border);
	public static void glCopyTexSubImage1D (GLenum target, GLint level, GLint xoffset, GLint x, GLint y, GLsizei width);
	public static void glCopyTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint x, GLint y, GLsizei width, GLsizei height);

	// Evaluators
	public static void glMap1d (GLenum target, GLdouble u1, GLdouble u2, GLint stride, GLint order, [CCode (array_length = false)] GLdouble[] points);
	public static void glMap1f (GLenum target, GLfloat u1, GLfloat u2, GLint stride, GLint order, [CCode (array_length = false)] GLfloat[] points);
	public static void glMap2d (GLenum target, GLdouble u1, GLdouble u2, GLint ustride, GLint uorder, GLdouble v1, GLdouble v2, GLint vstride, GLint vorder,[CCode (array_length = false)]  GLdouble[] points);
	public static void glMap2f (GLenum target, GLfloat u1, GLfloat u2, GLint ustride, GLint uorder, GLfloat v1, GLfloat v2, GLint vstride, GLint vorder, [CCode (array_length = false)] GLfloat[] points);
	public static void glGetMapdv (GLenum target, GLenum query, [CCode (array_length = false)] GLdouble[] v);
	public static void glGetMapfv (GLenum target, GLenum query, [CCode (array_length = false)] GLfloat[] v);
	public static void glGetMapiv (GLenum target, GLenum query, [CCode (array_length = false)] GLint[] v);
	public static void glEvalCoord1d (GLdouble u);
	public static void glEvalCoord1f (GLfloat u);
	public static void glEvalCoord1dv ([CCode (array_length = false)] GLdouble[] u);
	public static void glEvalCoord1fv ([CCode (array_length = false)] GLfloat[] u);
	public static void glEvalCoord2d (GLdouble u, GLdouble v);
	public static void glEvalCoord2f (GLfloat u, GLfloat v);
	public static void glEvalCoord2dv ([CCode (array_length = false)] GLdouble[] u);
	public static void glEvalCoord2fv ([CCode (array_length = false)] GLfloat[] u);
	public static void glMapGrid1d (GLint un, GLdouble u1, GLdouble u2);
	public static void glMapGrid1f (GLint un, GLfloat u1, GLfloat u2);
	public static void glMapGrid2d (GLint un, GLdouble u1, GLdouble u2, GLint vn, GLdouble v1, GLdouble v2);
	public static void glMapGrid2f (GLint un, GLfloat u1, GLfloat u2, GLint vn, GLfloat v1, GLfloat v2);
	public static void glEvalPoint1 (GLint i);
	public static void glEvalPoint2 (GLint i, GLint j);
	public static void glEvalMesh1 (GLenum mode, GLint i1, GLint i2);
	public static void glEvalMesh2 (GLenum mode, GLint i1, GLint i2, GLint j1, GLint j2);

	// Fog
	public static void glFogf (GLenum pname, GLfloat param);
	public static void glFogi (GLenum pname, GLint param);
	public static void glFogfv (GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glFogiv (GLenum pname, [CCode (array_length = false)] GLint[] params);

	// Selection and Feedback
	public static void glFeedbackBuffer (GLsizei size, GLenum type, [CCode (array_length = false)] GLfloat[] buffer);
	public static void glPassThrough (GLfloat token);
	public static void glSelectBuffer (GLsizei size, [CCode (array_length = false)] GLuint[] buffer);
	public static void glInitNames ();
	public static void glLoadName (GLuint name);
	public static void glPushName (GLuint name);
	public static void glPopName ();
	
	// OpenGL 1.2
	public static void glDrawRangeElements (GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type, GLvoid* indices);
	public static void glTexImage3D (GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLsizei depth, GLint border, GLenum format, GLenum type, GLvoid* pixels);
	public static void glTexSubImage3D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLenum type, GLvoid* pixels);
	public static void glCopyTexSubImage3D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLint x, GLint y, GLsizei width, GLsizei height);
	
	// GL_ARB_imaging
	public static void glColorTable (GLenum target, GLenum internalformat, GLsizei width, GLenum format, GLenum type, GLvoid* table);
	public static void glColorSubTable (GLenum target, GLsizei start, GLsizei count, GLenum format, GLenum type, GLvoid* data);
	public static void glColorTableParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glColorTableParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glCopyColorSubTable (GLenum target, GLsizei start, GLint x, GLint y, GLsizei width);
	public static void glCopyColorTable (GLenum target, GLenum internalformat, GLint x, GLint y, GLsizei width);
	public static void glGetColorTable (GLenum target, GLenum format, GLenum type, out GLvoid table);
	public static void glGetColorTableParameterfv (GLenum target, GLenum pname, out GLfloat params);
	public static void glGetColorTableParameteriv (GLenum target, GLenum pname, out GLint params);
	public static void glBlendEquation (GLenum mode);
	public static void glBlendColor (GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
	public static void glHistogram (GLenum target, GLsizei width, GLenum internalformat, GLboolean sink);
	public static void glResetHistogram (GLenum target);
	public static void glGetHistogram (GLenum target, GLboolean reset, GLenum format, GLenum type, out GLvoid values);
	public static void glGetHistogramParameterfv (GLenum target, GLenum pname, out GLfloat params);
	public static void glGetHistogramParameteriv (GLenum target, GLenum pname, out GLint params);
	public static void glMinmax (GLenum target, GLenum internalformat, GLboolean sink);
	public static void glResetMinmax (GLenum target);
	public static void glGetMinmax (GLenum target, GLboolean reset, GLenum format, GLenum types, out GLvoid values);
	public static void glGetMinmaxParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetMinmaxParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glConvolutionFilter1D (GLenum target, GLenum internalformat, GLsizei width, GLenum format, GLenum type, GLvoid* image);
	public static void glConvolutionFilter2D (GLenum target, GLenum internalformat, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* image);
	public static void glConvolutionParameterf (GLenum target, GLenum pname, GLfloat params);
	public static void glConvolutionParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glConvolutionParameteri (GLenum target, GLenum pname, GLint params);
	public static void glConvolutionParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glCopyConvolutionFilter1D (GLenum target, GLenum internalformat, GLint x, GLint y, GLsizei width);
	public static void glCopyConvolutionFilter2D (GLenum target, GLenum internalformat, GLint x, GLint y, GLsizei width, GLsizei height);
	public static void glGetConvolutionFilter (GLenum target, GLenum format, GLenum type, GLvoid *image);
	public static void glGetConvolutionParameterfv (GLenum target, GLenum pname, [CCode (array_length = false)] GLfloat[] params);
	public static void glGetConvolutionParameteriv (GLenum target, GLenum pname, [CCode (array_length = false)] GLint[] params);
	public static void glSeparableFilter2D (GLenum target, GLenum internalformat, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid* row, GLvoid* column);
	public static void glGetSeparableFilter (GLenum target, GLenum format, GLenum type, out GLvoid row, out GLvoid column, out GLvoid span);

	//OpenGL 1.3
	public static void glActiveTexture (GLenum texture);
	public static void glClientActiveTexture (GLenum texture);
	public static void glCompressedTexImage1D (GLenum target, GLint level, GLenum internalformat, GLsizei width, GLint border, GLsizei imageSize, GLvoid* data);
	public static void glCompressedTexImage2D (GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, GLvoid* data);
	public static void glCompressedTexImage3D (GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLsizei depth, GLint border, GLsizei imageSize, GLvoid* data);
	public static void glCompressedTexSubImage1D (GLenum target, GLint level, GLint xoffset, GLsizei width, GLenum format, GLsizei imageSize, GLvoid* data);
	public static void glCompressedTexSubImage2D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLsizei imageSize, GLvoid* data);
	public static void glCompressedTexSubImage3D (GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLsizei imageSize, GLvoid* data);
	public static void glGetCompressedTexImage (GLenum target, GLint lod, out GLvoid img);
	public static void glMultiTexCoord1d (GLenum target, GLdouble s);
	public static void glMultiTexCoord1dv (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord1f (GLenum target, GLfloat s);
	public static void glMultiTexCoord1fv (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord1i (GLenum target, GLint s);
	public static void glMultiTexCoord1iv (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord1s (GLenum target, GLshort s);
	public static void glMultiTexCoord1sv (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord2d (GLenum target, GLdouble s, GLdouble t);
	public static void glMultiTexCoord2dv (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord2f (GLenum target, GLfloat s, GLfloat t);
	public static void glMultiTexCoord2fv (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord2i (GLenum target, GLint s, GLint t);
	public static void glMultiTexCoord2iv (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord2s (GLenum target, GLshort s, GLshort t);
	public static void glMultiTexCoord2sv (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord3d (GLenum target, GLdouble s, GLdouble t, GLdouble r);
	public static void glMultiTexCoord3dv (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord3f (GLenum target, GLfloat s, GLfloat t, GLfloat r);
	public static void glMultiTexCoord3fv (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord3i (GLenum target, GLint s, GLint t, GLint r);
	public static void glMultiTexCoord3iv (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord3s (GLenum target, GLshort s, GLshort t, GLshort r);
	public static void glMultiTexCoord3sv (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord4d (GLenum target, GLdouble s, GLdouble t, GLdouble r, GLdouble q);
	public static void glMultiTexCoord4dv (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord4f (GLenum target, GLfloat s, GLfloat t, GLfloat r, GLfloat q);
	public static void glMultiTexCoord4fv (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord4i (GLenum target, GLint s, GLint t, GLint r, GLint q);
	public static void glMultiTexCoord4iv (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord4s (GLenum target, GLshort s, GLshort t, GLshort r, GLshort q);
	public static void glMultiTexCoord4sv (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glLoadTransposeMatrixd ([CCode (array_length = false)] GLdouble[] m);
	public static void glLoadTransposeMatrixf ([CCode (array_length = false)] GLfloat[] m);
	public static void glMultTransposeMatrixd ([CCode (array_length = false)] GLdouble[] m);
	public static void glMultTransposeMatrixf ([CCode (array_length = false)] GLfloat[] m);
	public static void glSampleCoverage (GLclampf @value, GLboolean invert);
	
	// GL_ARB_multitexture (ARB extension 1 and OpenGL 1.2.1)
	public static void glActiveTextureARB (GLenum texture);
	public static void glClientActiveTextureARB (GLenum texture);
	public static void glMultiTexCoord1dARB (GLenum target, GLdouble s);
	public static void glMultiTexCoord1dvARB (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord1fARB (GLenum target, GLfloat s);
	public static void glMultiTexCoord1fvARB (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord1iARB (GLenum target, GLint s);
	public static void glMultiTexCoord1ivARB (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord1sARB (GLenum target, GLshort s);
	public static void glMultiTexCoord1svARB (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord2dARB (GLenum target, GLdouble s, GLdouble t);
	public static void glMultiTexCoord2dvARB (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord2fARB (GLenum target, GLfloat s, GLfloat t);
	public static void glMultiTexCoord2fvARB (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord2iARB (GLenum target, GLint s, GLint t);
	public static void glMultiTexCoord2ivARB (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord2sARB (GLenum target, GLshort s, GLshort t);
	public static void glMultiTexCoord2svARB (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord3dARB (GLenum target, GLdouble s, GLdouble t, GLdouble r);
	public static void glMultiTexCoord3dvARB (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord3fARB (GLenum target, GLfloat s, GLfloat t, GLfloat r);
	public static void glMultiTexCoord3fvARB (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord3iARB (GLenum target, GLint s, GLint t, GLint r);
	public static void glMultiTexCoord3ivARB (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord3sARB (GLenum target, GLshort s, GLshort t, GLshort r);
	public static void glMultiTexCoord3svARB (GLenum target, [CCode (array_length = false)] GLshort[] v);
	public static void glMultiTexCoord4dARB (GLenum target, GLdouble s, GLdouble t, GLdouble r, GLdouble q);
	public static void glMultiTexCoord4dvARB (GLenum target, [CCode (array_length = false)] GLdouble[] v);
	public static void glMultiTexCoord4fARB (GLenum target, GLfloat s, GLfloat t, GLfloat r, GLfloat q);
	public static void glMultiTexCoord4fvARB (GLenum target, [CCode (array_length = false)] GLfloat[] v);
	public static void glMultiTexCoord4iARB (GLenum target, GLint s, GLint t, GLint r, GLint q);
	public static void glMultiTexCoord4ivARB (GLenum target, [CCode (array_length = false)] GLint[] v);
	public static void glMultiTexCoord4sARB (GLenum target, GLshort s, GLshort t, GLshort r, GLshort q);
	public static void glMultiTexCoord4svARB (GLenum target, [CCode (array_length = false)] GLshort[] v);
}

