public List<AIProfile> load_ai_profiles (string filename)
{
   var profiles = new List<AIProfile> ();

   var file = new KeyFile ();
   try
   {
       file.load_from_file (filename, KeyFileFlags.NONE);
   }
   catch (KeyFileError e)
   {
       warning ("Failed to load AI profiles: %s", e.message);
       return profiles;   
   }
   catch (FileError e)
   {
       warning ("Failed to load AI profiles: %s", e.message);
       return profiles;
   }

   foreach (string name in file.get_groups ())
   {
       debug ("Loading AI profile %s", name);
       var profile = new AIProfile ();
       try
       {
           profile.name = name;
           profile.protocol = file.get_value (name, "protocol");
           profile.binary = file.get_value (name, "binary");
           if (file.has_key (name, "args"))
               profile.args = file.get_value (name, "args");
       }
       catch (KeyFileError e)
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
