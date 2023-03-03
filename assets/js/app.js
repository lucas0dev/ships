import "../css/app.css"
import socket from "./user_socket.js"
import "phoenix_html"

let lobby = socket.channel('lobby');

socket.connect();
lobby.join()
.receive('ok', resp => {
  channel.push("join_game", {})
});