
/// A model representing an invalid notation error.
public enum InvalidNotation: Error {
  case ambiguous(candidates: [String])
  case badPunctuation(correctPunctuation: String)
  case illegalMove
  case unparseable
}
