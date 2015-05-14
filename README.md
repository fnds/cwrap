# cwrap
cwrap.sh - cron wrapper

Every time I write a shell script to be executed by cron, no matter what the script does, I need to add code to save the output and email me the status after it ends. So I thought these actions should be automated and moved to a wrapper that would take care of them. cwrap.sh was born.

My scripts now perform the primary task and send a return code back to be handled by cwrap.sh.

Execute it without parameters to show the usage message below:

 ```
 $ ./cwrap.sh

 USAGE: cwrap.sh [ options ] script [ script parameters ]

– Executes script at default directory: /tmp
  unless script includes directory location
– Redirects output to unique file for each run
– Checks for errors
– Sends email with status
– Do not send emails if file cwrap.blackout exists at /tmp

Options: (override any config file settings)
-c : optional config file
-e a : (a)lways sends email
-e n : (n)ever sends email
-e s : email only when (s)uccessful
-e e : email only when (e)rrors found (default)
-h : detailed help
-m : sends email to this address (default: myemail@mydomain.com)
-o : save script output to a separate file (default: false)
-v : shows more info on screen (verbose)
-x : do not include script output in email (default: true)

Settings search order:
1) command line options
2) optional config file (-c)
3) configuration file: /tmp/cwrap.conf
```
