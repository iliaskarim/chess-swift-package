
/// A model representing a chess piece.
public struct Piece: Equatable {
  /// Color
  public enum Color: String, CaseIterable {
    case white
    case black
  }

  /// Figure
  public enum Figure: String, CaseIterable {
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

  public init(color: Color, figure: Figure) {
    self.color = color
    self.figure = figure
  }
}
