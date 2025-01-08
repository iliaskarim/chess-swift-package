
// MARK: -
private extension Square {
  func allSquaresInDirection(_ direction: Vector) -> [Self] {
    (self + direction).map { squareInDirection in
      [squareInDirection] + squareInDirection.allSquaresInDirection(direction)
    } ?? []
  }
}

// MARK: -
private extension Piece {
  func capturePaths(from square: Square) -> [[Square]] {
    guard figure == .pawn else {
      return movePaths(from: square)
    }

    return [Vector(files: -1, ranks: forwardUnitVector.ranks),
            Vector(files: 1, ranks: forwardUnitVector.ranks)].compactMap { vector in
      (square + vector).map { targetSquare in
        [targetSquare]
      }
    }
  }

  func movePaths(from square: Square) -> [[Square]] {
    switch figure {
    case .bishop:
      Vector.diagonalUnitVectors.compactMap(square.allSquaresInDirection)

    case .king:
      Vector.unitVectors.compactMap { vector in
        (square + vector).map { targetSquare in
          [targetSquare]
        }
      }

    case .knight:
      [Vector(files: -2, ranks: -1),
       Vector(files: -2, ranks: 1),
       Vector(files: -1, ranks: -2),
       Vector(files: -1, ranks: 2),
       Vector(files: 1, ranks: -2),
       Vector(files: 1, ranks: 2),
       Vector(files: 2, ranks: -1),
       Vector(files: 2, ranks: 1)].compactMap { vector in
        (square + vector).map { targetSquare in
          [targetSquare]
        }
      }

    case .pawn:
      if square.rank == startRank {
        [[(square + forwardUnitVector)!], [((square + forwardUnitVector)! + forwardUnitVector)!]]
      } else {
        [[(square + forwardUnitVector)!]]
      }

    case .queen:
      Vector.unitVectors.compactMap(square.allSquaresInDirection)

    case .rook:
      Vector.cardinalUnitVectors.compactMap(square.allSquaresInDirection)
    }
  }
}

// MARK: -
private extension Vector {
  static let cardinalUnitVectors: [Self] = [
    .init(files: -1, ranks: 0),
    .init(files: 0, ranks: -1),
    .init(files: 0, ranks: 1),
    .init(files: 1, ranks: 0)
  ]

  static let diagonalUnitVectors: [Self] = [
    .init(files: -1, ranks: -1),
    .init(files: -1, ranks: 1),
    .init(files: 1, ranks: -1),
    .init(files: 1, ranks: 1)
  ]

  static let unitVectors = cardinalUnitVectors + diagonalUnitVectors
}

// MARK: - Board

/// A model representing a chess board.
///
/// Chess boards consist of black and white figures arranged on an eight-by-eight grid.
public struct Board {
  typealias Mutation = (Board) -> (Board)

  public let pieces: [Square: Piece]

  weak var dataSource: BoardDataSource?
}

public extension Board {
  /// Conventional board setup
  static var board: Board {
    Board(pieces: Piece.Color.allCases.flatMap { color in
      Piece.Figure.allCases.map { figure in
        Piece(color: color, figure: figure)
      }
    }.reduce(into: .init()) { pieces, piece in
      let files: [Square.File] = switch piece.figure {
      case .bishop:
        [.c, .f]

      case .king:
        [.e]

      case .knight:
        [.b, .g]

      case .pawn:
        Square.File.allCases

      case .queen:
        [.d]

      case .rook:
        [.a, .h]
      }

      pieces = files.reduce(into: pieces) { pieces, file in
        pieces[.init(file: file, rank: piece.startRank)] = piece
      }
    })
  }

  /// Possible moves from a square
  /// - Parameter square: Source square
  /// - Returns: Destination squares
  func moves(from square: Square) -> [Square] {
    guard let piece = pieces[square], piece.color == moveColor else {
      return []
    }

    let captures = moves(for: piece, from: square, isCapture: true)
    let nonCaptures = moves(for: piece, from: square, isCapture: false)
    return captures + nonCaptures
  }
}

extension Board: CustomDebugStringConvertible {
  public var debugDescription: String {
    Square.Rank.allCases.reversed().map { rank in
      " \(rank) ".appending(Square.File.allCases.map { file in
        pieces[Square(file: file, rank: rank)]?.debugDescription ?? " "
      }.joined(separator: " "))
    }.joined(separator: "\n").appending("\n   ").appending(Square.File.allCases.map(\.description).joined(separator: " "))
  }
}

