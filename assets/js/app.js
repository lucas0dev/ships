import "../css/app.css"
import "phoenix_html"
import {Socket} from "phoenix"
let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect();

let lobby = socket.channel('lobby');
let game_channel;
let player_num;
let selectedCell = [];
let orientation = "horizontal";

const player_board = document.getElementById("player-board");
const enemy_board = document.getElementById("enemy-board");
const message_block = document.getElementById("messages");
const modal = document.querySelector(".modal");
const overlay = document.querySelector(".overlay");
const join_btn = document.querySelector(".btn-join");
const modal_title = document.querySelector(".modal-title");
const enemy_status = document.querySelector(".status");
const enemy_ships = document.querySelector(".ships-placed");

let current_board = player_board;

socket.connect();
lobby.join();

join_btn.addEventListener("click", joinLobby);
join_btn.addEventListener("click", closeModal);
join_btn.addEventListener("click", prepareBoards);

lobby.on("game_found", (payload) => {
    let game_id = payload.game_id;
    player_num = payload.player;
    game_channel = socket.channel(`game:${game_id}`);
    game_channel.join()
      .receive('ok', resp => {
        addListeners(player_board);
      })
      .receive('error', resp => {
        lobby.push("find_game", {});
      });
    game_channel.on("unable_to_join", () => {
      joinLobby();
    });
    game_channel.on("place_ship", (payload) => {
      ship_size = payload.size;
    });
    game_channel.on("ship_placed", (payload) => {
      placeOnBoard(payload.coordinates)
      if(payload.last == "true"){
        removeListeners(player_board);
        current_board = enemy_board;
      }
    });
    game_channel.on("next_turn", (payload) => {
      selectBoard(payload.turn);
      if(payload.turn == player_num){
        enemy_board.addEventListener('mouseover', highlightCell)
        enemy_board.addEventListener('click', shootEnemy)
      }
    });
    game_channel.on("message", (payload) => {
      addMessage(payload);
    });
    game_channel.on("game_started", (payload) => {
      hideStatus();
    });
    game_channel.on("modal_msg", (payload) => {
      openModal(payload.message);
    });
    game_channel.on("board_update", (payload) => {
      updateBoard(payload);
    });
    game_channel.on("opponent_update", (payload) => {
      if(payload.recipient == player_num){
        if(payload.status == "online"){
          enemy_status.innerHTML = "online";
        }
        enemy_ships.innerHTML = payload.ships;
      }
    });
});

function joinLobby() {
  lobby.push("find_game", {}) 
}

function prepareBoards(){
  current_board = player_board;
  cells = document.getElementsByClassName("col");
  for(var i = 0; i < cells.length; i++) {
    if(cells[i].classList.contains("ship")){cells[i].classList.remove("ship");}
    if(cells[i].classList.contains("hit")){cells[i].classList.remove("hit");}
    if(cells[i].classList.contains("miss")){cells[i].classList.remove("miss");}
    if(cells[i].classList.contains("destroyed")){cells[i].classList.remove("destroyed");}
  }
  let active_board = document.querySelector(".active-board");
  if(active_board){ active_board.classList.remove("active-board"); }
}

function selectBoard(turn){
  if(turn == player_num){
    enemy_board.classList.remove("active-board");
    player_board.classList.add("active-board");
    enemy_board.querySelector(".turn-label").classList.add("text-hidden");
    player_board.querySelector(".turn-label").classList.remove("text-hidden");
  } else {
    enemy_board.classList.add("active-board");
    player_board.classList.remove("active-board");
    player_board.querySelector(".turn-label").classList.add("text-hidden");
    enemy_board.querySelector(".turn-label").classList.remove("text-hidden");
  }
}

function updateBoard(data){
  let board = (data.shooter == player_num) ? enemy_board : player_board;
  let cell_class = data.result;
  if(data.result == "game_over"){ 
    cell_class = "destroyed";
  }
  for(var i = 0; i < data.coordinates.length; i++) {
    [col, row] = data.coordinates[i]
    if (row >= 0 && row <= 9 && col >= 0 && col <= 9) {
      board.getElementsByClassName(`cell${row}${col}`)[0].classList.add(cell_class);
    }
  }
}

