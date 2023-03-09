import "../css/app.css"
import socket from "./user_socket.js"
import "phoenix_html"

let lobby = socket.channel('lobby');

socket.connect();
lobby.join()
.receive('ok', resp => {
    lobby.push("find_game", {})
});

lobby.on("game_found", (payload) => {
    game_id = payload.game_id;
    game_channel = socket.channel(`game:${game_id}`);
    game_channel.join()
    .receive('ok', resp => {
    })
    .receive('error', resp => {
      lobby.push("find_game", {});
    });
});
