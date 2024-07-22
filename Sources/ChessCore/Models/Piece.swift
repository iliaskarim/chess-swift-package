
/// A model representing a chess piece.
public struct Piece: Equatable {
  /// Color
  enum Color: String, CaseIterable {
    case white
    case black
  }

  /// Figure
  enum Figure: String, CaseIterable {
    case bishop = "B"
    case king = "K"
    case knight = "N"
    case pawn = ""
    case queen = "Q"
    case rook = "R"

    init?(_ character: Character) {
      self.init(rawValue: String(character))
    }
  }

  /// Color
  let color: Color

  /// Figure
  let figure: Figure
}

extension Piece.Color {
  var opposite: Self {
    switch self {
    case .white:
      return .black

    case .black:
      return .white
    }
  }
}
