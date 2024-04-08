white_pawn_tex:        Simp.Texture;
white_knight_tex:      Simp.Texture;
white_bishop_tex:      Simp.Texture;
white_rook_tex:        Simp.Texture;
white_queen_tex:       Simp.Texture;
white_king_tex:        Simp.Texture;

black_pawn_tex:        Simp.Texture;
black_knight_tex:      Simp.Texture;
black_bishop_tex:      Simp.Texture;
black_rook_tex:        Simp.Texture;
black_queen_tex:       Simp.Texture;
black_king_tex:        Simp.Texture;

highlight_tex:         Simp.Texture;
capture_highlight_tex: Simp.Texture;

init_textures :: () {
    Simp.texture_load_from_file(*white_pawn_tex,        "assets/white_pawn.png");
    Simp.texture_load_from_file(*white_knight_tex,      "assets/white_knight.png");
    Simp.texture_load_from_file(*white_bishop_tex,      "assets/white_bishop.png");
    Simp.texture_load_from_file(*white_rook_tex,        "assets/white_rook.png");
    Simp.texture_load_from_file(*white_queen_tex,       "assets/white_queen.png");
    Simp.texture_load_from_file(*white_king_tex,        "assets/white_king.png");

    Simp.texture_load_from_file(*black_pawn_tex,        "assets/black_pawn.png");
    Simp.texture_load_from_file(*black_knight_tex,      "assets/black_knight.png");
    Simp.texture_load_from_file(*black_bishop_tex,      "assets/black_bishop.png");
    Simp.texture_load_from_file(*black_rook_tex,        "assets/black_rook.png");
    Simp.texture_load_from_file(*black_queen_tex,       "assets/black_queen.png");
    Simp.texture_load_from_file(*black_king_tex,        "assets/black_king.png");

    Simp.texture_load_from_file(*highlight_tex,         "assets/highlight.png");
    Simp.texture_load_from_file(*capture_highlight_tex, "assets/capture_highlight.png");
}

draw_previous_move := false;

