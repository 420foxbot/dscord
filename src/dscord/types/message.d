module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex;

import dscord.client,
       dscord.types.base,
       dscord.types.user,
       dscord.types.guild,
       dscord.types.channel,
       dscord.util.json;

class MessageEmbed : Model {
  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.title = obj.get!string("title");
    this.type = obj.get!string("type");
    this.description = obj.get!string("description");
    this.url = obj.get!string("url");
  }
}

class MessageAttachment : Model {
  Snowflake  id;
  string     filename;
  uint       size;
  string     url;
  string     proxyUrl;
  uint       height;
  uint       width;

  this(Client client, JSONObject obj) {
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.filename = obj.get!string("filename");
    this.size = obj.get!uint("size");
    this.url = obj.get!string("url");
    this.proxyUrl = obj.maybeGet!string("proxy_url", "");
    this.height = obj.maybeGet!uint("height", 0);
    this.width = obj.maybeGet!uint("width", 0);
  }
}

class Message : Model {
  Snowflake  id;
  Snowflake  channel_id;
  User       author;
  string    content;
  string     timestamp; // TODO: timestamps lol
  string     edited_timestamp; // TODO: timestamps lol
  bool       tts;
  bool       mention_everyone;
  string     nonce;
  UserMap    mentions;

  // Embeds
  MessageEmbed[]  embeds;

  // Attachments
  MessageAttachment[]  attachments;


  this(Client client, JSONObject obj) {
    this.mentions = new UserMap;
    super(client, obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.channel_id = obj.get!Snowflake("channel_id");
    this.content = obj.maybeGet!(string)("content", "");
    this.timestamp = obj.maybeGet!string("timestamp", "");
    this.edited_timestamp = obj.maybeGet!string("edited_timestamp", "");
    this.tts = obj.maybeGet!bool("tts", false);
    this.mention_everyone = obj.maybeGet!bool("mention_everyone", false);
    this.nonce = obj.maybeGet!string("nonce", "");

    if (obj.has("author")) {
      auto auth = obj.get!JSONObject("author");

      if (this.client.state.users.has(auth.get!Snowflake("id"))) {
        this.author = this.client.state.users(auth.get!Snowflake("id"));
        this.author.load(auth);
      } else {
        this.author = new User(this.client, auth);
        this.client.state.users.set(this.author.id, this.author);
      }
    }

    if (obj.has("mentions")) {
      foreach (Variant v; obj.getRaw("mentions")) {
        auto user = new User(this.client, new JSONObject(variantToJSON(v)));
        if (this.client.state.users.has(user.id)) {
          user = this.client.state.users.get(user.id);
        }
        this.mentions.set(user.id, user);
      }
    }

    if (obj.has("embeds")) {
      foreach (Variant v; obj.getRaw("embeds")) {
        auto embed = new MessageEmbed(this.client, new JSONObject(variantToJSON(v)));
        this.embeds ~= embed;
      }
    }

    if (obj.has("attachments")) {
      foreach (Variant v; obj.getRaw("attachments")) {
        auto attach = new MessageAttachment(this.client,
          new JSONObject(variantToJSON(v)));
        this.attachments ~= attach;
      }
    }
  }

  /*
    Returns a version of the message contents, with mentions completely removed
  */
  string withoutMentions() {
    return this.replaceMentions((m, u) => "");
  }

  /*
    Returns a version of the message contents, replacing all mentions with user/nick names
  */
  string withProperMentions(bool nicks=true) {
    return this.replaceMentions((msg, user) {
      GuildMember m;
      if (nicks) {
        m = msg.guild.members.get(user.id);
      }
      return "@" ~ ((m && m.nick != "") ? m.nick : user.username);
    });
  }

  /*
    Returns the message contents, replacing all mentions with the result from the
    specified delegate.
  */
  string replaceMentions(string delegate(Message, User) f) {
    if (!this.mentions.length) {
      return this.content;
    }

    string result = this.content;
    foreach (ref User user; this.mentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", user.id)), f(this, user));
    }

    return result;
  }

  void reply(string content, string nonce=null, bool tts=false, bool mention=false) {
    // TODO: support mentioning
    this.client.api.sendMessage(this.channel_id, content, nonce, tts);
  }

  @property Guild guild() {
    return this.channel.guild;
  }

  @property Channel channel() {
    return this.client.state.channels.get(this.channel_id);
  }
}
