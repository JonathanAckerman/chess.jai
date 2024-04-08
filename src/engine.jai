BUILD : enum { DEBUG; RELEASE; } : .DEBUG;
DEBUG_MEMORY :: BUILD == .DEBUG;
// hide console in release builds
#if BUILD == .RELEASE then #run #if OS == .WINDOWS {
    WR :: #import "Windows_Resources";
    WR.disable_runtime_console();
}

window: struct {
    width := 720;
    height := 720;
    handle: Window_Type;
    saved_info: Saved_Window_Info;
    name: string;
    is_fullscreen: bool;
}
set_window_size :: (w: int, h: int) { window.width = w; window.height = h; }
set_window_size :: (size: Vector2) { window.width = cast(int) size.x; window.height = cast(int) size.y; }
set_fullscreen :: (enabled: bool) { toggle_fullscreen(window.handle, window.is_fullscreen, *window.saved_info); }

input: struct {
    key_left:  u32;
    key_right: u32;
    key_up:    u32;
    key_down:  u32;
    undo:      u32;
    save:      u32;
    load:      u32;

    // @@@: for some reason when testing, input.mouse.left is "held", while this is just "pressed"?
    is_key_down :: (c: u32) -> bool {
        for event : Input.events_this_frame {
            if event.type == .KEYBOARD {
                if xx event.key_code == c return xx event.key_pressed;
            }
        }
        return false;
    }
    is_key_up :: (c: u32) -> bool {
        return true;
    }
    is_key_pressed :: (c: u32) -> bool {
        for event : Input.events_this_frame {
            if event.type == .KEYBOARD {
                if xx event.key_code == c {
                    return Input.input_button_states[event.key_code] & .START && !event.repeat;
                }
            }
        }
        return false;
    }
    is_key_released :: (c: u32) -> bool {
        for event : Input.events_this_frame {
            if event.type == .KEYBOARD {
                if xx event.key_code == c {
                    return xx (Input.input_button_states[event.key_code] & .END);
                }
            }
        }
        return false;
    }

    mouse: struct {
        position: Vector2;
        left: u32;
        right: u32;
    }
}

game: struct {
    quit := false;
    resetting := false;
    current_time: float64;
    last_time: float64;
    dt: float64;

    promoting_pawn: *Piece;
    held_piece: *Piece;
    player_color : u8 = 0;
    history: [..] struct {
        piece: [2] *Piece;
        capture: *Piece;
        from: [2] Cell;
    };
    board: Board;
}

init_fonts :: () {
    // if !working_directory_set {
    //     path := path_strip_filename(get_path_of_running_executable());
    //     set_working_directory(path);
    //     working_directory_set = true;
    // }
    // fonts.OpenSans = Simp.get_font_at_size("assets/fonts", "OpenSans-Regular.ttf", window.height/24);
    // fonts.DejaVuSansMono = Simp.get_font_at_size("assets/fonts", "DejaVuSansMono.ttf", 100);
    // assert(fonts.OpenSans != null);
    // assert(fonts.DejaVuSansMono != null);
}

// fonts: struct {
//     OpenSans: *Simp.Dynamic_Font;
//     DejaVuSansMono: *Simp.Dynamic_Font;
// }

working_directory_set := false;

Simp    :: #import "Simp";
Input   :: #import "Input";
Windows :: #import "Windows";
#import "File";
#import "Window_Creation";
#import "Basic"()(MEMORY_DEBUGGER=DEBUG_MEMORY);
#import "Math";
#import "Random";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.