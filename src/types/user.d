module types.user;

import types.base,
       types.guild,
       util.json;

alias UserMap = ModelMap!(Snowflake, User);

class User : Model {
  Snowflake  id;
  string     username;
  string     discriminator;
  byte[]     avatar;
  bool       verified;
  string     email;

  this(JSONObject obj) {
    super(obj);
  }

  override void load(JSONObject obj) {
    this.id = obj.get!Snowflake("id");
    this.username = obj.get!string("username");
    this.discriminator = obj.get!string("discriminator");
    this.avatar = cast(byte[])obj.get!string("avatar");
    this.verified = obj.get!bool("verified", false);
    this.email = obj.get!string("email", "");
  }
}
