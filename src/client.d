module client;

import state,
       api.client,
       gateway.client,
       types.user;

class Client {
  // User auth token
  string  token;

  // Clients
  APIClient      api;
  GatewayClient  gw;

  // State
  State  state;

  this(string token) {
    this.token = token;

    this.api = new APIClient(this.token);
    this.gw = new GatewayClient(this.api.gateway(), this.token);
    this.state = new State(this.api, this.gw);

    this.gw.start();
  }
}
