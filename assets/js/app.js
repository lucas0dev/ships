import "../css/app.css"
import socket from "./user_socket.js"
import "phoenix_html"

let lobby = socket.channel('lobby');

socket.connect();
lobby.join()
.receive('ok', resp => {
    console.log("joined lobby")
    lobby.push("join_game", {})
});

lobby.on("new_game", (payload) => {
    game_id = payload.game_id;
    game_channel = socket.channel(`game:${game_id}`);
    game_channel.join()
    .receive('ok', resp => {
    })
    .receive('error', resp => {
      channel.push("join_game", {});
    });
});
