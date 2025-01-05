
enum InvalidNotation: Error {
  enum BadPunctuation {
    case isCheck
    case isCheckmate
    case isNotCheck
    case isNotCheckmate
  }

  case ambiguous([String])
  case badPunctuation(_: BadPunctuation)
  case illegalMove
  case unparseable(notation: String)
}
