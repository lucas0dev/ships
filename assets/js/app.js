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
      game_channel.push("get_next_ship", {});
    })
    .receive('error', resp => {
      lobby.push("find_game", {});
    });

    game_channel.on("place_ship", (payload) => {
      
    })
});
