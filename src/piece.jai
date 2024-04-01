Piece :: struct {
    using piece_data: Piece_Data;
    type: u8;
}

Piece_Data :: struct {
    using cell: Cell;
    is_alive : bool = true;
};

Cell :: struct {
    x: int;
    y: int;
}

equals :: (c1: Cell, c2: Cell) -> bool {
    return c1.x == c2.x && c1.y == c2.y;
}

//
// Piece_Type definitions:
//      0000__000__0 
//      value_type_color
//
WHITE_PAWN:    u8 : 0b_0001_000_0; // 16
WHITE_KNIGHT:  u8 : 0b_0011_001_0; // 50
WHITE_BISHOP:  u8 : 0b_0011_010_0; // 52
WHITE_ROOK:    u8 : 0b_0101_011_0; // 86
WHITE_QUEEN:   u8 : 0b_1001_100_0; // 152
WHITE_KING:    u8 : 0b_1111_101_0; // 250

BLACK_PAWN:    u8 : 0b_0001_000_1; // 17
BLACK_KNIGHT:  u8 : 0b_0011_001_1; // 51
BLACK_BISHOP:  u8 : 0b_0011_010_1; // 53
BLACK_ROOK:    u8 : 0b_0101_011_1; // 87
BLACK_QUEEN:   u8 : 0b_1001_100_1; // 153
BLACK_KING:    u8 : 0b_1111_101_1; // 251


