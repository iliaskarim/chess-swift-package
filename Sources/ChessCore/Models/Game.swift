import Foundation
import SwiftUI

// MARK: -
private extension Notation.Play {
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

// MARK: - Game

/// A model representing a chess game.
///
/// Chess is a board game played between two players.
public class Game: ObservableObject {
  /// A model representing a game state.
  public enum Status: Equatable {
    public enum Draw {
      case byAgreement
      case byFiftyMoveRule
      case byStalemate
    }

    case winner(color: Piece.Color, isByResignation: Bool)
    case draw(Draw)
    case toMove(Piece.Color)
  }

  /// Game state
  public var status: Status {
    if case let .end(victor) = moves.last {
      return victor.flatMap { color in
        .winner(color: color, isByResignation: true)
      } ?? .draw(.byAgreement)
    }

    if board.isCheckmate {
      return .winner(color: moveColor.opposite, isByResignation: false)
    }

    if board.isNoMovePossible {
      return .draw(.byStalemate)
    }

    if moves.count >= 50, !moves.suffix(50).contains(where: { move in
      if case let .play(.translation(_, _, figure, isCapture, _, _), _) = move, figure == .pawn || isCapture {
        true
      } else {
        false
      }
    }) {
      return .draw(.byFiftyMoveRule)
    }

    return .toMove(moveColor)
  }

  /// Game board
  @Published public private(set) var board: Board

  /// Game over
  public var isGameOver: Bool {
    if case .toMove = status {
      return false
    }
    return true
  }

  private var moves = [Notation]()

  /// Move
  /// - Parameter notation: Move notation
  public func move(notation: String) throws {
    guard let notation = Notation(notation: notation) else {
      throw InvalidNotation.unparseable
    }

    guard case let .play(play, punctuation) = notation else {
      moves += [notation]
      return
    }

    let plays = board.pieces.filter { _, piece in
      piece.color == moveColor
    }.flatMap { square, piece in
      let isCapture = if case let .translation(_, _, _, isCapture, _, _) = play {
        isCapture
      } else {
        false
      }

      let moves = board.moves(for: piece, from: square, isCapture: isCapture)
      return moves.reduce(into: [Notation.Play: [Board.Mutation]]()) { mutations, targetSquare in
        if piece.figure == .king, square.file == .e, targetSquare.file == .c || targetSquare.file == .g {
          let backRank = piece.color.backRank
          let isCastleLong = targetSquare.file == .c
          let kingOriginSquare = Square(file: .e, rank: backRank)
          let kingTargetSquare = Square(file: isCastleLong ? .c : .g, rank: backRank)
          let rookOriginSquare = Square(file: isCastleLong ? .a : .h, rank: backRank)
          let rookTargetSquare = Square(file: isCastleLong ? .d : .f, rank: backRank)

          // King must move over the rook's target square without moving into check.
          mutations[.castle(castle: isCastleLong ? .long : .short)] = [{ board in
            .init(pieces: board.pieces.filter { square, _ in
              square != kingOriginSquare
            }.merging([rookTargetSquare: .init(color: self.moveColor, figure: .king)]) { _, new in
              new
            })
          }, { board in
            .init(pieces: board.pieces.filter { square, _ in
              square != rookTargetSquare
            }.merging([kingTargetSquare: .init(color: self.moveColor, figure: .king)]) { _, new in
              new
            })
          }, { board in
            .init(pieces: board.pieces.filter { square, _ in
              square != rookOriginSquare
            }.merging([rookTargetSquare: .init(color: self.moveColor, figure: .rook)]) { _, new in
              new
            })
          }]
          return
        }

        let promotions: [Piece.Figure?] = if piece.figure == .pawn, targetSquare.rank == moveColor.opposite.backRank {
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
      throw InvalidNotation.ambiguous(candidates: plays.map(\.key).map(\.description))
    }

    guard let play = plays.first, let mutatedBoard = board.mutatedBoard(mutations: play.value) else {
      throw InvalidNotation.illegalMove
    }

    moves += [notation]

    if mutatedBoard.isCheckmate {
      guard punctuation == .checkmate else {
        moves = moves.dropLast()
        throw InvalidNotation.badPunctuation(correctPunctuation: Notation.Punctuation.checkmate.description)
      }
    } else if mutatedBoard.isCheck {
      guard punctuation == .check else {
        moves = moves.dropLast()
        throw InvalidNotation.badPunctuation(correctPunctuation: Notation.Punctuation.check.description)
      }
    } else {
      guard punctuation == nil else {
        moves = moves.dropLast()
        throw InvalidNotation.badPunctuation(correctPunctuation: "")
      }
    }

    board = mutatedBoard
  }

  /// Designated initializer
  public init(board: Board = .board) {
    self.board = board
    self.board.dataSource = self
  }
}

extension Game: BoardDataSource {
  var enPassant: Square? {
    let pawn = Piece(color: moveColor.opposite, figure: .pawn)

    let intermediateRank = Square.Rank(rawValue: pawn.startRank.rawValue + pawn.forwardUnitVector.ranks)!
    let enPassantRank = Square.Rank(rawValue: intermediateRank.rawValue + pawn.forwardUnitVector.ranks)!

    guard case let .play(.translation(_, _, figure, isCapture, _, targetSquare), _) = moves.last, figure == .pawn, !isCapture,
          targetSquare.rank == enPassantRank else {
      return nil
    }

    let intermediateSquare = Square(file: targetSquare.file, rank: intermediateRank)

    guard !moves.contains(where: { move in
      if case let .play(.translation(_, _, figure, isCapture, _, targetSquare), _) = move {
        figure == .pawn && !isCapture && targetSquare == intermediateSquare
      } else {
        false
      }
    }) else {
      return nil
    }

    return targetSquare
  }

  var moveColor: Piece.Color {
    moves.count.isMultiple(of: 2) ? .white : .black
  }

  func hasPieceNotMoved(piece: Piece, square: Square) -> Bool {
    board.pieces[square] == piece && !moves.contains { notation in
      notation.description.contains(square.description)
    }
  }
}

extension Game: CustomDebugStringConvertible {
  public var debugDescription: String {
    let transcript = moves.isEmpty ? "" : stride(from: 0, to: moves.count, by: 2).map { i in
      "\(i / 2 + 1). "
        .appending(moves[i].description)
        .appending(moves.count > i + 1 ? " \(moves[i + 1])" : "")
    }.joined(separator: "\n")

    return "\(transcript)\(moves.isEmpty ? "" : "\n\n")\(status).\n\n\(board)"
  }
}

extension Game.Status: CustomStringConvertible {
  public var description: String {
    switch self {
    case let .winner(color, _):
      "\(color.description.capitalized) \(String.wins)"

    case .draw:
      .drawGame

    case let .toMove(color):
      "\(color.description.capitalized) \(String.toMove)"
    }
  }
}

extension Game.Status.Draw: CustomStringConvertible {
  public var description: String {
    switch self {
    case .byAgreement:
      "\(String.drawBy) \(String.agreement)"

    case .byFiftyMoveRule:
      "\(String.drawBy) \(String.fiftyMoveRule)"

    case .byStalemate:
      "\(String.drawBy) \(String.stalemate)"
    }
  }
}
