import Foundation

// MARK: -
public extension Board {
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

  func moves(from square: Square) -> [Square] {
    guard let piece = pieces[square], piece.color == moveColor else {
      return []
    }

    let captures = moves(for: piece, from: square, isCapture: true)
    let nonCaptures = moves(for: piece, from: square, isCapture: false)
    return captures + nonCaptures
  }
}

private extension Board {
  var isCheckmate: Bool {
    isCheck(color: moveColor) && isNoMovePossible
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

  var moveColor: Piece.Color {
    moves.count.isMultiple(of: 2) ? .white : .black
  }

  func isCheck(color: Piece.Color) -> Bool {
    pieces.filter { _, piece in
      piece.color == color.opposite
    }.flatMap { square, piece in
      moves(for: piece, from: square, isCapture: true)
    }.contains { targetSquare in
      pieces[targetSquare]?.figure == .king
    }
  }

  func moves(for piece: Piece, from square: Square, isCapture: Bool) -> [Square] {
    let castleMoves: [Square]

    let backRank = moveColor.backRank
    let kingSquare = Square(file: .e, rank: backRank)

    if piece.figure == .king,
       pieces[kingSquare] == .init(color: moveColor, figure: .king),
       !moves.contains(where: { move in
         move.description.contains(kingSquare.description)
       }),
       !isCapture, !isCheck(color: moveColor) {
      let longRookSquare = Square(file: .a, rank: backRank)
      let castleLong: [Square] = if ![Square(file: .b, rank: backRank),
                                      Square(file: .c, rank: backRank),
                                      Square(file: .d, rank: backRank)].contains(where: pieces.keys.contains),
        pieces[longRookSquare] == Piece(color: moveColor, figure: .rook),
        !moves.contains(where: { move in
          move.description.contains(longRookSquare.description)
        }) {
        [Square(file: .c, rank: .one)]
      } else {
        []
      }

      let shortRookSquare = Square(file: .h, rank: backRank)
      let castleShort: [Square] = if ![Square(file: .f, rank: backRank),
                                       Square(file: .g, rank: backRank)].contains(where: pieces.keys.contains),
        pieces[shortRookSquare] == Piece(color: moveColor, figure: .rook),
        !moves.contains(where: { move in
          move.description.contains(shortRookSquare.description)
        }) {
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

  func mutations(for piece: Piece, from originSquare: Square, isCapture: Bool) -> [Notation.Play: [Mutation]] {
    moves(for: piece, from: originSquare, isCapture: isCapture).reduce(into: [:]) { mutations, targetSquare in
      let backRank = piece.color.backRank
      if piece.figure == .king, originSquare.file == .e, targetSquare.file == .c || targetSquare.file == .g {
        let isCastleLong = targetSquare.file == .c

        let kingOriginSquare = Square(file: .e, rank: backRank)
        let kingTargetSquare = Square(file: isCastleLong ? .c : .g, rank: backRank)
        let rookOriginSquare = Square(file: isCastleLong ? .a : .h, rank: backRank)
        let rookTargetSquare = Square(file: isCastleLong ? .d : .f, rank: backRank)

        // King must move over the rook's target square without moving into check.
        mutations[.castle(castle: isCastleLong ? .long : .short)] = [{ board in
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
        return
      }

      let promotions: [Piece.Figure?] = if piece.figure == .pawn, targetSquare.rank == moveColor.opposite.backRank {
        [.bishop, .knight, .queen, .rook]
      } else {
        [nil]
      }

      mutations = promotions.reduce(into: mutations) { mutations, promotion in
        mutations[.translation(originFile: originSquare.file,
                               originRank: originSquare.rank,
                               figure: piece.figure,
                               isCapture: isCapture,
                               promotion: promotion,
                               targetSquare: targetSquare)] = [mutation(for: piece, from: originSquare, to: targetSquare, promoteTo: promotion)]
      }
    }
  }

  func mutation(for piece: Piece, from originSquare: Square, to targetSquare: Square, promoteTo promotion: Piece.Figure?) -> Mutation {
    { board in
      // Move piece.
      var pieces = board.pieces
      pieces[originSquare] = nil
      pieces[targetSquare] = .init(color: piece.color, figure: promotion ?? piece.figure)

      // Capture en passant.
      if let enPassant = board.enPassant, piece.figure == .pawn, targetSquare == enPassant + piece.forwardUnitVector {
        pieces[enPassant] = nil
      }

      // Check for pawns that can be captured en passant.
      let enPassant = (piece.figure == .pawn && abs(originSquare.rank.rawValue - targetSquare.rank.rawValue) == 2) ? targetSquare : nil

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

extension Board: CustomDebugStringConvertible {
  public var debugDescription: String {
    let state = switch (moves.last, isCheckmate, isNoMovePossible) {
    case (.some(.end(.some)), _, _), (_, true, _):
      (moves.last.flatMap { move in
        if case let .end(.some(color)) = move {
          color
        } else {
          nil
        }
      } ?? moveColor.opposite).description.capitalized.appending(" \(String.wins)")

    case (.some(.end(nil)), _, _), (_, _, true):
      String.drawGame

    default:
      "\(moveColor.description.capitalized) \(String.toMove)"
    }

    let grid = Square.Rank.allCases.reversed().map { rank in
      " \(rank) ".appending(Square.File.allCases.map { file in
        pieces[Square(file: file, rank: rank)]?.debugDescription ?? " "
      }.joined(separator: " "))
    }.joined(separator: "\n").appending("\n   ").appending(Square.File.allCases.map(\.description).joined(separator: " "))

    return "\(state).\n\n\(grid)"
  }
}

// MARK: -
extension Notation: CustomStringConvertible {
  var description: String {
    switch self {
    case let .end(victor):
      switch victor {
      case .black:
        .blackVictory

      case .white:
        .whiteVictory

      case .none:
        .draw
      }

    case let .play(play, punctuation):
      "\(play)\(punctuation?.description ?? "")"
    }
  }
}

extension Notation.Play {
  static func ~= (lhs: Self, rhs: Self) -> Bool {
    guard case let .translation(lhsOriginFile, lhsOriginRank, lhsFigure, lhsIsCapture, lhsPromotion, lhsTargetSquare) = lhs,
          case let .translation(rhsOriginFile, rhsOriginRank, rhsFigure, rhsIsCapture, rhsPromotion, rhsTargetSquare) = rhs else {
      return lhs == rhs
    }

    if let lhsOriginFile, let rhsOriginFile, lhsOriginFile != rhsOriginFile {
      return false
    }

    if let lhsOriginRank, let rhsOriginRank, lhsOriginRank != rhsOriginRank {
      return false
    }

    if let lhsPromotion, let rhsPromotion, lhsPromotion != rhsPromotion {
      return false
    }
    
    return lhsFigure == rhsFigure && lhsIsCapture == rhsIsCapture && lhsTargetSquare == rhsTargetSquare
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

    case let .translation(originFile, originRank, figure, isCapture, promotion, targetSquare):
      let disambiguation = "\(originFile?.description ?? "")\(originRank?.description ?? "")"
      let promotion = promotion.map(\.rawValue).map(String.promotion.appending) ?? ""
      return "\(figure.rawValue)\(disambiguation)\(isCapture ? .capture : "")\(targetSquare)\(promotion)"
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
  /// - Parameter notationString: move notation
  public mutating func move(_ notation: String) throws {
    guard let notation = Notation(string: notation) else {
      throw InvalidNotation.unparseable(notation: notation)
    }

    guard case let .play(play, punctuation) = notation else {
      board.moves += [notation]
      return
    }

    let plays = board.pieces.filter { _, piece in
      piece.color == board.moveColor
    }.enumerated().flatMap { _, element in
      let (square, piece) = element
      let isCapture = if case let .translation(_, _, _, isCapture, _, _) = play {
        isCapture
      } else {
        false
      }

      let moves = board.moves(for: piece, from: square, isCapture: isCapture)
      return moves.reduce(into: [Notation.Play: [Board.Mutation]]()) { mutations, targetSquare in
        let backRank = piece.color.backRank
        if piece.figure == .king, square.file == .e, targetSquare.file == .c || targetSquare.file == .g {
          let isCastleLong = targetSquare.file == .c

          let kingOriginSquare = Square(file: .e, rank: backRank)
          let kingTargetSquare = Square(file: isCastleLong ? .c : .g, rank: backRank)
          let rookOriginSquare = Square(file: isCastleLong ? .a : .h, rank: backRank)
          let rookTargetSquare = Square(file: isCastleLong ? .d : .f, rank: backRank)

          // King must move over the rook's target square without moving into check.
          mutations[.castle(castle: isCastleLong ? .long : .short)] = [{ board in
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
          return
        }

        let promotions: [Piece.Figure?] = if piece.figure == .pawn, targetSquare.rank == board.moveColor.opposite.backRank {
          [.bishop, .knight, .queen, .rook]
        } else {
          [nil]
        }

        mutations = promotions.reduce(into: mutations) { mutations, promotion in
          mutations[.translation(originFile: square.file,
                                 originRank: square.rank,
                                 figure: piece.figure,
                                 isCapture: isCapture,
                                 promotion: promotion,
                                 targetSquare: targetSquare)] = [
            board.mutation(for: piece, from: square, to: targetSquare, promoteTo: promotion)
          ]
        }
      }

    }.filter { key, _ in
      key ~= play
    }

    guard plays.count < 2 else {
      throw InvalidNotation.ambiguous(plays.map(\.key).map(\.description))
    }

    guard let play = plays.first, var mutatedBoard = board.mutatedBoard(mutations: play.value) else {
      throw InvalidNotation.illegalMove
    }

    mutatedBoard.moves = board.moves + [notation]

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
      guard !isCheckmate else {
        throw InvalidNotation.badPunctuation(.isCheckmate)
      }
      guard !isCheck else {
        throw InvalidNotation.badPunctuation(.isCheck)
      }
    }

    board = mutatedBoard
  }

  /// Designated initializer
  public init(board: Board = .board) {
    self.board = board
  }
}

extension Game: CustomDebugStringConvertible {
  public var debugDescription: String {
    let moves = board.moves.isEmpty ? "" : stride(from: 0, to: board.moves.count, by: 2).map { i in
      "\(i / 2 + 1). "
        .appending(board.moves[i].description)
        .appending(board.moves.count > i + 1 ? " \(board.moves[i + 1])" : "")
    }.joined(separator: "\n")

    return "\(moves)\n\n\(board)"
  }
}