extension Board: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (Square, Piece)...) {
    self.init(pieces: .init(uniqueKeysWithValues: elements))
  }
}

extension Board {
  var isCheck: Bool {
    pieces.filter { _, piece in
      piece.color == moveColor.opposite
    }.flatMap { square, piece in
      moves(for: piece, from: square, isCapture: true)
    }.contains { targetSquare in
      pieces[targetSquare]?.figure == .king
    }
  }

  var isCheckmate: Bool {
    isCheck && isNoMovePossible
  }

  var isNoMovePossible: Bool {
    !pieces.filter { _, piece in
      piece.color == moveColor
    }.flatMap { originSquare, piece in
      moves(from: originSquare).map { targetSquare in
        mutation(for: piece, from: originSquare, to: targetSquare, promoteTo: nil)
      }
    }.contains { mutation in
      mutatedBoard(mutations: [mutation]) != nil
    }
  }

  func moves(for piece: Piece, from square: Square, isCapture: Bool) -> [Square] {
    let castleMoves: [Square]

    let backRank = moveColor.backRank
    let kingSquare = Square(file: .e, rank: backRank)

    if piece.figure == .king,
       hasPieceNotMoved(piece: .init(color: moveColor, figure: .king), square: kingSquare),
       !isCapture,
       !isCheck {
      let longRookSquare = Square(file: .a, rank: backRank)
      let castleLong: [Square] = if ![Square(file: .b, rank: backRank),
                                      Square(file: .c, rank: backRank),
                                      Square(file: .d, rank: backRank)].contains(where: pieces.keys.contains),
        hasPieceNotMoved(piece: .init(color: moveColor, figure: .rook), square: longRookSquare) {
        [Square(file: .c, rank: .one)]
      } else {
        []
      }

      let shortRookSquare = Square(file: .h, rank: backRank)
      let castleShort: [Square] = if ![Square(file: .f, rank: backRank),
                                       Square(file: .g, rank: backRank)].contains(where: pieces.keys.contains),
        hasPieceNotMoved(piece: .init(color: moveColor, figure: .rook), square: shortRookSquare) {
        [Square(file: .g, rank: .one)]
      } else {
        []
      }

      castleMoves = castleLong + castleShort
    } else {
      castleMoves = []
    }

    let traditionalMoves = (isCapture ? piece.capturePaths(from: square) : piece.movePaths(from: square)).flatMap { path in
      let obstruction = path.enumerated().first { _, square in
        pieces.keys.contains(square)
      }

      // Non-capture moves can move a piece up to the first obstruction in its path or the end of the path if it's unobstructed.
      guard isCapture else {
        return path.prefix(upTo: obstruction?.0 ?? path.endIndex)
      }

      // En passant captures are the only captures where the captured piece is not in the capture path.
      guard let obstruction, pieces[obstruction.1]!.color != piece.color else {
        guard let enPassant, piece.figure == .pawn, path.first == enPassant + piece.forwardUnitVector else {
          return []
        }

        return [path.first!]
      }

      // All other captures take the first opposing piece in the path.
      return path[obstruction.0 ..< obstruction.0 + 1]
    }

    return castleMoves + traditionalMoves
  }

  func mutation(for piece: Piece,
                from originSquare: Square,
                to targetSquare: Square,
                promoteTo promotion: Piece.Figure?) -> Mutation {
    { board in
      // Move piece.
      var pieces = board.pieces
      pieces[originSquare] = nil
      pieces[targetSquare] = .init(color: piece.color, figure: promotion ?? piece.figure)

      // Capture en passant.
      if let enPassant = board.enPassant, piece.figure == .pawn, targetSquare == enPassant + piece.forwardUnitVector {
        pieces[enPassant] = nil
      }

      return Board(pieces: pieces)
    }
  }

  func mutatedBoard(mutations: [Mutation]) -> Self? {
    mutations.reduce(self) { board, mutation in
      guard let board else {
        return nil
      }

      // To move into check is forbidden.
      var mutatedBoard = mutation(board)
      mutatedBoard.dataSource = dataSource
      guard !mutatedBoard.isCheck else {
        return nil
      }

      return mutatedBoard
    }
  }
}

private extension Board {
  var enPassant: Square? {
    dataSource?.enPassant
  }

  var moveColor: Piece.Color {
    dataSource?.moveColor ?? .white
  }

  func hasPieceNotMoved(piece: Piece, square: Square) -> Bool {
    dataSource?.hasPieceNotMoved(piece: piece, square: square) ?? true
  }
}
