
// MARK: - Board

/// A model representing a chess board.
///
/// Chess boards consist of black and white figures arranged on an eight-by-eight grid.
public struct Board {
  typealias Mutation = (Board) -> (Board)

  let enPassant: Square?

  var moves = [Notation]()

  let pieces: [Square: Piece]

  init(pieces: [Square : Piece], enPassant: Square? = nil) {
    self.pieces = pieces
    self.enPassant = enPassant
  }
}