render :: () {
    using game;
    Simp.clear_render_target(0.5, 0.5, 0.5, 1);

    using board;
    // draw cells
    for y: 0..WIDTH-1 {
        for x: 0..WIDTH-1 {
            Simp.set_shader_for_color();
            color := ifx (x + y) % 2 == 0 then Vector4.{0.47, 0.62, 0.34, 1} else Vector4.{0.92, 0.92, 0.86, 1};
            p0 := Vector2.{x * CELL_SIZE, y * CELL_SIZE};
            p1 := Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE + CELL_SIZE};
            Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, color);
        }
    }

    if draw_previous_move && history.count > 0 {
        previous_move := history[history.count-1];

        Simp.set_shader_for_color();
        x := previous_move.piece[0].x;
        y := previous_move.piece[0].y;
        p0 := Vector2.{x * CELL_SIZE, y * CELL_SIZE};
        p1 := Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE + CELL_SIZE};
        Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{0.8, 0.1, 0.1, 0.6});

        x = previous_move.from[0].x;
        y = previous_move.from[0].y;
        p0 = Vector2.{x * CELL_SIZE, y * CELL_SIZE};
        p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE + CELL_SIZE};
        Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{0.9, 0.4, 0.4, 0.2});
    }

    for pieces if it.is_alive && *it != held_piece {
        draw_piece(it);
    }
    if held_piece {
        // draw origin cell
        {
            Simp.set_shader_for_color();
            p0 := Vector2.{held_piece.x * CELL_SIZE, held_piece.y * CELL_SIZE};
            p1 := Vector2.{held_piece.x * CELL_SIZE + CELL_SIZE, held_piece.y * CELL_SIZE + CELL_SIZE};
            Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{0.8, 0.8, 0.1, 0.2});
        }

        // draw move highlights
        moveset := get_moveset_cells();
        for moveset {
            if has_clear_path(it) {
                capture := get_piece_at(it);
                if capture {
                    if !matches_color(capture, held_piece) {
                        // don't draw pawn forward-moves if it's blocked (ie: not a capture)
                        if is_pawn(held_piece) && it.x == held_piece.x continue;

                        // don't draw captures of kings
                        if is_king(capture) continue;

                        p0 := Vector2.{it.x * CELL_SIZE, it.y * CELL_SIZE};
                        p1 := Vector2.{it.x * CELL_SIZE + CELL_SIZE, it.y * CELL_SIZE + CELL_SIZE};
                        Simp.set_shader_for_images(*capture_highlight_tex);
                        Simp.immediate_quad(p0.x + CELL_SIZE, p0.y + CELL_SIZE, p1.x - CELL_SIZE, p1.y - CELL_SIZE, .{0.25, 0.4, 0.25, 0.35});
                    }
                }
                else {
                    if !is_enpassant(it) && is_pawn(held_piece) && it.x != held_piece.x continue;
                    if !is_castle(it) && is_king(held_piece) && abs(it.x - held_piece.x) == 2 continue;

                    p0 := Vector2.{it.x * CELL_SIZE, it.y * CELL_SIZE};
                    p1 := Vector2.{it.x * CELL_SIZE + CELL_SIZE, it.y * CELL_SIZE + CELL_SIZE};
                    Simp.set_shader_for_images(*highlight_tex);
                    Simp.immediate_quad(p0.x + CELL_SIZE/3, p0.y + CELL_SIZE/3, p1.x - CELL_SIZE/3, p1.y - CELL_SIZE/3, .{0.25, 0.4, 0.25, 0.35});
                }
            }
        }

        // draw held piece
        p0, p1: Vector2;
        if input.mouse.left {
            p0 = input.mouse.position - Vector2.{board.CELL_SIZE/2.0, board.CELL_SIZE/2.0};
            p1 = input.mouse.position + Vector2.{board.CELL_SIZE/2.0, board.CELL_SIZE/2.0};
        } else {
            p0 = Vector2.{held_piece.x * CELL_SIZE, held_piece.y * CELL_SIZE};
            p1 = Vector2.{held_piece.x * CELL_SIZE + CELL_SIZE, held_piece.y * CELL_SIZE + CELL_SIZE};
        }
        draw_piece(<<held_piece, p0, p1);
    }

    if promoting_pawn {
        // background
        Simp.set_shader_for_color();
        is_black := promoting_pawn.type & 1;
        x := promoting_pawn.x;
        y := promoting_pawn.y;
        p0, p1: Vector2;

        if is_black {
            // black
            p0 = Vector2.{x * CELL_SIZE, CELL_SIZE};
            p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, 5 * CELL_SIZE};
        } else {
            // white
            p0 = Vector2.{x * CELL_SIZE, y * CELL_SIZE - 4 * CELL_SIZE};
            p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE};
        }
        Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{0.4, 0.4, 0.4, 1});

        // piece choices
        choices: [4] Simp.Texture;
        if is_black {
            choices = .[black_queen_tex, black_rook_tex, black_bishop_tex, black_knight_tex];
            for i: 0..3 {
                Simp.set_shader_for_images(*choices[i]);
                p0 = Vector2.{x * CELL_SIZE, CELL_SIZE * i + CELL_SIZE};
                p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, CELL_SIZE * i + CELL_SIZE * 2};
                Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{1,1,1,1});
            }
        } else {
            choices = .[white_queen_tex, white_rook_tex, white_bishop_tex, white_knight_tex];
            for i: 0..3 {
                Simp.set_shader_for_images(*choices[i]);
                p0 = Vector2.{x * CELL_SIZE, y * CELL_SIZE - CELL_SIZE * i - CELL_SIZE};
                p1 = Vector2.{x * CELL_SIZE + CELL_SIZE, y * CELL_SIZE - CELL_SIZE * i};
                Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{1,1,1,1});
            }
        }
    }

    Simp.swap_buffers(window.handle);
}

draw_piece :: (piece: Piece) {
    using game.board;
    p0 := Vector2.{piece.x * CELL_SIZE, piece.y * CELL_SIZE};
    p1 := Vector2.{piece.x * CELL_SIZE + CELL_SIZE, piece.y * CELL_SIZE + CELL_SIZE};
    draw_piece(piece, p0, p1);
}

draw_piece :: (piece: Piece, p0: Vector2, p1: Vector2) {
    tex: *Simp.Texture;
    if piece.type == {
        case WHITE_PAWN;   tex = *white_pawn_tex;
        case WHITE_KNIGHT; tex = *white_knight_tex;
        case WHITE_BISHOP; tex = *white_bishop_tex;
        case WHITE_ROOK;   tex = *white_rook_tex;
        case WHITE_QUEEN;  tex = *white_queen_tex;
        case WHITE_KING;   tex = *white_king_tex;

        case BLACK_PAWN;   tex = *black_pawn_tex;
        case BLACK_KNIGHT; tex = *black_knight_tex;
        case BLACK_BISHOP; tex = *black_bishop_tex;
        case BLACK_ROOK;   tex = *black_rook_tex;
        case BLACK_QUEEN;  tex = *black_queen_tex;
        case BLACK_KING;   tex = *black_king_tex;
    }

    Simp.set_shader_for_images(tex);
    Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, .{1,1,1,1});
}