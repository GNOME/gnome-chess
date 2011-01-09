using GL;

public class TDSModel
{
    private GLfloat min_height = float.MAX;
    private GLfloat max_height = float.MIN;
    private GLfloat[] vertices;
    private GLushort[] triangles;
    private GLfloat[] normals;
    private GLfloat[] texture_coords;

    public TDSModel (File file) throws Error
    {
        var stream = file.read ();
        parse_block (stream, stream.query_info (FILE_ATTRIBUTE_STANDARD_SIZE).get_size ());

        /* Calculate normals */
        normals = new GLfloat[vertices.length];
        for (int i = 0; i < normals.length; i++)
            normals[i] = 0f;
        for (int i = 0; i < triangles.length; i += 3)
        {
            var v0 = triangles[i] * 3;
            var v1 = triangles[i+1] * 3;
            var v2 = triangles[i+2] * 3;

            /* Do cross-product of face to get normal */
            GLfloat a[3], b[3], normal[3];
            a[0] = vertices[v1] - vertices[v0];
            a[1] = vertices[v1+1] - vertices[v0+1];
            a[2] = vertices[v1+2] - vertices[v0+2];
            b[0] = vertices[v2] - vertices[v0];
            b[1] = vertices[v2+1] - vertices[v0+1];
            b[2] = vertices[v2+2] - vertices[v0+2];
            normal[0] = a[1]*b[2] - a[2]*b[1];
            normal[1] = a[2]*b[0] - a[0]*b[2];
            normal[2] = a[0]*b[1] - a[1]*b[0];

            /* Add this normal to the three vertices of this face */
            normals[v0] += normal[0];
            normals[v0+1] += normal[1];
            normals[v0+2] += normal[2];
            normals[v1] += normal[0];
            normals[v1+1] += normal[1];
            normals[v1+2] += normal[2];
            normals[v2] += normal[0];
            normals[v2+1] += normal[1];
            normals[v2+2] += normal[2];
        }

        /* Normalize normals */
        for (int i = 0; i < normals.length; i += 3)
        {
            GLfloat length = (GLfloat) Math.sqrt (normals[i]*normals[i] + normals[i+1]*normals[i+1] + normals[i+2]*normals[i+2]);
            normals[i] /= length;
            normals[i+1] /= length;
            normals[i+2] /= length;
        }

        /* Set texture coordinates to a conical projection */
        texture_coords = new GLfloat[(vertices.length / 3) * 2];
        for (int i = 0, j = 0; i < vertices.length; i += 3, j += 2)
        {
            var u = vertices[i];
            var v = vertices[i+2];
            var r = (GLfloat) Math.sqrt (u*u + v*v);
            if (r != 0)
            {
                u /= r;
                v /= r;
            }

            /* Maximum height is in the middle of the texture, minimum on the boundary */
            var h = 1.0f - (vertices[i+1] / max_height);
            texture_coords[j] = 0.5f + 0.5f * h * u;
            texture_coords[j+1] = 0.5f + 0.5f * h * v;
        }
    }
    
