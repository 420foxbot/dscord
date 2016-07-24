module dscord.client;

import std.stdio;

public import std.experimental.logger;

import std.algorithm.iteration;

import dscord.state,
       dscord.api.client,
       dscord.gateway.client,
       dscord.voice.client,
       dscord.types.all,
       dscord.util.emitter;

class Client {
  // Log
  Logger  log;

  // User auth token
  string  token;

  // Clients
  APIClient      api;
  GatewayClient  gw;

  // Voice connections
  VoiceClient[Snowflake]  voiceConns;

  // State
  State  state;

  // Emitters
  Emitter  events;
  Emitter  packets;

  this(string token, LogLevel lvl=LogLevel.all) {
    this.log = new FileLogger(stdout, lvl);
    this.token = token;

    this.api = new APIClient(this);
    this.gw = new GatewayClient(this);
    this.state = new State(this);
  }

  /**
    Returns the current user.
  */
  @property User me() {
    return this.state.me;
  }

  /**
    Deletes an array of message IDs for a given channel, properly bulking them
    if required.

    Params:
      channelID = the channelID all the messages originate from
      messages = the array of message IDs
  */
  void deleteMessages(Snowflake channelID, Snowflake[] messages) {
    if (messages.length <= 2) {
      messages.each!(x => this.api.deleteMessage(channelID, x));
    } else {
      this.api.bulkDeleteMessages(channelID, messages);
    }
  }
}
