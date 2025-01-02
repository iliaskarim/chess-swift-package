import Foundation

// MARK: -
public extension Board {
  static var board: Board {
    let allPieces = Piece.Color.allCases.flatMap { color in
      Piece.Figure.allCases.map { figure in
        Piece(color: color, figure: figure)
      }
    }

    return Board(pieces: allPieces.reduce(into: .init()) { pieces, piece in
      let files: [Square.File]
      switch piece.figure {
      case .bishop:
        files = [.c, .f]

      case .king:
        files = [.e]

      case .knight:
        files = [.b, .g]

      case .pawn:
        files = Square.File.allCases

      case .queen:
        files = [.d]

      case .rook:
        files = [.a, .h]
      }

      pieces = files.reduce(into: pieces) { pieces, file in
        let rank: Square.Rank
        if case piece.figure = .pawn {
          rank = piece.color == .black ? .seven : .two
        } else {
          rank = piece.color == .black ? .eight : .one
        }
        pieces[.init(file: file, rank: rank)] = piece
      }
    })
  }
}

private extension Board {
  var isCheckmate: Bool {
    isCheck(color: moveColor) && isNoMovePossible
  }

  var isNoMovePossible: Bool {
    !pieces.filter { _, piece in
      piece.color == moveColor
    }.flatMap { square, piece in
      (moves(from: square, isCapture: false) + moves(from: square, isCapture: true)).map { targetSquare in
        mutatation(for: piece, from: square, to: targetSquare)
      }
    }.contains { mutation in
      mutatedBoard(mutations: [mutation]) != nil
    }
  }

  var moveColor: Piece.Color {
    moves.count.isMultiple(of: 2) ? .white : .black
  }

  func isCheck(color: Piece.Color) -> Bool {
    pieces.flatMap { square, _ in
      moves(from: square, isCapture: true)
    }.contains { targetSquare in
      pieces[targetSquare] == .init(color: color, figure: .king)
    }
  }

