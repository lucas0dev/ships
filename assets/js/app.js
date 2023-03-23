import "../css/app.css"
import socket from "./user_socket.js"
import "phoenix_html"

let lobby = socket.channel('lobby');
let player_num = "";
let selectedCell = [];
let orientation = "horizontal";
let player_board = document.getElementById("player-board");
let enemy_board = document.getElementById("enemy-board");
let message_block = document.getElementById("messages");
let current_board = player_board;

socket.connect();
joinLobby();

lobby.on("game_found", (payload) => {
    game_id = payload.game_id;
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
    game_channel.on("player_joined", (payload) => {
      // updateStatus(payload.player);
    });
    game_channel.on("place_ship", (payload) => {
      ship_size = payload.size;
    });
    game_channel.on("ship_placed", (payload) => {
      console.log(payload);
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
      message_block.innerHTML = payload.message;
      message_block.classList.add("new-message");
    });
    game_channel.on("board_update", (payload) => {
      updateBoard(payload);
    });
});

function selectBoard(turn){
  if(turn == player_num){
    player_board.classList.remove("active-board");
    enemy_board.classList.add("active-board");
  } else {
    player_board.classList.add("active-board");
    enemy_board.classList.remove("active-board");
  }
}

function updateBoard(data){
  console.log(data)
  let board = (data.shooter == player_num) ? enemy_board : player_board;
  let cell_class = data.result;
  for(var i = 0; i < data.coordinates.length; i++) {
    [col, row] = data.coordinates[i]
    if (row >= 0 && row <= 9 && col >= 0 && col <= 9) {
      board.getElementsByClassName(`cell${row}${col}`)[0].classList.add(cell_class);
    }
  }
}

function joinLobby() {
  lobby.join().receive('ok', resp => {
    lobby.push("find_game", {}) 
  });
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
  selectedCell = event.target;
  addShipShape(selectedCell);
  selectedCell.onmouseleave = function() { 
    removeShipShape();
    selectedCell = [];
  }
}

function highlightCell(event) {
  if(event.target.classList.contains("col")){
    let cell = event.target;
    console.log(cell);
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

function removeMessage(){
  message_block.innerHTML = "";
  message_block.classList.remove("new-message");
}