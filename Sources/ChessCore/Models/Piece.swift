
// MARK: - Piece

/// A model representing a chess piece.
public struct Piece: Equatable {
  /// Color
  public enum Color: String, CaseIterable {
    case white
    case black
  }

  /// Figure
  public enum Figure: String, CaseIterable {
    case rook = "R"
    case knight = "N"
    case bishop = "B"
    case queen = "Q"
    case king = "K"
    case pawn = ""

    init?(_ character: Character) {
      self.init(rawValue: String(character))
    }
  }

  /// Color
  public let color: Color

  /// Figure
  public let figure: Figure

  /// Designated initializer
  /// - Parameters:
  ///   - color: Color
  ///   - figure: Figure
  public init(color: Color, figure: Figure) {
    self.color = color
    self.figure = figure
  }
}

extension Piece: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch color {
    case .black:
      figure.debugDescription.lowercased()

    case .white:
      figure.debugDescription
    }
  }
}

extension Piece {
  var forwardUnitVector: Vector {
    switch color {
    case .black:
      .init(ranks: -1)

    case .white:
      .init(ranks: 1)
    }
  }

  var startRank: Square.Rank {
    switch figure {
    case .pawn:
      .init(rawValue: color.backRank.rawValue + forwardUnitVector.ranks)!

    default:
      .init(rawValue: color.backRank.rawValue)!
    }
  }
}

extension Piece.Color {
  var backRank: Square.Rank {
    switch self {
    case .black:
      .eight

    case .white:
      .one
    }
  }

  var opposite: Self {
    switch self {
    case .black:
      .white

    case .white:
      .black
    }
  }
}

extension Piece.Color: CustomStringConvertible {
  public var description: String {
    rawValue
  }
}

extension Piece.Figure: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .pawn:
      "P"

    default:
      rawValue
    }
  }
}
