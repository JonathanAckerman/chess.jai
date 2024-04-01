board: struct {
    pieces := Piece.[
        .{.{x=0, y=0}, WHITE_ROOK},
        .{.{x=1, y=0}, WHITE_KNIGHT},
        .{.{x=2, y=0}, WHITE_BISHOP},
        .{.{x=3, y=0}, WHITE_QUEEN},
        .{.{x=4, y=0}, WHITE_KING},
        .{.{x=5, y=0}, WHITE_BISHOP},
        .{.{x=6, y=0}, WHITE_KNIGHT},
        .{.{x=7, y=0}, WHITE_ROOK},
        .{.{x=0, y=1}, WHITE_PAWN},
        .{.{x=1, y=1}, WHITE_PAWN},
        .{.{x=2, y=1}, WHITE_PAWN},
        .{.{x=3, y=1}, WHITE_PAWN},
        .{.{x=4, y=1}, WHITE_PAWN},
        .{.{x=5, y=1}, WHITE_PAWN},
        .{.{x=6, y=1}, WHITE_PAWN},
        .{.{x=7, y=1}, WHITE_PAWN},

        .{.{x=0, y=7}, BLACK_ROOK},
        .{.{x=1, y=7}, BLACK_KNIGHT},
        .{.{x=2, y=7}, BLACK_BISHOP},
        .{.{x=3, y=7}, BLACK_KING},
        .{.{x=4, y=7}, BLACK_QUEEN},
        .{.{x=5, y=7}, BLACK_BISHOP},
        .{.{x=6, y=7}, BLACK_KNIGHT},
        .{.{x=7, y=7}, BLACK_ROOK},
        .{.{x=0, y=6}, BLACK_PAWN},
        .{.{x=1, y=6}, BLACK_PAWN},
        .{.{x=2, y=6}, BLACK_PAWN},
        .{.{x=3, y=6}, BLACK_PAWN},
        .{.{x=4, y=6}, BLACK_PAWN},
        .{.{x=5, y=6}, BLACK_PAWN},
        .{.{x=6, y=6}, BLACK_PAWN},
        .{.{x=7, y=6}, BLACK_PAWN},
    ];

    WIDTH :: 8;
    CELL_SIZE :: 90.0;
}

// @@@: if a struct has a readonly member and a variable member, how does that work?

// @TODO:
// - require escaping check
// - disallow move creating self-check
// - checkmate
// - flip white top/bottom
//      - decouple white/black = bottom/top
// - castling
//      - make_move
//      - checking if it's valid
// - AI
// - Networking
// - no progress game ending
// - save states

handle_input :: () {
    using input;

    Input.update_window_events();
    for Input.get_window_resizes() {
        Simp.update_window(it.window);  // Simp will do nothing if it doesn't care about this window.            
        if it.window == window.handle {
            should_reinit := (it.width != window.width) || (it.height != window.height);
            window.width  = it.width;
            window.height = it.height;
            if should_reinit init_fonts();  // Resize the font for the new window size.
        }
    }

    for event : Input.events_this_frame {
        if event.type == .QUIT then game.quit = true;

        if event.type == .KEYBOARD {
            key := event.key_code;
            if key == {
                case .ESCAPE; 
                    game.quit = true;
                case .F5;     
                    game.resetting = true;
                case .ENTER; 
                    if  event.modifier_flags.alt_pressed        && 
                        Input.input_button_states[key] & .START &&
                        !event.repeat {
                            window.is_fullscreen = !window.is_fullscreen;
                            set_fullscreen(window.is_fullscreen);
                    }

                case #char "Z";
                    if  event.modifier_flags.ctrl_pressed       && 
                        Input.input_button_states[key] & .START &&
                        !event.repeat {
                            undo = event.key_pressed;
                    }
                case #char "S";
                    if  event.modifier_flags.ctrl_pressed       && 
                        Input.input_button_states[key] & .START &&
                        !event.repeat {
                            save = event.key_pressed;
                    }
                case #char "O";
                    if  event.modifier_flags.ctrl_pressed       && 
                        Input.input_button_states[key] & .START &&
                        !event.repeat {
                            load = event.key_pressed;
                    }

                case .MOUSE_BUTTON_LEFT;
                    mouse.left = event.key_pressed;
                case .MOUSE_BUTTON_RIGHT;
                    mouse.right = event.key_pressed;
            }

        }
    }

    per_frame_update_mouse_position :: () {
        current_mouse_x, current_mouse_y, success := get_mouse_pointer_position(true);
        if success {
            input.mouse.position.x = xx max(current_mouse_x, 0);
            input.mouse.position.y = xx max(current_mouse_y, 0);
        }
    }
    per_frame_update_mouse_position();
}

