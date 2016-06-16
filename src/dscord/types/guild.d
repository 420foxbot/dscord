module dscord.types.guild;

import std.stdio,
       std.algorithm,
       std.array,
       std.conv;

import dscord.client,
       dscord.types.all;

alias GuildMap = ModelMap!(Snowflake, Guild);
alias RoleMap = ModelMap!(Snowflake, Role);
alias GuildMemberMap = ModelMap!(Snowflake, GuildMember);
alias EmojiMap = ModelMap!(Snowflake, Emoji);

bool memberHasRoleWithin(RoleMap map, GuildMember mem) {
  foreach (ref role; map.values) {
    if (mem.hasRole(role)) return true;
  }
  return false;
}

class Role : IModel {
  mixin Model;

  Snowflake   id;
  Guild       guild;
  Permission  permissions;

  string  name;
  uint    color;
  bool    hoist;
  short   position;
  bool    managed;
  bool    mentionable;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "name", "hoist", "position", "permissions",
      "managed", "mentionable", "color"
    )(
      { this.id = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.hoist = obj.read!bool; },
      { this.position = obj.read!short; },
      { this.permissions = Permission(obj.read!uint); },
      { this.managed = obj.read!bool; },
      { this.mentionable = obj.read!bool; },
      { this.color = obj.read!uint; },
    );
  }

  Snowflake getID() {
    return this.id;
  }
}

class Emoji : IModel {
  mixin Model;

  Snowflake  id;
  Guild      guild;
  string     name;
  bool       requireColons;
  bool       managed;

  Snowflake[]  roles;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "name", "require_colons", "managed", "roles"
    )(
      { this.id = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.requireColons = obj.read!bool; },
      { this.managed = obj.read!bool; },
      { this.roles = obj.read!(string[]).map!((c) => c.to!Snowflake).array; },
    );
  }
}

class GuildMember : IModel {
  mixin Model;

  User    user;
  Guild   guild;
  string  nick;
  string  joinedAt;
  bool    mute;
  bool    deaf;

  Snowflake[]  roles;

  this(Client client, ref JSON obj) {
    super(client, obj);
  }

  this(Guild guild, ref JSON obj) {
    this.guild = guild;
    super(guild.client, obj);
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "user", "guild_id", "roles", "nick", "mute", "deaf", "joined_at"
    )(
      { this.user = new User(this.client, obj); },
      { this.guild = this.client.state.guilds.get(readSnowflake(obj)); },
      { this.roles = obj.read!(string[]).map!((c) => c.to!Snowflake).array; },
      { this.nick = obj.read!string; },
      { this.mute = obj.read!bool; },
      { this.deaf = obj.read!bool; },
      { this.joinedAt = obj.read!string; },
    );

    // If the state has a user, lets use that version (and trash our local one)
    //  in theory this could leave things dirty, which isn't great...
    if (this.client.state.users.has(this.user.id)) {
      this.user = this.client.state.users.get(this.user.id);
    }
  }

  Snowflake getID() {
    return this.user.id;
  }

  bool hasRole(Role role) {
    return this.hasRole(role.id);
  }

  bool hasRole(Snowflake id) {
    return this.roles.canFind(id);
  }
}

class Guild : IModel {
  mixin Model;

  Snowflake  id;
  Snowflake  ownerID;
  Snowflake  afkChannelID;
  Snowflake  embedChannelID;
  string     name;
  string     icon;
  string     splash;
  string     region;
  uint       afkTimeout;
  bool       embedEnabled;
  ushort     verificationLevel;
  string[]   features;

  bool  unavailable;

  // Mappings
  GuildMemberMap  members;
  VoiceStateMap   voiceStates;
  ChannelMap      channels;
  RoleMap         roles;
  EmojiMap        emojis;

  override void init() {
    this.members = new GuildMemberMap;
    this.voiceStates = new VoiceStateMap;
    this.channels = new ChannelMap;
    this.roles = new RoleMap;
    this.emojis = new EmojiMap;
  }

  override void load(ref JSON obj) {
    obj.keySwitch!(
      "id", "unavailable", "owner_id", "name", "icon",
      "region", "verification_level", "afk_channel_id",
      "splash", "afk_timeout", "channels", "roles", "members",
      "voice_states", "emojis", "features",
    )(
      { this.id = readSnowflake(obj); },
      { this.unavailable = obj.read!bool; },
      { this.ownerID = readSnowflake(obj); },
      { this.name = obj.read!string; },
      { this.icon = obj.read!string; },
      { this.region = obj.read!string; },
      { this.verificationLevel = obj.read!ushort; },
      { this.afkChannelID = readSnowflake(obj); },
      { this.splash = obj.read!string; },
      { this.afkTimeout = obj.read!uint; },
      {
        loadManyComplex!(Guild, Channel)(this, obj, (c) { this.channels[c.id] = c; });
      },
      {
        loadManyComplex!(Guild, Role)(this, obj, (r) { this.roles[r.id] = r; });
      },
      {
        loadManyComplex!(Guild, GuildMember)(this, obj, (m) { this.members[m.user.id] = m; });
      },
      {
        loadMany!VoiceState(this.client, obj, (v) { this.voiceStates[v.sessionID] = v; });
      },
      {
        loadManyComplex!(Guild, Emoji)(this, obj, (e) { this.emojis[e.id] = e; });
      },
      { this.features = obj.read!(string[]); });
  }

  GuildMember getMember(User obj) {
    return this.getMember(obj.id);
  }

  GuildMember getMember(Snowflake id) {
    return this.members[id];
  }

  Snowflake getID() {
    return this.id;
  }
}
