public GLib.List<AIProfile> load_ai_profiles (string filename)
{
   var profiles = new GLib.List<AIProfile> ();

   var file = new GLib.KeyFile ();
   try
   {
       file.load_from_file (filename, GLib.KeyFileFlags.NONE);
   }
   catch (GLib.KeyFileError e)
   {
       GLib.warning ("Failed to load AI profiles: %s", e.message);
       return profiles;   
   }
   catch (GLib.FileError e)
   {
       GLib.warning ("Failed to load AI profiles: %s", e.message);
       return profiles;
   }

   foreach (string name in file.get_groups ())
   {
       GLib.debug ("Loading AI profile %s", name);
       var profile = new AIProfile ();
       try
       {
           profile.name = name;
           profile.protocol = file.get_value (name, "protocol");
           profile.binary = file.get_value (name, "binary");
           if (file.has_key (name, "args"))
               profile.args = file.get_value (name, "args");
       }
       catch (GLib.KeyFileError e)
       {
           continue;
       }

       if (Environment.find_program_in_path (profile.binary) != null)
           profiles.append (profile);
   }

   return profiles;
}

public class AIProfile
{
    public string name;
    public string protocol;
    public string binary;
    public string args = "";
    public string[] easy_options;
    public string[] normal_options;
    public string[] hard_options;
}
