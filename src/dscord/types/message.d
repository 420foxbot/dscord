module dscord.types.message;

import std.stdio,
       std.variant,
       std.conv,
       std.format,
       std.regex,
       std.array,
       std.algorithm.iteration;

import dscord.client,
       dscord.types.all;

class MessageEmbed : IModel {
  mixin Model;

  string  title;
  string  type;
  string  description;
  string  url;

  // TODO: thumbnail, provider

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "title", "type", "description", "url"
    )(
      { this.title = obj.read!string; },
      { this.type = obj.read!string; },
      { this.description = obj.read!string; },
      { this.url = obj.read!string; },
    );
  }
}

class MessageAttachment : IModel {
  mixin Model;

  Snowflake  id;
  string     filename;
  uint       size;
  string     url;
  string     proxyUrl;
  uint       height;
  uint       width;

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "filename", "size", "url", "proxy_url",
      "height", "width",
    )(
      { this.id = readSnowflake(obj); },
      { this.filename = obj.read!string; },
      { this.size = obj.read!uint; },
      { this.url = obj.read!string; },
      { this.proxyUrl = obj.read!string; },
      { this.height = obj.read!uint; },
      { this.width = obj.read!uint; },
    );
  }
}

class Message : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  channelID;
  Channel    channel;
  User       author;
  string     content;
  string     timestamp; // TODO: timestamps lol
  string     editedTimestamp; // TODO: timestamps lol
  bool       tts;
  bool       mentionEveryone;
  string     nonce;
  bool       pinned;

  // TODO: GuildMemberMap here
  UserMap    mentions;
  RoleMap    roleMentions;

  // Embeds
  MessageEmbed[]  embeds;

  // Attachments
  MessageAttachment[]  attachments;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Channel channel, ref JSON obj) {
    this.channel = channel;
    super(channel.client, obj);
  }

  override void init() {
    this.mentions = new UserMap;
    this.roleMentions = new RoleMap;
  }

  override void load(ref JSON obj) {
    // TODO: avoid leaking user

    obj.keySwitch!(
      "id", "channel_id", "content", "timestamp", "edited_timestamp", "tts",
      "mention_everyone", "nonce", "author", "pinned", "mentions", "mention_roles",
      // "embeds", "attachments",
    )(
      { this.id = readSnowflake(obj); },
      { this.channelID = readSnowflake(obj); },
      { this.content = obj.read!string; },
      { this.timestamp = obj.read!string; },
      {
        if (obj.peek() == DataType.string) {
          this.editedTimestamp = obj.read!string;
        } else {
          obj.skipValue;
        }
      },
      { this.tts = obj.read!bool; },
      { this.mentionEveryone = obj.read!bool; },
      {
        if (obj.peek() == DataType.string) {
          this.nonce = obj.read!string;
        } else if (obj.peek() == DataType.null_) {
          obj.skipValue;
        } else {
          this.nonce = obj.read!long.to!string;
        }
      },
      { this.author = new User(this.client, obj); },
      { this.pinned = obj.read!bool; },
      { loadMany!User(this.client, obj, (u) { this.mentions[u.id] = u; }); },
      { obj.skipValue; },
      // { obj.skipValue; },
      // { obj.skipvalue; },
    );

    if (!this.channel && this.client.state.channels.has(this.channelID)) {
      this.channel = this.client.state.channels.get(this.channelID);
    }
  }

  /*
    Returns a version of the message contents, with mentions completely removed
  */
  string withoutMentions() {
    return this.replaceMentions((m, u) => "", (m, r) => "");
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
    }, (msg, role) { return "@" ~ role.name; });
  }

  /**
    Returns the message contents, replacing all mentions with the result from the
    specified delegate.
  */
  string replaceMentions(string delegate(Message, User) fu, string delegate(Message, Role) fr) {
    if (!this.mentions.length) {
      return this.content;
    }

    string result = this.content;
    foreach (ref User user; this.mentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", user.id)), fu(this, user));
    }

    foreach (ref Role role; this.roleMentions.values) {
      result = replaceAll(result, regex(format("<@!?(%s)>", role.id)), fr(this, role));
    }

    return result;
  }

  /**
    Sends a new message to the same channel as this message.

    Params:
      content = the message contents
      nonce = the message nonce
      tts = whether this is a TTS message
  */
  Message reply(string content, string nonce=null, bool tts=false) {
    return this.client.api.sendMessage(this.channel.id, content, nonce, tts);
  }

  /**
    Sends a new MessageBuffer message to the same channel as this message.
  */
  Message reply(MessageBuffer msg) {
    return this.client.api.sendMessage(this.channel.id, msg.contents, null, false);
  }

  /**
    Sends a new formatted message to the same channel as this message.
  */
  Message replyf(T...)(string content, T args) {
    return this.client.api.sendMessage(this.channel.id, format(content, args), null, false);
  }

  /**
    Edits this message contents.
  */
  Message edit(string content) {
    // We can only edit messages we sent
    assert(this.client.me.id == this.author.id);
    return this.client.api.editMessage(this.channel.id, this.id, content);
  }

  /**
    Deletes this message.
  */
  void del() {
    // TODO: permissions check
    return this.client.api.deleteMessage(this.channel.id, this.id);
  }

  /*
    True if this message mentions the current user in any way (everyone, direct mention, role mention)
  */
  @property bool mentioned() {
    this.client.log.tracef("M: %s", this.mentions.keys);

    return this.mentionEveryone ||
      this.mentions.has(this.client.state.me.id) ||
      this.roleMentions.memberHasRoleWithin(
        this.guild.getMember(this.client.state.me));
  }

  /**
    Guild this message was sent in (if applicable).
  */
  @property Guild guild() {
    if (this.channel && this.channel.guild) return this.channel.guild;
    return null;
  }

  /**
    Returns an array of emoji IDs for all custom emoji used in this message.
  */
  @property Snowflake[] customEmojiByID() {
    return matchAll(this.content, regex("<:\\w+:(\\d+)>")).map!((m) => m.back.to!Snowflake).array;
  }
}
