module dscord.api.client;

import std.stdio,
       std.array,
       std.variant,
       std.conv,
       core.time;

import vibe.http.client,
       vibe.stream.operations;

import dscord.types.all,
       dscord.api.ratelimit,
       dscord.util.errors;

import std.json : parseJSON;

class APIError : BaseError {
  this(int code, string msg) {
    super("[%s] %s", code, msg);
  }
}

// Simple URL constructor to help building routes
struct U {
  string  _bucket;
  string  value;

  this(string url) {
    if (url[0] != '/') {
      url = "/" ~ url;
    }

    this.value = url;
  }

  U opCall(string url) {
    this.value ~= "/" ~ url;
    return this;
  }

  U opCall(Snowflake s) {
    this.opCall(s.toString());
    return this;
  }

  U bucket(string bucket) {
    this._bucket = bucket;
    return this;
  }
}

// Wrapper for HTTP API Responses
class APIResponse {
  private {
    HTTPClientResponse res;
  }

  this(HTTPClientResponse res) {
    this.res = res;
  }

  void ok() {
    if (100 < this.statusCode && this.statusCode < 400) {
      return;
    }

    throw new APIError(this.statusCode, this.content);
  }

  @property string contentType() {
    return this.res.contentType;
  }

  @property int statusCode() {
    return this.res.statusCode;
  }

  @property JSONValue json() {
    return parseJSON(this.content);
  }

  @property string content() {
    return this.res.bodyReader.readAllUTF8();
  }

  string header(string name, string def="") {
    if (name in this.res.headers) {
      return this.res.headers[name];
    }

    return def;
  }
}

// Actual API client used for making requests
class APIClient {
  string       baseURL = "https://discordapp.com/api/";
  string       token;
  RateLimiter  ratelimit;
  Client       client;
  Logger       log;

  this(Client client) {
    this.client = client;
    this.log = client.log;
    this.token = client.token;
    this.ratelimit = new RateLimiter;
  }

  APIResponse requestJSON(HTTPMethod method, U url) {
    return requestJSON(method, url, "");
  }

  APIResponse requestJSON(HTTPMethod method, U url, JSONValue obj) {
    return requestJSON(method, url, obj.toString);
  }

  APIResponse requestJSON(HTTPMethod method, U url, string data,
      Duration timeout=15.seconds) {

    // Grab the rate limit lock
    if (!this.ratelimit.wait(url._bucket, timeout)) {
      throw new APIError(-1, "Request expired before rate-limit");
    }

    debug writefln("R: %s %s %s", method, this.baseURL ~ url.value, data);
    auto res = new APIResponse(requestHTTP(this.baseURL ~ url.value,
      (scope req) {
        req.method = method;
        req.headers["Authorization"] = this.token;
        req.headers["Content-Type"] = "application/json";
        req.bodyWriter.write(data);
    }));

    // If we got a 429, cooldown and recurse
    if (res.statusCode == 429) {
      this.ratelimit.cooldown(url._bucket,
          dur!"seconds"(res.header("Retry-After", "1").to!int));
      return this.requestJSON(method, url, data, timeout);
    // If we got a 502, just retry immedietly
    } else if (res.statusCode == 502) {
      return this.requestJSON(method, url, data, timeout);
    }

    return res;
  }

  JSONValue me() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me"));
    res.ok();
    return res.json;
  }

  JSONValue meGuilds() {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")("@me")("guilds"));
    res.ok();
    return res.json;
  }

  JSONValue user(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("users")(id));
    res.ok();
    return res.json;
  }

  JSONValue guild(Snowflake id) {
    auto res = this.requestJSON(HTTPMethod.GET, U("guilds")(id));
    res.ok();
    return res.json;
  }

  JSONValue sendMessage(Snowflake chan, string content, string nonce, bool tts) {
    JSONValue payload;
    payload["content"] = JSONValue(content);
    payload["nonce"] = JSONValue(nonce);
    payload["tts"] = JSONValue(tts);
    auto res = this.requestJSON(HTTPMethod.POST,
        U("channels")(chan)("messages").bucket("send-message"), payload);
    res.ok();
    return res.json;
  }

  string gateway() {
    auto res = this.requestJSON(HTTPMethod.GET, U("gateway?v=4"));
    res.ok();
    return res.json["url"].str();
  }
}