function addListeners(target){
  window.addEventListener('keydown', changeOrientation); 
  target.addEventListener('click', placeShip);
  target.addEventListener('auxclick', changeOrientation);
  target.addEventListener('mouseover', highlightCells);
}

function removeListeners(target){
  window.removeEventListener('keydown', changeOrientation); 
  target.removeEventListener('click', placeShip);
  target.removeEventListener('auxclick', changeOrientation);
  target.removeEventListener('mouseover', highlightCells);
}

function changeOrientation(event){
  if(event.key == " " | event.button == 1){
    switch (orientation) {
      case "horizontal":
        orientation = "vertical"
      break;
      case "vertical":
        orientation = "horizontal"
        break;
    }
    removeShipShape();  
    if (selectedCell != []){
      addShipShape(selectedCell)
    } 
  }
};

function placeShip(event) {
  if(event.target.className != "board"){
    var classname = event.target.className.split(" ");
    y =  parseInt(classname[1].slice(-2, -1));
    x =  parseInt(classname[1].slice(-1));
    game_channel.push("place_ship", {x: x, y: y, orientation: orientation})
    removeMessage();
  }
}

function highlightCells(event) {
  if(event.target.classList.contains("col")){
    selectedCell = event.target;
    addShipShape(selectedCell);
    selectedCell.onmouseleave = function() { 
      removeShipShape();
      selectedCell = [];
    }
  }
}

function highlightCell(event) {
  if(event.target.classList.contains("col")){
    let cell = event.target;
    cell.classList.add("hovered");
    cell.onmouseleave = function() { 
      cell.classList.remove("hovered");
    }
  }
}

function addShipShape(cell){
  ship_cells = getShipCells(cell, orientation)
  for(var i = 0; i < ship_cells.length; i++) {
    [col, row] = ship_cells[i]
    if (row >= 0 && row <= 9 && col >= 0 && col <= 9) {
      current_board.getElementsByClassName(`cell${row}${col}`)[0].classList.add("hovered");
    }
  }
}

function removeShipShape(){
  let hovered = current_board.getElementsByClassName("hovered");
  while(hovered.length > 0){
    hovered[0].classList.remove('hovered');
  }
}

function getShipCells(root_cell, orientation){
  var classname = root_cell.className.split(" ");
  y =  parseInt(classname[1].slice(-2, -1));
  x =  parseInt(classname[1].slice(-1));
  switch (orientation) {
    case "horizontal":
      max_size = [[x,y], [x+1, y], [x+2, y], [x+3, y]]
      return max_size.slice(0, ship_size);
    break;
    case "vertical":
      max_size = [[x,y], [x, y+1], [x, y+2], [x, y+3]]
      return max_size.slice(0, ship_size)
    break;
  }
}

function placeOnBoard(shipCoordinates){
  for(var i = 0; i < shipCoordinates.length; i++) {
    [col, row] = shipCoordinates[i]
    player_board.getElementsByClassName(`cell${row}${col}`)[0].classList.add("ship");
  }
}

function shootEnemy(event) {
  var classname = event.target.className.split(" ");
  y =  parseInt(classname[1].slice(-2, -1));
  x =  parseInt(classname[1].slice(-1));
  game_channel.push("shoot", {x: x, y: y})
  enemy_board.removeEventListener('click', shootEnemy);
  enemy_board.removeEventListener('mouseover', highlightCell);
}

function addMessage(payload){
  message_block.innerHTML = payload.message;
  message_block.className = "msg-" + payload.type;
}

function removeMessage(){
  message_block.innerHTML = "";
  message_block.removeAttribute('class');
}

function openModal(message){
  modal_title.innerHTML = message;
  removeListeners(player_board);
  modal.classList.remove("hidden");
  overlay.classList.remove("hidden");
}

function closeModal() {
  modal.classList.add("hidden");
  overlay.classList.add("hidden");
  document.querySelector(".modal-msg").classList.add("hidden");
}

function hideStatus(){
  document.querySelector(".enemy-status").classList.add("hidden");
}