game_loop :: () {
    using game;
    current_time = seconds_since_init();
    dt = xx (current_time - last_time);
    defer last_time = current_time;
    simulate();
    input.undo = 0;
    input.save = 0;
    input.load = 0;
}

make_move :: (mouse_cell: Cell, capture: *Piece, castled: *Piece) {
    using game;
    if capture then capture.is_alive = false;

    from: [2] Cell;
    from[0] = held_piece.cell;
    if castled then from[1] = castled.cell;
    array_add(*history, .{
        .[held_piece, castled],
        capture,
        from
    });

    held_piece.cell = mouse_cell;
    if castled {
        castle_direction := sign(held_piece.cell.x - castled.cell.x);
        castled.cell.x = held_piece.cell.x + castle_direction;
    }

    if is_pawn(held_piece) && (held_piece.y == 0 || held_piece.y == 7) 
        promoting_pawn = held_piece;
    if !promoting_pawn then player_color = xx !player_color;

    held_piece = null;
    draw_previous_move = true;
}

simulate :: () {
    using input;
    using game;
    if !promoting_pawn {
        mouse_cell := pixel_to_cell(mouse.position.x, mouse.position.y);
        if is_key_pressed(xx Input.Key_Code.MOUSE_BUTTON_LEFT) {
            if is_on_board(mouse_cell) {
                if !held_piece {
                    found := get_piece_at(mouse_cell);
                    if found && (found.type & 1) == player_color {
                        held_piece = found;
                    }
                } else {
                    piece := get_piece_at(mouse_cell);
                    if piece && (piece.type & 1) == player_color {
                        // pickup different piece
                        held_piece = piece;
                    } else {
                        is_valid, capture, castled := is_valid_move(mouse_cell);
                        if is_valid {
                            make_move(mouse_cell, capture, castled);
                        } else {
                            // drop without moving
                            held_piece = null;
                        }
                    }
                }
            }
        } 
        if is_key_released(xx Input.Key_Code.MOUSE_BUTTON_LEFT) && held_piece {
            is_valid, capture, castled := is_valid_move(mouse_cell);
            if is_valid {
                make_move(mouse_cell, capture, castled);
            }
        }
        if undo && history.count > 0 {
            previous_move := history[history.count-1];
            previous_move.piece[0].cell = previous_move.from[0];
            if previous_move.capture {
                previous_move.capture.is_alive = true;
            } else if previous_move.piece[1] {
                previous_move.piece[1].cell = previous_move.from[1];
            }
            player_color = xx !player_color;
            history.count -= 1;
            draw_previous_move = false;
            held_piece = null;
        }
        if save {
            file, success := file_open("save_state.txt", true);
            if success {
                file_write(file, )
                talloc()
                file_length(file);
                defer file_close()
                for board.pieces {
                    it.x
                    it.y
                    it.is_alive
                    it.type
                }
                print_to_builder(*sb, "%", player_color);
                data := builder_to_string(*sb);
                File.write_entire_file("save_state.txt", data);
            }
        }
        if load {
            data, success := File.read_entire_file("save_state.txt");
            if success {
                log("%", data);
                cursor : *void = *data;
                for i: 0..board.pieces.count-1 {
                    board.pieces[i].x = cast(int)cursor;
                    log("%", <<(cast(*int)cursor));
                    log("%", board.pieces[i].x);
                    cursor += size_of(int);
                    board.pieces[i].y = <<(cast(*int)cursor);
                    cursor += size_of(int);
                    board.pieces[i].is_alive = <<(cast(*bool)cursor);
                    cursor += size_of(bool);
                    board.pieces[i].type = <<(cast(*u8)cursor);
                    cursor += size_of(u8);
                }
                player_color = <<(cast(*u8)cursor);
            }
        }
    } else {
        using board;
        // interact with promotion UI
        is_black := promoting_pawn.type & 1;
        x := promoting_pawn.x;
        y := promoting_pawn.y;

        choices: [4] struct {
            type: u8;
            p0, p1: Vector2;
        };

        if is_black {
            types := u8.[BLACK_QUEEN, BLACK_ROOK, BLACK_BISHOP, BLACK_KNIGHT];
            for i: 0..3 {
                choices[i] = .{
                    type = types[i],
                    p0 = Vector2.{x * CELL_SIZE, CELL_SIZE * i + CELL_SIZE},
                    p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, CELL_SIZE * i + CELL_SIZE * 2}
                };

            }
        } else {
            types := u8.[WHITE_QUEEN, WHITE_ROOK, WHITE_BISHOP, WHITE_KNIGHT];
            for i: 0..3 {
                choices[i] = .{
                    type = types[i],
                    p0 = Vector2.{x * CELL_SIZE, y * CELL_SIZE - CELL_SIZE * i - CELL_SIZE},
                    p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE - CELL_SIZE * i}
                };
            }
        }

        if mouse.left {
            for choices {
                if  mouse.position.x >= it.p0.x && mouse.position.x <= it.p1.x &&
                    mouse.position.y >= it.p0.y && mouse.position.y <= it.p1.y {
                        promoting_pawn.type = it.type;
                        promoting_pawn = null;
                        player_color = xx !player_color;
                }
            }
        }
    }
}