  func moves(from originSquare: Square, isCapture: Bool) -> [Square] {
    let piece = pieces[originSquare]!
    let paths = isCapture ? piece.capturePaths(from: originSquare) : piece.movePaths(from: originSquare)
    return paths.flatMap { path in
      let obstruction = path.enumerated().first { _, square in
        pieces[square] != nil
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
  }

  func mutatation(for piece: Piece, from originSquare: Square, to targetSquare: Square) -> Mutation {
    { board in
      // Move piece.
      var pieces = board.pieces
      pieces[originSquare] = nil
      pieces[targetSquare] = piece

      // Capture en passant.
      if let enPassant = board.enPassant, piece.figure == .pawn, targetSquare == enPassant + piece.forwardUnitVector {
        pieces[enPassant] = nil
      }

      // Check for pawns that can be captured en passant.
      let enPassant: Square?
      if piece.figure == .pawn, abs(originSquare.rank.rawValue - targetSquare.rank.rawValue) == 2 {
        enPassant = targetSquare
      } else {
        enPassant = nil
      }

      return Board(pieces: pieces, enPassant: enPassant)
    }
  }

  func mutatedBoard(mutations: [Mutation]) -> Self? {
    mutations.reduce(self) { board, mutation in
      guard let board else {
        return nil
      }

      // To move into check is forbidden.
      let mutatedBoard = mutation(board)
      guard !mutatedBoard.isCheck(color: moveColor) else {
        return nil
      }

      return mutatedBoard
    }
  }
}

extension Board: CustomStringConvertible {
  public var description: String {
    let state: String
    if case let .end(victor) = moves.last {
      switch victor {
        case let .some(color):
          state = "\(color.description.capitalized) \(String.wins)"
        case nil:
         state = .drawGame
      }
    } else if isCheckmate {
      let oppositeColor: Piece.Color = moveColor == .black ? .white : .black
      state = "\(oppositeColor.description.capitalized) \(String.wins)"
    } else if isNoMovePossible {
      state = .drawGame
    } else {
      state = "\(moveColor.description.capitalized) \(String.toMove)"
    }

    let grid = Square.Rank.allCases.reversed().map { rank in
      " \(rank) ".appending(Square.File.allCases.map { file in
        pieces[Square(file: file, rank: rank)]?.description ?? " "
      }.joined(separator: " "))
    }.joined(separator: "\n")
    .appending("\n   ")
    .appending(Square.File.allCases.map(\.description).joined(separator: " "))

    return "\(state).\n\n\(grid)"
  }
}

// MARK: -
extension Notation: CustomStringConvertible {
  var description: String {
    switch self {
    case let .end(victor):
      guard let victor else {
        return .draw
      }
      return victor == .black ? .blackVictory : .whiteVictory

    case let .play(play, punctuation):
      return "\(play)\(punctuation?.description ?? "")"
    }
  }
}

extension Notation.Play: CustomStringConvertible {
  var description: String {
    switch self {
    case let .castle(castle):
      switch castle {
      case .long:
        return .castleLong

      case .short:
        return .castleShort
      }

    case let .translation(disambiguationFile, disambiguationRank, figure, isCapture, promotion, targetSquare):
      let disambiguation = "\(disambiguationFile?.description ?? "")\(disambiguationRank?.description ?? "")"
      let promotion = promotion.map(\.description).map(String.promotion.appending) ?? ""
      return "\(figure)\(disambiguation)\(isCapture ? .capture : "")\(targetSquare)\(promotion)"
    }
  }
}

extension Notation.Punctuation: CustomStringConvertible {
  var description: String {
    rawValue
  }
}

// MARK: -
private extension Piece {
  var forwardUnitVector: Vector {
    Vector(ranks: color == .black ? -1 : 1)
  }

  func capturePaths(from square: Square) -> [[Square]] {
    guard .pawn == figure else {
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
      return Vector.diagonalUnitVectors.compactMap(square.allSquaresInDirection)

    case .king:
      return Vector.unitVectors.compactMap { vector in
        (square + vector).map { targetSquare in
          [targetSquare]
        }
      }

    case .knight:
      return [Vector(files: -2, ranks: -1),
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
      let oneSquareForward = (square + forwardUnitVector)!
      let isOnStartRank = square.rank == .two || square.rank == .seven
      return [[oneSquareForward, isOnStartRank ? oneSquareForward + forwardUnitVector : nil].compactMap { targetSquare in
        targetSquare
      }]

    case .queen:
      return Vector.unitVectors.compactMap(square.allSquaresInDirection)

    case .rook:
      return Vector.cardinalUnitVectors.compactMap(square.allSquaresInDirection)
    }
  }
}

extension Piece: CustomStringConvertible {
  public var description: String {
    let description = figure == .pawn ? "P" : figure.rawValue
    return color == .black ? description.lowercased() : description
  }
}

extension Piece.Color: CustomStringConvertible {
  public var description: String {
    rawValue
  }
}

extension Piece.Figure: CustomStringConvertible {
  public var description: String {
    rawValue
  }
}

// MARK: -
private extension Square {
  static func + (lhs: Self, rhs: Vector) -> Self? {
    guard let file = File(rawValue: lhs.file.rawValue + rhs.files), let rank = Rank(rawValue: lhs.rank.rawValue + rhs.ranks) else {
      return nil
    }
    return .init(file: file, rank: rank)
  }

  func allSquaresInDirection(_ direction: Vector) -> [Self] {
    (self + direction).map { squareInDirection in
      [squareInDirection] + squareInDirection.allSquaresInDirection(direction)
    } ?? []
  }
}

extension Square: CustomStringConvertible {
  public var description: String {
    "\(file)\(rank)"
  }
}

extension Square.File: CustomStringConvertible {
  var description: String {
    String(Character(UnicodeScalar(rawValue + 96)!))
  }
}

extension Square.Rank: CustomStringConvertible {
  var description: String {
    String(rawValue)
  }
}

// MARK: -
extension Vector {
  static let cardinalUnitVectors: [Vector] = [
    .init(files: -1, ranks: 0),
    .init(files: 0, ranks: -1),
    .init(files: 0, ranks: 1),
    .init(files: 1, ranks: 0)
  ]

  static let diagonalUnitVectors: [Vector] = [
    .init(files: -1, ranks: -1),
    .init(files: -1, ranks: 1),
    .init(files: 1, ranks: -1),
    .init(files: 1, ranks: 1)
  ]

  static let unitVectors = cardinalUnitVectors + diagonalUnitVectors
}

// MARK: - Game

/// A model representing a chess game.
///
/// Chess is a board game played between two players.
public struct Game {
  /// Game state
  public var isGameOver: Bool {
    guard case .end = board.moves.last else {
      return board.isNoMovePossible
    }
    return true
  }

  /// Game board
  private(set) var board: Board

  /// Move
  /// - Parameter notation: Notation
  public mutating func move(_ notationString: String) throws {
    guard let notation = Notation(string: notationString) else {
      throw InvalidNotation.unparseable(notation: notationString)
    }

    guard case let .play(play, punctuation) = notation else {
      board.moves += [notation]
      return
    }

    let mutations: [Board.Mutation]
    
    switch play {
    case let .castle(castle):
      // Cannot castle in check.
      guard !board.isCheck(color: board.moveColor) else {
        throw IllegalMove.cannotCastle(.inCheck)
      }
      
      let rank: Square.Rank = board.moveColor == .black ? .eight : .one

      // Squares between king and rook must be free.
      guard !(castle == .long ? [.b, .c, .d] : [.f, .g]).map({ file in
        Square(file: file, rank: rank)
      }).contains(where: board.pieces.keys.contains) else {
        throw IllegalMove.cannotCastle(.obstructed)
      }
      
      let kingOriginSquare = Square(file: .e, rank: rank)
      let rookOriginSquare = Square(file: castle == .long ? .a : .h, rank: rank)

      // Both king and rook must be unmoved.
      for (figure, square) in [Piece.Figure.king: kingOriginSquare, Piece.Figure.rook: rookOriginSquare] {
        guard board.pieces[square] == .init(color: board.moveColor, figure: figure) else {
          throw IllegalMove.cannotCastle(.pieceOutOfPosition(figure: figure))
        }
        
        guard !board.moves.contains(where: { notation in
          notation.description.contains(square.description)
        }) else {
          throw IllegalMove.cannotCastle(.pieceMoved(figure: figure))
        }
      }
      
      let kingTargetSquare = Square(file: castle == .long ?.c : .g, rank: rank)
      let rookTargetSquare = Square(file: castle == .long ? .d : .f, rank: rank)

      // King must move over the rook's target square without moving into check.
      mutations = [{ board in
        var pieces = board.pieces
        pieces[kingOriginSquare] = nil
        pieces[rookTargetSquare] = .init(color: board.moveColor, figure: .king)
        return Board(pieces: pieces)
      }, { board in
        var pieces = board.pieces
        pieces[rookTargetSquare] = nil
        pieces[kingTargetSquare] = .init(color: board.moveColor, figure: .king)
        return Board(pieces: pieces)
      }, { board in
        var pieces = board.pieces
        pieces[rookOriginSquare] = nil
        pieces[rookTargetSquare] = .init(color: board.moveColor, figure: .rook)
        return Board(pieces: pieces)
      }]
      
    case let .translation(disambiguationFile, disambiguationRank, figure, isCapture, promotion, targetSquare):
      let eligibleSquares: [Square] = board.pieces.compactMap { square, piece in
        guard piece == .init(color: board.moveColor, figure: figure) else {
          return nil
        }
        
        if let disambiguationFile, square.file != disambiguationFile {
          return nil
        }
        
        if let disambiguationRank, square.rank != disambiguationRank {
          return nil
        }
        
        return board.moves(from: square, isCapture: isCapture).contains(targetSquare) ? square : nil
      }
      
      guard let originSquare = eligibleSquares.first else {
        throw InvalidNotation.badMove
      }
      
      guard eligibleSquares.count == 1 else {
        throw InvalidNotation.ambiguous
      }
      
      // Pawns must be promoted when they reach the end of the board.
      let promotionRank: Square.Rank = board.moveColor == .black ? .one : .eight
      guard promotion != nil || figure != .pawn || targetSquare.rank != promotionRank else {
        throw IllegalMove.figureMustPromote
      }
      
      if let promotion {
        // Only pawns can be promoted
        guard figure == .pawn else {
          throw IllegalMove.figureCannotPromote
        }
        
        // only when they reach the end of the board
        guard targetSquare.rank == promotionRank else {
          throw IllegalMove.mustReachEndOfBoardToPromote
        }
        
        // and they must be promoted to bishop, knight, rook or queen.
        guard ![Piece.Figure.king, Piece.Figure.pawn].contains(promotion) else {
          throw IllegalMove.cannotPromoteToFigure
        }
      }

      let piece = Piece(color: board.moveColor, figure: promotion ?? figure)
      mutations = [board.mutatation(for: piece, from: originSquare, to: targetSquare)]
    }
    
    guard var mutatedBoard = board.mutatedBoard(mutations: mutations) else {
      throw IllegalMove.cannotMoveIntoCheck
    }
    
    mutatedBoard.moves = self.board.moves + [notation]
    
    // Compute game state.
    let isCheck = mutatedBoard.isCheck(color: mutatedBoard.moveColor)
    let isCheckmate = mutatedBoard.isCheckmate
    
    // Validate punctuation parsed from input notation.
    switch punctuation {
    case .check:
      guard isCheck else {
        throw InvalidNotation.badPunctuation(.isNotCheck)
      }
      guard !isCheckmate else {
        throw InvalidNotation.badPunctuation(.isCheckmate)
      }
      
    case .checkmate:
      guard isCheckmate else {
        throw InvalidNotation.badPunctuation(.isNotCheckmate)
      }
      
    case .none:
      guard  !isCheckmate else {
        throw InvalidNotation.badPunctuation(.isCheckmate)
      }
      guard !isCheck else {
        throw InvalidNotation.badPunctuation(.isCheck)
      }
    }
    
    self.board = mutatedBoard
  }

  /// Designated initializer
  public init(board: Board = .board) {
    self.board = board
  }
}

extension Game: CustomStringConvertible {
  public var description: String {
    let moves = board.moves.isEmpty ? "" : stride(from: 0, to: board.moves.count, by: 2).map { i in
      "\(i / 2 + 1). "
        .appending(board.moves[i].description)
        .appending(board.moves.count > i + 1 ? " \(board.moves[i + 1])" : "")
      }.joined(separator: "\n")

    return "\(moves)\n\n\(board)"
  }
}