    private void parse_block (FileInputStream stream, int64 length) throws Error
    {
        while (length > 6)
        {
            var id = read_uint16 (stream);
            int64 block_length = read_uint32 (stream);
            if (block_length < 6)
            {
                return;
            }
            if (block_length > length)
            {
                // throw error
                stderr.printf("Overflow, need %lli octets for %04X, but only have %lli\n", block_length, (int) id, length);
                return;
            }

            switch (id)
            {
            /* Main chunk */
            case 0x4D4D:
                //stdout.printf("<root>\n");
                parse_block (stream, block_length - 6);
                //stdout.printf("</root>\n");
                break;

            /* Version */
            /*case 0x0002:
                var version = read_uint32 (stream);
                //stdout.printf("<version>%u</version>\n", version);
                break;*/

            /* 3D editor */
            case 0x3D3D:
                //stdout.printf("<editor>\n");
                parse_block (stream, block_length - 6);
                //stdout.printf("</editor>\n");
                break;

            /* Object block */
            case 0x4000:
                var name = read_string (stream);
                //stdout.printf("<object name=\"%s\">\n", name);
                parse_block (stream, block_length - 6 - (name.length + 1));
                //stdout.printf("</object>\n");
                break;
                
            /* Triangular mesh */
            case 0x4100:
                //stdout.printf("<triangles>\n");
                parse_block (stream, block_length - 6);
                //stdout.printf("</triangles>\n");
                break;

            /* Vertices */
            case 0x4110:
                //stdout.printf("<vertices>\n");
                var n = read_uint16 (stream);
                vertices = new GLfloat[n*3];
                for (var i = 0; i < n; i++)
                {
                    var x = read_float (stream);
                    var y = read_float (stream);
                    var z = read_float (stream);
                    var scale = 3.5f; // FIXME: Fix the model files
                    vertices[i*3] = scale*x;
                    vertices[i*3+1] = scale*z;
                    vertices[i*3+2] = scale*y;

                    var h = scale*z;
                    if (h < min_height)
                        min_height = h;
                    if (h > max_height)
                        max_height = h;

                    //stdout.printf ("<vertex x=\"%f\" y=\"%f\" z=\"%f\"/>\n", x, y, z);
                }
                //stdout.printf("</vertices>\n");
                break;

            /* Faces */
            case 0x4120:
                //stdout.printf("<faces>\n");
                if (block_length < 2)
                    return;
                var n = read_uint16 (stream);
                triangles = new GLushort[n*3];
                if (block_length < 2 + n * 8)                  
                {
                    stderr.printf("Invalid face data, need %u, have %lli\n", 2+n*8, block_length);
                    return;
                }
                for (var i = 0; i < n; i++)
                {
                    var a = read_uint16 (stream);
                    var b = read_uint16 (stream);
                    var c = read_uint16 (stream);
                    /*var flags = */read_uint16 (stream);
                    triangles[i*3] = (GLushort) a;
                    triangles[i*3+1] = (GLushort) c;
                    triangles[i*3+2] = (GLushort) b;
                    //stdout.printf ("<face a=\"%u\" b=\"%u\" c=\"%u\"/ flags=\"%u\">\n", a, b, c, flags);
                }
                parse_block (stream, block_length - (2 + n*8));
                //stdout.printf("</faces>\n");
                break;

            /* Keyframer */
/*            case 0xB000:
                //stdout.printf("<keyframe>\n");
                parse_block (stream, block_length - 6);
                //stdout.printf("</keyframe>\n");
                break;*/

            default:
                //stdout.printf ("<%04X>", id);
                for (var i = 0; i < block_length - 6; i++)
                {
                    /*var c = */read_uint8 (stream);
                    //stdout.printf("%02X ", c);
                }
                //stdout.printf ("<\\%04X>\n", id);
                break;
            }

            length -= block_length;
                //stream.seek (block_length - 6, SeekType.CUR);
        }
        
        if (length != 0)
        {
            return; // throw error
        }
    }

    public void render ()
    {
        glEnable (GL_CULL_FACE);

        glEnableClientState (GL_VERTEX_ARRAY);
        glEnableClientState (GL_NORMAL_ARRAY);
        glEnableClientState (GL_TEXTURE_COORD_ARRAY);

        glVertexPointer (3, GL_FLOAT, 0, vertices);
        glNormalPointer (GL_FLOAT, 0, normals);
        glTexCoordPointer (2, GL_FLOAT, 0, texture_coords);
        glDrawElements (GL_TRIANGLES, (GLsizei) triangles.length, GL_UNSIGNED_SHORT, triangles);

        glDisableClientState (GL_VERTEX_ARRAY);
        glDisableClientState (GL_NORMAL_ARRAY);
        glDisableClientState (GL_TEXTURE_COORD_ARRAY);
    }

    private uint8 read_uint8 (InputStream stream) throws Error
    {
        uchar buffer[1];
        stream.read_all (buffer, null, null);
        return buffer[0];
    }

    private uint16 read_uint16 (InputStream stream) throws Error
    {
        uchar buffer[2];
        stream.read_all (buffer, null, null);
        return buffer[1] << 8 | buffer[0];
    }

    private uint32 read_uint32 (InputStream stream) throws Error
    {
        uchar buffer[4];
        stream.read_all (buffer, null, null);
        return buffer[3] << 24 | buffer[2] << 16 | buffer[1] << 8 | buffer[0];
    }

    private float read_float (InputStream stream) throws Error
    {
        uint8 buffer[4];
        stream.read_all (buffer, null, null);
        float[] fbuffer = (float[]) buffer;
        return fbuffer[0];
    }

    private string read_string (InputStream stream) throws Error
    {
        var value = new StringBuilder();
        while (true)
        {
            var c = read_uint8 (stream);
            if (c == 0)
                return value.str;
            value.append_c ((char)c);
        }
    }
}