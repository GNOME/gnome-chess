/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class AIProfile
{
    public string name;
    public string protocol;
    public string binary;
    public string path;
    public string args;
    public string[] easy_options;
    public string[] normal_options;
    public string[] hard_options;
}

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
           else
               profile.args = null; // bgo#696474
           profile.easy_options = load_options (file, name, "easy");
           profile.normal_options = load_options (file, name, "normal");
           profile.hard_options = load_options (file, name, "hard");
       }
       catch (KeyFileError e)
       {
           continue;
       }

       var path = Environment.find_program_in_path (profile.binary);
       if (path != null)
       {
           profile.path = path;
           profiles.append (profile);
       }
   }

   return profiles;
}

private string[] load_options (KeyFile file, string name, string difficulty) throws KeyFileError
{
    int count = 0;
    while (file.has_key (name, "option-%s-%d".printf (difficulty, count)))
        count++;

    string[] options = new string[count];
    for (var i = 0; i < count; i++)
        options[i] = file.get_value (name, "option-%s-%d".printf (difficulty, i));

    return options;
}