is_valid_move :: (mouse_cell: Cell) -> bool, *Piece, *Piece {
    using game;
    if is_on_board(mouse_cell) && is_in_moveset(mouse_cell) {
        if has_clear_path(mouse_cell) {
            onto := get_piece_at(mouse_cell);
            if onto {
                if (onto.type & 1) != (held_piece.type & 1) {
                    allow_capture := true;

                    // disallow capturing kings
                    allow_capture = !is_king(onto);

                    // disallow pawn forward-ontos
                    if is_pawn(held_piece) && onto.x == held_piece.x {
                        allow_capture = false;
                    }
                    
                    return allow_capture, onto, null;

                } else if is_castle(onto.cell) return true, null, onto;
            } else {
                // Castling onto king destination
                _, rook := is_castle(mouse_cell);
                if rook 
                    return true, null, rook;
                else if is_king(held_piece) && abs(held_piece.x - mouse_cell.x) == 2
                    return false, null, null;

                // Allow enpassant, disallow pawn diagonal moves otherwise
                if is_enpassant(mouse_cell)
                    return true, history[history.count-1].piece[0], null;
                else if is_pawn(held_piece) && mouse_cell.x != held_piece.x 
                    return false, null, null;

                return true, null, null;
            }
        }
    }
    return false, null, null;
}

is_enpassant :: (to_cell: Cell) -> bool {
    using game;
    if history.count == 0 return false;
    previous_move := history[history.count-1];

    if is_pawn(held_piece) {
        is_diagonal_move := to_cell.x != held_piece.x;
        if is_diagonal_move {
            if previous_move.piece[0] {
                is_towards_previous := to_cell.x - held_piece.x == previous_move.piece[0].x - held_piece.x;
                was_pawn := is_pawn(previous_move.piece[0]);
                was_double_move := abs(previous_move.piece[0].y - previous_move.from[0].y) == 2;
                if was_pawn && was_double_move && is_towards_previous && previous_move.piece[0].y == held_piece.y {
                    return true;
                }
            }
        }
    }
    return false;
}

