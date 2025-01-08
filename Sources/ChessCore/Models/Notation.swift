import Foundation

// MARK: - Notation

enum Notation {
  enum Play: Hashable {
    enum Castle {
      case long
      case short
    }

    case castle(castle: Castle)
    case translation(originFile: Square.File?,
                     originRank: Square.Rank?,
                     figure: Piece.Figure,
                     isCapture: Bool,
                     promotion: Piece.Figure?,
                     targetSquare: Square)
  }

  enum Punctuation: String {
    case check = "+"
    case checkmate = "#"

    fileprivate init?(_ character: Character) {
      self.init(rawValue: String(character))
    }
  }

  case end(victor: Piece.Color?)
  case play(_ play: Play, punctuation: Punctuation?)

  init?(notation: String) {
    switch notation {
    case .whiteVictory:
      self = .end(victor: .white)

    case .blackVictory:
      self = .end(victor: .black)

    case .draw:
      self = .end(victor: nil)

    default:
      var notation = notation

      let punctuation = notation.last.map(Punctuation.init) ?? nil
      if punctuation != nil {
        notation = String(notation.dropLast())
      }

      switch notation {
      case .castleLong:
        self = .play(.castle(castle: .long), punctuation: punctuation)

      case .castleShort:
        self = .play(.castle(castle: .short), punctuation: punctuation)

      default:
        let regex = try! NSRegularExpression(pattern: "([KQRBN])?([a-h])?([1-8])?([x])?([a-h][1-8])(?:=([QRBN]))?$")
        guard let match = regex.firstMatch(in: notation, range: NSRange(notation.startIndex..., in: notation)) else {
          return nil
        }

        let figure = (Range(match.range(at: 1), in: notation).flatMap { range in
          Piece.Figure(rawValue: String(notation[range]))
        }) ?? .pawn

        let originFile = Range(match.range(at: 2), in: notation).flatMap { range in
          Square.File(String(notation[range]).first!)
        }

        let originRank = Range(match.range(at: 3), in: notation).flatMap { range in
          Square.Rank(rawValue: Int(notation[range])!)
        }

        let isCapture = Range(match.range(at: 4), in: notation) != nil

        guard let targetSquare = Range(match.range(at: 5), in: notation).flatMap({ range in
          Square(notation: String(notation[range]))
        }) else {
          return nil
        }

        let promotion = Range(match.range(at: 6), in: notation).flatMap { range in
          Piece.Figure(rawValue: String(notation[range]))
        }

        self = .play(.translation(originFile: originFile,
                                  originRank: originRank,
                                  figure: figure,
                                  isCapture: isCapture,
                                  promotion: promotion,
                                  targetSquare: targetSquare),
                     punctuation: punctuation)
      }
    }
  }
}

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
