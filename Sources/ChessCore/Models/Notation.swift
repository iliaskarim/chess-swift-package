
// MARK: - Notation

enum Notation {
  enum Play: Hashable {
    enum Castle {
      case long
      case short
    }

    case castle(castle: Castle)
    case translation(originFile: Square.File?, originRank: Square.Rank?, figure: Piece.Figure, isCapture: Bool, promotion: Piece.Figure?, targetSquare: Square)
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

  init?(string: String) {
    switch string {
    case .whiteVictory:
      self = .end(victor: .white)

    case .blackVictory:
      self = .end(victor: .black)

    case .draw:
      self = .end(victor: nil)

    default:
      var string = string

      let punctuation = string.last.map(Punctuation.init) ?? nil
      if punctuation != nil {
        string = String(string.dropLast())
      }

      switch string {
      case .castleLong:
        self = .play(.castle(castle: .long), punctuation: punctuation)
        
      case .castleShort:
        self = .play(.castle(castle: .short), punctuation: punctuation)
        
      default:
        let figure = (string.first.map(Piece.Figure.init) ?? nil) ?? .pawn
        if figure != .pawn {
          string = String(string.dropFirst())
        }

        let isCapture = string.contains(String.capture)
        string = string.replacingOccurrences(of: String.capture, with: "")
        
        let promotion = string.last.map(Piece.Figure.init) ?? nil
        if promotion != nil {
          string = String(string.dropLast())
          guard string.last == Character(String.promotion) else {
            return nil
          }
          string = String(string.dropLast())
        }

        let originFile: Square.File?
        let originRank: Square.Rank?
        if string.count == 4 {
          guard let file = string.first.map(Square.File.init) ?? nil else {
            return nil
          }
          originFile = file
          string = String(string.dropFirst())

          guard let rank = string.first.map(Square.Rank.init) ?? nil else {
            return nil
          }
          originRank = rank
          string = String(string.dropFirst())
        } else if string.count == 3 {
          if let file = string.first.map(Square.File.init) ?? nil {
            originFile = file
            originRank = nil
          } else if let rank = string.first.map(Square.Rank.init) ?? nil {
            originFile = nil
            originRank = rank
          } else {
            return nil
          }
          string = String(string.dropFirst())
        } else {
          originFile = nil
          originRank = nil
        }

        guard let targetSquare = Square(String(string)) else {
          return nil
        }

        self = .play(.translation(originFile: originFile, originRank: originRank, figure: figure, isCapture: isCapture, promotion: promotion, targetSquare: targetSquare), punctuation: punctuation)
      }
    }
  }
}
