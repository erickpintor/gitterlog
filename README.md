# Gitterlog

[Weechat][WEECHAT] plugin to get history from [Gitter.im][GITTER]

---

# Requirements

- Weechat with ruby plugin
- Ruby 2.0

# How to install

Download the gitter_log.rb to your ```~/.weechat/ruby``` folder and then type ```/script load gitter_log.rb``` in your Weechat.

You might want to create a symbolic link on ```~/.weechat/ruby/autoload``` so you don't need to load the script manually again.

# Configurations

- plugins.var.ruby.gitterlog.server: The name you gave to your gitter server on weechat
- plugins.var.ruby.gitterlog.token: The gitter secure token to access its API

# How to get your secure token

[Here][SECURE_TOKEN] but, you need to be logged in.

# How to use gitterlog

Once the script is loaded, it'll be watching for new channels and once you join any gitter room, the script will automaticaly load the history for you.

You can also force the download with the command ```/gitterlog```.

# Inspiration

This script was highly inspired by [Slacklog][SLACKLOG]

[GITTER]:https://gitter.im
[WEECHAT]:https://weechat.org/
[SECURE_TOKEN]:https://developer.gitter.im/apps
[SLACKLOG]:https://github.com/thoughtbot/weechat-slacklog