is_castle :: (to_cell: Cell) -> bool, *Piece {
    using game;
    if is_king(held_piece) {
        if abs(to_cell.x - held_piece.x) == 2 {
            // Moving onto the king destination
            rooks: [..] *Piece;
            for board.pieces if it.is_alive &&
                                is_rook(it) && 
                                matches_color(held_piece, it) {
                array_add(*rooks, *it);
            }

            log("before: %", rooks);
            for rook: rooks {
                move_direction := sign(to_cell.x - held_piece.x);
                rook_direction := sign(rook.x - held_piece.x);
                if move_direction != rook_direction {
                    remove rook; break;
                }

                for history { if it.piece[0] == rook
                    remove rook; break;
                }

                log("% != %", rook.y, held_piece.y);
                if rook.y != held_piece.y {
                    remove rook; break;
                }
            }
            log("after: %", rooks);
            // we will have 0..1 rooks
            assert(rooks.count < 2);
            
            if rooks.count == 1 {
                if has_clear_path(rooks[0].cell) {
                    return true, rooks[0];
                }
            }
        } else {
            // Moving onto a rook
            onto := get_piece_at(to_cell);
            if onto && is_rook(onto) {
                if history.count > 0 && has_clear_path(onto.cell) {
                    for history {
                        if it.piece[0] == held_piece || it.piece[0] == onto {
                            return false, null;
                        }
                    }
                    return true, onto;
                }
            }
        }
    }
    return false, null;
}

matches_color :: (piece: Piece, other: Piece) -> bool {
    return (piece.type & 1) == (other.type & 1);
}
is_pawn :: (piece: Piece) -> bool {
    return piece.type == WHITE_PAWN || piece.type == BLACK_PAWN;
}
is_king :: (piece: Piece) -> bool {
    return piece.type == WHITE_KING || piece.type == BLACK_KING;
}
is_rook :: (piece: Piece) -> bool {
    return piece.type == WHITE_ROOK || piece.type == BLACK_ROOK;
}

is_in_moveset :: (using cell: Cell) -> bool {
    using game;
    if held_piece.type == {
        case WHITE_PAWN;
            if x == held_piece.x {
                is_first_move := held_piece.y == 1;
                if is_first_move && y == held_piece.y + 2 return true;
                if y == held_piece.y + 1 return true;
            } else {
                return y == held_piece.y + 1 && (x == held_piece.x + 1 || x == held_piece.x - 1);
            }
        case BLACK_PAWN;
            if x == held_piece.x {
                is_first_move := held_piece.y == 6;
                if is_first_move && y == held_piece.y - 2 return true;
                if y == held_piece.y - 1 return true;
            } else {
                return y == held_piece.y - 1 && (x == held_piece.x + 1 || x == held_piece.x - 1);
            }
        case WHITE_KNIGHT; #through;
        case BLACK_KNIGHT;
            if abs(x - held_piece.x) == 1 && abs(y - held_piece.y) == 2 return true;
            if abs(x - held_piece.x) == 2 && abs(y - held_piece.y) == 1 return true;

        case WHITE_BISHOP; #through;
        case BLACK_BISHOP;
            if abs(x - held_piece.x) == abs(y - held_piece.y) return true;

        case WHITE_ROOK; #through;
        case BLACK_ROOK;
            if abs(x - held_piece.x) <= board.WIDTH && y == held_piece.y return true;
            if abs(y - held_piece.y) <= board.WIDTH && x == held_piece.x return true;

        case WHITE_QUEEN; #through;
        case BLACK_QUEEN;
            if abs(x - held_piece.x) == abs(y - held_piece.y) return true;
            if abs(x - held_piece.x) <= board.WIDTH && y == held_piece.y return true;
            if abs(y - held_piece.y) <= board.WIDTH && x == held_piece.x return true;

        case WHITE_KING; #through;
        case BLACK_KING;
            if abs(x - held_piece.x) <= 1 && abs(y - held_piece.y) <= 1 return true;
            if abs(x - held_piece.x) == 2 && abs(y - held_piece.y) == 0 return true;
    }

    return false;
}

has_clear_path :: (using destination: Cell) -> bool {
    path := get_move_path(destination);
    if path.count == 0 return false;

    for path {
        if equals(it, destination) continue; // don't disqualify if our destination is occupied as it *might* be a capture
        if get_piece_at(it) return false;
    }
    return true;
}

get_moveset_cells :: () -> [] Cell {
    cells: [..] Cell;
    for y: 0..board.WIDTH-1 {
        for x: 0..board.WIDTH-1 {
            if is_in_moveset(.{x,y}) array_add(*cells, .{x,y});
        }
    }
    return cells;
}

get_move_path :: (using destination: Cell) -> [] Cell {
    using game;
    if equals(destination, held_piece.cell) return Cell.[];

    path: [..] Cell;
    array_add(*path, destination);

    // Create the path ***from destination, excluding current***
    if held_piece.type == {
        case WHITE_PAWN;
            for i: 1..abs(held_piece.y - destination.y) - 1 {
                array_add(*path, Cell.{destination.x, destination.y - i});
            }
        case BLACK_PAWN;
            for i: 1..abs(held_piece.y - destination.y) - 1 {
                array_add(*path, Cell.{destination.x, destination.y + i});
            }

        case WHITE_KNIGHT; // we only need the destination
        case BLACK_KNIGHT; // we only need the destination

        case WHITE_BISHOP; #through;
        case BLACK_BISHOP;
            for i: 1..abs(held_piece.x - destination.x) - 1 {
                x_dir := sign(held_piece.x - destination.x);
                y_dir := sign(held_piece.y - destination.y);
                array_add(*path, Cell.{destination.x + i * x_dir, destination.y + i * y_dir});
            }

        case WHITE_ROOK; #through;
        case BLACK_ROOK;
            // these are mutually exclusive
            for x: 1..abs(held_piece.x - destination.x) - 1 {
                x_dir := sign(held_piece.x - destination.x);
                array_add(*path, Cell.{destination.x + x * x_dir, destination.y});
            }
            for y: 1..abs(held_piece.y - destination.y) - 1 {
                y_dir := sign(held_piece.y - destination.y);
                array_add(*path, Cell.{destination.x, destination.y + y * y_dir});
            }

        case WHITE_QUEEN; #through;
        case BLACK_QUEEN;
            // bishop-esque
            if abs(held_piece.x - destination.x) == abs(held_piece.y - destination.y) {
                for i: 1..abs(held_piece.x - destination.x) - 1 {
                    x_dir := sign(held_piece.x - destination.x);
                    y_dir := sign(held_piece.y - destination.y);
                    array_add(*path, Cell.{destination.x + i * x_dir, destination.y + i * y_dir});
                }
            }
            // rook-esque
            else {
                // these are mutually exclusive
                for x: 1..abs(held_piece.x - destination.x) - 1 {
                    x_dir := sign(held_piece.x - destination.x);
                    array_add(*path, Cell.{destination.x + x * x_dir, destination.y});
                }
                for y: 1..abs(held_piece.y - destination.y) - 1 {
                    y_dir := sign(held_piece.y - destination.y);
                    array_add(*path, Cell.{destination.x, destination.y + y * y_dir});
                }
            }
            
        case WHITE_KING; // we only need the destination
        case BLACK_KING; // we only need the destination
    }
    return path;
}

is_on_board :: (using cell: Cell) -> bool { return x >= 0 && x < board.WIDTH && y >= 0 && y < board.WIDTH; }

sign :: (n: int) -> int {
    if n == 0 return 0; 
    return n / abs(n);
}

pixel_to_cell :: (pixel_x: float, pixel_y: float) -> Cell {
    x := cast(int)(pixel_x / board.CELL_SIZE);
    y := cast(int)(pixel_y / board.CELL_SIZE);
    return Cell.{x, y};
}

get_piece_at :: (cell: Cell) -> *Piece {
    for board.pieces if it.is_alive && it.x == cell.x && it.y == cell.y return *it;
    return null;
}

game_reset :: () {
    print("RESETTING\n");
    game = .{};
    board = .{};
}

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        Windows.timeBeginPeriod(1);
    }

    // @Jay: find the better way to specify a monitor instead of setting the window_x
    window.handle = create_window(window.width, window.height, window.name, 2750, 250);
    Simp.set_render_target(window.handle);
    init_fonts();
    init_textures();

    while !game.quit {
        handle_input();
        game_loop();
        render();
        if game.resetting game_reset();
    }
    #if DEBUG_MEMORY then report_memory_leaks();
}

#load "src/engine.jai";
#load "src/piece.jai";
#load "src/graphics.jai";